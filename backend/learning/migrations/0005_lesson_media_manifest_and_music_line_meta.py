from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("learning", "0004_lesson_cover_image_url_lesson_generated_by_ai_and_more"),
    ]

    operations = [
        migrations.AddField(
            model_name="lesson",
            name="media_manifest",
            field=models.JSONField(blank=True, default=dict),
        ),
        migrations.AddField(
            model_name="exerciseline",
            name="artist_name",
            field=models.CharField(blank=True, max_length=255),
        ),
        migrations.AddField(
            model_name="exerciseline",
            name="segment_index",
            field=models.PositiveSmallIntegerField(default=0),
        ),
        migrations.AddField(
            model_name="exerciseline",
            name="track_title",
            field=models.CharField(blank=True, max_length=255),
        ),
    ]
