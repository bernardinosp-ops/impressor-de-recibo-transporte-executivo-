import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../models/modelos.dart';
import 'armazenamento.dart';
import 'recibo_pdf.dart';

/// Impressão pelo sistema operacional.
///
/// * iOS: AirPrint (Wi-Fi ou Wi-Fi Direct da impressora; o iOS não imprime
///   por Bluetooth pelo sistema). É possível lembrar a impressora para
///   imprimir sem abrir a caixa de diálogo.
/// * Android: serviço de impressão do Android. A impressora Bluetooth aparece
///   depois de parear e instalar o plug-in do fabricante (ex.: "Brother Print
///   Service Plugin", "HP Print Service Plugin", "Canon Print Service" ou
///   "Mopria Print Service").
class ServicoImpressao {
  ServicoImpressao(this._armazenamento);

  final Armazenamento _armazenamento;

  Future<Uint8List> gerar(Recibo r, Motorista m) => gerarReciboPdf(r, m);

  String _nomeArquivo(Recibo r) => 'Recibo_${r.numeroFormatado}';

  /// Imprime. Retorna true se o trabalho foi enviado.
  Future<bool> imprimir(Recibo r, Motorista m) async {
    final bytes = await gerar(r, m);
    final salva = _armazenamento.impressora;
    if (salva != null) {
      final ok = await Printing.directPrintPdf(
        printer: Printer(url: salva.$1, name: salva.$2),
        onLayout: (_) async => bytes,
        name: _nomeArquivo(r),
        format: PdfPageFormat.a4,
        dynamicLayout: false,
      );
      if (ok) return true;
    }
    return Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: _nomeArquivo(r),
      format: PdfPageFormat.a4,
      dynamicLayout: false,
    );
  }

  /// Compartilha o PDF (WhatsApp, e-mail, arquivos...).
  Future<void> compartilhar(Recibo r, Motorista m) async {
    final bytes = await gerar(r, m);
    await Printing.sharePdf(bytes: bytes, filename: '${_nomeArquivo(r)}.pdf');
  }

  /// Indica se o sistema permite escolher e lembrar uma impressora (iOS).
  Future<bool> podeLembrarImpressora() async => (await Printing.info()).directPrint;

  /// Abre o seletor de impressoras do sistema e lembra a escolhida.
  Future<String?> escolherImpressora(BuildContext context) async {
    final p = await Printing.pickPrinter(context: context, title: 'Impressora padrão');
    if (p == null) return null;
    await _armazenamento.salvarImpressora(p.url, p.name);
    return p.name;
  }

  Future<void> esquecerImpressora() => _armazenamento.salvarImpressora(null, null);
}
