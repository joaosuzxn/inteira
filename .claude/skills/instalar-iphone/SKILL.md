---
name: instalar-iphone
description: "Use para instalar ou reinstalar o app do ar no iPhone do dono pelo Xcode ('/instalar-iphone', 'instala no celular', 'o app parou de abrir', 'expirou') — a assinatura gratuita expira 7 dias depois da instalação. Confere branch e testes, faz o build assinado, instala pelo cabo ou pela rede, confere que abre e registra a data de expiração."
---

# /instalar-iphone

Sem App Store: o app vai do Xcode direto para o iPhone com a assinatura gratuita (ADR 0002). O perfil
expira **7 dias depois da instalação**; depois disso o app não abre e a automação para sem aviso.

## Antes

1. `git branch --show-current` e `git status --porcelain` — diga ao dono de qual branch sai o build
   e se há alteração não commitada indo junto.
2. Rodar os testes (comando na seção Comandos do `CLAUDE.md`). Teste falhando: parar e avisar.
3. iPhone conectado por cabo (ou pareado pela rede), desbloqueado, com Modo Desenvolvedor ligado.
   `xcrun devicectl list devices` mostra o aparelho.

## Instalar

O esquema, o caminho do `.app` e o id do aparelho ficam na seção Comandos do `CLAUDE.md`, preenchida
quando o projeto Xcode for criado. A sequência é:

1. Build assinado para iOS: `xcodebuild` com o esquema do app, `-destination` do iPhone,
   `-allowProvisioningUpdates` (o Xcode renova o perfil gratuito com a conta Apple configurada nele).
2. Instalar: `xcrun devicectl device install app --device` com o id do aparelho e o `.app` gerado.
3. Abrir: `xcrun devicectl device process launch --device` com o id e o bundle id.

Se o Xcode reclamar de conta ou de perfil, pedir ao dono para abrir o Xcode → Settings → Accounts e
conferir a conta Apple; não tentar contornar a assinatura.

## Depois

- Pedir ao dono para confirmar que o app abriu e que o botão de ligar responde.
- Registrar na memória ("Próxima sessão começa AQUI"): data da instalação e **data de expiração (+7 dias)**.
- Itens do backlog entregues nesta instalação e ainda não testados: `validacao=pendente` até o dono testar.
