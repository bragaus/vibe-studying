# PRD - Vibe Studying

Doc status: baseline alinhada ao codigo real do monorepo em 2026-04-30.

## Overview

Vibe Studying e um produto educacional mobile-first que transforma referencias de cultura pop em sessoes curtas de pratica de ingles. O backend ja sustenta autenticacao, onboarding, feed personalizado basico, conteudo curado por professor, fila offline de tentativas no mobile e operacao inicial com health checks, cache e e-mails assincronos.

A web existe hoje como camada de aquisicao, autenticacao simples e distribuicao de links Android. A experiencia principal de estudo esta no app Flutter.

## Product Statement

Transformar o impulso de consumir feed curto em pratica ativa de ingles com:

- entrada rapida
- contexto cultural familiar
- repeticao guiada
- experiencia visual memoravel
- resiliencia a rede instavel

## Problema

Apps de estudo costumam falhar em tres pontos:

- exigem muita energia inicial para comecar
- apresentam conteudo pouco emocionalmente relevante
- quebram a rotina quando a conexao falha ou a sessao e interrompida

O Vibe Studying reduz essa friccao com lessons curtas, onboarding por gostos, feed personalizado e pratica guiada em formato HUD/karaoke.

## Posicionamento

Posicionamento recomendado com base no codigo atual:

"Vibe Studying e um MVP mobile-first de microlearning de ingles com cultura pop, focado em lessons curtas, repeticao guiada e pratica de fala."

Nao posicionar ainda como:

- plataforma completa multi-idioma
- produto premium com billing
- experiencia de IA robusta em producao
- SaaS web completo para professor e aluno

## Usuarios

### Aluno

Perfil:

- quer estudar ingles com baixa friccao
- responde bem a musica, filmes, series e anime
- prefere celular ao desktop
- pode estudar em contexto de conectividade instavel

Objetivos:

- criar conta rapido
- configurar gostos sem burocracia
- receber um feed relevante
- praticar sem perder progresso quando a internet cai

### Professor / Curador

Perfil:

- organiza conteudo curto para consumo em feed
- precisa publicar lessons com baixo custo operacional

Objetivos:

- criar e editar lessons
- adicionar frases e linhas de pratica
- publicar conteudo no feed sem depender do mobile

### Operacao

Perfil:

- acompanha saude da aplicacao
- precisa detectar backlog e falhas de fila/processamento

Objetivos:

- monitorar disponibilidade
- disparar lembretes de reengajamento
- receber alertas operacionais

## Jobs To Be Done

Quando eu abrir o app para estudar ingles, quero entrar em uma sessao curta baseada no que eu gosto, para praticar sem sentir que estou entrando em uma aula pesada.

Quando eu estiver sem conexao, quero continuar praticando e enviar a tentativa depois, para nao perder o ritmo.

Quando eu publicar conteudo como professor, quero ver isso chegar ao feed do aluno sem pipeline complexa.

Quando eu operar a plataforma, quero descobrir rapidamente se banco, cache, broker ou filas estao degradados.

## Estado Atual Do Produto

### Implementado Hoje

- landing page publica com CTA e waitlist real
- autenticacao JWT custom para aluno e professor
- onboarding de aluno com preferencias e nivel de ingles
- feed publico e feed personalizado autenticado
- detalhe de lesson com exercise e multiplas linhas
- criacao e edicao de lessons pelo professor
- envio de submissions do aluno com idempotencia
- historico de submissions do aluno
- app mobile com login, cadastro, onboarding, feed e pratica
- cache local de profile, feed e lesson no mobile
- fila offline de tentativas no mobile com sincronizacao posterior
- cache de feed publico e detalhe de lesson no backend
- health check com banco, cache e broker
- fila de e-mails, lembretes de inatividade e alertas operacionais
- Docker Compose, CI para backend/frontend e workflow Codemagic para mobile

### Parcial Ou Incompleto

- scoring confiavel do aprendizado no backend
- processamento de submissions apos status `pending`
- personalizacao baseada em mastery/review real
- portal web de produto alem de auth/download
- cobertura de testes no frontend e no mobile
- endurecimento de seguranca para producao

### Fora Do Escopo Atual

- billing
- gamificacao complexa com ranking social
- IA de avaliacao de fala em producao
- app mobile de professor
- cursos, modulos e trilhas longas
- suporte amplo a multiplos idiomas

## Fluxos Principais

### 1. Aquisicao Web

1. Usuario acessa a landing.
2. Usuario entra na waitlist via `POST /api/waitlist`.
3. Backend deduplica o e-mail e agenda e-mail de boas-vindas.

### 2. Ativacao Do Aluno

1. Usuario cria conta via mobile ou web.
2. Backend retorna `access_token`, `refresh_token` e user.
3. Mobile busca `GET /api/profile/me`.
4. Se onboarding nao foi concluido, direciona para `/onboarding`.
5. Usuario informa nivel e gostos.
6. Mobile envia `POST /api/profile/onboarding`.
7. Usuario entra no feed personalizado.

### 3. Loop De Estudo

1. Mobile carrega `GET /api/feed/personalized`.
2. Usuario abre a lesson.
3. Mobile carrega `GET /api/lessons/{slug}`.
4. Usuario pratica linha por linha com reconhecimento local de fala.
5. App envia `POST /api/submissions`.
6. Se estiver offline, salva a tentativa localmente e reenvia depois.

### 4. Publicacao De Conteudo

1. Professor autentica.
2. Professor lista ou cria lessons via `/api/teacher/lessons`.
3. Ao publicar, a lesson entra no feed publico e pode entrar no feed personalizado.

### 5. Operacao

1. Health check exposto em `/api/health`.
2. Beat agenda lembretes e checks operacionais.
3. Worker processa e-mails pendentes.
4. Alertas podem ser enviados por e-mail quando thresholds estouram.

## Requisitos Funcionais

### Aquisicao E Identidade

- RF-01: permitir entrada na waitlist publica com deduplicacao por e-mail
- RF-02: permitir cadastro de aluno
- RF-03: permitir login e refresh de sessao
- RF-04: permitir cadastro de professor por endpoint dedicado, controlado por ambiente
- RF-05: expor dados basicos do usuario autenticado

### Perfil E Onboarding

- RF-06: criar profile de aluno automaticamente no cadastro
- RF-07: permitir leitura do profile do aluno
- RF-08: permitir atualizar preferencias
- RF-09: permitir concluir onboarding com nivel e gostos

### Conteudo E Feed

- RF-10: listar feed publico de lessons publicadas
- RF-11: listar feed personalizado para aluno autenticado
- RF-12: exibir motivo de match no feed personalizado quando houver
- RF-13: exibir detalhe da lesson com exercise e linhas ordenadas
- RF-14: permitir ao professor listar suas lessons
- RF-15: permitir ao professor criar lessons com exercise e multiplas linhas
- RF-16: permitir ao professor editar lessons existentes

### Pratica E Submissoes

- RF-17: permitir pratica mobile linha a linha
- RF-18: permitir envio de submission vinculada a um exercise publicado
- RF-19: garantir idempotencia por `client_submission_id`
- RF-20: listar historico de submissions do aluno
- RF-21: preservar o backend como fonte de verdade para processamento futuro

### Offline-First

- RF-22: salvar profile em cache local no mobile
- RF-23: salvar feed personalizado em cache local no mobile
- RF-24: salvar lesson em cache local no mobile
- RF-25: enfileirar tentativas offline no mobile
- RF-26: sincronizar tentativas pendentes quando a conectividade voltar

### Operacao E Plataforma

- RF-27: expor health check com status de banco, cache e broker
- RF-28: enfileirar e-mails de boas-vindas e lembretes
- RF-29: agendar lembretes de inatividade para alunos onboarded
- RF-30: executar checks operacionais por threshold
- RF-31: permitir execucao local e reproduzivel com Docker Compose
- RF-32: rodar checks e testes minimos em CI

## Requisitos Nao Funcionais

- RNF-01: mobile deve continuar util sob falha de rede temporaria
- RNF-02: contrato da API deve permanecer simples e estavel para web e mobile
- RNF-03: feed e lesson detail devem suportar cache para reduzir custo de leitura
- RNF-04: backlog operacional deve ser observavel por health check e alertas
- RNF-05: arquitetura deve continuar monolitica e incremental enquanto o MVP amadurece
- RNF-06: backend deve centralizar autenticacao, perfil, conteudo e status das tentativas

## Metricas De Sucesso

### Ativacao

- taxa de conversao landing -> waitlist
- taxa de cadastro concluido
- taxa de onboarding concluido

### Uso

- lessons abertas por usuario ativo por semana
- sessoes de pratica concluidas por usuario ativo
- percentual de usuarios que voltam ao app em D1 e D7

### Qualidade Operacional

- percentual de submissions sincronizadas com sucesso apos modo offline
- tempo medio ate envio de e-mail pendente
- disponibilidade do endpoint `/api/health`
- numero de submissions presas em `pending` acima do threshold

## Principais Riscos

- marketing vender mais do que o produto real entrega hoje
- feed personalizado parecer melhor do que e, por depender de match textual simples
- `Submission` permanecer `pending` por falta de processor de scoring
- heuristicas de pratica no cliente serem confundidas com avaliacao confiavel
- seguranca insuficiente para producao por defaults abertos e JWT custom
- portal web ser interpretado como SaaS completo, quando hoje e apenas auth + download

## Principios De Produto

- mobile primeiro, web como apoio
- friccao minima para entrar na pratica
- contexto cultural como alavanca de motivacao, nao como gimmick
- clareza entre o que ja existe e o que ainda e visao futura
- robustez incremental acima de complexidade prematura

## Roadmap Recomendado

### Fase 1 - Harden MVP

- alinhar toda documentacao ao estado real
- endurecer auth, CORS e segredos
- ampliar testes web/mobile nos fluxos reais
- revisar copy publica para evitar overpromise

### Fase 2 - Credibilidade Da Aprendizagem

- implementar processor confiavel de submissions
- preencher `score_en`, `score_pt`, `final_score` e `processed_at`
- recalibrar feed personalizado com mastery/review de verdade
- adicionar feedback de progresso que nao dependa so do cliente

### Fase 3 - Teacher Experience

- criar interface web para criacao e manutencao de lessons
- melhorar validacoes de conteudo
- suportar preview da experiencia mobile a partir do conteudo criado

### Fase 4 - Crescimento E Retencao

- reminders mais inteligentes
- analytics de ativacao e retencao
- loops de reengajamento baseados em gosto e historico
- experimentos de distribuicao dos apps

## Criterios De Aceite Desta Baseline

- PRD descreve com precisao o que esta implementado hoje
- PRD explicita a diferenca entre escopo atual e visao futura
- mobile aparece como experiencia principal de estudo
- web aparece como camada secundaria de aquisicao/auth/download
- riscos de produto e gaps tecnicos ficam claros para o proximo ciclo
