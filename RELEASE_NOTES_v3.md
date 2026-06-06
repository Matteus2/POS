# v3.0.0 — Sistema de login, ponto com cargo e schema-heal

Primeira versão "operacional completa" do Caixa Padaria. Pronta pra piloto em padaria real com múltiplos funcionários.

## ✨ Novidades

### Sistema de login (multi-usuário)
- Tela de login com grade visual de funcionários (avatar + iniciais coloridas por nível)
- Numpad de 4 dígitos com autenticação automática no 4º dígito (sem precisar apertar Enter)
- 3 níveis de acesso hierárquicos:
  - **Funcionário** — só bate ponto
  - **Operador** — bate ponto + caixa + vendas + histórico + perdas/produção
  - **Admin** — tudo acima + cadastro de produtos, usuários e configurações
- Após autenticar, dois botões grandes "CAIXA" e "BATER PONTO" filtrados pelas permissões do usuário
- Admin padrão seed automático na primeira instalação (`Admin` / `0000`) — desativar após criar usuários reais

### Sistema de ponto com cargo
- Cada usuário pode ter múltiplas funções permitidas (Caixa, Cozinheiro, Padeiro, Atendente, Faxineiro, Entregador, Gerente)
- Admin define no cadastro quais cargos cada funcionário pode exercer
- Ao bater entrada, o funcionário escolhe o cargo do dia no dropdown
- Função fica travada durante o turno em andamento (saída herda automaticamente)

### Tabela semanal de turnos
- Tela de ponto com layout responsivo (duas colunas em tablet, empilhado em phone)
- Painel esquerdo: avatar + nome + dropdown de função + botão grande verde/laranja + total de horas da semana
- Painel direito: tabela `Função | Dia | Entrada | Saída` com turnos da semana atual
- Turnos em andamento marcados como `● em curso` (verde)
- Apenas semana atual exibida — dados de semanas anteriores acessíveis só pelo admin

### Auto-fechamento de turnos esquecidos
- Saída automática às 04:00 do dia seguinte pra qualquer entrada sem par em dias anteriores
- Saídas automáticas marcadas com ícone de varinha (`auto_awesome`) pra distinção visual
- Rodada na abertura do app (`main.dart`)

### Edição de horários pelo admin
- Nova tela `tela_pontos_admin.dart` acessível pelo ícone de relógio em cada usuário
- Editar timestamp (date + time picker), tipo (entrada/saída), função
- Remover pontos indevidos
- Adicionar pontos manualmente pra corrigir esquecimentos

### Schema-heal (migração defensiva)
- Banco agora detecta colunas faltantes em qualquer tabela e adiciona automaticamente via `PRAGMA table_info` + `ALTER TABLE`
- Resolve crashes em tablets que vieram de versões antigas com schema incompleto
- Idempotente — pode rodar várias vezes sem efeito colateral

### Botões de ação centralizados
- Botão "Novo produto" e "Novo usuário" agora ficam centralizados na barra inferior (não mais FAB no canto direito)
- Mais alcançável pra balconistas usando tablet com uma mão só

## 🐛 Correções

- `_finalizarVenda` agora tem try/catch — exceptions do SQLite ficam visíveis em snackbar (antes o botão "engolia" o clique silenciosamente)
- `_fecharCaixa` recarrega o estado depois de salvar — ícone de caixa fica vermelho de novo, bottom sheet não reabre como se nada tivesse acontecido
- Dialog de fechar caixa mostra diferença (sobra/falta) em tempo real e deixa explícito que pode fechar com qualquer valor
- Sangria/suprimento também recarregam o saldo do caixa no estado local

## 📦 Esquema do banco — v6

Migrations rodam automaticamente do v3 (versão do APK v1) até v6 (atual) sem perder dados.

Novas tabelas: `usuarios`, `pontos`.
Novas colunas em existentes: `usuarios.funcoes_permitidas`, `pontos.funcao`, `pontos.automatica`, `produtos.custo`, `vendas.estorno`, `vendas.venda_original_id`, `vendas.valor_recebido`, `vendas.troco`, `vendas.caixa_id`, `caixas.valor_fechamento_esperado`, `caixas.valor_fechamento_informado`, `itens_venda.custo_unitario`.

## 📲 Instalação

Ver `INSTALL.md` no repositório.

**Importante:** NÃO desinstale a versão anterior antes de instalar a v3. O Android atualiza por cima preservando o banco de dados (produtos, vendas, usuários). Desinstalar apaga tudo.

## 🚧 Próximas versões

- Backup automático em nuvem (Firebase ou similar)
- PIX QR Code dinâmico no cupom
- Modo kiosk pra travar o tablet só no app
- Relatórios visuais (gráficos de vendas por dia/produto/cargo)
- Hash de senha (atualmente texto puro — aceitável pra 4 dígitos mas troca em v4)
