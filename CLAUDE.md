# CLAUDE.md — ar

App pessoal para controlar o ar-condicionado Midea de casa pelo iPhone e pelo Mac, ligando-o
automaticamente quando o dono está chegando em casa. Repositório único, uma sessão Claude por vez.

---

## Protocolo do Dev — nada é feito sem passar por ele

Todo pedido segue PENSAR → PRIORIZAR → FAZER → CATALOGAR, sem pular etapa:
1. **Pensar**: feature → `brainstorming` (spec em docs/specs, plano em docs/plans); bug → `systematic-debugging`;
   decisão com alternativas → ADR em docs/decisions (skill `adr-decisoes`). Não editar código sem saber dizer em uma frase o quê e por quê.
2. **Priorizar**: todo pedido, ideia ou bug vira item em docs/backlog/itens (tipo, P0–P3, módulos) antes de
   entrar em execução. A sessão começa por `node tools/backlog/backlog.mjs next`. Bug achado no caminho vira item na hora, sem desviar.
3. **Fazer**: feature branch, TDD, revisão por task e do branch inteiro (agentes sp-* e ar-* deste projeto).
4. **Catalogar**: item fechado com commits e texto `resumo` (+ `validacao=pendente` se o dono ainda não testou no aparelho),
   memória (Why/How to apply + "Próxima sessão começa AQUI"), ADR se houve decisão, linha em "Decisões Recentes".
   Só então "concluído".
"Faz rápido" = protocolo em escala menor, nunca protocolo dispensado.

---

## Fluxo de desenvolvimento — UMA SESSÃO

O Claude commita; o dono integra. Fluxo para qualquer mudança:

    # 1. Partir da main
    git checkout main
    git checkout -b feat/<slug>       # ou fix/ | refactor/ | chore/

    # 2. Implementar, testar, commitar na branch (arquivo por arquivo, nunca `git add -A` / `git add .`)

    # 3. Ao finalizar: avisar o dono e pedir autorização para integrar
    git checkout main && git merge feat/<slug> --no-edit && git branch -d feat/<slug>

Regras:
- SEMPRE feature branch. Commit na `main` é bloqueado pelo hook `.claude/hooks/branch-guard.py`.
- **Merge na `main` e push só com autorização explícita do dono.** Não há remoto configurado.
- `git branch --show-current` antes de cada commit.
- Mensagem de commit em português, terminando com a linha `Co-Authored-By` do Claude.

## Documentos gerados pelo Claude

Nunca na raiz:
- `docs/specs/`, `docs/plans/` — specs e planos do Superpowers (este projeto usa estas pastas, não `docs/superpowers/`)
- `docs/decisions/` — ADRs
- `docs/analises/` — análises e pesquisas · `docs/referencias/` — material de referência (inclui o guia SuperBrain original)
- `docs/relatorios/` — relatórios gerados (inclui `backlog/`)

Não há manual do operador: o único usuário é o dono. O texto `resumo` dos itens do backlog faz esse papel.

---

## Estrutura do repositório

    ar/
    ├── .claude/            # agentes, skills e hook deste projeto
    ├── docs/               # specs, planos, ADRs, backlog, análises
    └── tools/backlog/      # CLI do backlog

O projeto Xcode ainda não existe; a estrutura do código sai do plano (backlog #1). Ao criá-lo,
atualizar esta seção, a seção Comandos e os "Arquivos Críticos" dos agentes `ar-*`.

## Stack

| Camada | Tecnologia |
|---|---|
| App | Swift + SwiftUI, um app multiplataforma (iOS e macOS), Xcode 27.1 |
| Testes | Swift Testing (preferido) ou XCTest |
| Controle do ar | nuvem da Midea (conta do app SmartHome/MSmartHome), protocolo não oficial — ADR 0001 |
| Localização | CoreLocation, monitoramento de região no iPhone |
| Segredos | Keychain. Nunca em código, UserDefaults, log, teste ou commit |
| Distribuição | Xcode direto para o iPhone, assinatura gratuita (expira em 7 dias) — ADR 0002 |

## Comandos

A preencher quando o projeto Xcode existir (esquema, destino de teste do macOS, instalação no iPhone).
Instalação no iPhone: skill `/instalar-iphone`.

## Convenções

- Código e identificadores em inglês; comentários e textos de tela em português.
- Lógica que importa (montar comando Midea, criptografia, regra de disparo por localização) fica
  fora da UI e testável sem rede: rede, relógio e localização entram por protocolo injetável.
- Teste automatizado **nunca** chama a nuvem real da Midea (o ar liga de verdade e a conta pode ser bloqueada).
- Constantes do protocolo Midea (URLs, chaves, assinatura) só copiadas de fonte citada (URL + commit), nunca de memória.

## Equipamento e rede (fatos levantados em 2026-10-21)

- Ar: Midea **42EFVCB12M5 / 38TAVCB12M5** (Springer Carrier), 12 mil BTU, 220 V, R-32, Wi-Fi integrado.
  Na rede local responde na porta 6444. Pareado pelo app SmartHome. Endereços da rede de casa ficam só na
  memória local do Claude — **nunca** colocar IP, MAC ou dado da rede do dono em arquivo versionado (o repositório é público).
- Internet com **CGNAT**: conexão de fora para dentro de casa é impossível
  em IPv4. Por isso o controle remoto é pela nuvem da Midea.

## Subagentes deste projeto

`.claude/agents/` deste repositório substitui os `sp-*` globais (que são do Órbita):
- `ar-nuvem` — nuvem da Midea, login, comandos, estado do ar
- `ar-automacao` — localização, raio de casa, regra de disparo
- `ar-app` — telas SwiftUI no iPhone e no Mac, configurações
- `sp-implementer`, `sp-spec-reviewer`, `sp-code-reviewer`, `sp-researcher`, `web-research` — versões para Swift

Validar depois de editar: `node ~/.claude/validar-agentes.mjs .claude/agents`.

## Backlog de desenvolvimento

Ideias, bugs, melhorias, features e tarefas ficam em `docs/backlog/itens/` (um `.md` por item,
tipo × urgência P0–P3 × módulo). Quadro gerado em `docs/backlog/BACKLOG.md`. Operar pela skill `/backlog`
ou por `node tools/backlog/backlog.mjs <cmd>`.
Regras de sessão: (1) entrega que resolve item fecha o item com commits e texto `resumo`; (2) bug ou ideia
achada no caminho vira item na hora; (3) a memória aponta ids do backlog em vez de repetir o texto.

## graphify

Ainda não há grafo (não há código). Quando o projeto Xcode existir, o item de backlog correspondente
instala o grafo e o resumo `.scripts/graph-summary.mjs` e acrescenta aqui as regras de leitura.

## Decisões Recentes

- 2026-10-21 — Controle remoto pela nuvem da Midea; porta no roteador inviável por CGNAT (ver docs/decisions/0001)
- 2026-10-21 — Instalação pelo Xcode com assinatura gratuita, sem loja (ver docs/decisions/0002)
- 2026-10-21 — Ao entrar no raio de casa o ar liga direto, sem pedir confirmação (decisão do dono; vai para a spec)
