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
DEBUG = env_bool("DEBUG", default=True)

ALLOWED_HOSTS = env_list("ALLOWED_HOSTS", "localhost,127.0.0.1,testserver")


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
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
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

CORS_ALLOWED_ORIGINS = env_list(
    'CORS_ALLOWED_ORIGINS',
    'http://localhost:3000,http://127.0.0.1:3000',
)
CSRF_TRUSTED_ORIGINS = env_list(
    'CSRF_TRUSTED_ORIGINS',
    'http://localhost:3000,http://127.0.0.1:3000',
)

JWT_ALGORITHM = 'HS256'
# O JWT usa uma chave dedicada, mas cai na SECRET_KEY se nao houver outra definida.
JWT_SECRET_KEY = os.getenv('JWT_SECRET_KEY', SECRET_KEY)
JWT_ACCESS_TOKEN_LIFETIME_MINUTES = int(os.getenv('JWT_ACCESS_TOKEN_LIFETIME_MINUTES', '60'))
JWT_REFRESH_TOKEN_LIFETIME_DAYS = int(os.getenv('JWT_REFRESH_TOKEN_LIFETIME_DAYS', '7'))
