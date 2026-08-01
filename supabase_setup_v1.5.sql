-- =========================================================
-- AtlasIA v1.5 — Setup do Supabase (rodar UMA VEZ)
-- =========================================================
-- Onde rodar: painel do Supabase do projeto (o mesmo que já é usado hoje
-- pro login/sincronização) → menu "SQL Editor" → "New query" → cole tudo
-- isso aqui → "Run". Depois disso não precisa rodar de novo (só se um dia
-- quiser resetar/apagar essas tabelas).
--
-- O que isso cria:
--  1) app_config        → guarda o link/vídeo do Vlow, compartilhado com
--                          TODO MUNDO que abrir o app (inclusive
--                          prestadores externos, sem precisar de login).
--  2) team_members       → aba Equipes (só quem está logado vê/edita)
--  3) projects            → aba Projetos (só quem está logado vê/edita)
--  4) shared_items        → aba Compartilhados (só quem está logado vê/edita)
--  5) bucket "vlow-videos"  → onde o vídeo mp4 do Vlow fica hospedado
--                              (link público, upload só logado)
--  6) bucket "shared-files" → onde arquivos anexados em Compartilhados
--                              ficam hospedados (só logado vê/envia)
-- =========================================================

-- 1) app_config — leitura pública (qualquer visitante), escrita só logado
create table if not exists public.app_config (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.app_config enable row level security;

drop policy if exists "app_config_public_read" on public.app_config;
create policy "app_config_public_read" on public.app_config
  for select using (true);

drop policy if exists "app_config_auth_insert" on public.app_config;
create policy "app_config_auth_insert" on public.app_config
  for insert with check (auth.role() = 'authenticated');

drop policy if exists "app_config_auth_update" on public.app_config;
create policy "app_config_auth_update" on public.app_config
  for update using (auth.role() = 'authenticated');

-- 2) team_members (aba Equipes) — só logado lê e edita
create table if not exists public.team_members (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  role text,
  contact text,
  created_at timestamptz not null default now()
);
alter table public.team_members enable row level security;

drop policy if exists "team_members_auth_all" on public.team_members;
create policy "team_members_auth_all" on public.team_members
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- 3) projects (aba Projetos) — só logado lê e edita
create table if not exists public.projects (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  status text not null default 'nao_iniciado',
  responsible text,
  description text,
  created_at timestamptz not null default now()
);
alter table public.projects enable row level security;

drop policy if exists "projects_auth_all" on public.projects;
create policy "projects_auth_all" on public.projects
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- 4) shared_items (aba Compartilhados) — só logado lê e edita
create table if not exists public.shared_items (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  url text,
  description text,
  created_at timestamptz not null default now()
);
alter table public.shared_items enable row level security;

drop policy if exists "shared_items_auth_all" on public.shared_items;
create policy "shared_items_auth_all" on public.shared_items
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- 5) bucket do vídeo do Vlow — leitura pública (prestadores sem login
--    conseguem assistir), envio só por quem está logado.
insert into storage.buckets (id, name, public)
values ('vlow-videos', 'vlow-videos', true)
on conflict (id) do update set public = true;

drop policy if exists "vlow_videos_public_read" on storage.objects;
create policy "vlow_videos_public_read" on storage.objects
  for select using (bucket_id = 'vlow-videos');

drop policy if exists "vlow_videos_auth_upload" on storage.objects;
create policy "vlow_videos_auth_upload" on storage.objects
  for insert with check (bucket_id = 'vlow-videos' and auth.role() = 'authenticated');

drop policy if exists "vlow_videos_auth_delete" on storage.objects;
create policy "vlow_videos_auth_delete" on storage.objects
  for delete using (bucket_id = 'vlow-videos' and auth.role() = 'authenticated');

-- 6) bucket de arquivos de Compartilhados. IMPORTANTE: assim como o bucket
--    do vídeo, este é criado como "público" pra simplificar (link direto,
--    sem expirar). Isso quer dizer que, na prática, quem tiver o link exato
--    de um arquivo consegue abri-lo mesmo sem login (o link em si é bem
--    difícil de adivinhar, mas não é "privado de verdade" — é o mesmo
--    modelo do "qualquer pessoa com o link" do Google Drive). A tabela
--    shared_items em si (a lista de itens, título, descrição) continua só
--    visível pra quem está logado — essa política abaixo só entra em jogo
--    em acessos feitos pelo SDK (fora do link público direto).
insert into storage.buckets (id, name, public)
values ('shared-files', 'shared-files', true)
on conflict (id) do update set public = true;

drop policy if exists "shared_files_auth_read" on storage.objects;
create policy "shared_files_auth_read" on storage.objects
  for select using (bucket_id = 'shared-files' and auth.role() = 'authenticated');

drop policy if exists "shared_files_auth_upload" on storage.objects;
create policy "shared_files_auth_upload" on storage.objects
  for insert with check (bucket_id = 'shared-files' and auth.role() = 'authenticated');

drop policy if exists "shared_files_auth_delete" on storage.objects;
create policy "shared_files_auth_delete" on storage.objects
  for delete using (bucket_id = 'shared-files' and auth.role() = 'authenticated');

-- =========================================================
-- Pronto! Depois de rodar isso, é só publicar o novo index.html — o app já
-- sabe usar essas tabelas/buckets sozinho (nenhuma outra configuração é
-- necessária). Se aparecer algum erro de permissão ao usar o app, o mais
-- provável é que este script não tenha rodado por completo — rode de novo,
-- ele é seguro de repetir (usa "if not exists"/"on conflict").
-- =========================================================
