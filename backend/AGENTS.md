# AGENTS #

## Scope
- This repository is backend-only. `README.md` describes the larger challenge (landing page, Next.js, Flutter), but the checked-in code here is only the Django + Django Ninja backend.
- Current product direction is mobile-first: Flutter is the primary client, and any future Next.js app should consume the same backend flows rather than reintroducing Telegram-specific integrations.
- Exclude `venv/` when searching. It is committed and will drown out real project files in glob/grep results.

## Runtime And Env
- Use the repo-local interpreter for all Django commands: `./venv/bin/python manage.py ...`
- `config/settings.py` auto-loads `.env` from the repo root via `python-dotenv`; no extra env loader is wired elsewhere.
- Source of truth for defaults is `config/settings.py`, not `.env.example`. Current code defaults to PostgreSQL (`vibe_studying`) and does not support SQLite.
- Tests also use PostgreSQL through the normal Django settings, so a reachable Postgres server is required even for `manage.py test`.

## Verified Commands
- Run dev server: `./venv/bin/python manage.py runserver`
- Apply migrations: `./venv/bin/python manage.py migrate`
- Create migrations: `./venv/bin/python manage.py makemigrations`
- Django system check: `./venv/bin/python manage.py check`
- Full test suite: `./venv/bin/python manage.py test`
- Focused tests:
  - `./venv/bin/python manage.py test accounts.tests.AuthApiTests`
  - `./venv/bin/python manage.py test learning.tests.LearningApiTests`

## Architecture
- API entrypoint is `config/api.py`; it is mounted under `/api/` from `config/urls.py`.
- Package boundaries:
  - `accounts/`: custom user model, JWT auth, auth routers
  - `learning/`: feed domain (`Lesson`, `Exercise`, `Submission`) and public/teacher/student routers
- `accounts.User` is the active auth model (`AUTH_USER_MODEL = 'accounts.User'`) and is already in `accounts/migrations/0001_initial.py`; do not replace it or rewrite initial auth migrations casually.
- Login is email-based, not username-based. The custom manager auto-generates `username` only to satisfy `AbstractUser`.

## API Conventions
- Public auth routes live under `/api/auth`.
- Student signup is `POST /api/auth/register`.
- Teacher signup is `POST /api/auth/register/teacher`.
- Protected user routes use Bearer access tokens from the custom JWT implementation in `accounts/jwt.py`; this repo does not use `simplejwt` or another JWT package.
- Current role model is enforced in code:
  - student and teacher have separate signup endpoints
  - teacher CRUD is under `/api/teacher/lessons`
  - student submissions are under `/api/submissions`

## Domain Model Gotchas
- `Lesson` is the feed item for the MVP, not a course/module container.
- Each `Lesson` has exactly one `Exercise` (`OneToOneField`), by design.
- `Submission` is created with `pending` status and no scoring; that shape is intentional for later async/AI processing.
- `Lesson.slug` is auto-generated on first save. If you change title/slug behavior, check feed/detail endpoints and tests.

## Verification Expectations
- There is no repo-level lint/typecheck/CI config checked in right now. Do not invent `make`, `npm`, `pytest`, or pre-commit commands that are not present.
- After backend changes, the minimum meaningful verification in this repo is:
  1. `./venv/bin/python manage.py check`
  2. `./venv/bin/python manage.py test`
