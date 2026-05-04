"""Ponto central de montagem da API.

Aqui o Django Ninja junta routers menores em uma API unica.
Cada router concentra um contexto do sistema para manter o codigo modular.
"""

from ninja import NinjaAPI

from config.health import build_health_report

from accounts.api import marketing_router, profile_router, router as auth_router
from accounts.web_api import web_auth_router
from learning.api import public_router, submission_router, teacher_router


api = NinjaAPI(title="Vibe Studying API", version="0.1.0")
# Rotas de autenticacao do usuario final.
api.add_router("/auth", auth_router)
# Rotas de autenticacao web e login social.
api.add_router("/auth", web_auth_router)
# Rotas de perfil/onboarding do aluno.
api.add_router("/profile", profile_router)
# Rotas publicas de captacao.
api.add_router("", marketing_router)
# Rotas publicas do produto.
api.add_router("", public_router)
# Rotas restritas ao portal do professor.
api.add_router("/teacher", teacher_router)
# Rotas de submissao do aluno autenticado.
api.add_router("", submission_router)


@api.get("/health", tags=["Health"], response={200: dict, 503: dict})
def health_check(request):
    return build_health_report()
