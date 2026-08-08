import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'scan_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const IrrigacaoApp());
}

class IrrigacaoApp extends StatelessWidget {
  const IrrigacaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Irrigação Inteligente',

      // --------------------------------------------------------
      // LOCALIZAÇÃO
      // --------------------------------------------------------
      //
      // Necessário para componentes como:
      // - showDatePicker
      // - calendário
      // - textos internos do Flutter
      //
      locale: const Locale('pt', 'BR'),

      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // --------------------------------------------------------
      // TEMA
      // --------------------------------------------------------

      theme: ThemeData(
        useMaterial3: true,

        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
        ),

        appBarTheme: const AppBarTheme(
          centerTitle: true,
        ),

        inputDecorationTheme:
            const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),

        cardTheme: const CardThemeData(
          elevation: 2,
          margin: EdgeInsets.zero,
        ),
      ),

      // --------------------------------------------------------
      // PRIMEIRA TELA
      // --------------------------------------------------------

      home: const ScanPage(),
    );
  }
}