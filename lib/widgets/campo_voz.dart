import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/ditado.dart';
import '../services/voz.dart';

/// Campo de texto com microfone próprio: toque no microfone e fale só o
/// conteúdo deste campo (ex.: no campo Valor, diga "trezentos reais").
class CampoVoz extends StatelessWidget {
  const CampoVoz({
    super.key,
    required this.campo,
    required this.controller,
    this.obrigatorio = false,
    this.linhas = 1,
    this.prefixo,
    this.aoAlterar,
    this.agora,
  });

  final Campo campo;
  final TextEditingController controller;
  final bool obrigatorio;
  final int linhas;
  final Widget? prefixo;
  final VoidCallback? aoAlterar;
  final DateTime Function()? agora;

  TextInputType get _teclado {
    if (campo.monetario) return const TextInputType.numberWithOptions(decimal: true);
    switch (campo) {
      case Campo.km:
        return const TextInputType.numberWithOptions(decimal: true);
      case Campo.documento:
      case Campo.data:
      case Campo.hora:
        return TextInputType.datetime;
      case Campo.observacoes:
        return TextInputType.multiline;
      default:
        return TextInputType.text;
    }
  }

  Future<void> _ditar(BuildContext context) async {
    final voz = ServicoVoz.instancia;
    if (voz.ouvindo.value == campo.name) {
      await voz.parar();
      return;
    }
    final ok = await voz.ouvir(
      quem: campo.name,
      pausa: const Duration(seconds: 2),
      limite: const Duration(seconds: 20),
      aoTerminar: (texto) {
        final valor = normalizarCampo(campo, texto, agora: agora?.call());
        if (valor.isEmpty) return;
        controller.text = valor;
        aoAlterar?.call();
      },
    );
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Reconhecimento de voz indisponível. Verifique a permissão do microfone.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return ValueListenableBuilder<String?>(
      valueListenable: ServicoVoz.instancia.ouvindo,
      builder: (context, quem, _) {
        final ativo = quem == campo.name;
        return TextFormField(
          controller: controller,
          minLines: linhas,
          maxLines: linhas == 1 ? 1 : linhas + 2,
          keyboardType: _teclado,
          textCapitalization: campo == Campo.passageiro || campo == Campo.empresa
              ? TextCapitalization.words
              : TextCapitalization.sentences,
          inputFormatters: campo.monetario
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
              : null,
          onChanged: (_) => aoAlterar?.call(),
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            labelText: obrigatorio ? '${campo.rotulo} *' : campo.rotulo,
            prefixText: campo.monetario ? 'R\$ ' : null,
            prefixIcon: prefixo,
            filled: ativo,
            fillColor: ativo ? cores.primaryContainer.withValues(alpha: 0.35) : null,
            suffixIcon: IconButton(
              tooltip: ativo ? 'Parar' : 'Ditar ${campo.rotulo.toLowerCase()}',
              iconSize: 28,
              icon: Icon(ativo ? Icons.stop_circle : Icons.mic_none,
                  color: ativo ? Colors.red : cores.primary),
              onPressed: () => _ditar(context),
            ),
          ),
          validator: obrigatorio
              ? (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null
              : null,
        );
      },
    );
  }
}

/// Botão grande de microfone para o ditado completo, com animação de nível.
class BotaoMicrofone extends StatelessWidget {
  const BotaoMicrofone({super.key, required this.ativo, required this.aoTocar});

  final bool ativo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return ValueListenableBuilder<double>(
      valueListenable: ServicoVoz.instancia.nivel,
      builder: (context, nivel, _) {
        // O nível vem aproximadamente entre -2 e 10 dB.
        final extra = ativo ? (nivel.clamp(0, 10) * 2.2) : 0.0;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: EdgeInsets.all(6 + extra),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (ativo ? Colors.red : cores.primary).withValues(alpha: 0.15),
          ),
          child: Material(
            color: ativo ? Colors.red : cores.primary,
            shape: const CircleBorder(),
            elevation: 4,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: aoTocar,
              child: SizedBox(
                width: 96,
                height: 96,
                child: Icon(ativo ? Icons.stop : Icons.mic, size: 52, color: Colors.white),
              ),
            ),
          ),
        );
      },
    );
  }
}
