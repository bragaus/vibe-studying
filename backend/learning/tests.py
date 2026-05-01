from unittest.mock import patch

from django.test import SimpleTestCase, TestCase

from accounts.jwt import create_token_pair
from accounts.models import StudentProfile, User
from learning.models import Exercise, ExerciseLine, Lesson, PersonalizedFeedJob, Submission
from learning.services.ollama import OllamaClient
from learning.services.personalization import PersonalizationError, generate_lesson_payloads
from learning.services.web import MultiSearchClient, WebSearchError, WebSearchResult
from learning.tasks import bootstrap_personalized_feed_task


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

    def test_personalized_feed_includes_student_private_lessons_only(self):
        StudentProfile.objects.create(
            user=self.student,
            onboarding_completed=True,
            favorite_movies=["Interstellar"],
        )
        other_student = User.objects.create_user(
            email="other-student@example.com",
            password="StrongPass123!",
            role=User.Role.STUDENT,
        )

        private_lesson = Lesson.objects.create(
            teacher=self.teacher,
            student=self.student,
            title="Interstellar Docking Quote",
            description="Trecho montado para o aluno.",
            content_type=Lesson.ContentType.MOVIE_CLIP,
            source_type=Lesson.SourceType.EXTERNAL_LINK,
            difficulty=Lesson.Difficulty.EASY,
            tags=["Interstellar", "space"],
            media_url="https://example.com/interstellar",
            cover_image_url="https://example.com/interstellar.jpg",
            source_url="https://example.com/interstellar",
            source_title="Interstellar article",
            match_reason_hint="Based on favorite movie: Interstellar",
            generated_by_ai=True,
            visibility=Lesson.Visibility.PRIVATE,
            status=Lesson.Status.PUBLISHED,
        )
        foreign_private_lesson = Lesson.objects.create(
            teacher=self.teacher,
            student=other_student,
            title="Other Student Lesson",
            description="Nao deve aparecer.",
            content_type=Lesson.ContentType.MUSIC,
            source_type=Lesson.SourceType.EXTERNAL_LINK,
            difficulty=Lesson.Difficulty.EASY,
            tags=["exclusive"],
            media_url="https://example.com/other",
            source_url="https://example.com/other",
            generated_by_ai=True,
            visibility=Lesson.Visibility.PRIVATE,
            status=Lesson.Status.PUBLISHED,
        )
        public_lesson = Lesson.objects.create(
            teacher=self.teacher,
            title="Generic Public Lesson",
            description="Visivel para todos.",
            content_type=Lesson.ContentType.CHARGE,
            source_type=Lesson.SourceType.EXTERNAL_LINK,
            difficulty=Lesson.Difficulty.MEDIUM,
            tags=["public"],
            media_url="https://example.com/public",
            source_url="https://example.com/public",
            status=Lesson.Status.PUBLISHED,
        )

        for lesson in [private_lesson, foreign_private_lesson, public_lesson]:
            Exercise.objects.create(
                lesson=lesson,
                instruction_text="Repita a fala.",
                expected_phrase_en="Keep talking.",
                expected_phrase_pt="Continue falando.",
                max_score=100,
            )

        response = self.client.get(
            "/api/feed/personalized",
            HTTP_AUTHORIZATION=f"Bearer {self.student_token}",
        )

        self.assertEqual(response.status_code, 200)
        items = response.json()["items"]
        slugs = [item["slug"] for item in items]
        self.assertIn(private_lesson.slug, slugs)
        self.assertIn(public_lesson.slug, slugs)
        self.assertNotIn(foreign_private_lesson.slug, slugs)
        self.assertTrue(items[0]["is_personalized"])
        self.assertEqual(items[0]["slug"], private_lesson.slug)

    def test_private_lesson_detail_requires_owner_token(self):
        private_lesson = Lesson.objects.create(
            teacher=self.teacher,
            student=self.student,
            title="Naruto Practice Line",
            description="Detalhe privado.",
            content_type=Lesson.ContentType.ANIME_CLIP,
            source_type=Lesson.SourceType.EXTERNAL_LINK,
            difficulty=Lesson.Difficulty.EASY,
            tags=["Naruto"],
            media_url="https://example.com/naruto",
            source_url="https://example.com/naruto",
            generated_by_ai=True,
            visibility=Lesson.Visibility.PRIVATE,
            status=Lesson.Status.PUBLISHED,
        )
        Exercise.objects.create(
            lesson=private_lesson,
            instruction_text="Repita a fala.",
            expected_phrase_en="Believe it!",
            expected_phrase_pt="Pode acreditar!",
            max_score=100,
        )

        anonymous_response = self.client.get(f"/api/lessons/{private_lesson.slug}")
        self.assertEqual(anonymous_response.status_code, 404)

        authorized_response = self.client.get(
            f"/api/lessons/{private_lesson.slug}",
            HTTP_AUTHORIZATION=f"Bearer {self.student_token}",
        )
        self.assertEqual(authorized_response.status_code, 200)
        self.assertEqual(authorized_response.json()["slug"], private_lesson.slug)

    def test_feed_bootstrap_status_reflects_job_state(self):
        PersonalizedFeedJob.objects.create(
            student=self.student,
            status=PersonalizedFeedJob.Status.RUNNING,
            target_items=8,
            generated_items=2,
        )
        lesson = Lesson.objects.create(
            teacher=self.teacher,
            student=self.student,
            title="Bootstrap Private Lesson",
            description="Ja pronta.",
            content_type=Lesson.ContentType.MUSIC,
            source_type=Lesson.SourceType.EXTERNAL_LINK,
            difficulty=Lesson.Difficulty.EASY,
            tags=["bootstrap"],
            media_url="https://example.com/bootstrap",
            source_url="https://example.com/bootstrap",
            generated_by_ai=True,
            visibility=Lesson.Visibility.PRIVATE,
            status=Lesson.Status.PUBLISHED,
        )
        Exercise.objects.create(
            lesson=lesson,
            instruction_text="Repita a frase.",
            expected_phrase_en="We are live.",
            expected_phrase_pt="Estamos no ar.",
            max_score=100,
        )

        response = self.client.get(
            "/api/feed/bootstrap-status",
            HTTP_AUTHORIZATION=f"Bearer {self.student_token}",
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], PersonalizedFeedJob.Status.RUNNING)
        self.assertEqual(response.json()["ready_items"], 1)
        self.assertEqual(response.json()["target_items"], 8)

    @patch("learning.tasks.generate_and_store_personalized_lessons", return_value=3)
    def test_bootstrap_task_marks_job_done(self, generate_and_store_personalized_lessons):
        StudentProfile.objects.create(
            user=self.student,
            onboarding_completed=True,
            favorite_songs=["Numb"],
        )
        job = PersonalizedFeedJob.objects.create(
            student=self.student,
            status=PersonalizedFeedJob.Status.PENDING,
            target_items=6,
        )

        result = bootstrap_personalized_feed_task.apply(args=[self.student.id]).get()

        job.refresh_from_db()
        self.assertEqual(job.status, PersonalizedFeedJob.Status.DONE)
        self.assertEqual(job.generated_items, 3)
        self.assertEqual(result["generated_items"], 3)
        generate_and_store_personalized_lessons.assert_called_once()

    @patch("learning.tasks.generate_and_store_personalized_lessons", side_effect=RuntimeError("search down"))
    def test_bootstrap_task_marks_job_failed_without_raising(self, generate_and_store_personalized_lessons):
        StudentProfile.objects.create(
            user=self.student,
            onboarding_completed=True,
            favorite_songs=["Numb"],
        )
        job = PersonalizedFeedJob.objects.create(
            student=self.student,
            status=PersonalizedFeedJob.Status.PENDING,
            target_items=6,
        )

        result = bootstrap_personalized_feed_task.apply(args=[self.student.id]).get()

        job.refresh_from_db()
        self.assertEqual(job.status, PersonalizedFeedJob.Status.FAILED)
        self.assertEqual(result["status"], PersonalizedFeedJob.Status.FAILED)
        self.assertIn("search down", result["error"])
        generate_and_store_personalized_lessons.assert_called_once()


class SearchServicesTests(TestCase):
    def test_multi_search_client_falls_back_when_first_provider_fails(self):
        class BrokenProvider:
            def search(self, query: str, limit: int = 5):
                raise WebSearchError("connection refused")

        class WorkingProvider:
            def search(self, query: str, limit: int = 5):
                return [
                    WebSearchResult(
                        title="Fallback result",
                        url="https://example.com/fallback",
                        snippet="Recovered from fallback",
                    )
                ]

        client = MultiSearchClient(providers=[BrokenProvider(), WorkingProvider()])
        results = client.search("linkin park numb", limit=3)

        self.assertEqual(len(results), 1)
        self.assertEqual(results[0].url, "https://example.com/fallback")

    @patch("learning.services.personalization.collect_source_documents", side_effect=WebSearchError("connection refused"))
    def test_generate_lesson_payloads_wraps_web_search_error(self, _collect_source_documents):
        student = User.objects.create_user(
            email="profile2@example.com",
            password="StrongPass123!",
            role=User.Role.STUDENT,
        )
        profile = StudentProfile.objects.create(
            user=student,
            onboarding_completed=True,
            favorite_songs=["Numb"],
        )

        with self.assertRaises(PersonalizationError) as context:
            generate_lesson_payloads(profile, 3)

        self.assertIn("Web search failed", str(context.exception))


class _FakeHTTPResponse:
    def __init__(self, payload: dict):
        import json

        self._payload = json.dumps(payload).encode("utf-8")

    def read(self):
        return self._payload

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False


class OllamaClientTests(SimpleTestCase):
    @patch("learning.services.ollama.urlopen")
    def test_generate_json_falls_back_from_empty_chat_to_generate_response(self, mocked_urlopen):
        mocked_urlopen.side_effect = [
            _FakeHTTPResponse({"response": "{\"ok\": true}"}),
        ]

        client = OllamaClient(base_url="http://127.0.0.1:11434", model="deepseek-r1:8b", timeout=5)
        payload = client.generate_json(system_prompt="Return JSON only.", user_prompt="Return {\"ok\": true}.")

        self.assertEqual(payload, {"ok": True})

    @patch("learning.services.ollama.urlopen")
    def test_generate_json_extracts_json_from_markdown_block(self, mocked_urlopen):
        mocked_urlopen.side_effect = [
            _FakeHTTPResponse({"response": "```json\n{\"ok\": true}\n```"}),
        ]

        client = OllamaClient(base_url="http://127.0.0.1:11434", model="deepseek-r1:8b", timeout=5)
        payload = client.generate_json(system_prompt="Return JSON only.", user_prompt="Return {\"ok\": true}.")

        self.assertEqual(payload, {"ok": True})
