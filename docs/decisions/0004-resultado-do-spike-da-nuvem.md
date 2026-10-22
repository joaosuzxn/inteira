# 0004 — Resultado do spike contra a nuvem real da Midea

- **Status:** Accepted
- **Data:** 2026-10-21
- **Módulo(s):** nuvem
- **Decisor:** dono — teste executado por ele no Terminal (`ar-spike`, Task 4 do plano)

## Contexto

O ADR 0003 escolheu portar o cliente MSmartHome da midea_auto_cloud e controlar o ar por comandos JSON
na nuvem, com riscos em aberto: nenhum relato com conta brasileira nem com o modelo 42EFVCB12M5,
possível limitação regional, e logins da mesma conta em vários clientes se derrubando.

A conta original do dono foi criada com "Entrar com a Apple", que nenhuma implementação de referência
suporta (só e-mail + senha). O teste foi feito com login por e-mail e senha.

## Decisão

Seguir com a nuvem MSmartHome pelo caminho JSON (`/v1/device/lua/control`, `/v1/device/status/lua/get`).
O portão da Task 4 está aprovado.

Resultado do `ar-spike` (2026-10-21, conta do dono, Brasil):

| Passo | Resultado |
|---|---|
| 1. Login (e-mail + senha) | ok |
| 2. Listar aparelhos | 1 aparelho, tipo 0xAC, online |
| 3. Ler estado | ok — atributos `power`, `mode`, `temperature`(+`small_temperature`), `indoor_temperature` lidos corretamente (estava ligado, modo auto, alvo 17 °C, ambiente 23,1 °C) |
| 4. `turnOn(23)` | ar ligou; estado após 10 s: ligado, modo cool, alvo 23 °C |
| 5. `turnOff` | ar desligou; estado após 10 s: desligado |
| 6. Segunda sessão com a mesma conta | **a primeira sessão continuou válida** |

`applianceCode` enviado como número (como a referência) funcionou.

## Alternativas rejeitadas

| Alternativa | Por que não |
|---|---|
| Implementar o login "Entrar com a Apple" da Midea | Nenhuma fonte para portar; fluxo frágil. O dono usa login por e-mail e senha |
| Voltar ao `transparent/send` binário | Desnecessário: o caminho JSON funcionou de ponta a ponta |

## Consequências

- iPhone e Mac podem usar a mesma conta sem derrubar a sessão um do outro (ao menos dois logins
  seguidos); o relogin limitado do cliente continua como proteção.
- O parse de `ACStatus` não precisa de ajuste.
- O app deve deixar claro, na tela de entrada, que a conta precisa de e-mail e senha (conta criada com
  "Entrar com a Apple" sem senha não funciona) — vai para a Task 9.
- O e-mail da conta do dono **não** é registrado no repositório (público).

## Referências

- ADR 0001, ADR 0003; plano `docs/plans/2026-10-21-app-ar.md` (Task 4); `Packages/ArCore/Sources/ar-spike/main.swift`
