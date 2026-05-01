"""Routers do contexto de autenticacao e contas.

No Django Ninja, cada router agrupa endpoints relacionados.
Isso deixa o codigo mais facil de navegar e apresentar.
"""

from django.conf import settings
from django.contrib.auth import authenticate, get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.core.validators import validate_email
from django.db import transaction
from ninja import Router, Schema
from ninja.errors import HttpError

from accounts.jwt import JWTError, create_token_pair, decode_jwt, jwt_auth
from accounts.models import StudentProfile, WaitlistSignup
from accounts.permissions import require_role
from operations.emailing import queue_student_welcome_email, queue_waitlist_welcome_email


router = Router()
profile_router = Router()
marketing_router = Router()
User = get_user_model()


class UserSchema(Schema):
    # Schemas descrevem entrada e saida da API.
    # O Ninja usa isso para validar payloads e gerar documentacao automaticamente.
    id: int
    email: str
    first_name: str
    last_name: str
    role: str


class AuthResponseSchema(Schema):
    access_token: str
    refresh_token: str
    token_type: str
    user: UserSchema


class StudentProfileSchema(Schema):
    onboarding_completed: bool
    english_level: str
    favorite_songs: list[str]
    favorite_movies: list[str]
    favorite_series: list[str]
    favorite_anime: list[str]
    favorite_artists: list[str]
    favorite_genres: list[str]


class ProfileResponseSchema(Schema):
    user: UserSchema
    profile: StudentProfileSchema


class RegisterInput(Schema):
    email: str
    password: str
    first_name: str = ""
    last_name: str = ""


class LoginInput(Schema):
    email: str
    password: str


class RefreshInput(Schema):
    refresh_token: str


class ProfileUpdateInput(Schema):
    english_level: str | None = None
    favorite_songs: list[str] | None = None
    favorite_movies: list[str] | None = None
    favorite_series: list[str] | None = None
    favorite_anime: list[str] | None = None
    favorite_artists: list[str] | None = None
    favorite_genres: list[str] | None = None


class WaitlistInput(Schema):
    email: str
    source: str = "landing_page"


class WaitlistResponseSchema(Schema):
    email: str
    source: str
    already_registered: bool


def serialize_user(user) -> UserSchema:
    # Converte o model Django em um objeto pronto para resposta JSON.
    return UserSchema(
        id=user.id,
        email=user.email,
        first_name=user.first_name,
        last_name=user.last_name,
        role=user.role,
    )


def build_auth_response(user) -> AuthResponseSchema:
    # Toda resposta de autenticacao devolve tokens + dados resumidos do usuario.
    token_pair = create_token_pair(user)
    return AuthResponseSchema(user=serialize_user(user), **token_pair)


def normalize_list(values: list[str] | None) -> list[str]:
    if not values:
        return []

    unique_values: list[str] = []
    seen: set[str] = set()
    for raw_value in values:
        clean_value = raw_value.strip()
        if not clean_value:
            continue

        lowered = clean_value.lower()
        if lowered in seen:
            continue

        seen.add(lowered)
        unique_values.append(clean_value)

    return unique_values


def get_or_create_student_profile(user) -> StudentProfile:
    profile, _ = StudentProfile.objects.get_or_create(user=user)
    return profile


def serialize_profile(profile: StudentProfile) -> StudentProfileSchema:
    return StudentProfileSchema(
        onboarding_completed=profile.onboarding_completed,
        english_level=profile.english_level,
        favorite_songs=profile.favorite_songs,
        favorite_movies=profile.favorite_movies,
        favorite_series=profile.favorite_series,
        favorite_anime=profile.favorite_anime,
        favorite_artists=profile.favorite_artists,
        favorite_genres=profile.favorite_genres,
    )


def build_profile_response(user) -> ProfileResponseSchema:
    profile = get_or_create_student_profile(user)
    return ProfileResponseSchema(user=serialize_user(user), profile=serialize_profile(profile))


def update_student_profile(profile: StudentProfile, payload: ProfileUpdateInput, complete_onboarding: bool = False) -> StudentProfile:
    changes = payload.model_dump(exclude_unset=True)

    list_fields = {
        "favorite_songs",
        "favorite_movies",
        "favorite_series",
        "favorite_anime",
        "favorite_artists",
        "favorite_genres",
    }

    for field, value in changes.items():
        if value is None:
            continue

        if field in list_fields:
            setattr(profile, field, normalize_list(value))
            continue

        setattr(profile, field, value)

    if complete_onboarding:
        profile.onboarding_completed = True

    profile.save()
    return profile


def validate_identity_payload(email: str, password: str) -> None:
    # Reaproveitamos as validacoes nativas do Django em vez de duplicar regra.
    try:
        validate_email(email)
        validate_password(password)
    except ValidationError as exc:
        raise HttpError(400, exc.messages[0]) from exc


def validate_email_payload(email: str) -> str:
    try:
        validate_email(email)
    except ValidationError as exc:
        raise HttpError(400, exc.messages[0]) from exc
    return email.strip().lower()


def create_account(payload: RegisterInput, role: str):
    with transaction.atomic():
        # atomic garante que nada fique salvo pela metade se algo falhar.
        user = User.objects.create_user(
            email=payload.email,
            password=payload.password,
            first_name=payload.first_name,
            last_name=payload.last_name,
            role=role,
        )
        if role == User.Role.STUDENT:
            StudentProfile.objects.get_or_create(user=user)
        return user


@router.post("/register", response={201: AuthResponseSchema})
def register_student(request, payload: RegisterInput):
    # Cadastro publico do MVP: apenas aluno entra por aqui.
    validate_identity_payload(payload.email, payload.password)

    if User.objects.filter(email__iexact=payload.email).exists():
        raise HttpError(409, "An account with this e-mail already exists.")

    user = create_account(payload, User.Role.STUDENT)
    queue_student_welcome_email(user)

    return 201, build_auth_response(user)


@router.post("/register/teacher", response={201: AuthResponseSchema})
def register_teacher(request, payload: RegisterInput):
    # Professores agora entram pelo app com um fluxo proprio, sem Telegram.
    if not settings.ENABLE_PUBLIC_TEACHER_SIGNUP:
        raise HttpError(403, "Public teacher signup is disabled in this environment.")

    validate_identity_payload(payload.email, payload.password)

    if User.objects.filter(email__iexact=payload.email).exists():
        raise HttpError(409, "An account with this e-mail already exists.")

    user = create_account(payload, User.Role.TEACHER)

    return 201, build_auth_response(user)


@router.post("/login", response=AuthResponseSchema)
def login(request, payload: LoginInput):
    # authenticate usa o backend de auth do Django e compara a senha com hash.
    user = authenticate(request, username=payload.email, password=payload.password)
    if user is None:
        raise HttpError(401, "Invalid e-mail or password.")

    return build_auth_response(user)


@router.post("/refresh", response=AuthResponseSchema)
def refresh_token(request, payload: RefreshInput):
    # O refresh token nao acessa recurso de negocio; ele so gera uma nova sessao curta.
    try:
        decoded = decode_jwt(payload.refresh_token, expected_type="refresh")
    except JWTError as exc:
        raise HttpError(401, str(exc)) from exc

    try:
        user = User.objects.get(pk=decoded["sub"], is_active=True)
    except User.DoesNotExist as exc:
        raise HttpError(401, "User not found for this token.") from exc

    return build_auth_response(user)


@router.get("/me", auth=jwt_auth, response=UserSchema)
def me(request):
    # request.auth foi preenchido pelo JWTAuth com o usuario autenticado.
    return serialize_user(request.auth)


@profile_router.get("/me", auth=jwt_auth, response=ProfileResponseSchema)
def profile_me(request):
    require_role(request.auth, request.auth.Role.STUDENT)
    return build_profile_response(request.auth)


@profile_router.put("/me", auth=jwt_auth, response=ProfileResponseSchema)
def update_profile(request, payload: ProfileUpdateInput):
    require_role(request.auth, request.auth.Role.STUDENT)
    profile = get_or_create_student_profile(request.auth)
    update_student_profile(profile, payload)
    return build_profile_response(request.auth)


@profile_router.post("/onboarding", auth=jwt_auth, response=ProfileResponseSchema)
def complete_onboarding(request, payload: ProfileUpdateInput):
    require_role(request.auth, request.auth.Role.STUDENT)
    profile = get_or_create_student_profile(request.auth)
    update_student_profile(profile, payload, complete_onboarding=True)
    return build_profile_response(request.auth)


@marketing_router.post("/waitlist", response={200: WaitlistResponseSchema, 201: WaitlistResponseSchema})
def join_waitlist(request, payload: WaitlistInput):
    normalized_email = validate_email_payload(payload.email)
    source = payload.source.strip() or "landing_page"

    signup, created = WaitlistSignup.objects.get_or_create(
        email=normalized_email,
        defaults={"source": source},
    )
    if not created and signup.source != source:
        signup.source = source
        signup.save(update_fields=["source"])
    elif created:
        queue_waitlist_welcome_email(signup)

    response = WaitlistResponseSchema(
        email=signup.email,
        source=signup.source,
        already_registered=not created,
    )
    return (201 if created else 200), response
