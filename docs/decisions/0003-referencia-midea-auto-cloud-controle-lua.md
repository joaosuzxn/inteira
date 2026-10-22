# 0003 — Referência do protocolo: midea_auto_cloud, controle por JSON na nuvem

- **Status:** Accepted
- **Data:** 2026-10-21
- **Módulo(s):** nuvem
- **Decisor:** Claude, no planejamento do backlog #1 (a ser conferido pelo dono no plano)

## Contexto

O ADR 0001 escolheu controlar o ar pela nuvem da Midea e citou msmart-ng, midea_ac_lan e
midea-beautiful-air como referências. A pesquisa de 2026-10-21 (código lido nos commits abaixo)
mostrou que:
- msmart-ng (`56bc30a`) e midea_ac_lan / midea-lan **não** controlam pela nuvem: usam a nuvem só para
  obter token/chave e controlam pela rede local.
- midea-beautiful-air (`ac7911e`) tem envio pela nuvem (`transparent/send`), mas há relatos de 2024–2025
  de erro 1000 com contas MSmartHome, sem correção.
- **sususweet/midea_auto_cloud** (`ce0c4b88224def0f6b53714312c19f71aa9c2a50`, Apache-2.0, ativo em
  out/2026) controla contas MSmartHome pela nuvem, enviando **JSON** (`/v1/device/lua/control`) e lendo
  estado (`/v1/device/status/lua/get`); a nuvem traduz para o protocolo do ar.

## Decisão

Portar para Swift o cliente MSmartHome da midea_auto_cloud, no commit acima:
`custom_components/midea_auto_cloud/core/cloud.py` (classes `MideaCloud` e `MSmartHomeCloud`) e
`core/security.py` (`CloudSecurity`, `MSmartCloudSecurity`). Controle e leitura por JSON
(`power`, `mode`, `temperature`, `small_temperature`, `wind_speed`, `indoor_temperature`), sem montar
frame binário no app. Atribuição Apache-2.0 no cabeçalho dos arquivos portados e em `NOTICE`.

## Alternativas rejeitadas

| Alternativa | Prós | Contras | Por que não |
|---|---|---|---|
| `transparent/send` com frame binário (midea-beautiful-air / msmart-ng) | Não depende do Lua da nuvem | Relatos de erro 1000 com MSmartHome; montar frame, CRC e checksum no app | Mais código e caminho com falhas relatadas |
| Token da nuvem + controle LAN (msmart-ng) | Mais rápido em casa | Exige ponte em casa (CGNAT); endpoint de token da SmartHome relatado quebrado | Não atende o controle remoto (ADR 0001) |

## Consequências

- Positivas: menos código (sem frame/CRC); referência mantida e ativa.
- Negativas / riscos (verificados no spike, tarefa 4 do plano):
  - nenhum relato de conta brasileira nem do modelo 42EFVCB12M5; há relatos de limitação regional da nuvem;
  - a Midea fala numa "API v2" que pode substituir esta;
  - mesma conta em vários clientes gera logins conflitantes (issue #219 da midea_auto_cloud) — iPhone,
    Mac e app oficial podem derrubar a sessão um do outro;
  - limite de requisições: relogin com espera mínima de 60 s, nunca em laço.
- Se o spike falhar, o plano para e o caminho é rediscutido com o dono (ADR 0001 pode ser superado).

## Referências

- https://github.com/sususweet/midea_auto_cloud/blob/ce0c4b88224def0f6b53714312c19f71aa9c2a50/custom_components/midea_auto_cloud/core/cloud.py
- https://github.com/sususweet/midea_auto_cloud/blob/ce0c4b88224def0f6b53714312c19f71aa9c2a50/custom_components/midea_auto_cloud/core/security.py
- https://github.com/sususweet/midea_auto_cloud/blob/ce0c4b88224def0f6b53714312c19f71aa9c2a50/custom_components/midea_auto_cloud/device_mapping/T0xAC.py
- Issues: midea-beautiful-air #37 e #42; midea-msmart #201; midea_auto_cloud #204 e #219
- Plano: docs/plans/2026-10-21-app-ar.md
