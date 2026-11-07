import 'package:flutter/material.dart';

import '../core/ditado.dart';
import '../core/extenso.dart';
import '../core/formatadores.dart';
import '../core/interpretadores.dart';
import '../models/modelos.dart';
import '../services/armazenamento.dart';
import '../services/impressao.dart';
import '../services/voz.dart';
import '../widgets/campo_voz.dart';
import 'tela_historico.dart';
import 'tela_motorista.dart';
import 'tela_previa.dart';

const _exemploDitado =
    '"Passageiro João da Silva, origem Aeroporto de Guarulhos, destino Avenida '
    'Paulista 1000, hora 14:30, valor 250 reais, pedágio 18 reais, pagamento PIX"';

class TelaRecibo extends StatefulWidget {
  const TelaRecibo({super.key, required this.armazenamento});

  final Armazenamento armazenamento;

  @override
  State<TelaRecibo> createState() => _TelaReciboState();
}

class _TelaReciboState extends State<TelaRecibo> {
  final _form = GlobalKey<FormState>();
  final _ctrl = {for (final c in Campo.values) c: TextEditingController()};
  final _numero = TextEditingController();
  late final ServicoImpressao _impressao = ServicoImpressao(widget.armazenamento);
  final _voz = ServicoVoz.instancia;
  bool _ocupado = false;

  Armazenamento get _arm => widget.armazenamento;

  @override
  void initState() {
    super.initState();
    _novo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_arm.motorista.completo) _abrirMotorista(primeiraVez: true);
    });
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    _numero.dispose();
    super.dispose();
  }

  void _novo() {
    for (final c in _ctrl.values) {
      c.clear();
    }
    final agora = DateTime.now();
    _ctrl[Campo.data]!.text = formatarData(agora);
    _ctrl[Campo.hora]!.text = formatarHora(agora.hour, agora.minute);
    _numero.text = _arm.proximoNumero.toString();
    setState(() {});
  }

  int _centavos(Campo c) => interpretarValor(_ctrl[c]!.text) ?? 0;

  int get _total =>
      _centavos(Campo.valor) +
      _centavos(Campo.pedagio) +
      _centavos(Campo.estacionamento) +
      _centavos(Campo.outros);

  Recibo _montar() {
    String t(Campo c) => _ctrl[c]!.text.trim();
    return Recibo(
      numero: int.tryParse(_numero.text.trim()) ?? _arm.proximoNumero,
      emissao: DateTime.now(),
      passageiro: t(Campo.passageiro),
      documento: t(Campo.documento),
      empresa: t(Campo.empresa),
      dataViagem: lerData(t(Campo.data)) ?? interpretarData(t(Campo.data)),
      hora: t(Campo.hora),
      origem: t(Campo.origem),
      destino: t(Campo.destino),
      km: t(Campo.km),
      valorCorrida: _centavos(Campo.valor),
      pedagio: _centavos(Campo.pedagio),
      estacionamento: _centavos(Campo.estacionamento),
      outros: _centavos(Campo.outros),
      pagamento: t(Campo.pagamento),
      observacoes: t(Campo.observacoes),
    );
  }

  void _carregar(Recibo r, {required bool comoNovo}) {
    _ctrl[Campo.passageiro]!.text = r.passageiro;
    _ctrl[Campo.documento]!.text = r.documento;
    _ctrl[Campo.empresa]!.text = r.empresa;
    _ctrl[Campo.origem]!.text = r.origem;
    _ctrl[Campo.destino]!.text = r.destino;
    _ctrl[Campo.km]!.text = r.km;
    String v(int c) => c == 0 ? '' : formatarMoeda(c, simbolo: false);
    _ctrl[Campo.valor]!.text = v(r.valorCorrida);
    _ctrl[Campo.pedagio]!.text = v(r.pedagio);
    _ctrl[Campo.estacionamento]!.text = v(r.estacionamento);
    _ctrl[Campo.outros]!.text = v(r.outros);
    _ctrl[Campo.pagamento]!.text = r.pagamento;
    _ctrl[Campo.observacoes]!.text = r.observacoes;
    if (comoNovo) {
      final agora = DateTime.now();
      _ctrl[Campo.data]!.text = formatarData(agora);
      _ctrl[Campo.hora]!.text = formatarHora(agora.hour, agora.minute);
      _numero.text = _arm.proximoNumero.toString();
    } else {
      _ctrl[Campo.data]!.text = r.dataViagem != null ? formatarData(r.dataViagem!) : '';
      _ctrl[Campo.hora]!.text = r.hora;
      _numero.text = r.numero.toString();
    }
    setState(() {});
  }

  // ---------------------------------------------------------------- Voz

  Future<void> _ditadoCompleto() async {
    if (_voz.ouvindo.value == 'ditado') {
      await _voz.parar();
      return;
    }
    final ok = await _voz.ouvir(
      quem: 'ditado',
      pausa: const Duration(seconds: 5),
      limite: const Duration(seconds: 90),
      frasesDeContexto: [
        for (final c in Campo.values) ...c.palavrasChave,
        'pix', 'cartão de crédito', 'cartão de débito', 'dinheiro', 'imprimir',
      ],
      aoTerminar: _aplicarDitado,
    );
    if (!ok && mounted) {
      _aviso('Reconhecimento de voz indisponível. '
          'Libere o microfone e o reconhecimento de fala nos Ajustes do aparelho.');
    }
  }

  void _aplicarDitado(String texto) {
    final r = interpretarDitado(texto);
    if (r.vazio) {
      _aviso('Não reconheci nenhum campo. Comece cada informação pelo nome do campo, '
          'por exemplo: "passageiro ...", "valor ...".');
      return;
    }
    r.campos.forEach((campo, valor) => _ctrl[campo]!.text = valor);
    setState(() {});
    _aviso('${r.campos.length} campo(s) preenchido(s): '
        '${r.campos.keys.map((c) => c.rotulo).join(', ')}');
    if (r.imprimir) _imprimir();
  }

  // ---------------------------------------------------------------- Ações

  void _aviso(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 5)));
  }

  bool _validar() {
    if (!(_form.currentState?.validate() ?? false)) {
      _aviso('Preencha os campos obrigatórios (*).');
      return false;
    }
    if (_total <= 0) {
      _aviso('Informe o valor da corrida.');
      return false;
    }
    if (!_arm.motorista.completo) {
      _abrirMotorista(primeiraVez: true);
      return false;
    }
    return true;
  }

  Future<void> _imprimir() async {
    if (_ocupado || !_validar()) return;
    setState(() => _ocupado = true);
    try {
      final r = _montar();
      final enviado = await _impressao.imprimir(r, _arm.motorista);
      if (!mounted) return;
      if (enviado) {
        await _arm.registrar(r);
        if (mounted) await _perguntarNovo();
      }
    } catch (e) {
      _aviso('Falha ao imprimir: $e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _perguntarNovo() async {
    final novo = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Recibo enviado para a impressora'),
        content: const Text('Deseja começar um novo recibo?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Manter dados')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Novo recibo')),
        ],
      ),
    );
    if (novo == true) _novo();
  }

  Future<void> _previa() async {
    if (!_validar()) return;
    final r = _montar();
    final impresso = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TelaPrevia(recibo: r, motorista: _arm.motorista),
      ),
    );
    if (impresso == true) {
      await _arm.registrar(r);
      if (mounted) await _perguntarNovo();
    }
  }

  Future<void> _compartilhar() async {
    if (!_validar()) return;
    final r = _montar();
    await _impressao.compartilhar(r, _arm.motorista);
    await _arm.registrar(r);
    if (mounted) setState(() => _numero.text = _arm.proximoNumero.toString());
  }

  Future<void> _abrirMotorista({bool primeiraVez = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaMotorista(armazenamento: _arm, primeiraVez: primeiraVez),
      ),
    );
    if (mounted) setState(() => _numero.text = _arm.proximoNumero.toString());
  }

  Future<void> _abrirHistorico() async {
    final duplicar = await Navigator.push<Recibo>(
      context,
      MaterialPageRoute(builder: (_) => TelaHistorico(armazenamento: _arm)),
    );
    if (duplicar != null) _carregar(duplicar, comoNovo: true);
    if (mounted) setState(() {});
  }

  Future<void> _escolherData() async {
    final atual = lerData(_ctrl[Campo.data]!.text) ?? DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: atual,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _ctrl[Campo.data]!.text = formatarData(d));
  }

  Future<void> _escolherHora() async {
    final partes = _ctrl[Campo.hora]!.text.split(':');
    final inicial = partes.length == 2
        ? TimeOfDay(hour: int.tryParse(partes[0]) ?? 0, minute: int.tryParse(partes[1]) ?? 0)
        : TimeOfDay.now();
    final h = await showTimePicker(context: context, initialTime: inicial);
    if (h != null) setState(() => _ctrl[Campo.hora]!.text = formatarHora(h.hour, h.minute));
  }

  // ---------------------------------------------------------------- Interface

  Widget _campo(Campo c, {bool obrigatorio = false, int linhas = 1, Widget? prefixo}) => CampoVoz(
        key: ValueKey('campo_${c.name}'),
        campo: c,
        controller: _ctrl[c]!,
        obrigatorio: obrigatorio,
        linhas: linhas,
        prefixo: prefixo,
        aoAlterar: () => setState(() {}),
      );

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recibo Executivo'),
        actions: [
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: _abrirHistorico,
            icon: const Icon(Icons.history),
            label: const Text('Histórico'),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: _abrirMotorista,
            icon: const Icon(Icons.badge_outlined),
            label: const Text('Motorista'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: LayoutBuilder(builder: (context, box) {
            final largo = box.maxWidth >= 720;
            Widget par(Widget a, Widget b) => largo
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: a),
                    const SizedBox(width: 16),
                    Expanded(child: b),
                  ])
                : Column(children: [a, const SizedBox(height: 14), b]);

            return ListView(
              padding: EdgeInsets.symmetric(horizontal: largo ? 32 : 16, vertical: 16),
              children: [
                _painelDitado(tema, largo),
                const SizedBox(height: 20),
                _titulo(tema, 'Passageiro'),
                par(_campo(Campo.passageiro, obrigatorio: true), _campo(Campo.documento)),
                const SizedBox(height: 14),
                _campo(Campo.empresa),
                const SizedBox(height: 22),
                _titulo(tema, 'Viagem'),
                par(
                  _campo(Campo.data,
                      prefixo: IconButton(icon: const Icon(Icons.event), onPressed: _escolherData)),
                  _campo(Campo.hora,
                      prefixo: IconButton(icon: const Icon(Icons.schedule), onPressed: _escolherHora)),
                ),
                const SizedBox(height: 14),
                _campo(Campo.origem),
                const SizedBox(height: 14),
                _campo(Campo.destino),
                const SizedBox(height: 14),
                par(_campo(Campo.km), _campo(Campo.pagamento)),
                const SizedBox(height: 22),
                _titulo(tema, 'Valores'),
                par(_campo(Campo.valor, obrigatorio: true), _campo(Campo.pedagio)),
                const SizedBox(height: 14),
                par(_campo(Campo.estacionamento), _campo(Campo.outros)),
                const SizedBox(height: 14),
                _caixaTotal(tema),
                const SizedBox(height: 22),
                _titulo(tema, 'Observações'),
                _campo(Campo.observacoes, linhas: 2),
                const SizedBox(height: 120),
              ],
            );
          }),
        ),
      ),
      bottomNavigationBar: _barraAcoes(tema),
    );
  }

  Widget _titulo(ThemeData tema, String t) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(t.toUpperCase(),
            style: tema.textTheme.titleSmall?.copyWith(
              letterSpacing: 1.2,
              color: tema.colorScheme.primary,
              fontWeight: FontWeight.bold,
            )),
      );

  Widget _painelDitado(ThemeData tema, bool largo) {
    return Card(
      elevation: 0,
      color: tema.colorScheme.primaryContainer.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ValueListenableBuilder<String?>(
          valueListenable: _voz.ouvindo,
          builder: (context, quem, _) {
            final ativo = quem == 'ditado';
            final texto = Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(ativo ? 'Ouvindo... fale os dados' : 'Preencher por voz',
                        style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    SizedBox(
                      width: 110,
                      child: TextField(
                        controller: _numero,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          labelText: 'Recibo nº',
                          isDense: true,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<String>(
                    valueListenable: _voz.parcial,
                    builder: (context, parcial, _) => Text(
                      ativo && parcial.isNotEmpty
                          ? parcial
                          : 'Toque no microfone e diga o nome de cada campo seguido do valor. '
                              'Ex.: $_exemploDitado. Termine com "imprimir" para imprimir direto.',
                      style: tema.textTheme.bodyLarge?.copyWith(
                        fontStyle: ativo ? FontStyle.normal : FontStyle.italic,
                        color: ativo ? null : tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            );
            return Row(children: [
              BotaoMicrofone(ativo: ativo, aoTocar: _ditadoCompleto),
              const SizedBox(width: 20),
              texto,
            ]);
          },
        ),
      ),
    );
  }

  Widget _caixaTotal(ThemeData tema) {
    final total = _total;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: tema.colorScheme.primary,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Expanded(
          child: Text(
            total > 0 ? valorPorExtenso(total) : 'Total do recibo',
            style: TextStyle(color: tema.colorScheme.onPrimary.withValues(alpha: 0.85)),
          ),
        ),
        Text(formatarMoeda(total),
            style: tema.textTheme.headlineSmall?.copyWith(
              color: tema.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            )),
      ]),
    );
  }

  Widget _barraAcoes(ThemeData tema) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: tema.colorScheme.surface,
          boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black12)],
        ),
        child: Row(children: [
          OutlinedButton.icon(
            onPressed: _novo,
            icon: const Icon(Icons.cleaning_services_outlined),
            label: const Text('Limpar'),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _compartilhar,
            icon: const Icon(Icons.share),
            label: const Text('PDF'),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: _previa,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Visualizar'),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            onPressed: _ocupado ? null : _imprimir,
            icon: _ocupado
                ? const SizedBox(
                    width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.print),
            label: const Text('Imprimir'),
          ),
        ]),
      ),
    );
  }
}
