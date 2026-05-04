"""Tasks assicronas do dominio de learning."""

import logging

from celery import shared_task
from celery.exceptions import CeleryError
from django.conf import settings
from django.contrib.auth import get_user_model
from django.utils import timezone

from accounts.models import StudentProfile
from learning.models import Lesson, PersonalizedFeedJob
from learning.services.personalization import (
    PersonalizationError,
    build_profile_signature,
    generate_and_store_personalized_lessons,
)


logger = logging.getLogger(__name__)


def is_personalized_feed_async_available() -> bool:
    if settings.CELERY_TASK_ALWAYS_EAGER:
        return True

    broker_url = (settings.CELERY_BROKER_URL or "").strip()
    if not broker_url or broker_url == "memory://":
        return False

    try:
        inspector = bootstrap_personalized_feed_task.app.control.inspect(timeout=0.5)
        ping_response = inspector.ping() if inspector is not None else None
    except Exception:
        return False

    return bool(ping_response)


def mark_personalized_feed_job_unavailable(job: PersonalizedFeedJob, student, *, message: str) -> PersonalizedFeedJob:
    job.status = PersonalizedFeedJob.Status.FAILED
    job.generated_items = count_ready_personalized_lessons(student)
    job.last_error = message
    job.finished_at = timezone.now()
    job.save(
        update_fields=[
            "status",
            "generated_items",
            "last_error",
            "finished_at",
            "updated_at",
        ]
    )
    return job


def reconcile_personalized_feed_job(job: PersonalizedFeedJob | None, student) -> PersonalizedFeedJob | None:
    if job is None:
        return None

    now = timezone.now()
    if job.status == PersonalizedFeedJob.Status.PENDING and job.started_at is None:
        age_seconds = max((now - job.updated_at).total_seconds(), 0)
        if age_seconds >= settings.PERSONALIZED_FEED_PENDING_STALE_SECONDS:
            return mark_personalized_feed_job_unavailable(
                job,
                student,
                message="Personalized bootstrap stalled before execution. Try again from the feed.",
            )

    if job.status == PersonalizedFeedJob.Status.RUNNING and job.started_at is not None:
        running_seconds = max((now - job.started_at).total_seconds(), 0)
        if running_seconds >= settings.PERSONALIZED_FEED_RUNNING_STALE_SECONDS:
            return mark_personalized_feed_job_unavailable(
                job,
                student,
                message="Personalized bootstrap stalled during processing. Try again from the feed.",
            )

    if job.status not in {PersonalizedFeedJob.Status.PENDING, PersonalizedFeedJob.Status.RUNNING}:
        return job

    if is_personalized_feed_async_available():
        return job

    return mark_personalized_feed_job_unavailable(
        job,
        student,
        message="Personalized bootstrap unavailable; opening regular feed.",
    )


def get_or_create_personalized_feed_job(student) -> PersonalizedFeedJob:
    job, _ = PersonalizedFeedJob.objects.get_or_create(
        student=student,
        defaults={"target_items": settings.PERSONALIZED_FEED_TARGET_ITEMS},
    )
    return job


def count_ready_personalized_lessons(student) -> int:
    return Lesson.objects.filter(
        student=student,
        visibility=Lesson.Visibility.PRIVATE,
        generated_by_ai=True,
        status=Lesson.Status.PUBLISHED,
    ).count()


def enqueue_personalized_feed_bootstrap(student_id: int, *, force: bool = False) -> PersonalizedFeedJob:
    user_model = get_user_model()
    student = user_model.objects.get(pk=student_id, role=user_model.Role.STUDENT, is_active=True)
    profile, _ = StudentProfile.objects.get_or_create(user=student)
    signature = build_profile_signature(profile)
    job = get_or_create_personalized_feed_job(student)
    ready_items = count_ready_personalized_lessons(student)

    if not force and job.profile_signature == signature:
        if job.status in {PersonalizedFeedJob.Status.PENDING, PersonalizedFeedJob.Status.RUNNING}:
            return job
        if job.status == PersonalizedFeedJob.Status.DONE and ready_items > 0:
            job.generated_items = ready_items
            job.save(update_fields=["generated_items", "updated_at"])
            return job

    job.status = PersonalizedFeedJob.Status.PENDING
    job.target_items = settings.PERSONALIZED_FEED_TARGET_ITEMS
    job.generated_items = ready_items
    job.profile_signature = signature
    job.last_error = ""
    job.started_at = None
    job.finished_at = None
    job.save(
        update_fields=[
            "status",
            "target_items",
            "generated_items",
            "profile_signature",
            "last_error",
            "started_at",
            "finished_at",
            "updated_at",
        ]
    )

    if not is_personalized_feed_async_available():
        return mark_personalized_feed_job_unavailable(
            job,
            student,
            message="Personalized bootstrap unavailable; opening regular feed.",
        )

    try:
        bootstrap_personalized_feed_task.delay(student.id, force=force)
    except CeleryError:
        return mark_personalized_feed_job_unavailable(
            job,
            student,
            message="Personalized bootstrap unavailable; opening regular feed.",
        )
    except Exception:
        logger.exception(
            "failed to enqueue personalized feed bootstrap",
            extra={"student_id": student.id},
        )
        return mark_personalized_feed_job_unavailable(
            job,
            student,
            message="Personalized bootstrap unavailable; opening regular feed.",
        )

    return job


@shared_task(bind=True, max_retries=1)
def bootstrap_personalized_feed_task(self, student_id: int, force: bool = False):
    user_model = get_user_model()
    student = user_model.objects.get(pk=student_id, role=user_model.Role.STUDENT, is_active=True)
    profile, _ = StudentProfile.objects.get_or_create(user=student)
    job = get_or_create_personalized_feed_job(student)
    signature = build_profile_signature(profile)

    if not force and job.status == PersonalizedFeedJob.Status.DONE and job.profile_signature == signature:
        ready_items = count_ready_personalized_lessons(student)
        if ready_items > 0:
            return {"status": job.status, "generated_items": ready_items}

    started_at = timezone.now()
    job.status = PersonalizedFeedJob.Status.RUNNING
    job.target_items = settings.PERSONALIZED_FEED_TARGET_ITEMS
    job.generated_items = 0
    job.profile_signature = signature
    job.last_error = ""
    job.started_at = started_at
    job.finished_at = None
    job.save(
        update_fields=[
            "status",
            "target_items",
            "generated_items",
            "profile_signature",
            "last_error",
            "started_at",
            "finished_at",
            "updated_at",
        ]
    )

    try:
        generated_items = generate_and_store_personalized_lessons(student, profile, job.target_items)
    except PersonalizationError as exc:
        job.status = PersonalizedFeedJob.Status.FAILED
        job.generated_items = count_ready_personalized_lessons(student)
        job.last_error = str(exc)
        job.finished_at = timezone.now()
        job.save(update_fields=["status", "generated_items", "last_error", "finished_at", "updated_at"])
        logger.warning("personalized feed bootstrap failed", extra={"student_id": student.id, "error": str(exc)})
        return {"status": job.status, "error": str(exc)}
    except Exception as exc:
        job.status = PersonalizedFeedJob.Status.FAILED
        job.generated_items = count_ready_personalized_lessons(student)
        job.last_error = str(exc)
        job.finished_at = timezone.now()
        job.save(update_fields=["status", "generated_items", "last_error", "finished_at", "updated_at"])
        logger.exception("unexpected personalized feed bootstrap error", extra={"student_id": student.id})
        return {"status": job.status, "error": str(exc)}

    job.status = PersonalizedFeedJob.Status.DONE
    job.generated_items = generated_items
    job.last_error = ""
    job.finished_at = timezone.now()
    job.save(update_fields=["status", "generated_items", "last_error", "finished_at", "updated_at"])
    logger.info("personalized feed bootstrap finished", extra={"student_id": student.id, "generated_items": generated_items})
    return {"status": job.status, "generated_items": generated_items}
