import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/tela_recibo.dart';
import 'services/armazenamento.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final armazenamento = await Armazenamento.abrir();
  runApp(AppRecibo(armazenamento: armazenamento));
}

class AppRecibo extends StatelessWidget {
  const AppRecibo({super.key, required this.armazenamento});

  final Armazenamento armazenamento;

  @override
  Widget build(BuildContext context) {
    const azul = Color(0xFF1F2A44);
    const dourado = Color(0xFFB08D57);
    final esquema = ColorScheme.fromSeed(
      seedColor: azul,
      primary: azul,
      secondary: dourado,
    );
    return MaterialApp(
      title: 'Recibo Executivo',
      debugShowCheckedModeBanner: false,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: esquema,
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: azul,
          foregroundColor: Colors.white,
        ),
      ),
      home: TelaRecibo(armazenamento: armazenamento),
    );
  }
}
