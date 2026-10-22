# App do ar — design

- **Data:** 2026-10-21
- **Backlog:** #1 (relacionados: #3, #5)
- **Decisões já registradas:** ADR 0001 (nuvem da Midea), ADR 0002 (Xcode + assinatura gratuita)
- **Status:** rascunho para aprovação do dono

Legenda: **[dono]** = decidido pelo dono · **[Claude]** = decisão minha, o dono pode trocar ·
**[builder]** = fica a critério de quem implementa.

---

## 1. Intenção

O dono quer chegar em casa com o quarto já fresco e não deixar o ar ligado à toa quando sai. Hoje ele
não usa nenhum app; o ar (Midea 42EFVCB12M5, Wi-Fi integrado) foi pareado pelo app oficial SmartHome
só para entrar no Wi-Fi. O app é pessoal: um usuário, um ar, iPhone e Mac.

Sucesso é: ao voltar do trabalho, o ar já está ligado quando ele entra em casa, sem ele ter feito
nada; ao passar do raio de saída, o ar se desliga sozinho; e, quando quiser, ele liga, desliga ou muda a
temperatura em segundos pelo iPhone ou pela barra de menus do Mac.

## 2. Objetivos

1. Ligar, desligar e mudar a temperatura do ar pelo iPhone e pelo Mac, de qualquer lugar. **[dono]**
2. No iPhone, ligar o ar automaticamente ao chegar perto de casa e desligar automaticamente ao
   passar do raio de saída. **[dono]**
3. Todos os valores da automação configuráveis no app, nada fixo no código. **[dono]**

## 3. Fora do escopo (agora)

- Trocar modo (refrigerar, aquecer, desumidificar) e ventilação pelo app; o app sempre usa refrigerar
  com ventilação automática. **[dono]**
- Temperatura que varia conforme o momento da ativação — backlog #5. **[dono]**
- Agendamento por horário, mais de um ar, mais de um usuário. **[Claude]**
- Controle pela rede local sem nuvem — backlog #4.
- Aviso de expiração da assinatura gratuita — backlog #3 (recomendado logo depois deste).
- Acabamento visual fino (ícones definitivos, animações, espaçamentos): refinado depois com o dono,
  dentro da identidade do §6.4. **[dono]**

## 4. Anti-objetivos (falha mesmo que "funcione")

- O ar liga ou desliga sem que o dono entenda por quê → todo disparo automático avisa e fica registrado.
- Falha silenciosa: um comando que não chegou e o app não disse nada.
- O ar desliga com o dono dentro de casa.
- Senha, token ou chave da conta Midea vazando (log, commit, arquivo, UserDefaults).
- Dado da rede de casa do dono (IP, MAC) em arquivo versionado — o repositório no GitHub é **público**.
- Teste automatizado ligando o ar de verdade ou disparando bloqueio da conta Midea.

## 5. Restrições

- **Sem ponte em casa:** a internet usa CGNAT e o dono não tem aparelho sempre ligado. Todo comando
  vai pela **nuvem da Midea**, com a conta do dono no SmartHome (ADR 0001).
- **Protocolo não oficial.** Constantes (URLs, chaves, assinatura, criptografia) só copiadas de uma
  implementação de referência com URL + commit citados no código: msmart-ng
  (github.com/mill1000/midea-msmart), midea_ac_lan (github.com/wuwentao/midea_ac_lan),
  midea-beautiful-air (github.com/nbogojevic/midea-beautiful-air).
- **Assinatura gratuita:** o app do iPhone expira 7 dias após instalar (ADR 0002). Nada que exija
  conta paga (push remoto, App Groups com iCloud etc.).
- **iOS em segundo plano:** o app só é acordado por eventos do sistema (entrada/saída de região) e
  ganha poucos segundos. Não existe timer confiável em segundo plano. Ver §7.4.
- Swift + SwiftUI, Xcode 27.1; código em inglês, textos em português; segredos no Keychain.

## 6. Plataformas e telas

### 6.1 iPhone — app com uma tela principal **[dono]**

- Nome do ar e estado atual: ligado/desligado, temperatura alvo e, se a nuvem informar, temperatura
  ambiente. **[Claude]**
- Botão grande de ligar/desligar.
- Temperatura com − e +, passo de 1 °C, dentro da faixa que o protocolo aceita **[builder: tirar da
  fonte]**. O comando só sai depois que o dono para de tocar (agrupar toques; intervalo **[builder]**,
  ~1 s). **[Claude]**
- Faixa mostrando se o automático está ligado e as regras atuais (ex.: "liga ao chegar a 2 km, fora há
  30 min ou mais · desliga ao passar de 2 km").
- Engrenagem → Ajustes (§8) e Histórico (§9).
- Toda ação mostra "enviando…" e depois o resultado; erro com mensagem clara (§10).

### 6.2 Mac — só ícone na barra de menus **[dono]**

- Sem janela principal e **sem ícone no Dock**.
- O ícone mostra o estado de relance: ligado com a temperatura alvo (ex.: "❄︎ 23°"), ou um ícone
  apagado quando desligado/desconhecido. **[Claude]**
- Um clique abre um painel pequeno: estado, ligar/desligar, temperatura − / +, item "Conta Midea…" e
  "Sair do app". **[Claude]**
- O Mac **não** tem automação por localização (o Mac fica em casa). **[dono]**
- Opção "abrir ao iniciar o Mac", ligada por padrão. **[Claude]**
- Estado atualizado ao abrir o painel e periodicamente enquanto o Mac está acordado (intervalo
  **[builder]**, sugestão 5 min). **[Claude]**

### 6.4 Identidade visual **[dono: referência enviada em 2026-10-21]**

Referência: captura de um app de finanças em tema escuro (guardada fora do repositório, em
`.superpowers/referencias/`, por ser trabalho de terceiros). Elementos extraídos:

- **Tema escuro monocromático.** Fundo quase preto; cartões um tom acima com **borda fina de 1 px**;
  texto branco-acinzentado; rótulos em cinza médio. Nada de gradiente nem sombra.
- **Cor só com significado:** verde dessaturado = ok/ativo/positivo; vermelho dessaturado = erro/negativo.
  Nenhuma cor decorativa.
- **Tipografia monoespaçada em tudo**, números grandes e finos (peso leve) para o dado principal,
  rótulos pequenos acima dos valores, títulos de cartão em seminegrito. No app: SF Mono via
  `fontDesign(.monospaced)` **[Claude]** (sem embutir fonte).
- **Ênfase por inversão:** o elemento mais importante vira bloco claro com texto escuro (na referência,
  as bolhas de chat) — aqui, o botão ligar/desligar. **[Claude]**
- **Componentes:** cartões com título à esquerda e "chip" com borda à direita (ex.: `1M`); grupos de
  rótulo + valor em colunas; botões quadrados com borda e cantos pouco arredondados (~8 px); ícones de
  contorno finos; linhas separadoras tracejadas; visualização de dados em **grade de pontos/quadrados**
  (heatmap) e barras hachuradas.
- **Densidade de informação:** a tela mostra dados (estado, distância, histórico), não só botões.

Paleta inicial (amostrada da imagem; afinar no refinamento visual):

| Token | Cor | Uso |
|---|---|---|
| fundo | `#121314` | fundo da tela |
| cartão | `#17181A` | superfície dos cartões |
| borda | `#2A2C2E` | borda de cartões, chips e botões |
| texto | `#E6EAEB` | texto e números principais |
| texto secundário | `#7C8486` | rótulos e legendas |
| claro | `#D8E0E2` | bloco invertido (ação principal) |
| superfície escura alternativa | `#282C2C` | estados pressionados, faixas |
| verde | `#6FA892` | ok, ativo |
| vermelho | `#C8645A` | erro (estimado; a referência quase não mostra) |

Elementos novos que a identidade sugere, aprovados pelo dono para o piloto: distância
até casa e tempo fora no cartão do automático; grade de uso das últimas semanas montada a partir do
histórico. O app segue escuro mesmo com o sistema em modo claro **[Claude]**.

### 6.5 Primeiro uso (nos dois aparelhos) **[Claude]**

1. Login com e-mail e senha da conta SmartHome → senha e token no Keychain do aparelho.
2. O app lista os aparelhos da conta; com um só ar, seleciona sozinho.
3. (Só iPhone) Definir a casa: botão "usar minha localização atual como casa" (o dono faz isso
   estando em casa) e pedir a permissão de localização **Sempre**, explicando por quê.

Cada aparelho faz seu próprio login; não há sincronização de credenciais entre iPhone e Mac. **[Claude]**

## 7. Automação (só iPhone)

### 7.1 Regiões **[dono]**

Dois círculos centrados na casa, **configurados separadamente**:
- **Raio de chegada** (padrão 2 km) — usado para ligar.
- **Raio de saída** (padrão 2 km) — usado para desligar.

### 7.2 Ligar ao chegar **[dono]**

Quando o iPhone **entra** no raio de chegada **e** o dono ficou fora dele por pelo menos o **tempo de
ausência para ligar** (padrão 30 min) **e** o automático está ligado:
- liga o ar direto, sem perguntar, em **refrigerar, temperatura automática configurada (padrão 23 °C),
  ventilação automática**; o comando leva o estado completo (repetir dá o mesmo resultado);
- antes, consulta o estado na nuvem: se o ar já está ligado (em qualquer modo/temperatura), não muda
  nada; se a consulta falhar, envia o "ligar" mesmo assim (é idempotente) **[Claude]**;
- notificação local "Liguei o ar (23 °C) — você está chegando" **[dono, aceito no resumo]**;
- registra no histórico.

O "ficou fora" é medido pela hora da última **saída** do raio de chegada, guardada no aparelho. Se não
há saída registrada (ex.: app recém-instalado fora de casa), **não** dispara. **[Claude]**

Os dois raios são independentes: cada um tem sua própria hora de saída e sua regra. Se o raio de saída
for **menor** que o de chegada, o dono pode sair, ter o ar desligado e voltar sem nunca deixar o raio de
chegada — nesse caso o ar não religa sozinho. Os Ajustes avisam disso quando o raio de saída ficar
menor que o de chegada. **[Claude]**

O estado da automação (horas de saída) fica nos dados do app, que sobrevivem a
reinstalar pelo Xcode por cima. Trocar o local de casa zera esse estado (volta a "sem saída
registrada"). **[Claude]**

### 7.3 Desligar ao sair **[dono]**

Quando o iPhone **sai** do raio de saída com o automático ligado, desliga o ar **na hora**, sem
perguntar e sem esperar tempo fora (decisão do dono em 2026-10-21, depois de saber que o iOS não
garante um timer de 30 min em segundo plano):
- se o ar já está desligado, não faz nada; se a consulta de estado falhar, envia o "desligar" mesmo
  assim (idempotente) **[Claude]**;
- notificação local "Desliguei o ar — você passou de 2 km" e registro no histórico.

Saída curta dentro do raio (ex.: academia perto de casa) não desliga; o dono desliga na mão. **[dono]**

### 7.4 Por que não há espera ao sair

Uma versão anterior previa desligar só após 30 min fora. Foi descartada: o iOS não roda timer em
segundo plano e o timer interno do ar pela nuvem não é garantido. Com o desligamento imediato, o
evento de saída de região basta. Para que uma volta rápida não desligue o ar, o dono ajusta o raio de saída.

### 7.5 Limitações aceitas

- O iOS pode atrasar alguns minutos para avisar entrada/saída de região; raio pequeno é menos
  confiável (mínimo permitido nos ajustes: 200 m **[Claude]**).
- Sem permissão "Sempre", a automação não funciona: o app mostra isso na tela principal em vez de
  fingir que está ativo.
- Quando a assinatura gratuita expira, a automação para (backlog #3).

## 8. Ajustes

| Ajuste | Onde | Padrão | Faixa **[Claude]** |
|---|---|---|---|
| Automático ligado | iPhone | ligado após configurar a casa | — |
| Local de casa | iPhone | — | "usar localização atual" |
| Raio de chegada | iPhone | 2 km | 200 m – 20 km |
| Raio de saída | iPhone | 2 km | 200 m – 20 km |
| Tempo fora para ligar ao chegar | iPhone | 30 min | 0 – 240 min |
| Temperatura ao ligar automático | iPhone | 23 °C | faixa do protocolo |
| Conta Midea (entrar/sair) | iPhone e Mac | — | — |
| Abrir ao iniciar o Mac | Mac | ligado | — |

## 9. Histórico **[dono, aceito no resumo]**

Lista local, mais recente primeiro, das últimas ~200 entradas **[Claude]**: data e hora, o que
aconteceu (entrou/saiu de raio, ligou, desligou, comando manual) e o
resultado (ok / erro com motivo). Serve para o dono entender por que algo disparou ou não. Só no
iPhone; o Mac não tem histórico. **[Claude]**

## 10. Erros

Toda falha vira mensagem legível na tela (e notificação, se veio de disparo automático):
- "A Midea recusou o login — confira a senha" (sem novas tentativas automáticas em loop)

Sessão e token **[Claude]**: quando o token vence, o app refaz o login sozinho com a senha do Keychain,
**uma** vez por ação (inclusive em disparo automático). Se esse login falhar, para, avisa e só tenta de
novo na próxima ação do dono ou no próximo disparo.

Confirmação de comando **[Claude]**: "enviado" = a nuvem aceitou; em seguida o app lê o estado e mostra
o que o ar informa. No iPhone o estado é lido ao abrir/voltar à tela e após cada comando, sem consulta
contínua.
- "O ar está offline" · "Sem internet" · "A Midea mudou algo e o app precisa de atualização" (resposta
  inesperada da nuvem)

## 11. Verificação

- Testes automatizados (Swift Testing), **sem nuvem real**: montagem e leitura das mensagens do
  protocolo contra exemplos tirados das implementações de referência; regras de §7.2 e §7.3 como lógica
  pura com relógio e localização injetados (chegar após 29 vs 31 min, sair do raio de saída, sem saída
  registrada, automático desligado, ar já ligado/desligado).
- Teste manual de localização no Xcode com rotas simuladas (GPX).
- Teste do dono no aparelho real, registrado no backlog (`validacao`): ligar, desligar e mudar
  temperatura pelo iPhone e pelo Mac; voltar do trabalho com o automático ligado; sair e ver o desligamento.

## 12. Ordem de construção **[Claude]**

0. **Spike (descartável):** login na nuvem, achar o ar, ligar/desligar de verdade a partir de um teste
   manual; verificar se o login no
   Mac derruba a sessão do iPhone (mesma conta nos dois); verificar se o app do Mac assinado com a conta
   gratuita expira (se sim, assinar o Mac para execução local, que não expira). Resultado → ADR.
1. Controle manual no iPhone e no Mac (§6), primeiro uso e erros.
2. Automação no iPhone (§7, §8, §9).
3. Refinamento visual com o dono, dentro da identidade do §6.4.

Cada fase fecha com teste do dono no aparelho antes da próxima.

## 13. Fica com quem implementa **[builder]**

Estrutura do projeto Xcode e dos módulos; API do CoreLocation a usar; detalhes do protocolo Midea
(seguindo as fontes citadas); intervalos de agrupamento de toques e de atualização no Mac; textos
exatos das telas e notificações (em português, curtos).
