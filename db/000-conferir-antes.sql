-- ---------------------------------------------------------------------
-- 000 - CONFERIR ANTES DE RODAR O 001
--
-- Uma consulta so. SQL Editor do Supabase, na mesma aba de sempre.
--
-- Responde duas perguntas de uma vez:
--   1. Estou no projeto certo? (o do chatbot, com contas/perfis/instancias)
--   2. Os nomes que o Rank vai criar estao livres?
--
-- `create table if not exists` PULA em silencio se ja existir tabela com o
-- mesmo nome e outro formato. Por isso a conferencia vem antes.
-- ---------------------------------------------------------------------
select 'chatbot: ' || t as item,
       case when to_regclass('public.' || t) is null
            then 'FALTOU - projeto errado'
            else 'ok' end as situacao
from unnest(array['contas','perfis','instancias']) as t
union all
select 'funcao: ' || p,
       case when exists (select 1 from pg_proc where proname = p)
            then 'ok'
            else 'FALTOU - projeto errado' end
from unnest(array['minha_conta','e_admin']) as p
union all
select 'rank: ' || t,
       case when to_regclass('public.' || t) is null
            then 'livre'
            else 'JA EXISTE - me avise antes de rodar o 001' end
from unnest(array['produtos','conta_produtos','locais','palavras_chave',
                  'varreduras','pontos_varredura','concorrentes']) as t
order by item;
