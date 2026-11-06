# CookYaBackend/urls.py
from django.contrib import admin
from django.urls import path, include, re_path
from django.conf import settings
from django.conf.urls.static import static
from rest_framework import permissions
from rest_framework.authtoken import views as token_views
from drf_yasg.views import get_schema_view
from drf_yasg import openapi
from django.http import HttpResponse
from django.views.decorators.http import require_GET
import os
import re


# ==================== Media Streaming (with HTTP Range support) ====================

def _serve_media_impl(request, full_path):
    """
    Serve a media file with proper HTTP Range support.

    iOS AVPlayer strictly requires 206 Partial Content responses with a
    correct Content-Range header. Django's built-in static() helper does
    not support Range, which causes "byte range length mismatch" errors
    on real devices when playing video/audio from chat_media.
    """
    if not os.path.exists(full_path):
        return HttpResponse(status=404)

    file_size = os.path.getsize(full_path)

    ext = os.path.splitext(full_path)[1].lower()
    mime_map = {
        # Videos
        '.mp4': 'video/mp4',
        '.mov': 'video/quicktime',
        '.m4v': 'video/x-m4v',
        '.avi': 'video/x-msvideo',
        '.mkv': 'video/x-matroska',
        '.webm': 'video/webm',
        '.3gp': 'video/3gpp',
        '.flv': 'video/x-flv',
        '.wmv': 'video/x-ms-wmv',
        # Images
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.png': 'image/png',
        '.gif': 'image/gif',
        '.webp': 'image/webp',
        '.heic': 'image/heic',
        '.bmp': 'image/bmp',
        '.tiff': 'image/tiff',
    }
    mime_type = mime_map.get(ext, 'application/octet-stream')

    range_header = request.META.get('HTTP_RANGE', '').strip()

    if range_header:
        range_match = re.match(r'bytes=(\d+)-(\d*)', range_header)
        if range_match:
            start = int(range_match.group(1))
            end = (
                int(range_match.group(2))
                if range_match.group(2)
                else file_size - 1
            )
        else:
            start = 0
            end = file_size - 1

        if start >= file_size or end >= file_size or start > end:
            return HttpResponse(status=416)

        chunk_size = end - start + 1
        with open(full_path, 'rb') as f:
            f.seek(start)
            data = f.read(chunk_size)

        response = HttpResponse(data, status=206)
        response['Content-Length'] = str(chunk_size)
        response['Content-Range'] = f'bytes {start}-{end}/{file_size}'
    else:
        with open(full_path, 'rb') as f:
            data = f.read()

        response = HttpResponse(data, status=200)
        response['Content-Length'] = str(file_size)

    response['Accept-Ranges'] = 'bytes'
    response['Content-Type'] = mime_type
    response['Cache-Control'] = 'public, max-age=3600'

    return response


@require_GET
def serve_recipe_video(request, file_path):
    """Serve files under MEDIA_ROOT/videos/ (recipe videos)."""
    full_path = os.path.join(settings.MEDIA_ROOT, 'videos', file_path)
    return _serve_media_impl(request, full_path)


@require_GET
def serve_ingredient_video(request, file_path):
    """Serve files under MEDIA_ROOT/ingredient_videos/ (ingredient videos)."""
    full_path = os.path.join(settings.MEDIA_ROOT, 'ingredient_videos', file_path)
    return _serve_media_impl(request, full_path)


@require_GET
def serve_class_video(request, file_path):
    """Serve files under MEDIA_ROOT/classes/videos/ (booking class videos)."""
    full_path = os.path.join(settings.MEDIA_ROOT, 'classes', 'videos', file_path)
    return _serve_media_impl(request, full_path)


@require_GET
def serve_chat_media(request, file_path):
    """
    Serve files under MEDIA_ROOT/chat_media/ (chat image/video attachments).

    This is required for iOS/Android video playback in chat because
    AVPlayer / ExoPlayer only accept Range-enabled responses.
    """
    full_path = os.path.join(settings.MEDIA_ROOT, 'chat_media', file_path)
    return _serve_media_impl(request, full_path)


# ==================== API Schema ====================

schema_view = get_schema_view(
    openapi.Info(
        title="Cookya API",
        default_version='v1',
        description="API documentation for Cookya Recipe App",
    ),
    public=True,
    permission_classes=(permissions.AllowAny,),
)


# ==================== URL Patterns ====================

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('recipes.urls')),
    path('api/users/', include('users.urls')),
    path('api/login/', token_views.obtain_auth_token, name='api_login'),
    path('api/docs/', schema_view.with_ui('swagger', cache_timeout=0), name='schema-swagger-ui'),
    path('api/ingredients/', include('ingredients.urls')),
    path('api/groceries/', include('groceries.urls')),
    path('api/bookings/', include('bookings.urls')),
    path('api/reports/', include('reports.urls')),
]

if settings.DEBUG:
    urlpatterns += [
        re_path(
            r'^media/videos/(?P<file_path>.+)$',
            serve_recipe_video,
            name='serve_recipe_video',
        ),
        re_path(
            r'^media/ingredient_videos/(?P<file_path>.+)$',
            serve_ingredient_video,
            name='serve_ingredient_video',
        ),
        re_path(
            r'^media/classes/videos/(?P<file_path>.+)$',
            serve_class_video,
            name='serve_class_video',
        ),
        # Chat media (images + videos) must come BEFORE static() so that
        # Range requests are handled here instead of by Django's static().
        re_path(
            r'^media/chat_media/(?P<file_path>.+)$',
            serve_chat_media,
            name='serve_chat_media',
        ),
    ]

    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)