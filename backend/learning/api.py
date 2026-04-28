"""Routers do contexto de aprendizagem.

Separacao atual:
- public_router: consumo publico do feed
- teacher_router: gestao de lessons pelo professor
- submission_router: tentativas enviadas pelo aluno
"""

from datetime import datetime

from django.db import transaction
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja import Router, Schema
from ninja.errors import HttpError

from accounts.jwt import jwt_auth
from accounts.permissions import require_role
from learning.models import Exercise, Lesson, Submission


public_router = Router()
teacher_router = Router()
submission_router = Router()


class ExercisePublicSchema(Schema):
    id: int
    exercise_type: str
    instruction_text: str
    expected_phrase_en: str
    expected_phrase_pt: str
    max_score: int


class LessonFeedItemSchema(Schema):
    id: int
    slug: str
    title: str
    description: str
    content_type: str
    source_type: str
    media_url: str
    teacher_name: str
    created_at: datetime


class LessonDetailSchema(LessonFeedItemSchema):
    status: str
    published_at: datetime | None
    exercise: ExercisePublicSchema


class FeedResponseSchema(Schema):
    items: list[LessonFeedItemSchema]
    next_cursor: int | None


class TeacherLessonInput(Schema):
    title: str
    description: str = ""
    content_type: str = Lesson.ContentType.CHARGE
    source_type: str = Lesson.SourceType.EXTERNAL_LINK
    media_url: str
    status: str = Lesson.Status.DRAFT
    instruction_text: str
    expected_phrase_en: str
    expected_phrase_pt: str
    max_score: int = 100


class TeacherLessonUpdateInput(Schema):
    title: str | None = None
    description: str | None = None
    content_type: str | None = None
    source_type: str | None = None
    media_url: str | None = None
    status: str | None = None
    instruction_text: str | None = None
    expected_phrase_en: str | None = None
    expected_phrase_pt: str | None = None
    max_score: int | None = None


class TeacherLessonSchema(LessonDetailSchema):
    updated_at: datetime


class SubmissionCreateInput(Schema):
    exercise_id: int
    transcript_en: str = ""
    transcript_pt: str = ""


class SubmissionSchema(Schema):
    id: int
    status: str
    transcript_en: str
    transcript_pt: str
    score_en: int | None
    score_pt: int | None
    final_score: int | None
    processed_at: datetime | None
    created_at: datetime
    exercise_id: int
    lesson_title: str
    lesson_slug: str


def get_teacher_name(lesson: Lesson) -> str:
    # Preferimos nome completo no feed, mas usamos o e-mail como fallback.
    full_name = f"{lesson.teacher.first_name} {lesson.teacher.last_name}".strip()
    return full_name or lesson.teacher.email


def serialize_exercise(exercise: Exercise) -> ExercisePublicSchema:
    # Centralizar serializacao evita duplicacao entre endpoints.
    return ExercisePublicSchema(
        id=exercise.id,
        exercise_type=exercise.exercise_type,
        instruction_text=exercise.instruction_text,
        expected_phrase_en=exercise.expected_phrase_en,
        expected_phrase_pt=exercise.expected_phrase_pt,
        max_score=exercise.max_score,
    )


def serialize_lesson_feed_item(lesson: Lesson) -> LessonFeedItemSchema:
    return LessonFeedItemSchema(
        id=lesson.id,
        slug=lesson.slug,
        title=lesson.title,
        description=lesson.description,
        content_type=lesson.content_type,
        source_type=lesson.source_type,
        media_url=lesson.media_url,
        teacher_name=get_teacher_name(lesson),
        created_at=lesson.created_at,
    )


def serialize_lesson_detail(lesson: Lesson) -> LessonDetailSchema:
    # Reaproveita os campos do feed e adiciona o exercise vinculado.
    return LessonDetailSchema(
        **serialize_lesson_feed_item(lesson).model_dump(),
        status=lesson.status,
        published_at=lesson.published_at,
        exercise=serialize_exercise(lesson.exercise),
    )


def serialize_teacher_lesson(lesson: Lesson) -> TeacherLessonSchema:
    return TeacherLessonSchema(
        **serialize_lesson_detail(lesson).model_dump(),
        updated_at=lesson.updated_at,
    )


def serialize_submission(submission: Submission) -> SubmissionSchema:
    return SubmissionSchema(
        id=submission.id,
        status=submission.status,
        transcript_en=submission.transcript_en,
        transcript_pt=submission.transcript_pt,
        score_en=submission.score_en,
        score_pt=submission.score_pt,
        final_score=submission.final_score,
        processed_at=submission.processed_at,
        created_at=submission.created_at,
        exercise_id=submission.exercise_id,
        lesson_title=submission.exercise.lesson.title,
        lesson_slug=submission.exercise.lesson.slug,
    )


def get_owned_lesson_or_404(user, lesson_id: int) -> Lesson:
    # Professor so enxerga a propria lesson; admin pode acessar qualquer uma.
    queryset = Lesson.objects.select_related("teacher", "exercise")
    if user.role == user.Role.ADMIN:
        return get_object_or_404(queryset, pk=lesson_id)
    return get_object_or_404(queryset, pk=lesson_id, teacher=user)


@public_router.get("/feed", response=FeedResponseSchema)
def get_feed(request, cursor: int | None = None, limit: int = 10):
    # Cursor pagination e melhor que paginacao por pagina para um feed estilo scroll.
    if limit < 1 or limit > 50:
        raise HttpError(400, "Limit must be between 1 and 50.")

    queryset = Lesson.objects.filter(status=Lesson.Status.PUBLISHED).select_related("teacher")
    if cursor is not None:
        queryset = queryset.filter(id__lt=cursor)

    # Buscamos um item extra para saber se ainda existe proxima pagina.
    lessons = list(queryset.order_by("-id")[: limit + 1])
    has_more = len(lessons) > limit
    lessons = lessons[:limit]
    next_cursor = lessons[-1].id if has_more and lessons else None

    return FeedResponseSchema(
        items=[serialize_lesson_feed_item(lesson) for lesson in lessons],
        next_cursor=next_cursor,
    )


@public_router.get("/lessons/{slug}", response=LessonDetailSchema)
def get_lesson_detail(request, slug: str):
    # O aluno so pode abrir detalhes de lessons publicadas.
    lesson = get_object_or_404(
        Lesson.objects.filter(status=Lesson.Status.PUBLISHED).select_related("teacher", "exercise"),
        slug=slug,
    )
    return serialize_lesson_detail(lesson)


@teacher_router.get("/lessons", auth=jwt_auth, response=list[TeacherLessonSchema])
def list_teacher_lessons(request):
    # A autorizacao e separada da autenticacao: primeiro validamos o token, depois o papel.
    require_role(request.auth, request.auth.Role.TEACHER, request.auth.Role.ADMIN)

    queryset = Lesson.objects.select_related("teacher", "exercise")
    if request.auth.role == request.auth.Role.TEACHER:
        queryset = queryset.filter(teacher=request.auth)

    return [serialize_teacher_lesson(lesson) for lesson in queryset.order_by("-created_at")]


@teacher_router.post("/lessons", auth=jwt_auth, response={201: TeacherLessonSchema})
def create_teacher_lesson(request, payload: TeacherLessonInput):
    require_role(request.auth, request.auth.Role.TEACHER, request.auth.Role.ADMIN)

    with transaction.atomic():
        # Lesson e Exercise nascem juntos para manter o item do feed completo.
        lesson = Lesson.objects.create(
            teacher=request.auth,
            title=payload.title,
            description=payload.description,
            content_type=payload.content_type,
            source_type=payload.source_type,
            media_url=payload.media_url,
            status=payload.status,
            published_at=timezone.now() if payload.status == Lesson.Status.PUBLISHED else None,
        )
        Exercise.objects.create(
            lesson=lesson,
            instruction_text=payload.instruction_text,
            expected_phrase_en=payload.expected_phrase_en,
            expected_phrase_pt=payload.expected_phrase_pt,
            max_score=payload.max_score,
        )

    lesson.refresh_from_db()
    return 201, serialize_teacher_lesson(lesson)


@teacher_router.put("/lessons/{lesson_id}", auth=jwt_auth, response=TeacherLessonSchema)
def update_teacher_lesson(request, lesson_id: int, payload: TeacherLessonUpdateInput):
    require_role(request.auth, request.auth.Role.TEACHER, request.auth.Role.ADMIN)

    lesson = get_owned_lesson_or_404(request.auth, lesson_id)
    # exclude_unset evita sobrescrever campos que nao vieram no payload.
    changes = payload.model_dump(exclude_unset=True)

    # Separar campos de lesson e exercise deixa claro quais atributos pertencem a cada model.
    lesson_fields = {"title", "description", "content_type", "source_type", "media_url", "status"}
    exercise_fields = {"instruction_text", "expected_phrase_en", "expected_phrase_pt", "max_score"}

    for field, value in changes.items():
        if field in lesson_fields:
            setattr(lesson, field, value)

    if "status" in changes:
        if lesson.status == Lesson.Status.PUBLISHED and lesson.published_at is None:
            lesson.published_at = timezone.now()
        elif lesson.status == Lesson.Status.DRAFT:
            lesson.published_at = None

    exercise = lesson.exercise
    for field, value in changes.items():
        if field in exercise_fields:
            setattr(exercise, field, value)

    with transaction.atomic():
        lesson.save()
        exercise.save()

    lesson.refresh_from_db()
    return serialize_teacher_lesson(lesson)


@submission_router.post("/submissions", auth=jwt_auth, response={201: SubmissionSchema})
def create_submission(request, payload: SubmissionCreateInput):
    # Apenas aluno envia tentativa; professor nao deveria registrar submission.
    require_role(request.auth, request.auth.Role.STUDENT)

    exercise = get_object_or_404(
        Exercise.objects.select_related("lesson"),
        pk=payload.exercise_id,
        lesson__status=Lesson.Status.PUBLISHED,
    )

    # A submission nasce como pending; a etapa de IA pode processar depois.
    submission = Submission.objects.create(
        student=request.auth,
        exercise=exercise,
        transcript_en=payload.transcript_en,
        transcript_pt=payload.transcript_pt,
        status=Submission.Status.PENDING,
    )

    submission.refresh_from_db()
    return 201, serialize_submission(submission)


@submission_router.get("/submissions/me", auth=jwt_auth, response=list[SubmissionSchema])
def list_my_submissions(request):
    require_role(request.auth, request.auth.Role.STUDENT)

    # O aluno so lista o proprio historico.
    submissions = Submission.objects.filter(student=request.auth).select_related("exercise__lesson")
    return [serialize_submission(submission) for submission in submissions.order_by("-created_at")]
