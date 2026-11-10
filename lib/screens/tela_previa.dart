import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../models/modelos.dart';
import '../services/recibo_pdf.dart';

/// Pré-visualização do recibo A4. Retorna `true` ao sair se foi impresso.
class TelaPrevia extends StatefulWidget {
  const TelaPrevia({super.key, required this.recibo, required this.motorista});

  final Recibo recibo;
  final Motorista motorista;

  @override
  State<TelaPrevia> createState() => _TelaPreviaState();
}

class _TelaPreviaState extends State<TelaPrevia> {
  bool _impresso = false;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _impresso);
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Recibo nº ${widget.recibo.numeroFormatado}')),
        body: PdfPreview(
          build: (_) => gerarReciboPdf(widget.recibo, widget.motorista),
          initialPageFormat: PdfPageFormat.a4,
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          pdfFileName: 'Recibo_${widget.recibo.numeroFormatado}.pdf',
          onPrinted: (_) => _impresso = true,
          onShared: (_) => _impresso = true,
        ),
      ),
    );
  }
}
