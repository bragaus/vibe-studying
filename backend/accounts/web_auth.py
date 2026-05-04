import hashlib
import json
import secrets
from urllib import parse, request
from urllib.error import HTTPError, URLError

from django.conf import settings
from django.core.cache import cache
from ninja.errors import HttpError

from accounts.models import User


def get_client_ip(request_obj) -> str:
    forwarded_for = request_obj.headers.get("X-Forwarded-For", "")
    if forwarded_for:
        return forwarded_for.split(",", 1)[0].strip() or "unknown"
    return request_obj.META.get("REMOTE_ADDR", "unknown") or "unknown"


def _post_form_json(url: str, payload: dict[str, str], *, timeout_seconds: int, headers: dict[str, str] | None = None) -> dict:
    encoded_payload = parse.urlencode(payload).encode("utf-8")
    http_request = request.Request(
        url,
        data=encoded_payload,
        headers={"Content-Type": "application/x-www-form-urlencoded", **(headers or {})},
        method="POST",
    )

    try:
        with request.urlopen(http_request, timeout=timeout_seconds) as response:
            body = response.read().decode("utf-8")
    except HTTPError as exc:
        body = exc.read().decode("utf-8", errors="ignore")
        raise HttpError(502, f"External auth provider returned an error: {body[:200] or exc.reason}") from exc
    except URLError as exc:
        raise HttpError(502, "External auth provider is unavailable right now.") from exc

    try:
        return json.loads(body)
    except json.JSONDecodeError as exc:
        raise HttpError(502, "External auth provider returned an invalid response.") from exc


def _rate_limit_key(scope: str, identifier: str) -> str:
    digest = hashlib.sha256(identifier.encode("utf-8")).hexdigest()
    return f"rate-limit:{scope}:{digest}"


def enforce_rate_limit(*, scope: str, identifier: str, limit: int, window_seconds: int, detail: str) -> None:
    cache_key = _rate_limit_key(scope, identifier)
    if cache.add(cache_key, 1, timeout=window_seconds):
        return

    current_value = cache.incr(cache_key)
    if current_value == 2:
        cache.touch(cache_key, timeout=window_seconds)

    if current_value > limit:
        raise HttpError(429, detail)


def verify_turnstile(request_obj, turnstile_token: str) -> None:
    if not settings.TURNSTILE_ENABLED:
        return

    if not settings.TURNSTILE_SECRET_KEY:
        raise HttpError(503, "Turnstile is not configured on this environment.")

    if not turnstile_token.strip():
        raise HttpError(400, "Turnstile validation is required.")

    payload = _post_form_json(
        "https://challenges.cloudflare.com/turnstile/v0/siteverify",
        {
            "secret": settings.TURNSTILE_SECRET_KEY,
            "response": turnstile_token,
            "remoteip": get_client_ip(request_obj),
        },
        timeout_seconds=settings.TURNSTILE_VERIFY_TIMEOUT_SECONDS,
    )

    if not payload.get("success"):
        raise HttpError(400, "Turnstile validation failed. Please try again.")


def _social_login_session_key(session_token: str) -> str:
    return f"social-auth:session:{session_token}"


def create_social_login_session(user, *, source: str) -> str:
    session_token = secrets.token_urlsafe(32)
    cache.set(
        _social_login_session_key(session_token),
        {"user_id": user.id, "source": source},
        timeout=settings.WEB_AUTH_SESSION_TTL_SECONDS,
    )
    return session_token


def consume_social_login_session(session_token: str):
    normalized_session_token = session_token.strip()
    if not normalized_session_token:
        raise HttpError(400, "Session token is required.")

    cache_key = _social_login_session_key(normalized_session_token)
    session_payload = cache.get(cache_key)
    cache.delete(cache_key)
    if not session_payload:
        raise HttpError(404, "This authentication session has expired. Please start again.")

    user = User.objects.filter(pk=session_payload.get("user_id"), is_active=True).first()
    if user is None:
        raise HttpError(401, "The user for this authentication session is no longer available.")

    return user
