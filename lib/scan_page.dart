import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'services/ble_connection_service.dart';
import 'configuracao_cultivo_page.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final BleConnectionService _bleService = BleConnectionService();

  List<ScanResult> _results = [];

  StreamSubscription<List<ScanResult>>? _scanSubscription;

  bool _scanning = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  // ============================================================
  // INICIALIZAÇÃO
  // ============================================================

  Future<void> _inicializar() async {
    try {
      final permissao = await _bleService.requestPermissions();

      if (!mounted) return;

      if (!permissao) {
        setState(() {
          _statusMessage =
              'Permissões de Bluetooth/localização negadas. '
              'Habilite as permissões nas configurações do aplicativo.';
        });
        return;
      }

      final bluetoothLigado = await _bleService.isBluetoothOn();

      if (!bluetoothLigado) {
        setState(() {
          _statusMessage = 'Bluetooth desligado. Tentando ativar...';
        });

        await _bleService.turnOnBluetooth();

        // Dá um pequeno tempo para o Android atualizar o estado.
        await Future.delayed(const Duration(milliseconds: 500));

        final ligadoAgora = await _bleService.isBluetoothOn();

        if (!ligadoAgora) {
          if (!mounted) return;

          setState(() {
            _statusMessage =
                'O Bluetooth está desligado. Ative-o para continuar.';
          });

          return;
        }
      }

      await _iniciarScan();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _statusMessage = 'Erro ao inicializar Bluetooth: $e';
      });
    }
  }

  // ============================================================
  // SCAN
  // ============================================================

  Future<void> _iniciarScan() async {
    if (_scanning) return;

    setState(() {
      _results = [];
      _scanning = true;
      _statusMessage = null;
    });

    await _scanSubscription?.cancel();

    _scanSubscription = _bleService.scanResults.listen(
      (results) {
        if (!mounted) return;

        // Evita mostrar o mesmo dispositivo várias vezes.
        final dispositivos = <String, ScanResult>{};

        for (final result in results) {
          final id = result.device.remoteId.str;

          final existente = dispositivos[id];

          // Se o dispositivo já apareceu, mantém a leitura
          // com sinal mais forte.
          if (existente == null || result.rssi > existente.rssi) {
            dispositivos[id] = result;
          }
        }

        setState(() {
          _results = dispositivos.values.toList();
        });
      },
      onError: (error) {
        if (!mounted) return;

        setState(() {
          _scanning = false;
          _statusMessage = 'Erro durante a busca BLE: $error';
        });
      },
    );

    try {
      await _bleService.startScan(
        timeout: const Duration(seconds: 8),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _statusMessage = 'Erro ao iniciar busca: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _scanning = false;
        });
      }
    }
  }

  // ============================================================
  // SELEÇÃO DO ESP32
  // ============================================================

  Future<void> _selecionarDispositivo(ScanResult result) async {
    if (_scanning) {
      await _bleService.stopScan();
    }

    if (!mounted) return;

    final device = result.device;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConfiguracaoCultivoPage(
          device: device,
        ),
      ),
    );
  }

  // ============================================================
  // NOME DO DISPOSITIVO
  // ============================================================

  String _nomeDispositivo(ScanResult result) {
    final platformName = result.device.platformName.trim();

    if (platformName.isNotEmpty) {
      return platformName;
    }

    final advertisementName =
        result.advertisementData.advName.trim();

    if (advertisementName.isNotEmpty) {
      return advertisementName;
    }

    return 'Dispositivo sem nome';
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _bleService.stopScan();

    super.dispose();
  }

  // ============================================================
  // INTERFACE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conectar ao ESP32'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Procurar novamente',
            onPressed: _scanning ? null : _iniciarScan,
          ),
        ],
      ),
      body: Column(
        children: [
          // ------------------------------------------------------
          // MENSAGEM DE STATUS
          // ------------------------------------------------------

          if (_statusMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              child: Text(
                _statusMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.red,
                ),
              ),
            ),

          // ------------------------------------------------------
          // BARRA DE PROGRESSO
          // ------------------------------------------------------

          if (_scanning)
            const LinearProgressIndicator(),

          // ------------------------------------------------------
          // LISTA DE DISPOSITIVOS
          // ------------------------------------------------------

          Expanded(
            child: _results.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      final result = _results[index];

                      final nome = _nomeDispositivo(result);

                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.bluetooth),
                        ),
                        title: Text(nome),
                        subtitle: Text(
                          result.device.remoteId.str,
                        ),
                        trailing: Text(
                          '${result.rssi} dBm',
                        ),
                        onTap: () =>
                            _selecionarDispositivo(result),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ESTADO VAZIO
  // ============================================================

  Widget _buildEmptyState() {
    if (_scanning) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bluetooth_searching,
                size: 64,
              ),
              SizedBox(height: 16),
              Text(
                'Procurando ESP32_Irrigacao...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Mantenha o ESP32 ligado e próximo ao celular.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.bluetooth_disabled,
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'Nenhum dispositivo encontrado.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Verifique se o ESP32 está ligado e anunciando '
              'o serviço BLE.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _iniciarScan,
              icon: const Icon(Icons.refresh),
              label: const Text('Procurar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}