import re
import sys

from django.conf import settings
from django.contrib import admin
from django.urls import path
from django.urls import re_path
from django.views.static import serve

from config.api import api

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', api.urls),
]

if settings.DEBUG or "runserver" in sys.argv:
    media_prefix = settings.MEDIA_URL.lstrip("/")
    urlpatterns += [
        re_path(rf"^{re.escape(media_prefix)}(?P<path>.*)$", serve, {"document_root": settings.MEDIA_ROOT}),
    ]
