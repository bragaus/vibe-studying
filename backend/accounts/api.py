"""Routers do contexto de autenticacao e contas.

No Django Ninja, cada router agrupa endpoints relacionados.
Isso deixa o codigo mais facil de navegar e apresentar.
"""

import logging

from django.conf import settings
from django.contrib.auth import authenticate, get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.core.validators import validate_email
from django.db import transaction
from django.db.models import Count, Exists, OuterRef, Prefetch
from ninja import Router, Schema
from ninja.errors import HttpError

from accounts.jwt import JWTError, create_token_pair, decode_jwt, jwt_auth
from accounts.models import StudentPost, StudentPostComment, StudentPostEnergy, StudentProfile, WaitlistSignup
from accounts.permissions import require_role
from learning.tasks import enqueue_personalized_feed_bootstrap
from operations.emailing import queue_student_welcome_email, queue_waitlist_welcome_email


router = Router()
profile_router = Router()
marketing_router = Router()
User = get_user_model()
logger = logging.getLogger(__name__)


class UserSchema(Schema):
    # Schemas descrevem entrada e saida da API.
    # O Ninja usa isso para validar payloads e gerar documentacao automaticamente.
    id: int
    email: str
    first_name: str
    last_name: str
    role: str
    avatar_url: str = ""


class AuthResponseSchema(Schema):
    access_token: str
    refresh_token: str
    token_type: str
    user: UserSchema


class StudentProfileSchema(Schema):
    onboarding_completed: bool
    english_level: str
    bio: str = ""
    avatar_url: str = ""
    posts_count: int = 0
    energy_received_count: int = 0
    comments_received_count: int = 0
    favorite_songs: list[str]
    favorite_movies: list[str]
    favorite_series: list[str]
    favorite_anime: list[str]
    favorite_artists: list[str]
    favorite_genres: list[str]


class ProfileResponseSchema(Schema):
    user: UserSchema
    profile: StudentProfileSchema


class StudentIdentitySchema(Schema):
    id: int
    display_name: str
    role: str
    avatar_url: str = ""
    bio: str = ""


class StudentPostCommentSchema(Schema):
    id: int
    content: str
    created_at: str
    updated_at: str
    is_owner: bool
    author: StudentIdentitySchema


class StudentPostSchema(Schema):
    id: int
    content: str
    created_at: str
    updated_at: str
    is_owner: bool
    energy_count: int
    comment_count: int
    energized_by_me: bool
    author: StudentIdentitySchema
    comments: list[StudentPostCommentSchema]


class StudentPostInput(Schema):
    content: str


class StudentPostCommentInput(Schema):
    content: str


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
    bio: str | None = None
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


def normalize_text(value: str | None, *, max_length: int, fallback: str = "") -> str:
    clean_value = (value or fallback).strip()
    if len(clean_value) > max_length:
        raise HttpError(400, f"Text exceeds maximum length of {max_length} characters.")
    return clean_value


def build_file_url(request, file_field) -> str:
    if not file_field:
        return ""
    try:
        return request.build_absolute_uri(file_field.url)
    except ValueError:
        return ""


def serialize_student_identity(request, profile: StudentProfile) -> StudentIdentitySchema:
    return StudentIdentitySchema(
        id=profile.user_id,
        display_name=profile.user.get_full_name().strip() or profile.user.email,
        role=profile.user.role,
        avatar_url=build_file_url(request, profile.avatar_image),
        bio=profile.bio,
    )


def serialize_comment(request, comment: StudentPostComment, current_user) -> StudentPostCommentSchema:
    comment_profile = get_or_create_student_profile(comment.user)
    return StudentPostCommentSchema(
        id=comment.id,
        content=comment.content,
        created_at=comment.created_at.isoformat(),
        updated_at=comment.updated_at.isoformat(),
        is_owner=comment.user_id == current_user.id,
        author=serialize_student_identity(request, comment_profile),
    )


def serialize_post(request, post: StudentPost, current_user) -> StudentPostSchema:
    energy_count = getattr(post, "energy_count", None)
    comment_count = getattr(post, "comment_count", None)
    energized_by_me = getattr(post, "energized_by_me", None)

    comments = [serialize_comment(request, comment, current_user) for comment in post.comments.all()]

    return StudentPostSchema(
        id=post.id,
        content=post.content,
        created_at=post.created_at.isoformat(),
        updated_at=post.updated_at.isoformat(),
        is_owner=post.profile.user_id == current_user.id,
        energy_count=energy_count if energy_count is not None else post.energies.count(),
        comment_count=comment_count if comment_count is not None else post.comments.count(),
        energized_by_me=bool(energized_by_me) if energized_by_me is not None else post.energies.filter(user=current_user).exists(),
        author=serialize_student_identity(request, post.profile),
        comments=comments,
    )


def build_profile_stats(profile: StudentProfile) -> tuple[int, int, int]:
    posts_count = profile.posts.count()
    energy_received_count = StudentPostEnergy.objects.filter(post__profile=profile).count()
    comments_received_count = StudentPostComment.objects.filter(post__profile=profile).count()
    return posts_count, energy_received_count, comments_received_count


def get_social_posts_queryset(current_user):
    energy_subquery = StudentPostEnergy.objects.filter(post_id=OuterRef("pk"), user=current_user)
    return (
        StudentPost.objects.select_related("profile__user")
        .prefetch_related(
            Prefetch(
                "comments",
                queryset=StudentPostComment.objects.select_related("user", "user__student_profile").order_by("created_at", "id"),
            )
        )
        .annotate(
            energy_count=Count("energies", distinct=True),
            comment_count=Count("comments", distinct=True),
            energized_by_me=Exists(energy_subquery),
        )
    )


def get_student_post_or_404(post_id: int) -> StudentPost:
    try:
        return StudentPost.objects.select_related("profile__user").get(pk=post_id)
    except StudentPost.DoesNotExist as exc:
        raise HttpError(404, "Post not found.") from exc


def ensure_post_owner(post: StudentPost, user) -> None:
    if post.profile.user_id != user.id:
        raise HttpError(403, "You can only modify your own posts.")


def validate_avatar_upload(request):
    avatar = request.FILES.get("avatar")
    if avatar is None:
        raise HttpError(400, "Avatar file is required.")

    content_type = getattr(avatar, "content_type", "") or ""
    if not content_type.startswith("image/"):
        raise HttpError(400, "Avatar must be an image file.")

    max_size = 5 * 1024 * 1024
    if avatar.size > max_size:
        raise HttpError(400, "Avatar must be 5MB or smaller.")

    return avatar


def delete_stored_file_quietly(*, storage, name: str) -> None:
    if not name:
        return

    try:
        storage.delete(name)
    except OSError:
        logger.warning("Failed to delete avatar file '%s'.", name, exc_info=True)


def get_existing_student_profile(user) -> StudentProfile | None:
    if user.role != User.Role.STUDENT:
        return None

    try:
        return user.student_profile
    except StudentProfile.DoesNotExist:
        return None


def serialize_user(user, request=None, profile: StudentProfile | None = None) -> UserSchema:
    # Converte o model Django em um objeto pronto para resposta JSON.
    resolved_profile = profile if profile is not None else get_existing_student_profile(user)
    return UserSchema(
        id=user.id,
        email=user.email,
        first_name=user.first_name,
        last_name=user.last_name,
        role=user.role,
        avatar_url=build_file_url(request, resolved_profile.avatar_image) if request and resolved_profile else "",
    )


def build_auth_response(request, user) -> AuthResponseSchema:
    # Toda resposta de autenticacao devolve tokens + dados resumidos do usuario.
    token_pair = create_token_pair(user)
    return AuthResponseSchema(user=serialize_user(user, request=request), **token_pair)


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
    posts_count, energy_received_count, comments_received_count = build_profile_stats(profile)
    return StudentProfileSchema(
        onboarding_completed=profile.onboarding_completed,
        english_level=profile.english_level,
        bio=profile.bio,
        avatar_url="",
        posts_count=posts_count,
        energy_received_count=energy_received_count,
        comments_received_count=comments_received_count,
        favorite_songs=profile.favorite_songs,
        favorite_movies=profile.favorite_movies,
        favorite_series=profile.favorite_series,
        favorite_anime=profile.favorite_anime,
        favorite_artists=profile.favorite_artists,
        favorite_genres=profile.favorite_genres,
    )


def build_profile_response(request, user) -> ProfileResponseSchema:
    profile = get_or_create_student_profile(user)
    serialized_profile = serialize_profile(profile)
    serialized_profile.avatar_url = build_file_url(request, profile.avatar_image)
    return ProfileResponseSchema(user=serialize_user(user, request=request, profile=profile), profile=serialized_profile)


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

        if field == "bio":
            setattr(profile, field, normalize_text(value, max_length=280))
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

    return 201, build_auth_response(request, user)


@router.post("/register/teacher", response={201: AuthResponseSchema})
def register_teacher(request, payload: RegisterInput):
    # Professores agora entram pelo app com um fluxo proprio, sem Telegram.
    if not settings.ENABLE_PUBLIC_TEACHER_SIGNUP:
        raise HttpError(403, "Public teacher signup is disabled in this environment.")

    validate_identity_payload(payload.email, payload.password)

    if User.objects.filter(email__iexact=payload.email).exists():
        raise HttpError(409, "An account with this e-mail already exists.")

    user = create_account(payload, User.Role.TEACHER)

    return 201, build_auth_response(request, user)


@router.post("/login", response=AuthResponseSchema)
def login(request, payload: LoginInput):
    # authenticate usa o backend de auth do Django e compara a senha com hash.
    user = authenticate(request, username=payload.email, password=payload.password)
    if user is None:
        raise HttpError(401, "Invalid e-mail or password.")

    return build_auth_response(request, user)


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

    return build_auth_response(request, user)


@router.get("/me", auth=jwt_auth, response=UserSchema)
def me(request):
    # request.auth foi preenchido pelo JWTAuth com o usuario autenticado.
    return serialize_user(request.auth, request=request)


@profile_router.get("/me", auth=jwt_auth, response=ProfileResponseSchema)
def profile_me(request):
    require_role(request.auth, request.auth.Role.STUDENT)
    return build_profile_response(request, request.auth)


@profile_router.put("/me", auth=jwt_auth, response=ProfileResponseSchema)
def update_profile(request, payload: ProfileUpdateInput):
    require_role(request.auth, request.auth.Role.STUDENT)
    profile = get_or_create_student_profile(request.auth)
    update_student_profile(profile, payload)
    return build_profile_response(request, request.auth)


@profile_router.post("/onboarding", auth=jwt_auth, response=ProfileResponseSchema)
def complete_onboarding(request, payload: ProfileUpdateInput):
    require_role(request.auth, request.auth.Role.STUDENT)
    profile = get_or_create_student_profile(request.auth)
    update_student_profile(profile, payload, complete_onboarding=True)
    transaction.on_commit(lambda: enqueue_personalized_feed_bootstrap(request.auth.id, force=True))
    return build_profile_response(request, request.auth)


@profile_router.post("/me/avatar", auth=jwt_auth, response=ProfileResponseSchema)
def upload_avatar(request):
    require_role(request.auth, request.auth.Role.STUDENT)
    profile = get_or_create_student_profile(request.auth)
    avatar = validate_avatar_upload(request)
    previous_avatar_name = profile.avatar_image.name if profile.avatar_image else ""
    previous_avatar_storage = profile.avatar_image.storage if profile.avatar_image else None

    profile.avatar_image = avatar
    profile.save(update_fields=["avatar_image", "updated_at"])

    if previous_avatar_storage and previous_avatar_name != profile.avatar_image.name:
        delete_stored_file_quietly(storage=previous_avatar_storage, name=previous_avatar_name)

    return build_profile_response(request, request.auth)


@profile_router.delete("/me/avatar", auth=jwt_auth, response=ProfileResponseSchema)
def delete_avatar(request):
    require_role(request.auth, request.auth.Role.STUDENT)
    profile = get_or_create_student_profile(request.auth)
    if profile.avatar_image:
        previous_avatar_name = profile.avatar_image.name
        previous_avatar_storage = profile.avatar_image.storage
        profile.avatar_image = None
        profile.save(update_fields=["avatar_image", "updated_at"])
        delete_stored_file_quietly(storage=previous_avatar_storage, name=previous_avatar_name)

    return build_profile_response(request, request.auth)


@profile_router.get("/posts", auth=jwt_auth, response=list[StudentPostSchema])
def list_student_posts(request):
    require_role(request.auth, request.auth.Role.STUDENT)
    posts = get_social_posts_queryset(request.auth)[:20]
    return [serialize_post(request, post, request.auth) for post in posts]


@profile_router.post("/posts", auth=jwt_auth, response={201: StudentPostSchema})
def create_student_post(request, payload: StudentPostInput):
    require_role(request.auth, request.auth.Role.STUDENT)
    profile = get_or_create_student_profile(request.auth)
    content = normalize_text(payload.content, max_length=1200)
    if not content:
        raise HttpError(400, "Post content is required.")

    post = StudentPost.objects.create(profile=profile, content=content)
    hydrated_post = get_social_posts_queryset(request.auth).get(pk=post.pk)
    return 201, serialize_post(request, hydrated_post, request.auth)


@profile_router.patch("/posts/{post_id}", auth=jwt_auth, response=StudentPostSchema)
def update_student_post(request, post_id: int, payload: StudentPostInput):
    require_role(request.auth, request.auth.Role.STUDENT)
    post = get_student_post_or_404(post_id)
    ensure_post_owner(post, request.auth)

    content = normalize_text(payload.content, max_length=1200)
    if not content:
        raise HttpError(400, "Post content is required.")

    post.content = content
    post.save(update_fields=["content", "updated_at"])
    hydrated_post = get_social_posts_queryset(request.auth).get(pk=post.pk)
    return serialize_post(request, hydrated_post, request.auth)


@profile_router.delete("/posts/{post_id}", auth=jwt_auth, response={204: None})
def delete_student_post(request, post_id: int):
    require_role(request.auth, request.auth.Role.STUDENT)
    post = get_student_post_or_404(post_id)
    ensure_post_owner(post, request.auth)
    post.delete()
    return 204, None


@profile_router.post("/posts/{post_id}/energy", auth=jwt_auth, response=StudentPostSchema)
def energize_student_post(request, post_id: int):
    require_role(request.auth, request.auth.Role.STUDENT)
    post = get_student_post_or_404(post_id)
    StudentPostEnergy.objects.get_or_create(post=post, user=request.auth)
    hydrated_post = get_social_posts_queryset(request.auth).get(pk=post.pk)
    return serialize_post(request, hydrated_post, request.auth)


@profile_router.delete("/posts/{post_id}/energy", auth=jwt_auth, response=StudentPostSchema)
def remove_energy_from_student_post(request, post_id: int):
    require_role(request.auth, request.auth.Role.STUDENT)
    post = get_student_post_or_404(post_id)
    StudentPostEnergy.objects.filter(post=post, user=request.auth).delete()
    hydrated_post = get_social_posts_queryset(request.auth).get(pk=post.pk)
    return serialize_post(request, hydrated_post, request.auth)


@profile_router.post("/posts/{post_id}/comments", auth=jwt_auth, response={201: StudentPostSchema})
def create_student_post_comment(request, post_id: int, payload: StudentPostCommentInput):
    require_role(request.auth, request.auth.Role.STUDENT)
    post = get_student_post_or_404(post_id)
    content = normalize_text(payload.content, max_length=600)
    if not content:
        raise HttpError(400, "Comment content is required.")

    StudentPostComment.objects.create(post=post, user=request.auth, content=content)
    hydrated_post = get_social_posts_queryset(request.auth).get(pk=post.pk)
    return 201, serialize_post(request, hydrated_post, request.auth)


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
