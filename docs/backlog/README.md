# Backlog de desenvolvimento

Um arquivo por item em `itens/NNNN-slug.md`. `BACKLOG.md` é gerado — nunca editar à mão.
Operar sempre pela CLI (`node tools/backlog/backlog.mjs <cmd>`) ou pela skill `/backlog`;
editar o arquivo à mão só para escrever Contexto, Como reproduzir e Proposta.

## Campos do cabeçalho

| Campo | Valores | Regra |
|---|---|---|
| id | inteiro | igual ao prefixo do nome; sequencial, nunca reaproveitado |
| titulo | texto livre, uma linha | obrigatório; vira o slug do arquivo |
| tipo | bug, melhoria, ideia, feature, tarefa | bug: deveria funcionar e não funciona · melhoria: funciona, pode ficar melhor · ideia: ainda não decidido · feature: novo e aprovado · tarefa: projeto, ferramenta, docs, débito |
| urgencia | P0, P1, P2, P3 | P0 agora (o app parou de ligar o ar) · P1 esta semana · P2 próximo ciclo · P3 quando der |
| status | aberto, em-andamento, feito, descartado | feito exige `concluido` + commits (+ `resumo` em bug/melhoria/feature); descartado exige motivo nas Notas |
| modulos | nuvem, automacao, app, projeto | ao menos um. nuvem: falar com a Midea · automacao: localização e disparo · app: telas e projeto Xcode · projeto: ferramentas, docs, setup |
| criado / iniciado / concluido | AAAA-MM-DD | a CLI preenche iniciado e concluido |
| commits | ["sha", ...] | `set N commits="+sha"` acrescenta |
| relacionados | [ids] | opcional |
| resumo | frase(s) sem termo técnico | o que mudou para quem usa o app; vai para o relatório mensal. `check` recusa sha, caminho de arquivo, endpoint, payload, commit, PR, merge, API, SwiftUI, Keychain |
| validacao | pendente, ok | teste do dono no iPhone/Mac depois da entrega. `pendente` = entregue sem o dono testar; `ok` = testou; vazio = não se aplica |

## Corpo

Exatamente estas seções, nesta ordem: `## Contexto`, `## Como reproduzir` (obrigatória em bug),
`## Proposta`, `## Notas de execução` (uma linha por data; `set N nota=...` acrescenta).

## Comandos

    node tools/backlog/backlog.mjs new --tipo bug --urgencia P1 --modulos app --titulo "..."
    node tools/backlog/backlog.mjs set 12 status=em-andamento
    node tools/backlog/backlog.mjs set 12 status=feito commits="a1b2c3d" resumo="..." validacao=pendente
    node tools/backlog/backlog.mjs set 12 validacao=ok nota="Dono testou no iPhone."
    node tools/backlog/backlog.mjs list --status aberto --modulo nuvem
    node tools/backlog/backlog.mjs list --validacao pendente
    node tools/backlog/backlog.mjs next
    node tools/backlog/backlog.mjs board
    node tools/backlog/backlog.mjs report --periodo AAAA-MM [--tipo resumo|tecnico]
    node tools/backlog/backlog.mjs check

## Regras de sessão

1. Entrega que resolve um item termina com `set <id> status=feito commits=... resumo=...`.
2. Bug ou ideia encontrada no caminho vira item na hora.
3. `check` antes de commitar itens; `board` depois de qualquer alteração (a CLI já faz).
4. Itens são commitados junto com a entrega que os fecha, ou numa branch `chore/backlog-...`
   (mensagem `backlog: #id título`) quando não há código.
5. Entrega que o dono ainda não testou no aparelho fecha com `validacao=pendente`; quando ele
   testar, `validacao=ok` + nota.
