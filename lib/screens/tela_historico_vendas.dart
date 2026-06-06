import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/models.dart';
import '../services/banco_dados.dart';
import '../services/servico_impressora.dart';

class TelaHistoricoVendas extends StatefulWidget {
  final ConfiguracaoLoja config;
  final ServicoImpressora impressora;
  final CaixaTurno? caixaAberto;

  const TelaHistoricoVendas({
    super.key,
    required this.config,
    required this.impressora,
    this.caixaAberto,
  });

  @override
  State<TelaHistoricoVendas> createState() => _TelaHistoricoVendasState();
}

class _TelaHistoricoVendasState extends State<TelaHistoricoVendas> {
  final _formatoData = DateFormat('dd/MM HH:mm');
  List<Venda> _vendas = [];
  Set<int> _vendasEstornadas = {};
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final vendas = await BancoDados.carregarVendas(limite: 200);
    final estornadas = <int>{};
    for (final venda in vendas) {
      if (venda.id != null && await BancoDados.vendaPossuiEstorno(venda.id!)) {
        estornadas.add(venda.id!);
      }
    }
    if (!mounted) return;
    setState(() {
      _vendas = vendas;
      _vendasEstornadas = estornadas;
      _carregando = false;
    });
  }

  Future<void> _reimprimir(Venda venda) async {
    final ok = await widget.impressora.imprimirCupom(
      venda: venda,
      config: widget.config,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Cupom reenviado.' : 'Falha ao reimprimir cupom.'),
      ),
    );
  }

  Future<void> _estornar(Venda venda) async {
    if (venda.id == null ||
        venda.estorno ||
        _vendasEstornadas.contains(venda.id)) {
      return;
    }

    final confirma = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Estornar venda'),
        content: Text(
          'Criar um lancamento negativo para a venda #${venda.id}? '
          'O historico original sera preservado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Estornar'),
          ),
        ],
      ),
    );
    if (confirma != true) return;

    await BancoDados.estornarVenda(
      venda,
      caixaId: widget.caixaAberto?.id,
    );
    await _carregar();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Estorno registrado.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ultimas vendas')),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _vendas.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final venda = _vendas[index];
                final estornada =
                    venda.id != null && _vendasEstornadas.contains(venda.id);
                final corTotal = venda.total < 0 ? Colors.red : Colors.green;
                return ExpansionTile(
                  tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                  collapsedBackgroundColor: Colors.white,
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  collapsedShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  leading: Icon(
                    venda.estorno ? Icons.undo : Icons.receipt_long,
                    color: venda.estorno ? Colors.red : null,
                  ),
                  title: Text(
                    '#${venda.id ?? '-'}  ${_formatoData.format(venda.data)}',
                  ),
                  subtitle: Text(
                    venda.estorno
                        ? 'Estorno da venda #${venda.vendaOriginalId}'
                        : '${venda.formaPagamento}${estornada ? '  |  estornada' : ''}',
                  ),
                  trailing: Wrap(
                    spacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'R\$ ${venda.total.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: corTotal,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Reimprimir',
                        icon: const Icon(Icons.print),
                        onPressed: () => _reimprimir(venda),
                      ),
                      IconButton(
                        tooltip: 'Estornar',
                        icon: const Icon(Icons.keyboard_return),
                        onPressed: venda.estorno || estornada
                            ? null
                            : () => _estornar(venda),
                      ),
                    ],
                  ),
                  children: [
                    for (final item in venda.itens)
                      ListTile(
                        dense: true,
                        title: Text(item.produtoNome),
                        subtitle: Text(item.produtoCategoria),
                        trailing: Text(
                          '${item.quantidade}x  R\$ ${item.subtotal.toStringAsFixed(2)}',
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}
