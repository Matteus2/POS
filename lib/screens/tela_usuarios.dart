import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/banco_dados.dart';
import '../services/servico_sessao.dart';
import 'tela_pontos_admin.dart';

/// Gestão de usuários. Acessível só pelo admin.
///
/// Permite criar/editar usuários, escolher quais funções (cargos) cada
/// um pode exercer ao bater ponto, e acessar o editor de pontos
/// individual pra corrigir batidas.
class TelaUsuarios extends StatefulWidget {
  const TelaUsuarios({super.key});

  @override
  State<TelaUsuarios> createState() => _TelaUsuariosState();
}

class _TelaUsuariosState extends State<TelaUsuarios> {
  List<Usuario> _usuarios = [];
  bool _carregando = true;
  bool _mostrarInativos = false;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final usuarios =
        await BancoDados.carregarUsuarios(somenteAtivos: !_mostrarInativos);
    if (!mounted) return;
    setState(() {
      _usuarios = usuarios;
      _carregando = false;
    });
  }

  Future<void> _abrirFormulario({Usuario? usuario}) async {
    final nomeController = TextEditingController(text: usuario?.nome ?? '');
    final senhaController = TextEditingController(text: usuario?.senha ?? '');
    var nivel = usuario?.nivel ?? NivelUsuario.funcionario;
    var ativo = usuario?.ativo ?? true;
    final funcoesSelecionadas = <String>{
      ...(usuario?.funcoesPermitidas ?? const [FuncoesDisponiveis.caixa])
    };

    final salvou = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(usuario == null ? 'Novo usuário' : 'Editar usuário'),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: nomeController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nome',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: senhaController,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    decoration: const InputDecoration(
                      labelText: 'Senha (4 dígitos)',
                      border: OutlineInputBorder(),
                      helperText: 'Apenas números',
                    ),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<NivelUsuario>(
                    initialValue: nivel,
                    items: NivelUsuario.values
                        .map((n) => DropdownMenuItem(
                              value: n,
                              child: Text(n.rotulo),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => nivel = v);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Nível de acesso',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Multi-select de funções permitidas
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Funções (cargos) que pode exercer',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'O usuário só vê essas opções no dropdown de "Função do dia" ao bater ponto.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: FuncoesDisponiveis.todas.map((f) {
                      final selecionada = funcoesSelecionadas.contains(f);
                      return FilterChip(
                        label: Text(f),
                        selected: selecionada,
                        onSelected: (v) {
                          setDialogState(() {
                            if (v) {
                              funcoesSelecionadas.add(f);
                            } else if (funcoesSelecionadas.length > 1) {
                              // Não deixa zerar — pelo menos uma função
                              funcoesSelecionadas.remove(f);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (usuario != null) ...[
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ativo'),
                      value: ativo,
                      onChanged: (v) => setDialogState(() => ativo = v),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () async {
                final nome = nomeController.text.trim();
                final senha = senhaController.text.trim();
                if (nome.isEmpty ||
                    senha.length != 4 ||
                    int.tryParse(senha) == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Nome e senha de 4 dígitos numéricos obrigatórios.'),
                    ),
                  );
                  return;
                }
                if (funcoesSelecionadas.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Selecione ao menos uma função permitida.'),
                    ),
                  );
                  return;
                }

                // Trava: não permite desativar/rebaixar o último admin
                if (usuario != null &&
                    usuario.nivel == NivelUsuario.admin &&
                    (!ativo || nivel != NivelUsuario.admin)) {
                  final qtdAdmins = await BancoDados.contarAdminsAtivos();
                  if (qtdAdmins <= 1) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Não dá pra desativar o último administrador ativo.'),
                      ),
                    );
                    return;
                  }
                }

                final novo = Usuario(
                  id: usuario?.id,
                  nome: nome,
                  senha: senha,
                  nivel: nivel,
                  ativo: ativo,
                  funcoesPermitidas: funcoesSelecionadas.toList()..sort(),
                );
                if (usuario == null) {
                  await BancoDados.inserirUsuario(novo);
                } else {
                  await BancoDados.atualizarUsuario(novo);
                }
                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (salvou == true) {
      await _carregar();
    }
  }

  Future<void> _desativar(Usuario u) async {
    final sessao = ServicoSessao();
    if (sessao.usuario?.id == u.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Você não pode desativar o usuário em uso.')),
      );
      return;
    }
    if (u.nivel == NivelUsuario.admin) {
      final qtd = await BancoDados.contarAdminsAtivos();
      if (qtd <= 1) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Não dá pra desativar o último administrador ativo.'),
          ),
        );
        return;
      }
    }

    final confirma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desativar usuário'),
        content: Text(
            'Desativar "${u.nome}"? O histórico de ponto e vendas será preservado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desativar'),
          ),
        ],
      ),
    );
    if (confirma == true && u.id != null) {
      await BancoDados.desativarUsuario(u.id!);
      await _carregar();
    }
  }

  Future<void> _abrirPontos(Usuario u) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TelaPontosAdmin(usuario: u),
      ),
    );
    await _carregar();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuários'),
        actions: [
          IconButton(
            tooltip: _mostrarInativos
                ? 'Esconder desativados'
                : 'Mostrar desativados',
            icon: Icon(_mostrarInativos
                ? Icons.visibility_off
                : Icons.visibility),
            onPressed: () {
              setState(() => _mostrarInativos = !_mostrarInativos);
              _carregar();
            },
          ),
        ],
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _usuarios.isEmpty
              ? const Center(child: Text('Nenhum usuário'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  itemCount: _usuarios.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final u = _usuarios[i];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: _corNivel(u.nivel),
                                child: Text(
                                  u.iniciais,
                                  style:
                                      const TextStyle(color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      u.nome,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: u.ativo ? null : Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      '${u.nivel.rotulo}${u.ativo ? "" : "  ·  desativado"}',
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Editar horários',
                                icon: const Icon(Icons.schedule),
                                onPressed: () => _abrirPontos(u),
                              ),
                              IconButton(
                                tooltip: 'Editar usuário',
                                icon: const Icon(Icons.edit),
                                onPressed: () =>
                                    _abrirFormulario(usuario: u),
                              ),
                              if (u.ativo)
                                IconButton(
                                  tooltip: 'Desativar',
                                  icon: const Icon(Icons.block,
                                      color: Colors.red),
                                  onPressed: () => _desativar(u),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: u.funcoesPermitidas.map((f) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.brown.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: Colors.brown.shade200),
                                ),
                                child: Text(
                                  f,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF5D3A1A),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      // Botão centralizado embaixo (substitui o FAB do canto)
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 8, 40, 16),
          child: SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: () => _abrirFormulario(),
              icon: const Icon(Icons.person_add, size: 22),
              label: const Text(
                'NOVO USUÁRIO',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
