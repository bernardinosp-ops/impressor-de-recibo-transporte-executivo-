import 'package:flutter/material.dart';

import '../core/formatadores.dart';
import '../models/modelos.dart';
import '../services/armazenamento.dart';
import '../services/impressao.dart';

/// Dados do motorista (emitente do recibo), numeração e impressora.
class TelaMotorista extends StatefulWidget {
  const TelaMotorista({super.key, required this.armazenamento, this.primeiraVez = false});

  final Armazenamento armazenamento;
  final bool primeiraVez;

  @override
  State<TelaMotorista> createState() => _TelaMotoristaState();
}

class _TelaMotoristaState extends State<TelaMotorista> {
  final _form = GlobalKey<FormState>();
  late final Motorista _m = widget.armazenamento.motorista;
  late final _nome = TextEditingController(text: _m.nome);
  late final _documento = TextEditingController(text: _m.documento);
  late final _telefone = TextEditingController(text: _m.telefone);
  late final _email = TextEditingController(text: _m.email);
  late final _endereco = TextEditingController(text: _m.endereco);
  late final _cidade = TextEditingController(text: _m.cidade);
  late final _veiculo = TextEditingController(text: _m.veiculo);
  late final _cor = TextEditingController(text: _m.cor);
  late final _placa = TextEditingController(text: _m.placa);
  late final _pix = TextEditingController(text: _m.chavePix);
  late final _proximo =
      TextEditingController(text: widget.armazenamento.proximoNumero.toString());
  late final ServicoImpressao _impressao = ServicoImpressao(widget.armazenamento);
  bool _podeLembrar = false;

  @override
  void initState() {
    super.initState();
    _impressao.podeLembrarImpressora().then((v) {
      if (mounted) setState(() => _podeLembrar = v);
    });
  }

  @override
  void dispose() {
    for (final c in [
      _nome, _documento, _telefone, _email, _endereco, _cidade, _veiculo, _cor, _placa, _pix,
      _proximo,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _salvar() async {
    if (!_form.currentState!.validate()) return;
    await widget.armazenamento.salvarMotorista(Motorista(
      nome: _nome.text.trim(),
      documento: formatarDocumento(_documento.text),
      telefone: _telefone.text.trim(),
      email: _email.text.trim(),
      endereco: _endereco.text.trim(),
      cidade: _cidade.text.trim(),
      veiculo: _veiculo.text.trim(),
      cor: _cor.text.trim(),
      placa: _placa.text.trim().toUpperCase(),
      chavePix: _pix.text.trim(),
    ));
    final n = int.tryParse(_proximo.text.trim());
    if (n != null && n > 0) await widget.armazenamento.definirProximoNumero(n);
    if (mounted) Navigator.pop(context);
  }

  Widget _campo(TextEditingController c, String rotulo,
          {bool obrigatorio = false, TextInputType? teclado, String? dica}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextFormField(
          controller: c,
          keyboardType: teclado,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(labelText: obrigatorio ? '$rotulo *' : rotulo, helperText: dica),
          validator: obrigatorio
              ? (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null
              : null,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final impressora = widget.armazenamento.impressora;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dados do motorista'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _salvar,
              icon: const Icon(Icons.check),
              label: const Text('Salvar'),
            ),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (widget.primeiraVez)
              Card(
                color: tema.colorScheme.secondaryContainer,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Cadastre seus dados uma única vez. Eles aparecem no cabeçalho e na '
                    'assinatura de todos os recibos.',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            _campo(_nome, 'Nome completo ou razão social', obrigatorio: true),
            _campo(_documento, 'CPF ou CNPJ', obrigatorio: true, teclado: TextInputType.number),
            _campo(_telefone, 'Telefone / WhatsApp', teclado: TextInputType.phone),
            _campo(_email, 'E-mail', teclado: TextInputType.emailAddress),
            _campo(_endereco, 'Endereço'),
            _campo(_cidade, 'Cidade de emissão',
                dica: 'Aparece em "São Paulo, 7 de novembro de 2026".'),
            _campo(_pix, 'Chave PIX (opcional)'),
            const Divider(height: 32),
            Text('Veículo', style: tema.textTheme.titleMedium),
            const SizedBox(height: 12),
            _campo(_veiculo, 'Modelo (ex.: Toyota Corolla)'),
            Row(children: [
              Expanded(child: _campo(_cor, 'Cor')),
              const SizedBox(width: 16),
              Expanded(child: _campo(_placa, 'Placa')),
            ]),
            const Divider(height: 32),
            Text('Recibos e impressão', style: tema.textTheme.titleMedium),
            const SizedBox(height: 12),
            _campo(_proximo, 'Próximo número de recibo', teclado: TextInputType.number),
            if (_podeLembrar)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.print_outlined),
                title: Text(impressora == null ? 'Nenhuma impressora padrão' : impressora.$2),
                subtitle: const Text(
                    'Com uma impressora padrão, o botão Imprimir envia direto, sem abrir a caixa de diálogo.'),
                trailing: Wrap(spacing: 8, children: [
                  if (impressora != null)
                    TextButton(
                      onPressed: () async {
                        await _impressao.esquecerImpressora();
                        setState(() {});
                      },
                      child: const Text('Remover'),
                    ),
                  OutlinedButton(
                    onPressed: () async {
                      await _impressao.escolherImpressora(context);
                      if (mounted) setState(() {});
                    },
                    child: const Text('Escolher'),
                  ),
                ]),
              )
            else
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.bluetooth),
                title: Text('Impressora Bluetooth no Android'),
                subtitle: Text(
                  '1) Pareie a impressora nas configurações de Bluetooth.\n'
                  '2) Instale o plug-in de impressão do fabricante na Play Store '
                  '(Brother, HP, Canon, Epson ou Mopria).\n'
                  '3) Ao tocar em Imprimir, escolha a impressora e o papel A4.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
