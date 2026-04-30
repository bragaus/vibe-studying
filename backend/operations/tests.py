from datetime import timedelta

from django.core import mail
from django.test import TestCase, override_settings
from django.utils import timezone

from accounts.models import StudentProfile, User
from learning.models import Exercise, Lesson, Submission
from operations.models import EmailDelivery
from operations.tasks import deliver_email_task, run_operational_checks_task, schedule_inactivity_reminders_task


@override_settings(EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend")
class OperationsTests(TestCase):
    def test_health_endpoint_returns_component_statuses(self):
        response = self.client.get("/api/health")

        self.assertEqual(response.status_code, 200)
        payload = response.json()
        self.assertEqual(payload["status"], "ok")
        self.assertIn("database", payload["components"])
        self.assertIn("cache", payload["components"])
        self.assertIn("broker", payload["components"])

    def test_deliver_email_task_marks_delivery_as_sent(self):
        delivery = EmailDelivery.objects.create(
            recipient_email="ops@example.com",
            template_key=EmailDelivery.TemplateKey.OPS_ALERT,
            payload={"title": "Teste", "lines": ["linha 1"]},
            source="tests",
        )

        deliver_email_task(delivery.pk)
        delivery.refresh_from_db()

        self.assertEqual(delivery.status, EmailDelivery.Status.SENT)
        self.assertEqual(len(mail.outbox), 1)
        self.assertIn("Teste", mail.outbox[0].subject)

    @override_settings(REMINDER_INACTIVITY_HOURS=24)
    def test_inactivity_scheduler_creates_single_daily_reminder(self):
        user = User.objects.create_user(
            email="inactive@example.com",
            password="StrongPass123!",
            role=User.Role.STUDENT,
            first_name="Ina",
        )
        profile = StudentProfile.objects.create(user=user, onboarding_completed=True)
        StudentProfile.objects.filter(pk=profile.pk).update(updated_at=timezone.now() - timedelta(hours=30))

        first_run = schedule_inactivity_reminders_task()
        second_run = schedule_inactivity_reminders_task()

        self.assertEqual(first_run["count"], 1)
        self.assertEqual(second_run["count"], 0)
        self.assertEqual(EmailDelivery.objects.filter(template_key=EmailDelivery.TemplateKey.INACTIVITY_REMINDER).count(), 1)

    @override_settings(
        ALERT_EMAIL_RECIPIENTS=["ops@example.com"],
        OPERATIONS_PENDING_EMAIL_MINUTES=10,
        OPERATIONS_PENDING_EMAIL_THRESHOLD=1,
        OPERATIONS_PENDING_SUBMISSION_HOURS=1,
        OPERATIONS_PENDING_SUBMISSION_THRESHOLD=1,
    )
    def test_operational_checks_create_alert_email_when_thresholds_are_exceeded(self):
        stale_delivery = EmailDelivery.objects.create(
            recipient_email="student@example.com",
            template_key=EmailDelivery.TemplateKey.STUDENT_WELCOME,
            status=EmailDelivery.Status.PENDING,
            scheduled_for=timezone.now() - timedelta(minutes=30),
            source="tests",
        )
        EmailDelivery.objects.filter(pk=stale_delivery.pk).update(created_at=timezone.now() - timedelta(minutes=30))

        student = User.objects.create_user(
            email="student@example.com",
            password="StrongPass123!",
            role=User.Role.STUDENT,
        )
        teacher = User.objects.create_user(
            email="teacher@example.com",
            password="StrongPass123!",
            role=User.Role.TEACHER,
        )
        lesson = Lesson.objects.create(
            teacher=teacher,
            title="Pending Review",
            description="",
            content_type=Lesson.ContentType.CHARGE,
            source_type=Lesson.SourceType.EXTERNAL_LINK,
            media_url="https://example.com/pending.png",
            status=Lesson.Status.PUBLISHED,
        )
        exercise = Exercise.objects.create(
            lesson=lesson,
            instruction_text="Repita",
            expected_phrase_en="Hello",
            expected_phrase_pt="Ola",
        )
        stale_submission = Submission.objects.create(student=student, exercise=exercise, status=Submission.Status.PENDING)
        Submission.objects.filter(pk=stale_submission.pk).update(created_at=timezone.now() - timedelta(hours=3))

        result = run_operational_checks_task()

        self.assertGreaterEqual(len(result["issues"]), 2)
        self.assertEqual(EmailDelivery.objects.filter(template_key=EmailDelivery.TemplateKey.OPS_ALERT).count(), 1)
