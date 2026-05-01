# Vibe Studying

Vibe Studying e um monorepo educacional mobile-first focado em microlearning de ingles com cultura pop.

Hoje o projeto esta dividido assim:

- `backend/`: API Django + Django Ninja, auth JWT custom, profile, onboarding, feed, lessons, submissions, cache, e-mails e health check
- `frontend/`: landing publica, auth web simples e portal autenticado para distribuicao de links Android
- `mobile/`: app Flutter do aluno com onboarding, feed personalizado, pratica estilo HUD e fila offline de tentativas

## Estado Atual

Ja implementado no codigo:

- waitlist publica na landing
- cadastro e login de aluno e professor
- onboarding de gostos e nivel de ingles
- feed publico e feed personalizado
- criacao e edicao de lessons pelo professor
- detail de lesson com multiplas linhas de pratica
- submissions do aluno com idempotencia
- cache local no mobile
- fila offline de tentativas no mobile
- e-mails transacionais, reminders e checks operacionais no backend

## Documentacao Do Projeto

- `PRD.md`: visao de produto e roadmap realista
- `TechSpecs.md`: arquitetura, contratos e gaps tecnicos
- `DESIGN.md`: diretrizes de UX, sistema visual e copy
- `backend/README.md`: setup e operacao do backend
- `frontend/README.md`: setup e operacao do frontend
- `mobile/README.md`: setup do Flutter e execucao do app

## Requisitos Do Monorepo

Para trabalhar nas tres camadas localmente, o caminho mais pratico em Linux e:

- Python 3.12+
- PostgreSQL 16+
- Redis 7+ opcional para fila/cache completos
- Node.js 20+
- npm 10+
- Flutter stable
- Git, curl e unzip

## Quick Start

### 1. Backend

Veja detalhes completos em `backend/README.md`.

Resumo:

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
python manage.py migrate
python manage.py runserver
```

API local esperada em `http://127.0.0.1:8000/api`.

### 2. Frontend

Veja detalhes completos em `frontend/README.md`.

Resumo:

```bash
cd frontend
cp .env.example .env
npm install
npm run dev
```

Frontend local esperado em `http://127.0.0.1:8080`.

### 3. Mobile Flutter

Veja detalhes completos em `mobile/README.md`.

Resumo para Linux desktop:

```bash
cd mobile
flutter pub get
flutter run -d linux --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

Importante:

- o projeto ja possui `linux/`, `android/` e `ios/` versionados
- voce nao precisa rodar `flutter create .`
- para testar o fluxo completo de microfone, Android ou iOS continuam sendo os alvos mais confiaveis

## Variaveis De Ambiente

### Backend

Arquivo: `backend/.env`

Base recomendada:

```env
DEBUG=True
SECRET_KEY=change-me
PUBLIC_API_HOST=127.0.0.1
PUBLIC_API_ORIGIN=http://127.0.0.1:8000
ALLOWED_HOSTS=127.0.0.1,localhost,testserver
CORS_ALLOW_ALL_ORIGINS=True
CORS_ALLOWED_ORIGINS=http://localhost:8080,http://127.0.0.1:8080
CSRF_TRUSTED_ORIGINS=http://localhost:8080,http://127.0.0.1:8080
DATABASE_NAME=vibe_studying
DATABASE_USER=postgres
DATABASE_PASSWORD=postgres
DATABASE_HOST=127.0.0.1
DATABASE_PORT=5432
JWT_SECRET_KEY=change-me-too
ENABLE_PUBLIC_TEACHER_SIGNUP=True
EMAIL_BACKEND=django.core.mail.backends.console.EmailBackend
PUBLIC_WEB_URL=http://localhost:8080
RUNTIME_ENVIRONMENT=development
REDIS_URL=
CACHE_URL=
CELERY_BROKER_URL=memory://
CELERY_RESULT_BACKEND=cache+memory://
```

### Frontend

Arquivo: `frontend/.env`

Base recomendada:

```env
VITE_API_URL=http://127.0.0.1:8000/api
VITE_ANDROID_APP_URL=
VITE_FLUTTER_ANDROID_URL=
```

### Mobile

O app Flutter nao usa `.env` no repositorio atual.

Voce pode configurar a URL do backend de duas formas:

- por `--dart-define=API_BASE_URL=...`
- pelo botao de configuracao de backend dentro do app

Exemplo:

```bash
flutter run -d linux --dart-define=API_BASE_URL=http://127.0.0.1:8000/api
```

## Docker Compose

Se quiser subir uma stack local mais completa com Postgres, Redis, backend, worker, beat e frontend:

```bash
docker compose up --build
```

Servicos esperados:

- frontend em `http://127.0.0.1:8080`
- backend em `http://127.0.0.1:8000/api`
- PostgreSQL em `127.0.0.1:5432`
- Redis em `127.0.0.1:6379`

## Testes

### Backend

```bash
cd backend
source .venv/bin/activate
python manage.py check
python manage.py test
```

### Frontend

```bash
cd frontend
npm install
npm run test
npm run build
```

### Mobile

```bash
cd mobile
flutter test
```

## Observacoes Importantes

- a experiencia principal de estudo esta no app mobile
- a web hoje nao implementa feed de estudo completo; ela cobre aquisicao, auth e distribuicao
- o backend ja tem base de operacao, mas o processamento confiavel de score das submissions ainda e um gap aberto
- para setup detalhado por camada, use os READMEs internos de `backend/`, `frontend/` e `mobile/`
