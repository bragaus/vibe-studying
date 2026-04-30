# PRD - Vibe Studying

## Objetivo

Construir uma plataforma educacional mobile-first que transforma padroes de consumo de feed curto em pratica ativa de ingles, combinando cultura pop, microlearning, personalizacao e uma experiencia de uso resiliente mesmo com conectividade instavel.

## Problema

Apps tradicionais de estudo tendem a perder retencao porque exigem muita energia de arranque e pouca recompensa imediata. O Vibe Studying quer reduzir essa friccao com:

- lessons curtas e repetiveis
- contexto cultural relevante para o aluno
- feedback rapido de pratica
- feed personalizado com baixo custo cognitivo de entrada

## Visao Do Produto

Entregar um ecossistema com tres camadas complementares:

- landing web para apresentacao do produto e captacao
- backend centralizado como source of truth de autenticacao, conteudo, perfil e processamento
- app mobile do aluno com experiencia de estudo prioritaria, incluindo cache local e sincronizacao offline -> online

## Escopo

### Incluido neste ciclo

- landing page publica com SEO basico
- backend Django com auth, perfil de aluno, feed, lessons e submissions
- app Flutter do aluno com login, onboarding, feed personalizado e pratica
- cache local e fila de tentativas pendentes no mobile
- sincronizacao offline -> online com idempotencia
- processamento assincrono inicial para e-mails e jobs de backoffice
- deploy reproduzivel com Docker e CI/CD minimo
- logs, monitoramento e health checks essenciais

### Nao Incluido neste ciclo

- migracao para microservicos
- app mobile de professor
- realtime completo de avaliacao de voz
- automacao de IA sem revisao humana
- plataforma SaaS completa com pagamentos, turmas e billing
- Temporal como requisito imediato de infraestrutura

## Usuarios E Personas

### Aluno

- quer estudar ingles com baixa friccao
- responde bem a cultura pop e experiencia mobile
- precisa continuar estudando com rede instavel

### Professor / Curador

- cria e publica lessons
- organiza exercicios e linhas de pratica
- precisa de fluxos simples de edicao e distribuicao

### Operacao

- acompanha saude do sistema e jobs assincronos
- dispara comunicacoes e lembra o aluno de voltar
- precisa de visibilidade sobre falhas e gargalos

## Casos De Uso Principais

1. Aluno cria conta, faz login e conclui onboarding.
2. Aluno recebe feed personalizado com base em gostos e historico.
3. Aluno abre uma lesson, pratica as linhas e envia a tentativa.
4. Aluno continua usando o app sem internet e sincroniza depois.
5. Professor publica lessons para o feed.
6. Plataforma envia e-mails de onboarding, lembrete e reengajamento.
7. Operacao acompanha falhas, disponibilidade e jobs em processamento.

## Requisitos Funcionais

### Identidade E Perfil

- RF-01: permitir cadastro e login com sessao persistente
- RF-02: permitir onboarding do aluno com preferencias de conteudo
- RF-03: expor perfil do aluno para leitura e atualizacao

### Conteudo E Aprendizagem

- RF-04: listar feed publico e feed personalizado
- RF-05: expor detalhe da lesson com exercise e linhas ordenadas
- RF-06: permitir submissao de tentativa do aluno
- RF-07: armazenar status de processamento da submissao

### Mobile Offline-First

- RF-08: manter cache local de perfil, feed e lessons recentes
- RF-09: permitir criar tentativas offline
- RF-10: reenviar tentativas pendentes quando a conectividade voltar
- RF-11: evitar duplicidade usando identificadores idempotentes de sincronizacao

### Workflows Assincronos

- RF-12: enviar e-mails transacionais de forma assincrona
- RF-13: agendar lembretes e drip content
- RF-14: preparar pipeline para processamento futuro de feedback/IA

### Plataforma E Operacao

- RF-15: expor health checks e logs estruturados
- RF-16: disponibilizar deploy reproduzivel via Docker
- RF-17: executar validacoes basicas em CI/CD

## Requisitos Nao Funcionais

- RNF-01: backend deve ser a fonte confiavel de status, score e processamento
- RNF-02: aplicacao mobile deve tolerar falhas de rede sem perder tentativas do aluno
- RNF-03: configuracao de producao nao pode depender de defaults inseguros
- RNF-04: servicos devem ser observaveis com logs e monitoramento basico
- RNF-05: API deve suportar paginacao e evolucao de contratos sem quebrar os clientes atuais
- RNF-06: arquitetura deve priorizar incrementalismo e baixo custo operacional

## Metricas De Sucesso

- taxa de cadastro concluido
- taxa de onboarding concluido
- retencao D1 e D7
- lessons consumidas por usuario ativo por semana
- percentual de tentativas sincronizadas com sucesso
- tempo medio de processamento de jobs assincronos
- disponibilidade da API
- conversao da landing para waitlist/cadastro

## Riscos

- desalinhamento entre marketing e o que o codigo realmente entrega
- sync offline -> online sem idempotencia gerar duplicidade
- score calculado no cliente comprometer confiabilidade dos dados
- falta de observabilidade atrasar diagnostico em producao
- personalizacao do feed escalar mal sem revisao de algoritmo e cache
- endurecimento tardio de seguranca bloquear o deploy final

## Dependencias Tecnicas

- PostgreSQL como banco principal
- Redis como base recomendada para filas, scheduler e cache
- worker assicrono para e-mails, lembretes e processamento de submissions
- contrato estavel entre backend Django e app Flutter

## Estrategia De Entrega

### Fundacao

- alinhar PRD, README e TechSpecs
- endurecer seguranca e contratos do backend
- preparar Docker, CI minima e observabilidade basica

### Produto Minimo Viavel

- completar SEO basico da landing
- reforcar auth no web e mobile
- adicionar cache local e fila pendente no mobile
- criar sincronizacao offline -> online segura

### Robustez

- introduzir worker assincrono
- processar e-mails e submissions em background
- adicionar reminders e testes de falha

### Automacao

- automatizar campanhas de onboarding e reengajamento
- gerar rascunhos de conteudo com IA sob revisao humana

### Escalabilidade

- cachear consultas quentes
- reduzir custo do feed personalizado
- ampliar monitoramento, alertas e performance

## Criterios De Aceite Do Primeiro Marco

- `PRD.md` aprovado e refletindo o estado real do produto
- documentacao principal alinhada com o monorepo atual
- backlog inicial organizado por fases
- primeira trilha de execucao pronta para sair da documentacao e entrar em hardening de base
