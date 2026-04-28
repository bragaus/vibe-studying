"""Modelos do app de contas.

O User foi customizado logo no inicio do projeto porque trocar o modelo de usuario
depois costuma ser caro no Django.
"""

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
