from django.contrib import admin

from learning.models import Exercise, Lesson, Submission


@admin.register(Lesson)
class LessonAdmin(admin.ModelAdmin):
    list_display = ("title", "teacher", "content_type", "source_type", "status", "created_at")
    list_filter = ("content_type", "source_type", "status")
    search_fields = ("title", "description", "teacher__email")
    prepopulated_fields = {"slug": ("title",)}


@admin.register(Exercise)
class ExerciseAdmin(admin.ModelAdmin):
    list_display = ("lesson", "exercise_type", "max_score", "created_at")
    list_filter = ("exercise_type",)
    search_fields = ("lesson__title", "expected_phrase_en", "expected_phrase_pt")


@admin.register(Submission)
class SubmissionAdmin(admin.ModelAdmin):
    list_display = ("student", "exercise", "status", "final_score", "processed_at", "created_at")
    list_filter = ("status",)
    search_fields = ("student__email", "exercise__lesson__title", "transcript_en", "transcript_pt")
