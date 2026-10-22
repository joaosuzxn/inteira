---
id: 1
titulo: "App para ligar o ar pelo iPhone e pelo Mac, com acionamento ao chegar em casa"
tipo: feature
urgencia: P1
status: em-andamento
modulos: [app, nuvem, automacao]
criado: 2026-10-21
iniciado: 2026-10-21
concluido: null
commits: []
relacionados: [3, 5]
resumo: null
validacao: null
---
## Contexto
Ligar o ar de casa sem estar em casa, principalmente para que ele já esteja ligado quando o dono
voltar do trabalho. App próprio no iPhone e no Mac; hoje o dono não usa nenhum app (o SmartHome foi
instalado só para parear o ar ao Wi-Fi em 2026-10-21).

Já decidido: controle pela nuvem da Midea (ADR 0001); instalação pelo Xcode com assinatura gratuita
(ADR 0002); ao entrar no raio de casa o ar liga direto, sem perguntar.

## Como reproduzir

## Proposta
Em brainstorming (2026-10-21). Desenho inicial, ainda a confirmar com o dono:
- um app SwiftUI multiplataforma (iPhone e Mac) com botão de ligar/desligar e estado do ar;
- no iPhone, monitoramento de região em volta de casa (palpite: raio de 2 km) que liga o ar ao entrar,
  só se o dono ficou fora por um tempo mínimo (palpite: 30 min);
- modo e temperatura ao ligar automaticamente: pergunta em aberto (palpite: refrigerar a 23 °C).
Sai spec em docs/specs e plano em docs/plans antes de qualquer código.

## Notas de execução
2026-10-21: Brainstorming iniciado; ADRs 0001 e 0002 registram as decisões já tomadas.
2026-10-21: Dono decidiu: ao ligar automaticamente, refrigerar a 23 °C com ventilação automática; temperatura variável fica no #5.
2026-10-21: Dono confirmou o gatilho: raio de 2 km em volta de casa; só dispara se ficou fora do raio por pelo menos 30 min.
2026-10-21: Controle manual: ligar, desligar e mudar a temperatura. No Mac, só ícone na barra de menus (sem janela nem ícone no Dock). Visual das telas ainda será refinado.
2026-10-21: Dono decidiu: ao sair do raio e ficar 30 min fora, o app desliga o ar. Raio, tempo fora e temperatura são configuráveis no app, não fixos no código.
