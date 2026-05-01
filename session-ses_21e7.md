# APRESENTACAO

**Session ID:** ses_21e762320ffe67P7xWFAYsruuf
**Created:** 5/1/2026, 12:16:41 AM
**Updated:** 5/1/2026, 2:48:19 PM

---

## User

# 🧪 Desafio Técnico — Software Engineer Web

## 📌 Contexto

O objetivo deste desafio é avaliar sua capacidade de:

- Estruturar um projeto end-to-end
- Utilizar LLMs (ex: Claude, GPT, etc.) como copiloto de desenvolvimento
- Tomar decisões de produto e engenharia
- Entregar algo funcional, bem apresentado e coerente

---

## 🎯 Proposta

Você deverá desenvolver **um mini ecossistema educacional**, contendo:

### 1) 🌐 Landing Page

- Página pública apresentando o produto
- Deve ter:
  - Proposta de valor clara
  - Call-to-action (CTA)
  - Estrutura básica de SEO

---

### 2) 🧩 Plataforma SaaS

- Sistema web completo com:
  - 🔐 Autenticação (login/cadastro)
  - 🖥️ Frontend em React com Next.js
  - ⚙️ Backend em Django + Django Ninja
  - 🗄️ Banco de dados PostgreSQL
- Deve conter pelo menos **uma funcionalidade principal relevante**

---

### 3) 📱 App Mobile (Flutter)

- Aplicativo com:
  - Funcionalidade offline-first
  - Sincronização com backend
- Pode ser uma versão simplificada do SaaS

---

## 🧠 Tema do Projeto

Você é livre para escolher o tema, **desde que esteja relacionado à educação**.

### 💡 Sugestões de temas (opcional)

- Plataforma de resolução de exercícios com correção automática  
- App de flashcards com repetição espaçada  
- Sistema de acompanhamento de estudos  
- Plataforma de simulados  
- App de leitura com anotações e resumos  
- Sistema para professores gerenciarem turmas  
- Plataforma de microlearning  
- App de ensino de programação  
- Sistema de organização de estudos com IA  

---

## 🪜 Etapas do Desafio

### 0) ⏱️ Planejamento inicial

- 1 hora para leitura e definição de prazo

### 1) ❓ Levantamento de dúvidas

- Enviar perguntas antes de iniciar

### 2) 🎨 Prototipação

- Wireframes e protótipos visuais

### 3) ⚙️ Setup inicial

- Inicialização do projeto e ferramentas

### 4) 📝 PRD

- Criar PRD.md com apoio de LLMs

### 5) 🏗️ Tech Specs

- Criar TechSpecs.md com decisões técnicas

### 6) 🚀 Implementação

- Desenvolvimento completo

### 7) 🎤 Apresentação

- Demonstração e explicação

---

## ⭐ Bônus (Avançado)

> Bônus não são obrigatórios, mas serão considerados como diferencial forte — especialmente quando bem justificados.

### 🧵 Uso de Temporal (filas e workflows)

- Implementar ao menos um fluxo assíncrono relevante

Sugestões:

- Envio de e-mails assíncronos  
- Processamento de exercícios em background  
- Sincronização offline → online  
- Geração de conteúdo com IA  
- Agendamentos (lembretes, drip content)  

---

### ☁️ Deploy & Infra

- Deploy completo
- Docker / CI-CD

---

### 📊 Observabilidade

- Logs e monitoramento

---

### 🔐 Segurança

- Autenticação e boas práticas

---

### ⚡ Performance

- Cache e otimizações

---

### 🧪 Testes

- Testes básicos

---

### 🧱 Arquitetura

- Código modular e bem estruturado

---

## 📊 Critérios de Avaliação

### 🧠 Uso de LLMs

- Clareza e eficiência

### 🏗️ Estrutura

- Organização e arquitetura

### 🎨 Produto

- UX/UI e detalhes

### ⚙️ Técnica

- Código e funcionamento

### 🗣️ Comunicação

- Clareza e alinhamento

### 🎤 Apresentação

- Demonstração e explicação

### ⏱️ Prazo

- Cumprimento do prazo oque falta para cumprir todos os requisitos desse teste, e pense em como vamos implementar porque es pra eu entregaar amanha

---

## Assistant (Plan · GPT-5.4 Pro · 86.1s)

Vou inspecionar a estrutura atual do repositório para mapear o que já existe e o que falta para fechar os requisitos até amanhã.

**Tool: glob**

**Tool: glob**

**Tool: glob**

**Tool: glob**

**Tool: glob**

**Tool: glob**

---

## Assistant (Plan · GPT-5.4 Pro · 1764.1s)

Achei os três blocos do desafio já iniciados (`frontend`, `backend`, `mobile`) e também `PRD.md` e `TechSpecs.md`. Agora vou ler os documentos principais e os arquivos de setup para medir o nível de conclusão real.

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: task**

---

## User

minha internet caiu, contunue de onde parou

---

## Assistant (Plan · GPT-5.4 Pro · 129.7s)

Vou validar o que os READMEs e configs internos prometem, para separar o que está realmente coberto do que ainda parece gap de entrega.

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: glob**

**Tool: read**

**Tool: read**

---

## Assistant (Plan · GPT-5.4 Pro · 134.5s)

Os documentos mostram um produto mais forte no mobile do que no web, e já aparece um desvio importante do enunciado: o frontend atual é `React + Vite`, não `Next.js`. Vou confirmar isso no código-fonte principal e medir os gaps mais críticos por superfície.

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: grep**

**Tool: grep**

---

## Assistant (Plan · GPT-5.4 Pro · 151.8s)

Já dá para afirmar que `PRD`, `TechSpecs`, Docker, CI e o núcleo backend/mobile existem. O principal risco para o teste não é "falta de código", e sim alinhamento com o enunciado: web não é Next.js e a plataforma SaaS web ainda está incompleta. Vou checar a landing, o portal web e a cobertura de testes/backend para fechar um diagnóstico objetivo.

**Tool: read**

**Tool: glob**

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: glob**

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: read**

---

## Assistant (Plan · GPT-5.4 Pro · 138.3s)

Vou abrir só os trechos de API que definem o menor caminho para fechar o SaaS web amanhã: feed do aluno e CRUD do professor já parecem existir no backend, então isso provavelmente vira a funcionalidade principal do web.

**Tool: grep**

**Tool: read**

**Tool: read**

---

## Assistant (Plan · GPT-5.4 Pro · 566.1s)

Vou usar um agente rápido só para estimar o menor caminho de migração do frontend atual para Next.js sem mexer no backend, porque esse é o maior desvio em relação ao enunciado.

**Tool: task**

---

## Assistant (Plan · GPT-5.4 Pro · 134.3s)

Vou checar só o empacotamento atual do frontend para incluir no plano a parte de Docker/CI, porque isso também vai precisar acompanhar a eventual migração para Next.js.

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: grep**

---

## Assistant (Plan · GPT-5.4 Pro · 148.2s)

**Diagnóstico**

Se o avaliador ler o enunciado ao pé da letra, hoje os blockers principais são 2:

1. O frontend web não está em `Next.js`; está em `React + Vite`.
   Arquivos que comprovam: `frontend/package.json`, `frontend/vite.config.ts`, `frontend/src/App.tsx`, `frontend/src/main.tsx`.

2. A plataforma SaaS web ainda não está “completa” como produto.
   Hoje a web entrega landing + auth + portal de download, mas não entrega a funcionalidade educacional principal no navegador.
   Arquivos que mostram isso: `frontend/README.md`, `frontend/src/pages/Portal.tsx`, `TechSpecs.md`.

**O que já está atendido**

- Tema educacional bem definido: microlearning de ingles com cultura pop.
- Landing page com proposta, CTA e SEO basico.
  Referencias: `frontend/src/pages/Index.tsx`, `frontend/index.html`, `backend/accounts/api.py` (`POST /api/waitlist`).
- Backend em `Django + Django Ninja`.
  Referencias: `backend/config/api.py`, `backend/accounts/api.py`, `backend/learning/api.py`.
- PostgreSQL no projeto e no `docker-compose.yml`.
- Autenticacao pronta no backend, com aluno e professor.
- Pelo menos uma funcionalidade principal relevante existe no ecossistema: lessons, feed, submissions e onboarding.
- Mobile com offline-first real:
  cache local + fila offline + sync posterior.
  Referencias: `mobile/lib/core/repositories.dart`, `mobile/lib/core/state.dart`.
- PRD e tech specs existem.
  Referencias: `PRD.md`, `TechSpecs.md`.
- Bonus parcialmente cobertos:
  Docker, CI, health check, filas/e-mails, observabilidade basica.

**O que falta para cumprir “todos os requisitos” com mais seguranca**

- Migrar a web para `Next.js`.
- Transformar a web em SaaS de verdade com 1 fluxo principal educacional.
- Adicionar pelo menos testes minimos no frontend.
  Hoje ha so placeholder em `frontend/src/test/example.test.ts`.
- Adicionar pelo menos testes minimos no mobile.
  Hoje nao encontrei testes em `mobile/test`.
- Fechar o artefato de prototipacao de forma mais explicita.
  `DESIGN.md` ajuda, mas eu ainda faria 3 a 5 telas/wireframes ou screenshots finais.
- Preparar a demo mobile em Android/iPhone.
  No Linux o `speech_to_text` esta limitado segundo `mobile/README.md`.

**Melhor estrategia para entregar amanha**

Eu nao reescreveria backend nem mobile. O caminho mais seguro e:

1. Migrar `frontend/` de Vite para `Next.js` reaproveitando a UI atual.
2. Implementar na web um dashboard de professor.
3. Usar os endpoints que ja existem:
   `GET/POST/PUT /api/teacher/lessons`.
4. Manter a landing atual, auth atual e portal atual.
5. Fazer login por role:
   professor entra no dashboard;
   aluno continua vendo portal/feed simples.
6. Adicionar 2 ou 3 testes web focados em auth e lesson CRUD.
7. Fechar a apresentacao com screenshots, arquitetura e roteiro de demo.

**Por que teacher dashboard é a melhor funcionalidade web**

- Ja existe backend pronto e testado para isso.
- E muito mais rapido do que construir pratica completa no navegador.
- Faz sentido como “SaaS web”:
  professor cria, edita e publica lessons;
  aluno consome no mobile.
- Valoriza o ecossistema:
  web = gestao/captacao, mobile = estudo/offline.

**Plano de implementacao**

1. `Next.js`
- Criar `app/layout.tsx`, `app/page.tsx`, `app/auth/page.tsx`, `app/app/page.tsx`.
- Portar componentes da landing.
- Trocar `react-router-dom` por navegação do Next.
- Trocar `import.meta.env.VITE_*` por `process.env.NEXT_PUBLIC_*`.
- Migrar SEO do `frontend/index.html` para metadata do Next.
- Ajustar `Dockerfile`, CI e compose para build Next.

2. SaaS web
- Dashboard do professor com:
  login/cadastro,
  listagem de lessons,
  criar lesson,
  editar lesson,
  publicar draft.
- Opcional rapido:
  preview do feed publico ou detalhe da lesson.

3. Testes
- Frontend:
  login happy path,
  criar lesson,
  editar/publish lesson.
- Mobile:
  pelo menos 1 teste do offline queue/sync, se der tempo.

4. Entrega
- Atualizar `README.md` com arquitetura final e como rodar.
- Incluir screenshots da landing, dashboard web e mobile.
- Preparar roteiro de demo de 5 minutos.

**Ordem de prioridade para amanha**

1. Migracao para Next.js.
2. Dashboard web do professor.
3. Ajustes de Docker/CI.
4. Testes frontend.
5. Screenshots e apresentacao.
6. Teste mobile extra, se sobrar tempo.

**O que eu cortaria sem culpa se o tempo apertar**

- Scoring server-side de submissions.
- Feed completo no web para aluno.
- Hardening avancado de seguranca.
- Observabilidade extra.
- Deploy completo, se nao ja estiver pronto.

**Resumo curto**

Se entregar agora, o projeto esta forte em backend e mobile, mas ainda falha no requisito literal de `Next.js` e no “SaaS web completo”.  
Para fechar isso ate amanha, eu faria `Next.js + dashboard de professor` reaproveitando o backend atual.

Se quiser, no proximo passo eu posso te devolver um plano de execução por horas para hoje/amanha cedo.

---

## User

eu gostei do plano, mas vamos mudar um dashboard do professor para o perfil do aluno, com estatisticas, quantas horas usou o app flutter foto de perfil, bio e etc. o professor vai ser a IA nao precisa de dashboard para professor e vamos criar uma nova branch que vai se chamar "previa" vamos jogar todas essas novas funcionalidades nessa branch. uma funcionalidade legal para cumprir o requesito do desafio seria o aluno poder ver os perfis de outros alunos na web. depois dele fazer o login ele deve cair em uma tela que seria o perfil dele tipo uma rede social, so que com suas conquistas, foto, posts e etc

---

## Assistant (Plan · GPT-5.4 Pro · 159.6s)

Vou mapear o modelo atual para transformar a entrega em “perfil social do aluno” sem inventar backend desnecessário, e já separar o que dá para derivar dos dados existentes do que exige novas tabelas/campos.

**Tool: read**

**Tool: read**

**Tool: grep**

**Tool: grep**

**Tool: grep**

**Tool: bash**

---

## Assistant (Plan · GPT-5.4 Pro · 364.3s)

Há um ponto de escopo que muda muito o tempo: `foto` e `posts`. Para amanhã, a diferença entre “campo simples/atividade derivada” e “upload/rede social real” é grande.

**Tool: question**

---

## Assistant (Plan · GPT-5.4 Pro · 282.4s)

**Direção Nova**

Essa mudança faz sentido e fica mais forte para o desafio:

- `web` vira o SaaS principal do aluno
- `mobile` continua como superfície de estudo offline-first
- `backend` segue como source of truth
- `professor` não precisa de dashboard; no domínio, ele vira um usuário interno tipo `AI Curator`

**Ponto técnico importante**

- Hoje o frontend ainda é `Vite`, não `Next.js`
- Hoje `StudentProfile` só guarda onboarding e gostos; não tem `bio`, `foto`, `handle` nem perfil público
- Hoje o mobile não registra horas de uso
- Hoje `Lesson.teacher` é obrigatório em `backend/learning/models.py`, então a forma mais rápida é manter um usuário interno de IA em vez de remover esse conceito

**Produto que eu implementaria**

Após login, o aluno cai em `/app` e vê:

- foto de perfil
- nome + `@handle`
- bio
- stats: horas no app, submissions, lessons praticadas, streak, posts
- conquistas
- composer de post de texto
- feed dos próprios posts
- lista de outros alunos públicos
- navegação para perfil público de outro aluno

Perfis públicos em `/students/[handle]` com:

- avatar
- bio
- stats públicas
- conquistas
- posts públicos

**Escopo técnico mínimo para entregar amanhã**

**1. Branch**
- Primeiro passo fora do modo de planejamento: criar `previa` a partir da branch atual `demo`
- Há um arquivo solto `backend/.env.swp` no worktree; não deve entrar em commit

**2. Backend**
Em `accounts`:

- expandir `StudentProfile` com:
  - `handle` único
  - `display_name`
  - `bio`
  - `avatar_url`
  - `is_public`
- criar `StudentPost`
  - `author`
  - `body`
  - `visibility` público/privado
  - timestamps
- criar `AppUsageSession`
  - `student`
  - `client_session_id`
  - `platform`
  - `started_at`
  - `ended_at`
  - `duration_seconds`
  - idempotência por `student + client_session_id`

**3. APIs**
Manter tudo no `accounts/api.py` para ser mais rápido:

- `GET /api/profile/me`
  Retorna perfil expandido + stats + conquistas + posts recentes
- `PUT /api/profile/me`
  Atualiza bio, avatar URL, display name, visibilidade
- `POST /api/profile/posts`
  Cria post de texto
- `GET /api/profile/posts/me`
  Lista posts do aluno autenticado
- `POST /api/profile/usage-sessions`
  Sincroniza sessão de uso vinda do Flutter
- `GET /api/students`
  Lista alunos públicos
- `GET /api/students/{handle}`
  Perfil público completo
- `GET /api/students/{handle}/posts`
  Posts públicos desse aluno

**4. Stats e conquistas**
Para amanhã, tudo derivado sem pipeline pesada:

Stats:
- `study_hours`: soma de `duration_seconds` das `AppUsageSession`
- `submission_count`: total de `Submission`
- `lessons_practiced`: distinct de `exercise__lesson`
- `current_streak_days`: dias consecutivos com submission
- `post_count`

Conquistas derivadas:
- primeiro onboarding completo
- primeira submission
- 5 submissions
- 10 submissions
- primeira hora estudada
- primeiro post
- 3 dias de streak

**5. Web em Next.js**
Continua obrigatório para o teste.

Plano mínimo:
- migrar `frontend/` para `Next.js`
- reaproveitar a landing atual
- reaproveitar auth UI atual
- trocar `react-router-dom` por App Router
- trocar `VITE_*` por `NEXT_PUBLIC_*`

Páginas:
- `/` landing
- `/auth` login/cadastro
- `/app` perfil social do aluno
- `/students` diretório
- `/students/[handle]` perfil público

**6. Mobile**
Adicionar telemetria simples de uso, nova a partir de agora:

- registrar abertura/fechamento de sessão
- gerar `client_session_id`
- calcular `duration_seconds`
- enviar ao backend
- se offline, enfileirar localmente e sincronizar depois

Isso fecha bem o requisito de “horas usou o app Flutter”.

**7. Decisão de produto para ganhar tempo**
Eu **não** faria agora:

- likes
- comentários
- seguidores
- upload real de imagem
- edição/deleção de posts
- feed algorítmico entre alunos

Faria só:
- perfil público
- posts de texto
- diretório de alunos
- stats
- conquistas

Isso já parece rede social educacional e cabe no prazo.

**Sequência de implementação**

1. criar branch `previa`
2. migrar frontend para `Next.js`
3. expandir modelos e migrations do backend
4. criar APIs de perfil social, posts e diretório
5. instrumentar o Flutter para `usage sessions`
6. montar `/app`, `/students` e `/students/[handle]`
7. adicionar testes mínimos
8. atualizar README, PRD e TechSpecs para o novo recorte
9. preparar demo

**Risco principal**
O único risco grande continua sendo a migração para `Next.js`.  
Por isso eu faria a parte web toda client-side dentro do Next, sem SSR sofisticado e sem refatorar auth para cookies.

**Minha recomendação final**
Essa versão entrega melhor o enunciado do que o dashboard do professor:

- landing pública
- SaaS web do aluno em `Next.js`
- backend Django/Ninja/Postgres
- mobile Flutter offline-first
- funcionalidade principal clara: perfil social educacional com stats e perfis públicos

Se quiser, no próximo passo eu transformo isso em um cronograma de execução por blocos de 1h para hoje e amanhã cedo.

---

## User

# 🧪 Desafio Técnico — Software Engineer Web

## 📌 Contexto

O objetivo deste desafio é avaliar sua capacidade de:

- Estruturar um projeto end-to-end
- Utilizar LLMs (ex: Claude, GPT, etc.) como copiloto de desenvolvimento
- Tomar decisões de produto e engenharia
- Entregar algo funcional, bem apresentado e coerente

---

## 🎯 Proposta

Você deverá desenvolver **um mini ecossistema educacional**, contendo:

### 1) 🌐 Landing Page

- Página pública apresentando o produto
- Deve ter:
  - Proposta de valor clara
  - Call-to-action (CTA)
  - Estrutura básica de SEO

---

### 2) 🧩 Plataforma SaaS

- Sistema web completo com:
  - 🔐 Autenticação (login/cadastro)
  - 🖥️ Frontend em React com Next.js
  - ⚙️ Backend em Django + Django Ninja
  - 🗄️ Banco de dados PostgreSQL
- Deve conter pelo menos **uma funcionalidade principal relevante**

---

### 3) 📱 App Mobile (Flutter)

- Aplicativo com:
  - Funcionalidade offline-first
  - Sincronização com backend
- Pode ser uma versão simplificada do SaaS

---

## 🧠 Tema do Projeto

Você é livre para escolher o tema, **desde que esteja relacionado à educação**.

### 💡 Sugestões de temas (opcional)

- Plataforma de resolução de exercícios com correção automática  
- App de flashcards com repetição espaçada  
- Sistema de acompanhamento de estudos  
- Plataforma de simulados  
- App de leitura com anotações e resumos  
- Sistema para professores gerenciarem turmas  
- Plataforma de microlearning  
- App de ensino de programação  
- Sistema de organização de estudos com IA  

---

## 🪜 Etapas do Desafio

### 0) ⏱️ Planejamento inicial

- 1 hora para leitura e definição de prazo

### 1) ❓ Levantamento de dúvidas

- Enviar perguntas antes de iniciar

### 2) 🎨 Prototipação

- Wireframes e protótipos visuais

### 3) ⚙️ Setup inicial

- Inicialização do projeto e ferramentas

### 4) 📝 PRD

- Criar PRD.md com apoio de LLMs

### 5) 🏗️ Tech Specs

- Criar TechSpecs.md com decisões técnicas

### 6) 🚀 Implementação

- Desenvolvimento completo

### 7) 🎤 Apresentação

- Demonstração e explicação

---

## ⭐ Bônus (Avançado)

> Bônus não são obrigatórios, mas serão considerados como diferencial forte — especialmente quando bem justificados.

### 🧵 Uso de Temporal (filas e workflows)

- Implementar ao menos um fluxo assíncrono relevante

Sugestões:

- Envio de e-mails assíncronos  
- Processamento de exercícios em background  
- Sincronização offline → online  
- Geração de conteúdo com IA  
- Agendamentos (lembretes, drip content)  

---

### ☁️ Deploy & Infra

- Deploy completo
- Docker / CI-CD

---

### 📊 Observabilidade

- Logs e monitoramento

---

### 🔐 Segurança

- Autenticação e boas práticas

---

### ⚡ Performance

- Cache e otimizações

---

### 🧪 Testes

- Testes básicos

---

### 🧱 Arquitetura

- Código modular e bem estruturado

---

## 📊 Critérios de Avaliação

### 🧠 Uso de LLMs

- Clareza e eficiência

### 🏗️ Estrutura

- Organização e arquitetura

### 🎨 Produto

- UX/UI e detalhes

### ⚙️ Técnica

- Código e funcionamento

### 🗣️ Comunicação

- Clareza e alinhamento

### 🎤 Apresentação

- Demonstração e explicação

### ⏱️ Prazo

- Cumprimento do prazo preciso que voce prepare uma apresentacao do projeto, apontando pra qual arquivo o requisito do projeto pediu, e deixando comentario de porque usei essa solucao e qual es o arquivo, qual linha etc. uma apresentacao bem preparada para eu fazer para o diretor da empresa que tambem es CTO  e programador

---

## Assistant (Plan · GPT-5.4 Pro · 1987.4s)

Vou levantar as referências exatas por requisito para montar uma apresentação executiva, mas tecnicamente rigorosa, com arquivo e linha.

**Tool: task**

**Tool: read**

**Tool: read**

**Tool: read**

---

## Assistant (Plan · GPT-5.4 Pro · 94.0s)

Vou completar as referências de arquitetura, testes e observabilidade para a apresentação ficar defensável diante de um CTO.

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: glob**

**Tool: read**

**Tool: read**

---

## Assistant (Plan · GPT-5.4 Pro · 105.3s)

Vou confirmar os trechos de design/escopo para incluir uma parte de "decisões e limites conscientes", que costuma pesar bem em avaliação técnica.

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: read**

**Tool: read**

---

## Assistant (Plan · GPT-5.4 Pro · 201.3s)

**Estrutura Recomendada**

Use esta narrativa: apresentar o que já está sólido, mostrar evidência em código, explicar tradeoffs conscientemente e fechar com gaps honestos.

Frase de abertura:
"Eu construí um ecossistema educacional mobile-first em que o backend centraliza o domínio, a web resolve aquisição e identidade, e o Flutter entrega o loop principal de estudo com resiliência offline."

Base para essa frase:
- `README.md:7-9`
- `PRD.md:7-10`
- `TechSpecs.md:15-21`

**Matriz De Requisitos**

| Requisito do desafio | Status atual | Evidência principal |
| --- | --- | --- |
| Landing page pública | Atendido | `frontend/src/pages/Index.tsx:10-23` |
| Proposta de valor clara | Atendido | `frontend/src/components/Hero.tsx:37-59`, `frontend/src/components/FeedSection.tsx:36-44` |
| CTA | Atendido | `frontend/src/components/Hero.tsx:67-74`, `frontend/src/components/CTASection.tsx:13-26,50-84` |
| SEO básico | Atendido | `frontend/index.html:2-15,16-55` |
| Auth login/cadastro | Atendido | `frontend/src/pages/Auth.tsx:46-80,82-185`, `backend/accounts/api.py:220-280` |
| Backend Django + Ninja | Atendido | `backend/requirements.txt:1-5`, `backend/config/api.py:7-17,30-32`, `backend/config/urls.py:4-8` |
| PostgreSQL | Atendido | `backend/config/settings.py:102-112`, `docker-compose.yml:4-13` |
| Funcionalidade principal relevante | Atendido | `backend/learning/api.py:464-540,645-705`, `mobile/lib/features/practice/practice_screen.dart:43-77,121-265` |
| Flutter offline-first | Atendido | `mobile/lib/core/repositories.dart:110-218,369-457`, `mobile/lib/core/state.dart:111-167,276-285` |
| Sync com backend | Atendido | `mobile/lib/core/repositories.dart:402-457`, `backend/learning/api.py:645-705` |
| PRD | Atendido | `PRD.md:98-126,176-236` |
| Tech Specs | Atendido | `TechSpecs.md:242-365,366-427` |
| Docker / CI-CD | Atendido | `docker-compose.yml:3-117`, `.github/workflows/ci.yml:10-91`, `codemagic.yaml:1-40` |
| Observabilidade | Parcial forte | `backend/config/health.py:58-84`, `backend/operations/tasks.py:122-169`, `backend/config/settings.py:282-309` |
| Segurança | Parcial | `backend/accounts/jwt.py:37-139`, `backend/config/settings.py:115-192`, `frontend/src/lib/auth.ts:52-60,72-95` |
| Testes | Parcial | `backend/accounts/tests.py:9-171`, `backend/learning/tests.py:30-198`, `backend/operations/tests.py:24-116`, `frontend/src/test/example.test.ts:1-7`, `mobile/test/widget_test.dart:6-12` |
| Frontend em Next.js | Gap | `frontend/README.md:3-13`, `frontend/package.json:6-14`, `frontend/vite.config.ts:1-30`, `frontend/src/main.tsx:1-5` |

**Apresentação Pronta**

**Slide 1 - Resumo Executivo**
"Este projeto é um mini ecossistema educacional focado em microlearning de inglês com cultura pop, com backend único, landing pública, autenticação web e app mobile offline-first."

Porque escolhi isso:
- O desafio pedia end-to-end; eu foquei num recorte com loop principal claro, em vez de espalhar esforço em muitas features superficiais.
- Mantive uma arquitetura incremental e monolítica para acelerar entrega sem fragmentar o domínio.

Evidências:
- `README.md:3-9`
- `PRD.md:5-10,13-19`
- `TechSpecs.md:15-21`

**Slide 2 - Problema e Tese de Produto**
"O produto combate baixa aderência ao estudo ao transformar referências de cultura pop em sessões curtas, visuais e repetíveis."

Porque usei essa solução:
- O aprendizado ganha contexto emocional.
- O mobile-first faz sentido para sessões curtas e conectividade instável.

Evidências:
- `PRD.md:21-30`
- `PRD.md:88-97`
- `DESIGN.md:13-18`
- `DESIGN.md:271-277`

**Slide 3 - Arquitetura End-to-End**
"Centralizei o domínio no backend e deixei web e mobile consumirem os mesmos contratos HTTP."

Porque usei essa solução:
- reduz duplicação de regra
- facilita evolução simultânea de web/mobile
- mantém uma única source of truth

Evidências:
- `TechSpecs.md:15-21`
- `TechSpecs.md:64-75`
- `backend/config/api.py:15-32`
- `backend/config/urls.py:4-8`

**Slide 4 - Landing Page**
"A landing entrega proposta de valor, CTA e SEO básico, como pedido no desafio."

O que eu mostraria:
- headline e proposta
- CTA para login e waitlist
- meta tags, Open Graph e JSON-LD

Porque usei essa solução:
- a landing precisava converter rápido
- conectei o CTA com waitlist real, não um mock

Evidências:
- Proposta de valor: `frontend/src/components/Hero.tsx:37-59`
- CTA visual: `frontend/src/components/Hero.tsx:67-74`
- CTA funcional: `frontend/src/components/CTASection.tsx:13-26,50-84`
- SEO: `frontend/index.html:2-15,16-55`
- Composição da landing: `frontend/src/pages/Index.tsx:10-23`

**Slide 5 - Autenticação e Identidade**
"Implementei autenticação JWT custom com cadastro, login, refresh e leitura do usuário autenticado."

Porque usei essa solução:
- queria controle total do fluxo e poucas dependências no MVP
- backend expõe um contrato simples para web e mobile

Evidências:
- Auth web: `frontend/src/pages/Auth.tsx:46-80,82-185`
- Rotas web: `frontend/src/App.tsx:19-25`
- Registro/login/refresh/me: `backend/accounts/api.py:220-280`
- JWT custom: `backend/accounts/jwt.py:37-139`

Observação importante para CTO:
- ponto positivo: simplicidade e transparência
- gap assumido: sem rotation/revogação

Gap documentado:
- `TechSpecs.md:375-382`

**Slide 6 - Backend e Persistência**
"O backend foi construído em Django + Django Ninja com PostgreSQL como banco principal."

Porque usei essa solução:
- Django acelera modelagem e operações
- Ninja mantém API enxuta e tipada
- PostgreSQL dá base robusta para o domínio relacional

Evidências:
- Stack backend: `backend/README.md:3-10`
- Dependências: `backend/requirements.txt:1-7`
- API central: `backend/config/api.py:7-17,30-32`
- PostgreSQL: `backend/config/settings.py:102-112`
- Compose com banco: `docker-compose.yml:4-13`

**Slide 7 - Funcionalidade Principal Relevante**
"A principal funcionalidade entregue é o loop de estudo: feed personalizado, detalhe da lesson e prática linha a linha com submissão idempotente."

Porque usei essa solução:
- o desafio pedia pelo menos uma funcionalidade relevante
- escolhi uma feature educacional central, não só CRUD administrativo

Evidências de domínio:
- Modelos: `backend/learning/models.py:23-61,89-121,133-199`
- Feed público/personalizado e lesson detail: `backend/learning/api.py:464-540`
- Submissions idempotentes: `backend/learning/api.py:645-705`
- Testes de idempotência: `backend/learning/tests.py:64-142`

**Slide 8 - Mobile Offline-First**
"O app Flutter é a superfície principal de estudo e foi desenhado para continuar útil mesmo sem rede."

Porque usei essa solução:
- o problema real do usuário envolve interrupção e rede instável
- offline-first aqui não é discurso: há cache, fila local e sincronização posterior

Evidências:
- Stack Flutter: `mobile/pubspec.yaml:9-20`
- Rotas do app: `mobile/lib/app/app.dart:15-45`
- Cache local: `mobile/lib/core/repositories.dart:110-174`
- Fila offline: `mobile/lib/core/repositories.dart:176-218`
- Sync pendente: `mobile/lib/core/repositories.dart:402-457`
- Bootstrap com fallback offline: `mobile/lib/core/state.dart:111-167`
- Sync antes do feed: `mobile/lib/core/state.dart:276-285`

**Slide 9 - Experiência de Prática**
"A prática usa reconhecimento local e envia a tentativa ao backend, ou enfileira offline se necessário."

Porque usei essa solução:
- reconhecimento local melhora responsividade
- backend preserva neutralidade do dado para processar melhor depois

Evidências:
- UI de prática: `mobile/lib/features/practice/practice_screen.dart:43-77`
- Avaliação local da fala: `mobile/lib/features/practice/practice_screen.dart:121-225`
- Envio ou fila offline: `mobile/lib/features/practice/practice_screen.dart:227-265`
- Backend mantém submission como `pending`: `backend/learning/api.py:668-697`

Mensagem boa para CTO:
"Eu preferi não falsear um score server-side frágil; o backend guarda a tentativa e deixa espaço para um processor confiável no próximo ciclo."

Suporte:
- `PRD.md:118-122`
- `TechSpecs.md:411-415`

**Slide 10 - Infra, Operação e Bônus**
"Além do core do produto, eu entreguei uma base operacional: Docker Compose, health check, e-mails assíncronos, scheduler, CI e mobile CI."

Porque usei essa solução:
- quis demonstrar maturidade de entrega, não só features de UI
- o produto fica reproduzível localmente e observável

Evidências:
- Docker Compose: `docker-compose.yml:3-117`
- Health check: `backend/config/health.py:58-84`
- Tasks operacionais: `backend/operations/tasks.py:72-169`
- Configuração de cache/Celery/logging: `backend/config/settings.py:210-309`
- GitHub Actions: `.github/workflows/ci.yml:10-91`
- Codemagic: `codemagic.yaml:1-40`

**Slide 11 - Testes**
"Eu priorizei cobertura do backend, que concentra regra de negócio e contratos críticos."

Porque usei essa solução:
- backend é o núcleo do domínio
- autenticação, submissions, feed e operações são as áreas com maior risco funcional

Evidências:
- Auth/profile/waitlist: `backend/accounts/tests.py:9-171`
- Feed/submissions: `backend/learning/tests.py:30-198`
- Health/ops: `backend/operations/tests.py:24-116`

Honestidade necessária:
- frontend ainda tem teste placeholder
- mobile ainda tem teste muito básico

Evidências:
- `frontend/src/test/example.test.ts:1-7`
- `mobile/test/widget_test.dart:6-12`
- `TechSpecs.md:395-401`

**Slide 12 - Tradeoffs Técnicos**
"Eu tomei algumas decisões intencionais para caber no prazo sem sacrificar coerência arquitetural."

Tradeoff 1:
- Monólito em vez de microsserviços
- porque: rapidez, clareza de domínio e menos custo operacional
- evidência: `PRD.md:230-236`, `TechSpecs.md:21`

Tradeoff 2:
- JWT custom em vez de solução pronta
- porque: controle e simplicidade no MVP
- risco: segurança precisa endurecer
- evidência: `backend/accounts/jwt.py:37-139`, `TechSpecs.md:375-382`

Tradeoff 3:
- Mobile-first real
- porque a experiência principal é prática curta e offline
- evidência: `README.md:204-207`, `TechSpecs.md:417-420`

**Slide 13 - Gaps Honestamente Assumidos**
"Eu prefiro explicitar os gaps do que vender uma maturidade que o código ainda não sustenta."

Gap 1:
- o enunciado pede Next.js, mas o frontend atual é React + Vite
- evidências: `frontend/README.md:3-13`, `frontend/package.json:6-14`, `frontend/vite.config.ts:1-30`, `frontend/src/main.tsx:1-5`

Gap 2:
- a web ainda não é um SaaS completo; hoje cobre landing, auth e portal
- evidências: `frontend/README.md:81-94`, `TechSpecs.md:242-263`, `PRD.md:118-126`

Gap 3:
- scoring server-side ainda não foi fechado
- evidências: `PRD.md:120-122`, `TechSpecs.md:413-415`

Gap 4:
- segurança e testes de frontend/mobile ainda precisam de ciclo adicional
- evidências: `TechSpecs.md:375-401`

**Slide 14 - Fechamento**
"Minha prioridade foi entregar um sistema funcional e coerente de ponta a ponta, com núcleo educacional real, resiliência offline e base operacional suficiente para evoluir."

Feche com:
- produto coerente
- backend consistente
- mobile com diferencial técnico real
- web já útil para aquisição e identidade
- gaps claramente mapeados para o próximo ciclo

**Script Curto De Demo**

1. Mostrar a landing e a proposta de valor.
   Referência: `frontend/src/components/Hero.tsx:37-59`

2. Mostrar o CTA conectado ao backend.
   Referência: `frontend/src/components/CTASection.tsx:13-26`

3. Mostrar login/cadastro web.
   Referência: `frontend/src/pages/Auth.tsx:46-80`

4. Mostrar rapidamente os endpoints centrais no backend.
   Referência: `backend/config/api.py:15-32`

5. Mostrar no mobile:
   login, onboarding, feed, lesson, prática.
   Referências:
   - `mobile/lib/app/app.dart:15-45`
   - `mobile/lib/core/state.dart:111-167`
   - `mobile/lib/features/practice/practice_screen.dart:227-265`

6. Fechar mostrando que o app suporta offline queue e sync.
   Referência: `mobile/lib/core/repositories.dart:176-218,402-457`

7. Finalizar com CI, Docker e health.
   Referências:
   - `docker-compose.yml:3-117`
   - `.github/workflows/ci.yml:10-91`
   - `backend/config/health.py:58-84`

**Perguntas Que O CTO Provavelmente Vai Fazer**

"Por que mobile-first?"
- Porque a prática curta e recorrente faz mais sentido no celular, e o app precisava continuar útil em rede instável.
- `PRD.md:23-30`
- `TechSpecs.md:287-305`

"Por que Django monolítico?"
- Porque reduz custo de coordenação e mantém o domínio centralizado enquanto o MVP amadurece.
- `PRD.md:234-235`
- `TechSpecs.md:21`

"Por que JWT custom?"
- Para manter o fluxo explícito e com baixa dependência no MVP.
- Reconheço que o próximo passo é endurecer segurança.
- `backend/accounts/jwt.py:37-139`
- `TechSpecs.md:375-382`

"O que você faria no próximo ciclo?"
- migrar web para Next.js
- transformar a web em SaaS mais completo
- endurecer auth/segurança
- ampliar testes de frontend/mobile
- fechar processor de scoring
- `PRD.md:118-125`
- `TechSpecs.md:403-427`

**O Que Eu Não Recomendo Você Falar**
- Não diga que já está em `Next.js`.
- Não diga que já existe IA robusta em produção.
- Não diga que já suporta múltiplos idiomas amplamente.
- Não diga que a web já é a experiência principal.

Base para manter o discurso honesto:
- `DESIGN.md:271-282`
- `PRD.md:37-43`
- `PRD.md:127-134`

Se quiser, no próximo passo eu posso transformar isso em um roteiro de apresentação de 5 minutos, com fala pronta slide por slide.

---

