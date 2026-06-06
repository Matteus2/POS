import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/banco_dados.dart';
import '../services/servico_sessao.dart';
import 'tela_login.dart';

/// Tela de ponto.
///
/// Layout responsivo:
///   - Esquerda (1/3 em tablet, topo em phone): identidade do usuário,
///     dropdown da função do dia, botão grande de bater ponto, logout.
///   - Direita (2/3 em tablet, abaixo em phone): tabela com os turnos
///     da SEMANA ATUAL (segunda 00:00 → próxima segunda 00:00).
///
/// Dados anteriores à semana atual não aparecem aqui (são acessíveis
/// só pelo admin via tela_pontos_admin).
class TelaPonto extends StatefulWidget {
  const TelaPonto({super.key});

  @override
  State<TelaPonto> createState() => _TelaPontoState();
}

class _TelaPontoState extends State<TelaPonto> {
  final _sessao = ServicoSessao();
  final _formatoHora = DateFormat('HH:mm');
  final _formatoDia = DateFormat('EEE dd/MM', 'pt_BR');

  RegistroPonto? _ultimo;
  List<Turno> _turnos = [];
  int _minutosSemana = 0;
  bool _carregando = true;
  bool _registrando = false;
  String _funcaoSelecionada = FuncoesDisponiveis.caixa;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final u = _sessao.usuario;
    if (u == null) return;

    final ultimo = await BancoDados.ultimoPontoDoUsuario(u.id!);
    final turnos = await BancoDados.carregarTurnosDaSemana(u.id!);
    final minutos = await BancoDados.minutosTrabalhadosNaSemana(u.id!);

    if (!mounted) return;

    // Função inicial: se tem turno em aberto, herda a função dele.
    // Senão, primeira função permitida ou Caixa.
    String funcaoInicial;
    if (ultimo != null && ultimo.tipo == 'entrada') {
      funcaoInicial = ultimo.funcao;
    } else if (u.funcoesPermitidas.isNotEmpty) {
      funcaoInicial = u.funcoesPermitidas.first;
    } else {
      funcaoInicial = FuncoesDisponiveis.caixa;
    }

    setState(() {
      _ultimo = ultimo;
      _turnos = turnos;
      _minutosSemana = minutos;
      _funcaoSelecionada = funcaoInicial;
      _carregando = false;
    });
  }

  Future<void> _bater() async {
    if (_registrando) return;
    final u = _sessao.usuario;
    if (u == null) return;
    setState(() => _registrando = true);

    try {
      final novo = await BancoDados.baterPonto(u, funcao: _funcaoSelecionada);
      if (!mounted) return;

      final msg = novo.ehEntrada
          ? 'Entrada às ${_formatoHora.format(novo.data)} como ${novo.funcao}'
          : 'Saída às ${_formatoHora.format(novo.data)} (turno de ${novo.funcao})';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: novo.ehEntrada ? Colors.green : Colors.orange,
        ),
      );
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao bater ponto: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _registrando = false);
    }
  }

  Future<void> _sair() async {
    _sessao.logout();
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TelaLogin()),
    );
  }

  String _formatarHoras(int minutos) {
    final h = minutos ~/ 60;
    final m = minutos % 60;
    return '${h}h ${m.toString().padLeft(2, '0')}min';
  }

  @override
  Widget build(BuildContext context) {
    final u = _sessao.usuario;
    if (u == null) {
      return const Scaffold(body: Center(child: Text('Sessão expirada')));
    }
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ponto'),
        actions: [
          IconButton(
            tooltip: 'Sair',
            icon: const Icon(Icons.logout),
            onPressed: _sair,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final largo = constraints.maxWidth > 700;
            if (largo) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 1, child: _painelEsquerda(u)),
                  const VerticalDivider(width: 1),
                  Expanded(flex: 2, child: _painelDireita()),
                ],
              );
            }
            return SingleChildScrollView(
              child: Column(
                children: [
                  _painelEsquerda(u),
                  const Divider(height: 1),
                  SizedBox(
                    height: 400,
                    child: _painelDireita(),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ── Painel esquerdo: identidade + função + botão ───────────────

  Widget _painelEsquerda(Usuario u) {
    final temTurnoAberto = _ultimo != null && _ultimo!.tipo == 'entrada';
    final proximaAcao = temTurnoAberto ? 'SAÍDA' : 'ENTRADA';
    final corBotao = temTurnoAberto ? Colors.orange : Colors.green;
    final iconeBotao = temTurnoAberto ? Icons.logout : Icons.login;

    final statusAtual = temTurnoAberto
        ? 'Trabalhando desde ${_formatoHora.format(_ultimo!.data)} como ${_ultimo!.funcao}'
        : (_ultimo == null
            ? 'Sem registro hoje'
            : 'Última saída às ${_formatoHora.format(_ultimo!.data)}');

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Avatar + nome
          Center(
            child: CircleAvatar(
              radius: 44,
              backgroundColor: const Color(0xFF5D3A1A),
              child: Text(
                u.iniciais,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              u.nome,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),

          // Card de função do dia
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.brown.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.brown.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Função do dia',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                if (temTurnoAberto)
                  // Em turno aberto não dá pra trocar de função no meio.
                  // A função fica travada na que foi escolhida na entrada.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline,
                            color: Colors.grey, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          _ultimo!.funcao,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        const Text(
                          'em andamento',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: u.funcoesPermitidas
                            .contains(_funcaoSelecionada)
                        ? _funcaoSelecionada
                        : u.funcoesPermitidas.first,
                    items: u.funcoesPermitidas
                        .map((f) =>
                            DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _funcaoSelecionada = v);
                      }
                    },
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Status
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: temTurnoAberto
                  ? Colors.green.shade50
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  temTurnoAberto
                      ? Icons.access_time_filled
                      : Icons.access_time,
                  color: temTurnoAberto ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    statusAtual,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Botão grande de bater ponto
          SizedBox(
            height: 90,
            child: FilledButton(
              onPressed: _registrando ? null : _bater,
              style: FilledButton.styleFrom(backgroundColor: corBotao),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(iconeBotao, size: 32, color: Colors.white),
                  const SizedBox(height: 4),
                  Text(
                    'REGISTRAR $proximaAcao',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Total da semana
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total desta semana',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  _formatarHoras(_minutosSemana),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5D3A1A),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Painel direito: tabela da semana ──────────────────────────

  Widget _painelDireita() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Esta semana',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Apenas turnos desta semana são exibidos',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          // Cabeçalho da tabela
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF5D3A1A),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Função',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    'Dia',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Entrada',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Saída',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Corpo da tabela
          Expanded(
            child: _turnos.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'Sem registros nesta semana',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: _turnos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 2),
                    itemBuilder: (context, i) => _linhaTurno(_turnos[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _linhaTurno(Turno t) {
    final saida = t.fim;
    final auto = t.fechadoAutomaticamente;
    final aberto = t.aberto;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              t.funcao,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(_formatoDia.format(t.inicio)),
          ),
          Expanded(
            flex: 2,
            child: Text(_formatoHora.format(t.inicio)),
          ),
          Expanded(
            flex: 2,
            child: aberto
                ? const Row(
                    children: [
                      Icon(Icons.circle,
                          color: Colors.green, size: 10),
                      SizedBox(width: 4),
                      Text('em curso',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontStyle: FontStyle.italic)),
                    ],
                  )
                : Row(
                    children: [
                      Text(_formatoHora.format(saida!)),
                      if (auto) ...[
                        const SizedBox(width: 4),
                        const Tooltip(
                          message: 'Saída automática (4h)',
                          child: Icon(Icons.auto_awesome,
                              size: 12, color: Colors.orange),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
