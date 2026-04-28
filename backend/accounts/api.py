"""Routers do contexto de autenticacao e contas.

No Django Ninja, cada router agrupa endpoints relacionados.
Isso deixa o codigo mais facil de navegar e apresentar.
"""

from django.contrib.auth import authenticate, get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.core.validators import validate_email
from django.db import transaction
from ninja import Router, Schema
from ninja.errors import HttpError

from accounts.jwt import JWTError, create_token_pair, decode_jwt, jwt_auth


router = Router()
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


def validate_identity_payload(email: str, password: str) -> None:
    # Reaproveitamos as validacoes nativas do Django em vez de duplicar regra.
    try:
        validate_email(email)
        validate_password(password)
    except ValidationError as exc:
        raise HttpError(400, exc.messages[0]) from exc


def create_account(payload: RegisterInput, role: str):
    with transaction.atomic():
        # atomic garante que nada fique salvo pela metade se algo falhar.
        return User.objects.create_user(
            email=payload.email,
            password=payload.password,
            first_name=payload.first_name,
            last_name=payload.last_name,
            role=role,
        )


@router.post("/register", response={201: AuthResponseSchema})
def register_student(request, payload: RegisterInput):
    # Cadastro publico do MVP: apenas aluno entra por aqui.
    validate_identity_payload(payload.email, payload.password)

    if User.objects.filter(email__iexact=payload.email).exists():
        raise HttpError(409, "An account with this e-mail already exists.")

    user = create_account(payload, User.Role.STUDENT)

    return 201, build_auth_response(user)


@router.post("/register/teacher", response={201: AuthResponseSchema})
def register_teacher(request, payload: RegisterInput):
    # Professores agora entram pelo app com um fluxo proprio, sem Telegram.
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
