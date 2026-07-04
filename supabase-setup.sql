-- =====================================================================
-- Caderno de Cifras v0.4 — configuração do Supabase (rode no SQL Editor)
-- Modelo de segurança: todo mundo LÊ; escreve apenas quem está na tabela
-- "editores" E autenticado. Assim, mesmo que o cadastro público de contas
-- fique ligado por engano, contas estranhas NÃO conseguem escrever nada.
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

-- 3) Quem pode editar ----------------------------------------------------
create table if not exists public.editores (
  email text primary key
);
alter table public.editores enable row level security;      -- sem policies = ninguém acessa direto
revoke all on table public.editores from anon, authenticated;

create or replace function public.is_editor()
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.editores e
    where lower(e.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$$;
revoke all on function public.is_editor() from public;
grant execute on function public.is_editor() to authenticated;

-- 4) Regras de acesso (RLS) ----------------------------------------------
alter table public.songs enable row level security;
alter table public.app_config enable row level security;

drop policy if exists "songs_leitura_publica" on public.songs;
create policy "songs_leitura_publica" on public.songs
  for select using (true);

drop policy if exists "songs_editor_insere" on public.songs;
create policy "songs_editor_insere" on public.songs
  for insert to authenticated with check (public.is_editor());

drop policy if exists "songs_editor_atualiza" on public.songs;
create policy "songs_editor_atualiza" on public.songs
  for update to authenticated using (public.is_editor()) with check (public.is_editor());

drop policy if exists "songs_editor_exclui" on public.songs;
create policy "songs_editor_exclui" on public.songs
  for delete to authenticated using (public.is_editor());

drop policy if exists "config_leitura_publica" on public.app_config;
create policy "config_leitura_publica" on public.app_config
  for select using (true);

drop policy if exists "config_editor_atualiza" on public.app_config;
create policy "config_editor_atualiza" on public.app_config
  for update to authenticated using (public.is_editor()) with check (public.is_editor());

-- 5) updated_at automático -------------------------------------------------
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists trg_songs_updated on public.songs;
create trigger trg_songs_updated before update on public.songs
  for each row execute function public.set_updated_at();

drop trigger if exists trg_config_updated on public.app_config;
create trigger trg_config_updated before update on public.app_config
  for each row execute function public.set_updated_at();

-- 6) Áudios (bucket público com limites) -----------------------------------
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

-- 7) >>> TROQUE PELO E-MAIL DO PROFESSOR (o mesmo do usuário criado em Auth) <<<
insert into public.editores (email) values ('EMAIL_DO_PROFESSOR_AQUI')
on conflict (email) do nothing;
