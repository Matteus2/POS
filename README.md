# Caixa Padaria

PDV (Ponto de Venda) digital pra padarias pequenas no Brasil. Tablet Android substitui calculadora/registradora, funciona offline, registra vendas estruturadas, imprime cupom Bluetooth (ESC/POS), e gera dados pro pipeline de previsão de demanda (LightGBM + Newsvendor).

## Funcionalidades

**Operação de loja:**
- Caixa digital com grid de produtos por categoria, carrinho com edição de quantidade, cálculo de troco em tempo real
- Abertura/fechamento de turno (sangria, suprimento, conferência com sobra/falta)
- Histórico de vendas com reimpressão de cupom e estorno (lançamento contábil negativo, preserva histórico)
- Cadastro de produtos via UI (preço, custo/COGS, cor, categoria)

**Sistema de usuários:**
- Login por senha de 4 dígitos com seleção visual de usuário
- 3 níveis de acesso: Funcionário (só ponto), Operador (caixa), Admin (tudo)
- Bater ponto com escolha de cargo do dia (Caixa, Cozinheiro, Padeiro, Atendente, Faxineiro, Entregador, Gerente)
- Tabela semanal de turnos visível pro próprio funcionário
- Auto-fechamento de turnos esquecidos às 04:00 do dia seguinte
- Admin edita horários pra corrigir batidas

**Pipeline de ML (alimentação de dados):**
- Custo (COGS) por produto pra cálculo de margem
- Registro de perdas/sobras e produção diária
- Export CSV em três fontes (vendas, perdas, produção) — entrada do modelo Newsvendor

**Resiliência:**
- Schema do banco com auto-cura (PRAGMA table_info + ALTER) — migrações suaves entre versões do APK
- Try/catch em toda operação de banco com snackbar de erro visível

## Stack

- Flutter (Dart) — UI cross-platform, foco em tablet Android
- SQLite via `sqflite` — persistência local relacional
- shared_preferences — config da loja
- `blue_thermal_printer` + `esc_pos_utils_plus` — Bluetooth Classic com impressoras térmicas (stub no MVP, ativado em hardware físico)
- `intl` — formatação de data/hora em pt_BR
- `permission_handler` — permissões Bluetooth no Android 12+

## Como rodar (desenvolvimento)

```bash
flutter pub get
flutter run
```

## Como buildar APK release

```bash
flutter clean
flutter pub get
flutter build apk --release
```

O APK fica em `build/app/outputs/flutter-apk/app-release.apk` (~51 MB).

## Estrutura

```
lib/
├── main.dart                     ← entry point + seed admin + auto-fechamento
├── models/
│   └── models.dart               ← Produto, Venda, ItemVenda, CaixaTurno,
│                                   MovimentoCaixa, RegistroOperacional,
│                                   Usuario, RegistroPonto, Turno
├── services/
│   ├── banco_dados.dart          ← SQLite + schema-heal + export CSV
│   ├── servico_impressora.dart   ← Bluetooth ESC/POS (stub no MVP)
│   ├── servico_sessao.dart       ← usuário ativo + permissões
│   └── servico_config.dart       ← config da loja em SharedPreferences
└── screens/
    ├── tela_login.dart           ← grade de usuários + numpad
    ├── tela_caixa.dart           ← grid de produtos + carrinho + finalização
    ├── tela_produtos.dart        ← CRUD de catálogo
    ├── tela_historico_vendas.dart ← lista + reimpressão + estorno
    ├── tela_operacoes_ml.dart    ← registro de perdas/produção
    ├── tela_ponto.dart           ← bater ponto + tabela semanal
    ├── tela_usuarios.dart        ← gestão de usuários (admin)
    ├── tela_pontos_admin.dart    ← edição de batidas (admin)
    └── tela_impressora.dart      ← configuração Bluetooth
```

## Instalação no tablet do cliente

Ver `INSTALL.md`.

## Releases

APKs assinados ficam em [Releases](../../releases). Não commitar APK no repo — vai pra Release.

## Licença

Privado · uso comercial restrito ao projeto Caixa Padaria.
