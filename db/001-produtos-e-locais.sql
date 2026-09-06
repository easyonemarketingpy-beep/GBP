-- ---------------------------------------------------------------------
-- 001 - EASY ONE RANK: produtos, locais, palavras-chave e varreduras
--
-- Roda no SQL Editor do Supabase, na MESMA aba de sempre, no MESMO projeto
-- que o chatbot ja usa. Tudo aqui e idempotente: pode rodar de novo.
--
-- DEPENDE do schema do chatbot ja existir neste banco:
--   tabela `contas`, tabela `perfis`, funcoes `minha_conta()` e `e_admin()`.
-- Elas vem do db/001-schema.sql do easyone-chatbot-platform. Nao recria
-- nenhuma delas aqui.
--
-- O QUE ESTE ARQUIVO FAZ
--
-- 1. Cria o catalogo de produtos da plataforma e liga cada conta aos produtos
--    que ela comprou. E isto que faz o menu da logo, em
--    app.easyonemarketing.com, mostrar "Easy One Chatbot", "Easy One Rank",
--    ou os dois.
-- 2. Cria o nucleo do Easy One Rank: local, palavra-chave, varredura e ponto
--    de varredura.
--
-- POR QUE O SCHEMA VEM ANTES DA TELA
--
-- Toda tela do Lovable e escrita contra estas tabelas. Se elas nascem por
-- prompt, cada prompt precisa descrever o banco inteiro de novo e a RLS sai
-- errada. Com o schema pronto, o prompt vira so "monte esta tela lendo destas
-- tabelas": fica curto e sem margem para inventar.
--
-- A REGRA QUE NAO PODE SER QUEBRADA
--
-- `varreduras` e `pontos_varredura` sao IMUTAVEIS. Cada medicao de posicao
-- grava uma linha nova em `varreduras` e N linhas em `pontos_varredura`.
-- Nenhum update nessas duas, nunca. O historico por data e so:
--   select * from varreduras where palavra_id = ? order by medido_em desc
-- Nao existe tabela de historico separada. O historico E isso.
-- ---------------------------------------------------------------------

-- =====================================================================
-- 1. PRODUTOS DA PLATAFORMA
-- =====================================================================
create table if not exists produtos (
  id         uuid primary key default gen_random_uuid(),
  slug       text unique not null,                 -- easy-chat | easy-rank
  nome       text not null,
  caminho    text not null,                        -- /chat | /rank
  icone      text,
  ativo      boolean not null default true,
  ordem      int not null default 0,
  criado_em  timestamptz not null default now()
);

-- Quem comprou o que. Uma linha por produto, por conta.
-- Conta que compra os dois recebe duas linhas e o seletor aparece sozinho:
-- nao existe nenhuma logica de "combo" em lugar nenhum.
create table if not exists conta_produtos (
  conta_id    uuid not null references contas(id) on delete cascade,
  produto_id  uuid not null references produtos(id) on delete cascade,
  status      text not null default 'ativo',       -- ativo | vencido | cancelado
  liberado_em timestamptz not null default now(),
  expira_em   timestamptz,
  primary key (conta_id, produto_id)
);
create index if not exists idx_conta_produtos_conta on conta_produtos(conta_id);

insert into produtos (slug, nome, caminho, ordem) values
  ('easy-chat', 'Easy One Chatbot', '/chat', 1),
  ('easy-rank', 'Easy One Rank',    '/rank', 2)
on conflict (slug) do nothing;

-- =====================================================================
-- 2. QUOTAS DO EASY GOOGLE RANK
--
-- Duas quotas independentes, no mesmo estilo de limite_instancias:
--   limite_locais     - quantos Perfis da Empresa podem ficar ativos
--   limite_otimizacao - quantos podem ter otimizacao ligada
-- A segunda e sempre menor. E o que permite vender "10 perfis, 5 otimizados".
-- =====================================================================
alter table contas add column if not exists limite_locais     int not null default 1;
alter table contas add column if not exists limite_otimizacao int not null default 1;

-- =====================================================================
-- 3. LOCAIS - o Perfil da Empresa no Google
-- =====================================================================
create table if not exists locais (
  id                uuid primary key default gen_random_uuid(),
  conta_id          uuid not null references contas(id) on delete cascade,
  gbp_location      text,                          -- "locations/123..." da API do Google
  google_place_id   text,
  cid               text,
  nome              text not null,
  endereco          text,
  lat               double precision,
  lng               double precision,
  categoria         text,
  categorias        text[],
  telefone          text,
  site              text,
  horarios          jsonb,
  nota              numeric(2,1),
  total_avaliacoes  int not null default 0,
  ativo             boolean not null default true,
  otimizacao        boolean not null default false,
  protecao          boolean not null default false,
  brand_voice       jsonb,                         -- as seis secoes
  sincronizado_em   timestamptz,
  criado_em         timestamptz not null default now(),
  unique (conta_id, google_place_id)
);
create index if not exists idx_locais_conta on locais(conta_id, criado_em desc);

-- =====================================================================
-- 4. PALAVRAS-CHAVE monitoradas
-- =====================================================================
create table if not exists palavras_chave (
  id              uuid primary key default gen_random_uuid(),
  local_id        uuid not null references locais(id) on delete cascade,
  termo           text not null,
  volume_busca    int,
  frequencia      text not null default 'semanal', -- semanal | quinzenal | mensal
  ativa           boolean not null default true,
  medida_em       timestamptz,
  criado_em       timestamptz not null default now(),
  unique (local_id, termo)
);
create index if not exists idx_palavras_local on palavras_chave(local_id);

-- =====================================================================
-- 5. VARREDURAS - uma linha por medicao. IMUTAVEL.
-- =====================================================================
create table if not exists varreduras (
  id            uuid primary key default gen_random_uuid(),
  palavra_id    uuid not null references palavras_chave(id) on delete cascade,
  local_id      uuid not null references locais(id) on delete cascade,
  medido_em     timestamptz not null default now(),
  tamanho       int not null default 7,            -- 7 = grade 7x7 = 49 pontos
  raio_m        int not null default 3000,
  formato       text not null default 'quadrado',  -- quadrado | hexagono
  posicao_media numeric(5,2),
  visibilidade  numeric(5,2),                      -- % de pontos no top 3
  dificuldade   text,                              -- baixa | media | alta
  situacao      text not null default 'ok',        -- ok | parcial | falhou
  custo_usd     numeric(8,4) not null default 0
);
create index if not exists idx_varreduras_palavra on varreduras(palavra_id, medido_em desc);

-- =====================================================================
-- 6. PONTOS DA VARREDURA - 49 linhas por varredura. IMUTAVEL.
-- =====================================================================
create table if not exists pontos_varredura (
  id            uuid primary key default gen_random_uuid(),
  varredura_id  uuid not null references varreduras(id) on delete cascade,
  linha         int not null,
  coluna        int not null,
  lat           double precision not null,
  lng           double precision not null,
  posicao       int,                               -- null = nao apareceu neste ponto
  resultados    jsonb                              -- o pacote local daquele ponto
);
create index if not exists idx_pontos_varredura on pontos_varredura(varredura_id);

-- =====================================================================
-- 7. CONCORRENTES vistos nas varreduras
-- =====================================================================
create table if not exists concorrentes (
  id               uuid primary key default gen_random_uuid(),
  local_id         uuid not null references locais(id) on delete cascade,
  google_place_id  text,
  nome             text not null,
  endereco         text,
  categoria        text,
  nota             numeric(2,1),
  total_avaliacoes int,
  visto_em         timestamptz not null default now(),
  unique (local_id, google_place_id)
);
create index if not exists idx_concorrentes_local on concorrentes(local_id);

-- =====================================================================
-- 8. RLS - mesma regra do resto da plataforma
--
-- Este produto e vendido a terceiros. Um cliente enxergar o Perfil do
-- Google de outro nao e defeito, e incidente. Por isso toda tabela entra
-- com policy, inclusive as que so o worker escreve.
-- =====================================================================
alter table produtos          enable row level security;
alter table conta_produtos    enable row level security;
alter table locais            enable row level security;
alter table palavras_chave    enable row level security;
alter table varreduras        enable row level security;
alter table pontos_varredura  enable row level security;
alter table concorrentes      enable row level security;

drop policy if exists "produtos visiveis"       on produtos;
drop policy if exists "produtos da conta"       on conta_produtos;
drop policy if exists "locais da conta"         on locais;
drop policy if exists "palavras da conta"       on palavras_chave;
drop policy if exists "varreduras da conta"     on varreduras;
drop policy if exists "pontos da conta"         on pontos_varredura;
drop policy if exists "concorrentes da conta"   on concorrentes;

-- O catalogo e publico para quem esta logado: a tela precisa saber o nome
-- e o caminho do produto. Quem decide o que aparece e conta_produtos.
create policy "produtos visiveis" on produtos
  for select using (auth.uid() is not null);

create policy "produtos da conta" on conta_produtos
  for all using (conta_id = minha_conta() or e_admin());

create policy "locais da conta" on locais
  for all using (conta_id = minha_conta() or e_admin());

create policy "palavras da conta" on palavras_chave
  for all using (
    exists (select 1 from locais l where l.id = local_id
            and (l.conta_id = minha_conta() or e_admin()))
  );

create policy "varreduras da conta" on varreduras
  for all using (
    exists (select 1 from locais l where l.id = local_id
            and (l.conta_id = minha_conta() or e_admin()))
  );

create policy "pontos da conta" on pontos_varredura
  for all using (
    exists (select 1 from varreduras v join locais l on l.id = v.local_id
            where v.id = varredura_id
            and (l.conta_id = minha_conta() or e_admin()))
  );

create policy "concorrentes da conta" on concorrentes
  for all using (
    exists (select 1 from locais l where l.id = local_id
            and (l.conta_id = minha_conta() or e_admin()))
  );

-- =====================================================================
-- 9. CONFERENCIA
--
-- O SQL Editor mostra so o resultado da ULTIMA instrucao, entao a
-- conferencia e uma consulta so, com union all.
-- Esperado: 7 linhas de tabela com "criada", e 2 produtos.
-- =====================================================================
select 'tabela: ' || t as item,
       case when to_regclass('public.' || t) is null then 'FALTOU' else 'criada' end as situacao
from unnest(array['produtos','conta_produtos','locais','palavras_chave',
                  'varreduras','pontos_varredura','concorrentes']) as t
union all
select 'produto: ' || slug, nome from produtos
union all
select 'coluna: contas.limite_locais',
       case when exists (select 1 from information_schema.columns
                         where table_name='contas' and column_name='limite_locais')
            then 'criada' else 'FALTOU' end
union all
select 'coluna: contas.limite_otimizacao',
       case when exists (select 1 from information_schema.columns
                         where table_name='contas' and column_name='limite_otimizacao')
            then 'criada' else 'FALTOU' end
order by item;
