# Instalação — Caixa Padaria

Guia passo-a-passo pra instalar o APK no tablet do cliente.

## Requisitos

- Tablet Android 7.0 (API 24) ou superior
- Memória interna: pelo menos 200 MB livres
- Bluetooth Classic (não BLE) pra impressão térmica

## Primeira instalação

### 1. Habilitar instalação de fontes desconhecidas

No tablet:

1. **Configurações** → **Segurança** (ou **Aplicativos especiais** em Android mais novo)
2. Procura por **"Fontes desconhecidas"** ou **"Instalar apps desconhecidos"**
3. Habilita pro app que vai abrir o APK (ex: navegador, gerenciador de arquivos, Google Drive)

### 2. Copiar o APK pro tablet

Escolhe um dos métodos:

**Cabo USB:**
1. Conecta o tablet no computador
2. Aceita "permitir acesso a arquivos" no tablet
3. Copia `padaria_pos_v3_login_ponto_release.apk` pra pasta `Download/` do tablet

**Google Drive / e-mail:**
1. Sobe o APK pro Drive ou se manda por e-mail
2. Abre no tablet, baixa, toca pra instalar

**ADB (se você é técnico):**
```bash
adb install padaria_pos_v3_login_ponto_release.apk
```

### 3. Instalar

1. Abre o **gerenciador de arquivos** do tablet
2. Vai em **Download/**
3. Toca em `padaria_pos_v3_login_ponto_release.apk`
4. Confirma a instalação (pode aparecer aviso do Play Protect — clica em "instalar mesmo assim")

### 4. Primeira abertura

1. Abre o app **Caixa Padaria**
2. Na tela de login, aparece um usuário **Admin**
3. Toca em Admin → digita senha `0000`
4. Aparecem dois botões — toca em **CAIXA**

### 5. Configuração inicial (faz como Admin)

1. Menu (3 pontinhos no canto superior direito) → **Configurações**
2. Define **Nome da loja**, **Endereço**
3. Volta ao menu → **Usuários**
4. Cria os usuários reais da padaria com nível e funções corretas
5. (Opcional mas recomendado) Volta em Usuários → edita o **Admin** padrão → desativa
6. Volta ao menu → **Produtos** → ajusta preço, custo e cor de cada produto
7. (Se a impressora chegou) Menu → **Impressora** → conecta com a térmica Bluetooth

## Atualização (instalar v3 por cima de v1 ou v2)

⚠️ **Não desinstale a versão atual.** Desinstalar apaga o banco de dados (produtos, vendas, usuários). A atualização é não-destrutiva.

1. Copia o `padaria_pos_v3_login_ponto_release.apk` pro tablet
2. Toca pra instalar
3. Android avisa "este aplicativo está sendo atualizado" — confirma
4. Ao abrir, a migração de banco roda automaticamente (uns 50 ms invisíveis)
5. Pronto — dados antigos preservados, funcionalidades novas disponíveis

A analogia: é como trocar o motor do carro sem trocar a placa. O painel, os bancos, o porta-malas continuam iguais — só a engenharia embaixo do capô muda.

## Problemas comuns

### "App não instalado" ou "Assinatura conflitante"

Acontece quando a versão atual foi assinada com chave diferente da nova. Solução:

```bash
adb uninstall com.caixapadaria.pos
```

Aí instala a v3 normalmente — **mas você perde o banco**. Pra preservar, exporte o CSV antes (Menu → Operações ou função interna se já existir).

### "Espaço insuficiente"

Tablet muito cheio. Libera com Configurações → Armazenamento → Limpar cache de outros apps. Caixa Padaria ocupa ~100 MB instalado.

### Bluetooth não pareia com impressora

1. Bluetooth está ligado no tablet?
2. A impressora foi pareada **primeiro** pelas Configurações do Android (não pelo app)?
3. PIN da impressora geralmente é `0000` ou `1234`
4. App pede permissão `BLUETOOTH_SCAN` e `BLUETOOTH_CONNECT` na primeira abertura — concede

### Impressora pareia mas não imprime

- Acabou o papel?
- Largura de coluna configurada bate com a impressora? (58mm = 32 colunas, 80mm = 48 colunas)
- Em Configurações da loja → ajusta "Largura do cupom"

## Suporte

Mateus Bacini
📱 +1 (630) 943-0234
✉️ matbacini@gmail.com
