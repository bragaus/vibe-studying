from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("learning", "0005_lesson_media_manifest_and_music_line_meta"),
    ]

    operations = [
        migrations.CreateModel(
            name="MusicCatalogEntry",
            fields=[
                ("id", models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name="ID")),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("normalized_key", models.CharField(max_length=255, unique=True)),
                ("track_title", models.CharField(max_length=255)),
                ("artist_name", models.CharField(max_length=255)),
                ("source_provider", models.CharField(default="letras", max_length=30)),
                ("source_url", models.URLField(blank=True, max_length=500)),
                ("translation_url", models.URLField(blank=True, max_length=500)),
                ("listen_url", models.URLField(blank=True, max_length=500)),
                ("preview_audio_url", models.URLField(blank=True, max_length=500)),
                ("youtube_url", models.URLField(blank=True, max_length=500)),
                ("cover_image_url", models.URLField(blank=True, max_length=500)),
                ("language_code", models.CharField(blank=True, default="", max_length=20)),
                ("duration_ms", models.PositiveIntegerField(default=0)),
                ("lyrics_manifest", models.JSONField(blank=True, default=dict)),
                (
                    "status",
                    models.CharField(
                        choices=[("pending", "Pending"), ("ready", "Ready"), ("failed", "Failed")],
                        default="pending",
                        max_length=20,
                    ),
                ),
                ("last_error", models.TextField(blank=True)),
                ("last_synced_at", models.DateTimeField(blank=True, null=True)),
            ],
            options={
                "ordering": ["artist_name", "track_title"],
            },
        ),
    ]
