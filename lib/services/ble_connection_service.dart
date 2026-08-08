import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Serviço responsável pela parte inicial da comunicação BLE.
///
/// Aqui ficam:
/// - permissões;
/// - estado do Bluetooth;
/// - busca de dispositivos;
/// - parada do scan.
///
/// A conexão efetiva e a comunicação com o ESP32 ficam no
/// IrrigacaoBleController.
class BleConnectionService {
  /// Nome que o ESP32 anuncia no BLE.
  static const String targetDeviceName = 'ESP32_Irrigacao';

  // ============================================================
  // STREAMS
  // ============================================================

  /// Resultados encontrados durante o scan.
  Stream<List<ScanResult>> get scanResults {
    return FlutterBluePlus.scanResults;
  }

  /// Estado atual do adaptador Bluetooth.
  Stream<BluetoothAdapterState> get adapterState {
    return FlutterBluePlus.adapterState;
  }

  // ============================================================
  // PERMISSÕES
  // ============================================================

  /// Solicita as permissões necessárias para BLE.
  ///
  /// Android mais recente:
  /// - Bluetooth Scan
  /// - Bluetooth Connect
  ///
  /// Android mais antigo pode precisar da localização para
  /// realizar o scan BLE.
  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    return statuses.values.every(
      (status) =>
          status.isGranted || status.isLimited,
    );
  }

  // ============================================================
  // BLUETOOTH
  // ============================================================

  /// Verifica se o Bluetooth está ligado.
  Future<bool> isBluetoothOn() async {
    final state =
        await FlutterBluePlus.adapterState.first;

    return state == BluetoothAdapterState.on;
  }

  /// Tenta ligar o Bluetooth.
  ///
  /// No Android isso pode funcionar dependendo da versão e
  /// das permissões.
  ///
  /// No iOS o aplicativo não pode simplesmente ligar o Bluetooth
  /// por conta própria.
  Future<void> turnOnBluetooth() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (_) {
      // Se o sistema não permitir ligar automaticamente,
      // a tela pode orientar o usuário a ligar manualmente.
    }
  }

  // ============================================================
  // SCAN
  // ============================================================

  /// Inicia a procura por dispositivos BLE.
  ///
  /// O filtro pelo serviço ajuda a encontrar somente dispositivos
  /// que anunciam o serviço utilizado pelo sistema de irrigação.
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    await FlutterBluePlus.startScan(
      timeout: timeout,
      withServices: [
        Guid(
          '4fafc201-1fb5-459e-8fcc-c5c9c331914b',
        ),
      ],
    );
  }

  /// Para o scan BLE.
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {
      // Não há problema se o scan já tiver sido encerrado.
    }
  }

  // ============================================================
  // VERIFICAÇÃO DO DISPOSITIVO
  // ============================================================

  /// Verifica se o dispositivo encontrado parece ser o ESP32
  /// utilizado pelo projeto.
  ///
  /// Alguns dispositivos podem não informar o nome em
  /// platformName, por isso também verificamos advertisementData.
  bool isIrrigationDevice(ScanResult result) {
    final deviceName =
        result.device.platformName.trim();

    final advertisedName =
        result.advertisementData.advName.trim();

    return deviceName == targetDeviceName ||
        advertisedName == targetDeviceName;
  }

  // ============================================================
  // DISPOSITIVO
  // ============================================================

  /// Retorna o nome que deve ser mostrado na interface.
  String getDeviceName(ScanResult result) {
    final platformName =
        result.device.platformName.trim();

    if (platformName.isNotEmpty) {
      return platformName;
    }

    final advertisedName =
        result.advertisementData.advName.trim();

    if (advertisedName.isNotEmpty) {
      return advertisedName;
    }

    return 'Dispositivo sem nome';
  }

  /// Retorna o identificador do dispositivo.
  String getDeviceId(ScanResult result) {
    return result.device.remoteId.str;
  }
}
