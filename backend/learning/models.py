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
        ANIME_CLIP = "anime_clip", _("Anime Clip")

    class SourceType(models.TextChoices):
        UPLOAD = "upload", _("Upload")
        EXTERNAL_LINK = "external_link", _("External Link")

    class Status(models.TextChoices):
        DRAFT = "draft", _("Draft")
        PUBLISHED = "published", _("Published")

    teacher = models.ForeignKey(
        # PROTECT evita apagar professor enquanto houver conteudo ligado a ele.
        settings.AUTH_USER_MODEL,
        on_delete=models.PROTECT,
        related_name="lessons",
    )
    title = models.CharField(max_length=255)
    slug = models.SlugField(max_length=255, unique=True, blank=True)
    description = models.TextField(blank=True)
    content_type = models.CharField(max_length=20, choices=ContentType.choices, default=ContentType.CHARGE)
    source_type = models.CharField(max_length=20, choices=SourceType.choices, default=SourceType.EXTERNAL_LINK)
    media_url = models.URLField(max_length=500)
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

    def __str__(self) -> str:
        return f"{self.student.email} - {self.exercise.lesson.title}"
