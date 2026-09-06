-- ---------------------------------------------------------------------
-- 002 - EASY ONE RANK: reputacao, conteudo, auditoria, tarefas e metricas
--
-- Roda no SQL Editor do Supabase, na MESMA aba, DEPOIS do 001.
-- Idempotente: pode rodar de novo sem quebrar.
--
-- Completa o banco de tudo que as telas dos prompts 3 a 7 precisam ler.
-- Com estas tabelas prontas, os prompts do Lovable param de descrever banco
-- e viram so "monte esta tela lendo daqui" - que e o que barateia tudo.
--
-- NAO cria papeis nem matriz de permissao. Isso e uma decisao de desenho
-- maior e fica para o 004; nenhuma tela depende dela para existir.
-- ---------------------------------------------------------------------

-- =====================================================================
-- 1. CONCORRENTES AO LONGO DO TEMPO
--
-- `concorrentes` (do 001) guarda quem e. Esta guarda como ele estava em
-- cada varredura. E o que permite dizer "voce ultrapassou 3 concorrentes".
-- =====================================================================
create table if not exists concorrente_snapshots (
  id             uuid primary key default gen_random_uuid(),
  concorrente_id uuid not null references concorrentes(id) on delete cascade,
  varredura_id   uuid not null references varreduras(id) on delete cascade,
  posicao_media  numeric(5,2),
  visibilidade   numeric(5,2),
  unique (concorrente_id, varredura_id)
);
create index if not exists idx_conc_snap_varredura on concorrente_snapshots(varredura_id);

-- =====================================================================
-- 2. REPUTACAO
-- =====================================================================
create table if not exists avaliacoes (
  id                uuid primary key default gen_random_uuid(),
  local_id          uuid not null references locais(id) on delete cascade,
  google_review_id  text,
  autor             text,
  nota              int,
  texto             text,
  criado_em         timestamptz not null default now(),
  respondido_em     timestamptz,
  resposta          text,
  -- apagado_em e o diferencial: o Google remove avaliacoes e quase ninguem
  -- mostra isso. Na sincronizacao, id que sumiu da resposta marca a data
  -- aqui em vez de apagar a linha. Sem isso nao da para contar "perdidas".
  apagado_em        timestamptz,
  unique (local_id, google_review_id)
);
create index if not exists idx_avaliacoes_local on avaliacoes(local_id, criado_em desc);

create table if not exists avaliacao_rascunhos (
  id            uuid primary key default gen_random_uuid(),
  avaliacao_id  uuid not null references avaliacoes(id) on delete cascade,
  variante      int not null default 1,
  texto         text not null,
  modelo        text,
  aceito        boolean,                          -- polegar para cima/baixo
  criado_em     timestamptz not null default now(),
  unique (avaliacao_id, variante)
);

create table if not exists avaliacao_stats (
  id         uuid primary key default gen_random_uuid(),
  local_id   uuid not null references locais(id) on delete cascade,
  mes        date not null,                       -- sempre dia 1 do mes
  total      int not null default 0,
  media      numeric(2,1),
  ganhas     int not null default 0,
  perdidas   int not null default 0,
  unique (local_id, mes)
);

create table if not exists modelos_resposta (
  id         uuid primary key default gen_random_uuid(),
  conta_id   uuid not null references contas(id) on delete cascade,
  nota       int,                                 -- null = serve para qualquer nota
  texto      text not null,
  pronto     boolean not null default false,      -- true = veio da biblioteca
  criado_em  timestamptz not null default now()
);
create index if not exists idx_modelos_conta on modelos_resposta(conta_id, nota);

create table if not exists cartaz_avaliacoes (
  local_id     uuid primary key references locais(id) on delete cascade,
  cor          text not null default '#00785C',
  slug         text unique,                       -- o link curto
  titulo       text not null default 'Avalie-nos no Google',
  descricao    text not null default 'Valorizamos sua opiniao!',
  frases       text[],                            -- palavras para o cliente citar
  mostrar_rodape boolean not null default true,
  formato      text not null default 'A4',        -- A4 | A5 | carta
  atualizado_em timestamptz not null default now()
);

-- =====================================================================
-- 3. CONTEUDO - publicacoes, ofertas e fotos
-- =====================================================================
create table if not exists conteudos (
  id               uuid primary key default gen_random_uuid(),
  local_id         uuid not null references locais(id) on delete cascade,
  tipo             text not null,                 -- post | oferta | foto
  situacao         text not null default 'rascunho', -- rascunho|agendado|publicado|falhou
  texto            text,
  midia_url        text,
  categoria_foto   text,                          -- exterior|interior|equipe|produto|acao
  cta_tipo         text,                          -- reservar|pedido|comprar|saiba_mais|inscrever|ligar
  cta_url          text,
  utm              jsonb,
  titulo           text,                          -- ofertas
  comeca_em        date,                          -- ofertas
  termina_em       date,                          -- ofertas
  termos           text,                          -- ofertas
  agendado_para    timestamptz,
  publicado_em     timestamptz,
  google_post_name text,
  google_estado    text,                          -- LIVE | REJECTED | ...
  erro             text,
  criado_em        timestamptz not null default now()
);
create index if not exists idx_conteudos_agenda on conteudos(local_id, agendado_para);
create index if not exists idx_conteudos_tipo   on conteudos(local_id, tipo, situacao);

-- =====================================================================
-- 4. AUDITORIA E TAREFAS
-- =====================================================================
create table if not exists auditorias (
  id         uuid primary key default gen_random_uuid(),
  local_id   uuid not null references locais(id) on delete cascade,
  criado_em  timestamptz not null default now(),
  dados      jsonb not null default '{}'::jsonb,  -- uma chave por aba
  nota       int                                  -- 0 a 100
);
create index if not exists idx_auditorias_local on auditorias(local_id, criado_em desc);

create table if not exists tarefas (
  id           uuid primary key default gen_random_uuid(),
  local_id     uuid not null references locais(id) on delete cascade,
  semana       date not null,                     -- segunda-feira da semana
  tipo         text not null,
  titulo       text not null,
  descricao    text,
  dados        jsonb,
  situacao     text not null default 'nova',      -- nova | feita | pulada
  bonus        boolean not null default false,
  concluida_em timestamptz,
  criado_em    timestamptz not null default now()
);
create index if not exists idx_tarefas_semana on tarefas(local_id, semana);

create table if not exists citacoes (
  id          uuid primary key default gen_random_uuid(),
  local_id    uuid not null references locais(id) on delete cascade,
  diretorio   text not null,
  url         text,
  situacao    text not null default 'a_fazer',    -- a_fazer|processando|ativa|perdida|ignorada
  conferido_em timestamptz,
  unique (local_id, diretorio)
);
create index if not exists idx_citacoes_local on citacoes(local_id, situacao);

-- =====================================================================
-- 5. PROTECAO E METRICAS DO GOOGLE
-- =====================================================================
create table if not exists locais_snapshots (
  id        uuid primary key default gen_random_uuid(),
  local_id  uuid not null references locais(id) on delete cascade,
  tirado_em timestamptz not null default now(),
  campos    jsonb not null
);
create index if not exists idx_snap_local on locais_snapshots(local_id, tirado_em desc);

create table if not exists protecao_eventos (
  id            uuid primary key default gen_random_uuid(),
  local_id      uuid not null references locais(id) on delete cascade,
  detectado_em  timestamptz not null default now(),
  campo         text not null,
  valor_antigo  text,
  valor_novo    text,
  acao          text,                             -- revertido | sinalizado | aceito
  revertido_em  timestamptz
);
create index if not exists idx_protecao_local on protecao_eventos(local_id, detectado_em desc);

-- As metricas do Google. A Performance API devolve 18 meses e NUNCA MAIS.
-- Por isso e upsert e nunca apaga: depois de 18 meses no ar teremos
-- historico que o proprio Google ja nao tem.
create table if not exists gbp_metricas (
  local_id  uuid not null references locais(id) on delete cascade,
  dia       date not null,
  metrica   text not null,
  valor     int not null default 0,
  primary key (local_id, dia, metrica)
);
create index if not exists idx_metricas_local on gbp_metricas(local_id, dia);

-- =====================================================================
-- 6. TRAVA DE QUOTA
--
-- A verificacao vive no banco, nao no frontend: o painel pode ser burlado,
-- o gatilho nao.
-- Regra: importar perfil acima da quota NAO recusa - cria como inativo.
-- Ligar otimizacao acima da quota recusa com mensagem, porque ali o usuario
-- clicou de proposito e precisa entender o motivo.
-- =====================================================================
create or replace function trava_quota_locais()
returns trigger
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  lim_ativos int;
  lim_otim   int;
  usados_ativos int;
  usados_otim   int;
begin
  select limite_locais, limite_otimizacao
    into lim_ativos, lim_otim
  from contas where id = new.conta_id;

  if new.ativo then
    select count(*) into usados_ativos
    from locais
    where conta_id = new.conta_id and ativo
      and id is distinct from new.id;

    if usados_ativos >= coalesce(lim_ativos, 1) then
      new.ativo := false;          -- nasce inativo, nao recusado
      new.otimizacao := false;
    end if;
  end if;

  if new.otimizacao then
    select count(*) into usados_otim
    from locais
    where conta_id = new.conta_id and otimizacao
      and id is distinct from new.id;

    if usados_otim >= coalesce(lim_otim, 1) then
      raise exception 'Limite de otimizacao atingido (% de %). Desative a otimizacao de outro perfil ou atualize o plano.',
        usados_otim, coalesce(lim_otim, 1);
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists tg_trava_quota_locais on locais;
create trigger tg_trava_quota_locais
  before insert or update of ativo, otimizacao on locais
  for each row execute function trava_quota_locais();

-- =====================================================================
-- 7. RLS
-- =====================================================================
alter table concorrente_snapshots enable row level security;
alter table avaliacoes            enable row level security;
alter table avaliacao_rascunhos   enable row level security;
alter table avaliacao_stats       enable row level security;
alter table modelos_resposta      enable row level security;
alter table cartaz_avaliacoes     enable row level security;
alter table conteudos             enable row level security;
alter table auditorias            enable row level security;
alter table tarefas               enable row level security;
alter table citacoes              enable row level security;
alter table locais_snapshots      enable row level security;
alter table protecao_eventos      enable row level security;
alter table gbp_metricas          enable row level security;

drop policy if exists "conc snapshots da conta" on concorrente_snapshots;
drop policy if exists "avaliacoes da conta"     on avaliacoes;
drop policy if exists "rascunhos da conta"      on avaliacao_rascunhos;
drop policy if exists "stats da conta"          on avaliacao_stats;
drop policy if exists "modelos da conta"        on modelos_resposta;
drop policy if exists "cartaz da conta"         on cartaz_avaliacoes;
drop policy if exists "conteudos da conta"      on conteudos;
drop policy if exists "auditorias da conta"     on auditorias;
drop policy if exists "tarefas da conta"        on tarefas;
drop policy if exists "citacoes da conta"       on citacoes;
drop policy if exists "snapshots da conta"      on locais_snapshots;
drop policy if exists "protecao da conta"       on protecao_eventos;
drop policy if exists "metricas da conta"       on gbp_metricas;

create policy "modelos da conta" on modelos_resposta
  for all using (conta_id = minha_conta() or e_admin());

create policy "avaliacoes da conta" on avaliacoes
  for all using (exists (select 1 from locais l where l.id = local_id
                 and (l.conta_id = minha_conta() or e_admin())));

create policy "stats da conta" on avaliacao_stats
  for all using (exists (select 1 from locais l where l.id = local_id
                 and (l.conta_id = minha_conta() or e_admin())));

create policy "cartaz da conta" on cartaz_avaliacoes
  for all using (exists (select 1 from locais l where l.id = local_id
                 and (l.conta_id = minha_conta() or e_admin())));

create policy "conteudos da conta" on conteudos
  for all using (exists (select 1 from locais l where l.id = local_id
                 and (l.conta_id = minha_conta() or e_admin())));

create policy "auditorias da conta" on auditorias
  for all using (exists (select 1 from locais l where l.id = local_id
                 and (l.conta_id = minha_conta() or e_admin())));

create policy "tarefas da conta" on tarefas
  for all using (exists (select 1 from locais l where l.id = local_id
                 and (l.conta_id = minha_conta() or e_admin())));

create policy "citacoes da conta" on citacoes
  for all using (exists (select 1 from locais l where l.id = local_id
                 and (l.conta_id = minha_conta() or e_admin())));

create policy "snapshots da conta" on locais_snapshots
  for all using (exists (select 1 from locais l where l.id = local_id
                 and (l.conta_id = minha_conta() or e_admin())));

create policy "protecao da conta" on protecao_eventos
  for all using (exists (select 1 from locais l where l.id = local_id
                 and (l.conta_id = minha_conta() or e_admin())));

create policy "metricas da conta" on gbp_metricas
  for all using (exists (select 1 from locais l where l.id = local_id
                 and (l.conta_id = minha_conta() or e_admin())));

create policy "rascunhos da conta" on avaliacao_rascunhos
  for all using (exists (
    select 1 from avaliacoes a join locais l on l.id = a.local_id
    where a.id = avaliacao_id
      and (l.conta_id = minha_conta() or e_admin())));

create policy "conc snapshots da conta" on concorrente_snapshots
  for all using (exists (
    select 1 from varreduras v join locais l on l.id = v.local_id
    where v.id = varredura_id
      and (l.conta_id = minha_conta() or e_admin())));

-- =====================================================================
-- 8. CONFERENCIA - uma consulta so
-- Esperado: 13 tabelas "criada", 13 policies "ok", o gatilho "ok".
-- =====================================================================
select 'tabela: ' || t as item,
       case when to_regclass('public.' || t) is null then 'FALTOU' else 'criada' end as situacao
from unnest(array['concorrente_snapshots','avaliacoes','avaliacao_rascunhos',
                  'avaliacao_stats','modelos_resposta','cartaz_avaliacoes',
                  'conteudos','auditorias','tarefas','citacoes',
                  'locais_snapshots','protecao_eventos','gbp_metricas']) as t
union all
select 'policy: ' || tablename,
       case when count(*) > 0 then 'ok' else 'FALTOU' end
from pg_policies
where schemaname = 'public'
  and tablename in ('concorrente_snapshots','avaliacoes','avaliacao_rascunhos',
                    'avaliacao_stats','modelos_resposta','cartaz_avaliacoes',
                    'conteudos','auditorias','tarefas','citacoes',
                    'locais_snapshots','protecao_eventos','gbp_metricas')
group by tablename
union all
select 'gatilho: tg_trava_quota_locais',
       case when exists (select 1 from pg_trigger where tgname = 'tg_trava_quota_locais')
            then 'ok' else 'FALTOU' end
order by item;
