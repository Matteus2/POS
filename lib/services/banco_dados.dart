import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

/// Persistência. Schema relacional pra suportar
/// o pipeline de análise/forecasting.
///
/// Tabelas:
///   produtos              — catálogo (com custo/COGS)
///   vendas                — uma linha por venda finalizada (com estorno, troco, caixa_id)
///   itens_venda           — N linhas por venda
///   caixas                — abertura/fechamento de turno
///   movimentos_caixa      — sangrias e suprimentos
///   registros_operacionais — perdas e produção (feature ML)
class BancoDados {
  static Database? _database;
  static const int _versaoSchema = 6;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _inicializar();
    return _database!;
  }

  static Future<Database> _inicializar() async {
    final caminhoBanco = await getDatabasesPath();
    return openDatabase(
      join(caminhoBanco, 'padaria_pos.db'),
      version: _versaoSchema,
      onCreate: _criarSchema,
      onUpgrade: _migrar,
    );
  }

  static Future<void> _criarSchema(Database db, int version) async {
    // ── Produtos ───────────────────────────────────────────
    await db.execute('''
      CREATE TABLE produtos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        categoria TEXT NOT NULL,
        preco REAL NOT NULL,
        custo REAL NOT NULL DEFAULT 0,
        cor INTEGER NOT NULL
      )
    ''');

    // ── Caixas (turnos) ────────────────────────────────────
    await db.execute('''
      CREATE TABLE caixas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        abertura TEXT NOT NULL,
        fechamento TEXT,
        valor_abertura REAL NOT NULL,
        valor_fechamento_esperado REAL,
        valor_fechamento_informado REAL,
        operador TEXT NOT NULL DEFAULT '',
        observacao TEXT NOT NULL DEFAULT ''
      )
    ''');

    // ── Vendas (cabeçalho) ─────────────────────────────────
    await db.execute('''
      CREATE TABLE vendas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        data TEXT NOT NULL,
        total REAL NOT NULL,
        pagamento TEXT NOT NULL,
        valor_recebido REAL NOT NULL DEFAULT 0,
        troco REAL NOT NULL DEFAULT 0,
        caixa_id INTEGER,
        estorno INTEGER NOT NULL DEFAULT 0,
        venda_original_id INTEGER,
        FOREIGN KEY(caixa_id) REFERENCES caixas(id),
        FOREIGN KEY(venda_original_id) REFERENCES vendas(id)
      )
    ''');

    // ── Itens da venda ─────────────────────────────────────
    await db.execute('''
      CREATE TABLE itens_venda(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        venda_id INTEGER NOT NULL,
        produto_nome TEXT NOT NULL,
        produto_categoria TEXT NOT NULL,
        preco_unitario REAL NOT NULL,
        custo_unitario REAL NOT NULL DEFAULT 0,
        quantidade INTEGER NOT NULL,
        FOREIGN KEY(venda_id) REFERENCES vendas(id) ON DELETE CASCADE
      )
    ''');

    // ── Movimentos de caixa (sangrias/suprimentos) ─────────
    await db.execute('''
      CREATE TABLE movimentos_caixa(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        caixa_id INTEGER NOT NULL,
        data TEXT NOT NULL,
        tipo TEXT NOT NULL,
        valor REAL NOT NULL,
        descricao TEXT NOT NULL DEFAULT '',
        FOREIGN KEY(caixa_id) REFERENCES caixas(id) ON DELETE CASCADE
      )
    ''');

    // ── Registros operacionais (perdas + produção) ─────────
    await db.execute('''
      CREATE TABLE registros_operacionais(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        produto_id INTEGER NOT NULL,
        produto_nome TEXT NOT NULL,
        produto_categoria TEXT NOT NULL,
        tipo TEXT NOT NULL,
        quantidade INTEGER NOT NULL,
        custo_unitario REAL NOT NULL DEFAULT 0,
        data TEXT NOT NULL,
        observacao TEXT NOT NULL DEFAULT ''
      )
    ''');

    // ── Usuários ───────────────────────────────────────────
    await db.execute('''
      CREATE TABLE usuarios(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        senha TEXT NOT NULL,
        nivel TEXT NOT NULL,
        ativo INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // ── Pontos (entrada/saída) ─────────────────────────────
    await db.execute('''
      CREATE TABLE pontos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER NOT NULL,
        usuario_nome TEXT NOT NULL,
        tipo TEXT NOT NULL,
        data TEXT NOT NULL,
        FOREIGN KEY(usuario_id) REFERENCES usuarios(id)
      )
    ''');

    // Índices pra consultas analíticas
    await db.execute('CREATE INDEX idx_vendas_data ON vendas(data)');
    await db.execute('CREATE INDEX idx_vendas_caixa ON vendas(caixa_id)');
    await db.execute('CREATE INDEX idx_itens_venda_id ON itens_venda(venda_id)');
    await db.execute('CREATE INDEX idx_mov_caixa ON movimentos_caixa(caixa_id)');
    await db.execute('CREATE INDEX idx_reg_op_data ON registros_operacionais(data)');
    await db.execute('CREATE INDEX idx_reg_op_tipo ON registros_operacionais(tipo)');
    await db.execute('CREATE INDEX idx_pontos_usuario ON pontos(usuario_id)');
    await db.execute('CREATE INDEX idx_pontos_data ON pontos(data)');
  }

  static Future<void> _migrar(
      Database db, int versaoAntiga, int versaoNova) async {
    if (versaoAntiga < 2) {
      await db.execute('DROP TABLE IF EXISTS vendas');
      await db.execute('DROP TABLE IF EXISTS produtos');
      await db.execute('DROP TABLE IF EXISTS itens_venda');
      await _criarSchema(db, versaoNova);
      return;
    }
    if (versaoAntiga < 3) {
      await db.execute(
          'ALTER TABLE produtos ADD COLUMN custo REAL NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE vendas ADD COLUMN valor_recebido REAL NOT NULL DEFAULT 0');
      await db.execute(
          'ALTER TABLE vendas ADD COLUMN troco REAL NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE vendas ADD COLUMN caixa_id INTEGER');
      await db.execute(
          'ALTER TABLE vendas ADD COLUMN estorno INTEGER NOT NULL DEFAULT 0');
      await db
          .execute('ALTER TABLE vendas ADD COLUMN venda_original_id INTEGER');
      await db.execute(
          'ALTER TABLE itens_venda ADD COLUMN custo_unitario REAL NOT NULL DEFAULT 0');

      await db.execute('''
        CREATE TABLE caixas(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          abertura TEXT NOT NULL,
          fechamento TEXT,
          valor_abertura REAL NOT NULL,
          valor_fechamento_esperado REAL,
          valor_fechamento_informado REAL,
          operador TEXT NOT NULL DEFAULT '',
          observacao TEXT NOT NULL DEFAULT ''
        )
      ''');
      await db.execute('''
        CREATE TABLE movimentos_caixa(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          caixa_id INTEGER NOT NULL,
          data TEXT NOT NULL,
          tipo TEXT NOT NULL,
          valor REAL NOT NULL,
          descricao TEXT NOT NULL DEFAULT '',
          FOREIGN KEY(caixa_id) REFERENCES caixas(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('''
        CREATE TABLE registros_operacionais(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          produto_id INTEGER NOT NULL,
          produto_nome TEXT NOT NULL,
          produto_categoria TEXT NOT NULL,
          tipo TEXT NOT NULL,
          quantidade INTEGER NOT NULL,
          custo_unitario REAL NOT NULL DEFAULT 0,
          data TEXT NOT NULL,
          observacao TEXT NOT NULL DEFAULT ''
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_vendas_caixa ON vendas(caixa_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_mov_caixa ON movimentos_caixa(caixa_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_reg_op_data ON registros_operacionais(data)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_reg_op_tipo ON registros_operacionais(tipo)');
    }
    if (versaoAntiga < 4) {
      // Schema v4 — sistema de usuários e ponto
      await db.execute('''
        CREATE TABLE IF NOT EXISTS usuarios(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          nome TEXT NOT NULL,
          senha TEXT NOT NULL,
          nivel TEXT NOT NULL,
          ativo INTEGER NOT NULL DEFAULT 1
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS pontos(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          usuario_id INTEGER NOT NULL,
          usuario_nome TEXT NOT NULL,
          tipo TEXT NOT NULL,
          data TEXT NOT NULL,
          FOREIGN KEY(usuario_id) REFERENCES usuarios(id)
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_pontos_usuario ON pontos(usuario_id)');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_pontos_data ON pontos(data)');
    }
    if (versaoAntiga < 5) {
      // Schema v5 — schema-heal defensivo.
      // Versões antigas do APK podem ter criado tabelas com schema incompleto
      // (ex: faltando 'estorno' em vendas, 'valor_fechamento_esperado' em caixas).
      // Aqui verificamos cada coluna esperada e adicionamos as que faltam.
      // É idempotente — pode rodar várias vezes sem dano.
      await _schemaHeal(db);
    }
    if (versaoAntiga < 6) {
      // Schema v6 — funções múltiplas + cargo no ponto.
      await _schemaHeal(db);
    }
  }

  /// Garante que toda tabela tem todas as colunas que o código espera.
  /// Verifica via PRAGMA table_info e ALTER TABLE só pra colunas faltantes.
  static Future<void> _schemaHeal(Database db) async {
    // produtos
    await _garantirColuna(
        db, 'produtos', 'custo', 'REAL NOT NULL DEFAULT 0');

    // vendas — colunas adicionadas em v3 que podem estar faltando
    await _garantirColuna(
        db, 'vendas', 'valor_recebido', 'REAL NOT NULL DEFAULT 0');
    await _garantirColuna(
        db, 'vendas', 'troco', 'REAL NOT NULL DEFAULT 0');
    await _garantirColuna(db, 'vendas', 'caixa_id', 'INTEGER');
    await _garantirColuna(
        db, 'vendas', 'estorno', 'INTEGER NOT NULL DEFAULT 0');
    await _garantirColuna(db, 'vendas', 'venda_original_id', 'INTEGER');

    // itens_venda
    await _garantirColuna(
        db, 'itens_venda', 'custo_unitario', 'REAL NOT NULL DEFAULT 0');

    // caixas — colunas de fechamento que podem estar faltando
    await _garantirTabelaCaixas(db);
    await _garantirColuna(
        db, 'caixas', 'valor_fechamento_esperado', 'REAL');
    await _garantirColuna(
        db, 'caixas', 'valor_fechamento_informado', 'REAL');
    await _garantirColuna(
        db, 'caixas', 'operador', "TEXT NOT NULL DEFAULT ''");
    await _garantirColuna(
        db, 'caixas', 'observacao', "TEXT NOT NULL DEFAULT ''");

    // movimentos_caixa e registros_operacionais — garantia
    await _garantirTabelaMovimentos(db);
    await _garantirTabelaRegistros(db);
    await _garantirTabelaUsuarios(db);
    await _garantirTabelaPontos(db);

    // v6 — múltiplas funções por usuário, cargo no ponto, flag de auto-fechamento
    await _garantirColuna(
        db, 'usuarios', 'funcoes_permitidas', "TEXT NOT NULL DEFAULT 'Caixa'");
    await _garantirColuna(
        db, 'pontos', 'funcao', "TEXT NOT NULL DEFAULT 'Caixa'");
    await _garantirColuna(
        db, 'pontos', 'automatica', 'INTEGER NOT NULL DEFAULT 0');
  }

  /// Verifica se uma coluna existe na tabela; se não, faz ALTER TABLE.
  /// Tem try/catch porque mesmo com a checagem alguma corrida estranha
  /// poderia disparar erro — preferimos seguir adiante e logar.
  static Future<void> _garantirColuna(
    Database db,
    String tabela,
    String coluna,
    String tipo,
  ) async {
    try {
      final cols = await db.rawQuery('PRAGMA table_info($tabela)');
      final existentes = cols.map((c) => c['name'] as String).toSet();
      if (existentes.contains(coluna)) return;
      await db.execute('ALTER TABLE $tabela ADD COLUMN $coluna $tipo');
    } catch (e) {
      // Se a tabela nem existe, isso falha — mas as funções _garantirTabela*
      // cuidam disso. Aqui só logamos pra debug.
      // ignore: avoid_print
      print('schemaHeal: falha ao garantir $tabela.$coluna: $e');
    }
  }

  static Future<void> _garantirTabelaCaixas(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS caixas(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        abertura TEXT NOT NULL,
        fechamento TEXT,
        valor_abertura REAL NOT NULL,
        valor_fechamento_esperado REAL,
        valor_fechamento_informado REAL,
        operador TEXT NOT NULL DEFAULT '',
        observacao TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  static Future<void> _garantirTabelaMovimentos(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS movimentos_caixa(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        caixa_id INTEGER NOT NULL,
        data TEXT NOT NULL,
        tipo TEXT NOT NULL,
        valor REAL NOT NULL,
        descricao TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  static Future<void> _garantirTabelaRegistros(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS registros_operacionais(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        produto_id INTEGER NOT NULL,
        produto_nome TEXT NOT NULL,
        produto_categoria TEXT NOT NULL,
        tipo TEXT NOT NULL,
        quantidade INTEGER NOT NULL,
        custo_unitario REAL NOT NULL DEFAULT 0,
        data TEXT NOT NULL,
        observacao TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  static Future<void> _garantirTabelaUsuarios(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        senha TEXT NOT NULL,
        nivel TEXT NOT NULL,
        ativo INTEGER NOT NULL DEFAULT 1,
        funcoes_permitidas TEXT NOT NULL DEFAULT 'Caixa'
      )
    ''');
  }

  static Future<void> _garantirTabelaPontos(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS pontos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        usuario_id INTEGER NOT NULL,
        usuario_nome TEXT NOT NULL,
        tipo TEXT NOT NULL,
        funcao TEXT NOT NULL DEFAULT 'Caixa',
        data TEXT NOT NULL,
        automatica INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // ═══════════════════════════════════════════════════════════════
  // PRODUTOS
  // ═══════════════════════════════════════════════════════════════

  static Future<int> inserirProduto(Produto produto) async {
    final db = await database;
    final map = produto.toMap()..remove('id');
    return db.insert('produtos', map);
  }

  static Future<void> atualizarProduto(Produto produto) async {
    final db = await database;
    await db.update(
      'produtos',
      produto.toMap(),
      where: 'id = ?',
      whereArgs: [produto.id],
    );
  }

  static Future<void> removerProduto(int id) async {
    final db = await database;
    await db.delete('produtos', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<Produto>> carregarProdutos() async {
    final db = await database;
    final maps = await db.query('produtos', orderBy: 'categoria, nome');
    return maps.map((m) => Produto.fromMap(m)).toList();
  }

  // ═══════════════════════════════════════════════════════════════
  // VENDAS — transação atômica (cabeçalho + itens)
  // ═══════════════════════════════════════════════════════════════

  static Future<int> salvarVenda(Venda venda) async {
    final db = await database;
    return await db.transaction((txn) async {
      final vendaMap = venda.toMap()..remove('id');
      final vendaId = await txn.insert('vendas', vendaMap);

      for (var item in venda.itens) {
        final itemMap = item.toMap();
        itemMap['venda_id'] = vendaId;
        itemMap.remove('id');
        await txn.insert('itens_venda', itemMap);
      }

      return vendaId;
    });
  }

  /// Estorno: cria uma venda nova com total negativo e quantidades negativas,
  /// apontando pra venda original. NÃO deleta a original — preserva histórico,
  /// igual lançamento contábil (erros viram contra-lançamentos, não rasuras).
  static Future<int> estornarVenda(Venda original, {int? caixaId}) async {
    final db = await database;
    return await db.transaction((txn) async {
      final estornoId = await txn.insert('vendas', {
        'data': DateTime.now().toIso8601String(),
        'total': -original.total,
        'pagamento': original.formaPagamento,
        'valor_recebido': 0,
        'troco': 0,
        'caixa_id': caixaId,
        'estorno': 1,
        'venda_original_id': original.id,
      });

      for (var item in original.itens) {
        await txn.insert('itens_venda', {
          'venda_id': estornoId,
          'produto_nome': item.produtoNome,
          'produto_categoria': item.produtoCategoria,
          'preco_unitario': item.precoUnitario,
          'custo_unitario': item.custoUnitario,
          'quantidade': -item.quantidade,
        });
      }
      return estornoId;
    });
  }

  /// True se a venda já tem um estorno registrado.
  static Future<bool> vendaPossuiEstorno(int vendaId) async {
    final db = await database;
    final result = await db.query(
      'vendas',
      where: 'venda_original_id = ?',
      whereArgs: [vendaId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  static Future<List<Venda>> carregarVendas({
    int limite = 100,
    DateTime? desde,
    DateTime? ate,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <dynamic>[];
    if (desde != null) {
      where.add('data >= ?');
      args.add(desde.toIso8601String());
    }
    if (ate != null) {
      where.add('data < ?');
      args.add(ate.toIso8601String());
    }

    final vendasMaps = await db.query(
      'vendas',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'data DESC',
      limit: limite,
    );

    final vendas = <Venda>[];
    for (var vendaMap in vendasMaps) {
      final itensMaps = await db.query(
        'itens_venda',
        where: 'venda_id = ?',
        whereArgs: [vendaMap['id']],
      );
      final itens = itensMaps.map((m) => ItemVenda.fromMap(m)).toList();
      vendas.add(Venda.fromMap(vendaMap, itens: itens));
    }
    return vendas;
  }

  static Future<List<Venda>> carregarVendasHoje() async {
    final hoje = DateTime.now();
    final inicio = DateTime(hoje.year, hoje.month, hoje.day);
    final fim = inicio.add(const Duration(days: 1));
    return carregarVendas(desde: inicio, ate: fim, limite: 1000);
  }

  /// Vendas associadas a um turno de caixa específico.
  static Future<List<Venda>> carregarVendasDoCaixa(int caixaId) async {
    final db = await database;
    final vendasMaps = await db.query(
      'vendas',
      where: 'caixa_id = ?',
      whereArgs: [caixaId],
      orderBy: 'data DESC',
    );
    final vendas = <Venda>[];
    for (var vendaMap in vendasMaps) {
      final itensMaps = await db.query(
        'itens_venda',
        where: 'venda_id = ?',
        whereArgs: [vendaMap['id']],
      );
      final itens = itensMaps.map((m) => ItemVenda.fromMap(m)).toList();
      vendas.add(Venda.fromMap(vendaMap, itens: itens));
    }
    return vendas;
  }

  // ═══════════════════════════════════════════════════════════════
  // CAIXA (turnos)
  // ═══════════════════════════════════════════════════════════════

  /// Retorna o caixa em aberto, se houver (só pode existir 1).
  static Future<CaixaTurno?> carregarCaixaAberto() async {
    final db = await database;
    final maps = await db.query(
      'caixas',
      where: 'fechamento IS NULL',
      orderBy: 'abertura DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return CaixaTurno.fromMap(maps.first);
  }

  static Future<int> abrirCaixa({
    required double valorAbertura,
    String operador = '',
  }) async {
    final db = await database;
    return db.insert('caixas', {
      'abertura': DateTime.now().toIso8601String(),
      'valor_abertura': valorAbertura,
      'operador': operador,
      'observacao': '',
    });
  }

  static Future<void> fecharCaixa({
    required int caixaId,
    required double valorFechamentoInformado,
    String? observacao,
  }) async {
    final db = await database;
    // Calcula o esperado agora pra travar o snapshot
    final caixaMap = await db.query(
      'caixas',
      where: 'id = ?',
      whereArgs: [caixaId],
      limit: 1,
    );
    if (caixaMap.isEmpty) return;
    final caixa = CaixaTurno.fromMap(caixaMap.first);

    final dinheiro = await _totalDinheiroDoCaixa(caixaId);
    final movs = await carregarMovimentosCaixa(caixaId);
    final suprimentos = movs
        .where((m) => m.tipo == 'suprimento')
        .fold<double>(0, (s, m) => s + m.valor);
    final sangrias = movs
        .where((m) => m.tipo == 'sangria')
        .fold<double>(0, (s, m) => s + m.valor);
    final esperado =
        caixa.valorAbertura + dinheiro + suprimentos - sangrias;

    await db.update(
      'caixas',
      {
        'fechamento': DateTime.now().toIso8601String(),
        'valor_fechamento_esperado': esperado,
        'valor_fechamento_informado': valorFechamentoInformado,
        'observacao': observacao ?? '',
      },
      where: 'id = ?',
      whereArgs: [caixaId],
    );
  }

  static Future<double> _totalDinheiroDoCaixa(int caixaId) async {
    final db = await database;
    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(total), 0) AS soma FROM vendas
      WHERE caixa_id = ? AND pagamento = ?
      ''',
      [caixaId, 'Dinheiro'],
    );
    return (result.first['soma'] as num).toDouble();
  }

  static Future<List<CaixaTurno>> historicoCaixas({int limite = 30}) async {
    final db = await database;
    final maps = await db.query(
      'caixas',
      orderBy: 'abertura DESC',
      limit: limite,
    );
    return maps.map((m) => CaixaTurno.fromMap(m)).toList();
  }

  // ── Movimentos (sangria/suprimento) ────────────────────────────

  static Future<int> salvarMovimentoCaixa(MovimentoCaixa mov) async {
    final db = await database;
    final map = mov.toMap()..remove('id');
    return db.insert('movimentos_caixa', map);
  }

  static Future<List<MovimentoCaixa>> carregarMovimentosCaixa(
      int caixaId) async {
    final db = await database;
    final maps = await db.query(
      'movimentos_caixa',
      where: 'caixa_id = ?',
      whereArgs: [caixaId],
      orderBy: 'data ASC',
    );
    return maps.map((m) => MovimentoCaixa.fromMap(m)).toList();
  }

  // ═══════════════════════════════════════════════════════════════
  // REGISTROS OPERACIONAIS — Perdas e Produção (feature ML)
  // ═══════════════════════════════════════════════════════════════

  static Future<int> salvarRegistroOperacional(
      RegistroOperacional registro) async {
    final db = await database;
    final map = registro.toMap()..remove('id');
    return db.insert('registros_operacionais', map);
  }

  static Future<void> removerRegistroOperacional(int id) async {
    final db = await database;
    await db
        .delete('registros_operacionais', where: 'id = ?', whereArgs: [id]);
  }

  /// Lista todos (ou filtrados por data/tipo).
  static Future<List<RegistroOperacional>> carregarRegistrosOperacionais({
    String? tipo,
    DateTime? desde,
    DateTime? ate,
    int limite = 500,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <dynamic>[];
    if (tipo != null) {
      where.add('tipo = ?');
      args.add(tipo);
    }
    if (desde != null) {
      where.add('data >= ?');
      args.add(desde.toIso8601String());
    }
    if (ate != null) {
      where.add('data < ?');
      args.add(ate.toIso8601String());
    }
    final maps = await db.query(
      'registros_operacionais',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'data DESC',
      limit: limite,
    );
    return maps.map((m) => RegistroOperacional.fromMap(m)).toList();
  }

  // ═══════════════════════════════════════════════════════════════
  // EXPORT CSV — formato consumido pelo pipeline de ML
  // ═══════════════════════════════════════════════════════════════

  /// Exporta vendas (linha por item).
  static Future<String> exportarVendasCSV() async {
    final vendas = await carregarVendas(limite: 100000);
    final buffer = StringBuffer();
    buffer.writeln(
      'date,time,sale_id,product,category,units_sold,unit_price,unit_cost,revenue,margin,payment,refund,refund_of',
    );
    for (var venda in vendas) {
      final s = venda.data.toIso8601String();
      final datePart = s.substring(0, 10);
      final timePart = s.substring(11, 19);
      for (var item in venda.itens) {
        buffer.writeln(
          '$datePart,$timePart,${venda.id ?? ""},'
          '"${item.produtoNome}",${item.produtoCategoria},'
          '${item.quantidade},${item.precoUnitario.toStringAsFixed(2)},'
          '${item.custoUnitario.toStringAsFixed(2)},'
          '${item.subtotal.toStringAsFixed(2)},'
          '${item.margemTotal.toStringAsFixed(2)},'
          '${venda.formaPagamento},'
          '${venda.estorno ? 1 : 0},'
          '${venda.vendaOriginalId ?? ""}',
        );
      }
    }
    return buffer.toString();
  }

  /// Exporta perdas como CSV — alimenta diretamente o Newsvendor.
  static Future<String> exportarPerdasCSV() async {
    final regs = await carregarRegistrosOperacionais(
        tipo: 'perda', limite: 100000);
    final buffer = StringBuffer();
    buffer.writeln('date,time,product,category,units_lost,unit_cost,reason');
    for (var r in regs) {
      final s = r.data.toIso8601String();
      buffer.writeln(
        '${s.substring(0, 10)},${s.substring(11, 19)},'
        '"${r.produtoNome}",${r.produtoCategoria},${r.quantidade},'
        '${r.custoUnitario.toStringAsFixed(2)},"${r.observacao}"',
      );
    }
    return buffer.toString();
  }

  /// Exporta produção como CSV — completa o sistema produced/sold/wasted.
  static Future<String> exportarProducaoCSV() async {
    final regs = await carregarRegistrosOperacionais(
        tipo: 'producao', limite: 100000);
    final buffer = StringBuffer();
    buffer.writeln('date,time,product,category,units_produced');
    for (var r in regs) {
      final s = r.data.toIso8601String();
      buffer.writeln(
        '${s.substring(0, 10)},${s.substring(11, 19)},'
        '"${r.produtoNome}",${r.produtoCategoria},${r.quantidade}',
      );
    }
    return buffer.toString();
  }

  /// Alias de compatibilidade.
  static Future<String> exportarCSV() => exportarVendasCSV();

  // ═══════════════════════════════════════════════════════════════
  // USUÁRIOS
  // ═══════════════════════════════════════════════════════════════

  static Future<int> inserirUsuario(Usuario usuario) async {
    final db = await database;
    final map = usuario.toMap()..remove('id');
    return db.insert('usuarios', map);
  }

  static Future<void> atualizarUsuario(Usuario usuario) async {
    final db = await database;
    await db.update(
      'usuarios',
      usuario.toMap(),
      where: 'id = ?',
      whereArgs: [usuario.id],
    );
  }

  /// Não deleta de fato — só desativa. Preserva o histórico de ponto/vendas.
  static Future<void> desativarUsuario(int id) async {
    final db = await database;
    await db.update(
      'usuarios',
      {'ativo': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Remove de fato — só deve ser usado em casos extremos.
  static Future<void> removerUsuario(int id) async {
    final db = await database;
    await db.delete('usuarios', where: 'id = ?', whereArgs: [id]);
  }

  /// Lista todos os usuários (default: só ativos).
  static Future<List<Usuario>> carregarUsuarios({bool somenteAtivos = true}) async {
    final db = await database;
    final maps = await db.query(
      'usuarios',
      where: somenteAtivos ? 'ativo = 1' : null,
      orderBy: 'nome',
    );
    return maps.map((m) => Usuario.fromMap(m)).toList();
  }

  /// Tenta autenticar por (usuarioId, senha). Retorna o usuário se bater.
  static Future<Usuario?> autenticar(int usuarioId, String senha) async {
    final db = await database;
    final maps = await db.query(
      'usuarios',
      where: 'id = ? AND senha = ? AND ativo = 1',
      whereArgs: [usuarioId, senha],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Usuario.fromMap(maps.first);
  }

  /// Conta quantos admins ativos existem (pra impedir desativar o último).
  static Future<int> contarAdminsAtivos() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM usuarios WHERE nivel = ? AND ativo = 1',
      [NivelUsuario.admin.name],
    );
    return (result.first['c'] as int?) ?? 0;
  }

  // ═══════════════════════════════════════════════════════════════
  // PONTOS (entrada/saída)
  // ═══════════════════════════════════════════════════════════════

  /// Último ponto registrado por um usuário (em qualquer data).
  static Future<RegistroPonto?> ultimoPontoDoUsuario(int usuarioId) async {
    final db = await database;
    final maps = await db.query(
      'pontos',
      where: 'usuario_id = ?',
      whereArgs: [usuarioId],
      orderBy: 'data DESC',
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return RegistroPonto.fromMap(maps.first);
  }

  /// Registra próxima batida — alterna automaticamente baseado na anterior.
  /// `funcao` é o cargo do turno (Caixa, Cozinheiro, etc.). Pra "saída",
  /// herdamos a função da última "entrada" pra que o par fique consistente.
  static Future<RegistroPonto> baterPonto(
    Usuario usuario, {
    required String funcao,
  }) async {
    final ultimo = await ultimoPontoDoUsuario(usuario.id!);
    final tipo =
        (ultimo == null || ultimo.tipo == 'saida') ? 'entrada' : 'saida';
    // Se está saindo, usa a função da entrada (não do dropdown atual)
    final funcaoFinal = (tipo == 'saida' && ultimo != null) ? ultimo.funcao : funcao;
    final registro = RegistroPonto(
      usuarioId: usuario.id!,
      usuarioNome: usuario.nome,
      tipo: tipo,
      funcao: funcaoFinal,
      data: DateTime.now(),
    );
    final db = await database;
    final map = registro.toMap()..remove('id');
    final id = await db.insert('pontos', map);
    return RegistroPonto(
      id: id,
      usuarioId: registro.usuarioId,
      usuarioNome: registro.usuarioNome,
      tipo: registro.tipo,
      funcao: registro.funcao,
      data: registro.data,
      automatica: registro.automatica,
    );
  }

  /// Atualiza o timestamp e função de um ponto existente (admin).
  static Future<void> atualizarPonto(
    int pontoId, {
    DateTime? novaData,
    String? novaFuncao,
    String? novoTipo,
  }) async {
    final db = await database;
    final dados = <String, Object?>{};
    if (novaData != null) dados['data'] = novaData.toIso8601String();
    if (novaFuncao != null) dados['funcao'] = novaFuncao;
    if (novoTipo != null) dados['tipo'] = novoTipo;
    if (dados.isEmpty) return;
    await db.update('pontos', dados, where: 'id = ?', whereArgs: [pontoId]);
  }

  /// Remove um ponto específico (admin — pra corrigir erros de batida).
  static Future<void> removerPonto(int pontoId) async {
    final db = await database;
    await db.delete('pontos', where: 'id = ?', whereArgs: [pontoId]);
  }

  /// Insere um ponto manualmente (admin — pra corrigir ausência).
  static Future<int> inserirPonto(RegistroPonto ponto) async {
    final db = await database;
    final map = ponto.toMap()..remove('id');
    return db.insert('pontos', map);
  }

  /// Pontos de um usuário (default: todos, mais recentes primeiro).
  static Future<List<RegistroPonto>> carregarPontos({
    int? usuarioId,
    DateTime? desde,
    DateTime? ate,
    int limite = 200,
  }) async {
    final db = await database;
    final where = <String>[];
    final args = <dynamic>[];
    if (usuarioId != null) {
      where.add('usuario_id = ?');
      args.add(usuarioId);
    }
    if (desde != null) {
      where.add('data >= ?');
      args.add(desde.toIso8601String());
    }
    if (ate != null) {
      where.add('data < ?');
      args.add(ate.toIso8601String());
    }
    final maps = await db.query(
      'pontos',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'data DESC',
      limit: limite,
    );
    return maps.map((m) => RegistroPonto.fromMap(m)).toList();
  }

  /// Pareia os pontos da SEMANA ATUAL (segunda 00:00 até a próxima
  /// segunda 00:00) em turnos (entrada + saída).
  ///
  /// Algoritmo: percorre os pontos em ordem cronológica crescente,
  /// emparelhando cada 'entrada' com a próxima 'saida' do mesmo usuário.
  /// Se sobrar 'entrada' sem par no fim, é um turno aberto (em andamento).
  static Future<List<Turno>> carregarTurnosDaSemana(int usuarioId) async {
    final agora = DateTime.now();
    // Segunda-feira da semana atual às 00:00.
    // weekday: segunda=1, terça=2, ..., domingo=7
    final inicioSemana = DateTime(agora.year, agora.month, agora.day)
        .subtract(Duration(days: agora.weekday - 1));
    final fimSemana = inicioSemana.add(const Duration(days: 7));

    final db = await database;
    final maps = await db.query(
      'pontos',
      where: 'usuario_id = ? AND data >= ? AND data < ?',
      whereArgs: [
        usuarioId,
        inicioSemana.toIso8601String(),
        fimSemana.toIso8601String(),
      ],
      orderBy: 'data ASC',
    );
    final pontos = maps.map((m) => RegistroPonto.fromMap(m)).toList();

    final turnos = <Turno>[];
    RegistroPonto? entradaPendente;
    for (final p in pontos) {
      if (p.tipo == 'entrada') {
        // Se vier uma entrada com outra ainda pendente, fecha a anterior
        // como turno aberto (sem saída) antes de começar nova.
        if (entradaPendente != null) {
          turnos.add(Turno(entrada: entradaPendente));
        }
        entradaPendente = p;
      } else if (p.tipo == 'saida' && entradaPendente != null) {
        turnos.add(Turno(entrada: entradaPendente, saida: p));
        entradaPendente = null;
      }
    }
    // Sobrou uma entrada sem par no fim?
    if (entradaPendente != null) {
      turnos.add(Turno(entrada: entradaPendente));
    }

    // Mais recentes primeiro (tabela de cima pra baixo).
    return turnos.reversed.toList();
  }

  /// Soma de minutos trabalhados na semana atual.
  static Future<int> minutosTrabalhadosNaSemana(int usuarioId) async {
    final turnos = await carregarTurnosDaSemana(usuarioId);
    var total = 0;
    for (final t in turnos) {
      total += t.duracaoMinutos ?? 0;
    }
    return total;
  }

  /// Auto-fechamento de pontos esquecidos.
  ///
  /// Regra: pra qualquer 'entrada' sem par 'saida' onde a entrada foi
  /// em dia anterior a hoje, o sistema gera uma 'saida' automática às
  /// 04:00 do dia seguinte da entrada.
  ///
  /// Pensamento por trás: assumir que ninguém trabalha de madrugada
  /// passando das 4h — então essa é uma hora "segura" pra cortar o
  /// turno. A flag `automatica` deixa rastro pra auditoria.
  ///
  /// Chamado em main.dart antes do runApp.
  static Future<int> executarAutoFechamentoPontos() async {
    final db = await database;
    final agora = DateTime.now();
    final hojeMeiaNoite =
        DateTime(agora.year, agora.month, agora.day);

    // Pega usuários ativos (incluindo inativos, na verdade — pra fechar
    // pontos de funcionários demitidos com turno em aberto)
    final usuarios = await carregarUsuarios(somenteAtivos: false);
    var fechados = 0;

    for (final u in usuarios) {
      if (u.id == null) continue;

      // Último ponto desse usuário
      final ultimoMaps = await db.query(
        'pontos',
        where: 'usuario_id = ?',
        whereArgs: [u.id],
        orderBy: 'data DESC',
        limit: 1,
      );
      if (ultimoMaps.isEmpty) continue;
      final ultimo = RegistroPonto.fromMap(ultimoMaps.first);

      // Só age se a última batida foi 'entrada' (turno em aberto)
      // e foi em dia ANTERIOR a hoje
      if (ultimo.tipo != 'entrada') continue;
      final diaEntrada = DateTime(
          ultimo.data.year, ultimo.data.month, ultimo.data.day);
      if (!diaEntrada.isBefore(hojeMeiaNoite)) continue;

      // Gera saída automática às 04:00 do dia SEGUINTE da entrada
      final saidaAuto = DateTime(
          diaEntrada.year, diaEntrada.month, diaEntrada.day + 1, 4, 0, 0);

      await db.insert('pontos', {
        'usuario_id': u.id,
        'usuario_nome': u.nome,
        'tipo': 'saida',
        'funcao': ultimo.funcao,
        'data': saidaAuto.toIso8601String(),
        'automatica': 1,
      });
      fechados++;
    }
    return fechados;
  }

  /// Exporta pontos como CSV — pra folha de pagamento ou conferência.
  static Future<String> exportarPontosCSV() async {
    final pontos = await carregarPontos(limite: 100000);
    final buffer = StringBuffer();
    buffer.writeln('date,time,user_id,user_name,type');
    for (var p in pontos) {
      final s = p.data.toIso8601String();
      buffer.writeln(
        '${s.substring(0, 10)},${s.substring(11, 19)},'
        '${p.usuarioId},"${p.usuarioNome}",${p.tipo}',
      );
    }
    return buffer.toString();
  }
}
