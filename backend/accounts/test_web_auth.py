from urllib.parse import parse_qs, urlparse
from unittest.mock import patch

from django.core.cache import cache
from django.test import TestCase, override_settings

from accounts.models import User
from accounts.web_auth import create_social_login_session


@override_settings(
    CACHES={
        "default": {
            "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
            "LOCATION": "web-auth-tests",
        }
    },
    PUBLIC_WEB_URL="http://localhost:3000",
    TURNSTILE_ENABLED=True,
    TURNSTILE_SECRET_KEY="turnstile-secret",
    GOOGLE_OAUTH_CLIENT_ID="google-client",
    GOOGLE_OAUTH_CLIENT_SECRET="google-secret",
    GOOGLE_OAUTH_REDIRECT_URI="http://testserver/api/auth/social/google/callback",
)
class WebAuthApiTests(TestCase):
    def setUp(self):
        super().setUp()
        cache.clear()

    def create_student(self, *, email: str) -> User:
        return User.objects.create_user(
            email=email,
            password="StrongPass123!",
            first_name="Stu",
            last_name="Dent",
            role=User.Role.STUDENT,
        )

    @patch("accounts.web_api.verify_turnstile")
    def test_web_login_returns_tokens_without_second_factor(self, _verify_turnstile):
        user = self.create_student(email="web-login@example.com")

        response = self.client.post(
            "/api/auth/web/login",
            data={
                "email": user.email,
                "password": "StrongPass123!",
                "turnstile_token": "turnstile-ok",
            },
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 200)
        self.assertIn("access_token", response.json())
        self.assertEqual(response.json()["user"]["email"], user.email)

    @patch("accounts.web_api.verify_turnstile")
    def test_web_register_returns_tokens_without_second_factor(self, _verify_turnstile):
        response = self.client.post(
            "/api/auth/web/register",
            data={
                "email": "new-web-user@example.com",
                "password": "StrongPass123!",
                "first_name": "New",
                "last_name": "User",
                "turnstile_token": "turnstile-ok",
            },
            content_type="application/json",
        )

        self.assertEqual(response.status_code, 201)
        self.assertIn("access_token", response.json())
        self.assertTrue(User.objects.filter(email="new-web-user@example.com").exists())

    @patch("accounts.web_api.verify_turnstile")
    @patch("accounts.web_api.resolve_social_user")
    @patch("accounts.web_api.fetch_social_identity")
    def test_social_callback_redirects_back_to_web_session(self, fetch_social_identity_mock, resolve_social_user_mock, _verify_turnstile):
        user = self.create_student(email="social-user@example.com")
        resolve_social_user_mock.return_value = user
        fetch_social_identity_mock.return_value = {
            "provider": "google",
            "provider_user_id": "google-123",
            "email": user.email,
            "email_verified": True,
            "first_name": "Social",
            "last_name": "User",
            "avatar_url": "https://example.com/avatar.png",
        }

        start_response = self.client.post(
            "/api/auth/social/google/start",
            data={"turnstile_token": "turnstile-ok"},
            content_type="application/json",
        )
        self.assertEqual(start_response.status_code, 200)

        authorization_url = start_response.json()["authorization_url"]
        state = parse_qs(urlparse(authorization_url).query)["state"][0]

        callback_response = self.client.get(f"/api/auth/social/google/callback?state={state}&code=provider-code")
        self.assertEqual(callback_response.status_code, 302)
        self.assertTrue(callback_response["Location"].startswith("http://localhost:3000/auth?session="))

        session_token = parse_qs(urlparse(callback_response["Location"]).query)["session"][0]
        session_response = self.client.get(f"/api/auth/web/session?session_token={session_token}")

        self.assertEqual(session_response.status_code, 200)
        self.assertIn("access_token", session_response.json())
        self.assertEqual(session_response.json()["user"]["email"], user.email)

    def test_social_session_is_single_use(self):
        user = self.create_student(email="single-use@example.com")
        session_token = create_social_login_session(user, source="social_google")

        first_response = self.client.get(f"/api/auth/web/session?session_token={session_token}")
        second_response = self.client.get(f"/api/auth/web/session?session_token={session_token}")

        self.assertEqual(first_response.status_code, 200)
        self.assertEqual(second_response.status_code, 404)

    def test_github_social_login_routes_are_not_available(self):
        start_response = self.client.post(
            "/api/auth/social/github/start",
            data={"turnstile_token": "turnstile-ok"},
            content_type="application/json",
        )
        callback_response = self.client.get("/api/auth/social/github/callback?state=test&code=test")

        self.assertEqual(start_response.status_code, 404)
        self.assertEqual(callback_response.status_code, 404)

    @patch("accounts.web_api.verify_turnstile")
    def test_web_login_rate_limit_blocks_excessive_attempts(self, _verify_turnstile):
        user = self.create_student(email="limit-user@example.com")

        for attempt in range(5):
            response = self.client.post(
                "/api/auth/web/login",
                data={
                    "email": user.email,
                    "password": "wrong-password",
                    "turnstile_token": f"turnstile-{attempt}",
                },
                content_type="application/json",
            )
            self.assertEqual(response.status_code, 401)

        blocked_response = self.client.post(
            "/api/auth/web/login",
            data={
                "email": user.email,
                "password": "wrong-password",
                "turnstile_token": "turnstile-final",
            },
            content_type="application/json",
        )
        self.assertEqual(blocked_response.status_code, 429)
