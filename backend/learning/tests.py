from django.test import TestCase

from accounts.jwt import create_token_pair
from accounts.models import User
from learning.models import Exercise, Lesson, Submission


class LearningApiTests(TestCase):
    def setUp(self):
        self.teacher = User.objects.create_user(
            email="teacher@example.com",
            password="StrongPass123!",
            role=User.Role.TEACHER,
            first_name="Tea",
            last_name="Cher",
        )
        self.student = User.objects.create_user(
            email="student@example.com",
            password="StrongPass123!",
            role=User.Role.STUDENT,
        )
        self.teacher_token = create_token_pair(self.teacher)["access_token"]
        self.student_token = create_token_pair(self.student)["access_token"]

    def test_teacher_can_create_lesson_and_public_feed_can_read_it(self):
        create_response = self.client.post(
            "/api/teacher/lessons",
            data={
                "title": "Simple Past com Charge",
                "description": "Pratique com uma charge curta.",
                "content_type": Lesson.ContentType.CHARGE,
                "source_type": Lesson.SourceType.EXTERNAL_LINK,
                "media_url": "https://example.com/charge.png",
                "status": Lesson.Status.PUBLISHED,
                "instruction_text": "Leia em ingles e depois em portugues.",
                "expected_phrase_en": "I missed the bus.",
                "expected_phrase_pt": "Eu perdi o onibus.",
                "max_score": 100,
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {self.teacher_token}",
        )

        self.assertEqual(create_response.status_code, 201)
        created_lesson = create_response.json()
        self.assertEqual(created_lesson["status"], Lesson.Status.PUBLISHED)

        feed_response = self.client.get("/api/feed")
        self.assertEqual(feed_response.status_code, 200)
        self.assertEqual(len(feed_response.json()["items"]), 1)
        self.assertEqual(feed_response.json()["items"][0]["slug"], created_lesson["slug"])

        detail_response = self.client.get(f"/api/lessons/{created_lesson['slug']}")
        self.assertEqual(detail_response.status_code, 200)
        self.assertEqual(detail_response.json()["exercise"]["expected_phrase_en"], "I missed the bus.")

    def test_student_can_submit_attempt_and_list_own_submissions(self):
        lesson = Lesson.objects.create(
            teacher=self.teacher,
            title="Listening Drill",
            description="Trecho rapido.",
            content_type=Lesson.ContentType.MOVIE_CLIP,
            source_type=Lesson.SourceType.EXTERNAL_LINK,
            media_url="https://example.com/clip.mp4",
            status=Lesson.Status.PUBLISHED,
        )
        exercise = Exercise.objects.create(
            lesson=lesson,
            instruction_text="Repita a frase.",
            expected_phrase_en="We were on a break.",
            expected_phrase_pt="Nos estavamos dando um tempo.",
            max_score=100,
        )

        create_submission_response = self.client.post(
            "/api/submissions",
            data={
                "exercise_id": exercise.id,
                "transcript_en": "We were on a break",
                "transcript_pt": "Nos estavamos dando um tempo",
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {self.student_token}",
        )

        self.assertEqual(create_submission_response.status_code, 201)
        self.assertEqual(create_submission_response.json()["status"], Submission.Status.PENDING)

        list_response = self.client.get(
            "/api/submissions/me",
            HTTP_AUTHORIZATION=f"Bearer {self.student_token}",
        )
        self.assertEqual(list_response.status_code, 200)
        self.assertEqual(len(list_response.json()), 1)
        self.assertEqual(list_response.json()[0]["lesson_slug"], lesson.slug)
