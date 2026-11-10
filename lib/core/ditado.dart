/// Interpretação do ditado completo do recibo.
///
/// O motorista fala uma frase com palavras-chave, por exemplo:
/// "passageiro João da Silva, CPF 123 456 789 09, origem Aeroporto de
/// Guarulhos, destino Avenida Paulista 1000, data hoje, hora 14:30,
/// valor 250 reais, pedágio 18 reais e 40 centavos, pagamento PIX".
/// Cada palavra-chave inicia um campo, que vai até a próxima palavra-chave.
library;

import 'formatadores.dart';
import 'interpretadores.dart';

enum Campo {
  passageiro('Passageiro', ['nome do passageiro', 'nome do cliente', 'passageira', 'passageiro', 'cliente', 'nome']),
  documento('CPF/CNPJ do passageiro', ['cpf', 'cnpj', 'documento']),
  empresa('Empresa', ['nome da empresa', 'empresa', 'companhia']),
  data('Data da viagem', ['data da viagem', 'data']),
  hora('Horário', ['horario de embarque', 'hora de embarque', 'horario', 'hora']),
  origem('Origem', ['local de embarque', 'embarque', 'origem', 'saida', 'partida']),
  destino('Destino', ['local de desembarque', 'desembarque', 'destino', 'chegada']),
  km('Distância (km)', ['quilometragem', 'quilometros rodados', 'distancia', 'km']),
  valor('Valor da corrida', ['valor da corrida', 'valor do servico', 'valor total', 'valor', 'preco', 'total']),
  pedagio('Pedágio', ['pedagios', 'pedagio']),
  estacionamento('Estacionamento', ['estacionamento']),
  outros('Outras despesas / espera', ['hora parada', 'tempo de espera', 'espera', 'outras despesas', 'adicional']),
  pagamento('Forma de pagamento', ['forma de pagamento', 'pagamento', 'pago com', 'pago em']),
  observacoes('Observações', ['observacoes', 'observacao', 'obs']);

  const Campo(this.rotulo, this.palavrasChave);

  final String rotulo;

  /// Palavras-chave já normalizadas (minúsculas, sem acento).
  final List<String> palavrasChave;

  bool get monetario =>
      this == valor || this == pedagio || this == estacionamento || this == outros;
}

/// Resultado do ditado completo.
class ResultadoDitado {
  ResultadoDitado(this.campos, {this.imprimir = false});

  /// Valores já formatados para exibição nos campos do formulário.
  final Map<Campo, String> campos;

  /// O motorista terminou o ditado com "imprimir".
  final bool imprimir;

  bool get vazio => campos.isEmpty;
}

/// Normaliza o texto falado de um campo específico (usado também pelo
/// microfone individual de cada campo).
String normalizarCampo(Campo campo, String texto, {DateTime? agora}) {
  final limpo = texto.trim().replaceAll(RegExp(r'^[\s,.:;-]+|[\s,.:;-]+$'), '');
  if (limpo.isEmpty) return '';
  switch (campo) {
    case Campo.passageiro:
    case Campo.empresa:
      return capitalizarNome(limpo);
    case Campo.documento:
      return interpretarDocumento(limpo);
    case Campo.data:
      final d = interpretarData(limpo, agora: agora);
      return d != null ? formatarData(d) : limpo;
    case Campo.hora:
      return interpretarHora(limpo) ?? limpo;
    case Campo.km:
      return interpretarKm(limpo);
    case Campo.valor:
    case Campo.pedagio:
    case Campo.estacionamento:
    case Campo.outros:
      final c = interpretarValor(limpo);
      return c != null ? formatarMoeda(c, simbolo: false) : limpo;
    case Campo.pagamento:
      return interpretarPagamento(limpo);
    case Campo.origem:
    case Campo.destino:
    case Campo.observacoes:
      return capitalizarPrimeira(limpo);
  }
}

class _Marca {
  _Marca(this.campo, this.inicio, this.fim);
  final Campo campo;
  final int inicio;
  final int fim;
}

// Palavras de ligação que o motorista costuma falar após a palavra-chave
// ("valor de 250", "origem é o aeroporto", "destino: ...").
final _conectores = RegExp(
  r'^(?:\s|[,.:;-])*(?:(?:e|eh|foi|sera|de|do|da|em|no|na|o|a|igual a|:)(?=\s|$)(?:\s|[,.:;-])*)*',
);

/// Interpreta o ditado completo e devolve os campos reconhecidos.
ResultadoDitado interpretarDitado(String texto, {DateTime? agora}) {
  var original = texto;
  var norm = normalizar(original);

  // Comando final "imprimir" / "imprimir recibo".
  var imprimir = false;
  final cmd = RegExp(r'[\s,.]*\b(?:pode\s+)?imprimir(?:\s+(?:o\s+)?recibo)?[\s,.!]*$').firstMatch(norm);
  if (cmd != null) {
    imprimir = true;
    original = original.substring(0, cmd.start);
    norm = norm.substring(0, cmd.start);
  }

  // Todas as palavras-chave, das mais longas para as mais curtas, para que
  // "forma de pagamento" vença "pagamento" e "valor total" vença "total".
  final chaves = <(String, Campo)>[
    for (final c in Campo.values)
      for (final p in c.palavrasChave) (p, c),
  ]..sort((a, b) => b.$1.length.compareTo(a.$1.length));

  final marcas = <_Marca>[];
  final ocupado = List<bool>.filled(norm.length, false);
  for (final (chave, campo) in chaves) {
    final re = RegExp('(?<![a-z0-9])${RegExp.escape(chave)}(?![a-z0-9])');
    for (final m in re.allMatches(norm)) {
      if (ocupado.sublist(m.start, m.end).any((o) => o)) continue;
      for (var i = m.start; i < m.end; i++) {
        ocupado[i] = true;
      }
      marcas.add(_Marca(campo, m.start, m.end));
    }
  }
  marcas.sort((a, b) => a.inicio.compareTo(b.inicio));

  // Cada campo começa na PRIMEIRA vez que sua palavra-chave é dita. Repetições
  // posteriores fazem parte do texto do campo em curso, como em
  // "observação cliente com 2 malas" ou "distância 45 km". Para corrigir um
  // campo já ditado, use o microfone do próprio campo.
  final vistos = <Campo>{};
  final aceitas = <_Marca>[];
  for (final m in marcas) {
    if (vistos.add(m.campo)) aceitas.add(m);
  }
  marcas
    ..clear()
    ..addAll(aceitas);

  final campos = <Campo, String>{};
  for (var i = 0; i < marcas.length; i++) {
    final atual = marcas[i];
    final fim = i + 1 < marcas.length ? marcas[i + 1].inicio : original.length;
    var trecho = original.substring(atual.fim, fim);
    final semConector = _conectores.firstMatch(normalizar(trecho));
    if (semConector != null) trecho = trecho.substring(semConector.end);
    final valor = normalizarCampo(atual.campo, trecho, agora: agora);
    if (valor.isNotEmpty) campos[atual.campo] = valor;
  }
  return ResultadoDitado(campos, imprimir: imprimir);
}
