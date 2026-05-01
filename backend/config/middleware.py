import uuid
from contextvars import ContextVar


request_id_context: ContextVar[str] = ContextVar("request_id", default="-")


def get_request_id() -> str:
    return request_id_context.get()


class RequestIdMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
        token = request_id_context.set(request_id)
        request.request_id = request_id

        try:
            response = self.get_response(request)
        finally:
            request_id_context.reset(token)

        response["X-Request-ID"] = request_id
        return response


class RequestIdLogFilter:
    def filter(self, record):
        record.request_id = get_request_id()
        return True
