/// Conversão de valores monetários (em centavos) para extenso em português do Brasil.
library;

const _unidades = [
  '', 'um', 'dois', 'três', 'quatro', 'cinco', 'seis', 'sete', 'oito', 'nove',
  'dez', 'onze', 'doze', 'treze', 'quatorze', 'quinze', 'dezesseis',
  'dezessete', 'dezoito', 'dezenove',
];

const _dezenas = [
  '', '', 'vinte', 'trinta', 'quarenta', 'cinquenta', 'sessenta', 'setenta',
  'oitenta', 'noventa',
];

const _centenas = [
  '', 'cento', 'duzentos', 'trezentos', 'quatrocentos', 'quinhentos',
  'seiscentos', 'setecentos', 'oitocentos', 'novecentos',
];

/// Escreve um número de 0 a 999.
String _ate999(int n) {
  if (n == 0) return '';
  if (n == 100) return 'cem';
  final c = n ~/ 100;
  final resto = n % 100;
  final partes = <String>[];
  if (c > 0) partes.add(_centenas[c]);
  if (resto > 0) {
    if (resto < 20) {
      partes.add(_unidades[resto]);
    } else {
      final d = resto ~/ 10;
      final u = resto % 10;
      partes.add(u == 0 ? _dezenas[d] : '${_dezenas[d]} e ${_unidades[u]}');
    }
  }
  return partes.join(' e ');
}

/// Escreve um inteiro não negativo por extenso (até 999 bilhões).
String inteiroPorExtenso(int n) {
  if (n == 0) return 'zero';
  const escalas = [
    ['', ''],
    ['mil', 'mil'],
    ['milhão', 'milhões'],
    ['bilhão', 'bilhões'],
  ];
  final grupos = <int>[];
  var x = n;
  while (x > 0) {
    grupos.add(x % 1000);
    x ~/= 1000;
  }
  final partes = <String>[];
  for (var i = grupos.length - 1; i >= 0; i--) {
    final g = grupos[i];
    if (g == 0) continue;
    String texto;
    if (i == 0) {
      texto = _ate999(g);
    } else if (i == 1) {
      texto = g == 1 ? 'mil' : '${_ate999(g)} mil';
    } else {
      texto = '${_ate999(g)} ${g == 1 ? escalas[i][0] : escalas[i][1]}';
    }
    partes.add(texto);
  }
  if (partes.length == 1) return partes.first;

  // Regra do "e": usa-se "e" antes do último grupo quando ele é menor que 100
  // ou é uma centena exata (ex.: "mil e duzentos", "mil e cinquenta").
  final ultimo = grupos.firstWhere((g) => g > 0);
  final usaE = ultimo > 0 && (ultimo < 100 || ultimo % 100 == 0);
  if (usaE) {
    final semUltimo = partes.sublist(0, partes.length - 1).join(' ');
    return '$semUltimo e ${partes.last}';
  }
  return partes.join(' ');
}

/// Valor em centavos por extenso, ex.: 25050 -> "duzentos e cinquenta reais e cinquenta centavos".
String valorPorExtenso(int centavos) {
  if (centavos < 0) {
    throw ArgumentError.value(centavos, 'centavos', 'não pode ser negativo');
  }
  final reais = centavos ~/ 100;
  final cent = centavos % 100;
  if (reais == 0 && cent == 0) return 'zero real';

  final partes = <String>[];
  if (reais > 0) {
    final txt = inteiroPorExtenso(reais);
    // "um milhão de reais", "dois milhões de reais"
    final exatoMilhao = reais >= 1000000 && reais % 1000000 == 0;
    final moeda = reais == 1 ? 'real' : 'reais';
    partes.add(exatoMilhao ? '$txt de $moeda' : '$txt $moeda');
  }
  if (cent > 0) {
    partes.add('${inteiroPorExtenso(cent)} ${cent == 1 ? 'centavo' : 'centavos'}');
  }
  return partes.join(' e ');
}
