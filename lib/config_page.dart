import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'home_page.dart';
import 'services/irrigacao_ble_controller.dart';
import 'models/configuracao_cultivo.dart';


class ConfigPage extends StatefulWidget {
  final BluetoothDevice device;
  const ConfigPage({
    super.key,
    required this.device,
  });
  @override
  State<ConfigPage> createState() =>
      _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  Cultura _cultura = Cultura.milho;
  TipoSolo _solo = TipoSolo.franco;
  DateTime _dataPlantio = DateTime.now();
  bool _carregando = false;
  Future<void> _selecionarData() async {
    final data = await showDatePicker(
      context: context,
      initialDate: _dataPlantio,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale:
          const Locale('pt','BR'),
    );
    if(data != null){
      setState(() {
        _dataPlantio = data;
      });
    }
  }
  Future<void> _continuar() async {
    final configuracao =
        ConfiguracaoCultivo(
          cultura: _cultura,
          solo: _solo,
          dataPlantio: _dataPlantio,
        );
    setState(() {
      _carregando = true;
    });
    try{
      final controller =
          IrrigacaoBleController(
            device: widget.device,
            configuracao:
                configuracao,
          );
      await controller.connectAndListen();
      if(!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              HomePage(
                controller:
                    controller,
              ),
        ),
      );
    }catch(e){
      setState(() {
        _carregando = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(
            SnackBar(
              content:
                  Text(
                    "Erro ao conectar: $e",
                  ),
            ),
          );
    }
  }
  String _formatarData(DateTime data){
    return
        "${data.day.toString().padLeft(2,'0')}/"
        "${data.month.toString().padLeft(2,'0')}/"
        "${data.year}";

  }
  @override
  Widget build(BuildContext context){
    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
              "Configuração da Irrigação",
            ),
      ),
      body:_carregando?
          const Center(
            child:
                CircularProgressIndicator(),
          )
          :
          Padding(
            padding:
                const EdgeInsets.all(20),
            child:
                ListView(
                  children:[
                    const Text(
                      "Cultivo",
                      style:
                          TextStyle(
                            fontSize:18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                    ),
                    const SizedBox(
                        height:8),
                    DropdownButtonFormField<Cultura>(
                      value:_cultura,
                      decoration:
                          const InputDecoration(
                            border:
                                OutlineInputBorder(),
                          ),
                      items:
                      const [
                        DropdownMenuItem(
                          value:
                              Cultura.milho,
                          child:
                              Text("Milho"),
                        ),
                        DropdownMenuItem(
                          value:
                              Cultura.soja,
                          child:
                              Text("Soja"),
                        ),
                      ],
                      onChanged:(valor){
                        if(valor==null)
                          return;
                        setState((){
                          _cultura =
                              valor;
                        });
                      },
                    ),
                    const SizedBox(height:24),
                    const Text(
                      "Tipo de Solo",
                      style:
                          TextStyle(
                            fontSize:18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height:8),
                    DropdownButtonFormField<TipoSolo>(
                      value:_solo,
                      decoration:
                          const InputDecoration(
                            border:
                                OutlineInputBorder(),
                          ),
                      items:
                      const [
                        DropdownMenuItem(
                          value:
                              TipoSolo.arenoso,
                          child:
                              Text("Arenoso"),
                        ),
                        DropdownMenuItem(
                          value:
                              TipoSolo.franco,
                          child:
                              Text("Franco"),
                        ),
                        DropdownMenuItem(
                          value:
                              TipoSolo.argiloso,
                          child:
                              Text("Argiloso"),
                        ),
                      ],
                      onChanged:(valor){
                        if(valor==null)
                          return;
                        setState((){
                          _solo =
                              valor;
                        });
                      },
                    ),
                    const SizedBox(height:24),
                    const Text(
                      "Data do Plantio",
                      style:
                          TextStyle(
                            fontSize:18,
                            fontWeight:
                                FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height:8),
                    OutlinedButton.icon(
                      icon:
                          const Icon(
                            Icons.calendar_month,
                          ),
                      label:
                          Text(
                            _formatarData(
                              _dataPlantio,
                            ),
                          ),
                      onPressed:
                          _selecionarData,
                    ),
                    const SizedBox(height:50),
                    SizedBox(
                      height:55,
                      child:
                          ElevatedButton(
                            onPressed:
                                _continuar,
                            child:
                                const Text(
                                  "CONECTAR E INICIAR",
                                  style:
                                      TextStyle(
                                        fontSize:18,
                                      ),
                                ),
                          ),
                    ),
                  ],
                ),
          ),
    );
  }
}