from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('accounts', '0002_studentprofile'),
    ]

    operations = [
        migrations.CreateModel(
            name='WaitlistSignup',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('email', models.EmailField(max_length=254, unique=True)),
                ('source', models.CharField(default='landing_page', max_length=50)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
            ],
            options={
                'ordering': ['-created_at'],
            },
        ),
    ]
