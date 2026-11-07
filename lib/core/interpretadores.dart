/// Interpreta trechos falados (valores, datas, horas, documentos, forma de pagamento).
///
/// O reconhecimento de voz do iOS e do Android costuma devolver números em
/// algarismos ("250 reais", "14:30"), mas às vezes devolve por extenso
/// ("duzentos e cinquenta reais"). Os dois formatos são aceitos.
library;

import 'formatadores.dart';

const Map<String, int> _numeros = {
  'zero': 0, 'um': 1, 'uma': 1, 'dois': 2, 'duas': 2, 'tres': 3, 'quatro': 4,
  'cinco': 5, 'seis': 6, 'meia': 6, 'sete': 7, 'oito': 8, 'nove': 9, 'dez': 10,
  'onze': 11, 'doze': 12, 'treze': 13, 'quatorze': 14, 'catorze': 14,
  'quinze': 15, 'dezesseis': 16, 'dezasseis': 16, 'dezessete': 17,
  'dezoito': 18, 'dezenove': 19, 'vinte': 20, 'trinta': 30, 'quarenta': 40,
  'cinquenta': 50, 'cincoenta': 50, 'sessenta': 60, 'setenta': 70,
  'oitenta': 80, 'noventa': 90, 'cem': 100, 'cento': 100, 'duzentos': 200,
  'duzentas': 200, 'trezentos': 300, 'trezentas': 300, 'quatrocentos': 400,
  'quatrocentas': 400, 'quinhentos': 500, 'quinhentas': 500,
  'seiscentos': 600, 'seiscentas': 600, 'setecentos': 700, 'setecentas': 700,
  'oitocentos': 800, 'oitocentas': 800, 'novecentos': 900, 'novecentas': 900,
};

/// Converte números falados por extenso (ou em algarismos) em inteiro.
/// Ex.: "mil duzentos e cinquenta" -> 1250. Retorna null se não houver número.
///
/// Observação: "meia" vale 6 aqui (como em ditado de telefone/documento);
/// a interpretação de "e meia" em horários é tratada em [interpretarHora].
int? palavrasParaNumero(String texto) {
  final palavras = normalizar(texto)
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty);
  var total = 0;
  var atual = 0;
  var achou = false;
  for (final p in palavras) {
    if (p == 'e') continue;
    final digitos = int.tryParse(p);
    if (digitos != null) {
      atual += digitos;
      achou = true;
    } else if (_numeros.containsKey(p)) {
      atual += _numeros[p]!;
      achou = true;
    } else if (p == 'mil') {
      total += (atual == 0 ? 1 : atual) * 1000;
      atual = 0;
      achou = true;
    } else if (p == 'milhao' || p == 'milhoes') {
      total += (atual == 0 ? 1 : atual) * 1000000;
      atual = 0;
      achou = true;
    }
  }
  return achou ? total + atual : null;
}

/// Lê um número escrito com algarismos no padrão brasileiro e devolve centavos.
/// "1.250,50" -> 125050 ; "250" -> 25000 ; "250.5" -> 25050 ; "1.250" -> 125000
int? _numeroComAlgarismosEmCentavos(String s) {
  final m = RegExp(r'\d[\d.,]*').firstMatch(s);
  if (m == null) return null;
  var n = m.group(0)!;
  n = n.replaceAll(RegExp(r'[.,]+$'), '');
  final ultimaVirgula = n.lastIndexOf(',');
  final ultimoPonto = n.lastIndexOf('.');
  String inteiro;
  String decimal = '';
  if (ultimaVirgula >= 0) {
    inteiro = n.substring(0, ultimaVirgula).replaceAll(RegExp(r'[.,]'), '');
    decimal = n.substring(ultimaVirgula + 1).replaceAll(RegExp(r'[.,]'), '');
  } else if (ultimoPonto >= 0 && n.length - ultimoPonto - 1 <= 2) {
    // "250.50": ponto como separador decimal (comum no ditado do iOS)
    inteiro = n.substring(0, ultimoPonto).replaceAll('.', '');
    decimal = n.substring(ultimoPonto + 1);
  } else {
    inteiro = n.replaceAll('.', '');
  }
  if (inteiro.isEmpty) inteiro = '0';
  decimal = '${decimal}00'.substring(0, 2);
  return int.parse(inteiro) * 100 + int.parse(decimal);
}

/// Interpreta um valor monetário falado e devolve em centavos.
/// Aceita "R$ 250,00", "250 reais", "250 reais e 50 centavos",
/// "duzentos e cinquenta reais", "cinquenta centavos".
int? interpretarValor(String texto) {
  final t = normalizar(texto).replaceAll('r\$', ' ');
  final temCentavos = RegExp(r'centavo').hasMatch(t);
  final temReais = RegExp(r'\breal\b|\breais\b').hasMatch(t);

  if (temCentavos) {
    String parteReais = '';
    String parteCent = t;
    if (temReais) {
      final idx = t.indexOf(RegExp(r'\breal\b|\breais\b'));
      parteReais = t.substring(0, idx);
      parteCent = t.substring(idx).replaceFirst(RegExp(r'^(real|reais)'), '');
    }
    parteCent = parteCent.replaceAll(RegExp(r'centavos?.*'), '');
    final r = parteReais.trim().isEmpty ? 0 : _inteiroFalado(parteReais);
    final c = _inteiroFalado(parteCent);
    if (r == null || c == null) return null;
    return r * 100 + c.clamp(0, 99);
  }

  final semMoeda = t.replaceAll(RegExp(r'\breais\b|\breal\b'), ' ');
  if (RegExp(r'\d').hasMatch(semMoeda)) {
    // "1 mil e 200" ou "2 mil"
    if (RegExp(r'\bmil\b|\bmilho').hasMatch(semMoeda)) {
      final n = palavrasParaNumero(semMoeda);
      return n == null ? null : n * 100;
    }
    return _numeroComAlgarismosEmCentavos(semMoeda);
  }
  final n = palavrasParaNumero(semMoeda);
  return n == null ? null : n * 100;
}

int? _inteiroFalado(String texto) {
  final t = texto.replaceAll(RegExp(r'[.,]'), '');
  return palavrasParaNumero(t);
}

/// Interpreta horário falado: "14:30", "14h30", "14 horas e 30 minutos",
/// "duas e meia da tarde", "meio-dia", "9 e 15". Devolve "HH:MM".
String? interpretarHora(String texto) {
  var t = normalizar(texto).trim();
  if (t.contains('meio dia') || t.contains('meio-dia')) {
    t = t.replaceAll(RegExp(r'meio[ -]dia'), '12');
  }
  if (t.contains('meia noite') || t.contains('meia-noite')) {
    t = t.replaceAll(RegExp(r'meia[ -]noite'), '0');
  }
  final tarde = RegExp(r'da tarde|da noite|\bpm\b').hasMatch(t);
  final madrugada = RegExp(r'da madrugada|da manha|\bam\b').hasMatch(t);
  t = t.replaceAll(RegExp(r'da (tarde|noite|madrugada|manha)|\b(am|pm)\b'), ' ');

  int? hora;
  int minuto = 0;

  final dig = RegExp(r'(\d{1,2})\s*(?::|horas?|h)\s*(\d{1,2})?').firstMatch(t) ??
      RegExp(r'^\s*(\d{1,2})\s+(\d{2})\s*$').firstMatch(t);
  if (dig != null) {
    hora = int.parse(dig.group(1)!);
    final resto = t.substring(dig.end);
    if (dig.group(2) != null) {
      minuto = int.parse(dig.group(2)!);
    } else if (RegExp(r'\be meia\b').hasMatch(resto)) {
      minuto = 30;
    } else {
      final m = RegExp(r'^\s*e?\s*(.+?)\s*(minutos?)?\s*$').firstMatch(resto);
      if (m != null) minuto = palavrasParaNumero(m.group(1)!) ?? 0;
    }
  } else {
    // Forma "X e Y" ou por extenso: "duas e meia", "nove e quinze", "14 e 30"
    final partes = t
        .replaceAll(RegExp(r'\bhoras?\b|\bminutos?\b'), ' ')
        .split(RegExp(r'\s+e\s+'));
    hora = palavrasParaNumero(partes.first);
    if (partes.length > 1) {
      final resto = partes.sublist(1).join(' e ');
      minuto = RegExp(r'^\s*meia\s*$').hasMatch(resto) ? 30 : (palavrasParaNumero(resto) ?? 0);
    }
  }
  if (hora == null) return null;
  if (tarde && hora < 12) hora += 12;
  if (madrugada && hora == 12) hora = 0;
  if (hora > 23 || minuto > 59) return null;
  return formatarHora(hora, minuto);
}

/// Interpreta datas faladas: "hoje", "ontem", "anteontem", "07/11/2026",
/// "7/11", "dia 7 de novembro", "sete de novembro de 2026", "dia 15".
DateTime? interpretarData(String texto, {DateTime? agora}) {
  final ref = agora ?? DateTime.now();
  final hoje = DateTime(ref.year, ref.month, ref.day);
  final t = normalizar(texto).trim();
  if (t.contains('anteontem')) return hoje.subtract(const Duration(days: 2));
  if (t.contains('ontem')) return hoje.subtract(const Duration(days: 1));
  if (t.contains('hoje')) return hoje;
  if (t.contains('amanha')) return hoje.add(const Duration(days: 1));

  final barra = RegExp(r'(\d{1,2})\s*[/.-]\s*(\d{1,2})(?:\s*[/.-]\s*(\d{2,4}))?').firstMatch(t);
  if (barra != null) {
    final dia = int.parse(barra.group(1)!);
    final mes = int.parse(barra.group(2)!);
    var ano = barra.group(3) != null ? int.parse(barra.group(3)!) : hoje.year;
    if (ano < 100) ano += 2000;
    return _dataValida(ano, mes, dia);
  }

  final mesesNorm = mesesPt.map(normalizar).toList();
  for (var i = 0; i < mesesNorm.length; i++) {
    final idx = t.indexOf(RegExp('\\b${mesesNorm[i]}\\b'));
    if (idx < 0) continue;
    final antes = t
        .substring(0, idx)
        .replaceAll(RegExp(r'\bprimeiro\b'), ' 1 ')
        .replaceAll(RegExp(r'\bdia\b|\bde\b'), ' ');
    final depois = t.substring(idx + mesesNorm[i].length);
    final dia = palavrasParaNumero(antes) ?? 1;
    final anoMatch = RegExp(r'\d{4}').firstMatch(depois);
    final ano = anoMatch != null
        ? int.parse(anoMatch.group(0)!)
        : (palavrasParaNumero(depois) ?? hoje.year);
    return _dataValida(ano < 100 ? ano + 2000 : ano, i + 1, dia);
  }

  final soDia = RegExp(r'^(?:dia\s+)?(.+)$').firstMatch(t);
  if (soDia != null) {
    final dia = palavrasParaNumero(soDia.group(1)!);
    if (dia != null && dia >= 1 && dia <= 31) {
      return _dataValida(hoje.year, hoje.month, dia);
    }
  }
  return null;
}

DateTime? _dataValida(int ano, int mes, int dia) {
  if (mes < 1 || mes > 12 || dia < 1 || dia > 31) return null;
  final d = DateTime(ano, mes, dia);
  return d.month == mes ? d : null;
}

/// Extrai dígitos de CPF/CNPJ ditados ("123 456 789 00", "um dois três ...").
String interpretarDocumento(String texto) {
  final t = normalizar(texto);
  final buffer = StringBuffer();
  for (final p in t.split(RegExp(r'[^a-z0-9]+'))) {
    if (p.isEmpty) continue;
    if (RegExp(r'^\d+$').hasMatch(p)) {
      buffer.write(p);
    } else if (_numeros.containsKey(p) && _numeros[p]! < 10) {
      buffer.write(_numeros[p]);
    }
  }
  final digitos = buffer.toString();
  return digitos.isEmpty ? texto.trim() : formatarDocumento(digitos);
}

/// Normaliza a forma de pagamento falada.
String interpretarPagamento(String texto) {
  final t = normalizar(texto);
  if (t.contains('pix')) return 'PIX';
  if (t.contains('credito')) return 'Cartão de crédito';
  if (t.contains('debito')) return 'Cartão de débito';
  if (t.contains('cartao')) return 'Cartão';
  if (t.contains('dinheiro') || t.contains('especie')) return 'Dinheiro';
  if (t.contains('transferencia') || t.contains('ted') || t.contains('doc')) {
    return 'Transferência bancária';
  }
  if (t.contains('faturad') || t.contains('boleto')) return 'Faturado';
  return capitalizarPrimeira(texto.trim());
}

String capitalizarPrimeira(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Quilometragem: "45 km", "quarenta e cinco quilômetros", "12,5".
String interpretarKm(String texto) {
  final t = normalizar(texto);
  final dig = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(t);
  if (dig != null) return dig.group(0)!.replaceAll('.', ',');
  final n = palavrasParaNumero(t);
  return n?.toString() ?? texto.trim();
}
