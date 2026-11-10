import 'package:flutter_test/flutter_test.dart';
import 'package:recibo_executivo/core/ditado.dart';
import 'package:recibo_executivo/core/extenso.dart';
import 'package:recibo_executivo/core/formatadores.dart';
import 'package:recibo_executivo/core/interpretadores.dart';

void main() {
  final agora = DateTime(2026, 11, 7, 10, 0);

  test('valor por extenso', () {
    expect(valorPorExtenso(25000), 'duzentos e cinquenta reais');
    expect(valorPorExtenso(100), 'um real');
    expect(valorPorExtenso(10000), 'cem reais');
    expect(valorPorExtenso(12050), 'cento e vinte reais e cinquenta centavos');
    expect(valorPorExtenso(1), 'um centavo');
    expect(valorPorExtenso(100000), 'mil reais');
    expect(valorPorExtenso(120000), 'mil e duzentos reais');
    expect(valorPorExtenso(125050), 'mil duzentos e cinquenta reais e cinquenta centavos');
    expect(valorPorExtenso(2100000), 'vinte e um mil reais');
    expect(valorPorExtenso(100000000), 'um milhão de reais');
    expect(valorPorExtenso(120000000), 'um milhão e duzentos mil reais');
  });

  test('moeda e documentos', () {
    expect(formatarMoeda(125050), r'R$ 1.250,50');
    expect(formatarMoeda(5), r'R$ 0,05');
    expect(formatarDocumento('12345678909'), '123.456.789-09');
    expect(formatarDocumento('12345678000199'), '12.345.678/0001-99');
    expect(normalizar('Ação São João').length, 'Ação São João'.length);
  });

  test('valores falados', () {
    expect(interpretarValor('250 reais'), 25000);
    expect(interpretarValor(r'R$ 250,50'), 25050);
    expect(interpretarValor('1.250,00'), 125000);
    expect(interpretarValor('250.5'), 25050);
    expect(interpretarValor('18 reais e 40 centavos'), 1840);
    expect(interpretarValor('duzentos e cinquenta reais'), 25000);
    expect(interpretarValor('mil e duzentos reais'), 120000);
    expect(interpretarValor('1 mil e 200'), 120000);
    expect(interpretarValor('cinquenta centavos'), 50);
    expect(interpretarValor('trinta reais e cinquenta centavos'), 3050);
  });

  test('horas faladas', () {
    expect(interpretarHora('14:30'), '14:30');
    expect(interpretarHora('14h30'), '14:30');
    expect(interpretarHora('14 horas e 30 minutos'), '14:30');
    expect(interpretarHora('9 horas'), '09:00');
    expect(interpretarHora('duas e meia da tarde'), '14:30');
    expect(interpretarHora('meio-dia'), '12:00');
    expect(interpretarHora('nove e quinze'), '09:15');
    expect(interpretarHora('8 da noite'), '20:00');
  });

  test('datas faladas', () {
    expect(interpretarData('hoje', agora: agora), DateTime(2026, 11, 7));
    expect(interpretarData('ontem', agora: agora), DateTime(2026, 11, 6));
    expect(interpretarData('05/10/2026', agora: agora), DateTime(2026, 10, 5));
    expect(interpretarData('5/10', agora: agora), DateTime(2026, 10, 5));
    expect(interpretarData('dia 3 de novembro', agora: agora), DateTime(2026, 11, 3));
    expect(interpretarData('sete de outubro de 2026', agora: agora), DateTime(2026, 10, 7));
    expect(interpretarData('primeiro de novembro', agora: agora), DateTime(2026, 11, 1));
    expect(interpretarData('dia 4', agora: agora), DateTime(2026, 11, 4));
  });

  test('documento e pagamento', () {
    expect(interpretarDocumento('123 456 789 09'), '123.456.789-09');
    expect(
      interpretarDocumento('um dois três quatro cinco seis sete oito nove zero nove'),
      '123.456.789-09',
    );
    expect(interpretarPagamento('foi no pix'), 'PIX');
    expect(interpretarPagamento('cartão de crédito'), 'Cartão de crédito');
  });

  test('ditado completo', () {
    final r = interpretarDitado(
      'Passageiro joão da silva, CPF 123 456 789 09, empresa acme ltda, '
      'origem Aeroporto de Guarulhos terminal 2, destino Avenida Paulista 1000, '
      'data hoje, hora 14:30, distância 45 km, valor de 250 reais, '
      'pedágio 18 reais e 40 centavos, forma de pagamento pix, '
      'observação cliente com 2 malas, imprimir',
      agora: agora,
    );
    expect(r.imprimir, isTrue);
    expect(r.campos[Campo.passageiro], 'João da Silva');
    expect(r.campos[Campo.documento], '123.456.789-09');
    expect(r.campos[Campo.empresa], 'Acme Ltda');
    expect(r.campos[Campo.origem], 'Aeroporto de Guarulhos terminal 2');
    expect(r.campos[Campo.destino], 'Avenida Paulista 1000');
    expect(r.campos[Campo.data], '07/11/2026');
    expect(r.campos[Campo.hora], '14:30');
    expect(r.campos[Campo.km], '45');
    expect(r.campos[Campo.valor], '250,00');
    expect(r.campos[Campo.pedagio], '18,40');
    expect(r.campos[Campo.pagamento], 'PIX');
    expect(r.campos[Campo.observacoes], 'Cliente com 2 malas');
  });

  test('ditado sem pontuação (como o reconhecedor costuma devolver)', () {
    final r = interpretarDitado(
      'cliente Maria Souza origem hotel Unique destino aeroporto de Congonhas '
      'valor 180 pagamento cartão de crédito',
      agora: agora,
    );
    expect(r.imprimir, isFalse);
    expect(r.campos[Campo.passageiro], 'Maria Souza');
    expect(r.campos[Campo.origem], 'Hotel Unique');
    expect(r.campos[Campo.destino], 'Aeroporto de Congonhas');
    expect(r.campos[Campo.valor], '180,00');
    expect(r.campos[Campo.pagamento], 'Cartão de crédito');
  });
}
