<h1 align="center">Vibe Studying</h1>

<p align="center">
  O Vibe Studying é um projeto educacional que transforma a lógica do feed infinito em uma experiência de estudo.
  Em vez de consumir conteúdo vazio, o usuário navega por lessons curtas inspiradas na cultura pop, com foco em aprendizagem rápida e repetível.
</p>

<p align="center">
  <img alt="Status" src="https://img.shields.io/badge/status-MVP-ff2ea6?style=for-the-badge">
  <img alt="Frontend" src="https://img.shields.io/badge/frontend-React%20%2B%20Vite-61dafb?style=for-the-badge&logo=react&logoColor=000">
  <img alt="Backend" src="https://img.shields.io/badge/backend-Django%20Ninja-0c4b33?style=for-the-badge&logo=django&logoColor=white">
  <img alt="Language" src="https://img.shields.io/badge/language-TypeScript%20%2B%20Python-7c3aed?style=for-the-badge">
  <img alt="Database" src="https://img.shields.io/badge/database-PostgreSQL-336791?style=for-the-badge&logo=postgresql&logoColor=white">
</p>

<p align="center">
  <img src="./frontend/src/assets/hero-vibe.jpg" alt="Capa do Vibe Studying" width="100%" />
</p>

## Visão Geral

O projeto foi estruturado como um desafio técnico end-to-end e, hoje, já entrega uma base funcional com:

- landing page pública com identidade visual forte
- autenticação com JWT customizado
- cadastro separado para aluno e professor
- feed público de lessons publicadas
- detalhe de lesson com exercise vinculado
- criação e edição de lessons pelo professor
- envio e consulta de submissions pelo aluno
- testes básicos no backend e no frontend

## Status Atual

- O que está implementado no código: landing page, tela de autenticação, API em Django Ninja, domínio de learning, JWT e testes principais.
- O que aparece como visão de produto na interface: IA de pronúncia, app Flutter e workflows assíncronos.
- O que ainda não está implementado neste repositório: pipeline real de IA, app mobile versionado aqui e orquestração com Temporal.

## Stack

| Camada | Tecnologia |
| --- | --- |
| Frontend | React 18, Vite, TypeScript, Tailwind CSS, shadcn/ui e Framer Motion |
| Backend | Django 6, Django Ninja e JWT customizado |
| Banco | PostgreSQL |
| Testes | Vitest, Testing Library e Django TestCase |
| UX | Visual cyberpunk, alto contraste e linguagem inspirada em HUD/feed |

## Arquitetura

```mermaid
flowchart LR
    A[Landing + Auth<br/>React/Vite] --> B[API /api<br/>Django Ninja]
    B --> C[Accounts]
    B --> D[Learning]
    C --> E[(PostgreSQL)]
    D --> E
    D --> F[Lessons]
    D --> G[Exercises]
    D --> H[Submissions]
```

## Fluxo Principal

1. O usuário cria uma conta ou faz login via `api/auth/*`.
2. O backend retorna `access_token`, `refresh_token` e os dados resumidos do usuário.
3. Professores podem criar lessons com exercise embutido.
4. Lessons publicadas entram no feed público consumido pelo frontend.
5. Alunos enviam submissions para exercícios e acompanham o próprio histórico.

## Estrutura do Repositório

```text
.
├── backend/
│   ├── accounts/
│   ├── learning/
│   ├── config/
│   ├── manage.py
│   └── requirements.txt
├── frontend/
│   ├── src/
│   │   ├── components/
│   │   ├── pages/
│   │   ├── lib/
│   │   └── test/
│   └── package.json
└── README.md
```

## Como Rodar

### Backend

Requisitos:

- Python 3.12+
- PostgreSQL

```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python manage.py migrate
python manage.py runserver
```

API disponível em `http://localhost:8000/api`.

Se quiser verificar rapidamente se a API subiu, use `GET /api/health`.

### Frontend

Requisitos:

- Node.js 20+
- npm

Crie um arquivo `.env` dentro de `frontend/` com:

```env
VITE_API_URL=http://localhost:8000/api
VITE_ANDROID_APP_URL=
VITE_FLUTTER_ANDROID_URL=
```

Depois, rode:

```bash
cd frontend
npm install
npm run dev
```

Aplicação web disponível em `http://localhost:8080` ou na porta informada pelo Vite.

## Variáveis de Ambiente

### Backend

| Variável | Descrição |
| --- | --- |
| `DEBUG` | Ativa o modo de desenvolvimento |
| `SECRET_KEY` | Chave principal do Django |
| `ALLOWED_HOSTS` | Hosts permitidos |
| `CORS_ALLOWED_ORIGINS` | Origens liberadas para o frontend |
| `CSRF_TRUSTED_ORIGINS` | Origens confiáveis para CSRF |
| `DATABASE_NAME` | Nome do banco PostgreSQL |
| `DATABASE_USER` | Usuário do banco |
| `DATABASE_PASSWORD` | Senha do banco |
| `DATABASE_HOST` | Host do banco |
| `DATABASE_PORT` | Porta do banco |
| `JWT_SECRET_KEY` | Chave para assinatura dos tokens |
| `JWT_ACCESS_TOKEN_LIFETIME_MINUTES` | Duração do access token |
| `JWT_REFRESH_TOKEN_LIFETIME_DAYS` | Duração do refresh token |

### Frontend

| Variável | Descrição |
| --- | --- |
| `VITE_API_URL` | URL base da API Django Ninja |
| `VITE_ANDROID_APP_URL` | Link do APK Android |
| `VITE_FLUTTER_ANDROID_URL` | Link da build Flutter Android |

## Endpoints Principais

| Método | Rota | Função |
| --- | --- | --- |
| `GET` | `/api/health` | Health check da API |
| `POST` | `/api/auth/register` | Cadastro de aluno |
| `POST` | `/api/auth/register/teacher` | Cadastro de professor |
| `POST` | `/api/auth/login` | Login |
| `POST` | `/api/auth/refresh` | Renovação de token |
| `GET` | `/api/auth/me` | Perfil autenticado |
| `GET` | `/api/feed` | Feed público de lessons |
| `GET` | `/api/lessons/{slug}` | Detalhe de uma lesson |
| `GET` | `/api/teacher/lessons` | Lista de lessons do professor |
| `POST` | `/api/teacher/lessons` | Cria uma lesson com exercise |
| `PUT` | `/api/teacher/lessons/{lesson_id}` | Atualiza a lesson |
| `POST` | `/api/submissions` | Envia a tentativa do aluno |
| `GET` | `/api/submissions/me` | Lista o histórico do aluno |

## Testes

### Backend

```bash
cd backend
source .venv/bin/activate
python manage.py test
```

### Frontend

```bash
cd frontend
npm install
npm run test
```

## Roadmap

- avaliação automatizada de pronúncia com pipeline real de IA
- roteamento completo do portal autenticado no frontend
- app Flutter offline-first integrado ao backend
- processamento assíncrono para correções e distribuição de conteúdo
- observabilidade, deploy e CI/CD

## Nota

Este README descreve o estado atual do código. A identidade visual da landing page comunica uma visão de produto maior do que o MVP implementado hoje, e isso foi mantido intencionalmente para apresentar o potencial da plataforma sem mascarar o escopo real já entregue.
