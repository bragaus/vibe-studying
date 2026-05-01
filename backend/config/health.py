from datetime import timedelta

import redis
from django.conf import settings
from django.core.cache import caches
from django.db import connections
from django.utils import timezone


def _component(status: str, detail: str, **extra) -> dict:
    payload = {"status": status, "detail": detail}
    payload.update(extra)
    return payload


def _check_database() -> tuple[bool, dict]:
    try:
        with connections["default"].cursor() as cursor:
            cursor.execute("SELECT 1")
            cursor.fetchone()
    except Exception as exc:
        return False, _component("error", str(exc))

    return True, _component("ok", "database reachable")


def _check_cache() -> tuple[bool, dict]:
    try:
        cache = caches["default"]
        probe_key = "health:cache:probe"
        cache.set(probe_key, "ok", timeout=5)
        cache_value = cache.get(probe_key)
        cache.delete(probe_key)
        if cache_value != "ok":
            return False, _component("error", "cache probe returned unexpected value")
    except Exception as exc:
        return False, _component("error", str(exc), backend=settings.CACHES["default"]["BACKEND"])

    return True, _component("ok", "cache reachable", backend=settings.CACHES["default"]["BACKEND"])


def _check_broker() -> tuple[bool, dict]:
    broker_url = settings.CELERY_BROKER_URL
    if not broker_url or broker_url == "memory://":
        return True, _component("not_configured", "celery broker using in-memory transport", broker=broker_url)

    if not broker_url.startswith(("redis://", "rediss://")):
        return True, _component("not_configured", "broker health check only probes redis brokers", broker=broker_url)

    try:
        redis.from_url(broker_url).ping()
    except Exception as exc:
        return False, _component("error", str(exc), broker=broker_url)

    return True, _component("ok", "broker reachable", broker=broker_url)


def build_health_report() -> tuple[int, dict]:
    database_ok, database_payload = _check_database()
    cache_ok, cache_payload = _check_cache()
    broker_ok, broker_payload = _check_broker()

    email_backlog_cutoff = timezone.now() - timedelta(minutes=settings.OPERATIONS_PENDING_EMAIL_MINUTES)

    payload = {
        "status": "ok" if all([database_ok, cache_ok, broker_ok]) else "degraded",
        "service": "vibe-studying-backend",
        "timestamp": timezone.now().isoformat(),
        "components": {
            "database": database_payload,
            "cache": cache_payload,
            "broker": broker_payload,
            "monitoring": _component(
                "ok",
                "operational thresholds loaded",
                alert_recipients=settings.ALERT_EMAIL_RECIPIENTS,
                stale_email_minutes=settings.OPERATIONS_PENDING_EMAIL_MINUTES,
                stale_submission_hours=settings.OPERATIONS_PENDING_SUBMISSION_HOURS,
                email_backlog_cutoff=email_backlog_cutoff.isoformat(),
            ),
        },
    }

    return (200 if payload["status"] == "ok" else 503), payload
