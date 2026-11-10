import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/modelos.dart';

/// Guarda no aparelho os dados do motorista, a numeração e o histórico.
class Armazenamento {
  Armazenamento._(this._prefs);

  static const _chaveMotorista = 'motorista';
  static const _chaveProximoNumero = 'proximo_numero';
  static const _chaveHistorico = 'historico';
  static const _chaveImpressoraUrl = 'impressora_url';
  static const _chaveImpressoraNome = 'impressora_nome';
  static const _limiteHistorico = 500;

  final SharedPreferences _prefs;

  static Future<Armazenamento> abrir() async =>
      Armazenamento._(await SharedPreferences.getInstance());

  Motorista get motorista {
    final json = _prefs.getString(_chaveMotorista);
    if (json == null) return const Motorista();
    return Motorista.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> salvarMotorista(Motorista m) =>
      _prefs.setString(_chaveMotorista, jsonEncode(m.toJson()));

  int get proximoNumero => _prefs.getInt(_chaveProximoNumero) ?? 1;

  Future<void> definirProximoNumero(int n) => _prefs.setInt(_chaveProximoNumero, n);

  List<Recibo> get historico {
    final lista = _prefs.getStringList(_chaveHistorico) ?? const [];
    return [
      for (final s in lista) Recibo.fromJson(jsonDecode(s) as Map<String, dynamic>),
    ];
  }

  /// Registra o recibo emitido (substitui se o número já existir) e avança a numeração.
  Future<void> registrar(Recibo r) async {
    final lista = historico.where((x) => x.numero != r.numero).toList()
      ..insert(0, r);
    final cortada = lista.take(_limiteHistorico).map((x) => jsonEncode(x.toJson())).toList();
    await _prefs.setStringList(_chaveHistorico, cortada);
    if (r.numero >= proximoNumero) await definirProximoNumero(r.numero + 1);
  }

  Future<void> remover(int numero) async {
    final lista = historico.where((x) => x.numero != numero).map((x) => jsonEncode(x.toJson())).toList();
    await _prefs.setStringList(_chaveHistorico, lista);
  }

  /// Impressora lembrada para impressão direta (somente iOS/AirPrint).
  (String url, String nome)? get impressora {
    final url = _prefs.getString(_chaveImpressoraUrl);
    if (url == null || url.isEmpty) return null;
    return (url, _prefs.getString(_chaveImpressoraNome) ?? url);
  }

  Future<void> salvarImpressora(String? url, String? nome) async {
    if (url == null) {
      await _prefs.remove(_chaveImpressoraUrl);
      await _prefs.remove(_chaveImpressoraNome);
    } else {
      await _prefs.setString(_chaveImpressoraUrl, url);
      await _prefs.setString(_chaveImpressoraNome, nome ?? url);
    }
  }
}
