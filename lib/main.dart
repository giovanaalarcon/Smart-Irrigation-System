import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'scan_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const HydroFlowApp(),
  );
}

class HydroFlowApp extends StatelessWidget {
  const HydroFlowApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // ========================================================
      // CONFIGURAÇÃO GERAL
      // ========================================================

      debugShowCheckedModeBanner: false,

      title: 'HydroFlow',

      // ========================================================
      // LOCALIZAÇÃO
      // ========================================================
      //
      // Necessário principalmente para componentes do Flutter
      // como:
      //
      // - showDatePicker;
      // - calendários;
      // - botões e textos internos dos componentes Material.
      // ========================================================

      locale: const Locale(
        'pt',
        'BR',
      ),

      supportedLocales: const [
        Locale(
          'pt',
          'BR',
        ),
      ],

      localizationsDelegates:
          GlobalMaterialLocalizations.delegates,

      // ========================================================
      // TEMA
      // ========================================================

      theme: ThemeData(
        useMaterial3: true,

        colorScheme:
            ColorScheme.fromSeed(
          seedColor: Colors.green,
        ),

        appBarTheme:
            const AppBarTheme(
          centerTitle: true,
        ),

        inputDecorationTheme:
            const InputDecorationTheme(
          border:
              OutlineInputBorder(),
        ),

        cardTheme:
            const CardThemeData(
          elevation: 2,
          margin: EdgeInsets.zero,
        ),
      ),

      // ========================================================
      // PRIMEIRA TELA
      // ========================================================
      //
      // O fluxo começa procurando o ESP32 via BLE.
      // ========================================================

      home: const ScanPage(),
    );
  }
}