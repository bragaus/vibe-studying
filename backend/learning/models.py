"""Modelos do dominio de aprendizagem.

Para o MVP, a unidade principal e a Lesson, que representa um item do feed.
Cada Lesson tem um Exercise associado e recebe varias Submissions dos alunos.
"""

from django.conf import settings
from django.db import models
from django.utils.text import slugify
from django.utils.translation import gettext_lazy as _


class TimeStampedModel(models.Model):
    """Mixin reutilizavel para rastrear criacao e atualizacao."""

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


class Lesson(TimeStampedModel):
    """Item de conteudo do feed educacional."""

    class ContentType(models.TextChoices):
        CHARGE = "charge", _("Charge")
        MUSIC = "music", _("Music")
        MOVIE_CLIP = "movie_clip", _("Movie Clip")
        SERIES_CLIP = "series_clip", _("Series Clip")
        ANIME_CLIP = "anime_clip", _("Anime Clip")

    class Difficulty(models.TextChoices):
        EASY = "easy", _("Easy")
        MEDIUM = "medium", _("Medium")
        HARD = "hard", _("Hard")

    class SourceType(models.TextChoices):
        UPLOAD = "upload", _("Upload")
        EXTERNAL_LINK = "external_link", _("External Link")

    class Status(models.TextChoices):
        DRAFT = "draft", _("Draft")
        PUBLISHED = "published", _("Published")

    class Visibility(models.TextChoices):
        PUBLIC = "public", _("Public")
        PRIVATE = "private", _("Private")

    teacher = models.ForeignKey(
        # PROTECT evita apagar professor enquanto houver conteudo ligado a ele.
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="lessons",
    )
    student = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="personalized_lessons",
        null=True,
        blank=True,
    )
    title = models.CharField(max_length=255)
    slug = models.SlugField(max_length=255, unique=True, blank=True)
    description = models.TextField(blank=True)
    content_type = models.CharField(max_length=20, choices=ContentType.choices, default=ContentType.CHARGE)
    source_type = models.CharField(max_length=20, choices=SourceType.choices, default=SourceType.EXTERNAL_LINK)
    difficulty = models.CharField(max_length=20, choices=Difficulty.choices, default=Difficulty.EASY)
    tags = models.JSONField(default=list, blank=True)
    media_url = models.URLField(max_length=500)
    cover_image_url = models.URLField(max_length=500, blank=True)
    source_url = models.URLField(max_length=500, blank=True)
    source_title = models.CharField(max_length=255, blank=True)
    source_domain = models.CharField(max_length=255, blank=True)
    match_reason_hint = models.CharField(max_length=255, blank=True)
    generated_by_ai = models.BooleanField(default=False)
    visibility = models.CharField(max_length=20, choices=Visibility.choices, default=Visibility.PUBLIC)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.DRAFT)
    published_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return self.title

    def save(self, *args, **kwargs):
        # Gera slug automaticamente na primeira gravacao.
        if not self.slug:
            self.slug = self._build_unique_slug()
        super().save(*args, **kwargs)

    def _build_unique_slug(self) -> str:
        # Mantem uma URL amigavel sem colidir com outra lesson de mesmo titulo.
        base = slugify(self.title) or "lesson"
        candidate = base[:255]
        suffix = 1

        while Lesson.objects.filter(slug=candidate).exclude(pk=self.pk).exists():
            suffix_str = f"-{suffix}"
            candidate = f"{base[:255 - len(suffix_str)]}{suffix_str}"
            suffix += 1

        return candidate


class Exercise(TimeStampedModel):
    """Desafio associado a uma lesson.

    No MVP existe um exercise por lesson para simplificar o fluxo do feed.
    """

    class ExerciseType(models.TextChoices):
        PRONUNCIATION = "pronunciation", _("Pronunciation")

    lesson = models.OneToOneField(Lesson, on_delete=models.CASCADE, related_name="exercise")
    exercise_type = models.CharField(max_length=30, choices=ExerciseType.choices, default=ExerciseType.PRONUNCIATION)
    instruction_text = models.TextField()
    expected_phrase_en = models.CharField(max_length=255)
    expected_phrase_pt = models.CharField(max_length=255)
    max_score = models.PositiveSmallIntegerField(default=100)

    class Meta:
        ordering = ["lesson__title"]

    def __str__(self) -> str:
        return f"{self.lesson.title} - {self.get_exercise_type_display()}"


class ExerciseLine(TimeStampedModel):
    """Linha individual da sessao estilo karaoke/Guitar Hero."""

    exercise = models.ForeignKey(Exercise, on_delete=models.CASCADE, related_name="lines")
    order = models.PositiveIntegerField(default=1)
    text_en = models.CharField(max_length=255)
    text_pt = models.CharField(max_length=255, blank=True)
    phonetic_hint = models.CharField(max_length=255, blank=True)
    reference_start_ms = models.PositiveIntegerField(default=0)
    reference_end_ms = models.PositiveIntegerField(default=0)

    class Meta:
        ordering = ["order", "id"]
        constraints = [
            models.UniqueConstraint(fields=["exercise", "order"], name="unique_exercise_line_order"),
        ]

    def __str__(self) -> str:
        return f"{self.exercise.lesson.title} [{self.order}]"


class Submission(TimeStampedModel):
    """Tentativa enviada pelo aluno para um exercise."""

    class Status(models.TextChoices):
        PENDING = "pending", _("Pending")
        PROCESSED = "processed", _("Processed")
        FAILED = "failed", _("Failed")

    student = models.ForeignKey(
        # Se o aluno for removido, suas tentativas deixam de fazer sentido e podem sair junto.
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="submissions",
    )
    exercise = models.ForeignKey(Exercise, on_delete=models.CASCADE, related_name="submissions")
    client_submission_id = models.CharField(max_length=64, null=True, blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    transcript_en = models.TextField(blank=True)
    transcript_pt = models.TextField(blank=True)
    score_en = models.PositiveSmallIntegerField(null=True, blank=True)
    score_pt = models.PositiveSmallIntegerField(null=True, blank=True)
    final_score = models.PositiveSmallIntegerField(null=True, blank=True)
    processed_at = models.DateTimeField(null=True, blank=True)
    # Esses campos de score ficam vazios ate a avaliacao automatica ser executada.

    class Meta:
        ordering = ["-created_at"]
        constraints = [
            models.UniqueConstraint(
                fields=["student", "client_submission_id"],
                condition=models.Q(client_submission_id__isnull=False),
                name="unique_student_client_submission_id",
            ),
        ]

    def __str__(self) -> str:
        return f"{self.student.email} - {self.exercise.lesson.title}"


class SubmissionLine(TimeStampedModel):
    """Resultado por linha dentro de uma tentativa completa."""

    class Status(models.TextChoices):
        PENDING = "pending", _("Pending")
        MATCHED = "matched", _("Matched")
        NEEDS_COACHING = "needs_coaching", _("Needs Coaching")

    submission = models.ForeignKey(Submission, on_delete=models.CASCADE, related_name="line_results")
    exercise_line = models.ForeignKey(
        ExerciseLine,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="submission_lines",
    )
    transcript_en = models.TextField(blank=True)
    accuracy_score = models.PositiveSmallIntegerField(null=True, blank=True)
    pronunciation_score = models.PositiveSmallIntegerField(null=True, blank=True)
    wrong_words = models.JSONField(default=list, blank=True)
    feedback = models.JSONField(default=dict, blank=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)

    class Meta:
        ordering = ["submission_id", "id"]

    def __str__(self) -> str:
        return f"LineResult<{self.submission_id}:{self.exercise_line_id}>"


class PersonalizedFeedJob(TimeStampedModel):
    """Estado da geracao do feed individual do aluno."""

    class Status(models.TextChoices):
        IDLE = "idle", _("Idle")
        PENDING = "pending", _("Pending")
        RUNNING = "running", _("Running")
        DONE = "done", _("Done")
        FAILED = "failed", _("Failed")

    student = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="personalized_feed_job",
    )
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.IDLE)
    target_items = models.PositiveSmallIntegerField(default=8)
    generated_items = models.PositiveSmallIntegerField(default=0)
    profile_signature = models.CharField(max_length=64, blank=True)
    last_error = models.TextField(blank=True)
    started_at = models.DateTimeField(null=True, blank=True)
    finished_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ["student__email"]

    def __str__(self) -> str:
        return f"PersonalizedFeedJob<{self.student.email}:{self.status}>"
