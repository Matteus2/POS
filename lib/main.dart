import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'models/models.dart';
import 'screens/tela_login.dart';
import 'services/banco_dados.dart';
import 'services/servico_impressora.dart';

/// Coleta de erros de inicialização — se algo falhar, mostra na tela
/// em vez de deixar tela preta.
final List<String> _errosInit = [];

void main() async {
  // Captura erros de framework e os mostra também
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _errosInit.add('Flutter: ${details.exceptionAsString()}');
  };

  // CADA inicialização agora tem try/catch independente. Se uma falhar,
  // as outras tentam, e o runApp() é chamado de qualquer jeito.
  // Sem isso, qualquer exception aqui causa a famigerada "tela preta da morte"
  // — o app abre mas runApp() nunca foi chamado, então não há UI pra desenhar.

  try {
    await initializeDateFormatting('pt_BR', null);
  } catch (e) {
    _errosInit.add('Locale pt_BR: $e');
    // Fallback silencioso: o app vai mostrar datas em formato default.
  }

  try {
    await _seedAdminPadrao();
  } catch (e) {
    _errosInit.add('Admin padrão: $e');
  }

  try {
    await BancoDados.executarAutoFechamentoPontos();
  } catch (e) {
    _errosInit.add('Auto-fechamento: $e');
  }

  try {
    ServicoImpressora().reconectarUltima();
  } catch (e) {
    _errosInit.add('Impressora: $e');
  }

  // runApp SEMPRE roda, mesmo se todas as inicializações falharam.
  runApp(PadariaPOSApp(errosInit: _errosInit));
}

/// Cria um usuário admin padrão (Admin / 0000) se o banco de usuários
/// estiver vazio. Pensado como "chave reserva" pra primeira instalação.
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
  final List<String> errosInit;
  const PadariaPOSApp({super.key, this.errosInit = const []});

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
      // Se houve erro grave (banco não abriu, etc.), mostra tela de
      // diagnóstico. Caso contrário, fluxo normal.
      home: errosInit.isEmpty
          ? const TelaLogin()
          : TelaErroInicializacao(erros: errosInit),
    );
  }
}

/// Tela que aparece quando há erros de inicialização. Em vez de tela
/// preta silenciosa, mostra o que deu errado e dá um botão pra tentar
/// abrir o app mesmo assim (alguns erros são não-fatais).
class TelaErroInicializacao extends StatelessWidget {
  final List<String> erros;
  const TelaErroInicializacao({super.key, required this.erros});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inicialização')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 64, color: Colors.orange),
              const SizedBox(height: 12),
              const Text(
                'Avisos de inicialização',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Algumas funcionalidades podem estar limitadas. '
                'Você pode tentar abrir o app mesmo assim.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: erros
                          .map((e) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  '• $e',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontFamily: 'monospace'),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const TelaLogin()),
                  );
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Abrir mesmo assim'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
