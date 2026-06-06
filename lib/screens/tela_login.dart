import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/banco_dados.dart';
import '../services/servico_sessao.dart';
import 'tela_caixa.dart';
import 'tela_ponto.dart';

/// Tela de login.
///
/// Fluxo:
///   1) Mostra grade de usuários ativos (avatar com iniciais + nome).
///   2) Toca em um → vai pro numpad de 4 dígitos.
///   3) Após digitar 4 dígitos (sem precisar apertar enter), o sistema valida.
///      Se a senha bate, aparecem dois botões — "Caixa" e "Bater Ponto" —
///      filtrados pelas permissões daquele usuário.
///   4) Se a senha não bate, mostra erro e limpa os dígitos.
///
/// Se não existe nenhum usuário ainda (primeira vez), o main.dart já criou
/// um admin padrão (nome "Admin", senha "0000") antes de chegar aqui.
class TelaLogin extends StatefulWidget {
  const TelaLogin({super.key});

  @override
  State<TelaLogin> createState() => _TelaLoginState();
}

class _TelaLoginState extends State<TelaLogin> {
  List<Usuario> _usuarios = [];
  bool _carregando = true;
  Usuario? _selecionado;
  String _senhaDigitada = '';
  String? _erro;
  bool _autenticado = false;

  @override
  void initState() {
    super.initState();
    _carregarUsuarios();
    // Importante: garante que ao voltar pra tela de login, a sessão esteja limpa.
    ServicoSessao().logout();
  }

  Future<void> _carregarUsuarios() async {
    final usuarios = await BancoDados.carregarUsuarios();
    if (!mounted) return;
    setState(() {
      _usuarios = usuarios;
      _carregando = false;
    });
  }

  void _selecionarUsuario(Usuario u) {
    setState(() {
      _selecionado = u;
      _senhaDigitada = '';
      _erro = null;
      _autenticado = false;
    });
  }

  void _voltarParaListaUsuarios() {
    setState(() {
      _selecionado = null;
      _senhaDigitada = '';
      _erro = null;
      _autenticado = false;
    });
  }

  Future<void> _digitar(String digito) async {
    if (_autenticado) return; // já validou, ignora cliques extras
    if (_senhaDigitada.length >= 4) return;

    setState(() {
      _senhaDigitada += digito;
      _erro = null;
    });

    if (_senhaDigitada.length == 4) {
      await _autenticar();
    }
  }

  void _apagar() {
    if (_autenticado) return;
    if (_senhaDigitada.isEmpty) return;
    setState(() {
      _senhaDigitada = _senhaDigitada.substring(0, _senhaDigitada.length - 1);
      _erro = null;
    });
  }

  Future<void> _autenticar() async {
    final autenticado =
        await BancoDados.autenticar(_selecionado!.id!, _senhaDigitada);
    if (!mounted) return;
    if (autenticado == null) {
      setState(() {
        _erro = 'Senha incorreta';
        _senhaDigitada = '';
        _autenticado = false;
      });
      return;
    }
    ServicoSessao().login(autenticado);
    setState(() {
      _autenticado = true;
      _selecionado = autenticado;
    });
  }

  Future<void> _entrarCaixa() async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TelaCaixa()),
    );
  }

  Future<void> _baterPonto() async {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TelaPonto()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Padaria POS'),
        leading: _selecionado != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _voltarParaListaUsuarios,
              )
            : null,
      ),
      body: _selecionado == null ? _listaUsuarios() : _telaSenha(),
    );
  }

  // ── Estado 1: lista de usuários ────────────────────────────────

  Widget _listaUsuarios() {
    if (_usuarios.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nenhum usuário cadastrado.\nReabra o app — o admin padrão será criado.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Toque no seu nome',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                childAspectRatio: 0.95,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _usuarios.length,
              itemBuilder: (context, index) {
                final u = _usuarios[index];
                return InkWell(
                  onTap: () => _selecionarUsuario(u),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.brown.shade200),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 32,
                          backgroundColor: _corNivel(u.nivel),
                          child: Text(
                            u.iniciais,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          u.nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _rotuloCurto(u.nivel),
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _corNivel(NivelUsuario nivel) {
    switch (nivel) {
      case NivelUsuario.admin:
        return const Color(0xFF5D3A1A);
      case NivelUsuario.operador:
        return Colors.brown.shade400;
      case NivelUsuario.funcionario:
        return Colors.grey.shade600;
    }
  }

  String _rotuloCurto(NivelUsuario nivel) {
    switch (nivel) {
      case NivelUsuario.admin:
        return 'Admin';
      case NivelUsuario.operador:
        return 'Operador';
      case NivelUsuario.funcionario:
        return 'Funcionário';
    }
  }

  // ── Estado 2: tela de senha + numpad ───────────────────────────

  Widget _telaSenha() {
    final u = _selecionado!;
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 36,
            backgroundColor: _corNivel(u.nivel),
            child: Text(
              u.iniciais,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(u.nome,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          Text(_rotuloCurto(u.nivel),
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          // 4 bolinhas mostrando progresso da senha
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final preenchido = i < _senhaDigitada.length;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: preenchido
                      ? const Color(0xFF5D3A1A)
                      : Colors.transparent,
                  border: Border.all(
                    color: Colors.brown.shade400,
                    width: 2,
                  ),
                ),
              );
            }),
          ),
          if (_erro != null) ...[
            const SizedBox(height: 12),
            Text(_erro!,
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 16),
          // Numpad
          if (!_autenticado) ...[
            Expanded(child: _numpad()),
          ] else ...[
            const SizedBox(height: 12),
            Expanded(child: _botoesAcao()),
          ],
        ],
      ),
    );
  }

  Widget _numpad() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: GridView.count(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.4,
          children: [
            for (var n = 1; n <= 9; n++) _botaoNumero('$n'),
            _botaoApagar(),
            _botaoNumero('0'),
            const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  Widget _botaoNumero(String n) {
    return ElevatedButton(
      onPressed: () => _digitar(n),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF5D3A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        n,
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _botaoApagar() {
    return ElevatedButton(
      onPressed: _apagar,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.brown.shade50,
        foregroundColor: const Color(0xFF5D3A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Icon(Icons.backspace_outlined, size: 26),
    );
  }

  // ── Estado 3: autenticado, mostrar botões de ação ──────────────

  Widget _botoesAcao() {
    final sessao = ServicoSessao();
    final podeBater = sessao.podeBaterPonto;
    final podeCaixa = sessao.podeAcessarCaixa;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 48),
          const SizedBox(height: 8),
          const Text('Senha confirmada',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          if (podeCaixa)
            SizedBox(
              width: double.infinity,
              height: 64,
              child: FilledButton.icon(
                onPressed: _entrarCaixa,
                icon: const Icon(Icons.point_of_sale, size: 28),
                label: const Text(
                  'CAIXA',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          if (podeCaixa) const SizedBox(height: 12),
          if (podeBater)
            SizedBox(
              width: double.infinity,
              height: 64,
              child: OutlinedButton.icon(
                onPressed: _baterPonto,
                icon: const Icon(Icons.access_time, size: 28),
                label: const Text(
                  'BATER PONTO',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          if (!podeCaixa && !podeBater)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Este usuário não tem permissões configuradas.',
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
