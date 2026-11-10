import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recibo_executivo/main.dart';
import 'package:recibo_executivo/models/modelos.dart';
import 'package:recibo_executivo/services/armazenamento.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('tela principal soma os valores e mostra o total por extenso', (tester) async {
    tester.view.physicalSize = const Size(2048, 1536); // tablet na horizontal
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({
      'motorista': jsonEncode(const Motorista(nome: 'Carlos', documento: '12345678909').toJson()),
    });
    final arm = await Armazenamento.abrir();
    await tester.pumpWidget(AppRecibo(armazenamento: arm));
    await tester.pumpAndSettle();

    expect(find.text('Preencher por voz'), findsOneWidget);
    expect(find.text('Imprimir'), findsOneWidget);

    Finder campo(String nome) =>
        find.descendant(of: find.byKey(ValueKey('campo_$nome')), matching: find.byType(TextField));

    await tester.scrollUntilVisible(campo('pedagio'), 200, scrollable: find.byType(Scrollable).first);
    await tester.enterText(campo('valor'), '250');
    await tester.enterText(campo('pedagio'), '18,40');
    await tester.pump();

    expect(find.text(r'R$ 268,40'), findsOneWidget);
    expect(find.text('duzentos e sessenta e oito reais e quarenta centavos'), findsOneWidget);
  });
}
