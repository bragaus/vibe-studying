"""
Este é o caderno de configurações secretas do laboratório. Ele define:

> Qual banco de dados usar (PostgreSQL).
> Quais "módulos" estão instalados (accounts, learning, etc.).
> Quanto tempo duram os tokens JWT.
> Quais origens externas podem chamar a API (CORS).

Obs: O frontend nunca toca neste arquivo.
"""

import os
from pathlib import Path

from celery.schedules import crontab
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR / ".env")

def env_bool(name: str, default: bool = False) -> bool:
    """Converte uma variavel de ambiente para bool."""
    value = os.getenv(name)
    if value is None:
        return default
    return value.lower() in {"1", "true", "yes", "on"}


def env_list(name: str, default: str = "") -> list[str]:
    """Converte uma lista separada por virgula em lista Python."""
    raw_value = os.getenv(name, default)
    return [item.strip() for item in raw_value.split(",") if item.strip()]


SECRET_KEY = os.getenv("SECRET_KEY", "django-insecure-dev-vibe-studying-secret-key")
DEBUG = env_bool("DEBUG", default=False)

PUBLIC_API_HOST = "backendvibestudying.planoartistico.com"
PUBLIC_API_ORIGIN = f"https://{PUBLIC_API_HOST}"
LOCAL_DEV_HOSTS = ["localhost", "127.0.0.1", "testserver"]
ALLOWED_HOSTS = env_list(
    "ALLOWED_HOSTS",
    ",".join([PUBLIC_API_HOST, *LOCAL_DEV_HOSTS]),
)


INSTALLED_APPS = [
    # Apps nativos do Django para admin, auth, sessoes e arquivos estaticos.
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    # Permite chamadas do frontend em outra origem durante o desenvolvimento.
    'corsheaders',
    # Django Ninja e a camada de API tipada deste projeto.
    'ninja',
    # Apps de dominio do projeto.
    'accounts',
    'learning',
    'operations',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'config.middleware.RequestIdMiddleware',
    # CORS precisa entrar cedo para adicionar os headers corretos na resposta.
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'config.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'config.wsgi.application'
ASGI_APPLICATION = 'config.asgi.application'


DATABASES = {
    'default': {
        # Para o MVP estamos usando PostgreSQL como banco principal.
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('DATABASE_NAME', 'vibe_studying'),
        'USER': os.getenv('DATABASE_USER', 'bragaus'),
        'PASSWORD': os.getenv('DATABASE_PASSWORD', ''),
        'HOST': os.getenv('DATABASE_HOST', '/var/run/postgresql'),
        'PORT': os.getenv('DATABASE_PORT', '5432'),
    }
}


AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]


LANGUAGE_CODE = 'pt-br'

TIME_ZONE = 'America/Sao_Paulo'

USE_I18N = True

USE_TZ = True


STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'
# Diz ao Django que o projeto usa um User customizado em vez do auth.User padrao.
AUTH_USER_MODEL = 'accounts.User'

LOCAL_DEV_ORIGINS = [
    'http://localhost:3000',
    'http://127.0.0.1:3000',
    'http://localhost:8080',
    'http://127.0.0.1:8080',
]
DEFAULT_CSRF_TRUSTED_ORIGINS = [PUBLIC_API_ORIGIN, *LOCAL_DEV_ORIGINS]

# O backend precisa aceitar qualquer origem para o frontend publicado e futuros clientes.
CORS_ALLOW_ALL_ORIGINS = env_bool('CORS_ALLOW_ALL_ORIGINS', default=True)

CORS_ALLOWED_ORIGINS = env_list(
    'CORS_ALLOWED_ORIGINS',
    ','.join(LOCAL_DEV_ORIGINS),
)
CSRF_TRUSTED_ORIGINS = env_list(
    'CSRF_TRUSTED_ORIGINS',
    ','.join(DEFAULT_CSRF_TRUSTED_ORIGINS),
)

if DEBUG and not CORS_ALLOW_ALL_ORIGINS:
    for origin in LOCAL_DEV_ORIGINS:
        if origin not in CORS_ALLOWED_ORIGINS:
            CORS_ALLOWED_ORIGINS.append(origin)
        if origin not in CSRF_TRUSTED_ORIGINS:
            CSRF_TRUSTED_ORIGINS.append(origin)

SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO', 'https')
USE_X_FORWARDED_HOST = env_bool('USE_X_FORWARDED_HOST', default=True)

PUBLIC_WEB_URL = os.getenv('PUBLIC_WEB_URL', 'https://vibestudying.app')
RUNTIME_ENVIRONMENT = os.getenv('RUNTIME_ENVIRONMENT', 'development' if DEBUG else 'production')

JWT_ALGORITHM = 'HS256'
# O JWT usa uma chave dedicada, mas cai na SECRET_KEY se nao houver outra definida.
JWT_SECRET_KEY = os.getenv('JWT_SECRET_KEY', SECRET_KEY)
JWT_ACCESS_TOKEN_LIFETIME_MINUTES = int(os.getenv('JWT_ACCESS_TOKEN_LIFETIME_MINUTES', '60'))
JWT_REFRESH_TOKEN_LIFETIME_DAYS = int(os.getenv('JWT_REFRESH_TOKEN_LIFETIME_DAYS', '7'))

# O cadastro publico de professor fica habilitado no ambiente de desenvolvimento,
# mas deve ser fechado explicitamente fora dele.
ENABLE_PUBLIC_TEACHER_SIGNUP = env_bool('ENABLE_PUBLIC_TEACHER_SIGNUP', default=DEBUG)

EMAIL_BACKEND = os.getenv('EMAIL_BACKEND', 'django.core.mail.backends.console.EmailBackend')
DEFAULT_FROM_EMAIL = os.getenv('DEFAULT_FROM_EMAIL', 'noreply@vibestudying.local')
SERVER_EMAIL = os.getenv('SERVER_EMAIL', DEFAULT_FROM_EMAIL)
EMAIL_TIMEOUT = int(os.getenv('EMAIL_TIMEOUT', '10'))
EMAIL_HOST = os.getenv('EMAIL_HOST', 'localhost')
EMAIL_PORT = int(os.getenv('EMAIL_PORT', '587'))
EMAIL_HOST_USER = os.getenv('EMAIL_HOST_USER', '')
EMAIL_HOST_PASSWORD = os.getenv('EMAIL_HOST_PASSWORD', '')
EMAIL_USE_TLS = env_bool('EMAIL_USE_TLS', default=True)
EMAIL_USE_SSL = env_bool('EMAIL_USE_SSL', default=False)

REDIS_URL = os.getenv('REDIS_URL', '')
CACHE_URL = os.getenv('CACHE_URL', REDIS_URL)
CACHE_DEFAULT_TIMEOUT_SECONDS = int(os.getenv('CACHE_DEFAULT_TIMEOUT_SECONDS', '300'))
PUBLIC_FEED_CACHE_TIMEOUT_SECONDS = int(os.getenv('PUBLIC_FEED_CACHE_TIMEOUT_SECONDS', '300'))
LESSON_DETAIL_CACHE_TIMEOUT_SECONDS = int(os.getenv('LESSON_DETAIL_CACHE_TIMEOUT_SECONDS', '600'))

if CACHE_URL.startswith(('redis://', 'rediss://')):
    CACHES = {
        'default': {
            'BACKEND': 'django.core.cache.backends.redis.RedisCache',
            'LOCATION': CACHE_URL,
            'TIMEOUT': CACHE_DEFAULT_TIMEOUT_SECONDS,
        }
    }
else:
    CACHES = {
        'default': {
            'BACKEND': 'django.core.cache.backends.locmem.LocMemCache',
            'LOCATION': 'vibe-studying-cache',
            'TIMEOUT': CACHE_DEFAULT_TIMEOUT_SECONDS,
        }
    }

CELERY_BROKER_URL = os.getenv('CELERY_BROKER_URL', REDIS_URL or 'memory://')
CELERY_RESULT_BACKEND = os.getenv('CELERY_RESULT_BACKEND', REDIS_URL or 'cache+memory://')
CELERY_TASK_DEFAULT_QUEUE = os.getenv('CELERY_TASK_DEFAULT_QUEUE', 'default')
CELERY_TIMEZONE = TIME_ZONE
CELERY_TASK_ALWAYS_EAGER = env_bool('CELERY_TASK_ALWAYS_EAGER', default=False)
CELERY_TASK_EAGER_PROPAGATES = env_bool('CELERY_TASK_EAGER_PROPAGATES', default=False)
CELERY_BEAT_SCHEDULE = {
    'dispatch-due-email-deliveries-every-minute': {
        'task': 'operations.tasks.dispatch_due_email_deliveries_task',
        'schedule': crontab(),
    },
    'schedule-inactivity-reminders-hourly': {
        'task': 'operations.tasks.schedule_inactivity_reminders_task',
        'schedule': crontab(minute=0),
    },
    'run-operational-checks-every-15-minutes': {
        'task': 'operations.tasks.run_operational_checks_task',
        'schedule': crontab(minute='*/15'),
    },
}

REMINDER_INACTIVITY_HOURS = int(os.getenv('REMINDER_INACTIVITY_HOURS', '24'))
ALERT_EMAIL_RECIPIENTS = env_list('ALERT_EMAIL_RECIPIENTS', '')
OPERATIONS_ALERTS_ENABLED = env_bool('OPERATIONS_ALERTS_ENABLED', default=True)
OPERATIONS_PENDING_EMAIL_MINUTES = int(os.getenv('OPERATIONS_PENDING_EMAIL_MINUTES', '15'))
OPERATIONS_PENDING_EMAIL_THRESHOLD = int(os.getenv('OPERATIONS_PENDING_EMAIL_THRESHOLD', '10'))
OPERATIONS_FAILED_EMAIL_THRESHOLD = int(os.getenv('OPERATIONS_FAILED_EMAIL_THRESHOLD', '3'))
OPERATIONS_PENDING_SUBMISSION_HOURS = int(os.getenv('OPERATIONS_PENDING_SUBMISSION_HOURS', '6'))
OPERATIONS_PENDING_SUBMISSION_THRESHOLD = int(os.getenv('OPERATIONS_PENDING_SUBMISSION_THRESHOLD', '10'))

LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'standard': {
            'format': '%(asctime)s %(levelname)s [%(name)s] [request_id=%(request_id)s] %(message)s',
        },
    },
    'filters': {
        'request_id': {
            '()': 'config.middleware.RequestIdLogFilter',
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'standard',
            'filters': ['request_id'],
        },
    },
    'root': {
        'handlers': ['console'],
        'level': os.getenv('LOG_LEVEL', 'INFO'),
    },
    'loggers': {
        'django.request': {
            'handlers': ['console'],
            'level': os.getenv('DJANGO_REQUEST_LOG_LEVEL', 'WARNING'),
            'propagate': False,
        },
        'accounts': {
            'handlers': ['console'],
            'level': os.getenv('APP_LOG_LEVEL', 'INFO'),
            'propagate': False,
        },
        'learning': {
            'handlers': ['console'],
            'level': os.getenv('APP_LOG_LEVEL', 'INFO'),
            'propagate': False,
        },
        'operations': {
            'handlers': ['console'],
            'level': os.getenv('APP_LOG_LEVEL', 'INFO'),
            'propagate': False,
        },
    },
}
