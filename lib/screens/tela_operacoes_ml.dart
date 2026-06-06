import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/banco_dados.dart';

class TelaOperacoesML extends StatefulWidget {
  const TelaOperacoesML({super.key});

  @override
  State<TelaOperacoesML> createState() => _TelaOperacoesMLState();
}

class _TelaOperacoesMLState extends State<TelaOperacoesML> {
  final _formatoData = DateFormat('dd/MM HH:mm');
  List<Produto> _produtos = [];
  List<RegistroOperacional> _registros = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final produtos = await BancoDados.carregarProdutos();
    final registros = await BancoDados.carregarRegistrosOperacionais();
    if (!mounted) return;
    setState(() {
      _produtos = produtos;
      _registros = registros;
      _carregando = false;
    });
  }

  Future<void> _registrar(String tipo) async {
    if (_produtos.isEmpty) return;

    Produto produto = _produtos.first;
    final quantidadeController = TextEditingController();
    final obsController = TextEditingController();

    final salvo = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(tipo == 'producao' ? 'Producao do dia' : 'Perda/sobra'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Produto>(
                    initialValue: produto,
                    items: _produtos
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(p.nome),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => produto = value);
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Produto',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: quantidadeController,
                    decoration: const InputDecoration(
                      labelText: 'Quantidade',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: obsController,
                    decoration: const InputDecoration(
                      labelText: 'Observacao',
                      border: OutlineInputBorder(),
                    ),
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
                onPressed: () async {
                  final quantidade =
                      int.tryParse(quantidadeController.text.trim()) ?? 0;
                  if (quantidade <= 0 || produto.id == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Informe a quantidade.')),
                    );
                    return;
                  }

                  await BancoDados.salvarRegistroOperacional(
                    RegistroOperacional(
                      produtoId: produto.id!,
                      produtoNome: produto.nome,
                      produtoCategoria: produto.categoria,
                      tipo: tipo,
                      quantidade: quantidade,
                      custoUnitario: produto.custo,
                      data: DateTime.now(),
                      observacao: obsController.text.trim(),
                    ),
                  );
                  if (context.mounted) Navigator.pop(context, true);
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );

    if (salvo == true) {
      await _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final perdas = _registros
        .where((r) => r.tipo == 'perda')
        .fold<int>(0, (total, r) => total + r.quantidade);
    final producao = _registros
        .where((r) => r.tipo == 'producao')
        .fold<int>(0, (total, r) => total + r.quantidade);

    return Scaffold(
      appBar: AppBar(title: const Text('Producao e perdas')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _registrar('producao'),
                          icon: const Icon(Icons.inventory_2),
                          label: const Text('Producao'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _registrar('perda'),
                          icon: const Icon(Icons.delete_sweep),
                          label: const Text('Perda'),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      _ResumoOperacao(
                        titulo: 'Produzido',
                        valor: '$producao un.',
                        cor: Colors.blue,
                      ),
                      const SizedBox(width: 10),
                      _ResumoOperacao(
                        titulo: 'Perdas',
                        valor: '$perdas un.',
                        cor: Colors.red,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: _registros.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final registro = _registros[index];
                      final perda = registro.tipo == 'perda';
                      return ListTile(
                        tileColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        leading: Icon(
                          perda ? Icons.delete_sweep : Icons.inventory_2,
                          color: perda ? Colors.red : Colors.blue,
                        ),
                        title: Text(registro.produtoNome),
                        subtitle: Text(
                          '${_formatoData.format(registro.data)}'
                          '${registro.observacao.isEmpty ? '' : '  |  ${registro.observacao}'}',
                        ),
                        trailing: Text(
                          '${registro.quantidade} un.',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _ResumoOperacao extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color cor;

  const _ResumoOperacao({
    required this.titulo,
    required this.valor,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontSize: 12)),
            Text(
              valor,
              style: TextStyle(
                color: cor,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
