---
name: ar-automacao
description: "Use para o disparo automático no projeto ar: localização de casa, raio em volta de casa, detectar que o dono está chegando, regra de só disparar depois de ficar fora um tempo, permissão de localização Sempre, o que roda em segundo plano no iPhone e o registro do que disparou. Ative quando o usuário mencionar: localização, chegar em casa, raio, geofence, automático, sair do trabalho, segundo plano, disparou ou não disparou. Para o envio do comando à Midea use ar-nuvem; para as telas use ar-app."
---

## Identidade do Domínio

Faz o iPhone perceber que o dono está chegando em casa e mandar ligar o ar sem perguntar
(decisão do dono, 2026-10-21). Roda só no iPhone; o Mac fica em casa e não participa do gatilho.

## Arquivos Críticos

Em `Packages/ArCore/Sources/ArCore/Automation/`:
- `AutomationEngine.swift` — regra de disparo (lógica pura, relógio injetável)
- `AutomationCoordinator.swift` e `AutomationSettings.swift`
- `Storage/HistoryStore.swift` — registro dos disparos
- Testes em `Packages/ArCore/Tests/ArCoreTests`

## Conceitos Principais

**Casa** → coordenada escolhida pelo dono no app
**Raio** → círculo em volta de casa; entrar nele é "estou chegando" (palpite inicial: 2 km, a confirmar na spec)
**Regra de ausência** → só dispara se o dono ficou fora do raio por um tempo mínimo (palpite: 30 min,
a confirmar na spec), para não ligar o ar depois de ir à padaria
**Registro de disparo** → histórico local do que disparou, quando e com que resultado, para depurar

## Regras que não podem ser quebradas

- A regra de disparo é lógica pura com relógio injetável, testada sem CoreLocation
- O monitoramento de região pede a permissão "Sempre"; sem ela, o app avisa o dono em vez de fingir que funciona
- Ao receber o evento em segundo plano, mandar o comando **imediatamente**: o iOS dá poucos segundos de
  execução. Nada de trabalho pesado antes do envio
- Um evento de entrada gera no máximo um comando (sem disparo duplicado)
- Todo disparo e toda falha ficam no registro

## Gotchas conhecidos

- 🚨 Com a assinatura gratuita (ADR 0002), o app para de abrir 7 dias depois de instalado e a automação
  morre **sem aviso**. O app deve mostrar quando expira
- O evento de entrada na região pode atrasar alguns minutos e depende de Wi-Fi e rede celular; raio
  muito pequeno falha
- Há limite de regiões monitoradas por app (20) — aqui só usamos uma
- Testar sem sair de casa: localização simulada no Xcode (arquivo GPX ou Debug → Simulate Location)

## Comandos Úteis

    swift test --package-path Packages/ArCore
