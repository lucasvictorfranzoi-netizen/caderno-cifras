-- =====================================================================
-- Caderno de Cifras v0.5 — configuração do Supabase (rode no SQL Editor)
-- MODELO DE SEGURANÇA (acesso por convite):
--   • Só MEMBROS (professor + alunos convidados) LEEM as músicas.
--   • Só o PROFESSOR (tabela editores) ESCREVE.
--   • Conta de aluno só é criada com um LINK DE CONVITE válido gerado pelo
--     professor — um gatilho no banco recusa qualquer cadastro sem convite.
-- Assim o caderno não se espalha: quem não tem convite não cria conta, e
-- quem não é membro não vê nada.
-- =====================================================================

-- 1) Músicas ------------------------------------------------------------
create table if not exists public.songs (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  artist      text default '',
  song_key    text default '',
  capo        int  default 0,
  difficulty  text default '',
  tags        text default '',
  blocks      jsonb not null default '[]',
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- 2) Configuração visível no app (nome do caderno / do professor) -------
create table if not exists public.app_config (
  id              int primary key check (id = 1),
  app_name        text not null default 'Caderno de Cifras',
  professor_name  text not null default 'Professor',
  updated_at      timestamptz not null default now()
);
insert into public.app_config (id) values (1) on conflict (id) do nothing;

-- 3) Quem pode editar (professor) ---------------------------------------
create table if not exists public.editores ( email text primary key );
alter table public.editores enable row level security;
revoke all on table public.editores from anon, authenticated;

-- 4) Alunos com acesso (preenchida automaticamente ao aceitar um convite)
create table if not exists public.alunos (
  email        text primary key,
  nome         text,
  mensalidade  numeric(10,2),
  vencimento   date,
  criado_em    timestamptz not null default now()
);
-- se a tabela já existia, garante as colunas:
alter table public.alunos add column if not exists nome text;
alter table public.alunos add column if not exists mensalidade numeric(10,2);
alter table public.alunos add column if not exists vencimento date;
alter table public.alunos enable row level security;
revoke all on table public.alunos from anon, authenticated;

-- 5) Convites (links gerados pelo professor) ----------------------------
create table if not exists public.convites (
  codigo     text primary key,
  usado      boolean not null default false,
  criado_em  timestamptz not null default now(),
  usado_por  text,
  usado_em   timestamptz
);
alter table public.convites enable row level security;
revoke all on table public.convites from anon, authenticated;

-- 6) Funções de papel ----------------------------------------------------
create or replace function public.is_editor()
returns boolean language sql security definer set search_path = public stable as $$
  select exists (select 1 from public.editores e
    where lower(e.email) = lower(coalesce(auth.jwt() ->> 'email', '')));
$$;
revoke all on function public.is_editor() from public;
grant execute on function public.is_editor() to authenticated;

create or replace function public.is_membro()
returns boolean language sql security definer set search_path = public stable as $$
  select exists (select 1 from public.editores e where lower(e.email) = lower(coalesce(auth.jwt() ->> 'email', '')))
      or exists (select 1 from public.alunos   a where lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', '')));
$$;
revoke all on function public.is_membro() from public;
grant execute on function public.is_membro() to authenticated;

-- papel do usuário logado: 'professor' | 'aluno' | 'nenhum'
create or replace function public.meu_papel()
returns text language sql security definer set search_path = public stable as $$
  select case
    when exists (select 1 from public.editores e where lower(e.email) = lower(coalesce(auth.jwt() ->> 'email', ''))) then 'professor'
    when exists (select 1 from public.alunos   a where lower(a.email) = lower(coalesce(auth.jwt() ->> 'email', ''))) then 'aluno'
    else 'nenhum' end;
$$;
revoke all on function public.meu_papel() from public;
grant execute on function public.meu_papel() to authenticated;

-- 7) GATILHO DE CONVITE: só cria conta com convite válido ----------------
-- Roda antes de inserir em auth.users. Professores passam sem convite.
-- Alunos precisam de um código válido e não usado; ao aceitar, o e-mail
-- entra em "alunos" e o convite é marcado como usado.
create or replace function public.checar_convite()
returns trigger language plpgsql security definer set search_path = public as $$
declare cod text; marcou boolean;
begin
  if exists (select 1 from public.editores e where lower(e.email) = lower(new.email)) then
    return new;  -- professor: não precisa de convite
  end if;
  cod := new.raw_user_meta_data ->> 'convite';
  if cod is null or cod = '' then
    raise exception 'É preciso de um convite do professor para criar conta.';
  end if;
  update public.convites
     set usado = true, usado_por = new.email, usado_em = now()
   where codigo = cod and usado = false
  returning true into marcou;
  if marcou is null then
    raise exception 'Convite inválido ou já utilizado.';
  end if;
  insert into public.alunos (email, nome)
    values (new.email, nullif(new.raw_user_meta_data ->> 'nome',''))
    on conflict (email) do update set nome = excluded.nome;
  return new;
end $$;

drop trigger if exists trg_checar_convite on auth.users;
create trigger trg_checar_convite before insert on auth.users
  for each row execute function public.checar_convite();

-- 8) Regras de acesso (RLS) ----------------------------------------------
alter table public.songs enable row level security;
alter table public.app_config enable row level security;

-- LEITURA das músicas: só MEMBROS (antes era pública)
drop policy if exists "songs_leitura_publica" on public.songs;
drop policy if exists "songs_leitura_membros" on public.songs;
create policy "songs_leitura_membros" on public.songs
  for select to authenticated using (public.is_membro());

drop policy if exists "songs_editor_insere" on public.songs;
create policy "songs_editor_insere" on public.songs
  for insert to authenticated with check (public.is_editor());
drop policy if exists "songs_editor_atualiza" on public.songs;
create policy "songs_editor_atualiza" on public.songs
  for update to authenticated using (public.is_editor()) with check (public.is_editor());
drop policy if exists "songs_editor_exclui" on public.songs;
create policy "songs_editor_exclui" on public.songs
  for delete to authenticated using (public.is_editor());

-- Config: leitura pública (o nome do caderno aparece na tela de login)
drop policy if exists "config_leitura_publica" on public.app_config;
create policy "config_leitura_publica" on public.app_config
  for select using (true);
drop policy if exists "config_editor_atualiza" on public.app_config;
create policy "config_editor_atualiza" on public.app_config
  for update to authenticated using (public.is_editor()) with check (public.is_editor());

-- Convites e alunos: só o professor gerencia (o gatilho grava via security definer)
drop policy if exists "convites_editor_le" on public.convites;
create policy "convites_editor_le" on public.convites for select to authenticated using (public.is_editor());
drop policy if exists "convites_editor_cria" on public.convites;
create policy "convites_editor_cria" on public.convites for insert to authenticated with check (public.is_editor());
drop policy if exists "convites_editor_apaga" on public.convites;
create policy "convites_editor_apaga" on public.convites for delete to authenticated using (public.is_editor());

drop policy if exists "alunos_editor_le" on public.alunos;
create policy "alunos_editor_le" on public.alunos for select to authenticated using (public.is_editor());
drop policy if exists "alunos_proprio_le" on public.alunos;
create policy "alunos_proprio_le" on public.alunos for select to authenticated
  using (lower(email) = lower(coalesce(auth.jwt() ->> 'email','')));
drop policy if exists "alunos_editor_atualiza" on public.alunos;
create policy "alunos_editor_atualiza" on public.alunos for update to authenticated
  using (public.is_editor()) with check (public.is_editor());
drop policy if exists "alunos_editor_apaga" on public.alunos;
create policy "alunos_editor_apaga" on public.alunos for delete to authenticated using (public.is_editor());

-- 9) updated_at automático ------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

drop trigger if exists trg_songs_updated on public.songs;
create trigger trg_songs_updated before update on public.songs
  for each row execute function public.set_updated_at();
drop trigger if exists trg_config_updated on public.app_config;
create trigger trg_config_updated before update on public.app_config
  for each row execute function public.set_updated_at();

-- 10) Áudios (bucket público com limites) ---------------------------------
-- Mantido público: os nomes de arquivo são aleatórios e só aparecem para
-- quem já pode ler a música (que é restrita a membros). O <audio> do app
-- toca por URL pública e o cache offline continua funcionando.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('audios', 'audios', true, 8388608, array['audio/*'])
on conflict (id) do update
  set public = true, file_size_limit = 8388608, allowed_mime_types = array['audio/*'];

drop policy if exists "audios_leitura_publica" on storage.objects;
create policy "audios_leitura_publica" on storage.objects
  for select using (bucket_id = 'audios');
drop policy if exists "audios_editor_envia" on storage.objects;
create policy "audios_editor_envia" on storage.objects
  for insert to authenticated with check (bucket_id = 'audios' and public.is_editor());
drop policy if exists "audios_editor_atualiza" on storage.objects;
create policy "audios_editor_atualiza" on storage.objects
  for update to authenticated using (bucket_id = 'audios' and public.is_editor());
drop policy if exists "audios_editor_exclui" on storage.objects;
create policy "audios_editor_exclui" on storage.objects
  for delete to authenticated using (bucket_id = 'audios' and public.is_editor());

-- 11) >>> TROQUE PELO E-MAIL DO PROFESSOR (o mesmo do usuário criado em Auth) <<<
insert into public.editores (email) values ('EMAIL_DO_PROFESSOR_AQUI')
on conflict (email) do nothing;
