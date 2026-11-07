import 'package:flutter/material.dart';

import '../core/formatadores.dart';
import '../models/modelos.dart';
import '../services/armazenamento.dart';
import '../services/impressao.dart';

/// Recibos já emitidos. Ao escolher "Repetir viagem", devolve o recibo para
/// preencher um novo com os mesmos dados.
class TelaHistorico extends StatefulWidget {
  const TelaHistorico({super.key, required this.armazenamento});

  final Armazenamento armazenamento;

  @override
  State<TelaHistorico> createState() => _TelaHistoricoState();
}

class _TelaHistoricoState extends State<TelaHistorico> {
  late final ServicoImpressao _impressao = ServicoImpressao(widget.armazenamento);
  String _busca = '';

  Future<void> _acoes(Recibo r) async {
    final m = widget.armazenamento.motorista;
    final escolha = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            title: Text('Recibo nº ${r.numeroFormatado} - ${r.passageiro}'),
            subtitle: Text(formatarMoeda(r.total)),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.print),
            title: const Text('Imprimir segunda via'),
            onTap: () => Navigator.pop(c, 'imprimir'),
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Compartilhar PDF'),
            onTap: () => Navigator.pop(c, 'compartilhar'),
          ),
          ListTile(
            leading: const Icon(Icons.repeat),
            title: const Text('Repetir viagem (novo recibo com estes dados)'),
            onTap: () => Navigator.pop(c, 'repetir'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Excluir do histórico'),
            onTap: () => Navigator.pop(c, 'excluir'),
          ),
        ]),
      ),
    );
    if (!mounted) return;
    switch (escolha) {
      case 'imprimir':
        await _impressao.imprimir(r, m);
      case 'compartilhar':
        await _impressao.compartilhar(r, m);
      case 'repetir':
        Navigator.pop(context, r);
      case 'excluir':
        final ok = await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Excluir recibo?'),
            content: Text('O recibo nº ${r.numeroFormatado} sairá do histórico.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Excluir')),
            ],
          ),
        );
        if (ok == true) {
          await widget.armazenamento.remover(r.numero);
          setState(() {});
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final busca = normalizar(_busca);
    final lista = widget.armazenamento.historico
        .where((r) =>
            busca.isEmpty ||
            normalizar('${r.passageiro} ${r.empresa} ${r.origem} ${r.destino} ${r.numero}')
                .contains(busca))
        .toList();
    final total = lista.fold<int>(0, (s, r) => s + r.total);
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de recibos')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar por passageiro, empresa, endereço ou número',
            ),
            onChanged: (v) => setState(() => _busca = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Text('${lista.length} recibo(s)'),
            const Spacer(),
            Text('Total: ${formatarMoeda(total)}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
        ),
        const Divider(),
        Expanded(
          child: lista.isEmpty
              ? const Center(child: Text('Nenhum recibo emitido ainda.'))
              : ListView.separated(
                  itemCount: lista.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = lista[i];
                    final data = r.dataViagem ?? r.emissao;
                    return ListTile(
                      leading: CircleAvatar(child: Text('${r.numero % 1000}')),
                      title: Text(r.passageiro, style: const TextStyle(fontSize: 18)),
                      subtitle: Text(
                        '${formatarData(data)} ${r.hora}  •  '
                        '${r.origem.isEmpty ? '-' : r.origem} → ${r.destino.isEmpty ? '-' : r.destino}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Text(formatarMoeda(r.total),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      onTap: () => _acoes(r),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}
