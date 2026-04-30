from django.conf import settings
from django.db import transaction
from django.utils import timezone

from operations.models import EmailDelivery


def render_email_delivery(delivery: EmailDelivery) -> tuple[str, str]:
    payload = delivery.payload or {}
    product_name = "Vibe Studying"
    web_url = settings.PUBLIC_WEB_URL

    if delivery.template_key == EmailDelivery.TemplateKey.WAITLIST_WELCOME:
        subject = "Voce entrou na waitlist do Vibe Studying"
        body = (
            f"Ola!\n\n"
            f"Seu e-mail foi registrado na waitlist do {product_name}.\n"
            f"Vamos avisar quando abrirmos novas vagas e entregas.\n\n"
            f"Origem: {payload.get('source', 'landing_page')}\n"
            f"Produto: {web_url}\n"
        )
        return subject, body

    if delivery.template_key == EmailDelivery.TemplateKey.STUDENT_WELCOME:
        first_name = payload.get("first_name") or "Operador"
        subject = "Sua conta no Vibe Studying esta pronta"
        body = (
            f"Ola, {first_name}!\n\n"
            f"Sua conta no {product_name} foi criada com sucesso.\n"
            f"Agora voce ja pode concluir o onboarding e destravar o feed personalizado.\n\n"
            f"Acesse: {web_url}\n"
        )
        return subject, body

    if delivery.template_key == EmailDelivery.TemplateKey.INACTIVITY_REMINDER:
        first_name = payload.get("first_name") or "Operador"
        inactivity_hours = payload.get("inactivity_hours") or settings.REMINDER_INACTIVITY_HOURS
        subject = "Voce tem uma sessao pendente no Vibe Studying"
        body = (
            f"Ola, {first_name}!\n\n"
            f"Faz cerca de {inactivity_hours} horas desde sua ultima atividade.\n"
            f"Seu feed e suas lessons continuam prontos para voce retomar o estudo.\n\n"
            f"Volte em: {web_url}\n"
        )
        return subject, body

    if delivery.template_key == EmailDelivery.TemplateKey.OPS_ALERT:
        title = payload.get("title") or "Alerta operacional"
        lines = payload.get("lines") or []
        body_lines = "\n".join(f"- {line}" for line in lines)
        subject = f"[Vibe Studying] {title}"
        body = (
            f"{title}\n\n"
            f"Detalhes:\n{body_lines or '- sem detalhes'}\n\n"
            f"Ambiente: {payload.get('environment', 'unknown')}\n"
            f"API: {settings.PUBLIC_API_ORIGIN}/api/health\n"
        )
        return subject, body

    return "Notificacao do Vibe Studying", "Entrega gerada sem template configurado."


def queue_email_delivery(
    *,
    recipient_email: str,
    template_key: str,
    payload: dict | None = None,
    source: str = "",
    dedupe_key: str | None = None,
    scheduled_for=None,
) -> tuple[EmailDelivery, bool]:
    if scheduled_for is None:
        scheduled_for = timezone.now()

    defaults = {
        "recipient_email": recipient_email,
        "template_key": template_key,
        "payload": payload or {},
        "source": source,
        "scheduled_for": scheduled_for,
    }

    if dedupe_key:
        delivery, created = EmailDelivery.objects.get_or_create(
            dedupe_key=dedupe_key,
            defaults={**defaults, "dedupe_key": dedupe_key},
        )
    else:
        delivery = EmailDelivery.objects.create(**defaults)
        created = True

    if created and delivery.scheduled_for <= timezone.now():
        from operations.tasks import deliver_email_task

        transaction.on_commit(lambda: deliver_email_task.delay(delivery.pk))

    return delivery, created


def queue_waitlist_welcome_email(signup) -> tuple[EmailDelivery, bool]:
    return queue_email_delivery(
        recipient_email=signup.email,
        template_key=EmailDelivery.TemplateKey.WAITLIST_WELCOME,
        payload={"source": signup.source},
        source="waitlist",
        dedupe_key=f"waitlist-welcome:{signup.pk}",
    )


def queue_student_welcome_email(user) -> tuple[EmailDelivery, bool]:
    return queue_email_delivery(
        recipient_email=user.email,
        template_key=EmailDelivery.TemplateKey.STUDENT_WELCOME,
        payload={"first_name": user.first_name, "user_id": user.pk},
        source="auth.register",
        dedupe_key=f"student-welcome:{user.pk}",
    )


def queue_inactivity_reminder(profile, inactivity_hours: int, dedupe_bucket: str) -> tuple[EmailDelivery, bool]:
    return queue_email_delivery(
        recipient_email=profile.user.email,
        template_key=EmailDelivery.TemplateKey.INACTIVITY_REMINDER,
        payload={
            "first_name": profile.user.first_name,
            "inactivity_hours": inactivity_hours,
            "user_id": profile.user_id,
        },
        source="scheduler.inactivity",
        dedupe_key=f"inactivity-reminder:{profile.user_id}:{dedupe_bucket}",
    )


def queue_operational_alert(recipient_email: str, title: str, lines: list[str], dedupe_key: str) -> tuple[EmailDelivery, bool]:
    return queue_email_delivery(
        recipient_email=recipient_email,
        template_key=EmailDelivery.TemplateKey.OPS_ALERT,
        payload={
            "title": title,
            "lines": lines,
            "environment": settings.RUNTIME_ENVIRONMENT,
        },
        source="operations.alert",
        dedupe_key=dedupe_key,
    )
