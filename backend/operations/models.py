from django.db import models
from django.utils import timezone
from django.utils.translation import gettext_lazy as _


class TimeStampedModel(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


class EmailDelivery(TimeStampedModel):
    class TemplateKey(models.TextChoices):
        WAITLIST_WELCOME = "waitlist_welcome", _("Waitlist Welcome")
        STUDENT_WELCOME = "student_welcome", _("Student Welcome")
        INACTIVITY_REMINDER = "inactivity_reminder", _("Inactivity Reminder")
        OPS_ALERT = "ops_alert", _("Operations Alert")

    class Status(models.TextChoices):
        PENDING = "pending", _("Pending")
        PROCESSING = "processing", _("Processing")
        SENT = "sent", _("Sent")
        FAILED = "failed", _("Failed")
        CANCELLED = "cancelled", _("Cancelled")

    recipient_email = models.EmailField()
    template_key = models.CharField(max_length=50, choices=TemplateKey.choices)
    subject = models.CharField(max_length=255, blank=True)
    payload = models.JSONField(default=dict, blank=True)
    source = models.CharField(max_length=100, blank=True)
    dedupe_key = models.CharField(max_length=255, null=True, blank=True, unique=True)
    scheduled_for = models.DateTimeField(default=timezone.now, db_index=True)
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING, db_index=True)
    attempts_count = models.PositiveSmallIntegerField(default=0)
    last_attempt_at = models.DateTimeField(null=True, blank=True)
    sent_at = models.DateTimeField(null=True, blank=True)
    last_error = models.TextField(blank=True)
    provider_message_id = models.CharField(max_length=255, blank=True)

    class Meta:
        ordering = ["-created_at"]
        indexes = [
            models.Index(fields=["status", "scheduled_for"]),
            models.Index(fields=["template_key", "recipient_email"]),
        ]

    def __str__(self) -> str:
        return f"{self.template_key}<{self.recipient_email}>"
