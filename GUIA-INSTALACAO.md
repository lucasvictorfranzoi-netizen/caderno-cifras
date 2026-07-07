# Caderno de Cifras v0.5 — Guia de instalação (para o Lucas)

**O que é:** frontend estático sem segredos (GitHub Pages) + backend com login de verdade (Supabase). Alunos leem sem cadastro; só o professor escreve, e isso é garantido **no servidor** (RLS). Custo: **R$ 0/mês**.

**A ordem importa — leia isto antes.** Duas informações cruzam entre os dois serviços:
- a **URL + chave do Supabase** (Parte 1) entram no app e no GitHub (Partes 2 e 4);
- o **endereço do site** só nasce quando o GitHub publica (Parte 3), e é a única coisa que falta ao Supabase no fim.

Por isso o roteiro é linear e deixa **um único campo para o final** (o *Site URL* do Supabase, na Parte 5). Faça os passos na ordem, **de 1 a 18**.

---

## Parte 1 — Supabase: criar o backend (~8 min)

1. Acesse https://supabase.com → **New project**. Região: **South America (São Paulo)**. Guarde a senha do banco no seu cofre (o app não usa essa senha).
2. Abra o **SQL Editor** → cole o `supabase-setup.sql` inteiro. **Antes de rodar**, troque `EMAIL_DO_PROFESSOR_AQUI` (na última linha) pelo e-mail real do professor → **Run**. Deve aparecer "Success"; em **Table Editor** surgem as tabelas `songs`, `app_config` e `editores`.
3. **Authentication → Users → Add user** → e-mail do professor (o **mesmo** do passo 2) + uma senha forte → marque **Auto Confirm User** → criar.
4. **Ajustes de cadastro (importante — mudou nesta versão):**
   - **Authentication → Sign In / Providers → DEIXE LIGADO "Allow new users to sign up".** Agora o cadastro é o caminho dos alunos, e o **gatilho do banco** (criado no passo 2) recusa qualquer cadastro sem um convite válido. Ou seja: ligado, mas só entra quem tem link de convite.
   - **Authentication → Emails (ou Providers → Email) → "Confirm email".** Recomendo **DESLIGAR** para o aluno criar a conta e já entrar (mais simples). Se preferir deixar ligado, o aluno precisará clicar num link de confirmação no e-mail antes de entrar.
5. **Copie a URL e a chave pública** (guarde num bloco de notas — vão ser usadas nas Partes 2 e 4). O jeito mais fácil é o botão **Connect**, no topo do painel: ele mostra a **Project URL** (`https://xxxxx.supabase.co`) e a chave pública prontas para copiar.
   - **Qual chave — o nome mudou em 2025:** em projetos novos (como o seu) ela se chama **Publishable key** e começa com `sb_publishable_...`. Em projetos antigos aparece como **anon public** (começa com `eyJ...`). **Qualquer uma serve** — as duas são públicas de propósito e só liberam o que as regras (RLS) permitem. Procurando direto: **Settings → API Keys** (Publishable na aba **API Keys**; anon na aba **Legacy API Keys**).

> ⏳ O **Site URL** do Supabase fica para a **Parte 5**, de propósito: ele precisa do endereço que o GitHub só vai criar na Parte 3. Não procure por ele agora.

---

## Parte 2 — Preencher o app no seu computador (~2 min)

6. Descompacte o `caderno-cifras-v4.zip`. Abra o `index.html` num editor de texto (o Bloco de Notas serve) e, no bloco `CONFIG` lá no começo, preencha com o que você copiou no passo 5:
   ```js
   SUPABASE_URL: "https://xxxxx.supabase.co",
   SUPABASE_ANON_KEY: "cole-aqui-a-chave-publishable-ou-anon",
   ```
   Salve o arquivo.

> O campo se chama `SUPABASE_ANON_KEY` por herança — **cole nele a chave pública** mesmo assim (a `sb_publishable_...`, ou a `anon`). Serve a mesma coisa; só o rótulo é antigo.
> `APP_NAME`/`PROFESSOR_NAME` são só o padrão inicial — o professor troca pelo próprio app depois, em *Personalizar*.

---

## Parte 3 — GitHub: publicar e pegar o link (~8 min)

**Conta:** recomendo uma **conta GitHub só para o caderno** (isola a origem `*.github.io` dos seus outros PWAs, como a agenda criptografada). Se já tiver conta e não se importar, use a mesma. Em qualquer caso, ligue o **2FA** em *Settings → Password and authentication*.

7. Logado no GitHub, clique no **＋** (canto superior direito) → **New repository**. Nome: **`caderno-cifras`** (minúsculo — entra no link). Marque **Public** (o Pages grátis exige repositório público; sem problema, não há segredo nos arquivos). **Não** marque "Add a README" → **Create repository**.
8. Na página do repositório novo, clique em **"uploading an existing file"** (ou **Add file → Upload files**). Da pasta descompactada, **arraste** para o navegador: o **`index.html` que você acabou de preencher**, mais `manifest.json`, `sw.js`, `diagnostico.html`, `supabase-setup.sql`, `GUIA-INSTALACAO.md` **e a pasta `icons`** inteira → **Commit changes**.
   > A pasta `.github` é **oculta** e some no gerenciador de arquivos — **não** a arraste. Ela será criada direto no site na Parte 4.
9. Ligue o Pages: aba **Settings** → barra lateral (seção **"Code and automation"**) → **Pages** → em **"Build and deployment" → Source** escolha **Deploy from a branch** → em **Branch** selecione **main** e a pasta **/ (root)** → **Save**.
10. Aguarde de **1 a 10 minutos** e recarregue a página do Pages. Quando ficar pronto, aparece **"Your site is live at …"**. **Copie esse endereço** — é o link dos alunos e o que falta para o Supabase. Formato:
    ```
    https://SUA-CONTA.github.io/caderno-cifras/
    ```

---

## Parte 4 — GitHub: manter o banco acordado (keep-alive) (~5 min)

Projetos grátis do Supabase pausam com ~7 dias sem acesso (ex.: férias escolares). Este workflow evita isso.

11. **Criar o arquivo do workflow** (assim você não precisa da pasta oculta): aba **Code** → **Add file → Create new file**. No campo do nome, digite **exatamente** isto (as barras criam as pastas sozinhas):
    ```
    .github/workflows/keepalive.yml
    ```
    Cole no corpo o conteúdo abaixo → **Commit changes**:
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

          - name: Ping no banco (mantem o Supabase acordado)
            run: |
              curl -fsS "${{ vars.SUPABASE_URL }}/rest/v1/songs?select=id&limit=1" \
                -H "apikey: ${{ vars.SUPABASE_ANON_KEY }}" \
                -H "Authorization: Bearer ${{ vars.SUPABASE_ANON_KEY }}" \
                -o /dev/null
              echo "Supabase respondeu."

          - name: Batimento numa branch separada (mantem o cron vivo, sem republicar o site)
            run: |
              git config user.name "keepalive-bot"
              git config user.email "actions@users.noreply.github.com"
              date -u +"%Y-%m-%dT%H:%M:%SZ" > .keepalive
              git add -f .keepalive
              git commit -m "chore: batimento de atividade"
              git push -f origin HEAD:refs/heads/keepalive
              echo "Batimento enviado para a branch keepalive (nao mexe no site)."
    ```
12. **Cadastrar as duas variáveis** que o workflow lê: **Settings** → barra lateral (seção **"Security"**) → **Secrets and variables** → **Actions** → aba **Variables** → **New repository variable**. Crie as duas:
    - `SUPABASE_URL` = a **Project URL** (a do passo 5)
    - `SUPABASE_ANON_KEY` = a **mesma chave pública** do passo 5 (`sb_publishable_...` ou `anon`)
13. **Testar uma vez:** aba **Actions** → se houver um aviso, clique em **"I understand my workflows, go ahead and enable them"** → clique em **Manter Supabase ativo** → **Run workflow** → **Run workflow**. Em ~30s fica ✓ verde; abra e confira "Supabase respondeu."
    > **Se (e só se) o passo do batimento falhar com erro 403:** vá em **Settings → Actions → General → Workflow permissions**, marque **Read and write permissions → Save**, e rode de novo. Normalmente não é preciso.
    > **Este workflow não republica o site.** O batimento vai para uma branch separada chamada `keepalive` (que o Pages não publica), só para manter o agendamento ativo — o GitHub desliga cron parado por 60 dias, e o batimento evita isso. Você vai ver essa branch `keepalive` aparecer no repositório: é esperado e inofensivo, pode ignorar. Daí em diante é automático: ping no Supabase a cada 3 dias, batimento na branch a cada rodada.

---

## Parte 5 — Conectar as pontas: o Site URL do Supabase (~1 min)

14. Agora que o endereço existe (passo 10), volte ao Supabase → **Authentication → URL Configuration** e preencha **os dois** campos:
    - **Site URL** = o link do Pages, **com a barra no final**: `https://SUA-CONTA.github.io/caderno-cifras/`
    - **Redirect URLs** → **Add URL** → `https://SUA-CONTA.github.io/caderno-cifras/**` (com os dois asteriscos no fim)
    - **Save**.
    - **Para que serve:** quando o professor usa "Esqueci a senha", o Supabase manda um e-mail cujo link volta para esse endereço e abre a tela de nova senha. Se o endereço estiver errado/ausente, o link "cai no GitHub" sem abrir a tela.
    - ⚠️ **Importante:** o link de redefinição é gerado no momento do envio e **expira em ~1 hora** (uso único). Sempre **peça um e-mail novo depois** de mexer aqui — e-mails pedidos antes têm o endereço antigo embutido e não vão funcionar.

---

## Parte 6 — Testar de ponta a ponta (~3 min)

15. Abra o link publicado e toque no **menu** (canto superior). Deve aparecer **"🔑 Área do professor"**. Se em vez disso houver uma faixa **"Modo demonstração"**, o `CONFIG` subiu vazio: no GitHub, edite o `index.html` (ícone de lápis), preencha `SUPABASE_URL`/`SUPABASE_ANON_KEY`, **Commit**, espere 1–2 min e recarregue.
16. Entre em **Área do professor** com o e-mail/senha do passo 3 → crie uma música qualquer → **Salvar**.
17. Abra o **mesmo link numa aba anônima** (ou no celular). Você entra como **aluno**: deve ver a música, buscar e abrir — **sem** nenhum botão de edição.
18. (Opcional) Teste o **"Esqueci a senha"** na tela de login: deve chegar um e-mail, e o link abre a tela de nova senha.

Passou nos passos 16, 17 e 18? Está **100% no ar**.

**Conferência automática (opcional, recomendada):** abra `https://SUA-CONTA.github.io/caderno-cifras/diagnostico.html`, cole a **mesma URL e chave** do `index.html` nos dois campos e clique em **Rodar testes**. Ele verifica ao vivo: conexão, leitura protegida (visitante não vê nada sem login), configuração, **bloqueio de escrita para visitantes** (segurança), login e armazenamento — e mostra ✓/✗ item a item. Se preencher e-mail e senha do professor (opcional), ainda confirma que ele tem permissão de salvar. "Tudo funcionando!" = pode entregar com confiança. (Nenhum teste cria ou apaga dados.)

---

## Entrega e uso (acesso por convite)

**Professor** entra com o **e-mail e senha** criados no passo 3. Primeira vez: *Menu → Personalizar nomes*. Depois é só criar músicas — salvar já publica na hora.

**Convidar um aluno:** *Menu → 👥 Convidar aluno → Gerar link de convite*. Copie o link e envie ao aluno (WhatsApp etc.). Cada link cria **uma** conta. Nessa tela o professor também **vê a turma pelos nomes de usuário** e pode **remover** quem quiser.

**Aluno** abre o link e cria a conta com **nome de usuário + e-mail + senha**. O **nome de usuário** é como o professor identifica cada aluno; o **e-mail** serve para entrar e recuperar a senha. Nas próximas vezes, entra com **e-mail + senha**. Pode usar *Adicionar à tela inicial* para virar app e funcionar offline.

**Quem não tem convite não cria conta e não vê nada** — o caderno não se espalha.

**Perfil (aluno e professor):** *Menu → 👤 Perfil* mostra os dados de cada um. O aluno vê seu nome de usuário, e-mail, **data de entrada**, **valor da mensalidade** e **data de vencimento** (esses dois definidos pelo professor). O professor vê nome, e-mail e data de entrada.

**Mensalidade e vencimento:** em *Alunos com acesso*, toque em **Editar** no aluno para definir o **valor da mensalidade** e a **data de vencimento**. O aluno passa a ver isso no próprio Perfil.

> **Esqueceu a senha?** Funciona para todos (aluno e professor): na tela de entrada, digite o e-mail e toque em **Esqueci a senha** — chega um link de redefinição.

## Segurança — resumo do modelo

| Ponto | Situação |
|---|---|
| Escrita | Só sessão autenticada **e** e-mail presente na tabela `editores` (RLS + função `is_editor`) |
| Criar conta | Ligado, mas **só com link de convite** válido — um gatilho no banco recusa o resto |
| Leitura das músicas | **Só para membros logados** (professor + alunos convidados); visitante não vê nada |
| Perfil / mensalidade | Cada aluno só enxerga o **próprio** perfil; só o professor edita valores e vê a turma toda |
| Chave pública exposta (`publishable`/`anon`) | Por design; sozinha não lê nada (leitura exige login de membro) |
| Senha do professor | Redefinível por e-mail; força bruta limitada pelo Supabase |
| XSS/exfiltração | Conteúdo 100% escapado + CSP: conexões só para o próprio site e `*.supabase.co` |
| Áudio | Bucket com limite de 8 MB e apenas `audio/*` |
| Backup | Menu → Exportar backup (JSON) + backups do Supabase |
| Ponto de atenção | Site é público: não coloquem dados pessoais em anotações; letras completas de terceiros têm exposição teórica a takedown |

## Limites do grátis (folgados)

Banco 500 MB · Storage 1 GB (~30h de áudio de batidas) · 5 GB tráfego/mês. O painel do Supabase mostra o uso.
