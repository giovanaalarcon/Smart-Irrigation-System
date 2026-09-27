import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'models/configuracao_cultivo.dart';
import 'services/irrigacao_ble_controller.dart';
import 'home_page.dart';

class ConfiguracaoCultivoPage extends StatefulWidget {
  final BluetoothDevice device;

  const ConfiguracaoCultivoPage({
    super.key,
    required this.device,
  });

  @override
  State<ConfiguracaoCultivoPage> createState() =>
      _ConfiguracaoCultivoPageState();
}

class _ConfiguracaoCultivoPageState
    extends State<ConfiguracaoCultivoPage> {
  // ============================================================
  // WEATHERAPI
  // ============================================================

  /// Chave da WeatherAPI utilizada pelo protótipo.
  ///
  /// Substitua pelo valor da sua chave atual.
  static const String _weatherApiKey =
      '7169c46fbf214d5e9b803630262205';

  // ============================================================
  // CONFIGURAÇÃO DO CULTIVO
  // ============================================================

  Cultura _cultura =
      Cultura.milho;

  TipoSolo _solo =
      TipoSolo.franco;

  DateTime _dataPlantio =
      DateTime.now();

  // ============================================================
  // CIDADE
  // ============================================================

  final TextEditingController _cidadeController =
      TextEditingController();

  // ============================================================
  // ESTADO DA PÁGINA
  // ============================================================

  bool _carregando =
      false;

  String? _erro;

  // ============================================================
  // CONFIGURAÇÃO ATUAL
  // ============================================================
  //
  // Centralizamos aqui para não duplicar regras de:
  //
  // - nome da cultura;
  // - nome do solo;
  // - dias de cultivo;
  // - data formatada.
  // ============================================================

  ConfiguracaoCultivo get _configuracaoAtual {
    return ConfiguracaoCultivo(
      cultura: _cultura,
      solo: _solo,
      dataPlantio: _dataPlantio,
    );
  }

  // ============================================================
  // DATA DE PLANTIO
  // ============================================================

  Future<void> _selecionarData() async {
    final data =
        await showDatePicker(
      context: context,
      initialDate:
          _dataPlantio,
      firstDate:
          DateTime(2020),
      lastDate:
          DateTime.now(),
      locale:
          const Locale(
        'pt',
        'BR',
      ),
      helpText:
          'Selecione a data do plantio',
      cancelText:
          'Cancelar',
      confirmText:
          'Confirmar',
    );

    if (data == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _dataPlantio =
          data;

      _erro =
          null;
    });
  }

  // ============================================================
  // CONTINUAR
  // ============================================================

  Future<void> _continuar() async {
    FocusScope.of(
      context,
    ).unfocus();

    final cidade =
        _cidadeController.text.trim();

    // ==========================================================
    // VALIDAÇÃO
    // ==========================================================

    if (cidade.isEmpty) {
      setState(() {
        _erro =
            'Informe a cidade para consultar o clima.';
      });

      return;
    }

    final configuracao =
        _configuracaoAtual;

    setState(() {
      _carregando =
          true;

      _erro =
          null;
    });

    IrrigacaoBleController?
        controller;

    try {
      // ========================================================
      // CONTROLLER
      // ========================================================

      controller =
          IrrigacaoBleController(
        device:
            widget.device,
        configuracao:
            configuracao,
        cidade:
            cidade,
        weatherApiKey:
            _weatherApiKey,
      );

      // ========================================================
      // BLE
      // ========================================================

      await controller
          .connectAndListen();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      // ========================================================
      // HOME
      // ========================================================

      Navigator.of(
        context,
      ).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              HomePage(
            controller:
                controller!,
            configuracao:
                configuracao,
            cidade:
                cidade,
          ),
        ),
      );
    } catch (e) {
      // Caso a conexão falhe depois que o Controller
      // já tenha sido criado, encerramos seus recursos.
      if (controller != null) {
        await controller.dispose();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _carregando =
            false;

        _erro =
            'Não foi possível conectar ao ESP32.';
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            'Erro ao conectar: $e',
          ),
        ),
      );
    }
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
        title: const Text(
          'Configuração da Irrigação',
        ),
      ),
      body: _carregando
          ? _buildCarregando()
          : _buildFormulario(),
    );
  }

  // ============================================================
  // CARREGAMENTO
  // ============================================================

  Widget _buildCarregando() {
    return const Center(
      child: Padding(
        padding:
            EdgeInsets.all(
          24,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            CircularProgressIndicator(),

            SizedBox(
              height: 24,
            ),

            Text(
              'Conectando ao ESP32...',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            SizedBox(
              height: 8,
            ),

            Text(
              'Aguarde enquanto estabelecemos a conexão Bluetooth.',
              textAlign:
                  TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FORMULÁRIO
  // ============================================================

  Widget _buildFormulario() {
    final configuracao =
        _configuracaoAtual;

    return SafeArea(
      child: ListView(
        padding:
            const EdgeInsets.all(
          20,
        ),
        children: [
          // ====================================================
          // DISPOSITIVO
          // ====================================================

          Card(
            child: Padding(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.bluetooth_connected,
                    size: 32,
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ESP32 selecionado',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height: 4,
                        ),

                        Text(
                          widget.device.platformName
                                  .trim()
                                  .isNotEmpty
                              ? widget
                                  .device
                                  .platformName
                                  .trim()
                              : widget
                                  .device
                                  .remoteId
                                  .str,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(
            height: 24,
          ),

          // ====================================================
          // CULTURA
          // ====================================================

          const Text(
            'Cultura',
            style:
                TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          DropdownButtonFormField<Cultura>(
            value:
                _cultura,
            decoration:
                const InputDecoration(
              border:
                  OutlineInputBorder(),
              prefixIcon:
                  Icon(
                Icons.grass,
              ),
            ),
            items:
                const [
              DropdownMenuItem(
                value:
                    Cultura.milho,
                child:
                    Text(
                  'Milho',
                ),
              ),
              DropdownMenuItem(
                value:
                    Cultura.soja,
                child:
                    Text(
                  'Soja',
                ),
              ),
              DropdownMenuItem(
                value:
                    Cultura.trigo,
                child:
                    Text(
                  'Trigo',
                ),
              ),
              DropdownMenuItem(
                value:
                    Cultura.canadeacucar,
                child:
                    Text(
                  'Cana-de-açúcar',
                ),
              ),
              DropdownMenuItem(
                value:
                    Cultura.algodao,
                child:
                    Text(
                  'Algodão',
                ),
              ),
            ],
            onChanged:
                (valor) {
              if (valor ==
                  null) {
                return;
              }

              setState(() {
                _cultura =
                    valor;

                _erro =
                    null;
              });
            },
          ),

          const SizedBox(
            height: 24,
          ),

          // ====================================================
          // SOLO
          // ====================================================

          const Text(
            'Tipo de solo',
            style:
                TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          DropdownButtonFormField<TipoSolo>(
            value:
                _solo,
            decoration:
                const InputDecoration(
              border:
                  OutlineInputBorder(),
              prefixIcon:
                  Icon(
                Icons.terrain,
              ),
            ),
            items:
                const [
              DropdownMenuItem(
                value:
                    TipoSolo.arenoso,
                child:
                    Text(
                  'Arenoso',
                ),
              ),
              DropdownMenuItem(
                value:
                    TipoSolo.franco,
                child:
                    Text(
                  'Franco',
                ),
              ),
              DropdownMenuItem(
                value:
                    TipoSolo.argiloso,
                child:
                    Text(
                  'Argiloso',
                ),
              ),
            ],
            onChanged:
                (valor) {
              if (valor ==
                  null) {
                return;
              }

              setState(() {
                _solo =
                    valor;

                _erro =
                    null;
              });
            },
          ),

          const SizedBox(
            height: 24,
          ),

          // ====================================================
          // DATA DO PLANTIO
          // ====================================================

          const Text(
            'Data do plantio',
            style:
                TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          OutlinedButton.icon(
            icon:
                const Icon(
              Icons.calendar_month,
            ),
            label:
                Text(
              configuracao
                  .dataPlantioFormatada,
              style:
                  const TextStyle(
                fontSize: 16,
              ),
            ),
            onPressed:
                _selecionarData,
          ),

          const SizedBox(
            height: 8,
          ),

          Text(
            'Idade atual do cultivo: '
            '${configuracao.diasCultivo} dias',
            style:
                Theme.of(
              context,
            ).textTheme.bodyMedium,
          ),

          const SizedBox(
            height: 24,
          ),

          // ====================================================
          // CIDADE
          // ====================================================

          const Text(
            'Cidade',
            style:
                TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          TextField(
            controller:
                _cidadeController,
            textCapitalization:
                TextCapitalization.words,
            decoration:
                const InputDecoration(
              border:
                  OutlineInputBorder(),
              prefixIcon:
                  Icon(
                Icons.location_city,
              ),
              hintText:
                  'Ex.: Campinas',
              helperText:
                  'A cidade será usada para consultar a previsão do tempo.',
            ),

            // Atualiza o resumo enquanto o usuário digita.
            onChanged:
                (_) {
              setState(() {
                _erro =
                    null;
              });
            },
          ),

          const SizedBox(
            height: 12,
          ),

          // ====================================================
          // ERRO
          // ====================================================

          if (_erro != null)
            Container(
              margin:
                  const EdgeInsets.only(
                top: 4,
                bottom: 12,
              ),
              padding:
                  const EdgeInsets.all(
                12,
              ),
              decoration:
                  BoxDecoration(
                borderRadius:
                    BorderRadius.circular(
                  8,
                ),
                color:
                    Colors.red.withOpacity(
                  0.08,
                ),
              ),
              child:
                  Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    color:
                        Colors.red,
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Expanded(
                    child:
                        Text(
                      _erro!,
                      style:
                          const TextStyle(
                        color:
                            Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(
            height: 20,
          ),

          // ====================================================
          // RESUMO
          // ====================================================

          Card(
            child:
                Padding(
              padding:
                  const EdgeInsets.all(
                16,
              ),
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Resumo da configuração',
                    style:
                        TextStyle(
                      fontSize:
                          17,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(
                    height:
                        12,
                  ),

                  _ResumoItem(
                    titulo:
                        'Cultura',
                    valor:
                        configuracao.nomeCultura,
                  ),

                  _ResumoItem(
                    titulo:
                        'Solo',
                    valor:
                        configuracao.nomeSolo,
                  ),

                  _ResumoItem(
                    titulo:
                        'Plantio',
                    valor:
                        configuracao.dataPlantioFormatada,
                  ),

                  _ResumoItem(
                    titulo:
                        'Idade',
                    valor:
                        '${configuracao.diasCultivo} dias',
                  ),

                  _ResumoItem(
                    titulo:
                        'Fase',
                    valor:
                        configuracao.faseAtual,
                  ),

                  _ResumoItem(
                    titulo:
                        'Cidade',
                    valor:
                        _cidadeController.text
                                .trim()
                                .isEmpty
                            ? 'Não informada'
                            : _cidadeController.text.trim(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(
            height: 28,
          ),

          // ====================================================
          // BOTÃO
          // ====================================================

          SizedBox(
            height:
                55,
            child:
                ElevatedButton.icon(
              onPressed:
                  _carregando
                      ? null
                      : _continuar,
              icon:
                  const Icon(
                Icons.bluetooth_connected,
              ),
              label:
                  const Text(
                'CONECTAR E INICIAR',
                style:
                    TextStyle(
                  fontSize:
                      17,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 20,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _cidadeController.dispose();

    super.dispose();
  }
}

// ================================================================
// ITEM DO RESUMO
// ================================================================

class _ResumoItem extends StatelessWidget {
  final String titulo;
  final String valor;

  const _ResumoItem({
    required this.titulo,
    required this.valor,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 4,
      ),
      child:
          Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width:
                80,
            child:
                Text(
              titulo,
              style:
                  const TextStyle(
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(
            width: 8,
          ),

          Expanded(
            child:
                Text(
              valor,
            ),
          ),
        ],
      ),
    );
  }
}