---
name: ar-nuvem
description: "Use para tudo que fala com a nuvem da Midea no projeto ar: login com a conta do app SmartHome (MSmartHome), token, lista de aparelhos da conta, montar e criptografar o comando (ligar, desligar, temperatura, modo, ventilação), ler o estado do ar e tratar erro da nuvem. Ative quando o usuário mencionar: nuvem, Midea, SmartHome, conta, login, token, comando, ligar ou desligar o ar, temperatura, modo, protocolo. Para as telas use ar-app; para o gatilho de localização use ar-automacao."
---

## Identidade do Domínio

O caminho iPhone/Mac → nuvem da Midea → ar-condicionado. Autentica com a conta do dono no
SmartHome, acha o ar na conta e envia comandos e leituras de estado. É um protocolo **não oficial**,
decifrado pela comunidade (ADR 0001): pode mudar sem aviso.

## Arquivos Críticos

Ainda não há código. A estrutura sai do plano do backlog #1; ao criá-la, listar aqui os arquivos de
cliente da nuvem, montagem de comando, criptografia e os testes com fixtures.

## Conceitos Principais

**Conta SmartHome** → e-mail e senha do dono no app oficial; guardados só no Keychain
**Aparelho** → o ar 42EFVCB12M5 pareado na conta; identificado pelo id que a nuvem devolve
**Comando** → mensagem binária do protocolo do ar (a mesma que iria pela rede local), criptografada e
enviada pela nuvem
**Estado** → leitura de ligado/desligado, modo, temperatura alvo e ambiente

## Regras que não podem ser quebradas

- Constantes (URLs, chaves do app, algoritmo de assinatura, chaves de criptografia) só copiadas de uma
  implementação de referência com **URL + commit** citados no código. Referência oficial do projeto
  (ADR 0003): `sususweet/midea_auto_cloud@ce0c4b88224def0f6b53714312c19f71aa9c2a50`, `core/cloud.py` e
  `core/security.py`; controle e estado por JSON (`/v1/device/lua/control`, `/v1/device/status/lua/get`).
  msmart-ng e midea_ac_lan **não** controlam pela nuvem. Nunca de memória — um byte errado
  vira erro opaco da nuvem
- Credencial e token só no Keychain. Nunca em log, `print`, UserDefaults, fixture ou commit
- Nenhum teste automatizado chama a nuvem real: o ar liga de verdade e a conta pode ser bloqueada.
  Testes usam respostas gravadas e sintéticas
- Nada de login repetido em loop: falhou, para e avisa (bloqueio de conta)
- "Ligar" envia o estado completo desejado (ligado + modo + temperatura + ventilação), para que repetir
  o comando dê o mesmo resultado
- Erro da nuvem chega ao dono como mensagem clara ("a Midea recusou o login", "o ar está offline"),
  nunca como falha silenciosa

## Gotchas conhecidos

- 🚨 Internet de casa com CGNAT: nada de fora alcança a rede local; o controle remoto depende da nuvem
- O ar responde na rede local (endereço na memória local do Claude, não no repositório), porta 6444 aberta. A descoberta UDP (portas 6445/20086) não respondeu
  em 2026-10-21 — pode ter sido pacote errado; irrelevante para o caminho pela nuvem
- Versão do protocolo local (V2/V3) desconhecida

## Comandos Úteis

A definir com o projeto Xcode (testes do módulo da nuvem).
