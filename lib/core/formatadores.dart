/// Formatação de moeda, datas e documentos no padrão brasileiro.
library;

const mesesPt = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', 'julho',
  'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

String _doisDigitos(int n) => n.toString().padLeft(2, '0');

/// 125050 -> "R$ 1.250,50"
String formatarMoeda(int centavos, {bool simbolo = true}) {
  final negativo = centavos < 0;
  final abs = centavos.abs();
  final reais = (abs ~/ 100).toString();
  final cent = _doisDigitos(abs % 100);
  final buffer = StringBuffer();
  for (var i = 0; i < reais.length; i++) {
    if (i > 0 && (reais.length - i) % 3 == 0) buffer.write('.');
    buffer.write(reais[i]);
  }
  final valor = '${negativo ? '-' : ''}$buffer,$cent';
  return simbolo ? 'R\$ $valor' : valor;
}

/// "07/11/2026"
String formatarData(DateTime d) =>
    '${_doisDigitos(d.day)}/${_doisDigitos(d.month)}/${d.year}';

/// "7 de novembro de 2026"
String dataPorExtenso(DateTime d) => '${d.day} de ${mesesPt[d.month - 1]} de ${d.year}';

/// "14:05"
String formatarHora(int hora, int minuto) => '${_doisDigitos(hora)}:${_doisDigitos(minuto)}';

/// Lê "dd/mm/aaaa" (ou "dd/mm/aa").
DateTime? lerData(String texto) {
  final m = RegExp(r'^\s*(\d{1,2})/(\d{1,2})/(\d{2,4})\s*$').firstMatch(texto);
  if (m == null) return null;
  final dia = int.parse(m.group(1)!);
  final mes = int.parse(m.group(2)!);
  var ano = int.parse(m.group(3)!);
  if (ano < 100) ano += 2000;
  if (mes < 1 || mes > 12 || dia < 1 || dia > 31) return null;
  final d = DateTime(ano, mes, dia);
  return d.month == mes ? d : null;
}

/// Formata CPF (11 dígitos) ou CNPJ (14 dígitos); outros textos voltam sem alteração.
String formatarDocumento(String texto) {
  final d = texto.replaceAll(RegExp(r'\D'), '');
  if (d.length == 11) {
    return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}';
  }
  if (d.length == 14) {
    return '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/'
        '${d.substring(8, 12)}-${d.substring(12)}';
  }
  return texto.trim();
}

/// "CPF" ou "CNPJ" conforme a quantidade de dígitos; "Documento" caso contrário.
String rotuloDocumento(String texto) {
  final n = texto.replaceAll(RegExp(r'\D'), '').length;
  if (n == 11) return 'CPF';
  if (n == 14) return 'CNPJ';
  return 'Documento';
}

const _acentos = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n',
};

/// Minúsculas e sem acentos. Mantém o mesmo comprimento do texto original
/// (cada caractere vira exatamente um caractere), o que permite usar os
/// índices encontrados no texto normalizado para recortar o original.
String normalizar(String texto) {
  final buffer = StringBuffer();
  for (final rune in texto.runes) {
    final ch = String.fromCharCode(rune);
    final lower = ch.toLowerCase();
    final semAcento = _acentos[lower] ?? lower;
    // Garante 1 unidade de código por caractere de entrada.
    buffer.write(semAcento.length == ch.length ? semAcento : ch);
  }
  return buffer.toString();
}

/// Primeira letra de cada palavra em maiúscula (exceto preposições).
String capitalizarNome(String texto) {
  const minusculas = {'de', 'da', 'do', 'das', 'dos', 'e'};
  final palavras = texto.trim().split(RegExp(r'\s+'));
  return [
    for (var i = 0; i < palavras.length; i++)
      if (palavras[i].isEmpty)
        ''
      else if (i > 0 && minusculas.contains(palavras[i].toLowerCase()))
        palavras[i].toLowerCase()
      else
        palavras[i][0].toUpperCase() + palavras[i].substring(1),
  ].join(' ');
}
