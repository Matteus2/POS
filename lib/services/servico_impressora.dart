import 'dart:async';
import '../models/models.dart';

/// STUB temporário do serviço de impressora.
/// Versão completa (com Bluetooth real) será habilitada quando
/// testarmos com impressora física.
class ServicoImpressora {
  static final ServicoImpressora _instance = ServicoImpressora._interno();
  factory ServicoImpressora() => _instance;
  ServicoImpressora._interno();

  final StreamController<EstadoImpressora> _estadoController =
      StreamController<EstadoImpressora>.broadcast();
  Stream<EstadoImpressora> get estadoStream => _estadoController.stream;

  final EstadoImpressora _estado = EstadoImpressora.desconectada;
  EstadoImpressora get estado => _estado;
  dynamic get dispositivoAtual => null;

  Future<bool> solicitarPermissoes() async => true;
  Future<bool> bluetoothLigado() async => false;
  Future<List> buscarPareados() async => [];
  Future<List> buscarImpressoras() async => [];
  Future<bool> conectar(dynamic device) async => false;
  Future<void> desconectar() async {}
  Future<bool> reconectarUltima() async => false;
  Future<bool> imprimirCupom(
          {required Venda venda, required ConfiguracaoLoja config}) async =>
      true;
  Future<bool> imprimirTeste() async => true;
  void dispose() => _estadoController.close();
}

enum EstadoImpressora {
  desconectada,
  conectando,
  conectada,
  imprimindo,
  erro,
}
