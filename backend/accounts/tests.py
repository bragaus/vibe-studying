from django.test import TestCase

from accounts.models import User


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
