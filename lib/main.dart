import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'scan_page.dart';

void main() {
  runApp(const IrrigacaoApp());
}

class IrrigacaoApp extends StatelessWidget {
  const IrrigacaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Irrigação Automática',
      theme: ThemeData(
        colorSchemeSeed: Colors.green,
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('pt', 'BR'),
        Locale('en', 'US'),
      ],
      home: const ScanPage(),
    );
  }
}