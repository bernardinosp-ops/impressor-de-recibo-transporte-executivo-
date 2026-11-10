// Gera um recibo de exemplo em PDF sem precisar de celular/tablet:
//   dart run tool/gerar_exemplo.dart exemplo.pdf
import 'dart:io';

import 'package:recibo_executivo/core/ditado.dart';
import 'package:recibo_executivo/core/formatadores.dart';
import 'package:recibo_executivo/core/interpretadores.dart';
import 'package:recibo_executivo/models/modelos.dart';
import 'package:recibo_executivo/services/recibo_pdf.dart';

Future<void> main(List<String> args) async {
  final agora = DateTime(2026, 11, 7, 15, 42);
  final ditado = interpretarDitado(
    'Passageiro Ricardo Almeida Prado, CPF 123 456 789 09, empresa Acme Participações, '
    'origem Aeroporto Internacional de Guarulhos terminal 3, '
    'destino Hotel Fasano Avenida Paulista 1000, data hoje, hora 14:30, '
    'distância 38 km, valor 280 reais, pedágio 18 reais e 40 centavos, '
    'estacionamento 25 reais, pagamento pix, '
    'observação voo LA 3341, 2 malas grandes',
    agora: agora,
  );
  final c = ditado.campos;
  final recibo = Recibo(
    numero: 128,
    emissao: agora,
    passageiro: c[Campo.passageiro] ?? '',
    documento: c[Campo.documento] ?? '',
    empresa: c[Campo.empresa] ?? '',
    dataViagem: lerData(c[Campo.data] ?? ''),
    hora: c[Campo.hora] ?? '',
    origem: c[Campo.origem] ?? '',
    destino: c[Campo.destino] ?? '',
    km: c[Campo.km] ?? '',
    valorCorrida: interpretarValor(c[Campo.valor] ?? '') ?? 0,
    pedagio: interpretarValor(c[Campo.pedagio] ?? '') ?? 0,
    estacionamento: interpretarValor(c[Campo.estacionamento] ?? '') ?? 0,
    pagamento: c[Campo.pagamento] ?? '',
    observacoes: c[Campo.observacoes] ?? '',
  );
  const motorista = Motorista(
    nome: 'Carlos Eduardo Mendes',
    documento: '12345678000199',
    telefone: '(11) 98765-4321',
    email: 'contato@carlosexecutivo.com.br',
    endereco: 'Rua das Palmeiras, 250 - Moema - São Paulo/SP',
    cidade: 'São Paulo',
    veiculo: 'Toyota Corolla Altis Hybrid',
    cor: 'Preto',
    placa: 'BRA2E19',
    chavePix: '12.345.678/0001-99',
  );
  final bytes = await gerarReciboPdf(recibo, motorista);
  final saida = args.isNotEmpty ? args.first : 'recibo_exemplo.pdf';
  await File(saida).writeAsBytes(bytes);
  stdout.writeln('Gerado: $saida (${bytes.length} bytes)');
}
