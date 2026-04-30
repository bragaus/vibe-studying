from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('learning', '0002_lesson_difficulty_lesson_tags_and_more'),
    ]

    operations = [
        migrations.AddField(
            model_name='submission',
            name='client_submission_id',
            field=models.CharField(blank=True, max_length=64, null=True),
        ),
        migrations.AddConstraint(
            model_name='submission',
            constraint=models.UniqueConstraint(
                condition=models.Q(('client_submission_id__isnull', False)),
                fields=('student', 'client_submission_id'),
                name='unique_student_client_submission_id',
            ),
        ),
    ]
