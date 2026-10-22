# 0001 — Controle remoto do ar pela nuvem da Midea

- **Status:** Accepted
- **Data:** 2026-10-21
- **Módulo(s):** nuvem, automacao
- **Decisor:** dono — sessão Claude de 2026-10-21

## Contexto

O dono quer ligar o ar (Midea 42EFVCB12M5, Wi-Fi integrado) de fora de casa, manualmente ou ao
chegar perto de casa, pelo iPhone e pelo Mac. Para um comando sair da rua e chegar ao ar, alguma
coisa precisa fazer a ponte. Fatos medidos em 2026-10-21:

- A internet de casa usa **CGNAT**: o IP que o modem recebe da operadora está na faixa 100.64.0.0/10 e é
  diferente do IP público visto de fora; a rota até a internet também passa por essa faixa.
  Conexão de fora para dentro em IPv4 não chega ao roteador.
- Há IPv6 público, mas módulos Wi-Fi da Midea costumam ser só IPv4.
- O dono não tem nenhum aparelho sempre ligado em casa (Mac dorme, sem Raspberry Pi, Apple TV ou HomePod).
- O ar está na rede local (porta 6444 aberta) e mantém conexão de saída com a
  nuvem da Midea depois de pareado pelo app SmartHome.

## Decisão

O app (iPhone e Mac) fala com a **nuvem da Midea** usando a conta do dono no SmartHome, seguindo o
protocolo não oficial decifrado pela comunidade: iPhone/Mac → nuvem da Midea → ar. Sem servidor
próprio no meio.

## Alternativas rejeitadas

| Alternativa | Prós | Contras | Por que não |
|---|---|---|---|
| Abrir porta no roteador direto para o ar | Sem nuvem; controle local | Expõe o módulo Wi-Fi (sem atualização) na internet; IP dinâmico exige DDNS | **Inviável**: CGNAT impede conexão de entrada. Preferida pelo dono antes da verificação |
| Pedir IP público à operadora + porta aberta | Volta a permitir a opção acima | Custo possível; mesmos riscos de segurança | Dono preferiu a nuvem |
| Aparelho sempre ligado em casa (Raspberry Pi, Mac sem dormir, Home Assistant) | Controle local, sem depender da Midea | Hardware ou Mac ligado o tempo todo | Dono não tem e não quis |
| Trocar o módulo Wi-Fi por ESP32 (ESPHome) | 100% local, maduro | Hardware; modelo tem Wi-Fi integrado (dongle removível não confirmado); ainda precisa de ponte por causa do CGNAT | Não resolve o acesso remoto sozinho |
| Infravermelho | Funciona em qualquer ar | Precisa de aparelho em casa; não lê o estado | Mesma razão |

## Consequências

- Positivas: nada para manter ligado em casa; funciona com CGNAT; mesmo caminho no iPhone e no Mac.
- Negativas / dívidas: protocolo **não oficial** — a Midea pode mudar e quebrar o app; credenciais da
  conta precisam ficar no Keychain; constantes do protocolo precisam de fonte rastreável (URL + commit);
  erro da nuvem tem de aparecer claramente ao dono.
- Impacto: módulo `nuvem` é o ponto mais frágil; testes nunca chamam a nuvem real.

## Referências

- Implementações de referência: msmart-ng (github.com/mill1000/midea-msmart), midea_ac_lan
  (github.com/wuwentao/midea_ac_lan), midea-beautiful-air (github.com/nbogojevic/midea-beautiful-air)
- Backlog #1
