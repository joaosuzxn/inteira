---
name: ar-app
description: "Use para as telas e a estrutura do app no projeto ar: SwiftUI no iPhone e no Mac, botão de ligar e desligar, temperatura e modo na tela, configurações (conta Midea, local de casa, raio, automático ligado ou não), avisos ao dono (erro, expiração da assinatura), projeto Xcode, targets e assinatura. Ative quando o usuário mencionar: tela, botão, app, iPhone, Mac, layout, configurações, Xcode, instalar. Para regras da nuvem use ar-nuvem; para a regra de disparo por localização use ar-automacao."
---

## Identidade do Domínio

A parte que o dono vê e toca, no iPhone e no Mac, com o mesmo código SwiftUI. Também cuida do
projeto Xcode (targets, permissões no Info.plist, capacidades) e da instalação no iPhone.

## Arquivos Críticos

- `project.yml` — fonte do projeto Xcode (XcodeGen); `Ar.xcodeproj` é gerado e ignorado pelo git
- `Config/Base.xcconfig`, `Config/Local.xcconfig.example` — `Local.xcconfig` (ignorado) só traz o `DEVELOPMENT_TEAM`
- `App/Shared/Theme.swift` — cores e fonte monoespaçada (spec §6.4)
- `App/iOS/ArApp.swift` e `App/iOS/Info.plist` — ponto de entrada do iPhone e textos de permissão de localização
- `App/macOS/ArMenuBarApp.swift` e `App/macOS/Info.plist` — app de barra de menus (`LSUIElement`)

## Conceitos Principais

**Controle rápido** → ligar, desligar e ver o estado do ar
**Configurações** → conta SmartHome (vai para o Keychain), local de casa, raio, automático ligado ou não
**Avisos** → erro da nuvem, permissão de localização faltando, assinatura perto de expirar

## Regras que não podem ser quebradas

- A tela não contém lógica de protocolo nem de disparo: chama os módulos de `ar-nuvem` e `ar-automacao`
- Senha digitada vai direto para o Keychain; nunca fica em `@AppStorage`/UserDefaults
- Diferenças iOS × macOS com `#if os(iOS)` / `#if os(macOS)` só na UI
- Textos de tela e de permissão em português
- Toda ação que fala com a nuvem mostra que está em andamento e o resultado (sucesso ou erro legível)

## Gotchas conhecidos

- 🚨 Assinatura gratuita: o app no iPhone expira 7 dias depois da instalação (ADR 0002); reinstalar com `/instalar-iphone`
- O iPhone precisa estar com o Modo Desenvolvedor ligado e confiar no Mac para instalar pelo Xcode

## Comandos Úteis

    xcodegen generate
    xcodebuild -project Ar.xcodeproj -scheme Ar-iOS -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
    xcodebuild -project Ar.xcodeproj -scheme Ar-macOS -destination 'platform=macOS' build

Instalação no iPhone: skill `/instalar-iphone`.
