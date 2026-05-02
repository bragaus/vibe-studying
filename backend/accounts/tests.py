import tempfile
from unittest.mock import patch

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings

from accounts.models import StudentPost, StudentPostComment, StudentPostEnergy, StudentProfile, User, WaitlistSignup
from operations.models import EmailDelivery


class AuthApiTests(TestCase):
    def register_student_and_get_token(self, *, email: str, first_name: str = "Stu", last_name: str = "Dent") -> str:
        response = self.client.post(
            "/api/auth/register",
            data={
                "email": email,
                "password": "StrongPass123!",
                "first_name": first_name,
                "last_name": last_name,
            },
            content_type="application/json",
        )
        self.assertEqual(response.status_code, 201)
        return response.json()["access_token"]

    def test_student_can_register_login_refresh_and_fetch_me(self):
        register_response = self.client.post(
            "/api/auth/register",
            data={
                "email": "student@example.com",
                "password": "StrongPass123!",
                "first_name": "Stu",
                "last_name": "Dent",
            },
            content_type="application/json",
        )

        self.assertEqual(register_response.status_code, 201)
        register_data = register_response.json()
        self.assertEqual(register_data["user"]["role"], User.Role.STUDENT)
        self.assertEqual(EmailDelivery.objects.filter(template_key=EmailDelivery.TemplateKey.STUDENT_WELCOME).count(), 1)

        me_response = self.client.get(
            "/api/auth/me",
            HTTP_AUTHORIZATION=f"Bearer {register_data['access_token']}",
        )
        self.assertEqual(me_response.status_code, 200)
        self.assertEqual(me_response.json()["email"], "student@example.com")

        login_response = self.client.post(
            "/api/auth/login",
            data={"email": "student@example.com", "password": "StrongPass123!"},
            content_type="application/json",
        )
        self.assertEqual(login_response.status_code, 200)

        refresh_response = self.client.post(
            "/api/auth/refresh",
            data={"refresh_token": login_response.json()["refresh_token"]},
            content_type="application/json",
        )
        self.assertEqual(refresh_response.status_code, 200)
        self.assertEqual(refresh_response.json()["user"]["email"], "student@example.com")

    def test_teacher_can_register_via_dedicated_auth_endpoint(self):
        response = self.client.post(
            "/api/auth/register/teacher",
            data={
                "email": "teacher@example.com",
                "password": "StrongPass123!",
                "first_name": "Tea",
                "last_name": "Cher",
            },
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.json()["user"]["role"], User.Role.TEACHER)
        self.assertIn("access_token", response.json())
        self.assertTrue(User.objects.filter(email="teacher@example.com", role=User.Role.TEACHER).exists())

    @override_settings(ENABLE_PUBLIC_TEACHER_SIGNUP=False)
    def test_teacher_signup_can_be_disabled_by_environment(self):
        response = self.client.post(
            "/api/auth/register/teacher",
            data={
                "email": "blocked-teacher@example.com",
                "password": "StrongPass123!",
                "first_name": "Tea",
                "last_name": "Cher",
            },
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 403)
        self.assertFalse(User.objects.filter(email="blocked-teacher@example.com").exists())

    @patch("accounts.api.enqueue_personalized_feed_bootstrap")
    def test_student_can_fetch_and_complete_profile_onboarding(self, enqueue_personalized_feed_bootstrap):
        token = self.register_student_and_get_token(email="profile@example.com", first_name="Pro", last_name="File")

        profile_response = self.client.get(
            "/api/profile/me",
            HTTP_AUTHORIZATION=f"Bearer {token}",
        )
        self.assertEqual(profile_response.status_code, 200)
        self.assertFalse(profile_response.json()["profile"]["onboarding_completed"])

        with self.captureOnCommitCallbacks(execute=True):
            onboarding_response = self.client.post(
                "/api/profile/onboarding",
                data={
                    "english_level": StudentProfile.EnglishLevel.INTERMEDIATE,
                    "favorite_songs": ["Numb", "Numb", " Yellow "],
                    "favorite_movies": ["Interstellar"],
                    "favorite_series": ["Dark"],
                    "favorite_anime": ["Naruto"],
                    "favorite_artists": ["Linkin Park"],
                    "favorite_genres": ["rock", "Sci-Fi"],
                },
                content_type="application/json",
                HTTP_AUTHORIZATION=f"Bearer {token}",
            )

        self.assertEqual(onboarding_response.status_code, 200)
        self.assertTrue(onboarding_response.json()["profile"]["onboarding_completed"])
        self.assertEqual(onboarding_response.json()["profile"]["favorite_songs"], ["Numb", "Yellow"])

        profile = StudentProfile.objects.get(user__email="profile@example.com")
        self.assertTrue(profile.onboarding_completed)
        self.assertEqual(profile.favorite_artists, ["Linkin Park"])
        enqueue_personalized_feed_bootstrap.assert_called_once_with(profile.user.id, force=True)

    def test_student_can_update_bio_and_receive_social_stats(self):
        token = self.register_student_and_get_token(email="bio@example.com", first_name="Bio", last_name="Field")

        response = self.client.put(
            "/api/profile/me",
            data={
                "bio": "Curto trilhas sonoras, sci-fi e animes estrategicos.",
                "favorite_movies": ["Blade Runner 2049"],
            },
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {token}",
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["profile"]["bio"], "Curto trilhas sonoras, sci-fi e animes estrategicos.")
        self.assertEqual(response.json()["profile"]["posts_count"], 0)
        self.assertEqual(response.json()["profile"]["energy_received_count"], 0)
        self.assertEqual(response.json()["profile"]["comments_received_count"], 0)

    def test_student_can_upload_and_remove_avatar(self):
        token = self.register_student_and_get_token(email="avatar@example.com", first_name="Ava", last_name="Tar")
        avatar = SimpleUploadedFile("avatar.png", b"fake-image-bytes", content_type="image/png")

        with tempfile.TemporaryDirectory() as media_root:
            with override_settings(MEDIA_ROOT=media_root):
                upload_response = self.client.post(
                    "/api/profile/me/avatar",
                    data={"avatar": avatar},
                    HTTP_AUTHORIZATION=f"Bearer {token}",
                )

                self.assertEqual(upload_response.status_code, 200)
                self.assertIn("/media/student-avatars/", upload_response.json()["profile"]["avatar_url"])

                delete_response = self.client.delete(
                    "/api/profile/me/avatar",
                    HTTP_AUTHORIZATION=f"Bearer {token}",
                )

                self.assertEqual(delete_response.status_code, 200)
                self.assertEqual(delete_response.json()["profile"]["avatar_url"], "")

    def test_student_can_replace_avatar_even_if_old_file_cleanup_fails(self):
        token = self.register_student_and_get_token(
            email="avatar-replace@example.com",
            first_name="Ava",
            last_name="Replace",
        )
        first_avatar = SimpleUploadedFile("avatar-1.png", b"first-image-bytes", content_type="image/png")
        second_avatar = SimpleUploadedFile("avatar-2.png", b"second-image-bytes", content_type="image/png")

        with tempfile.TemporaryDirectory() as media_root:
            with override_settings(MEDIA_ROOT=media_root):
                first_response = self.client.post(
                    "/api/profile/me/avatar",
                    data={"avatar": first_avatar},
                    HTTP_AUTHORIZATION=f"Bearer {token}",
                )

                self.assertEqual(first_response.status_code, 200)

                profile = StudentProfile.objects.get(user__email="avatar-replace@example.com")
                previous_avatar_name = profile.avatar_image.name

                with patch(
                    "django.core.files.storage.filesystem.FileSystemStorage.delete",
                    side_effect=PermissionError("sem permissao para apagar avatar antigo"),
                ):
                    replace_response = self.client.post(
                        "/api/profile/me/avatar",
                        data={"avatar": second_avatar},
                        HTTP_AUTHORIZATION=f"Bearer {token}",
                    )

                self.assertEqual(replace_response.status_code, 200)
                self.assertIn("/media/student-avatars/", replace_response.json()["profile"]["avatar_url"])

                profile.refresh_from_db()
                self.assertTrue(profile.avatar_image.name)
                self.assertNotEqual(profile.avatar_image.name, previous_avatar_name)

    def test_auth_endpoints_expose_avatar_url_after_avatar_upload(self):
        register_response = self.client.post(
            "/api/auth/register",
            data={
                "email": "avatar-auth@example.com",
                "password": "StrongPass123!",
                "first_name": "Avatar",
                "last_name": "Auth",
            },
            content_type="application/json",
        )

        self.assertEqual(register_response.status_code, 201)
        access_token = register_response.json()["access_token"]

        with tempfile.TemporaryDirectory() as media_root:
            with override_settings(MEDIA_ROOT=media_root):
                upload_response = self.client.post(
                    "/api/profile/me/avatar",
                    data={
                        "avatar": SimpleUploadedFile(
                            "avatar-auth.png",
                            b"avatar-auth-image-bytes",
                            content_type="image/png",
                        )
                    },
                    HTTP_AUTHORIZATION=f"Bearer {access_token}",
                )

                self.assertEqual(upload_response.status_code, 200)
                expected_avatar_url = upload_response.json()["profile"]["avatar_url"]
                self.assertEqual(upload_response.json()["user"]["avatar_url"], expected_avatar_url)

                me_response = self.client.get(
                    "/api/auth/me",
                    HTTP_AUTHORIZATION=f"Bearer {access_token}",
                )
                self.assertEqual(me_response.status_code, 200)
                self.assertEqual(me_response.json()["avatar_url"], expected_avatar_url)

                login_response = self.client.post(
                    "/api/auth/login",
                    data={"email": "avatar-auth@example.com", "password": "StrongPass123!"},
                    content_type="application/json",
                )
                self.assertEqual(login_response.status_code, 200)
                self.assertEqual(login_response.json()["user"]["avatar_url"], expected_avatar_url)

                refresh_response = self.client.post(
                    "/api/auth/refresh",
                    data={"refresh_token": login_response.json()["refresh_token"]},
                    content_type="application/json",
                )
                self.assertEqual(refresh_response.status_code, 200)
                self.assertEqual(refresh_response.json()["user"]["avatar_url"], expected_avatar_url)

    def test_students_can_create_posts_comments_and_energy(self):
        owner_token = self.register_student_and_get_token(email="owner@example.com", first_name="Owner", last_name="One")
        visitor_token = self.register_student_and_get_token(email="visitor@example.com", first_name="Visitor", last_name="Two")

        create_response = self.client.post(
            "/api/profile/posts",
            data={"content": "Acabei de atualizar minha vibe com Interstellar e Linkin Park."},
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {owner_token}",
        )

        self.assertEqual(create_response.status_code, 201)
        post_id = create_response.json()["id"]

        energy_response = self.client.post(
            f"/api/profile/posts/{post_id}/energy",
            HTTP_AUTHORIZATION=f"Bearer {visitor_token}",
        )
        self.assertEqual(energy_response.status_code, 200)
        self.assertTrue(energy_response.json()["energized_by_me"])
        self.assertEqual(energy_response.json()["energy_count"], 1)

        comment_response = self.client.post(
            f"/api/profile/posts/{post_id}/comments",
            data={"content": "Boa mistura. Isso vai render um feed forte."},
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {visitor_token}",
        )
        self.assertEqual(comment_response.status_code, 201)
        self.assertEqual(comment_response.json()["comment_count"], 1)
        self.assertEqual(comment_response.json()["comments"][0]["author"]["display_name"], "Visitor Two")

        list_response = self.client.get(
            "/api/profile/posts",
            HTTP_AUTHORIZATION=f"Bearer {owner_token}",
        )
        self.assertEqual(list_response.status_code, 200)
        self.assertEqual(len(list_response.json()), 1)
        self.assertEqual(list_response.json()[0]["energy_count"], 1)
        self.assertEqual(list_response.json()[0]["comment_count"], 1)

        profile_response = self.client.get(
            "/api/profile/me",
            HTTP_AUTHORIZATION=f"Bearer {owner_token}",
        )
        self.assertEqual(profile_response.status_code, 200)
        self.assertEqual(profile_response.json()["profile"]["posts_count"], 1)
        self.assertEqual(profile_response.json()["profile"]["energy_received_count"], 1)
        self.assertEqual(profile_response.json()["profile"]["comments_received_count"], 1)
        self.assertEqual(StudentPost.objects.count(), 1)
        self.assertEqual(StudentPostEnergy.objects.count(), 1)
        self.assertEqual(StudentPostComment.objects.count(), 1)

    def test_student_can_only_delete_own_post(self):
        owner_token = self.register_student_and_get_token(email="delete-owner@example.com", first_name="Delete", last_name="Owner")
        intruder_token = self.register_student_and_get_token(email="intruder@example.com", first_name="Intru", last_name="Der")

        create_response = self.client.post(
            "/api/profile/posts",
            data={"content": "Post protegido do dono."},
            content_type="application/json",
            HTTP_AUTHORIZATION=f"Bearer {owner_token}",
        )
        post_id = create_response.json()["id"]

        delete_response = self.client.delete(
            f"/api/profile/posts/{post_id}",
            HTTP_AUTHORIZATION=f"Bearer {intruder_token}",
        )

        self.assertEqual(delete_response.status_code, 403)
        self.assertTrue(StudentPost.objects.filter(pk=post_id).exists())

    def test_public_waitlist_endpoint_creates_and_deduplicates_signup(self):
        first_response = self.client.post(
            "/api/waitlist",
            data={"email": "Lead@example.com", "source": "landing"},
            content_type="application/json",
        )

        self.assertEqual(first_response.status_code, 201)
        self.assertFalse(first_response.json()["already_registered"])

        second_response = self.client.post(
            "/api/waitlist",
            data={"email": "lead@example.com", "source": "hero_cta"},
            content_type="application/json",
        )

        self.assertEqual(second_response.status_code, 200)
        self.assertTrue(second_response.json()["already_registered"])
        self.assertEqual(WaitlistSignup.objects.count(), 1)
        self.assertEqual(WaitlistSignup.objects.get().source, "hero_cta")
        self.assertEqual(EmailDelivery.objects.filter(template_key=EmailDelivery.TemplateKey.WAITLIST_WELCOME).count(), 1)

    def test_waitlist_rejects_invalid_email(self):
        response = self.client.post(
            "/api/waitlist",
            data={"email": "not-an-email"},
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 400)

    @patch("operations.emailing._enqueue_email_delivery_after_commit", side_effect=RuntimeError("broker offline"))
    def test_student_register_does_not_fail_when_email_broker_is_unavailable(self, _enqueue_email_delivery_after_commit):
        response = self.client.post(
            "/api/auth/register",
            data={
                "email": "broker-offline@example.com",
                "password": "StrongPass123!",
                "first_name": "Bro",
                "last_name": "Ker",
            },
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 201)
        self.assertTrue(User.objects.filter(email="broker-offline@example.com").exists())
        self.assertEqual(EmailDelivery.objects.filter(recipient_email="broker-offline@example.com").count(), 1)
