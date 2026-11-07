/// Geração do recibo em PDF, tamanho A4.
///
/// Este arquivo usa apenas o pacote `pdf` (Dart puro), sem Flutter, para que
/// possa ser executado também pelo script `tool/gerar_exemplo.dart`.
library;

import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/extenso.dart';
import '../core/formatadores.dart';
import '../models/modelos.dart';

const _azul = PdfColor.fromInt(0xFF1F2A44);
const _dourado = PdfColor.fromInt(0xFFB08D57);
const _cinzaClaro = PdfColor.fromInt(0xFFF3F4F6);
const _cinzaBorda = PdfColor.fromInt(0xFFD1D5DB);
const _cinzaTexto = PdfColor.fromInt(0xFF4B5563);

/// As fontes padrão do PDF (Helvetica) cobrem o Latin-1, que inclui todos os
/// acentos do português. Outros caracteres (aspas tipográficas, emojis) são
/// trocados para não interromper a impressão.
String _seguro(String s) {
  const trocas = {
    '“': '"', '”': '"', '‘': "'", '’': "'",
    '–': '-', '—': '-', '…': '...', ' ': ' ',
  };
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    if (trocas.containsKey(c)) {
      b.write(trocas[c]);
    } else if (r <= 0xFF) {
      b.write(c);
    }
  }
  return b.toString();
}

Future<Uint8List> gerarReciboPdf(Recibo r, Motorista m) async {
  final doc = pw.Document(
    title: 'Recibo ${r.numeroFormatado}',
    author: _seguro(m.nome),
    creator: 'Recibo Executivo',
  );

  final base = pw.Font.helvetica();
  final negrito = pw.Font.helveticaBold();
  final tema = pw.ThemeData.withFont(base: base, bold: negrito);

  final dataViagem = r.dataViagem ?? r.emissao;
  final cidade = m.cidade.trim().isEmpty ? '' : '${m.cidade.trim()}, ';

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 32, 40, 26),
      theme: tema,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          _cabecalho(r, m),
          pw.SizedBox(height: 14),
          pw.Container(
            color: _azul,
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            child: pw.Text(
              'RECIBO DE TRANSPORTE EXECUTIVO DE PASSAGEIRO',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                color: PdfColors.white,
                fontWeight: pw.FontWeight.bold,
                fontSize: 13,
                letterSpacing: 1,
              ),
            ),
          ),
          pw.SizedBox(height: 16),
          _declaracao(r, m),
          pw.SizedBox(height: 14),
          _secao('DADOS DA VIAGEM'),
          _tabelaViagem(r, dataViagem),
          pw.SizedBox(height: 12),
          _secao('DISCRIMINAÇÃO DOS VALORES'),
          _tabelaValores(r),
          if (r.pagamento.trim().isNotEmpty || m.chavePix.trim().isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _pagamento(r, m),
          ],
          if (m.veiculo.trim().isNotEmpty || m.placa.trim().isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _secao('VEÍCULO'),
            _tabelaVeiculo(m),
          ],
          if (r.observacoes.trim().isNotEmpty) ...[
            pw.SizedBox(height: 12),
            _secao('OBSERVAÇÕES'),
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(border: pw.Border.all(color: _cinzaBorda, width: 0.7)),
              child: pw.Text(_seguro(r.observacoes), maxLines: 4, style: const pw.TextStyle(fontSize: 10.5)),
            ),
          ],
          pw.SizedBox(height: 16),
          pw.Spacer(),
          pw.Text(
            _seguro('$cidade${dataPorExtenso(r.emissao)}.'),
            textAlign: pw.TextAlign.right,
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.SizedBox(height: 34),
          _assinatura(m),
          pw.SizedBox(height: 14),
          pw.Divider(color: _cinzaBorda, thickness: 0.5),
          pw.Text(
            'Recibo nº ${r.numeroFormatado} emitido em ${formatarData(r.emissao)} às '
            '${formatarHora(r.emissao.hour, r.emissao.minute)}.',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 8, color: _cinzaTexto),
          ),
        ],
      ),
    ),
  );
  return doc.save();
}

pw.Widget _cabecalho(Recibo r, Motorista m) {
  final linhas = <String>[
    if (m.documento.trim().isNotEmpty)
      '${rotuloDocumento(m.documento)}: ${formatarDocumento(m.documento)}',
    [m.telefone, m.email].where((s) => s.trim().isNotEmpty).join('  |  '),
    m.endereco,
  ].where((s) => s.trim().isNotEmpty).toList();

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(width: 4, height: 62, color: _dourado),
      pw.SizedBox(width: 10),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              _seguro(m.nome.trim().isEmpty ? 'Motorista' : m.nome.toUpperCase()),
              style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: _azul),
            ),
            pw.SizedBox(height: 2),
            pw.Text('Transporte Executivo de Passageiros',
                style: const pw.TextStyle(fontSize: 10, color: _dourado)),
            pw.SizedBox(height: 4),
            for (final l in linhas)
              pw.Text(_seguro(l), style: const pw.TextStyle(fontSize: 9.5, color: _cinzaTexto)),
          ],
        ),
      ),
      pw.SizedBox(width: 12),
      pw.Container(
        width: 170,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _azul, width: 1.2),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          children: [
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 5),
              color: _azul,
              child: pw.Text(
                'RECIBO Nº ${r.numeroFormatado}',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10.5),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              child: pw.Column(children: [
                pw.Text('VALOR', style: const pw.TextStyle(fontSize: 8.5, color: _cinzaTexto)),
                pw.SizedBox(height: 2),
                pw.Text(
                  formatarMoeda(r.total),
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: _azul),
                ),
              ]),
            ),
          ],
        ),
      ),
    ],
  );
}

pw.Widget _declaracao(Recibo r, Motorista m) {
  const estilo = pw.TextStyle(fontSize: 11.5, lineSpacing: 3);
  final b = pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11.5, lineSpacing: 3);
  final doc = r.documento.trim().isEmpty
      ? ''
      : ', ${rotuloDocumento(r.documento)} ${formatarDocumento(r.documento)}';
  final empresa = r.empresa.trim().isEmpty ? '' : ', da empresa ';
  return pw.RichText(
    textAlign: pw.TextAlign.left,
    text: pw.TextSpan(
      style: estilo,
      children: [
        const pw.TextSpan(text: 'Recebi de '),
        pw.TextSpan(text: _seguro(r.passageiro.trim().isEmpty ? '______________________' : r.passageiro), style: b),
        pw.TextSpan(text: _seguro(doc)),
        if (empresa.isNotEmpty) ...[
          pw.TextSpan(text: empresa),
          pw.TextSpan(text: _seguro(r.empresa), style: b),
        ],
        const pw.TextSpan(text: ', a importância de '),
        pw.TextSpan(text: formatarMoeda(r.total), style: b),
        pw.TextSpan(text: ' (${valorPorExtenso(r.total)})'),
        const pw.TextSpan(
          text: ', referente à prestação de serviço de transporte executivo de passageiro, '
              'conforme discriminado abaixo, pelo que dou plena e geral quitação.',
        ),
      ],
    ),
  );
}

pw.Widget _secao(String titulo) => pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      padding: const pw.EdgeInsets.only(bottom: 3),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: _dourado, width: 1.2)),
      ),
      child: pw.Text(
        titulo,
        style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _azul, letterSpacing: 0.8),
      ),
    );

pw.Widget _celula(String rotulo, String valor, {int flex = 1}) => pw.Expanded(
      flex: flex,
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: _cinzaBorda, width: 0.7)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(rotulo, style: const pw.TextStyle(fontSize: 8, color: _cinzaTexto)),
            pw.SizedBox(height: 2),
            pw.Text(_seguro(valor.trim().isEmpty ? '-' : valor), style: const pw.TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );

pw.Widget _tabelaViagem(Recibo r, DateTime data) => pw.Column(children: [
      pw.Row(children: [
        _celula('Data', formatarData(data)),
        _celula('Horário de embarque', r.hora),
        _celula('Distância percorrida', r.km.trim().isEmpty ? '' : '${r.km} km'),
      ]),
      pw.Row(children: [_celula('Origem', r.origem)]),
      pw.Row(children: [_celula('Destino', r.destino)]),
    ]);

pw.Widget _tabelaValores(Recibo r) {
  final itens = <(String, int)>[
    ('Serviço de transporte executivo', r.valorCorrida),
    if (r.pedagio > 0) ('Pedágio', r.pedagio),
    if (r.estacionamento > 0) ('Estacionamento', r.estacionamento),
    if (r.outros > 0) ('Outras despesas / hora de espera', r.outros),
  ];
  pw.Widget linha(String a, String b, {bool total = false, bool zebra = false}) => pw.Container(
        color: total ? _azul : (zebra ? _cinzaClaro : null),
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: pw.Row(children: [
          pw.Expanded(
            child: pw.Text(a,
                style: pw.TextStyle(
                  fontSize: total ? 11.5 : 11,
                  fontWeight: total ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: total ? PdfColors.white : PdfColors.black,
                )),
          ),
          pw.Text(b,
              style: pw.TextStyle(
                fontSize: total ? 12 : 11,
                fontWeight: total ? pw.FontWeight.bold : pw.FontWeight.normal,
                color: total ? PdfColors.white : PdfColors.black,
              )),
        ]),
      );
  return pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all(color: _cinzaBorda, width: 0.7)),
    child: pw.Column(children: [
      for (var i = 0; i < itens.length; i++)
        linha(itens[i].$1, formatarMoeda(itens[i].$2), zebra: i.isOdd),
      linha('TOTAL', formatarMoeda(r.total), total: true),
    ]),
  );
}

pw.Widget _pagamento(Recibo r, Motorista m) {
  final partes = <String>[
    if (r.pagamento.trim().isNotEmpty) 'Forma de pagamento: ${r.pagamento}',
    if (m.chavePix.trim().isNotEmpty) 'Chave PIX: ${m.chavePix}',
  ];
  return pw.Text(
    _seguro(partes.join('     |     ')),
    style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: _azul),
  );
}

pw.Widget _tabelaVeiculo(Motorista m) => pw.Row(children: [
      _celula('Modelo', m.veiculo, flex: 2),
      _celula('Cor', m.cor),
      _celula('Placa', m.placa.toUpperCase()),
    ]);

pw.Widget _assinatura(Motorista m) => pw.Center(
      child: pw.SizedBox(
        width: 300,
        child: pw.Column(children: [
          pw.Divider(color: PdfColors.black, thickness: 0.8),
          pw.Text(_seguro(m.nome.trim().isEmpty ? 'Assinatura do motorista' : m.nome),
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          if (m.documento.trim().isNotEmpty)
            pw.Text('${rotuloDocumento(m.documento)}: ${formatarDocumento(m.documento)}',
                style: const pw.TextStyle(fontSize: 9.5, color: _cinzaTexto)),
        ]),
      ),
    );
