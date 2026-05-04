"""Modelos do app de contas.

O User foi customizado logo no inicio do projeto porque trocar o modelo de usuario
depois costuma ser caro no Django.
"""

from django.conf import settings
from django.contrib.auth.models import AbstractUser
from django.db import models
from django.utils.translation import gettext_lazy as _

from accounts.managers import UserManager


class User(AbstractUser):
    """Usuario unico do sistema para aluno, professor e admin."""

    class Role(models.TextChoices):
        STUDENT = "student", _("Student")
        TEACHER = "teacher", _("Teacher")
        ADMIN = "admin", _("Admin")

    email = models.EmailField(_("email address"), unique=True)
    # O papel define o que o usuario pode fazer na plataforma.
    role = models.CharField(max_length=20, choices=Role.choices, default=Role.STUDENT)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    # Aqui dizemos ao Django para autenticar usando email em vez de username.
    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = []

    objects = UserManager()

    class Meta:
        ordering = ["email"]

    def __str__(self) -> str:
        return self.email


class StudentProfile(models.Model):
    """Preferencias e estado de onboarding do aluno mobile."""

    class EnglishLevel(models.TextChoices):
        BEGINNER = "beginner", _("Beginner")
        INTERMEDIATE = "intermediate", _("Intermediate")
        ADVANCED = "advanced", _("Advanced")

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="student_profile",
    )
    onboarding_completed = models.BooleanField(default=False)
    english_level = models.CharField(
        max_length=20,
        choices=EnglishLevel.choices,
        default=EnglishLevel.BEGINNER,
    )
    bio = models.TextField(blank=True, default="", max_length=280)
    avatar_image = models.FileField(upload_to="student-avatars/", blank=True, null=True)
    favorite_songs = models.JSONField(default=list, blank=True)
    favorite_movies = models.JSONField(default=list, blank=True)
    favorite_series = models.JSONField(default=list, blank=True)
    favorite_anime = models.JSONField(default=list, blank=True)
    favorite_artists = models.JSONField(default=list, blank=True)
    favorite_genres = models.JSONField(default=list, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["user__email"]

    def __str__(self) -> str:
        return f"Profile<{self.user.email}>"


class StudentPost(models.Model):
    """Post curto do aluno para o mural social da plataforma."""

    profile = models.ForeignKey(StudentProfile, on_delete=models.CASCADE, related_name="posts")
    content = models.TextField(max_length=1200)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["-created_at", "-id"]

    def __str__(self) -> str:
        return f"Post<{self.profile.user.email}:{self.id}>"


class StudentPostEnergy(models.Model):
    """Equivalente ao like, mas com a linguagem de energia do produto."""

    post = models.ForeignKey(StudentPost, on_delete=models.CASCADE, related_name="energies")
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="post_energies")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["post", "user"], name="unique_student_post_energy"),
        ]
        ordering = ["-created_at", "-id"]

    def __str__(self) -> str:
        return f"Energy<{self.user.email}:{self.post_id}>"


class StudentPostComment(models.Model):
    """Comentario textual em um post do mural do aluno."""

    post = models.ForeignKey(StudentPost, on_delete=models.CASCADE, related_name="comments")
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="post_comments")
    content = models.TextField(max_length=600)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["created_at", "id"]

    def __str__(self) -> str:
        return f"Comment<{self.user.email}:{self.post_id}:{self.id}>"


class WaitlistSignup(models.Model):
    """Captura de interesse da landing publica."""

    email = models.EmailField(unique=True)
    source = models.CharField(max_length=50, default="landing_page")
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ["-created_at"]

    def __str__(self) -> str:
        return self.email


class SocialAccount(models.Model):
    """Vinculo entre usuario local e identidade OAuth externa."""

    class Provider(models.TextChoices):
        GOOGLE = "google", _("Google")
        GITHUB = "github", _("GitHub")

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="social_accounts",
    )
    provider = models.CharField(max_length=20, choices=Provider.choices)
    provider_user_id = models.CharField(max_length=255)
    email = models.EmailField(blank=True)
    avatar_url = models.URLField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["provider", "provider_user_id"]
        constraints = [
            models.UniqueConstraint(fields=["provider", "provider_user_id"], name="unique_social_provider_identity"),
            models.UniqueConstraint(fields=["user", "provider"], name="unique_social_provider_per_user"),
        ]

    def __str__(self) -> str:
        return f"{self.provider}<{self.user.email}>"


class TelegramIdentity(models.Model):
    """Canal Telegram vinculado para confirmacao de login web."""

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="telegram_identity",
    )
    chat_id = models.BigIntegerField(unique=True)
    username = models.CharField(max_length=255, blank=True)
    first_name = models.CharField(max_length=255, blank=True)
    last_name = models.CharField(max_length=255, blank=True)
    is_active = models.BooleanField(default=True)
    linked_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ["user__email"]

    def __str__(self) -> str:
        return f"Telegram<{self.user.email}>"
