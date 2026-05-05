# Backend - Vibe Studying

Backend em Django 6 + Django Ninja responsavel por auth, profile, onboarding, feed, lessons, submissions e operacao inicial do produto.

## Stack

- Python 3.12+
- Django 6
- Django Ninja
- PostgreSQL
- Redis opcional para cache e Celery completos

## Dependencias Do Sistema

Exemplo para Ubuntu/Debian:

```bash
sudo apt update
sudo apt install -y python3 python3-venv python3-pip libpq-dev postgresql postgresql-contrib redis-server
```

Observacao:

- `redis-server` e opcional se voce quiser apenas subir a API com cache local e Celery em memoria
- para fila, cache Redis e scheduler completos, mantenha o Redis instalado e ativo

## Preparando O PostgreSQL

Uma configuracao simples local usando o usuario `postgres`:

```bash
sudo systemctl enable --now postgresql
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'postgres';"
sudo -u postgres createdb vibe_studying
```

Se o banco ja existir, o `createdb` pode falhar sem problema.

## Instalacao Do Projeto

```bash
cd backend
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
cp .env.example .env
```

## Variaveis De Ambiente

Arquivo usado pelo projeto: `backend/.env`

Exemplo minimo para desenvolvimento local:

```env
DEBUG=True
SECRET_KEY=change-me
PUBLIC_API_HOST=127.0.0.1
PUBLIC_API_ORIGIN=http://127.0.0.1:8000
CORS_ALLOW_ALL_ORIGINS=True
DATABASE_NAME=vibe_studying
DATABASE_USER=postgres
DATABASE_PASSWORD=postgres
DATABASE_HOST=127.0.0.1
DATABASE_PORT=5432
JWT_SECRET_KEY=change-me-too
ENABLE_PUBLIC_TEACHER_SIGNUP=True
EMAIL_BACKEND=
DEFAULT_FROM_EMAIL=noreply@vibestudying.local
SERVER_EMAIL=noreply@vibestudying.local
PUBLIC_WEB_URL=http://localhost:8080
RUNTIME_ENVIRONMENT=development
AI_CURATOR_EMAIL=ai-curator@vibestudying.local
SEARXNG_BASE_URL=http://127.0.0.1:8081
OLLAMA_BASE_URL=http://127.0.0.1:11434
OLLAMA_MODEL=deepseek-r1:8b
REDIS_URL=
CACHE_URL=
CELERY_BROKER_URL=memory://
CELERY_RESULT_BACKEND=cache+memory://
```

### Variaveis Mais Importantes

| Variavel | Obrigatoria | Uso |
| --- | --- | --- |
| `DEBUG` | sim | ativa modo de desenvolvimento |
| `SECRET_KEY` | sim | chave principal do Django |
| `DATABASE_NAME` | sim | nome do banco PostgreSQL |
| `DATABASE_USER` | sim | usuario do banco |
| `DATABASE_PASSWORD` | depende | senha do usuario do banco |
| `DATABASE_HOST` | sim | host do banco |
| `DATABASE_PORT` | sim | porta do banco |
| `JWT_SECRET_KEY` | sim | assinatura dos tokens JWT |
| `PUBLIC_API_ORIGIN` | recomendado | origem publica do backend para callbacks, health e hosts derivados |
| `PUBLIC_WEB_URL` | recomendado | origem publica do frontend para links, CORS e CSRF derivados |
| `CORS_ALLOWED_ORIGINS` | opcional | sobrescreve as origens derivadas do frontend/backend |
| `CSRF_TRUSTED_ORIGINS` | opcional | sobrescreve as origens derivadas do frontend/backend |
| `ENABLE_PUBLIC_TEACHER_SIGNUP` | recomendado | libera ou fecha signup publico de professor |
| `AI_CURATOR_EMAIL` | recomendado | conta tecnica dona das lessons geradas por IA |
| `SEARXNG_BASE_URL` | recomendado | endpoint HTTP do buscador SearXNG |
| `OLLAMA_BASE_URL` | recomendado | endpoint HTTP do Ollama local |
| `OLLAMA_MODEL` | recomendado | modelo carregado no Ollama |
| `EMAIL_BACKEND` | recomendado | console local ou SMTP real |
| `REDIS_URL` | opcional | broker/cache Redis |
| `CACHE_URL` | opcional | cache Redis |
| `CELERY_BROKER_URL` | opcional | broker do Celery |
| `CELERY_RESULT_BACKEND` | opcional | backend de resultados do Celery |

### Modo Minimo Vs Modo Completo

Modo minimo local:

- deixe `REDIS_URL` vazio
- use `CELERY_BROKER_URL=memory://`
- use `CELERY_RESULT_BACKEND=cache+memory://`
- deixe `EMAIL_BACKEND` vazio para modo automatico
- sem credenciais SMTP, o backend cai no console
- com `EMAIL_HOST_USER` e `EMAIL_HOST_PASSWORD`, o backend usa SMTP real

Hosts e origens:

- `ALLOWED_HOSTS`, `CORS_ALLOWED_ORIGINS` e `CSRF_TRUSTED_ORIGINS` podem ser omitidos
- quando omitidos, o backend deriva esses valores a partir de `PUBLIC_API_ORIGIN` e `PUBLIC_WEB_URL`
- se precisar de excecoes especificas, defina as listas manualmente nas variaveis de ambiente

Modo completo local:

```env
REDIS_URL=redis://127.0.0.1:6379/0
CACHE_URL=redis://127.0.0.1:6379/1
CELERY_BROKER_URL=redis://127.0.0.1:6379/0
CELERY_RESULT_BACKEND=redis://127.0.0.1:6379/2
```

## Rodando A API

```bash
cd backend
source .venv/bin/activate
python manage.py migrate
python manage.py runserver
```

API local esperada em `http://127.0.0.1:8000/api`.

Health check:

```text
GET /api/health
```

## Rodando Worker E Scheduler

Somente faz sentido rodar estes processos se voce configurou Redis ou quiser validar Celery localmente.

Para o bootstrap personalizado do feed, voce tambem precisa subir:

- um servidor Ollama com um modelo compatível com JSON, como `deepseek-r1:8b`
- um endpoint SearXNG acessivel pelo backend

Worker:

```bash
cd backend
source .venv/bin/activate
celery -A config worker -l info
```

Beat:

```bash
cd backend
source .venv/bin/activate
celery -A config beat -l info
```

## Testes E Checks

```bash
cd backend
source .venv/bin/activate
python manage.py check
python manage.py test
```

## Endpoints Principais

- `POST /api/auth/register`
- `POST /api/auth/register/teacher`
- `POST /api/auth/login`
- `POST /api/auth/refresh`
- `GET /api/auth/me`
- `GET /api/profile/me`
- `POST /api/profile/onboarding`
- `POST /api/waitlist`
- `GET /api/feed`
- `GET /api/feed/bootstrap-status`
- `POST /api/feed/bootstrap`
- `GET /api/feed/personalized`
- `GET /api/lessons/{slug}`
- `GET /api/teacher/lessons`
- `POST /api/teacher/lessons`
- `PUT /api/teacher/lessons/{lesson_id}`
- `POST /api/submissions`
- `GET /api/submissions/me`
- `GET /api/health`

## Observacoes

- o banco padrao do projeto e PostgreSQL; nao ha suporte real a SQLite no estado atual
- o backend ja suporta e-mails, reminders e checks operacionais
- o processamento confiavel de score das submissions ainda nao esta implementado
