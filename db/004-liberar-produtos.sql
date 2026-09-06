-- ---------------------------------------------------------------------
-- 004 - LIBERAR OS PRODUTOS PARA AS CONTAS QUE JA EXISTEM
--
-- Roda no SQL Editor do Supabase, na MESMA aba, depois do 001.
-- Idempotente.
--
-- POR QUE ISTO E NECESSARIO
--
-- O 001 criou o catalogo `produtos` com duas linhas, mas nao ligou nenhuma
-- conta a nenhum produto. Sem isso o seletor do canto superior esquerdo nao
-- tem o que mostrar, e o painel abre vazio parecendo defeito.
--
-- O QUE ESTE ARQUIVO DECIDE
--
--   Easy One Chatbot -> liberado para TODAS as contas que ja existem.
--                       Elas sao os clientes do chatbot, entao e verdade.
--   Easy One Rank    -> liberado so para as contas de ADMIN.
--                       Ninguem comprou o Rank ainda.
--
-- O efeito na tela e exatamente o que precisamos testar: cliente comum ve um
-- rotulo fixo com um produto so, e o admin ve o menu com os dois.
--
-- Para liberar o Rank a um cliente depois, e uma linha:
--   insert into conta_produtos (conta_id, produto_id, status)
--   select 'ID-DA-CONTA', id, 'ativo' from produtos where slug = 'easy-rank'
--   on conflict (conta_id, produto_id) do update set status = 'ativo';
-- ---------------------------------------------------------------------

-- Easy One Chatbot para todo mundo que ja e conta
insert into conta_produtos (conta_id, produto_id, status)
select c.id, p.id, 'ativo'
from contas c
cross join produtos p
where p.slug = 'easy-chat'
on conflict (conta_id, produto_id) do update set status = 'ativo';

-- Easy One Rank so para quem e admin
insert into conta_produtos (conta_id, produto_id, status)
select distinct pf.conta_id, p.id, 'ativo'
from perfis pf
cross join produtos p
where pf.papel = 'admin'
  and pf.conta_id is not null
  and p.slug = 'easy-rank'
on conflict (conta_id, produto_id) do update set status = 'ativo';

-- =====================================================================
-- CONFERENCIA - uma consulta so
--
-- A ultima linha e a que importa: mostra o seu usuario, se ele tem perfil
-- e a que conta pertence. Se `perfil` vier "FALTA", o painel vai abrir
-- vazio - o `minha_conta()` devolve nulo e a RLS barra tudo.
-- =====================================================================
select 'conta: ' || c.nome as item,
       string_agg(p.nome, ' + ' order by p.ordem) as valor
from contas c
join conta_produtos cp on cp.conta_id = c.id and cp.status = 'ativo'
join produtos p on p.id = cp.produto_id
group by c.nome
union all
select 'usuario: ' || u.email,
       case when pf.id is null then 'FALTA PERFIL - vai abrir vazio'
            else 'perfil ok, papel ' || pf.papel ||
                 ', conta ' || coalesce((select nome from contas where id = pf.conta_id), 'NENHUMA')
       end
from auth.users u
left join perfis pf on pf.id = u.id
order by item;
