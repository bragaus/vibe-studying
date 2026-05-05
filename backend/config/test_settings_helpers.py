from django.test import SimpleTestCase

from config.settings import (
    build_default_allowed_hosts,
    build_default_trusted_origins,
    extract_hostname,
    resolve_email_backend,
)


class SettingsHelperTests(SimpleTestCase):
    def test_extract_hostname_accepts_plain_host_or_full_origin(self):
        self.assertEqual(extract_hostname("backendvibestudying.planoartistico.com.br"), "backendvibestudying.planoartistico.com.br")
        self.assertEqual(extract_hostname("https://vibestudying.com.br/api"), "vibestudying.com.br")

    def test_build_default_allowed_hosts_includes_public_web_and_api_hosts(self):
        self.assertEqual(
            build_default_allowed_hosts(
                public_api_host="backendvibestudying.planoartistico.com.br",
                public_api_origin="https://backendvibestudying.planoartistico.com.br",
                public_web_url="https://vibestudying.com.br",
                local_hosts=["localhost", "127.0.0.1", "testserver"],
            ),
            [
                "backendvibestudying.planoartistico.com.br",
                "vibestudying.com.br",
                "localhost",
                "127.0.0.1",
                "testserver",
            ],
        )

    def test_build_default_trusted_origins_keeps_public_origins_and_optional_local(self):
        self.assertEqual(
            build_default_trusted_origins(
                public_api_origin="https://backendvibestudying.planoartistico.com.br",
                public_web_url="https://vibestudying.com.br",
                include_local_origins=False,
                local_origins=["http://localhost:3000"],
            ),
            [
                "https://backendvibestudying.planoartistico.com.br",
                "https://vibestudying.com.br",
            ],
        )

    def test_resolve_email_backend_uses_smtp_when_credentials_exist(self):
        self.assertEqual(
            resolve_email_backend(
                configured_backend="",
                email_host_user="mailer@example.com",
                email_host_password="secret",
            ),
            "django.core.mail.backends.smtp.EmailBackend",
        )

    def test_resolve_email_backend_keeps_explicit_backend(self):
        self.assertEqual(
            resolve_email_backend(
                configured_backend="django.core.mail.backends.console.EmailBackend",
                email_host_user="mailer@example.com",
                email_host_password="secret",
            ),
            "django.core.mail.backends.console.EmailBackend",
        )
