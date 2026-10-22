# 0002 — Instalação pelo Xcode com assinatura gratuita, sem App Store

- **Status:** Accepted
- **Data:** 2026-10-21
- **Módulo(s):** app, automacao
- **Decisor:** dono — sessão Claude de 2026-10-21

## Contexto

O app é de uso pessoal. Para rodar num iPhone, o iOS exige app assinado. O Xcode 27.1 já está
instalado no Mac do dono.

## Decisão

Instalar direto do Xcode no iPhone do dono, sem publicar na loja e sem conta de desenvolvedor paga.
A instalação é um procedimento repetível (skill `/instalar-iphone`).

## Alternativas rejeitadas

| Alternativa | Prós | Contras | Por que não |
|---|---|---|---|
| Conta Apple Developer paga (US$ 99/ano) | Perfil dura 1 ano; TestFlight | Custo anual | Dono escolheu instalar direto, sem loja |
| Publicar na App Store | Instalação normal | Revisão da Apple; protocolo não oficial da Midea dificulta aprovação | Fora do objetivo |

## Consequências

- Positivas: custo zero; ciclo rápido de mudança e teste.
- Negativas / dívidas: o perfil gratuito **expira 7 dias depois da instalação**. Depois disso o app não
  abre e a automação por localização para **sem aviso**. Mitigação: o app mostra quando expira
  (backlog #3) e a memória registra a data a cada instalação. No Mac a limitação não pesa.
- Impacto: recursos que exigem conta paga ficam fora (ex.: notificações push remotas); monitoramento de
  região do CoreLocation continua disponível.

## Referências

- Skill `.claude/skills/instalar-iphone/SKILL.md`
- Backlog #1, #3
