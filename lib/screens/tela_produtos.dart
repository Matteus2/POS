import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/banco_dados.dart';

class TelaProdutos extends StatefulWidget {
  const TelaProdutos({super.key});

  @override
  State<TelaProdutos> createState() => _TelaProdutosState();
}

class _TelaProdutosState extends State<TelaProdutos> {
  final _cores = const [
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.redAccent,
    Colors.amber,
    Colors.pinkAccent,
    Colors.purple,
    Colors.blueAccent,
    Colors.green,
    Colors.teal,
    Colors.indigo,
    Colors.blueGrey,
  ];

  List<Produto> _produtos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final produtos = await BancoDados.carregarProdutos();
    if (!mounted) return;
    setState(() {
      _produtos = produtos;
      _carregando = false;
    });
  }

  Future<void> _abrirFormulario({Produto? produto}) async {
    final nomeController = TextEditingController(text: produto?.nome ?? '');
    final categoriaController =
        TextEditingController(text: produto?.categoria ?? '');
    final precoController = TextEditingController(
      text: produto == null ? '' : produto.preco.toStringAsFixed(2),
    );
    final custoController = TextEditingController(
      text: produto == null ? '' : produto.custo.toStringAsFixed(2),
    );
    var cor = produto?.cor ?? _cores.first;

    final salvo = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(produto == null ? 'Novo produto' : 'Editar produto'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nomeController,
                    decoration: const InputDecoration(labelText: 'Nome'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  TextField(
                    controller: categoriaController,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    textCapitalization: TextCapitalization.words,
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: precoController,
                          decoration: const InputDecoration(labelText: 'Preco'),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: custoController,
                          decoration: const InputDecoration(
                            labelText: 'Custo',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final opcao in _cores)
                        InkWell(
                          onTap: () => setDialogState(() => cor = opcao),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: opcao,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: cor.toARGB32() == opcao.toARGB32()
                                    ? Colors.black
                                    : Colors.transparent,
                                width: 3,
                              ),
                            ),
                          ),
                        ),
                    ],
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
                  final nome = nomeController.text.trim();
                  final categoria = categoriaController.text.trim();
                  final preco = _parseMoeda(precoController.text);
                  final custo = _parseMoeda(custoController.text);
                  if (nome.isEmpty || categoria.isEmpty || preco <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Informe nome, categoria e preco.'),
                      ),
                    );
                    return;
                  }

                  final novo = Produto(
                    id: produto?.id,
                    nome: nome,
                    categoria: categoria,
                    preco: preco,
                    custo: custo,
                    cor: cor,
                  );
                  if (produto == null) {
                    await BancoDados.inserirProduto(novo);
                  } else {
                    await BancoDados.atualizarProduto(novo);
                  }
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

  Future<void> _remover(Produto produto) async {
    final confirma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover produto'),
        content: Text('Remover "${produto.nome}" do catalogo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirma != true || produto.id == null) return;
    await BancoDados.removerProduto(produto.id!);
    await _carregar();
  }

  double _parseMoeda(String value) {
    return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Produtos')),
      // Botão centralizado na parte inferior (antes era FAB no canto direito)
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 8, 40, 16),
          child: SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: () => _abrirFormulario(),
              icon: const Icon(Icons.add, size: 22),
              label: const Text(
                'NOVO PRODUTO',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
              itemCount: _produtos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final produto = _produtos[index];
                return ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  leading: CircleAvatar(backgroundColor: produto.cor),
                  title: Text(produto.nome),
                  subtitle: Text(
                    '${produto.categoria}  |  custo R\$ ${produto.custo.toStringAsFixed(2)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'R\$ ${produto.preco.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        tooltip: 'Editar',
                        icon: const Icon(Icons.edit),
                        onPressed: () => _abrirFormulario(produto: produto),
                      ),
                      IconButton(
                        tooltip: 'Remover',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _remover(produto),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
