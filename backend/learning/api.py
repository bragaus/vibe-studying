"""Routers do contexto de aprendizagem.

Separacao atual:
- public_router: consumo publico e feed personalizado
- teacher_router: gestao de lessons pelo professor
- submission_router: tentativas enviadas pelo aluno
"""

from datetime import datetime
import logging

from django.conf import settings
from django.core.cache import cache
from django.db import transaction
from django.db.models import Q
from django.shortcuts import get_object_or_404
from django.utils import timezone
from ninja import Router, Schema
from ninja.errors import HttpError

from accounts.jwt import jwt_auth
from accounts.models import StudentProfile
from accounts.permissions import require_role
from learning.models import Exercise, ExerciseLine, Lesson, PersonalizedFeedJob, Submission, SubmissionLine
from learning.tasks import count_ready_personalized_lessons, enqueue_personalized_feed_bootstrap, get_or_create_personalized_feed_job


public_router = Router()
teacher_router = Router()
submission_router = Router()

CONTENT_CACHE_VERSION_KEY = "learning:content-cache-version"
logger = logging.getLogger(__name__)


class ExerciseLineSchema(Schema):
    id: int | None
    order: int
    text_en: str
    text_pt: str
    phonetic_hint: str
    reference_start_ms: int
    reference_end_ms: int


class ExercisePublicSchema(Schema):
    id: int
    exercise_type: str
    instruction_text: str
    expected_phrase_en: str
    expected_phrase_pt: str
    max_score: int
    lines: list[ExerciseLineSchema]


class LessonFeedItemSchema(Schema):
    id: int
    slug: str
    title: str
    description: str
    content_type: str
    source_type: str
    difficulty: str
    tags: list[str]
    media_url: str
    cover_image_url: str = ""
    source_url: str = ""
    teacher_name: str
    created_at: datetime
    is_personalized: bool = False
    match_reason: str | None = None


class LessonDetailSchema(LessonFeedItemSchema):
    status: str
    published_at: datetime | None
    exercise: ExercisePublicSchema


class FeedResponseSchema(Schema):
    items: list[LessonFeedItemSchema]
    next_cursor: int | None


class FeedBootstrapStatusSchema(Schema):
    status: str
    ready_items: int
    target_items: int
    generated_items: int
    started_at: datetime | None = None
    finished_at: datetime | None = None
    last_error: str | None = None


class TeacherLessonLineInput(Schema):
    text_en: str
    text_pt: str = ""
    phonetic_hint: str = ""
    reference_start_ms: int = 0
    reference_end_ms: int = 0


class TeacherLessonInput(Schema):
    title: str
    description: str = ""
    content_type: str = Lesson.ContentType.CHARGE
    source_type: str = Lesson.SourceType.EXTERNAL_LINK
    difficulty: str = Lesson.Difficulty.EASY
    tags: list[str] = []
    media_url: str
    status: str = Lesson.Status.DRAFT
    instruction_text: str
    expected_phrase_en: str
    expected_phrase_pt: str
    max_score: int = 100
    line_items: list[TeacherLessonLineInput] | None = None


class TeacherLessonUpdateInput(Schema):
    title: str | None = None
    description: str | None = None
    content_type: str | None = None
    source_type: str | None = None
    difficulty: str | None = None
    tags: list[str] | None = None
    media_url: str | None = None
    status: str | None = None
    instruction_text: str | None = None
    expected_phrase_en: str | None = None
    expected_phrase_pt: str | None = None
    max_score: int | None = None
    line_items: list[TeacherLessonLineInput] | None = None


class TeacherLessonSchema(LessonDetailSchema):
    updated_at: datetime


class SubmissionLineInput(Schema):
    exercise_line_id: int | None = None
    transcript_en: str = ""
    accuracy_score: int | None = None
    pronunciation_score: int | None = None
    wrong_words: list[str] | None = None
    feedback: dict | None = None
    status: str = SubmissionLine.Status.PENDING


class SubmissionCreateInput(Schema):
    exercise_id: int
    client_submission_id: str | None = None
    transcript_en: str = ""
    transcript_pt: str = ""
    line_results: list[SubmissionLineInput] | None = None


class SubmissionLineSchema(Schema):
    exercise_line_id: int | None
    transcript_en: str
    accuracy_score: int | None
    pronunciation_score: int | None
    wrong_words: list[str]
    feedback: dict
    status: str


class SubmissionSchema(Schema):
    id: int
    client_submission_id: str | None
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
    line_results: list[SubmissionLineSchema]


def normalize_keyword(value: str) -> str:
    return " ".join(value.lower().strip().split())


def get_content_cache_version() -> int:
    try:
        cache_version = cache.get(CONTENT_CACHE_VERSION_KEY)
    except Exception as exc:
        logger.warning("content cache read failed", extra={"error": str(exc)})
        return 1

    if cache_version is None:
        try:
            cache.set(CONTENT_CACHE_VERSION_KEY, 1, timeout=None)
        except Exception as exc:
            logger.warning("content cache seed failed", extra={"error": str(exc)})
        return 1
    return int(cache_version)


def bump_content_cache_version() -> int:
    current_version = get_content_cache_version()
    next_version = current_version + 1
    try:
        cache.set(CONTENT_CACHE_VERSION_KEY, next_version, timeout=None)
    except Exception as exc:
        logger.warning("content cache version bump failed", extra={"error": str(exc)})
    return next_version


def safe_cache_get(cache_key: str):
    try:
        return cache.get(cache_key)
    except Exception as exc:
        logger.warning("cache get failed", extra={"cache_key": cache_key, "error": str(exc)})
        return None


def safe_cache_set(cache_key: str, value, timeout: int) -> None:
    try:
        cache.set(cache_key, value, timeout=timeout)
    except Exception as exc:
        logger.warning("cache set failed", extra={"cache_key": cache_key, "error": str(exc)})


def build_public_feed_cache_key(cursor: int | None, limit: int) -> str:
    return f"learning:feed:v{get_content_cache_version()}:cursor:{cursor or 'start'}:limit:{limit}"


def build_lesson_detail_cache_key(slug: str) -> str:
    return f"learning:lesson:v{get_content_cache_version()}:slug:{slug}"


def invalidate_public_learning_cache() -> None:
    bump_content_cache_version()


def normalize_keyword_list(values: list[str] | None) -> list[str]:
    if not values:
        return []

    unique_values: list[str] = []
    seen: set[str] = set()
    for raw_value in values:
        clean_value = raw_value.strip()
        if not clean_value:
            continue

        lowered = normalize_keyword(clean_value)
        if lowered in seen:
            continue

        seen.add(lowered)
        unique_values.append(clean_value)

    return unique_values


def get_teacher_name(lesson: Lesson) -> str:
    full_name = f"{lesson.teacher.first_name} {lesson.teacher.last_name}".strip()
    return full_name or lesson.teacher.email


def get_optional_request_user(request):
    authorization_header = request.headers.get("Authorization", "")
    if not authorization_header.startswith("Bearer "):
        return None

    token = authorization_header.removeprefix("Bearer ").strip()
    if not token:
        return None
    return jwt_auth.authenticate(request, token)


def serialize_feed_bootstrap_status(job: PersonalizedFeedJob | None, ready_items: int) -> FeedBootstrapStatusSchema:
    if job is None:
        return FeedBootstrapStatusSchema(
            status=PersonalizedFeedJob.Status.IDLE,
            ready_items=ready_items,
            target_items=settings.PERSONALIZED_FEED_TARGET_ITEMS,
            generated_items=ready_items,
            started_at=None,
            finished_at=None,
            last_error=None,
        )

    return FeedBootstrapStatusSchema(
        status=job.status,
        ready_items=ready_items,
        target_items=job.target_items,
        generated_items=job.generated_items,
        started_at=job.started_at,
        finished_at=job.finished_at,
        last_error=job.last_error or None,
    )


def serialize_exercise_lines(exercise: Exercise) -> list[ExerciseLineSchema]:
    saved_lines = list(exercise.lines.all())
    if saved_lines:
        return [
            ExerciseLineSchema(
                id=line.id,
                order=line.order,
                text_en=line.text_en,
                text_pt=line.text_pt,
                phonetic_hint=line.phonetic_hint,
                reference_start_ms=line.reference_start_ms,
                reference_end_ms=line.reference_end_ms,
            )
            for line in saved_lines
        ]

    return [
        ExerciseLineSchema(
            id=None,
            order=1,
            text_en=exercise.expected_phrase_en,
            text_pt=exercise.expected_phrase_pt,
            phonetic_hint="",
            reference_start_ms=0,
            reference_end_ms=0,
        )
    ]


def serialize_exercise(exercise: Exercise) -> ExercisePublicSchema:
    return ExercisePublicSchema(
        id=exercise.id,
        exercise_type=exercise.exercise_type,
        instruction_text=exercise.instruction_text,
        expected_phrase_en=exercise.expected_phrase_en,
        expected_phrase_pt=exercise.expected_phrase_pt,
        max_score=exercise.max_score,
        lines=serialize_exercise_lines(exercise),
    )


def serialize_lesson_feed_item(lesson: Lesson, match_reason: str | None = None) -> LessonFeedItemSchema:
    return LessonFeedItemSchema(
        id=lesson.id,
        slug=lesson.slug,
        title=lesson.title,
        description=lesson.description,
        content_type=lesson.content_type,
        source_type=lesson.source_type,
        difficulty=lesson.difficulty,
        tags=lesson.tags,
        media_url=lesson.media_url,
        cover_image_url=lesson.cover_image_url,
        source_url=lesson.source_url,
        teacher_name=get_teacher_name(lesson),
        created_at=lesson.created_at,
        is_personalized=lesson.visibility == Lesson.Visibility.PRIVATE and lesson.student_id is not None,
        match_reason=match_reason or lesson.match_reason_hint or None,
    )


def serialize_lesson_detail(lesson: Lesson) -> LessonDetailSchema:
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


def serialize_submission_line(submission_line: SubmissionLine) -> SubmissionLineSchema:
    return SubmissionLineSchema(
        exercise_line_id=submission_line.exercise_line_id,
        transcript_en=submission_line.transcript_en,
        accuracy_score=submission_line.accuracy_score,
        pronunciation_score=submission_line.pronunciation_score,
        wrong_words=submission_line.wrong_words,
        feedback=submission_line.feedback,
        status=submission_line.status,
    )


def serialize_submission(submission: Submission) -> SubmissionSchema:
    return SubmissionSchema(
        id=submission.id,
        client_submission_id=submission.client_submission_id,
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
        line_results=[serialize_submission_line(line) for line in submission.line_results.all()],
    )


def get_owned_lesson_or_404(user, lesson_id: int) -> Lesson:
    queryset = Lesson.objects.select_related("teacher", "exercise").prefetch_related("exercise__lines")
    if user.role == user.Role.ADMIN:
        return get_object_or_404(queryset, pk=lesson_id)
    return get_object_or_404(queryset, pk=lesson_id, teacher=user)


def sync_exercise_lines(exercise: Exercise, raw_lines: list[TeacherLessonLineInput] | None) -> None:
    normalized_lines = raw_lines or []
    if not normalized_lines:
        normalized_lines = [
            TeacherLessonLineInput(
                text_en=exercise.expected_phrase_en,
                text_pt=exercise.expected_phrase_pt,
                phonetic_hint="",
                reference_start_ms=0,
                reference_end_ms=0,
            )
        ]

    exercise.lines.all().delete()
    ExerciseLine.objects.bulk_create(
        [
            ExerciseLine(
                exercise=exercise,
                order=index,
                text_en=line.text_en,
                text_pt=line.text_pt,
                phonetic_hint=line.phonetic_hint,
                reference_start_ms=max(line.reference_start_ms, 0),
                reference_end_ms=max(line.reference_end_ms, 0),
            )
            for index, line in enumerate(normalized_lines, start=1)
        ]
    )


def build_searchable_lesson_text(lesson: Lesson) -> str:
    pieces = [
        lesson.title,
        lesson.description,
        lesson.source_title,
        lesson.match_reason_hint,
        " ".join(lesson.tags),
    ]
    if hasattr(lesson, "exercise"):
        pieces.append(lesson.exercise.expected_phrase_en)
        pieces.append(lesson.exercise.expected_phrase_pt)

    return normalize_keyword(" ".join(piece for piece in pieces if piece))


def get_or_create_student_profile(user) -> StudentProfile:
    profile, _ = StudentProfile.objects.get_or_create(user=user)
    return profile


def score_lesson_for_student(lesson: Lesson, profile: StudentProfile, user) -> tuple[int, str | None]:
    searchable_text = build_searchable_lesson_text(lesson)
    score = 0
    reasons: list[str] = []

    if lesson.visibility == Lesson.Visibility.PRIVATE and lesson.student_id == user.id:
        score += 100
        if lesson.match_reason_hint:
            reasons.append(lesson.match_reason_hint)
        else:
            reasons.append("generated from your onboarding")

    weighted_preferences = [
        (profile.favorite_songs, 5, "matches favorite song"),
        (profile.favorite_movies, 5, "matches favorite movie"),
        (profile.favorite_series, 5, "matches favorite series"),
        (profile.favorite_anime, 5, "matches favorite anime"),
        (profile.favorite_artists, 4, "matches favorite artist"),
        (profile.favorite_genres, 3, "matches favorite genre"),
    ]

    for values, weight, reason in weighted_preferences:
        for item in values:
            if normalize_keyword(item) in searchable_text:
                score += weight
                reasons.append(reason)
                break

    if lesson.content_type == Lesson.ContentType.MUSIC and profile.favorite_songs:
        score += 1
    if lesson.content_type == Lesson.ContentType.MOVIE_CLIP and profile.favorite_movies:
        score += 1
    if lesson.content_type == Lesson.ContentType.SERIES_CLIP and profile.favorite_series:
        score += 1
    if lesson.content_type == Lesson.ContentType.ANIME_CLIP and profile.favorite_anime:
        score += 1

    review_exercises = set(
        Submission.objects.filter(student=user, final_score__isnull=False, final_score__lt=80).values_list("exercise_id", flat=True)
    )
    mastered_exercises = set(
        Submission.objects.filter(student=user, final_score__isnull=False, final_score__gte=90).values_list("exercise_id", flat=True)
    )

    if lesson.exercise.id in review_exercises:
        score += 2
        reasons.append("recommended for review")
    if lesson.exercise.id in mastered_exercises:
        score -= 3

    return score, (reasons[0] if reasons else None)


def build_primary_line_values(
    expected_phrase_en: str,
    expected_phrase_pt: str,
    line_items: list[TeacherLessonLineInput] | None,
) -> tuple[str, str]:
    if line_items:
        return line_items[0].text_en, line_items[0].text_pt
    return expected_phrase_en, expected_phrase_pt


@public_router.get("/feed", response=FeedResponseSchema)
def get_feed(request, cursor: int | None = None, limit: int = 10):
    if limit < 1 or limit > 50:
        raise HttpError(400, "Limit must be between 1 and 50.")

    cache_key = build_public_feed_cache_key(cursor, limit)
    cached_response = safe_cache_get(cache_key)
    if cached_response is not None:
        return FeedResponseSchema.model_validate(cached_response)

    queryset = Lesson.objects.filter(
        status=Lesson.Status.PUBLISHED,
        visibility=Lesson.Visibility.PUBLIC,
    ).select_related("teacher")
    if cursor is not None:
        queryset = queryset.filter(id__lt=cursor)

    lessons = list(queryset.order_by("-id")[: limit + 1])
    has_more = len(lessons) > limit
    lessons = lessons[:limit]
    next_cursor = lessons[-1].id if has_more and lessons else None

    response = FeedResponseSchema(
        items=[serialize_lesson_feed_item(lesson) for lesson in lessons],
        next_cursor=next_cursor,
    )
    safe_cache_set(
        cache_key,
        response.model_dump(mode="json"),
        timeout=settings.PUBLIC_FEED_CACHE_TIMEOUT_SECONDS,
    )
    return response


@public_router.get("/feed/bootstrap-status", auth=jwt_auth, response=FeedBootstrapStatusSchema)
def get_feed_bootstrap_status(request):
    require_role(request.auth, request.auth.Role.STUDENT)
    ready_items = count_ready_personalized_lessons(request.auth)
    job = PersonalizedFeedJob.objects.filter(student=request.auth).first()
    return serialize_feed_bootstrap_status(job, ready_items)


@public_router.post("/feed/bootstrap", auth=jwt_auth, response=FeedBootstrapStatusSchema)
def bootstrap_feed(request):
    require_role(request.auth, request.auth.Role.STUDENT)
    profile = get_or_create_student_profile(request.auth)
    if not profile.onboarding_completed:
        raise HttpError(400, "Complete the onboarding before generating the personalized feed.")

    job = enqueue_personalized_feed_bootstrap(request.auth.id, force=True)
    ready_items = count_ready_personalized_lessons(request.auth)
    return serialize_feed_bootstrap_status(job, ready_items)


@public_router.get("/feed/personalized", auth=jwt_auth, response=FeedResponseSchema)
def get_personalized_feed(request, cursor: int | None = None, limit: int = 10):
    require_role(request.auth, request.auth.Role.STUDENT)
    if limit < 1 or limit > 50:
        raise HttpError(400, "Limit must be between 1 and 50.")

    profile = get_or_create_student_profile(request.auth)
    queryset = (
        Lesson.objects.filter(status=Lesson.Status.PUBLISHED)
        .filter(Q(visibility=Lesson.Visibility.PUBLIC) | Q(visibility=Lesson.Visibility.PRIVATE, student=request.auth))
        .select_related("teacher", "exercise")
        .prefetch_related("exercise__lines")
    )
    if cursor is not None:
        queryset = queryset.filter(id__lt=cursor)

    ranked_lessons = [
        (lesson, *score_lesson_for_student(lesson, profile, request.auth))
        for lesson in queryset
    ]
    ranked_lessons.sort(key=lambda item: (-item[1], -item[0].id))

    page = ranked_lessons[: limit + 1]
    has_more = len(page) > limit
    page = page[:limit]
    next_cursor = page[-1][0].id if has_more and page else None

    return FeedResponseSchema(
        items=[serialize_lesson_feed_item(lesson, match_reason=match_reason) for lesson, _, match_reason in page],
        next_cursor=next_cursor,
    )


@public_router.get("/lessons/{slug}", response=LessonDetailSchema)
def get_lesson_detail(request, slug: str):
    request_user = get_optional_request_user(request)
    if request_user is None:
        cache_key = build_lesson_detail_cache_key(slug)
        cached_response = safe_cache_get(cache_key)
        if cached_response is not None:
            return LessonDetailSchema.model_validate(cached_response)

    queryset = (
        Lesson.objects.filter(status=Lesson.Status.PUBLISHED)
        .select_related("teacher", "exercise", "student")
        .prefetch_related("exercise__lines")
    )
    if request_user is None:
        queryset = queryset.filter(visibility=Lesson.Visibility.PUBLIC)
    else:
        queryset = queryset.filter(
            Q(visibility=Lesson.Visibility.PUBLIC)
            | Q(visibility=Lesson.Visibility.PRIVATE, student=request_user)
        )

    lesson = get_object_or_404(queryset, slug=slug)
    response = serialize_lesson_detail(lesson)
    if lesson.visibility == Lesson.Visibility.PUBLIC:
        cache_key = build_lesson_detail_cache_key(slug)
        safe_cache_set(
            cache_key,
            response.model_dump(mode="json"),
            timeout=settings.LESSON_DETAIL_CACHE_TIMEOUT_SECONDS,
        )
    return response


@teacher_router.get("/lessons", auth=jwt_auth, response=list[TeacherLessonSchema])
def list_teacher_lessons(request):
    require_role(request.auth, request.auth.Role.TEACHER, request.auth.Role.ADMIN)

    queryset = Lesson.objects.select_related("teacher", "exercise").prefetch_related("exercise__lines")
    if request.auth.role == request.auth.Role.TEACHER:
        queryset = queryset.filter(teacher=request.auth)

    return [serialize_teacher_lesson(lesson) for lesson in queryset.order_by("-created_at")]


@teacher_router.post("/lessons", auth=jwt_auth, response={201: TeacherLessonSchema})
def create_teacher_lesson(request, payload: TeacherLessonInput):
    require_role(request.auth, request.auth.Role.TEACHER, request.auth.Role.ADMIN)

    primary_phrase_en, primary_phrase_pt = build_primary_line_values(
        payload.expected_phrase_en,
        payload.expected_phrase_pt,
        payload.line_items,
    )

    with transaction.atomic():
        lesson = Lesson.objects.create(
            teacher=request.auth,
            title=payload.title,
            description=payload.description,
            content_type=payload.content_type,
            source_type=payload.source_type,
            difficulty=payload.difficulty,
            tags=normalize_keyword_list(payload.tags),
            media_url=payload.media_url,
            status=payload.status,
            published_at=timezone.now() if payload.status == Lesson.Status.PUBLISHED else None,
        )
        exercise = Exercise.objects.create(
            lesson=lesson,
            instruction_text=payload.instruction_text,
            expected_phrase_en=primary_phrase_en,
            expected_phrase_pt=primary_phrase_pt,
            max_score=payload.max_score,
        )
        sync_exercise_lines(exercise, payload.line_items)

        transaction.on_commit(invalidate_public_learning_cache)

    lesson.refresh_from_db()
    return 201, serialize_teacher_lesson(lesson)


@teacher_router.put("/lessons/{lesson_id}", auth=jwt_auth, response=TeacherLessonSchema)
def update_teacher_lesson(request, lesson_id: int, payload: TeacherLessonUpdateInput):
    require_role(request.auth, request.auth.Role.TEACHER, request.auth.Role.ADMIN)

    lesson = get_owned_lesson_or_404(request.auth, lesson_id)
    changes = payload.model_dump(exclude_unset=True)

    lesson_fields = {
        "title",
        "description",
        "content_type",
        "source_type",
        "difficulty",
        "media_url",
        "status",
    }
    exercise_fields = {"instruction_text", "expected_phrase_en", "expected_phrase_pt", "max_score"}

    for field, value in changes.items():
        if field in lesson_fields and value is not None:
            setattr(lesson, field, value)

    if "tags" in changes and changes["tags"] is not None:
        lesson.tags = normalize_keyword_list(changes["tags"])

    if "status" in changes:
        if lesson.status == Lesson.Status.PUBLISHED and lesson.published_at is None:
            lesson.published_at = timezone.now()
        elif lesson.status == Lesson.Status.DRAFT:
            lesson.published_at = None

    exercise = lesson.exercise
    for field, value in changes.items():
        if field in exercise_fields and value is not None:
            setattr(exercise, field, value)

    line_items = payload.line_items
    if line_items:
        exercise.expected_phrase_en = line_items[0].text_en
        exercise.expected_phrase_pt = line_items[0].text_pt

    with transaction.atomic():
        lesson.save()
        exercise.save()
        if "line_items" in changes:
            sync_exercise_lines(exercise, line_items)

        transaction.on_commit(invalidate_public_learning_cache)

    lesson.refresh_from_db()
    return serialize_teacher_lesson(lesson)


@submission_router.post("/submissions", auth=jwt_auth, response={200: SubmissionSchema, 201: SubmissionSchema})
def create_submission(request, payload: SubmissionCreateInput):
    require_role(request.auth, request.auth.Role.STUDENT)

    if payload.client_submission_id:
        existing_submission = (
            Submission.objects.filter(
                student=request.auth,
                client_submission_id=payload.client_submission_id,
            )
            .select_related("exercise__lesson")
            .prefetch_related("line_results")
            .first()
        )
        if existing_submission is not None:
            return 200, serialize_submission(existing_submission)

    exercise = get_object_or_404(
        Exercise.objects.select_related("lesson"),
        pk=payload.exercise_id,
        lesson__status=Lesson.Status.PUBLISHED,
    )

    with transaction.atomic():
        submission = Submission.objects.create(
            student=request.auth,
            exercise=exercise,
            client_submission_id=payload.client_submission_id,
            transcript_en=payload.transcript_en,
            transcript_pt=payload.transcript_pt,
            status=Submission.Status.PENDING,
        )

        for line_result in payload.line_results or []:
            exercise_line = None
            if line_result.exercise_line_id is not None:
                exercise_line = get_object_or_404(ExerciseLine, pk=line_result.exercise_line_id, exercise=exercise)

            SubmissionLine.objects.create(
                submission=submission,
                exercise_line=exercise_line,
                transcript_en=line_result.transcript_en,
                # O cliente pode enviar heuristicas locais, mas o backend so aceita
                # transcript e vinculacao de linha ate que um processor confiavel rode.
                accuracy_score=None,
                pronunciation_score=None,
                wrong_words=[],
                feedback={},
                status=SubmissionLine.Status.PENDING,
            )

    submission.refresh_from_db()
    return 201, serialize_submission(submission)


@submission_router.get("/submissions/me", auth=jwt_auth, response=list[SubmissionSchema])
def list_my_submissions(request):
    require_role(request.auth, request.auth.Role.STUDENT)

    submissions = Submission.objects.filter(student=request.auth).select_related("exercise__lesson").prefetch_related("line_results")
    return [serialize_submission(submission) for submission in submissions.order_by("-created_at")]
