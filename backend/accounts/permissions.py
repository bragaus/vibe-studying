from ninja.errors import HttpError


def require_role(user, *roles: str) -> None:
    # Helper simples para evitar repetir a mesma checagem de permissao nas rotas.
    if user.role not in roles:
        raise HttpError(403, "You do not have permission to perform this action.")
