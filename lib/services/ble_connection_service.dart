import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Serviço responsável pela etapa inicial da comunicação BLE.
///
/// Responsabilidades:
///
/// - solicitar permissões;
/// - verificar o estado do Bluetooth;
/// - tentar ativar o Bluetooth;
/// - procurar dispositivos BLE;
/// - identificar o ESP32 do HydroFlow;
/// - interromper o scan.
///
/// A conexão efetiva, descoberta das characteristics,
/// recebimento dos sensores e envio de comandos ficam no
/// IrrigacaoBleController.
class BleConnectionService {
  // ============================================================
  // IDENTIFICAÇÃO DO ESP32
  // ============================================================

  /// Nome anunciado pelo ESP32.
  static const String targetDeviceName =
      'ESP32_Irrigacao';

  /// UUID do serviço BLE utilizado pelo HydroFlow.
  ///
  /// Deve ser igual ao SERVICE_UUID definido no firmware
  /// do ESP32 e ao serviceUuid do IrrigacaoBleController.
  static const String serviceUuid =
      '4fafc201-1fb5-459e-8fcc-c5c9c331914b';

  // ============================================================
  // STREAMS
  // ============================================================

  /// Resultados encontrados durante o scan atual.
  ///
  /// onScanResults retorna os resultados do scan em andamento
  /// e limpa os resultados entre novos scans.
  Stream<List<ScanResult>> get scanResults {
    return FlutterBluePlus.onScanResults;
  }

  /// Estado atual do adaptador Bluetooth.
  Stream<BluetoothAdapterState> get adapterState {
    return FlutterBluePlus.adapterState;
  }

  /// Indica se existe um scan BLE em andamento.
  Stream<bool> get scanningState {
    return FlutterBluePlus.isScanning;
  }

  // ============================================================
  // PERMISSÕES
  // ============================================================

  /// Solicita as permissões necessárias para utilizar BLE.
  ///
  /// Android 12 ou superior:
  /// - Bluetooth Scan
  /// - Bluetooth Connect
  ///
  /// Em versões anteriores do Android, a localização pode ser
  /// necessária para realizar o scan BLE.
  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    return statuses.values.every(
      (status) =>
          status.isGranted ||
          status.isLimited,
    );
  }

  // ============================================================
  // BLUETOOTH
  // ============================================================

  /// Verifica se o Bluetooth está ligado.
  Future<bool> isBluetoothOn() async {
    final state =
        await FlutterBluePlus.adapterState.first;

    return state ==
        BluetoothAdapterState.on;
  }

  /// Tenta ligar o Bluetooth.
  ///
  /// No Android essa operação pode ser solicitada pelo
  /// flutter_blue_plus.
  ///
  /// Caso o sistema não permita ativá-lo automaticamente,
  /// a interface deverá orientar o usuário.
  Future<void> turnOnBluetooth() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (_) {
      // A interface tratará o caso em que o Bluetooth
      // precisar ser ativado manualmente.
    }
  }

  // ============================================================
  // SCAN
  // ============================================================

  /// Inicia a procura pelo ESP32 do HydroFlow.
  ///
  /// O filtro pelo UUID do serviço reduz dispositivos
  /// irrelevantes encontrados durante o scan.
  Future<void> startScan({
    Duration timeout =
        const Duration(seconds: 8),
  }) async {
    // Evita iniciar dois scans simultaneamente.
    if (FlutterBluePlus.isScanningNow) {
      await stopScan();
    }

    await FlutterBluePlus.startScan(
      timeout: timeout,
      withServices: [
        Guid(
          serviceUuid,
        ),
      ],
    );
  }

  /// Interrompe o scan BLE.
  Future<void> stopScan() async {
    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {
      // Não existe problema se o scan já tiver sido
      // encerrado pelo timeout.
    }
  }

  // ============================================================
  // IDENTIFICAÇÃO DO DISPOSITIVO
  // ============================================================

  /// Verifica se o dispositivo encontrado corresponde
  /// ao ESP32 utilizado pelo HydroFlow.
  ///
  /// O nome pode aparecer em platformName ou no nome
  /// anunciado durante o advertising.
  bool isIrrigationDevice(
    ScanResult result,
  ) {
    final deviceName =
        result.device.platformName.trim();

    final advertisedName =
        result.advertisementData
            .advName
            .trim();

    return deviceName ==
            targetDeviceName ||
        advertisedName ==
            targetDeviceName;
  }

  // ============================================================
  // INFORMAÇÕES DO DISPOSITIVO
  // ============================================================

  /// Retorna o nome mais adequado para exibição na interface.
  String getDeviceName(
    ScanResult result,
  ) {
    final platformName =
        result.device.platformName.trim();

    if (platformName.isNotEmpty) {
      return platformName;
    }

    final advertisedName =
        result.advertisementData
            .advName
            .trim();

    if (advertisedName.isNotEmpty) {
      return advertisedName;
    }

    return 'Dispositivo sem nome';
  }

  /// Retorna o identificador BLE do dispositivo.
  String getDeviceId(
    ScanResult result,
  ) {
    return result.device.remoteId.str;
  }
}