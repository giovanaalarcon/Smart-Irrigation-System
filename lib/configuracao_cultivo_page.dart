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
  State<ConfiguracaoCultivoPage> createState() => _ConfiguracaoCultivoPageState();
}

class _ConfiguracaoCultivoPageState extends State<ConfiguracaoCultivoPage> {
  Cultura _culturaSelecionada = Cultura.milho;
  TipoSolo _soloSelecionado = TipoSolo.franco;
  DateTime? _dataPlantio;
  bool _conectando = false;
  Future<void> _selecionarData() async {
    final hoje = DateTime.now();
    final data = await showDatePicker(
      context: context,
      initialDate: hoje,
      firstDate: DateTime(hoje.year - 2,),
      lastDate: hoje,
    );
    if(data != null){
      setState((){
        _dataPlantio = data;
      });
    }
  }
  Future<void> _iniciarIrrigacao() async {
    if(_dataPlantio == null){
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione a data de plantio.',),),);
      return;
    }
    setState((){_conectando = true;});
    try {
      final configuracao = ConfiguracaoCultivo(cultura: _culturaSelecionada, solo: _soloSelecionado, dataPlantio: _dataPlantio!,);
      final controller =
          IrrigacaoBleController(
            device:widget.device,
            configuracao:configuracao,
          );
      await controller.connectAndListen();
      if(!mounted)
        return;
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
    }
    catch(e){
      setState((){
        _conectando = false;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(
            SnackBar(
              content:
                  Text(
                    'Erro ao conectar: $e',
                  ),
            ),
          );
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text(
              'Configurar Cultivo',
            ),
      ),
      body:
      _conectando
      ? const Center(
          child:
              CircularProgressIndicator(),
        )
      : Padding(
          padding:
              const EdgeInsets.all(20),
          child:
          ListView(
            children:[
              const Text('Escolha a cultura:',
                style:
                    TextStyle(
                      fontSize:18,
                      fontWeight:FontWeight.bold,
                    ),
              ),
              DropdownButtonFormField<Cultura>(
                value:_culturaSelecionada,
                items:
                    Cultura.values
                        .map(
                          (cultura)=>
                              DropdownMenuItem(
                                value:cultura,
                                child:
                                Text(
                                  _nomeCultura(
                                    cultura,
                                  ),
                                ),
                              ),
                        )
                        .toList(),
                onChanged:(value){
                      if(value != null){
                        setState((){
                          _culturaSelecionada =value;
                        });
                      }
                    },
              ),
              const SizedBox(height:25),
              const Text('Escolha o tipo de solo:',
                style:
                    TextStyle(
                      fontSize:18,
                      fontWeight:FontWeight.bold,
                    ),
              ),
              DropdownButtonFormField<TipoSolo>(
                value:_soloSelecionado,
                items:TipoSolo.values
                    .map((solo)=>
                      DropdownMenuItem(
                        value:solo,
                        child:Text(
                          _nomeSolo(solo,),
                        ),
                      ),
                    )
                    .toList(),
                onChanged:
                    (value){
                      if(value != null){
                        setState((){
                          _soloSelecionado =value;
                        });
                      }
                    },
              ),
              const SizedBox(height:25),
              const Text(
                'Data de plantio:',
                style:TextStyle(
                  fontSize:18,
                  fontWeight:FontWeight.bold,
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _dataPlantio == null
                  ?
                  'Nenhuma data selecionada'
                  :
                  '${_dataPlantio!.day}/'
                  '${_dataPlantio!.month}/'
                  '${_dataPlantio!.year}',
                ),
                trailing:const Icon(Icons.calendar_month,),
                onTap:_selecionarData,
              ),
              const SizedBox(height:40),
              FilledButton.icon(
                icon:const Icon(Icons.water_drop,),
                label:const Text('Iniciar Irrigação',),
                onPressed:_iniciarIrrigacao,
              ),
            ],
          ),
        ),
    );
  }
  String _nomeCultura(Cultura cultura){
    switch(cultura){
      case Cultura.milho:
        return 'Milho';
      case Cultura.soja:
        return 'Soja';
    }
  }
  String _nomeSolo(TipoSolo solo){
    switch(solo){
      case TipoSolo.arenoso:
        return 'Arenoso';
      case TipoSolo.franco:
        return 'Franco';
      case TipoSolo.argiloso:
        return 'Argiloso';

    }
  }
}



