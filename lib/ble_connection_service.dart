import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'irrigacao_ble_controller.dart';

/// Cuida de: permissões, estado do adaptador Bluetooth e scan de dispositivos.
/// A conexão em si (discoverServices, notify, write) fica no
/// [IrrigacaoBleController], que é criado depois que o usuário escolhe
/// o dispositivo na tela de scan.
class BleConnectionService {
  /// Nome anunciado pelo ESP32 no BLEDevice::init("ESP32_Irrigacao")
  static const String targetDeviceName = 'ESP32_Irrigacao';

  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;
  Stream<BluetoothAdapterState> get adapterState =>
      FlutterBluePlus.adapterState;

  /// Pede as permissões necessárias em runtime (Android 12+).
  /// Retorna true se todas foram concedidas.
  Future<bool> requestPermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse, // exigido em versões mais antigas do Android
    ].request();

    return statuses.values.every(
      (status) => status.isGranted || status.isLimited,
    );
  }

  Future<bool> isBluetoothOn() async {
    final state = await FlutterBluePlus.adapterState.first;
    return state == BluetoothAdapterState.on;
  }

  /// Pede para o usuário ligar o Bluetooth (Android). No iOS isso não
  /// é permitido programaticamente, o app deve orientar o usuário.
  Future<void> turnOnBluetooth() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (_) {
      // iOS ou dispositivo sem suporte: ignora, a UI deve orientar o usuário.
    }
  }

  Future<void> startScan({Duration timeout = const Duration(seconds: 8)}) {
    return FlutterBluePlus.startScan(
      timeout: timeout,
      withServices: [BleUuids.service], // filtra só o ESP32 de irrigação
    );
  }

  Future<void> stopScan() => FlutterBluePlus.stopScan();

  /// Cria e conecta o controlador para o dispositivo escolhido.
  Future<IrrigacaoBleController> connect(BluetoothDevice device) async {
    final controller = IrrigacaoBleController(device);
    await controller.connectAndListen();
    return controller;
  }
}