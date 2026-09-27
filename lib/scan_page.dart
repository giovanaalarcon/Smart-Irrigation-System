import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'configuracao_cultivo_page.dart';
import 'services/ble_connection_service.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({
    super.key,
  });

  @override
  State<ScanPage> createState() =>
      _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  // ============================================================
  // BLE
  // ============================================================

  final BleConnectionService _bleService =
      BleConnectionService();

  // ============================================================
  // DISPOSITIVOS ENCONTRADOS
  // ============================================================

  /// Mantém um único ScanResult por dispositivo.
  ///
  /// A chave é o remoteId.
  final Map<String, ScanResult> _resultadosPorId =
      {};

  List<ScanResult> _results =
      [];

  // ============================================================
  // SUBSCRIPTIONS
  // ============================================================

  StreamSubscription<List<ScanResult>>?
      _scanSubscription;

  StreamSubscription<BluetoothAdapterState>?
      _adapterSubscription;

  StreamSubscription<bool>?
      _scanningSubscription;

  // ============================================================
  // ESTADO DA TELA
  // ============================================================

  bool _scanning =
      false;

  String? _statusMessage;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _configurarStreams();

    _inicializar();
  }

  // ============================================================
  // STREAMS
  // ============================================================

  void _configurarStreams() {
    // ==========================================================
    // RESULTADOS DO SCAN
    // ==========================================================

    _scanSubscription =
        _bleService.scanResults.listen(
      _onScanResults,
      onError: (error) {
        if (!mounted) {
          return;
        }

        setState(() {
          _statusMessage =
              'Erro durante a busca BLE: $error';
        });
      },
    );

    // ==========================================================
    // ESTADO DO BLUETOOTH
    // ==========================================================

    _adapterSubscription =
        _bleService.adapterState.listen(
      _onAdapterState,
    );

    // ==========================================================
    // ESTADO DO SCAN
    // ==========================================================

    _scanningSubscription =
        _bleService.scanningState.listen(
      (scanning) {
        if (!mounted) {
          return;
        }

        setState(() {
          _scanning =
              scanning;
        });
      },
    );
  }

  // ============================================================
  // INICIALIZAÇÃO
  // ============================================================

  Future<void> _inicializar() async {
    try {
      // ========================================================
      // PERMISSÕES
      // ========================================================

      final permissao =
          await _bleService
              .requestPermissions();

      if (!mounted) {
        return;
      }

      if (!permissao) {
        setState(() {
          _statusMessage =
              'Permissões de Bluetooth necessárias não foram concedidas. '
              'Habilite-as nas configurações do aplicativo.';
        });

        return;
      }

      // ========================================================
      // BLUETOOTH
      // ========================================================

      final bluetoothLigado =
          await _bleService
              .isBluetoothOn();

      if (!mounted) {
        return;
      }

      if (!bluetoothLigado) {
        setState(() {
          _statusMessage =
              'Bluetooth desligado. Tentando ativar...';
        });

        await _bleService
            .turnOnBluetooth();

        if (!mounted) {
          return;
        }

        final ligadoAgora =
            await _bleService
                .isBluetoothOn();

        if (!ligadoAgora) {
          setState(() {
            _statusMessage =
                'O Bluetooth está desligado. '
                'Ative-o para continuar.';
          });

          return;
        }
      }

      // ========================================================
      // SCAN
      // ========================================================

      await _iniciarScan();
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage =
            'Erro ao inicializar Bluetooth: $e';
      });
    }
  }

  // ============================================================
  // ESTADO DO ADAPTADOR
  // ============================================================

  void _onAdapterState(
    BluetoothAdapterState state,
  ) {
    if (!mounted) {
      return;
    }

    if (state ==
        BluetoothAdapterState.off) {
      unawaited(
        _bleService.stopScan(),
      );

      setState(() {
        _statusMessage =
            'O Bluetooth foi desligado. '
            'Ative-o para procurar o ESP32.';
      });
    }
  }

  // ============================================================
  // RESULTADOS DO SCAN
  // ============================================================

  void _onScanResults(
    List<ScanResult> results,
  ) {
    if (!mounted) {
      return;
    }

    for (final result in results) {
      final id =
          _bleService.getDeviceId(
        result,
      );

      final existente =
          _resultadosPorId[id];

      // Mantém a leitura de RSSI mais forte recebida
      // para cada dispositivo.
      if (existente == null ||
          result.rssi >
              existente.rssi) {
        _resultadosPorId[id] =
            result;
      }
    }

    final atualizados =
        _resultadosPorId.values
            .toList();

    // Dispositivos mais próximos aparecem primeiro.
    atualizados.sort(
      (a, b) =>
          b.rssi.compareTo(
        a.rssi,
      ),
    );

    setState(() {
      _results =
          atualizados;
    });
  }

  // ============================================================
  // INICIAR SCAN
  // ============================================================

  Future<void> _iniciarScan() async {
    if (_scanning) {
      return;
    }

    try {
      // ========================================================
      // CONFIRMA BLUETOOTH
      // ========================================================

      final bluetoothLigado =
          await _bleService
              .isBluetoothOn();

      if (!mounted) {
        return;
      }

      if (!bluetoothLigado) {
        setState(() {
          _statusMessage =
              'O Bluetooth está desligado. '
              'Ative-o antes de iniciar uma nova busca.';
        });

        return;
      }

      // ========================================================
      // LIMPA RESULTADOS ANTERIORES
      // ========================================================

      _resultadosPorId.clear();

      setState(() {
        _results =
            [];

        _statusMessage =
            null;
      });

      // ========================================================
      // SCAN
      // ========================================================

      await _bleService.startScan(
        timeout:
            const Duration(
          seconds: 8,
        ),
      );

      // Não alteramos _scanning aqui.
      //
      // O valor é controlado pelo stream
      // BleConnectionService.scanningState.
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _statusMessage =
            'Erro ao iniciar busca BLE: $e';
      });
    }
  }

  // ============================================================
  // SELEÇÃO DO ESP32
  // ============================================================

  Future<void> _selecionarDispositivo(
    ScanResult result,
  ) async {
    // Sempre interrompe o scan antes da conexão.
    //
    // Alguns aparelhos apresentam problemas ao tentar
    // conectar enquanto ainda estão escaneando.
    await _bleService.stopScan();

    if (!mounted) {
      return;
    }

    final device =
        result.device;

    Navigator.of(
      context,
    ).push(
      MaterialPageRoute(
        builder: (_) =>
            ConfiguracaoCultivoPage(
          device:
              device,
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    unawaited(
      _scanSubscription?.cancel(),
    );

    unawaited(
      _adapterSubscription?.cancel(),
    );

    unawaited(
      _scanningSubscription?.cancel(),
    );

    unawaited(
      _bleService.stopScan(),
    );

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
          'Conectar ao ESP32',
        ),
        actions: [
          IconButton(
            icon:
                const Icon(
              Icons.refresh,
            ),
            tooltip:
                'Procurar novamente',
            onPressed:
                _scanning
                    ? null
                    : _iniciarScan,
          ),
        ],
      ),

      body: Column(
        children: [
          // ====================================================
          // MENSAGEM DE STATUS
          // ====================================================

          if (_statusMessage != null)
            Container(
              width:
                  double.infinity,
              padding:
                  const EdgeInsets.all(
                12,
              ),
              child:
                  Text(
                _statusMessage!,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  color:
                      Colors.red,
                ),
              ),
            ),

          // ====================================================
          // PROGRESSO
          // ====================================================

          if (_scanning)
            const LinearProgressIndicator(),

          // ====================================================
          // LISTA
          // ====================================================

          Expanded(
            child:
                _results.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount:
                            _results.length,
                        itemBuilder:
                            (
                          context,
                          index,
                        ) {
                          final result =
                              _results[index];

                          final nome =
                              _bleService
                                  .getDeviceName(
                            result,
                          );

                          final id =
                              _bleService
                                  .getDeviceId(
                            result,
                          );

                          return ListTile(
                            leading:
                                const CircleAvatar(
                              child:
                                  Icon(
                                Icons.bluetooth,
                              ),
                            ),

                            title:
                                Text(
                              nome,
                            ),

                            subtitle:
                                Text(
                              id,
                            ),

                            trailing:
                                Text(
                              '${result.rssi} dBm',
                            ),

                            onTap:
                                () =>
                                    _selecionarDispositivo(
                              result,
                            ),
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
        child:
            Padding(
          padding:
              EdgeInsets.all(
            24,
          ),
          child:
              Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Icon(
                Icons.bluetooth_searching,
                size:
                    64,
              ),

              SizedBox(
                height:
                    16,
              ),

              Text(
                'Procurando ESP32_Irrigacao...',
                textAlign:
                    TextAlign.center,
                style:
                    TextStyle(
                  fontSize:
                      16,
                ),
              ),

              SizedBox(
                height:
                    8,
              ),

              Text(
                'Mantenha o ESP32 ligado e próximo ao celular.',
                textAlign:
                    TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child:
          Padding(
        padding:
            const EdgeInsets.all(
          24,
        ),
        child:
            Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.bluetooth_disabled,
              size:
                  64,
            ),

            const SizedBox(
              height:
                  16,
            ),

            const Text(
              'Nenhum dispositivo encontrado.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize:
                    16,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height:
                  8,
            ),

            const Text(
              'Verifique se o ESP32 está ligado e anunciando '
              'o serviço BLE do HydroFlow.',
              textAlign:
                  TextAlign.center,
            ),

            const SizedBox(
              height:
                  20,
            ),

            ElevatedButton.icon(
              onPressed:
                  _iniciarScan,
              icon:
                  const Icon(
                Icons.refresh,
              ),
              label:
                  const Text(
                'Procurar novamente',
              ),
            ),
          ],
        ),
      ),
    );
  }
}