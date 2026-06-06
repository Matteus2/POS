import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'models/models.dart';
import 'screens/tela_login.dart';
import 'services/banco_dados.dart';
import 'services/servico_impressora.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Carrega símbolos de data em português (dia da semana abreviado etc.)
  await initializeDateFormatting('pt_BR', null);

  // Garante que existe pelo menos 1 admin antes de mostrar a tela de login.
  // Sem isso, na primeira instalação não teria ninguém pra entrar.
  await _seedAdminPadrao();

  // Auto-fecha pontos esquecidos do dia anterior (saída às 04:00).
  // Analogia: é o porteiro que faz a ronda de madrugada e tranca as
  // portas que o pessoal deixou abertas — depois o gerente vê os
  // registros e decide se ajusta na mão.
  try {
    await BancoDados.executarAutoFechamentoPontos();
  } catch (e) {
    // ignore: avoid_print
    print('Auto-fechamento de pontos falhou: $e');
  }

  // Reconecta impressora silenciosamente (não bloqueia a UI).
  ServicoImpressora().reconectarUltima();

  runApp(const PadariaPOSApp());
}

/// Cria um usuário admin padrão (Admin / 0000) se o banco de usuários
/// estiver vazio. Pensado como "chave reserva" pra primeira instalação —
/// o sócio que entrega o tablet pode usar essa senha pra cadastrar o
/// admin real do cliente e depois desativá-la.
Future<void> _seedAdminPadrao() async {
  final usuarios = await BancoDados.carregarUsuarios(somenteAtivos: false);
  if (usuarios.isNotEmpty) return;
  await BancoDados.inserirUsuario(
    Usuario(
      nome: 'Admin',
      senha: '0000',
      nivel: NivelUsuario.admin,
    ),
  );
}

class PadariaPOSApp extends StatelessWidget {
  const PadariaPOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Padaria POS',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5D3A1A),
          primary: const Color(0xFF5D3A1A),
          secondary: const Color(0xFFD4A24C),
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFFAF5EB),
        fontFamily: 'Roboto',
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF5D3A1A),
          foregroundColor: Color(0xFFF4D78A),
          centerTitle: true,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      home: const TelaLogin(),
    );
  }
}
