import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/banco_dados.dart';

/// Editor de pontos — só pra admin.
///
/// Permite corrigir batidas: editar timestamp, mudar tipo (entrada/saída),
/// remover registros indevidos, adicionar novos manualmente. Usa o
/// usuário-alvo passado no construtor.
///
/// Analogia: é o "livro de ocorrências" do RH, onde dá pra apagar e
/// rabiscar pra consertar erros do batedor de ponto.
class TelaPontosAdmin extends StatefulWidget {
  final Usuario usuario;
  const TelaPontosAdmin({super.key, required this.usuario});

  @override
  State<TelaPontosAdmin> createState() => _TelaPontosAdminState();
}

class _TelaPontosAdminState extends State<TelaPontosAdmin> {
  final _formatoData = DateFormat('dd/MM/yyyy HH:mm');
  List<RegistroPonto> _pontos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final pontos =
        await BancoDados.carregarPontos(usuarioId: widget.usuario.id, limite: 200);
    if (!mounted) return;
    setState(() {
      _pontos = pontos;
      _carregando = false;
    });
  }

  Future<DateTime?> _escolherDataHora(DateTime inicial) async {
    final dataNova = await showDatePicker(
      context: context,
      initialDate: inicial,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (dataNova == null || !mounted) return null;
    final horaNova = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(inicial),
    );
    if (horaNova == null) return null;
    return DateTime(
      dataNova.year,
      dataNova.month,
      dataNova.day,
      horaNova.hour,
      horaNova.minute,
    );
  }

  Future<void> _editar(RegistroPonto p) async {
    String tipo = p.tipo;
    String funcao = p.funcao;
    DateTime data = p.data;

    final salvou = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Editar ponto'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: tipo,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'entrada', child: Text('Entrada')),
                      DropdownMenuItem(value: 'saida', child: Text('Saída')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => tipo = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: widget.usuario.funcoesPermitidas
                            .contains(funcao)
                        ? funcao
                        : widget.usuario.funcoesPermitidas.first,
                    decoration: const InputDecoration(
                      labelText: 'Função',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.usuario.funcoesPermitidas
                        .map((f) =>
                            DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => funcao = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final novo = await _escolherDataHora(data);
                      if (novo != null) {
                        setDialogState(() => data = novo);
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_formatoData.format(data)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );

    if (salvou == true && p.id != null) {
      await BancoDados.atualizarPonto(
        p.id!,
        novaData: data,
        novaFuncao: funcao,
        novoTipo: tipo,
      );
      await _carregar();
    }
  }

  Future<void> _remover(RegistroPonto p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover ponto'),
        content: Text(
            'Remover o registro de ${p.tipo} em ${_formatoData.format(p.data)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (ok == true && p.id != null) {
      await BancoDados.removerPonto(p.id!);
      await _carregar();
    }
  }

  Future<void> _adicionar() async {
    String tipo = 'entrada';
    String funcao = widget.usuario.funcoesPermitidas.first;
    DateTime data = DateTime.now();

    final salvou = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Adicionar ponto manual'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: tipo,
                    decoration: const InputDecoration(
                      labelText: 'Tipo',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'entrada', child: Text('Entrada')),
                      DropdownMenuItem(value: 'saida', child: Text('Saída')),
                    ],
                    onChanged: (v) {
                      if (v != null) setDialogState(() => tipo = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: funcao,
                    decoration: const InputDecoration(
                      labelText: 'Função',
                      border: OutlineInputBorder(),
                    ),
                    items: widget.usuario.funcoesPermitidas
                        .map((f) =>
                            DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => funcao = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final novo = await _escolherDataHora(data);
                      if (novo != null) {
                        setDialogState(() => data = novo);
                      }
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_formatoData.format(data)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Adicionar'),
              ),
            ],
          );
        },
      ),
    );

    if (salvou == true) {
      await BancoDados.inserirPonto(RegistroPonto(
        usuarioId: widget.usuario.id!,
        usuarioNome: widget.usuario.nome,
        tipo: tipo,
        funcao: funcao,
        data: data,
      ));
      await _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pontos · ${widget.usuario.nome}'),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _pontos.isEmpty
              ? const Center(child: Text('Nenhum ponto registrado'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
                  itemCount: _pontos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, i) {
                    final p = _pontos[i];
                    final corTipo =
                        p.ehEntrada ? Colors.green : Colors.orange;
                    return ListTile(
                      tileColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      leading: Icon(
                        p.ehEntrada ? Icons.login : Icons.logout,
                        color: corTipo,
                      ),
                      title: Row(
                        children: [
                          Text(
                            p.ehEntrada ? 'Entrada' : 'Saída',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, color: corTipo),
                          ),
                          const SizedBox(width: 8),
                          Text('· ${p.funcao}',
                              style:
                                  const TextStyle(color: Colors.black54)),
                          if (p.automatica) ...[
                            const SizedBox(width: 6),
                            const Tooltip(
                              message: 'Gerado automaticamente às 4h',
                              child: Icon(Icons.auto_awesome,
                                  size: 14, color: Colors.orange),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(_formatoData.format(p.data)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Editar',
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _editar(p),
                          ),
                          IconButton(
                            tooltip: 'Remover',
                            icon: const Icon(Icons.delete_outline,
                                size: 20, color: Colors.red),
                            onPressed: () => _remover(p),
                          ),
                        ],
                      ),
                    );
                  },
                ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 8, 40, 16),
          child: SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _adicionar,
              icon: const Icon(Icons.add),
              label: const Text(
                'ADICIONAR PONTO MANUAL',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
