# Projeto - Easy One Rank

## O que e
Plataforma de gestao e ranqueamento de Perfis da Empresa no Google (GBP), para
agencias que cuidam de varios clientes e para negocios locais. Segundo produto
do portfolio Easy One. Vendido separado do chatbot, com landing page propria.

## Independente do chatbot, menos por um ponto
Repositorio proprio, projeto proprio no Lovable, deploy proprio.
O UNICO acoplamento e o **banco do Supabase**, compartilhado com o
easyone-chatbot-platform. Consequencias, todas de proposito:

- **Um login so.** A pessoa entra uma vez e as duas plataformas a reconhecem.
- **Uma tabela de contas so.** `contas` e `perfis` sao as do chatbot.
- **O menu da logo funciona.** Em app.easyonemarketing.com, clicar na logo
  mostra "Easy One Chatbot" e "Easy One Rank" conforme o que a conta comprou,
  lendo de `conta_produtos`.

Se o banco fosse separado, o menu nao teria como saber o que a pessoa comprou
sem inventar uma terceira plataforma de identidade.

## Stack
- **Painel:** Lovable + Supabase Auth (projeto Lovable separado do chatbot)
- **Dados:** Supabase - o MESMO projeto do chatbot
- **Posicao no mapa:** DataForSEO Google Maps API, via n8n na VPS
- **Perfil do Google:** Google Business Profile APIs (v1 + v4 legada)
- **IA:** Anthropic - Sonnet 5 no volume, Opus 5 na auditoria e no Brand Voice
- **Mapa:** MapLibre GL + tiles do OpenStreetMap. Nunca Google Maps.

## Invariantes - nao quebrar
1. **`varreduras` e `pontos_varredura` sao imutaveis.** Cada medicao grava uma
   linha nova em `varreduras` e N em `pontos_varredura`. Nenhum update, nunca.
   O historico por data e `order by medido_em desc` - nao existe tabela de
   historico separada.
2. **Nada de dado fixo dentro das telas.** Todo dado de exemplo vai gravado nas
   tabelas reais. E o que faz a troca por dado real depois custar uma funcao em
   vez de sete telas.
3. **Metrica derivada e calculada na gravacao, nunca na leitura.**
   `posicao_media`, `visibilidade` e `dificuldade` ja entram prontas.
4. **Toda tabela nova entra com RLS.** Produto vendido a terceiros: um cliente
   ver o Perfil do Google de outro nao e defeito, e incidente.
5. **A chave de servico do Supabase so existe no n8n.** Nunca no painel.
6. **Guardar toda metrica do Google desde o primeiro dia.** A Performance API
   devolve 18 meses e nunca mais. O que nao for gravado, se perde.

## Convencoes do SQL
Mesmas do repositorio do chatbot, porque o SQL Editor e o mesmo:
- **ASCII puro.** O paste do editor do Supabase corrompe acento e trunca.
- **Idempotente:** `create table if not exists`, `add column if not exists`,
  `drop policy if exists` antes de `create policy`.
- **Uma conferencia so no fim, com `union all`.** O SQL Editor mostra apenas o
  resultado da ultima instrucao; varias consultas fazem as anteriores sumirem.
- **`set search_path = public, extensions`** em funcao `security definer`. Se
  trancar so em `public`, o pgcrypto some e o gatilho quebra sem erro claro.
- Nomes em portugues, como no resto da plataforma.

## Ordem de trabalho
1. Supabase: rodar `db/001-produtos-e-locais.sql`
2. Lovable: projeto novo, ligado a ESTE repositorio e ao MESMO Supabase
3. Rodar os prompts de tela em `docs/`, um por vez
4. n8n: worker de varredura (DataForSEO) - primeiro contrato de freelancer
5. Google: so quando a quota for aprovada
