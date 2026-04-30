from django.test import TestCase, override_settings

from accounts.models import StudentProfile, User, WaitlistSignup


class AuthApiTests(TestCase):
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

    def test_student_can_fetch_and_complete_profile_onboarding(self):
        register_response = self.client.post(
            "/api/auth/register",
            data={
                "email": "profile@example.com",
                "password": "StrongPass123!",
                "first_name": "Pro",
                "last_name": "File",
            },
            content_type="application/json",
        )
        token = register_response.json()["access_token"]

        profile_response = self.client.get(
            "/api/profile/me",
            HTTP_AUTHORIZATION=f"Bearer {token}",
        )
        self.assertEqual(profile_response.status_code, 200)
        self.assertFalse(profile_response.json()["profile"]["onboarding_completed"])

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

    def test_waitlist_rejects_invalid_email(self):
        response = self.client.post(
            "/api/waitlist",
            data={"email": "not-an-email"},
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 400)
