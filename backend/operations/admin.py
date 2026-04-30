from django.contrib import admin

from operations.models import EmailDelivery


@admin.register(EmailDelivery)
class EmailDeliveryAdmin(admin.ModelAdmin):
    list_display = (
        "recipient_email",
        "template_key",
        "status",
        "scheduled_for",
        "sent_at",
        "attempts_count",
    )
    list_filter = ("template_key", "status")
    search_fields = ("recipient_email", "dedupe_key", "subject")
    readonly_fields = ("created_at", "updated_at", "last_attempt_at", "sent_at", "provider_message_id")
