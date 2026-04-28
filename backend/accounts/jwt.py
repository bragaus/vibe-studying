"""Implementacao enxuta de JWT para o MVP.

Em vez de depender de outra biblioteca agora, este modulo faz o suficiente para:
- gerar access e refresh token
- validar assinatura e expiracao
- autenticar requests do Django Ninja
"""

import base64
import hashlib
import hmac
import json
from datetime import datetime, timedelta, timezone

from django.conf import settings
from django.contrib.auth import get_user_model
from ninja.security import HttpBearer


class JWTError(Exception):
    """Erro usado quando um token e invalido, expirou ou foi adulterado."""

    pass


def _b64encode(data: bytes) -> str:
    # JWT usa base64 url-safe sem padding.
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _b64decode(data: str) -> bytes:
    # Recoloca o padding removido antes de decodificar.
    padding = "=" * (-len(data) % 4)
    return base64.urlsafe_b64decode(f"{data}{padding}")


def _sign(message: bytes) -> str:
    # Assina o header.payload usando HMAC SHA256.
    digest = hmac.new(
        settings.JWT_SECRET_KEY.encode("utf-8"),
        message,
        hashlib.sha256,
    ).digest()
    return _b64encode(digest)


def _build_payload(user, token_type: str, expires_delta: timedelta) -> dict:
    # O payload carrega o minimo necessario para identificar o usuario e o papel.
    now = datetime.now(timezone.utc)
    return {
        "sub": str(user.pk),
        "email": user.email,
        "role": user.role,
        "type": token_type,
        "iat": int(now.timestamp()),
        "exp": int((now + expires_delta).timestamp()),
    }


def encode_jwt(payload: dict) -> str:
    # Monta manualmente o token no formato header.payload.signature.
    header = {"alg": settings.JWT_ALGORITHM, "typ": "JWT"}
    encoded_header = _b64encode(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    encoded_payload = _b64encode(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signature = _sign(f"{encoded_header}.{encoded_payload}".encode("utf-8"))
    return f"{encoded_header}.{encoded_payload}.{signature}"


def decode_jwt(token: str, expected_type: str | None = None) -> dict:
    # Primeiro quebra o token em 3 partes.
    try:
        encoded_header, encoded_payload, signature = token.split(".")
    except ValueError as exc:
        raise JWTError("Invalid token format.") from exc

    # Depois valida se a assinatura bate com o conteudo recebido.
    message = f"{encoded_header}.{encoded_payload}".encode("utf-8")
    expected_signature = _sign(message)
    if not hmac.compare_digest(signature, expected_signature):
        raise JWTError("Invalid token signature.")

    # Se a estrutura estiver corrompida ou adulterada, a decodificacao falha aqui.
    try:
        header = json.loads(_b64decode(encoded_header))
        payload = json.loads(_b64decode(encoded_payload))
    except (json.JSONDecodeError, ValueError) as exc:
        raise JWTError("Invalid token payload.") from exc

    if header.get("alg") != settings.JWT_ALGORITHM:
        raise JWTError("Invalid token algorithm.")

    # Tambem garantimos que o token ainda esta dentro da validade.
    exp = payload.get("exp")
    if exp is None or int(exp) < int(datetime.now(timezone.utc).timestamp()):
        raise JWTError("Token has expired.")

    if expected_type and payload.get("type") != expected_type:
        raise JWTError("Invalid token type.")

    return payload


def create_token_pair(user) -> dict:
    # O frontend usa o access token nas requests e o refresh para renovar sessao.
    access_payload = _build_payload(
        user,
        token_type="access",
        expires_delta=timedelta(minutes=settings.JWT_ACCESS_TOKEN_LIFETIME_MINUTES),
    )
    refresh_payload = _build_payload(
        user,
        token_type="refresh",
        expires_delta=timedelta(days=settings.JWT_REFRESH_TOKEN_LIFETIME_DAYS),
    )
    return {
        "access_token": encode_jwt(access_payload),
        "refresh_token": encode_jwt(refresh_payload),
        "token_type": "bearer",
    }


class JWTAuth(HttpBearer):
    """Autenticacao Bearer para as rotas protegidas do Ninja."""

    def authenticate(self, request, token):
        try:
            payload = decode_jwt(token, expected_type="access")
        except JWTError:
            return None

        # request.auth passa a ser o proprio usuario Django autenticado.
        user_model = get_user_model()
        try:
            return user_model.objects.get(pk=payload["sub"], is_active=True)
        except user_model.DoesNotExist:
            return None


jwt_auth = JWTAuth()
