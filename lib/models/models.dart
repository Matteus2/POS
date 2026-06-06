import 'package:flutter/material.dart';

/// Representa um produto vendido pela padaria.
class Produto {
  final int? id;
  final String nome;
  final String categoria;
  final double preco;
  final double custo; // COGS — usado pelo modelo de ML pra calcular margem/lucro esperado
  final Color cor;

  Produto({
    this.id,
    required this.nome,
    required this.categoria,
    required this.preco,
    this.custo = 0.0,
    required this.cor,
  });

  /// Margem absoluta por unidade.
  double get margemUnitaria => preco - custo;

  /// Margem percentual (0..1). Retorna 0 se preço = 0.
  double get margemPercentual => preco == 0 ? 0 : margemUnitaria / preco;

  Map<String, dynamic> toMap() => {
        'id': id,
        'nome': nome,
        'categoria': categoria,
        'preco': preco,
        'custo': custo,
        'cor': cor.value,
      };

  factory Produto.fromMap(Map<String, dynamic> map) => Produto(
        id: map['id'] as int?,
        nome: map['nome'] as String,
        categoria: map['categoria'] as String,
        preco: (map['preco'] as num).toDouble(),
        custo: (map['custo'] as num?)?.toDouble() ?? 0.0,
        cor: Color(map['cor'] as int? ?? 0xFF9E9E9E),
      );

  Produto copyWith({
    int? id,
    String? nome,
    String? categoria,
    double? preco,
    double? custo,
    Color? cor,
  }) =>
      Produto(
        id: id ?? this.id,
        nome: nome ?? this.nome,
        categoria: categoria ?? this.categoria,
        preco: preco ?? this.preco,
        custo: custo ?? this.custo,
        cor: cor ?? this.cor,
      );
}

/// Item no carrinho de venda atual.
class ItemCarrinho {
  final Produto produto;
  int quantidade;

  ItemCarrinho({required this.produto, required this.quantidade});

  double get subtotal => produto.preco * quantidade;
}

/// Venda finalizada (gravada no banco).
class Venda {
  final int? id;
  final DateTime data;
  final double total;
  final String formaPagamento;
  final double valorRecebido; // só relevante pra Dinheiro
  final double troco; // calculado na hora da venda — preserva pra reimpressão
  final int? caixaId; // qual turno de caixa essa venda pertence
  final List<ItemVenda> itens;
  final bool estorno; // true se essa venda é um lançamento de estorno (negativo)
  final int? vendaOriginalId; // se estorno, aponta pra venda original

  Venda({
    this.id,
    required this.data,
    required this.total,
    required this.formaPagamento,
    this.valorRecebido = 0,
    this.troco = 0,
    this.caixaId,
    required this.itens,
    this.estorno = false,
    this.vendaOriginalId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'data': data.toIso8601String(),
        'total': total,
        'pagamento': formaPagamento,
        'valor_recebido': valorRecebido,
        'troco': troco,
        'caixa_id': caixaId,
        'estorno': estorno ? 1 : 0,
        'venda_original_id': vendaOriginalId,
      };

  factory Venda.fromMap(Map<String, dynamic> map, {List<ItemVenda>? itens}) =>
      Venda(
        id: map['id'] as int?,
        data: DateTime.parse(map['data'] as String),
        total: (map['total'] as num).toDouble(),
        formaPagamento: map['pagamento'] as String,
        valorRecebido: (map['valor_recebido'] as num?)?.toDouble() ?? 0,
        troco: (map['troco'] as num?)?.toDouble() ?? 0,
        caixaId: map['caixa_id'] as int?,
        itens: itens ?? const [],
        estorno: (map['estorno'] as int? ?? 0) == 1,
        vendaOriginalId: map['venda_original_id'] as int?,
      );
}

/// Item individual de uma venda (linha do recibo).
/// Crucial pro pipeline de forecasting — precisa saber EXATAMENTE
/// o que foi vendido, não só o total.
class ItemVenda {
  final int? id;
  final int? vendaId;
  final String produtoNome;
  final String produtoCategoria;
  final double precoUnitario;
  final double custoUnitario; // snapshot na hora da venda — pra análise de margem histórica
  final int quantidade;

  ItemVenda({
    this.id,
    this.vendaId,
    required this.produtoNome,
    required this.produtoCategoria,
    required this.precoUnitario,
    this.custoUnitario = 0.0,
    required this.quantidade,
  });

  double get subtotal => precoUnitario * quantidade;
  double get margemTotal => (precoUnitario - custoUnitario) * quantidade;

  Map<String, dynamic> toMap() => {
        'id': id,
        'venda_id': vendaId,
        'produto_nome': produtoNome,
        'produto_categoria': produtoCategoria,
        'preco_unitario': precoUnitario,
        'custo_unitario': custoUnitario,
        'quantidade': quantidade,
      };

  factory ItemVenda.fromMap(Map<String, dynamic> map) => ItemVenda(
        id: map['id'] as int?,
        vendaId: map['venda_id'] as int?,
        produtoNome: map['produto_nome'] as String,
        produtoCategoria: map['produto_categoria'] as String,
        precoUnitario: (map['preco_unitario'] as num).toDouble(),
        custoUnitario: (map['custo_unitario'] as num?)?.toDouble() ?? 0.0,
        quantidade: map['quantidade'] as int,
      );

  factory ItemVenda.fromCarrinho(ItemCarrinho item) => ItemVenda(
        produtoNome: item.produto.nome,
        produtoCategoria: item.produto.categoria,
        precoUnitario: item.produto.preco,
        custoUnitario: item.produto.custo,
        quantidade: item.quantidade,
      );
}

/// Configuração da loja (nome, endereço, impressora).
/// Persistida via shared_preferences.
class ConfiguracaoLoja {
  String nomeLoja;
  String endereco;
  String? impressoraEnderecoMAC;
  String? impressoraNome;
  bool impressaoAtiva;
  int larguraColunas;
  String mensagemRodape;

  ConfiguracaoLoja({
    this.nomeLoja = 'PADARIA',
    this.endereco = 'Ribeirão Preto - SP',
    this.impressoraEnderecoMAC,
    this.impressoraNome,
    this.impressaoAtiva = false,
    this.larguraColunas = 32,
    this.mensagemRodape = 'Obrigado pela preferência!',
  });
}

/// Turno de caixa — abre quando começa o expediente, fecha no fim.
/// Sem um turno aberto, vendas não podem ser finalizadas.
class CaixaTurno {
  final int? id;
  final DateTime abertura;
  final DateTime? fechamento;
  final double valorAbertura; // troco inicial
  final double? valorFechamentoEsperado; // calculado no fechamento
  final double? valorFechamentoInformado; // o que a pessoa contou
  final String operador;
  final String observacao;

  CaixaTurno({
    this.id,
    required this.abertura,
    this.fechamento,
    required this.valorAbertura,
    this.valorFechamentoEsperado,
    this.valorFechamentoInformado,
    this.operador = '',
    this.observacao = '',
  });

  bool get aberto => fechamento == null;

  /// Diferença = real − esperado. Negativo = faltou, positivo = sobrou.
  double? get diferenca {
    if (valorFechamentoEsperado == null || valorFechamentoInformado == null) {
      return null;
    }
    return valorFechamentoInformado! - valorFechamentoEsperado!;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'abertura': abertura.toIso8601String(),
        'fechamento': fechamento?.toIso8601String(),
        'valor_abertura': valorAbertura,
        'valor_fechamento_esperado': valorFechamentoEsperado,
        'valor_fechamento_informado': valorFechamentoInformado,
        'operador': operador,
        'observacao': observacao,
      };

  factory CaixaTurno.fromMap(Map<String, dynamic> map) => CaixaTurno(
        id: map['id'] as int?,
        abertura: DateTime.parse(map['abertura'] as String),
        fechamento: map['fechamento'] == null
            ? null
            : DateTime.parse(map['fechamento'] as String),
        valorAbertura: (map['valor_abertura'] as num).toDouble(),
        valorFechamentoEsperado:
            (map['valor_fechamento_esperado'] as num?)?.toDouble(),
        valorFechamentoInformado:
            (map['valor_fechamento_informado'] as num?)?.toDouble(),
        operador: map['operador'] as String? ?? '',
        observacao: map['observacao'] as String? ?? '',
      );
}

/// Sangria (saída) ou Suprimento (entrada extra) durante o turno.
/// Tipo guardado como String pra extensibilidade (e legibilidade do banco).
class MovimentoCaixa {
  final int? id;
  final int caixaId;
  final DateTime data;
  final String tipo; // "sangria" | "suprimento"
  final double valor;
  final String descricao;

  MovimentoCaixa({
    this.id,
    required this.caixaId,
    required this.data,
    required this.tipo,
    required this.valor,
    this.descricao = '',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'caixa_id': caixaId,
        'data': data.toIso8601String(),
        'tipo': tipo,
        'valor': valor,
        'descricao': descricao,
      };

  factory MovimentoCaixa.fromMap(Map<String, dynamic> map) => MovimentoCaixa(
        id: map['id'] as int?,
        caixaId: map['caixa_id'] as int,
        data: DateTime.parse(map['data'] as String),
        tipo: map['tipo'] as String,
        valor: (map['valor'] as num).toDouble(),
        descricao: map['descricao'] as String? ?? '',
      );
}

/// Registro operacional unifica perdas e produção em uma só tabela.
/// `tipo` discrimina ("perda" ou "producao"). Mantém schema simples
/// e simétrico — ambos têm produto + quantidade + data.
///
/// Pra o modelo Newsvendor, esses dois eventos juntos fecham a equação:
///   produced − sold − wasted ≈ 0
class RegistroOperacional {
  final int? id;
  final int produtoId;
  final String produtoNome;
  final String produtoCategoria;
  final String tipo; // "perda" | "producao"
  final int quantidade;
  final double custoUnitario;
  final DateTime data;
  final String observacao;

  RegistroOperacional({
    this.id,
    required this.produtoId,
    required this.produtoNome,
    required this.produtoCategoria,
    required this.tipo,
    required this.quantidade,
    this.custoUnitario = 0.0,
    required this.data,
    this.observacao = '',
  });

  double get custoTotal => custoUnitario * quantidade;

  Map<String, dynamic> toMap() => {
        'id': id,
        'produto_id': produtoId,
        'produto_nome': produtoNome,
        'produto_categoria': produtoCategoria,
        'tipo': tipo,
        'quantidade': quantidade,
        'custo_unitario': custoUnitario,
        'data': data.toIso8601String(),
        'observacao': observacao,
      };

  factory RegistroOperacional.fromMap(Map<String, dynamic> map) =>
      RegistroOperacional(
        id: map['id'] as int?,
        produtoId: map['produto_id'] as int,
        produtoNome: map['produto_nome'] as String,
        produtoCategoria: map['produto_categoria'] as String,
        tipo: map['tipo'] as String,
        quantidade: map['quantidade'] as int,
        custoUnitario: (map['custo_unitario'] as num?)?.toDouble() ?? 0.0,
        data: DateTime.parse(map['data'] as String),
        observacao: map['observacao'] as String? ?? '',
      );
}

/// Níveis de acesso. Hierárquico — admin engloba operador, operador
/// engloba funcionário. As permissões em ServicoSessao usam essa ordem.
enum NivelUsuario {
  funcionario, // só bate ponto
  operador,    // bate ponto + caixa/vendas/histórico/perdas/produção
  admin;       // tudo + produtos + usuários + configurações

  /// Nome humano pra mostrar na UI.
  String get rotulo {
    switch (this) {
      case NivelUsuario.funcionario:
        return 'Funcionário (só ponto)';
      case NivelUsuario.operador:
        return 'Operador (ponto + caixa)';
      case NivelUsuario.admin:
        return 'Administrador';
    }
  }

  static NivelUsuario fromString(String s) {
    return NivelUsuario.values.firstWhere(
      (n) => n.name == s,
      orElse: () => NivelUsuario.funcionario,
    );
  }
}

/// Funções (cargos) que um funcionário pode exercer durante o expediente.
/// Não é um nível de acesso — é o cargo do dia. O admin define quais
/// funções cada usuário pode escolher ao bater o ponto.
class FuncoesDisponiveis {
  static const caixa = 'Caixa';
  static const cozinheiro = 'Cozinheiro';
  static const padeiro = 'Padeiro';
  static const atendente = 'Atendente';
  static const faxineiro = 'Faxineiro';
  static const entregador = 'Entregador';
  static const gerente = 'Gerente';

  static const todas = <String>[
    caixa,
    cozinheiro,
    padeiro,
    atendente,
    faxineiro,
    entregador,
    gerente,
  ];
}

/// Usuário do sistema.
///
/// A "senha" são 4 dígitos numéricos. Pra padaria pequena com tablet
/// compartilhado isso é mais um controle de identificação ("quem fez
/// essa venda") do que segurança criptográfica. Por isso é armazenada
/// como texto simples — pra MVP é aceitável; pra v2 troca por hash.
///
/// `funcoesPermitidas` é a lista de cargos que esse usuário pode
/// escolher ao bater o ponto. Default: ['Caixa']. Admin pode liberar
/// múltiplas. Ex: padeiro de manhã, atendente à tarde.
class Usuario {
  final int? id;
  final String nome;
  final String senha; // 4 dígitos, ex: "1234"
  final NivelUsuario nivel;
  final bool ativo;
  final List<String> funcoesPermitidas;

  Usuario({
    this.id,
    required this.nome,
    required this.senha,
    required this.nivel,
    this.ativo = true,
    List<String>? funcoesPermitidas,
  }) : funcoesPermitidas = funcoesPermitidas == null || funcoesPermitidas.isEmpty
            ? const [FuncoesDisponiveis.caixa]
            : funcoesPermitidas;

  /// Iniciais pra mostrar como avatar no login. "João Silva" → "JS".
  String get iniciais {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes.first[0] + partes.last[0]).toUpperCase();
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'nome': nome,
        'senha': senha,
        'nivel': nivel.name,
        'ativo': ativo ? 1 : 0,
        // Lista serializada como CSV simples. Como os nomes de função
        // não contêm vírgula, é seguro.
        'funcoes_permitidas': funcoesPermitidas.join(','),
      };

  factory Usuario.fromMap(Map<String, dynamic> map) {
    final csv = (map['funcoes_permitidas'] as String?) ?? '';
    final funcoes = csv
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return Usuario(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      senha: map['senha'] as String,
      nivel: NivelUsuario.fromString(map['nivel'] as String),
      ativo: (map['ativo'] as int? ?? 1) == 1,
      funcoesPermitidas: funcoes.isEmpty ? null : funcoes,
    );
  }

  Usuario copyWith({
    int? id,
    String? nome,
    String? senha,
    NivelUsuario? nivel,
    bool? ativo,
    List<String>? funcoesPermitidas,
  }) =>
      Usuario(
        id: id ?? this.id,
        nome: nome ?? this.nome,
        senha: senha ?? this.senha,
        nivel: nivel ?? this.nivel,
        ativo: ativo ?? this.ativo,
        funcoesPermitidas: funcoesPermitidas ?? this.funcoesPermitidas,
      );
}

/// Registro de ponto — entrada ou saída de um funcionário.
/// O sistema alterna automaticamente: se a última batida foi 'entrada',
/// a próxima vira 'saida' e vice-versa.
///
/// `funcao` é o cargo exercido naquele turno (ex: Caixa, Cozinheiro).
/// `automatica` = true marca saídas geradas pelo sistema às 4h da manhã
/// pra fechar entradas esquecidas.
class RegistroPonto {
  final int? id;
  final int usuarioId;
  final String usuarioNome; // snapshot — preserva histórico se nome mudar
  final String tipo; // "entrada" | "saida"
  final String funcao; // cargo exercido no turno
  final DateTime data;
  final bool automatica;

  RegistroPonto({
    this.id,
    required this.usuarioId,
    required this.usuarioNome,
    required this.tipo,
    this.funcao = FuncoesDisponiveis.caixa,
    required this.data,
    this.automatica = false,
  });

  bool get ehEntrada => tipo == 'entrada';

  Map<String, dynamic> toMap() => {
        'id': id,
        'usuario_id': usuarioId,
        'usuario_nome': usuarioNome,
        'tipo': tipo,
        'funcao': funcao,
        'data': data.toIso8601String(),
        'automatica': automatica ? 1 : 0,
      };

  factory RegistroPonto.fromMap(Map<String, dynamic> map) => RegistroPonto(
        id: map['id'] as int?,
        usuarioId: map['usuario_id'] as int,
        usuarioNome: map['usuario_nome'] as String,
        tipo: map['tipo'] as String,
        funcao: (map['funcao'] as String?) ?? FuncoesDisponiveis.caixa,
        data: DateTime.parse(map['data'] as String),
        automatica: (map['automatica'] as int? ?? 0) == 1,
      );
}

/// Turno = par (entrada + saída opcional) derivado dos RegistroPonto.
/// É uma view, não tem tabela. Útil pra mostrar tabela "Função/Dia/Entrada/Saída"
/// sem precisar pareá-los na tela.
///
/// Se `saida` for null, o turno está em andamento. Se `saida.automatica`
/// for true, o sistema fechou esse turno automaticamente às 4h.
class Turno {
  final RegistroPonto entrada;
  final RegistroPonto? saida;

  Turno({required this.entrada, this.saida});

  String get funcao => entrada.funcao;
  DateTime get inicio => entrada.data;
  DateTime? get fim => saida?.data;

  /// Duração em minutos, ou null se ainda aberto.
  int? get duracaoMinutos {
    if (saida == null) return null;
    return saida!.data.difference(entrada.data).inMinutes;
  }

  bool get aberto => saida == null;
  bool get fechadoAutomaticamente => saida?.automatica ?? false;
}
