import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/banco_dados.dart';
import '../services/servico_impressora.dart';
import '../services/servico_sessao.dart';
import 'tela_historico_vendas.dart';
import 'tela_impressora.dart';
import 'tela_login.dart';
import 'tela_operacoes_ml.dart';
import 'tela_produtos.dart';
import 'tela_usuarios.dart';

class TelaCaixa extends StatefulWidget {
  const TelaCaixa({super.key});

  @override
  State<TelaCaixa> createState() => _TelaCaixaState();
}

class _TelaCaixaState extends State<TelaCaixa> {
  final _impressora = ServicoImpressora();
  final _valorRecebidoController = TextEditingController();

  ConfiguracaoLoja _config = ConfiguracaoLoja();
  List<Produto> _produtos = [];
  final List<ItemCarrinho> _carrinho = [];
  List<Venda> _vendasHoje = [];
  CaixaTurno? _caixaAberto;

  String _categoriaSelecionada = 'Todos';
  String _formaPagamento = 'Dinheiro';
  int _quantidadeRapida = 1;
  bool _carregando = true;

  final List<String> _formasPagamento = ['Dinheiro', 'Cartao', 'PIX'];

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _valorRecebidoController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => _carregando = true);
    await _carregarConfiguracao();

    var produtos = await BancoDados.carregarProdutos();
    if (produtos.isEmpty) {
      await _popularProdutosPadrao();
      produtos = await BancoDados.carregarProdutos();
    }

    final vendasHoje = await BancoDados.carregarVendasHoje();
    final caixaAberto = await BancoDados.carregarCaixaAberto();

    if (!mounted) return;
    setState(() {
      _produtos = produtos;
      _vendasHoje = vendasHoje;
      _caixaAberto = caixaAberto;
      _carregando = false;
    });
  }

  Future<void> _carregarConfiguracao() async {
    final prefs = await SharedPreferences.getInstance();
    _config = ConfiguracaoLoja(
      nomeLoja: prefs.getString('loja_nome') ?? 'PADARIA',
      endereco: prefs.getString('loja_endereco') ?? 'Ribeirao Preto - SP',
      impressoraEnderecoMAC: prefs.getString('impressora_mac'),
      impressoraNome: prefs.getString('impressora_nome'),
      impressaoAtiva: prefs.getBool('impressao_ativa') ?? false,
      larguraColunas: prefs.getInt('largura_colunas') ?? 32,
    );
  }

  Future<void> _salvarConfiguracao(ConfiguracaoLoja config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('loja_nome', config.nomeLoja);
    await prefs.setString('loja_endereco', config.endereco);
    await prefs.setBool('impressao_ativa', config.impressaoAtiva);
    await prefs.setInt('largura_colunas', config.larguraColunas);
    if (config.impressoraEnderecoMAC != null) {
      await prefs.setString('impressora_mac', config.impressoraEnderecoMAC!);
    }
    if (config.impressoraNome != null) {
      await prefs.setString('impressora_nome', config.impressoraNome!);
    }
    setState(() => _config = config);
  }

  Future<void> _popularProdutosPadrao() async {
    final padrao = [
      Produto(
        nome: 'Pao Frances',
        categoria: 'Paes',
        preco: 1,
        custo: 0.35,
        cor: Colors.orange,
      ),
      Produto(
        nome: 'Pao Integral',
        categoria: 'Paes',
        preco: 2.50,
        custo: 0.90,
        cor: Colors.deepOrange,
      ),
      Produto(
        nome: 'Cafe Pequeno',
        categoria: 'Cafes',
        preco: 4,
        custo: 0.80,
        cor: Colors.brown,
      ),
      Produto(
        nome: 'Cafe Grande',
        categoria: 'Cafes',
        preco: 6,
        custo: 1.20,
        cor: Colors.brown.shade700,
      ),
      Produto(
        nome: 'Coxinha',
        categoria: 'Salgados',
        preco: 8,
        custo: 2.40,
        cor: Colors.redAccent,
      ),
      Produto(
        nome: 'Esfiha',
        categoria: 'Salgados',
        preco: 7.50,
        custo: 2.20,
        cor: Colors.red,
      ),
      Produto(
        nome: 'Pao de Queijo',
        categoria: 'Salgados',
        preco: 5,
        custo: 1.60,
        cor: Colors.amber,
      ),
      Produto(
        nome: 'Sonho',
        categoria: 'Doces',
        preco: 7,
        custo: 2.10,
        cor: Colors.pinkAccent,
      ),
      Produto(
        nome: 'Brigadeiro',
        categoria: 'Doces',
        preco: 4.50,
        custo: 1,
        cor: Colors.purple,
      ),
      Produto(
        nome: 'Refrigerante',
        categoria: 'Bebidas',
        preco: 6.50,
        custo: 3,
        cor: Colors.blueAccent,
      ),
      Produto(
        nome: 'Suco',
        categoria: 'Bebidas',
        preco: 7.50,
        custo: 2.50,
        cor: Colors.green,
      ),
    ];
    for (final p in padrao) {
      await BancoDados.inserirProduto(p);
    }
  }

  void _adicionarAoCarrinho(Produto produto) {
    setState(() {
      final existentes = _carrinho.where((i) => i.produto.id == produto.id);
      if (existentes.isNotEmpty) {
        existentes.first.quantidade += _quantidadeRapida;
      } else {
        _carrinho.add(
          ItemCarrinho(produto: produto, quantidade: _quantidadeRapida),
        );
      }
      _quantidadeRapida = 1;
    });
  }

  void _removerUmaUnidade(ItemCarrinho item) {
    setState(() {
      if (item.quantidade > 1) {
        item.quantidade--;
      } else {
        _carrinho.remove(item);
      }
    });
  }

  void _removerItemInteiro(ItemCarrinho item) {
    setState(() => _carrinho.remove(item));
  }

  Future<void> _alterarQuantidadeItem(ItemCarrinho item) async {
    final quantidade = await _pedirQuantidade(
      titulo: item.produto.nome,
      valorInicial: item.quantidade,
    );
    if (quantidade == null) return;
    setState(() {
      if (quantidade <= 0) {
        _carrinho.remove(item);
      } else {
        item.quantidade = quantidade;
      }
    });
  }

  Future<void> _alterarQuantidadeRapida() async {
    final quantidade = await _pedirQuantidade(
      titulo: 'Quantidade rapida',
      valorInicial: _quantidadeRapida,
    );
    if (quantidade == null || quantidade <= 0) return;
    setState(() => _quantidadeRapida = quantidade);
  }

  Future<int?> _pedirQuantidade({
    required String titulo,
    required int valorInicial,
  }) async {
    final controller = TextEditingController(text: valorInicial.toString());
    return showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Quantidade',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, int.tryParse(controller.text.trim()) ?? 0);
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelarVendaAtual() async {
    if (_carrinho.isEmpty) return;
    final confirma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar venda'),
        content: const Text('Esvaziar todo o carrinho?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Nao'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sim'),
          ),
        ],
      ),
    );
    if (confirma == true) {
      setState(() => _carrinho.clear());
    }
  }

  double get _total => _carrinho.fold(0, (s, i) => s + i.subtotal);

  double get _valorRecebido =>
      double.tryParse(_valorRecebidoController.text.replaceAll(',', '.')) ?? 0;

  double get _troco {
    if (_formaPagamento != 'Dinheiro') return 0;
    final recebido = _valorRecebido;
    if (recebido <= 0) return 0;
    return (recebido - _total).clamp(0, double.infinity);
  }

  List<String> get _categorias {
    final categorias = _produtos.map((p) => p.categoria).toSet().toList()
      ..sort();
    return ['Todos', ...categorias];
  }

  List<Produto> get _produtosFiltrados {
    if (_categoriaSelecionada == 'Todos') return _produtos;
    return _produtos
        .where((p) => p.categoria == _categoriaSelecionada)
        .toList();
  }

  Future<void> _finalizarVenda() async {
    if (_carrinho.isEmpty) return;

    // Revalida caixa diretamente no banco — o estado local pode estar velho
    // (ex: outro usuário fechou o caixa em outra sessão).
    final caixaAtual = await BancoDados.carregarCaixaAberto();
    if (caixaAtual == null) {
      if (!mounted) return;
      setState(() => _caixaAberto = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Caixa fechado. Abra o caixa antes de vender.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final valorRecebido = _valorRecebido;
    if (_formaPagamento == 'Dinheiro' &&
        valorRecebido > 0 &&
        valorRecebido < _total) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Valor recebido menor que o total.')),
      );
      return;
    }

    final venda = Venda(
      data: DateTime.now(),
      total: _total,
      formaPagamento: _formaPagamento,
      valorRecebido: _formaPagamento == 'Dinheiro' ? valorRecebido : 0,
      troco: _troco,
      caixaId: caixaAtual.id,
      itens: _carrinho.map((i) => ItemVenda.fromCarrinho(i)).toList(),
    );

    try {
      final vendaId = await BancoDados.salvarVenda(venda);
      final vendaComId = Venda(
        id: vendaId,
        data: venda.data,
        total: venda.total,
        formaPagamento: venda.formaPagamento,
        valorRecebido: venda.valorRecebido,
        troco: venda.troco,
        caixaId: venda.caixaId,
        itens: venda.itens,
      );

      var impressaoOk = true;
      if (_config.impressaoAtiva &&
          _impressora.estado == EstadoImpressora.conectada) {
        impressaoOk = await _impressora.imprimirCupom(
          venda: vendaComId,
          config: _config,
        );
      }

      if (!mounted) return;
      setState(() {
        _carrinho.clear();
        _valorRecebidoController.clear();
      });
      await _carregarDados();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            impressaoOk
                ? 'Venda finalizada · R\$ ${venda.total.toStringAsFixed(2)}'
                : 'Venda salva, mas a impressão falhou',
          ),
          backgroundColor: impressaoOk ? Colors.green : Colors.orange,
        ),
      );
    } catch (e, stack) {
      // Sem try/catch o usuário só vê o botão "engolir" o clique. Aqui pelo
      // menos a mensagem do erro aparece — fundamental pra diagnosticar
      // em campo (sócio em Ribeirão consegue tirar print e mandar pra você).
      debugPrint('Erro ao finalizar venda: $e\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar venda: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  Future<void> _abrirControleCaixa() async {
    if (_caixaAberto == null) {
      await _abrirCaixaDialog();
    } else {
      await _mostrarCaixaAberto();
    }
    await _carregarDados();
  }

  Future<void> _abrirCaixaDialog() async {
    final valorController = TextEditingController(text: '50.00');
    final operadorController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abrir caixa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: valorController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Troco inicial',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: operadorController,
              decoration: const InputDecoration(
                labelText: 'Operador',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abrir'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await BancoDados.abrirCaixa(
        valorAbertura: _parseMoeda(valorController.text),
        operador: operadorController.text.trim(),
      );
      await _carregarDados();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Caixa aberto · pronto pra vender'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Erro ao abrir caixa: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao abrir caixa: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _mostrarCaixaAberto() async {
    final caixa = _caixaAberto!;
    final vendas = await BancoDados.carregarVendasDoCaixa(caixa.id!);
    final movimentos = await BancoDados.carregarMovimentosCaixa(caixa.id!);
    if (!mounted) return;

    final dinheiro = vendas
        .where((v) => v.formaPagamento == 'Dinheiro')
        .fold<double>(0, (s, v) => s + v.total);
    final cartao = vendas
        .where((v) => v.formaPagamento == 'Cartao')
        .fold<double>(0, (s, v) => s + v.total);
    final pix = vendas
        .where((v) => v.formaPagamento == 'PIX')
        .fold<double>(0, (s, v) => s + v.total);
    final suprimentos = movimentos
        .where((m) => m.tipo == 'suprimento')
        .fold<double>(0, (s, m) => s + m.valor);
    final sangrias = movimentos
        .where((m) => m.tipo == 'sangria')
        .fold<double>(0, (s, m) => s + m.valor);
    final esperado = caixa.valorAbertura + dinheiro + suprimentos - sangrias;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Caixa aberto',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _linhaResumo('Abertura', caixa.valorAbertura),
            _linhaResumo('Dinheiro', dinheiro),
            _linhaResumo('Cartao', cartao),
            _linhaResumo('PIX', pix),
            _linhaResumo('Suprimentos', suprimentos),
            _linhaResumo('Sangrias', -sangrias),
            const Divider(),
            _linhaResumo('Esperado em dinheiro', esperado, destaque: true),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _movimentoCaixa('suprimento');
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Suprimento'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _movimentoCaixa('sangria');
                    },
                    icon: const Icon(Icons.remove),
                    label: const Text('Sangria'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await _fecharCaixa(esperado);
              },
              icon: const Icon(Icons.lock),
              label: const Text('Fechar caixa'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _linhaResumo(String label, double valor, {bool destaque = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            'R\$ ${valor.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: destaque ? 18 : 14,
              fontWeight: destaque ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _movimentoCaixa(String tipo) async {
    final valorController = TextEditingController();
    final descricaoController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tipo == 'sangria' ? 'Sangria' : 'Suprimento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: valorController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Valor',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descricaoController,
              decoration: const InputDecoration(
                labelText: 'Observacao',
                border: OutlineInputBorder(),
              ),
            ),
          ],
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
      ),
    );
    if (ok != true || _caixaAberto?.id == null) return;

    final valor = _parseMoeda(valorController.text);
    if (valor <= 0) return;
    try {
      await BancoDados.salvarMovimentoCaixa(
        MovimentoCaixa(
          caixaId: _caixaAberto!.id!,
          data: DateTime.now(),
          tipo: tipo,
          valor: valor,
          descricao: descricaoController.text.trim(),
        ),
      );
      // Recarrega pra refletir o saldo atualizado no próximo bottom sheet.
      await _carregarDados();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tipo == 'sangria'
              ? 'Sangria de R\$ ${valor.toStringAsFixed(2)} registrada'
              : 'Suprimento de R\$ ${valor.toStringAsFixed(2)} registrado'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      debugPrint('Erro em $tipo: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao registrar $tipo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fecharCaixa(double esperado) async {
    final valorController =
        TextEditingController(text: esperado.toStringAsFixed(2));
    final obsController = TextEditingController();

    // StatefulBuilder permite que o dialog atualize a diferença em
    // tempo real conforme o usuário digita — fica claro que pode
    // fechar mesmo com sobra/falta (não há trava).
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final contado =
              double.tryParse(valorController.text.replaceAll(',', '.')) ?? 0;
          final diferenca = contado - esperado;
          Color corDif;
          String rotuloDif;
          if (diferenca.abs() < 0.005) {
            corDif = Colors.green;
            rotuloDif = 'EXATO';
          } else if (diferenca > 0) {
            corDif = Colors.blue;
            rotuloDif = 'SOBRA de R\$ ${diferenca.toStringAsFixed(2)}';
          } else {
            corDif = Colors.red;
            rotuloDif = 'FALTA R\$ ${diferenca.abs().toStringAsFixed(2)}';
          }

          return AlertDialog(
            title: const Text('Fechar caixa'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Esperado em dinheiro:'),
                      Text(
                        'R\$ ${esperado.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: valorController,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Valor contado',
                      border: OutlineInputBorder(),
                      prefixText: 'R\$ ',
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Selo grande mostrando a diferença em tempo real
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: corDif.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: corDif),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          diferenca.abs() < 0.005
                              ? Icons.check_circle
                              : (diferenca > 0
                                  ? Icons.trending_up
                                  : Icons.trending_down),
                          color: corDif,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          rotuloDif,
                          style: TextStyle(
                            color: corDif,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pode fechar com qualquer valor — a diferença fica registrada pra auditoria.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: obsController,
                    decoration: const InputDecoration(
                      labelText: 'Observação (opcional)',
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
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.lock),
                label: const Text('FECHAR CAIXA'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true || _caixaAberto?.id == null) return;

    final contado = _parseMoeda(valorController.text);
    final diferenca = contado - esperado;

    try {
      await BancoDados.fecharCaixa(
        caixaId: _caixaAberto!.id!,
        valorFechamentoInformado: contado,
        observacao: obsController.text.trim(),
      );
      // CRÍTICO: recarrega o estado pra UI refletir que o caixa fechou.
      // Sem isso o ícone fica verde, o bottom sheet abre de novo, e o
      // usuário acha que o fechamento não funcionou.
      await _carregarDados();

      if (!mounted) return;
      final msg = diferenca.abs() < 0.005
          ? 'Caixa fechado · valor exato'
          : (diferenca > 0
              ? 'Caixa fechado · sobra de R\$ ${diferenca.toStringAsFixed(2)}'
              : 'Caixa fechado · faltaram R\$ ${diferenca.abs().toStringAsFixed(2)}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor:
              diferenca.abs() < 0.005 ? Colors.green : Colors.orange,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      debugPrint('Erro ao fechar caixa: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao fechar caixa: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _abrirConfiguracoes() async {
    final nomeController = TextEditingController(text: _config.nomeLoja);
    final enderecoController = TextEditingController(text: _config.endereco);
    var impressaoAtiva = _config.impressaoAtiva;
    var largura = _config.larguraColunas;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Configuracoes da loja'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(
                    labelText: 'Nome da loja',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: enderecoController,
                  decoration: const InputDecoration(
                    labelText: 'Endereco',
                    border: OutlineInputBorder(),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Impressao ativa'),
                  value: impressaoAtiva,
                  onChanged: (value) {
                    setDialogState(() => impressaoAtiva = value);
                  },
                ),
                DropdownButtonFormField<int>(
                  initialValue: largura,
                  items: const [
                    DropdownMenuItem(value: 32, child: Text('32 colunas')),
                    DropdownMenuItem(value: 48, child: Text('48 colunas')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => largura = value);
                  },
                  decoration: const InputDecoration(
                    labelText: 'Largura do cupom',
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
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;

    await _salvarConfiguracao(
      ConfiguracaoLoja(
        nomeLoja: nomeController.text.trim().isEmpty
            ? 'PADARIA'
            : nomeController.text.trim(),
        endereco: enderecoController.text.trim().isEmpty
            ? 'Ribeirao Preto - SP'
            : enderecoController.text.trim(),
        impressaoAtiva: impressaoAtiva,
        larguraColunas: largura,
        impressoraEnderecoMAC: _config.impressoraEnderecoMAC,
        impressoraNome: _config.impressoraNome,
      ),
    );
  }

  double _parseMoeda(String value) {
    return double.tryParse(value.replaceAll(',', '.')) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final sessao = ServicoSessao();
    final usuarioAtivo = sessao.usuario;

    return Scaffold(
      appBar: AppBar(
        title: Text(_config.nomeLoja),
        actions: [
          if (usuarioAtivo != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Center(
                child: Chip(
                  avatar: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Text(
                      usuarioAtivo.iniciais,
                      style: const TextStyle(
                        color: Color(0xFF5D3A1A),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  label: Text(
                    usuarioAtivo.nome.split(' ').first,
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: Colors.brown.shade700,
                ),
              ),
            ),
          IconButton(
            tooltip: _caixaAberto == null ? 'Abrir caixa' : 'Caixa aberto',
            icon: Icon(
              Icons.point_of_sale,
              color: _caixaAberto == null ? null : Colors.greenAccent,
            ),
            onPressed: _abrirControleCaixa,
          ),
          PopupMenuButton<String>(
            onSelected: _abrirMenu,
            itemBuilder: (context) {
              final itens = <PopupMenuEntry<String>>[
                const PopupMenuItem(
                  value: 'vendas',
                  child: ListTile(
                    leading: Icon(Icons.receipt_long),
                    title: Text('Últimas vendas'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'operacoes',
                  child: ListTile(
                    leading: Icon(Icons.inventory_2),
                    title: Text('Produção e perdas'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'impressora',
                  child: ListTile(
                    leading: Icon(Icons.print),
                    title: Text('Impressora'),
                  ),
                ),
              ];

              // Só admin gerencia produtos
              if (sessao.podeEditarProdutos) {
                itens.insert(
                  1,
                  const PopupMenuItem(
                    value: 'produtos',
                    child: ListTile(
                      leading: Icon(Icons.bakery_dining),
                      title: Text('Produtos'),
                    ),
                  ),
                );
              }

              // Só admin gerencia usuários e configurações
              if (sessao.podeGerenciarUsuarios) {
                itens.add(const PopupMenuDivider());
                itens.add(const PopupMenuItem(
                  value: 'usuarios',
                  child: ListTile(
                    leading: Icon(Icons.people),
                    title: Text('Usuários'),
                  ),
                ));
              }
              if (sessao.podeConfigurarLoja) {
                itens.add(const PopupMenuItem(
                  value: 'config',
                  child: ListTile(
                    leading: Icon(Icons.settings),
                    title: Text('Configurações'),
                  ),
                ));
              }

              itens.add(const PopupMenuDivider());
              itens.add(const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text('Sair', style: TextStyle(color: Colors.red)),
                ),
              ));
              return itens;
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final largo = constraints.maxWidth > 700;
          return largo ? _layoutTablet() : _layoutPhone();
        },
      ),
    );
  }

  Future<void> _abrirMenu(String item) async {
    if (item == 'vendas') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TelaHistoricoVendas(
            config: _config,
            impressora: _impressora,
            caixaAberto: _caixaAberto,
          ),
        ),
      );
      await _carregarDados();
    } else if (item == 'produtos') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TelaProdutos()),
      );
      await _carregarDados();
    } else if (item == 'operacoes') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TelaOperacoesML()),
      );
    } else if (item == 'config') {
      await _abrirConfiguracoes();
    } else if (item == 'impressora') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TelaImpressora()),
      );
      setState(() {});
    } else if (item == 'usuarios') {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TelaUsuarios()),
      );
    } else if (item == 'logout') {
      await _confirmarLogout();
    }
  }

  Future<void> _confirmarLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sair'),
        content: const Text('Sair da sessão? O caixa em andamento NÃO é fechado automaticamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    ServicoSessao().logout();
    if (!mounted) return;
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const TelaLogin()),
    );
  }

  Widget _layoutTablet() {
    return Row(
      children: [
        Expanded(flex: 3, child: _construirProdutos()),
        SizedBox(width: 390, child: _construirCarrinho()),
      ],
    );
  }

  Widget _layoutPhone() {
    return Column(
      children: [
        Expanded(flex: 2, child: _construirProdutos()),
        Expanded(flex: 3, child: _construirCarrinho()),
      ],
    );
  }

  Widget _construirProdutos() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categorias.length,
                    itemBuilder: (context, index) {
                      final cat = _categorias[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: _categoriaSelecionada == cat,
                          onSelected: (_) {
                            setState(() => _categoriaSelecionada = cat);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _alterarQuantidadeRapida,
                icon: const Icon(Icons.pin),
                label: Text('x$_quantidadeRapida'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              itemCount: _produtosFiltrados.length,
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                childAspectRatio: 1.45,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemBuilder: (context, index) {
                final produto = _produtosFiltrados[index];
                return InkWell(
                  onTap: () => _adicionarAoCarrinho(produto),
                  borderRadius: BorderRadius.circular(8),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: produto.cor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          produto.nome,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'R\$ ${produto.preco.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
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

  Widget _construirCarrinho() {
    final totalHoje = _vendasHoje.fold<double>(0, (s, v) => s + v.total);
    final vendasHoje = _vendasHoje.where((v) => !v.estorno).length;

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Carrinho',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  tooltip: 'Cancelar venda',
                  onPressed: _carrinho.isEmpty ? null : _cancelarVendaAtual,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
          Expanded(
            child: _carrinho.isEmpty
                ? const Center(
                    child: Text(
                      'Toque nos produtos para adicionar',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    itemCount: _carrinho.length,
                    itemBuilder: (context, index) {
                      final item = _carrinho[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        child: ListTile(
                          onLongPress: () => _removerItemInteiro(item),
                          title: Text(item.produto.nome),
                          subtitle: Text(
                            'R\$ ${item.subtotal.toStringAsFixed(2)}',
                          ),
                          trailing: Wrap(
                            spacing: 2,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              IconButton(
                                tooltip: 'Diminuir',
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => _removerUmaUnidade(item),
                              ),
                              OutlinedButton(
                                onPressed: () => _alterarQuantidadeItem(item),
                                child: Text('x${item.quantidade}'),
                              ),
                              IconButton(
                                tooltip: 'Remover linha',
                                icon: const Icon(Icons.close),
                                onPressed: () => _removerItemInteiro(item),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'R\$ ${_total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _formaPagamento,
                  items: _formasPagamento
                      .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                      .toList(),
                  onChanged: (v) {
                    setState(() {
                      _formaPagamento = v!;
                      if (_formaPagamento != 'Dinheiro') {
                        _valorRecebidoController.clear();
                      }
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Pagamento',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                if (_formaPagamento == 'Dinheiro') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _valorRecebidoController,
                    onChanged: (_) => setState(() {}),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Recebido',
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixText: 'Troco R\$ ${_troco.toStringAsFixed(2)}',
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '$vendasHoje',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text('vendas hoje',
                              style: TextStyle(fontSize: 11)),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            'R\$ ${totalHoje.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text('total hoje',
                              style: TextStyle(fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _carrinho.isEmpty ? null : _finalizarVenda,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      'FINALIZAR - ${_formaPagamento.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
