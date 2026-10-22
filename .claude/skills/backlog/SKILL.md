---
name: backlog
description: "Use para lançar, consultar, priorizar, iniciar, concluir ou descartar itens do backlog do projeto ar (ideias, bugs, melhorias, features, tarefas do app do ar-condicionado, por urgência P0–P3 e módulo nuvem, automacao, app ou projeto) e para gerar o resumo mensal do que mudou — '/backlog bug P1 app: ...', '/backlog next', '/backlog relatório outubro'. Também vale quando, no meio de outra tarefa, aparece um bug ou ideia que precisa ser registrado, ou quando uma entrega fecha um item."
---

# /backlog — backlog de desenvolvimento do ar

Fonte: `docs/backlog/itens/*.md` (regras em `docs/backlog/README.md`).
CLI: `node tools/backlog/backlog.mjs <cmd>` (new, set, list, next, board, report, check).
Quadro gerado: `docs/backlog/BACKLOG.md`. Relatórios: `docs/relatorios/backlog/`.

## Interpretar o pedido

O dono fala natural. Deduza e confirme só o que faltar:

- **tipo**: "não funciona / não ligou / erro" → bug · "podia / melhorar" → melhoria · "e se / ideia" → ideia · "vamos fazer / quero" já decidido → feature · ferramenta, docs, setup → tarefa.
- **urgência**: "o ar não liga mais / parou" → P0 · "esta semana / está atrapalhando" → P1 · sem pressa explícita em bug ou melhoria → P2 · ideia / polimento → P3. Se o dono deu P0–P3, use.
- **módulos**: falar com a Midea → nuvem · localização, chegar em casa, disparo → automacao · tela, botão, Xcode, instalar → app · ferramentas e docs → projeto.
- **título**: uma linha, sem "bug:" no começo. Contexto vai no corpo.

Para **bug**, antes de considerar o item completo, pergunte (ou extraia da conversa) como reproduzir
e escreva na seção `## Como reproduzir`. Sem isso o `check` falha.

## Fluxos

**Lançar**: `new` com os campos deduzidos → editar o arquivo para preencher Contexto/Como reproduzir/Proposta com o que a conversa já disse → mostrar `#id · arquivo` ao dono. Não pergunte o que já está na conversa.

**Consultar**: `next` (o que atacar agora; no fim, o que aguarda teste no aparelho) · `list --status aberto --modulo x` · "o que falta eu testar?" → `list --validacao pendente`.

**Iniciar**: `set <id> status=em-andamento` no começo da tarefa que vai resolvê-lo.

**Concluir**: ao fechar a entrega — `set <id> status=feito commits="sha" resumo="frase para quem usa o app"` e `set <id> nota="o que foi feito / o que ficou para testar"`. Se o dono ainda não testou no iPhone ou no Mac, acrescente `validacao=pendente`. O `resumo` diz o que mudou na tela ou no comportamento, sem nome de arquivo, sha, endpoint ou jargão.

**Validar**: quando o dono diz que testou — `set <id> validacao=ok nota="Dono testou no iPhone."`.

**Descartar**: `set <id> nota="motivo" status=descartado`.

**Relatório**: `report --periodo AAAA-MM [--tipo resumo|tecnico]`.

**Commit dos itens**: junto com a entrega que os fecha; sem código, branch `chore/backlog-<slug>`, `git add docs/backlog/itens/<arquivo> docs/backlog/BACKLOG.md`, mensagem `backlog: #id título`. `check` antes do commit.

## Regras que valem em toda sessão, mesmo sem /backlog

1. Toda entrega que resolve um item fecha o item (status=feito, commits, resumo) antes de dar a tarefa por concluída.
2. Bug ou ideia que aparece no meio de outra tarefa vira item na hora (`new`), sem esperar o fim.
3. O quadro `BACKLOG.md` é a fonte do "Próxima sessão começa AQUI" da memória: a memória aponta ids (`#12`), não repete texto.
4. Pendência de teste no aparelho vive no campo `validacao` do item, não na memória.

## Não fazer

- Não editar `BACKLOG.md` à mão. Não criar item sem passar pela CLI (o id vem dela).
- Não usar o backlog para tarefas de uma sessão só; só o que sobrevive à sessão.
- Não inventar P0: só quando o app parou de ligar o ar.
