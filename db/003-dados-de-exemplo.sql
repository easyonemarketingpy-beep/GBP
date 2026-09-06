-- ---------------------------------------------------------------------
-- 003 - DADOS DE EXEMPLO
--
-- Roda no SQL Editor do Supabase, na MESMA aba, DEPOIS do 001 e do 002.
-- Idempotente: apaga o exemplo anterior e refaz. Pode rodar quantas vezes
-- quiser sem duplicar nada.
--
-- POR QUE ISTO EXISTE
--
-- Os prompts 3 a 7 da fila gastariam boa parte dos creditos so mandando o
-- Lovable "gerar dados de exemplo". Gerado aqui, em SQL, custa zero - e sai
-- melhor, porque tem forma de negocio de verdade: posicao que melhora com o
-- tempo, avaliacao que o Google apagou, ponto de grade sem resultado.
--
-- TUDO fica marcado com google_place_id comecando em 'demo-'. Para apagar:
--   delete from locais where google_place_id like 'demo-%';
-- O resto vai junto pela cascata.
--
-- SEGURANCA: nao toca em nenhuma tabela do chatbot. So escreve nas tabelas
-- do Rank criadas em 001 e 002.
-- ---------------------------------------------------------------------

do $$
declare
  v_conta   uuid;
  v_local   uuid;
  v_palavra uuid;
  v_conc    uuid;
  r_local   record;
  r_palavra record;
  i         int;
  v_nota    numeric;
begin
  -- Usa a primeira conta que existir. Se voce tiver varias e quiser outra,
  -- troque esta linha por:  select id into v_conta from contas where nome = 'X';
  select id into v_conta from contas order by criado_em limit 1;
  if v_conta is null then
    raise exception 'Nenhuma conta encontrada. Crie uma conta antes de rodar o 003.';
  end if;

  -- Limpa o exemplo anterior (cascata leva palavras, varreduras, pontos,
  -- avaliacoes, conteudos, tarefas e auditorias junto).
  delete from locais where google_place_id like 'demo-%';

  -- A trava de quota do 002 derrubaria os perfis 2 e 3 para inativo, e
  -- recusaria a otimizacao. Sobe o limite para o exemplo caber e para os
  -- contadores da tela ficarem com cara de plano de agencia.
  update contas set limite_locais = 10, limite_otimizacao = 5 where id = v_conta;

  -- =================================================================
  -- LOCAIS
  -- =================================================================
  insert into locais (conta_id, google_place_id, nome, endereco, lat, lng,
                      categoria, categorias, telefone, site, nota,
                      total_avaliacoes, ativo, otimizacao, protecao, horarios)
  values
    (v_conta, 'demo-1', 'Grupo Faustino Camiones',
     'F5C3+Q7, Nueva Esperanza, Canindeyu, PY', -24.3167, -54.6500,
     'Loja de autopecas', array['Loja de autopecas','Oficina de caminhoes'],
     '+595 983 000001', 'https://exemplo.com.py', 4.3, 82, true, true, false,
     '{"seg":"07:00-18:00","ter":"07:00-18:00","qua":"07:00-18:00","qui":"07:00-18:00","sex":"07:00-18:00","sab":"07:00-12:00","dom":"fechado"}'::jsonb),
    (v_conta, 'demo-2', 'Easy Bikes Motorcycle Rentals',
     '6 Letchford Mews, London NW10 6AG, UK', 51.5330, -0.2400,
     'Aluguel de motocicletas', array['Aluguel de motocicletas','Oficina de motos'],
     '+44 20 0000 0002', 'https://exemplo.co.uk', 4.7, 41, true, true, true,
     '{"seg":"09:00-18:00","ter":"09:00-18:00","qua":"09:00-18:00","qui":"09:00-18:00","sex":"09:00-18:00","sab":"10:00-16:00","dom":"fechado"}'::jsonb),
    (v_conta, 'demo-3', 'Oficina Central Pedro Juan',
     'C7H8+9WX, Pedro Juan Caballero, Amambay, PY', -22.5470, -55.7330,
     'Oficina mecanica', array['Oficina mecanica','Loja de pneus'],
     '+595 983 000003', null, 3.9, 17, true, false, false,
     '{"seg":"08:00-17:30","ter":"08:00-17:30","qua":"08:00-17:30","qui":"08:00-17:30","sex":"08:00-17:30","sab":"08:00-12:00","dom":"fechado"}'::jsonb);

  -- =================================================================
  -- PALAVRAS-CHAVE - 5 por local
  -- =================================================================
  select id into v_local from locais where google_place_id = 'demo-1';
  insert into palavras_chave (local_id, termo, volume_busca, frequencia) values
    (v_local, 'repuestos para camiones nueva esperanza', 140, 'semanal'),
    (v_local, 'autopecas de caminhao py',                90, 'semanal'),
    (v_local, 'taller de camiones canindeyu',            70, 'quinzenal'),
    (v_local, 'pecas scania paraguai',                  210, 'semanal'),
    (v_local, 'filtros e oleo para caminhao',            50, 'mensal');

  select id into v_local from locais where google_place_id = 'demo-2';
  insert into palavras_chave (local_id, termo, volume_busca, frequencia) values
    (v_local, 'scooter rental london',       880, 'semanal'),
    (v_local, 'motorcycle hire nw10',        170, 'semanal'),
    (v_local, 'rent to buy scooter uk',      320, 'semanal'),
    (v_local, 'delivery moped rental',       260, 'quinzenal'),
    (v_local, 'motorbike repair willesden',   90, 'mensal');

  select id into v_local from locais where google_place_id = 'demo-3';
  insert into palavras_chave (local_id, termo, volume_busca, frequencia) values
    (v_local, 'oficina mecanica pedro juan caballero', 190, 'semanal'),
    (v_local, 'troca de oleo pjc',                      60, 'semanal'),
    (v_local, 'borracharia pedro juan',                110, 'quinzenal'),
    (v_local, 'mecanico 24 horas amambay',              40, 'mensal'),
    (v_local, 'alinhamento e balanceamento pjc',        80, 'mensal');

  -- =================================================================
  -- CONCORRENTES - 20 por local
  -- =================================================================
  for r_local in select id, lat, lng from locais where google_place_id like 'demo-%' loop
    for i in 1..20 loop
      insert into concorrentes (local_id, google_place_id, nome, endereco,
                                categoria, nota, total_avaliacoes)
      values (r_local.id, 'demo-c-' || r_local.id || '-' || i,
              'Concorrente ' || i,
              'Rua ' || i || ', centro',
              case when i % 3 = 0 then 'Oficina mecanica'
                   when i % 3 = 1 then 'Loja de autopecas'
                   else 'Comercio de pneu' end,
              round((3.2 + random() * 1.7)::numeric, 1),
              (5 + random() * 250)::int);
    end loop;
  end loop;
end $$;

-- =====================================================================
-- VARREDURAS E PONTOS
--
-- 12 semanas, sempre sexta-feira, para cada palavra-chave.
-- Grade 7x7 = 49 pontos por varredura.
--
-- A posicao e melhor perto do centro e pior nas bordas, e MELHORA com o
-- tempo - e o que faz o minigrafico da tela ter forma de trabalho dando
-- resultado, em vez de uma linha reta.
-- =====================================================================
create temp table tmp_pontos on commit drop as
with base as (
  select p.id as palavra_id, p.local_id, l.lat, l.lng,
         gs.semana,
         (date_trunc('week', now())::date - (gs.semana * 7) + 4)::timestamptz
           + interval '11 hours' as medido_em
  from palavras_chave p
  join locais l on l.id = p.local_id
  cross join generate_series(0, 11) as gs(semana)
  where l.google_place_id like 'demo-%'
),
grade as (
  select b.*, r.linha, c.coluna,
         b.lat + ((r.linha - 3) * (3000.0 / 6) / 111320.0) as plat,
         b.lng + ((c.coluna - 3) * (3000.0 / 6)
                  / (111320.0 * cos(radians(b.lat))))       as plng,
         sqrt(power(r.linha - 3, 2) + power(c.coluna - 3, 2)) as dist
  from base b
  cross join generate_series(0, 6) as r(linha)
  cross join generate_series(0, 6) as c(coluna)
)
select palavra_id, local_id, semana, medido_em, linha, coluna, plat, plng,
       case
         -- ponto distante tem chance de nao retornar o negocio
         when dist > 3.4 and random() < 0.28 then null
         else greatest(1, least(20,
                round(1 + dist * 2.1 + semana * 0.32 + (random() * 2.4 - 1.2))::int))
       end as posicao
from grade;

insert into varreduras (palavra_id, local_id, medido_em, tamanho, raio_m,
                        formato, posicao_media, visibilidade, dificuldade,
                        situacao, custo_usd)
select palavra_id, local_id, medido_em, 7, 3000, 'quadrado',
       round(avg(posicao) filter (where posicao is not null), 2),
       round(100.0 * count(*) filter (where posicao <= 3) / count(*), 2),
       case
         when avg(posicao) filter (where posicao is not null) < 4  then 'baixa'
         when avg(posicao) filter (where posicao is not null) < 9  then 'media'
         else 'alta'
       end,
       'ok', 0.0294
from tmp_pontos
group by palavra_id, local_id, medido_em;

insert into pontos_varredura (varredura_id, linha, coluna, lat, lng, posicao)
select v.id, t.linha, t.coluna, t.plat, t.plng, t.posicao
from tmp_pontos t
join varreduras v
  on v.palavra_id = t.palavra_id and v.medido_em = t.medido_em;

update palavras_chave p
   set medida_em = (select max(medido_em) from varreduras where palavra_id = p.id)
 where exists (select 1 from varreduras where palavra_id = p.id);

-- =====================================================================
-- AVALIACOES, RESPOSTAS E O RESUMO MENSAL
--
-- Algumas avaliacoes nascem com apagado_em preenchido: sao as que o Google
-- removeu. E o que alimenta a coluna "perdidas" do grafico, que quase
-- nenhuma ferramenta do mercado mostra.
-- =====================================================================
insert into avaliacoes (local_id, google_review_id, autor, nota, texto,
                        criado_em, respondido_em, resposta, apagado_em)
select l.id,
       'demo-r-' || l.id || '-' || g.n,
       (array['Ezequias L.','Sidinei G.','Antonio O.','Marlene O.','Javier E.',
              'Claudio D.','Vilmar A.','Anderson H.','Rita S.','Paulo M.',
              'Nadia B.','Tiago R.'])[1 + (g.n % 12)],
       case when random() < 0.72 then 5
            when random() < 0.85 then 4
            when random() < 0.93 then 3
            when random() < 0.97 then 2
            else 1 end,
       (array['Atendimento rapido e preco justo.',
              'Achei a peca que ninguem tinha. Recomendo.',
              'Bom servico, mas demorou mais que o combinado.',
              'Equipe atenciosa, voltarei.',
              'Resolveram no mesmo dia.',
              null])[1 + (g.n % 6)],
       now() - ((350 - g.n * 9) || ' days')::interval,
       case when g.n % 3 = 0 then now() - ((348 - g.n * 9) || ' days')::interval end,
       case when g.n % 3 = 0 then 'Obrigado pelo retorno! Conte com a gente sempre que precisar.' end,
       -- 1 em cada 12 foi apagada pelo Google
       case when g.n % 12 = 5 then now() - ((60 - g.n) || ' days')::interval end
from locais l
cross join generate_series(1, 34) as g(n)
where l.google_place_id like 'demo-%';

insert into avaliacao_stats (local_id, mes, total, media, ganhas, perdidas)
select local_id,
       date_trunc('month', criado_em)::date,
       count(*),
       round(avg(nota)::numeric, 1),
       count(*) filter (where apagado_em is null),
       count(*) filter (where apagado_em is not null)
from avaliacoes
where local_id in (select id from locais where google_place_id like 'demo-%')
group by local_id, date_trunc('month', criado_em)
on conflict (local_id, mes) do update
  set total = excluded.total, media = excluded.media,
      ganhas = excluded.ganhas, perdidas = excluded.perdidas;

-- =====================================================================
-- CONTEUDO - publicacoes, ofertas e fotos, passadas e agendadas
-- =====================================================================
insert into conteudos (local_id, tipo, situacao, texto, titulo,
                       cta_tipo, agendado_para, publicado_em, google_estado,
                       comeca_em, termina_em)
select l.id,
       (array['post','post','post','oferta','foto'])[1 + (g.n % 5)],
       case when g.n <= 8 then 'publicado' else 'agendado' end,
       (array['Chegaram pecas novas para a linha pesada. Passe na loja.',
              'Troca de oleo e filtros com hora marcada.',
              'Atendemos todo o pais, com envio no mesmo dia.',
              'Promocao da semana em itens selecionados.',
              'Equipe pronta para o seu servico.'])[1 + (g.n % 5)],
       case when g.n % 5 = 3 then 'Promocao da semana' end,
       (array['saiba_mais','ligar','pedido',null,null])[1 + (g.n % 5)],
       case when g.n > 8 then now() + ((g.n - 8) * 2 || ' days')::interval end,
       case when g.n <= 8 then now() - ((g.n * 6) || ' days')::interval end,
       case when g.n <= 8 then 'LIVE' end,
       case when g.n % 5 = 3 then current_date end,
       case when g.n % 5 = 3 then current_date + 30 end
from locais l
cross join generate_series(1, 14) as g(n)
where l.google_place_id like 'demo-%';

-- =====================================================================
-- TAREFAS DA SEMANA - 6 por local, uma delas bonus
-- =====================================================================
insert into tarefas (local_id, semana, tipo, titulo, descricao, situacao, bonus)
select l.id, date_trunc('week', now())::date, t.tipo, t.titulo, t.descricao,
       case when t.ord <= 2 then 'feita' else 'nova' end,
       t.ord = 7
from locais l
cross join (values
  (1,'protecao','Protecao do Perfil da empresa','Proteja seu Perfil da empresa no Google de concorrentes desonestos.'),
  (2,'categoria','Adicionar a categoria adicional','Confira as categorias adicionais sugeridas para o seu negocio.'),
  (3,'post','Crie e agende uma publicacao do Google','Publicacoes do perfil sao envolventes e dificeis de ignorar.'),
  (4,'foto','Adicione fotos ao seu Perfil da empresa','Mantenha o que voce oferece em evidencia publicando fotos.'),
  (5,'citacao','Criar citacoes de negocio em um diretorio online','Alcance mais clientes sendo listado em diretorios do setor.'),
  (6,'avaliacao','Responda as Avaliacoes de Usuarios no Google','Mostre aos seus clientes que voce se importa.'),
  (7,'bonus','Tarefa bonus: revise a descricao do negocio','Uma descricao com as palavras certas ajuda a ranquear.')
) as t(ord, tipo, titulo, descricao)
where l.google_place_id like 'demo-%';

-- =====================================================================
-- AUDITORIA - uma por local, com o mapa de calor de horarios
--
-- O mapa tem forma de negocio de verdade: madrugada vazia, pico comercial,
-- sabado fraco a tarde, domingo zerado.
-- =====================================================================
insert into auditorias (local_id, dados, nota)
select l.id,
       jsonb_build_object(
         'nome', jsonb_build_object('comprimento_ok', true, 'caracteres', length(l.nome),
                                    'termos', to_jsonb(array['repuestos','camiones','oficina','pecas'])),
         'descricao', jsonb_build_object('comprimento', 359, 'limite', 750, 'qualidade', 'aceitavel'),
         'categoria', jsonb_build_object('principal', l.categoria,
                                         'sugeridas', to_jsonb(array['Oficina de caminhoes','Loja de pneus','Distribuidor de motores diesel'])),
         'horarios', (
           select jsonb_agg(dia_linha order by dia)
           from (
             select d.dia,
                    jsonb_build_object('dia', d.dia, 'horas', (
                      select jsonb_agg(
                        case
                          when d.dia = 6 then 0
                          when h.h < 7 or h.h > 18 then 0
                          when d.dia = 5 and h.h > 12 then (2 + random()*3)::int
                          else (11 + random()*4)::int
                        end order by h.h)
                      from generate_series(0,23) as h(h)
                    )) as dia_linha
             from generate_series(0,6) as d(dia)
           ) x
         ),
         'avaliacoes', jsonb_build_object('atual', l.total_avaliacoes,
                                          'mediana_concorrentes', l.total_avaliacoes + 16,
                                          'meta', 'Trabalhe para obter pelo menos 16 avaliacoes adicionais'),
         'imagens', jsonb_build_object('atual', 8, 'meta', 'Adicione pelo menos 4 fotos'),
         'publicacoes', jsonb_build_object('ultima_em_dias', 6, 'meta', 'Para resultados ideais, publique semanalmente')
       ),
       (58 + random() * 34)::int
from locais l
where l.google_place_id like 'demo-%';

-- =====================================================================
-- METRICAS DO GOOGLE - 90 dias, 4 metricas
-- =====================================================================
insert into gbp_metricas (local_id, dia, metrica, valor)
select l.id, (current_date - g.d), m.metrica,
       greatest(0, (m.base * (0.65 + random() * 0.7)
                    * (1 + (90 - g.d) * 0.004))::int)
from locais l
cross join generate_series(0, 89) as g(d)
cross join (values ('BUSINESS_IMPRESSIONS_MOBILE_MAPS', 34),
                   ('BUSINESS_IMPRESSIONS_MOBILE_SEARCH', 18),
                   ('CALL_CLICKS', 3),
                   ('BUSINESS_DIRECTION_REQUESTS', 5),
                   ('WEBSITE_CLICKS', 2)) as m(metrica, base)
where l.google_place_id like 'demo-%'
on conflict (local_id, dia, metrica) do update set valor = excluded.valor;

-- =====================================================================
-- CONFERENCIA - uma consulta so
-- =====================================================================
select 'conta usada'            as item, (select nome from contas order by criado_em limit 1) as valor
union all select 'locais',              count(*)::text from locais where google_place_id like 'demo-%'
union all select 'palavras-chave',      count(*)::text from palavras_chave p join locais l on l.id=p.local_id where l.google_place_id like 'demo-%'
union all select 'varreduras',          count(*)::text from varreduras v join locais l on l.id=v.local_id where l.google_place_id like 'demo-%'
union all select 'pontos de grade',     count(*)::text from pontos_varredura pv join varreduras v on v.id=pv.varredura_id join locais l on l.id=v.local_id where l.google_place_id like 'demo-%'
union all select 'concorrentes',        count(*)::text from concorrentes c join locais l on l.id=c.local_id where l.google_place_id like 'demo-%'
union all select 'avaliacoes',          count(*)::text from avaliacoes a join locais l on l.id=a.local_id where l.google_place_id like 'demo-%'
union all select 'avaliacoes apagadas', count(*)::text from avaliacoes a join locais l on l.id=a.local_id where l.google_place_id like 'demo-%' and a.apagado_em is not null
union all select 'conteudos',           count(*)::text from conteudos c join locais l on l.id=c.local_id where l.google_place_id like 'demo-%'
union all select 'tarefas',             count(*)::text from tarefas t join locais l on l.id=t.local_id where l.google_place_id like 'demo-%'
union all select 'auditorias',          count(*)::text from auditorias a join locais l on l.id=a.local_id where l.google_place_id like 'demo-%'
union all select 'metricas do google',  count(*)::text from gbp_metricas m join locais l on l.id=m.local_id where l.google_place_id like 'demo-%'
order by item;
