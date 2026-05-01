# DESIGN - Vibe Studying

Doc status: guia de produto e linguagem visual alinhado ao frontend React e ao app Flutter atuais.

## Objetivo

Definir a experiencia desejada do Vibe Studying de forma coerente com o produto real:

- web como camada de aquisicao e autenticacao
- mobile como camada principal de estudo
- identidade visual cyberpunk/HUD a servico da clareza, nao so do estilo

## Design Thesis

O Vibe Studying deve parecer energia, ritmo e foco. A referencia nao e um dashboard corporativo nem uma sala de aula tradicional. A referencia e uma interface de jogo/console que transforma pratica curta em algo desejavel e memoravel.

Ao mesmo tempo, o produto precisa passar credibilidade educacional. O visual pode ser ousado, mas a estrutura deve ser clara, navegavel e sem ruido desnecessario.

## Papel De Cada Superficie

### Web

Objetivo:

- atrair
- converter
- autenticar
- distribuir links do app

Tom de experiencia:

- manifesto de marca
- alto impacto visual
- narrativa curta
- CTA evidente

O que nao deve parecer:

- um LMS tradicional
- um painel cheio de widgets vazios
- uma promessa de produto maior do que o que existe

### Mobile

Objetivo:

- ativar o aluno
- capturar preferencias
- entregar feed relevante
- conduzir a pratica
- sobreviver a interrupcoes

Tom de experiencia:

- rapido
- tactil
- concentrado
- orientado a sessao

## Principios De UX

- Friccao minima para comecar: usuario deve chegar ao feed e a pratica com poucos passos.
- Relevancia antes de profundidade: primeiro mostrar algo com match emocional, depois expandir o produto.
- Uma tela, uma intencao: cada superficie deve ter um objetivo claro.
- Feedback sem humilhacao: erros de fala devem orientar, nao punir.
- Visual forte, hierarquia simples: glow, gradiente e motion nunca devem competir com a tarefa principal.
- Offline e parte da experiencia: estados de fila e sincronizacao devem parecer normais, nao falhas estranhas.

## Personalidade Da Marca

Caracteristicas centrais:

- eletrica
- urbana
- nerd/pop
- confiante
- ritmica
- acolhedora sem ser infantil

O produto fala como um console vivo, mas nao como meme incessante.

## Sistema Visual

### Fonte De Verdade Atual

- Web: `frontend/src/index.css`
- Mobile: `mobile/lib/app/theme.dart`

### Paleta

| Token | Web | Mobile equivalente | Papel |
| --- | --- | --- | --- |
| Background | `hsl(270 40% 4%)` | `#0C0615` | fundo principal |
| Panel/Card | `hsl(270 35% 7%)` | `#1A1026` com alpha | paineis e cards |
| Foreground | `hsl(180 100% 92%)` | `#E9F9FF` | texto principal |
| Primary | `hsl(322 100% 58%)` | `#FF2EA6` | CTA, acento principal, glow |
| Secondary | `hsl(180 100% 50%)` | `#2CF6FF` | informacao secundaria, destaque frio |
| Accent | `hsl(56 100% 55%)` | `#FFD84D` | score, match, alertas leves |
| Purple | `hsl(280 100% 65%)` | `#AA63FF` | apoio de gradiente |
| Muted | `hsl(270 15% 65%)` | `#9A8AB1` | texto secundario |
| Border | `hsl(322 80% 25%)` | `#66FF2EA6` | borda fina com brilho |

### Gradientes

Gradiente principal de marca:

- magenta -> purple -> cyan

Uso correto:

- headlines selecionadas
- detalhes de hero
- pequenos acentos de foco

Uso incorreto:

- blocos grandes de texto
- fundos inteiros de leitura
- excesso de elementos concorrendo pelo mesmo brilho

### Tipografia

#### Display

- Web: `Bungee`
- Mobile: `Bungee`

Uso:

- hero headlines
- labels de sistema
- nomes de seccao

#### Base

- Web: `Space Grotesk`
- Mobile: `Space Grotesk`

Uso:

- corpo de texto
- descricoes
- explicacoes e empty states

#### Mono

- Web: `JetBrains Mono`
- Mobile: `JetBrains Mono`

Uso:

- labels HUD
- tags tecnicas
- microcopy de estado
- metadados

### Forma

- radius baixo a medio
- borda fina e luminosa
- paineis escuros com transparencia controlada
- glow localizado, nunca em todos os componentes ao mesmo tempo

### Motion

Linguagem atual:

- fade/slide suave no web com Framer Motion
- pulse neon, float e glitch controlados
- progressao de lane na pratica mobile

Diretriz:

- motion deve reforcar foco, estado e energia
- efeitos permanentes so em poucos pontos heroicos
- evitar animacao continua em elementos de leitura prolongada

## Componentes Base

### HudPanel

Uso:

- container principal de conteudo funcional

Caracteristicas:

- fundo escuro transluscido
- borda fina
- espacamento generoso
- destaque por glow leve, nao por sombra pesada

### NeonButton

Uso:

- CTA principal
- acao de pratica
- envio de onboarding

Regras:

- magenta para CTA principal
- texto em caixa alta quando o contexto for mais "console"
- evitar mais de um CTA primario por bloco

### HudTag / Chips

Uso:

- dificuldade
- tipo de conteudo
- match reason
- tags de gosto

Regras:

- magenta para categoria principal
- cyan para status ou metadado
- amarelo para match/score/alerta leve

### Practice Lane

Uso:

- coracao da experiencia mobile

Elementos obrigatorios:

- linha atual em destaque
- progresso visual da leitura
- microfone/listening state
- feedback imediato
- saida clara para retry ou continuar

## Arquitetura De Informacao

### Web

Fluxo atual ideal:

1. Hero
2. proposta de valor
3. explicacao do feed/pratica
4. manifesto de marca
5. FAQ curta
6. CTA de waitlist
7. auth
8. portal de downloads

### Mobile

Fluxo atual ideal:

1. Splash
2. Login/Register
3. Onboarding
4. Feed
5. Practice

Nao adicionar profundidade desnecessaria antes de fortalecer esse loop.

## Diretrizes Por Tela

### Landing

Objetivo:

- vender a tese do produto em segundos

Deve comunicar:

- estudo de ingles
- cultura pop
- mobile-first
- lessons curtas

Deve evitar:

- claims de IA forte que o produto nao sustenta
- promessa multi-idioma ampla
- excesso de features sem prova no fluxo

### Auth Web

Objetivo:

- autenticar rapido

Diretrizes:

- manter card central unico
- inputs simples
- ruido visual menor que na landing
- estados de erro claros

### Portal Web

Objetivo:

- servir como command center minimo

Diretrizes:

- tratar como hub utilitario
- manter linguagem cyberpunk, mas mais calma que a landing
- nao fingir analytics ou operacao que nao existem

### Onboarding Mobile

Objetivo:

- capturar sinais suficientes para personalizar o feed

Diretrizes:

- formularios em blocos curtos
- chips para preferencias
- reforco de beneficio imediato
- CTA unico e forte no final

### Feed Mobile

Objetivo:

- iniciar sessoes de pratica com baixa carga cognitiva

Diretrizes:

- cards compactos e legiveis
- match reason deve ser visivel quando existir
- CTA de pratica sempre acima da dobra do card
- evitar excesso de texto descritivo

### Practice Mobile

Objetivo:

- transformar leitura e repeticao em loop energico

Diretrizes:

- foco total na linha atual
- traducao e dica fonetica aparecem como suporte, nao como protagonista
- feedback deve soar como coaching, nao como reprovacao
- estados offline e envio concluido devem ser tranquilizadores

## Copywriting

### Voz

- curta
- segura
- energica
- com vocabulario de sistema/HUD em pontos estrategicos

### Regras

- headlines podem ser ousadas
- descricoes devem ser claras e concretas
- microcopy de erro deve ser humana e objetiva
- nao usar hype vazio quando falar de aprendizagem

### Exemplos De Tom Correto

- `ENTRAR_NA_VIBE`
- `ATIVAR_FEED_PERSONALIZADO`
- `Sessao enviada ao backend com sucesso.`
- `Sem conexao: tentativa salva offline e marcada para sincronizacao.`

### Exemplos De Tom A Evitar

- promessas de IA ilimitada
- claims de nota/rating inventado
- copy generica de startup sem ligacao com estudo

## Acessibilidade

Minimos obrigatorios:

- contraste alto sempre preservado
- corpo de texto sem depender de gradiente
- estados de foco visiveis em web e mobile
- icones nunca sozinhos sem contexto em fluxos criticos
- feedback de erro/sucesso sempre com texto, nao so cor

Cuidados extras:

- o estilo neon pode cansar; por isso o fundo precisa permanecer escuro e a area de leitura precisa ser limpa
- glitch, pulse e scanlines devem ser reduzidos em areas de formulario e pratica longa

## Responsividade

### Web

- mobile e desktop devem preservar a hierarquia da landing
- navegacao pode colapsar em largura menor, mas CTA principal deve permanecer visivel
- cards e seccoes devem evitar overflow horizontal

### Mobile

- layouts devem suportar teclado aberto sem esconder CTA critico
- pratica deve funcionar com pouco espaco vertical
- alvos de toque devem continuar confortaveis mesmo em HUD compacto

## Do And Dont

### Do

- usar contraste e brilho para orientar o olho
- manter uma unica acao primaria por bloco
- usar tags curtas e significativas
- transformar estados tecnicos em UX clara
- preservar consistencia entre web e mobile

### Dont

- criar dashboards fake
- exagerar no glow em todos os elementos
- esconder informacao importante atras de estilo
- vender features ainda inexistentes
- usar texto longo demais em cards de feed

## Melhorias De Design Recomendadas

### Curto Prazo

- alinhar copy publica ao escopo real do produto
- revisar metadata/SEO para evitar claims nao comprovados
- tornar o portal web mais honesto como hub de download
- explicitar melhor estados offline no mobile

### Medio Prazo

- criar teacher portal web coerente com a linguagem atual
- adicionar progresso do aluno sem poluir o feed
- criar estados de processamento de submission apos scoring real

### Longo Prazo

- sistema de mastery/review com visual proprio
- biblioteca de componentes compartilhando tokens entre web e Flutter
- motion adaptativo por contexto e preferencia do usuario

## Regra Final

Se houver duvida entre "mais estilo" e "mais clareza", escolher clareza. O diferencial do Vibe Studying nao e apenas parecer futurista; e fazer o aluno querer voltar a praticar.
