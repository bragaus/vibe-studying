from django.test import TestCase

from accounts.jwt import create_token_pair
from accounts.models import StudentProfile, User
from learning.models import Exercise, ExerciseLine, Lesson, Submission


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
        self.assertEqual(len(detail_response.json()["exercise"]["lines"]), 1)
        self.assertEqual(detail_response.json()["exercise"]["lines"][0]["text_en"], "I missed the bus.")

    def test_student_can_submit_attempt_and_list_own_submissions(self):
        lesson = Lesson.objects.create(
            teacher=self.teacher,
            title="Listening Drill",
            description="Trecho rapido.",
            content_type=Lesson.ContentType.MOVIE_CLIP,
            source_type=Lesson.SourceType.EXTERNAL_LINK,
            tags=["friends", "series"],
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
        line = ExerciseLine.objects.create(
            exercise=exercise,
            order=1,
            text_en="We were on a break.",
            text_pt="Nos estavamos dando um tempo.",
            phonetic_hint="uir uer on a breik",
        )

        create_submission_response = self.client.post(
            "/api/submissions",
            data={
                "exercise_id": exercise.id,
                "client_submission_id": "offline-sync-001",
                "transcript_en": "We were on a break",
                "transcript_pt": "Nos estavamos dando um tempo",
                "line_results": [
                    {
                        "exercise_line_id": line.id,
                        "transcript_en": "We were on a break",
                        "accuracy_score": 86,
                        "pronunciation_score": 81,
                        "wrong_words": ["break"],
                        "feedback": {"coach_message": "Abra mais o ditongo de break."},
                        "status": "needs_coaching",
                    }
                ],
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {self.student_token}",
        )

        self.assertEqual(create_submission_response.status_code, 201)
        self.assertEqual(create_submission_response.json()["status"], Submission.Status.PENDING)
        self.assertEqual(create_submission_response.json()["client_submission_id"], "offline-sync-001")
        self.assertEqual(len(create_submission_response.json()["line_results"]), 1)
        self.assertEqual(create_submission_response.json()["line_results"][0]["wrong_words"], [])
        self.assertEqual(create_submission_response.json()["line_results"][0]["status"], Submission.Status.PENDING)
        self.assertIsNone(create_submission_response.json()["line_results"][0]["accuracy_score"])

        list_response = self.client.get(
            "/api/submissions/me",
            HTTP_AUTHORIZATION=f"Bearer {self.student_token}",
        )
        self.assertEqual(list_response.status_code, 200)
        self.assertEqual(len(list_response.json()), 1)
        self.assertEqual(list_response.json()[0]["lesson_slug"], lesson.slug)

        duplicate_response = self.client.post(
            "/api/submissions",
            data={
                "exercise_id": exercise.id,
                "client_submission_id": "offline-sync-001",
                "transcript_en": "We were on a break again",
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {self.student_token}",
        )

        self.assertEqual(duplicate_response.status_code, 200)
        self.assertEqual(duplicate_response.json()["id"], create_submission_response.json()["id"])
        self.assertEqual(Submission.objects.count(), 1)

    def test_personalized_feed_prioritizes_student_preferences(self):
        StudentProfile.objects.create(
            user=self.student,
            onboarding_completed=True,
            favorite_songs=["Numb"],
            favorite_artists=["Linkin Park"],
            favorite_anime=["Naruto"],
        )

        music_lesson = Lesson.objects.create(
            teacher=self.teacher,
            title="Numb Chorus",
            description="Treine Linkin Park no refrão.",
            content_type=Lesson.ContentType.MUSIC,
            source_type=Lesson.SourceType.EXTERNAL_LINK,
            difficulty=Lesson.Difficulty.EASY,
            tags=["Linkin Park", "rock"],
            media_url="https://example.com/numb.mp3",
            status=Lesson.Status.PUBLISHED,
        )
        anime_lesson = Lesson.objects.create(
            teacher=self.teacher,
            title="Random Anime Scene",
            description="Outra franquia.",
            content_type=Lesson.ContentType.ANIME_CLIP,
            source_type=Lesson.SourceType.EXTERNAL_LINK,
            difficulty=Lesson.Difficulty.MEDIUM,
            tags=["Bleach"],
            media_url="https://example.com/anime.mp4",
            status=Lesson.Status.PUBLISHED,
        )

        Exercise.objects.create(
            lesson=music_lesson,
            instruction_text="Cante a frase principal.",
            expected_phrase_en="I've become so numb.",
            expected_phrase_pt="Eu fiquei tao entorpecido.",
            max_score=100,
        )
        Exercise.objects.create(
            lesson=anime_lesson,
            instruction_text="Repita a fala.",
            expected_phrase_en="Believe it!",
            expected_phrase_pt="Pode acreditar!",
            max_score=100,
        )

        response = self.client.get(
            "/api/feed/personalized",
            HTTP_AUTHORIZATION=f"Bearer {self.student_token}",
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["items"][0]["slug"], music_lesson.slug)
        self.assertEqual(response.json()["items"][0]["match_reason"], "matches favorite song")
