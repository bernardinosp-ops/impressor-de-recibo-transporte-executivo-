import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Reconhecimento de voz em português do Brasil (Siri Speech no iOS e
/// reconhecedor do Google no Android).
class ServicoVoz {
  ServicoVoz._();
  static final ServicoVoz instancia = ServicoVoz._();

  final SpeechToText _stt = SpeechToText();
  bool _iniciado = false;
  String? _localeId;

  /// Identifica quem está ouvindo agora: `null` = ninguém,
  /// `'ditado'` = ditado completo, ou o nome do campo.
  final ValueNotifier<String?> ouvindo = ValueNotifier<String?>(null);

  /// Texto parcial reconhecido, exibido em tempo real.
  final ValueNotifier<String> parcial = ValueNotifier<String>('');

  /// Nível do som captado (para a animação do microfone).
  final ValueNotifier<double> nivel = ValueNotifier<double>(0);

  String? ultimoErro;

  Future<bool> iniciar() async {
    if (_iniciado) return true;
    _iniciado = await _stt.initialize(
      onError: (SpeechRecognitionError e) {
        ultimoErro = e.errorMsg;
        if (e.permanent) _encerrar();
      },
      onStatus: (status) {
        if (status == SpeechToText.doneStatus || status == SpeechToText.notListeningStatus) {
          _encerrar();
        }
      },
    );
    if (_iniciado) {
      final locais = await _stt.locales();
      String norm(String id) => id.replaceAll('-', '_').toLowerCase();
      _localeId = locais
              .map((l) => l.localeId)
              .firstWhere((id) => norm(id) == 'pt_br', orElse: () => '') ;
      if (_localeId!.isEmpty) {
        _localeId = locais.map((l) => l.localeId).firstWhere(
              (id) => norm(id).startsWith('pt'),
              orElse: () => 'pt_BR',
            );
      }
    }
    return _iniciado;
  }

  void _encerrar() {
    ouvindo.value = null;
    nivel.value = 0;
  }

  /// Começa a ouvir. [aoTerminar] recebe o texto final reconhecido.
  ///
  /// [pausa] é o silêncio tolerado antes de encerrar: maior no ditado completo,
  /// para o motorista poder pensar entre um campo e outro.
  Future<bool> ouvir({
    required String quem,
    required void Function(String texto) aoTerminar,
    Duration pausa = const Duration(seconds: 3),
    Duration limite = const Duration(seconds: 30),
    List<String> frasesDeContexto = const [],
  }) async {
    if (!await iniciar()) return false;
    if (_stt.isListening) await _stt.stop();
    parcial.value = '';
    ultimoErro = null;
    ouvindo.value = quem;
    await _stt.listen(
      onResult: (SpeechRecognitionResult r) {
        parcial.value = r.recognizedWords;
        if (r.finalResult) {
          _encerrar();
          aoTerminar(r.recognizedWords);
        }
      },
      onSoundLevelChange: (n) => nivel.value = n,
      listenOptions: SpeechListenOptions(
        localeId: _localeId,
        listenFor: limite,
        pauseFor: pausa,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        autoPunctuation: true,
        contextualPhrases: frasesDeContexto,
      ),
    );
    return true;
  }

  /// Para de ouvir; o resultado final ainda é entregue a [ouvir].
  Future<void> parar() async {
    await _stt.stop();
    _encerrar();
  }

  Future<void> cancelar() async {
    await _stt.cancel();
    parcial.value = '';
    _encerrar();
  }
}
