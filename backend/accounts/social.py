import json
import secrets
from urllib import parse, request
from urllib.error import HTTPError, URLError

from django.conf import settings
from django.core.cache import cache
from ninja.errors import HttpError

from accounts.models import SocialAccount, StudentProfile, User


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
        raise HttpError(502, f"Social login provider returned an error: {body[:200] or exc.reason}") from exc
    except URLError as exc:
        raise HttpError(502, "Social login provider is unavailable right now.") from exc

    try:
        return json.loads(body)
    except json.JSONDecodeError as exc:
        raise HttpError(502, "Social login provider returned an invalid response.") from exc


def _get_json(url: str, *, timeout_seconds: int, headers: dict[str, str] | None = None) -> dict | list:
    http_request = request.Request(url, headers=headers or {}, method="GET")

    try:
        with request.urlopen(http_request, timeout=timeout_seconds) as response:
            body = response.read().decode("utf-8")
    except HTTPError as exc:
        body = exc.read().decode("utf-8", errors="ignore")
        raise HttpError(502, f"Social login provider returned an error: {body[:200] or exc.reason}") from exc
    except URLError as exc:
        raise HttpError(502, "Social login provider is unavailable right now.") from exc

    try:
        return json.loads(body)
    except json.JSONDecodeError as exc:
        raise HttpError(502, "Social login provider returned an invalid response.") from exc


def _social_state_key(state: str) -> str:
    return f"social-oauth:state:{state}"


def create_social_state(provider: str) -> str:
    state = secrets.token_urlsafe(32)
    cache.set(_social_state_key(state), {"provider": provider}, timeout=settings.SOCIAL_OAUTH_STATE_TTL_SECONDS)
    return state


def consume_social_state(provider: str, state: str) -> None:
    if not state.strip():
        raise HttpError(400, "Missing OAuth state.")

    cache_key = _social_state_key(state)
    state_payload = cache.get(cache_key)
    cache.delete(cache_key)
    if not state_payload or state_payload.get("provider") != provider:
        raise HttpError(400, "Invalid or expired OAuth state.")


def get_social_provider_config(provider: str) -> dict[str, str]:
    if provider != SocialAccount.Provider.GOOGLE:
        raise HttpError(400, "Unsupported social login provider.")

    return {
        "client_id": settings.GOOGLE_OAUTH_CLIENT_ID,
        "client_secret": settings.GOOGLE_OAUTH_CLIENT_SECRET,
        "redirect_uri": settings.GOOGLE_OAUTH_REDIRECT_URI,
    }


def build_social_authorization_url(provider: str, state: str) -> str:
    if provider != SocialAccount.Provider.GOOGLE:
        raise HttpError(400, "Unsupported social login provider.")

    config = get_social_provider_config(provider)
    if not config["client_id"] or not config["client_secret"] or not config["redirect_uri"]:
        raise HttpError(503, f"{provider.capitalize()} login is not configured on this environment.")

    return "https://accounts.google.com/o/oauth2/v2/auth?" + parse.urlencode(
        {
            "client_id": config["client_id"],
            "redirect_uri": config["redirect_uri"],
            "response_type": "code",
            "scope": "openid email profile",
            "state": state,
            "prompt": "select_account",
        }
    )


def _fetch_google_identity(code: str) -> dict:
    config = get_social_provider_config(SocialAccount.Provider.GOOGLE)
    token_payload = _post_form_json(
        "https://oauth2.googleapis.com/token",
        {
            "code": code,
            "client_id": config["client_id"],
            "client_secret": config["client_secret"],
            "redirect_uri": config["redirect_uri"],
            "grant_type": "authorization_code",
        },
        timeout_seconds=settings.SOCIAL_OAUTH_TIMEOUT_SECONDS,
    )
    access_token = token_payload.get("access_token", "")
    if not access_token:
        raise HttpError(502, "Google login did not return an access token.")

    profile_payload = _get_json(
        "https://openidconnect.googleapis.com/v1/userinfo",
        timeout_seconds=settings.SOCIAL_OAUTH_TIMEOUT_SECONDS,
        headers={"Authorization": f"Bearer {access_token}"},
    )
    if not isinstance(profile_payload, dict):
        raise HttpError(502, "Google login returned an unexpected user payload.")

    return {
        "provider": SocialAccount.Provider.GOOGLE,
        "provider_user_id": str(profile_payload.get("sub", "")).strip(),
        "email": str(profile_payload.get("email", "")).strip().lower(),
        "email_verified": bool(profile_payload.get("email_verified")),
        "first_name": str(profile_payload.get("given_name", "")).strip(),
        "last_name": str(profile_payload.get("family_name", "")).strip(),
        "avatar_url": str(profile_payload.get("picture", "")).strip(),
    }


def fetch_social_identity(provider: str, code: str) -> dict:
    if provider != SocialAccount.Provider.GOOGLE:
        raise HttpError(400, "Unsupported social login provider.")
    if not code.strip():
        raise HttpError(400, "Missing OAuth authorization code.")

    identity = _fetch_google_identity(code)
    if not identity["provider_user_id"]:
        raise HttpError(502, f"{provider.capitalize()} login did not return a stable user identifier.")
    if not identity["email"]:
        raise HttpError(400, f"{provider.capitalize()} login did not return an e-mail address.")
    if not identity["email_verified"]:
        raise HttpError(400, f"{provider.capitalize()} login requires a verified e-mail address.")
    return identity


def resolve_social_user(provider: str, identity: dict):
    social_account = (
        SocialAccount.objects.select_related("user")
        .filter(provider=provider, provider_user_id=identity["provider_user_id"])
        .first()
    )
    if social_account is not None:
        if not social_account.user.is_active:
            raise HttpError(403, "This account is inactive.")
        social_account.email = identity["email"]
        social_account.avatar_url = identity.get("avatar_url", "")
        social_account.save(update_fields=["email", "avatar_url", "updated_at"])
        return social_account.user

    user = User.objects.filter(email__iexact=identity["email"]).first()
    if user is not None and not user.is_active:
        raise HttpError(403, "This account is inactive.")

    if user is None:
        user = User.objects.create_user(
            email=identity["email"],
            password=secrets.token_urlsafe(32),
            first_name=identity.get("first_name", ""),
            last_name=identity.get("last_name", ""),
            role=User.Role.STUDENT,
        )
        StudentProfile.objects.get_or_create(user=user)
    else:
        fields_to_update: list[str] = []
        if not user.first_name and identity.get("first_name"):
            user.first_name = identity["first_name"]
            fields_to_update.append("first_name")
        if not user.last_name and identity.get("last_name"):
            user.last_name = identity["last_name"]
            fields_to_update.append("last_name")
        if fields_to_update:
            user.save(update_fields=[*fields_to_update, "updated_at"])

    existing_provider_link = SocialAccount.objects.filter(user=user, provider=provider).first()
    if existing_provider_link and existing_provider_link.provider_user_id != identity["provider_user_id"]:
        raise HttpError(409, f"This {provider.capitalize()} account is already linked to another identity.")

    SocialAccount.objects.update_or_create(
        user=user,
        provider=provider,
        defaults={
            "provider_user_id": identity["provider_user_id"],
            "email": identity["email"],
            "avatar_url": identity.get("avatar_url", ""),
        },
    )
    return user
