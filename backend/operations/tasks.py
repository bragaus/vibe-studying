import logging
from datetime import timedelta

from celery import shared_task
from django.conf import settings
from django.core.mail import send_mail
from django.db.models import Max
from django.utils import timezone

from accounts.models import StudentProfile, User
from learning.models import Submission
from operations.emailing import queue_inactivity_reminder, queue_operational_alert, render_email_delivery
from operations.models import EmailDelivery


logger = logging.getLogger(__name__)


@shared_task(bind=True, max_retries=3)
def deliver_email_task(self, delivery_id: int):
    delivery = EmailDelivery.objects.get(pk=delivery_id)
    if delivery.status in {EmailDelivery.Status.SENT, EmailDelivery.Status.CANCELLED}:
        return {"status": delivery.status, "delivery_id": delivery.pk}

    delivery.status = EmailDelivery.Status.PROCESSING
    delivery.attempts_count += 1
    delivery.last_attempt_at = timezone.now()
    delivery.save(update_fields=["status", "attempts_count", "last_attempt_at", "updated_at"])

    subject, body = render_email_delivery(delivery)

    try:
        send_mail(
            subject,
            body,
            settings.DEFAULT_FROM_EMAIL,
            [delivery.recipient_email],
            fail_silently=False,
        )
    except Exception as exc:
        delivery.last_error = str(exc)
        if self.request.retries >= self.max_retries:
            delivery.status = EmailDelivery.Status.FAILED
            delivery.save(update_fields=["status", "last_error", "updated_at"])
            logger.exception("email delivery failed permanently", extra={"delivery_id": delivery.pk})
            raise

        delivery.status = EmailDelivery.Status.PENDING
        delivery.save(update_fields=["status", "last_error", "updated_at"])
        countdown = min(60 * (2 ** self.request.retries), 900)
        raise self.retry(exc=exc, countdown=countdown)

    delivery.subject = subject
    delivery.status = EmailDelivery.Status.SENT
    delivery.sent_at = timezone.now()
    delivery.last_error = ""
    delivery.provider_message_id = f"django-mail-{delivery.pk}-{delivery.attempts_count}"
    delivery.save(
        update_fields=[
            "subject",
            "status",
            "sent_at",
            "last_error",
            "provider_message_id",
            "updated_at",
        ]
    )
    logger.info("email delivery sent", extra={"delivery_id": delivery.pk, "template_key": delivery.template_key})
    return {"status": delivery.status, "delivery_id": delivery.pk}


@shared_task
def dispatch_due_email_deliveries_task(limit: int = 50):
    due_deliveries = list(
        EmailDelivery.objects.filter(
            status=EmailDelivery.Status.PENDING,
            scheduled_for__lte=timezone.now(),
        )
        .order_by("scheduled_for")[:limit]
        .values_list("id", flat=True)
    )

    for delivery_id in due_deliveries:
        deliver_email_task.delay(delivery_id)

    logger.info("dispatched due email deliveries", extra={"count": len(due_deliveries)})
    return {"count": len(due_deliveries)}


@shared_task
def schedule_inactivity_reminders_task():
    inactivity_cutoff = timezone.now() - timedelta(hours=settings.REMINDER_INACTIVITY_HOURS)
    profiles = (
        StudentProfile.objects.filter(
            onboarding_completed=True,
            user__is_active=True,
            user__role=User.Role.STUDENT,
        )
        .select_related("user")
        .annotate(last_submission_at=Max("user__submissions__created_at"))
    )

    created_count = 0
    dedupe_bucket = timezone.localdate().isoformat()
    for profile in profiles:
        last_activity_at = profile.last_submission_at or profile.updated_at or profile.created_at
        if last_activity_at and last_activity_at > inactivity_cutoff:
            continue

        _, created = queue_inactivity_reminder(
            profile,
            inactivity_hours=settings.REMINDER_INACTIVITY_HOURS,
            dedupe_bucket=dedupe_bucket,
        )
        if created:
            created_count += 1

    logger.info("scheduled inactivity reminders", extra={"count": created_count})
    return {"count": created_count}


@shared_task
def run_operational_checks_task():
    issues: list[str] = []

    stale_email_cutoff = timezone.now() - timedelta(minutes=settings.OPERATIONS_PENDING_EMAIL_MINUTES)
    stale_email_count = EmailDelivery.objects.filter(
        status=EmailDelivery.Status.PENDING,
        scheduled_for__lt=stale_email_cutoff,
    ).count()
    if stale_email_count >= settings.OPERATIONS_PENDING_EMAIL_THRESHOLD:
        issues.append(
            f"fila de e-mails com {stale_email_count} entregas pendentes alem de {settings.OPERATIONS_PENDING_EMAIL_MINUTES} minutos"
        )

    failed_email_count = EmailDelivery.objects.filter(
        status=EmailDelivery.Status.FAILED,
        updated_at__gte=timezone.now() - timedelta(hours=24),
    ).count()
    if failed_email_count >= settings.OPERATIONS_FAILED_EMAIL_THRESHOLD:
        issues.append(f"{failed_email_count} entregas de e-mail falharam nas ultimas 24 horas")

    stale_submission_cutoff = timezone.now() - timedelta(hours=settings.OPERATIONS_PENDING_SUBMISSION_HOURS)
    stale_submission_count = Submission.objects.filter(
        status=Submission.Status.PENDING,
        created_at__lt=stale_submission_cutoff,
    ).count()
    if stale_submission_count >= settings.OPERATIONS_PENDING_SUBMISSION_THRESHOLD:
        issues.append(
            f"{stale_submission_count} submissions ainda estao pendentes apos {settings.OPERATIONS_PENDING_SUBMISSION_HOURS} horas"
        )

    if not issues:
        logger.info("operational checks completed without issues")
        return {"issues": []}

    logger.warning("operational issues detected", extra={"issues": issues})

    if settings.OPERATIONS_ALERTS_ENABLED and settings.ALERT_EMAIL_RECIPIENTS:
        bucket = timezone.now().strftime("%Y%m%d%H")
        for recipient in settings.ALERT_EMAIL_RECIPIENTS:
            queue_operational_alert(
                recipient,
                title="Alertas operacionais detectados",
                lines=issues,
                dedupe_key=f"ops-alert:{recipient}:{bucket}",
            )

    return {"issues": issues}
