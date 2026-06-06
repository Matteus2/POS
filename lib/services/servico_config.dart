import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Persiste ConfiguracaoLoja em shared_preferences.
///
/// Singleton — uma instância única que mantém a config carregada em memória,
/// pra evitar I/O em todo build da tela. Funciona como cache write-through:
/// `salvar()` atualiza memória e disco juntos.
class ServicoConfig {
  static final ServicoConfig _instance = ServicoConfig._interno();
  factory ServicoConfig() => _instance;
  ServicoConfig._interno();

  // Chaves
  static const _kNomeLoja = 'config.nomeLoja';
  static const _kEndereco = 'config.endereco';
  static const _kImpressoraMAC = 'config.impressoraMAC';
  static const _kImpressoraNome = 'config.impressoraNome';
  static const _kImpressaoAtiva = 'config.impressaoAtiva';
  static const _kLarguraColunas = 'config.larguraColunas';
  static const _kMensagemRodape = 'config.mensagemRodape';

  ConfiguracaoLoja _config = ConfiguracaoLoja();
  bool _carregada = false;

  ConfiguracaoLoja get config => _config;

  /// Carrega da prefs. Chamado em main() antes de runApp().
  Future<ConfiguracaoLoja> carregar() async {
    if (_carregada) return _config;
    final prefs = await SharedPreferences.getInstance();

    _config = ConfiguracaoLoja(
      nomeLoja: prefs.getString(_kNomeLoja) ?? 'PADARIA',
      endereco: prefs.getString(_kEndereco) ?? 'Ribeirão Preto - SP',
      impressoraEnderecoMAC: prefs.getString(_kImpressoraMAC),
      impressoraNome: prefs.getString(_kImpressoraNome),
      impressaoAtiva: prefs.getBool(_kImpressaoAtiva) ?? false,
      larguraColunas: prefs.getInt(_kLarguraColunas) ?? 32,
      mensagemRodape: prefs.getString(_kMensagemRodape) ?? 'Obrigado pela preferência!',
    );
    _carregada = true;
    return _config;
  }

  /// Salva no disco. Sempre chama depois de mexer em _config.
  Future<void> salvar(ConfiguracaoLoja novo) async {
    _config = novo;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNomeLoja, novo.nomeLoja);
    await prefs.setString(_kEndereco, novo.endereco);
    if (novo.impressoraEnderecoMAC != null) {
      await prefs.setString(_kImpressoraMAC, novo.impressoraEnderecoMAC!);
    } else {
      await prefs.remove(_kImpressoraMAC);
    }
    if (novo.impressoraNome != null) {
      await prefs.setString(_kImpressoraNome, novo.impressoraNome!);
    } else {
      await prefs.remove(_kImpressoraNome);
    }
    await prefs.setBool(_kImpressaoAtiva, novo.impressaoAtiva);
    await prefs.setInt(_kLarguraColunas, novo.larguraColunas);
    await prefs.setString(_kMensagemRodape, novo.mensagemRodape);
  }
}
