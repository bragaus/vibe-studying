"""Managers customizados do app accounts.

No Django, o manager concentra a logica de criacao de objetos e consultas comuns.
Aqui ele garante que o login principal continue sendo por e-mail.
"""

from django.contrib.auth.models import UserManager as DjangoUserManager
from django.utils.text import slugify


class UserManager(DjangoUserManager):
    use_in_migrations = True

    def _build_unique_username(self, email: str, username: str | None = None) -> str:
        # Mesmo autenticando por e-mail, AbstractUser ainda espera username.
        # Por isso geramos um automaticamente a partir do e-mail.
        base_value = username or email.split("@", 1)[0]
        base = slugify(base_value) or "user"
        candidate = base[:150]
        suffix = 1

        while self.model.objects.filter(username=candidate).exists():
            suffix_str = f"-{suffix}"
            candidate = f"{base[:150 - len(suffix_str)]}{suffix_str}"
            suffix += 1

        return candidate

    def _create_user(self, email, password, **extra_fields):
        # Este metodo centraliza o fluxo usado tanto por create_user quanto create_superuser.
        if not email:
            raise ValueError("The email field must be set.")

        email = self.normalize_email(email)
        username = self._build_unique_username(email, extra_fields.pop("username", None))
        user = self.model(email=email, username=username, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, email, password=None, **extra_fields):
        # Usuario comum nasce sem privilegios administrativos.
        extra_fields.setdefault("is_staff", False)
        extra_fields.setdefault("is_superuser", False)
        extra_fields.setdefault("role", self.model.Role.STUDENT)
        return self._create_user(email, password, **extra_fields)

    def create_superuser(self, email, password=None, **extra_fields):
        # Superuser precisa vir com as flags administrativas ligadas.
        extra_fields.setdefault("is_staff", True)
        extra_fields.setdefault("is_superuser", True)
        extra_fields.setdefault("role", self.model.Role.ADMIN)

        if extra_fields.get("is_staff") is not True:
            raise ValueError("Superuser must have is_staff=True.")
        if extra_fields.get("is_superuser") is not True:
            raise ValueError("Superuser must have is_superuser=True.")

        return self._create_user(email, password, **extra_fields)
