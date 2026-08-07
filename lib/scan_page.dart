import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'services/ble_connection_service.dart';
import 'config_page.dart';
import 'home_page.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _bleService = BleConnectionService();

  List<ScanResult> _results = [];
  StreamSubscription<List<ScanResult>>? _scanSub;
  bool _scanning = false;
  bool _connecting = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final granted = await _bleService.requestPermissions();
    if (!granted) {
      setState(() {
        _statusMessage =
            'Permissões de Bluetooth/localização negadas. Habilite nas configurações do app.';
      });
      return;
    }

    final btOn = await _bleService.isBluetoothOn();
    if (!btOn) {
      setState(() => _statusMessage = 'Bluetooth desligado. Ligando...');
      await _bleService.turnOnBluetooth();
    }

    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      _results = [];
      _scanning = true;
      _statusMessage = null;
    });

    _scanSub?.cancel();
    _scanSub = _bleService.scanResults.listen((results) {
      setState(() => _results = results);
    });

    await _bleService.startScan();
    setState(() => _scanning = false);
  }

  Future<void> _selectDevice(ScanResult result) async {
    await _bleService.stopScan();
    if(!mounted)
      return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => ConfigPage(device:result.device,),),);
  }

  @override
  void dispose() {
    _scanSub?.cancel();
    _bleService.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectar ao ESP32'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _scanning ? null : _startScan,
          ),
        ],
      ),
      body: _connecting
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_statusMessage != null)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      _statusMessage!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_scanning) const LinearProgressIndicator(),
                Expanded(
                  child: _results.isEmpty
                      ? Center(
                          child: Text(
                            _scanning
                                ? 'Procurando ESP32_Irrigacao...'
                                : 'Nenhum dispositivo encontrado.\nToque em atualizar para buscar novamente.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            final result = _results[index];
                            final name = result.device.platformName.isNotEmpty
                                ? result.device.platformName
                                : result.advertisementData.advName;

                            return ListTile(
                              leading: const Icon(Icons.bluetooth),
                              title: Text(
                                name.isNotEmpty ? name : 'Dispositivo sem nome',
                              ),
                              subtitle: Text(result.device.remoteId.str),
                              trailing: Text('${result.rssi} dBm'),
                              onTap: () => _selectDevice(result),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}