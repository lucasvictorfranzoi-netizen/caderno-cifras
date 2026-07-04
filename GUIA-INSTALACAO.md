# Caderno de Cifras v0.4 — Guia de instalação (para o Lucas)

Arquitetura correta: **frontend estático sem segredos** (GitHub Pages) + **backend com login de verdade** (Supabase).
Alunos leem sem cadastro; só o professor escreve — regra aplicada **no servidor** (RLS), não em botão escondido.
Custo: R$ 0/mês nos planos grátis.

---

## 1) Supabase (~8 min)

1. https://supabase.com → **New project** → região `South America (São Paulo)`. Guarde a senha do banco no seu cofre (não será usada pelo app).
2. **SQL Editor** → cole o `supabase-setup.sql` inteiro → **antes de rodar**, troque `EMAIL_DO_PROFESSOR_AQUI` (última linha) pelo e-mail real do professor → **Run**.
3. **Authentication → Users → Add user** → e-mail do professor (o MESMO do passo 2) + senha forte → marque *Auto Confirm User*.
4. **Authentication → Sign In / Providers** → **DESLIGUE "Allow new users to sign up"**. ⚠️ Passo de segurança importante. (Mesmo que fique ligado por engano, o SQL do passo 2 impede contas estranhas de escrever — mas desligue.)
5. **Authentication → URL Configuration → *Site URL*** — é o endereço onde o app fica publicado (o do GitHub Pages, criado na seção 3).
   - **Para que serve:** quando o professor clica em "Esqueci a senha", o Supabase envia um e-mail com um link de redefinição. Esse link precisa levar de volta ao app, e é este campo que diz ao Supabase qual é o endereço. Sem ele preenchido, o link do e-mail não abre a tela de nova senha.
   - **Qual endereço colocar:** o do Pages segue sempre o formato `https://SUA-CONTA.github.io/caderno-cifras/` — o seu usuário do GitHub + o nome do repositório (`caderno-cifras`, criado na seção 3). Se você já sabe o nome da conta que vai usar, pode preencher agora. Se preferir, **pule este passo, faça a seção 3 e volte aqui** para colar o endereço definitivo.
6. **Project Settings → API** → copie **Project URL** e **anon public key**.

> A anon key é pública por design: ela só concede o que as regras permitem (leitura). Pode ficar no HTML e no workflow sem problema.

## 2) O app (~2 min)

Abra `index.html` e preencha o bloco `CONFIG`:

```js
SUPABASE_URL: "https://xxxxx.supabase.co",
SUPABASE_ANON_KEY: "cole-a-anon-key",
```

(`APP_NAME`/`PROFESSOR_NAME` são só o padrão inicial — o professor troca pelo próprio app em *Personalizar*.)

## 3) GitHub Pages — publicar e pegar o link (~10 min)

> É aqui que nasce o endereço do app (o link do passo 5 do Supabase). Siga na ordem: primeiro publicar e copiar o link, depois voltar ao Supabase, e por último o keep-alive.

**Antes de começar (recomendação da varredura):** crie uma **conta GitHub só para o caderno** — isso isola a origem `*.github.io` dos seus outros PWAs (como a sua agenda criptografada). Se já tiver conta e não se importar com isso, pode usar a mesma. Em qualquer caso, ligue o **2FA** em *Settings → Password and authentication*.

### 3.1 — Criar o repositório
1. Logado no GitHub, clique no **＋** (canto superior direito) → **New repository**.
2. **Repository name:** `caderno-cifras` (exatamente assim, minúsculo — esse nome entra no link).
3. Marque **Public**. (Precisa ser público: o Pages grátis só publica repositório público, e não tem problema — não há segredo nenhum nos arquivos.)
4. **Não** marque "Add a README". Deixe o resto em branco → **Create repository**.

### 3.2 — Enviar os arquivos
Descompacte o `caderno-cifras-v4.zip` no seu computador. Você vai enviar o conteúdo dele (não a pasta externa).

1. Na página do repositório recém-criado, clique no link **"uploading an existing file"** (ou **Add file → Upload files**).
2. Abra a pasta descompactada, selecione e **arraste para a área do navegador**: `index.html`, `manifest.json`, `sw.js`, `supabase-setup.sql`, `GUIA-INSTALACAO.md` **e a pasta `icons`** (arraste a pasta inteira — o GitHub mantém a subpasta).
3. Em baixo, clique **Commit changes**.

> A pasta `.github` (do keep-alive) é **oculta** e some no gerenciador de arquivos — por isso **não** vamos enviá-la por arrasto. Ela será criada direto no site no passo 3.5. Ignore-a por enquanto.

### 3.3 — Ligar o Pages e copiar o LINK
1. No repositório, aba **Settings** (no topo).
2. Na barra lateral, seção **"Code and automation"**, clique em **Pages**.
3. Em **"Build and deployment"** → **Source**: escolha **Deploy from a branch**.
4. Logo abaixo, em **Branch**: selecione **main** e a pasta **/ (root)** → **Save**.
5. Aguarde **1 a 10 minutos**. Recarregue a página; quando ficar pronto aparece no topo: **"Your site is live at …"** com o endereço.

**Esse endereço é o seu link.** Vai ser algo como:
```
https://SUA-CONTA.github.io/caderno-cifras/
```
Copie-o — é ele que os alunos recebem e que você cola no Supabase agora.

### 3.4 — Voltar ao Supabase (fecha o passo 5)
Vá ao Supabase → **Authentication → URL Configuration** → cole o link acima em **Site URL** → **Save**. Pronto: o "Esqueci a senha" já tem para onde levar.

### 3.5 — Keep-alive (criar o workflow + as duas variáveis)
Isso mantém o banco grátis acordado (ele pausa com ~7 dias sem acesso — ex.: férias escolares).

**a) Criar o arquivo do workflow direto no site** (assim você não precisa da pasta oculta):
1. Aba **Code** do repositório → **Add file → Create new file**.
2. No campo do nome, digite **exatamente** isto (as barras criam as pastas sozinhas):
   ```
   .github/workflows/keepalive.yml
   ```
3. Cole no corpo o conteúdo abaixo (é o mesmo arquivo entregue):
   ```yaml
   name: Manter Supabase ativo
   on:
     schedule:
       - cron: "17 3 */3 * *"
     workflow_dispatch: {}

   permissions:
     contents: write

   jobs:
     ping:
       runs-on: ubuntu-latest
       steps:
         - uses: actions/checkout@v4

         - name: Ping no banco (mantem o projeto acordado)
           run: |
             curl -fsS "${{ vars.SUPABASE_URL }}/rest/v1/songs?select=id&limit=1" \
               -H "apikey: ${{ vars.SUPABASE_ANON_KEY }}" \
               -H "Authorization: Bearer ${{ vars.SUPABASE_ANON_KEY }}" \
               -o /dev/null
             echo "Supabase respondeu."

         - name: Batimento no repositorio (mantem o cron vivo)
           run: |
             AGORA=$(date -u +%s)
             ULTIMO=$(git log -1 --format=%ct -- .keepalive 2>/dev/null || echo 0)
             IDADE=$(( (AGORA - ULTIMO) / 86400 ))
             if [ "$IDADE" -ge 20 ] || [ "$ULTIMO" = "0" ]; then
               date -u +"%Y-%m-%dT%H:%M:%SZ" > .keepalive
               git config user.name "keepalive-bot"
               git config user.email "actions@users.noreply.github.com"
               git add .keepalive
               git commit -m "chore: batimento de atividade"
               git push
             else
               echo "Ultimo batimento ha ${IDADE} dia(s) - nada a fazer."
             fi
   ```
4. **Commit changes**.

**b) Cadastrar as duas variáveis** (o workflow lê a URL e a chave daqui, não de dentro do código):
1. **Settings** → na barra lateral, seção **"Security"**, clique em **Secrets and variables** → **Actions**.
2. Abra a aba **Variables** → **New repository variable**. Crie as duas:
   - Nome `SUPABASE_URL` · Valor = a **Project URL** do Supabase (a mesma do passo 6)
   - Nome `SUPABASE_ANON_KEY` · Valor = a **anon public key**

**c) Testar uma vez:**
1. Aba **Actions** → se aparecer um aviso verde, clique em **"I understand my workflows, go ahead and enable them"**.
2. Na lista à esquerda, clique em **Manter Supabase ativo** → botão **Run workflow** → **Run workflow**.
3. Em ~30s o item fica com ✓ verde. Abra-o e confira que o passo do ping mostra "Supabase respondeu."

> **Se (e só se) o passo do batimento falhar** com erro de permissão (403): vá em **Settings → Actions → General → Workflow permissions**, marque **Read and write permissions → Save**, e rode de novo. Na maioria dos casos não é preciso, porque o próprio arquivo já pede a permissão que precisa.

Daí em diante é automático: ping a cada 3 dias e um commit de batimento a cada ~20 dias (esse commit evita que o GitHub desligue o agendamento por inatividade depois de 60 dias parado).

## 4) Entrega

- **Professor:** mande o link + e-mail/senha. Primeira coisa: *Menu → Personalizar nomes*. Depois é só criar músicas — salvar já publica na hora. Se esquecer a senha, o próprio login tem "Esqueci a senha".
- **Alunos:** mandem o link no grupo; cada um usa **Adicionar à tela inicial**. Atualiza sozinho; músicas/áudios já abertos funcionam offline.

## 5) Segurança — resumo do modelo

| Ponto | Situação |
|---|---|
| Escrita | Só sessão autenticada **e** e-mail presente na tabela `editores` (RLS + função `is_editor`) |
| Cadastro público | Desligado; e inofensivo se religar (não vira editor) |
| Anon key exposta | Por design; concede apenas leitura |
| Senha do professor | Redefinível por e-mail; força bruta limitada pelo Supabase |
| XSS/exfiltração | Conteúdo 100% escapado + CSP: conexões só para o próprio site e `*.supabase.co` |
| Áudio | Bucket com limite de 8 MB e apenas `audio/*` |
| Backup | Menu → Exportar backup (JSON) + backups do Supabase |
| Ponto de atenção | Site é público: não coloquem dados pessoais em anotações; letras completas de terceiros têm exposição teórica a takedown |

## 6) Limites do grátis (folgados)

Banco 500 MB · Storage 1 GB (~30h de áudio de batidas) · 5 GB tráfego/mês. Painel do Supabase mostra o uso.
