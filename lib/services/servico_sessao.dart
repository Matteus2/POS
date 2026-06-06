import '../models/models.dart';

/// Mantém o usuário logado da sessão atual.
///
/// É o "crachá" que circula pelo aplicativo: cada tela consulta `usuario`
/// e os getters de permissão pra decidir o que mostrar. Quando o usuário
/// faz logout, o crachá é devolvido e o app volta pra tela de login.
///
/// Singleton — uma única "pessoa" usando o tablet por vez. PDV não suporta
/// multi-usuário simultâneo, então isso é a modelagem correta.
class ServicoSessao {
  static final ServicoSessao _instance = ServicoSessao._interno();
  factory ServicoSessao() => _instance;
  ServicoSessao._interno();

  Usuario? _usuario;
  Usuario? get usuario => _usuario;

  bool get logado => _usuario != null;

  /// Define o usuário ativo. Chamado pela tela_login após autenticar.
  void login(Usuario usuario) {
    _usuario = usuario;
  }

  /// Limpa a sessão. Chamado pelo botão de logout na tela_caixa.
  void logout() {
    _usuario = null;
  }

  NivelUsuario? get nivel => _usuario?.nivel;

  // ── Permissões (hierárquicas) ──────────────────────────────────
  // Funcionário < Operador < Admin. Quem está em cima, herda tudo
  // o que está embaixo. Igual níveis de cartão de acesso num prédio:
  // o cartão "diretoria" abre todas as portas que o "estagiário" abre.

  /// Todos os usuários logados podem bater ponto.
  bool get podeBaterPonto => logado;

  /// Operador e admin podem usar o caixa, vender, ver histórico,
  /// fazer sangria/suprimento, registrar perdas/produção.
  bool get podeAcessarCaixa =>
      nivel == NivelUsuario.operador || nivel == NivelUsuario.admin;

  /// Só admin edita catálogo de produtos.
  bool get podeEditarProdutos => nivel == NivelUsuario.admin;

  /// Só admin gerencia usuários.
  bool get podeGerenciarUsuarios => nivel == NivelUsuario.admin;

  /// Só admin edita configurações da loja (nome, endereço, impressora).
  bool get podeConfigurarLoja => nivel == NivelUsuario.admin;
}
