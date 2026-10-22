---
name: adr-decisoes
description: "Use ao tomar ou registrar uma decisão no projeto ar (app do ar-condicionado): como falar com o ar (nuvem, rede local, outro caminho), estrutura do app e do projeto Xcode, regra de disparo por localização, onde guardar credenciais, distribuição e assinatura, escolha 'A vs B' entre abordagens, abandono de um caminho — cria ou atualiza ADR em docs/decisions/ com contexto, decisão, alternativas rejeitadas e consequências, e sincroniza 'Decisões Recentes' do CLAUDE.md e a memória."
---

# ADRs — Architecture Decision Records — ar

Adaptado de `addyosmani/agent-skills` (skill `documentation-and-adrs`, MIT). Código mostra
**o quê**; o ADR guarda **o porquê** e **o que foi rejeitado**. Quem mais lê são os agentes e o
"eu futuro" do dono — num projeto pessoal retomado de tempos em tempos, isso evita refazer a mesma
investigação (ex.: "por que não abrimos porta no roteador?").

## Quando usar

- Escolha entre abordagens com impacto além de um arquivo: caminho de controle do ar, segurança das
  credenciais, estrutura do app, regra de disparo, distribuição.
- Abandono de um caminho já usado (ex.: a nuvem da Midea mudou e foi trocada).
- Toda vez que o brainstorming fechar um desenho com "decisão do dono".
- **Não** para: fix pontual, refactor local, escolha óbvia sem alternativa real.

## Onde e como

- Diretório: `docs/decisions/`. Nome: `NNNN-slug-curto.md`, numeração sequencial, nunca reiniciar.
  Data no corpo, não no nome.
- Um ADR por decisão. **Nunca apagar nem reescrever** um ADR aceito: superseder com outro
  (`Status: Superseded by 0007`).
- "Decisões Recentes" no `CLAUDE.md` recebe **uma linha** apontando para o ADR (`ver docs/decisions/0003`);
  no máximo ~6 linhas, as antigas saem (o ADR continua). A memória do projeto recebe o link também.

## Template

    # NNNN — Título curto da decisão

    - **Status:** Proposed | Accepted | Superseded by NNNN | Deprecated
    - **Data:** AAAA-MM-DD
    - **Módulo(s):** nuvem | automacao | app | projeto
    - **Decisor:** dono — sessão Claude de AAAA-MM-DD

    ## Contexto
    Requisitos, restrições, o problema real (com números e fatos medidos quando houver).

    ## Decisão
    O que foi escolhido, em uma frase. Depois o desenho essencial.

    ## Alternativas rejeitadas
    | Alternativa | Prós | Contras | Por que não |
    |---|---|---|---|

    ## Consequências
    - Positivas
    - Negativas / dívidas assumidas (com follow-ups e o id do backlog onde estão)
    - Impacto em: app iPhone, app Mac, automação, segurança

    ## Referências
    Spec/plano, itens do backlog, commits, fontes externas.

## Processo

1. Verificar se já existe ADR sobre o tema (`docs/decisions/`, Grep). Se existir, superseder.
2. Escrever **antes** de implementar quando a decisão vem do brainstorming; ou logo após, quando
   nasce durante a implementação.
3. Listar alternativas de verdade consideradas (mínimo 1), com o motivo da rejeição.
4. Registrar consequências e dívidas — o que fica pendente vira item no backlog.
5. Atualizar "Decisões Recentes" do `CLAUDE.md` (1 linha) + memória.

## Anti-racionalização

| Desculpa | Realidade |
|---|---|
| "O código é autodocumentado" | O código mostra o quê; o ADR explica o porquê e o que foi descartado. |
| "Documento quando estabilizar" | Decisão sem registro é re-decidida na próxima sessão. |
| "É projeto pessoal, não precisa" | É justamente o projeto que você retoma depois de meses sem lembrar de nada. |
| "Já está no CLAUDE.md" | A linha é resumo; sem alternativas rejeitadas, a mesma discussão volta. |

## Red flags

- Decisão relevante só no chat ou na memória do Claude.
- Alternativa rejeitada sem motivo escrito.
- ADR editado retroativamente em vez de superseder.

## Verificação

- [ ] ADR criado/superseded em `docs/decisions/` com numeração sequencial.
- [ ] Alternativas rejeitadas listadas com motivo.
- [ ] Consequências e dívidas registradas; follow-ups viraram item no backlog.
- [ ] Linha em "Decisões Recentes" do `CLAUDE.md` + memória atualizada.
