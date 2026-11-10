// Ponte entre a página web do iPhone (iphone/recibo.html) e a lógica em Dart.
// Compilar: dart compile js -O2 -o iphone/api.js iphone/api.dart
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:recibo_executivo/core/ditado.dart';
import 'package:recibo_executivo/core/extenso.dart';
import 'package:recibo_executivo/core/formatadores.dart';
import 'package:recibo_executivo/core/interpretadores.dart';
import 'package:recibo_executivo/models/modelos.dart';
import 'package:recibo_executivo/services/recibo_pdf.dart';

Campo _campo(String nome) => Campo.values.firstWhere((c) => c.name == nome);

void main() {
  final api = JSObject();
  api['ditado'] = ((JSString texto) {
    final r = interpretarDitado(texto.toDart);
    return jsonEncode({
      'campos': {for (final e in r.campos.entries) e.key.name: e.value},
      'imprimir': r.imprimir,
    }).toJS;
  }).toJS;
  api['campo'] = ((JSString nome, JSString texto) =>
      normalizarCampo(_campo(nome.toDart), texto.toDart).toJS).toJS;
  api['valor'] = ((JSString texto) => (interpretarValor(texto.toDart) ?? 0).toJS).toJS;
  api['extenso'] = ((JSNumber centavos) => valorPorExtenso(centavos.toDartInt).toJS).toJS;
  api['moeda'] = ((JSNumber centavos) => formatarMoeda(centavos.toDartInt).toJS).toJS;
  api['data'] = ((JSString texto) {
    final d = lerData(texto.toDart) ?? interpretarData(texto.toDart);
    return (d?.toIso8601String() ?? '').toJS;
  }).toJS;
  api['documento'] = ((JSString texto) => formatarDocumento(texto.toDart).toJS).toJS;
  api['campos'] = jsonEncode([
    for (final c in Campo.values)
      {'nome': c.name, 'rotulo': c.rotulo, 'monetario': c.monetario},
  ]).toJS;
  api['pdf'] = ((JSString recibo, JSString motorista) {
    final r = Recibo.fromJson(jsonDecode(recibo.toDart) as Map<String, dynamic>);
    final m = Motorista.fromJson(jsonDecode(motorista.toDart) as Map<String, dynamic>);
    return gerarReciboPdf(r, m).then((b) => b.toJS).toJS;
  }).toJS;
  globalContext['reciboApi'] = api;
}
