import logging
from urllib import parse

from django.conf import settings
from django.contrib.auth import authenticate
from django.http import HttpResponseRedirect
from ninja import Router, Schema
from ninja.errors import HttpError

from accounts.api import AuthResponseSchema, RegisterInput, build_auth_response, create_account, validate_identity_payload
from accounts.models import SocialAccount, User
from accounts.social import build_social_authorization_url, consume_social_state, create_social_state, fetch_social_identity, resolve_social_user
from accounts.web_auth import consume_social_login_session, create_social_login_session, enforce_rate_limit, get_client_ip, verify_turnstile
from operations.emailing import queue_student_welcome_email


logger = logging.getLogger(__name__)

web_auth_router = Router(tags=["Web Auth"])


class AuthorizationUrlSchema(Schema):
    authorization_url: str


class WebLoginInput(Schema):
    email: str
    password: str
    turnstile_token: str


class WebRegisterInput(Schema):
    email: str
    password: str
    first_name: str = ""
    last_name: str = ""
    turnstile_token: str


class TurnstileProtectedInput(Schema):
    turnstile_token: str


def _frontend_auth_redirect(*, session_token: str = "", auth_error: str = "") -> HttpResponseRedirect:
    base_url = f"{settings.PUBLIC_WEB_URL.rstrip('/')}/auth"
    query_params: dict[str, str] = {}
    if session_token:
        query_params["session"] = session_token
    if auth_error:
        query_params["auth_error"] = auth_error
    url = f"{base_url}?{parse.urlencode(query_params)}" if query_params else base_url
    return HttpResponseRedirect(url)


def _normalize_web_email(email: str) -> str:
    return email.strip().lower()


def _enforce_login_limits(request, email: str) -> None:
    client_ip = get_client_ip(request)
    enforce_rate_limit(
        scope="web-login-ip",
        identifier=client_ip,
        limit=settings.WEB_LOGIN_RATE_LIMIT_PER_MINUTE,
        window_seconds=60,
        detail="Too many login attempts from this IP. Please wait a minute.",
    )
    enforce_rate_limit(
        scope="web-login-email",
        identifier=email,
        limit=settings.WEB_LOGIN_RATE_LIMIT_PER_EMAIL_WINDOW,
        window_seconds=settings.WEB_LOGIN_EMAIL_WINDOW_SECONDS,
        detail="Too many login attempts for this e-mail. Please wait and try again.",
    )


def _enforce_register_limits(request, email: str) -> None:
    client_ip = get_client_ip(request)
    enforce_rate_limit(
        scope="web-register-ip",
        identifier=client_ip,
        limit=settings.WEB_REGISTER_RATE_LIMIT_PER_HOUR,
        window_seconds=3600,
        detail="Too many registration attempts from this IP. Please wait before trying again.",
    )
    enforce_rate_limit(
        scope="web-register-email",
        identifier=email,
        limit=settings.WEB_REGISTER_RATE_LIMIT_PER_EMAIL_DAY,
        window_seconds=86400,
        detail="Too many registration attempts for this e-mail. Please try again tomorrow.",
    )


def _enforce_social_start_limits(request, provider: str) -> None:
    client_ip = get_client_ip(request)
    enforce_rate_limit(
        scope=f"social-start-{provider}",
        identifier=client_ip,
        limit=settings.SOCIAL_START_RATE_LIMIT_PER_WINDOW,
        window_seconds=settings.SOCIAL_START_RATE_LIMIT_WINDOW_SECONDS,
        detail="Too many social login attempts from this IP. Please wait before trying again.",
    )


@web_auth_router.post("/web/login", response=AuthResponseSchema)
def web_login(request, payload: WebLoginInput):
    normalized_email = _normalize_web_email(payload.email)
    _enforce_login_limits(request, normalized_email)
    verify_turnstile(request, payload.turnstile_token)

    user = authenticate(request, username=normalized_email, password=payload.password)
    if user is None:
        raise HttpError(401, "Invalid e-mail or password.")

    return build_auth_response(request, user)


@web_auth_router.post("/web/register", response={201: AuthResponseSchema})
def web_register(request, payload: WebRegisterInput):
    normalized_email = _normalize_web_email(payload.email)
    _enforce_register_limits(request, normalized_email)
    verify_turnstile(request, payload.turnstile_token)
    validate_identity_payload(normalized_email, payload.password)

    if User.objects.filter(email__iexact=normalized_email).exists():
        raise HttpError(409, "An account with this e-mail already exists.")

    user = create_account(
        RegisterInput(
            email=normalized_email,
            password=payload.password,
            first_name=payload.first_name,
            last_name=payload.last_name,
        ),
        User.Role.STUDENT,
    )
    queue_student_welcome_email(user)
    return 201, build_auth_response(request, user)


@web_auth_router.get("/web/session", response=AuthResponseSchema)
def web_auth_session_status(request, session_token: str):
    user = consume_social_login_session(session_token)
    return build_auth_response(request, user)


def _start_social_login(request, provider: str, payload: TurnstileProtectedInput) -> AuthorizationUrlSchema:
    _enforce_social_start_limits(request, provider)
    verify_turnstile(request, payload.turnstile_token)
    state = create_social_state(provider)
    return AuthorizationUrlSchema(authorization_url=build_social_authorization_url(provider, state))


@web_auth_router.post("/social/google/start", response=AuthorizationUrlSchema)
def start_google_login(request, payload: TurnstileProtectedInput):
    return _start_social_login(request, SocialAccount.Provider.GOOGLE, payload)


def _handle_social_callback(*, provider: str, state: str, code: str, provider_error: str) -> HttpResponseRedirect:
    if provider_error:
        return _frontend_auth_redirect(auth_error="social_cancelled")

    try:
        consume_social_state(provider, state)
        identity = fetch_social_identity(provider, code)
        user = resolve_social_user(provider, identity)
        session_token = create_social_login_session(user, source=f"social_{provider}")
    except HttpError as exc:
        logger.warning(
            "social login failed",
            extra={"provider": provider, "detail": str(exc), "state_present": bool(state), "code_present": bool(code)},
        )
        return _frontend_auth_redirect(auth_error="social_failed")

    return _frontend_auth_redirect(session_token=session_token)


@web_auth_router.get("/social/google/callback")
def google_social_callback(request, state: str = "", code: str = "", error: str = ""):
    return _handle_social_callback(provider=SocialAccount.Provider.GOOGLE, state=state, code=code, provider_error=error)
