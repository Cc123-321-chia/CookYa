# ingredients/views.py
from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from django.db import models
from django.core.files.storage import default_storage
from django.utils import timezone
import uuid
import json
import os
from django.http import HttpResponse, Http404
from django.views.decorators.http import require_GET
from django.conf import settings

from .models import IngredientPost, IngredientComment
from .serializers import (
    IngredientPostSerializer,
    IngredientPostCreateSerializer,
    IngredientPostUpdateSerializer,
    IngredientCommentSerializer,
)

# Sync helpers for the users app
from users.models import UserLike, UserComment, UserPost


# ==================== File helpers ====================

def _relative_url(request, url):
    """Store relative paths so image resolution is host-agnostic."""
    if not url:
        return url
    if url.startswith('http://') or url.startswith('https://'):
        from urllib.parse import urlparse
        return urlparse(url).path
    return url


def _save_uploaded_file(file, folder):
    filename = f"{folder}/{uuid.uuid4().hex}_{file.name}"
    saved_path = default_storage.save(filename, file)
    return default_storage.url(saved_path)


def _try_delete_file(url):
    if not url:
        return
    try:
        path = url
        if path.startswith('http://') or path.startswith('https://'):
            from urllib.parse import urlparse
            path = urlparse(path).path
        if path.startswith('/media/'):
            path = path[len('/media/'):]
        elif path.startswith('media/'):
            path = path[len('media/'):]
        if default_storage.exists(path):
            default_storage.delete(path)
    except Exception as e:
        print(f"Delete file error: {e}")


# ==================== Post views ====================

class IngredientPostListView(generics.ListAPIView):
    """List all ingredient posts."""
    serializer_class = IngredientPostSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        queryset = IngredientPost.objects.all().order_by('-created_at')

        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(
                models.Q(title__icontains=search) |
                models.Q(content__icontains=search) |
                models.Q(tags__icontains=search)
            )

        author = self.request.query_params.get('author')
        if author:
            queryset = queryset.filter(author_id=author)

        return queryset


class IngredientPostCreateView(generics.CreateAPIView):
    """Create a new ingredient post.

    UserPost / ingredient_count / points are handled by
    users.signals.handle_ingredient_post. Do NOT duplicate them here.
    """
    serializer_class = IngredientPostCreateSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context

    def create(self, request, *args, **kwargs):
        data = {}

        simple_fields = ['title', 'content']
        for field in simple_fields:
            if field in request.POST:
                data[field] = request.POST[field]

        if 'tags' in request.POST:
            try:
                data['tags'] = json.loads(request.POST['tags'])
            except json.JSONDecodeError:
                tags_str = request.POST['tags']
                data['tags'] = [tag.strip() for tag in tags_str.split(',') if tag.strip()]
        else:
            data['tags'] = []

        photo_urls = []

        if 'photo_urls' in request.FILES:
            for photo in request.FILES.getlist('photo_urls'):
                photo_urls.append(_save_uploaded_file(photo, 'ingredient_photos'))
        elif 'photos' in request.FILES:
            for photo in request.FILES.getlist('photos'):
                photo_urls.append(_save_uploaded_file(photo, 'ingredient_photos'))

        data['photo_urls'] = photo_urls
        if photo_urls:
            data['image_url'] = photo_urls[0]

        if 'video_url' in request.FILES:
            data['video_url'] = _save_uploaded_file(request.FILES['video_url'], 'ingredient_videos')
        elif 'video' in request.FILES:
            data['video_url'] = _save_uploaded_file(request.FILES['video'], 'ingredient_videos')

        if 'video_cover_url' in request.FILES:
            data['video_cover_url'] = _save_uploaded_file(request.FILES['video_cover_url'], 'ingredient_covers')
        elif 'video_cover' in request.FILES:
            data['video_cover_url'] = _save_uploaded_file(request.FILES['video_cover'], 'ingredient_covers')

        serializer = self.get_serializer(data=data)

        try:
            serializer.is_valid(raise_exception=True)
        except Exception as e:
            print("Serializer validation error:", e)
            print("Serializer errors:", serializer.errors)
            return Response({
                'success': False,
                'error': str(e),
                'details': serializer.errors
            }, status=status.HTTP_400_BAD_REQUEST)

        post = serializer.save()
        # UserPost, ingredient_count, and points handled by signals.

        return Response({
            'success': True,
            'message': 'Post created successfully',
            'data': {
                'id': str(post.id),
                'title': post.title,
                'photo_urls': post.photo_urls,
                'video_url': post.video_url if post.video_url else None,
            }
        }, status=status.HTTP_201_CREATED)


class IngredientPostDetailView(generics.RetrieveAPIView):
    """Get single ingredient post."""
    queryset = IngredientPost.objects.all()
    serializer_class = IngredientPostSerializer
    permission_classes = [permissions.AllowAny]
    lookup_field = 'id'


class IngredientPostUpdateView(generics.GenericAPIView):
    """Update an ingredient post (POST or PUT; front-end uses POST)."""
    queryset = IngredientPost.objects.all()
    serializer_class = IngredientPostUpdateSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    lookup_field = 'id'

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context

    def _get_post(self, id):
        try:
            return IngredientPost.objects.get(id=id)
        except IngredientPost.DoesNotExist:
            return None

    def _process_update(self, request, id):
        post = self._get_post(id)
        if post is None:
            return Response({'success': False, 'error': 'Post not found'}, status=status.HTTP_404_NOT_FOUND)

        if post.author != request.user:
            return Response({'success': False, 'error': 'You can only edit your own posts'}, status=status.HTTP_403_FORBIDDEN)

        data = {}

        for field in ['title', 'content']:
            if field in request.POST:
                data[field] = request.POST[field]

        if 'tags' in request.POST:
            try:
                data['tags'] = json.loads(request.POST['tags'])
            except json.JSONDecodeError:
                tags_str = request.POST['tags']
                data['tags'] = [tag.strip() for tag in tags_str.split(',') if tag.strip()]

        existing_photos = []
        if 'existing_photo_urls' in request.POST:
            try:
                existing_photos = json.loads(request.POST['existing_photo_urls'])
                if not isinstance(existing_photos, list):
                    existing_photos = []
            except Exception:
                existing_photos = []

        new_photo_urls = []
        if 'new_photos' in request.FILES:
            for photo in request.FILES.getlist('new_photos'):
                new_photo_urls.append(_save_uploaded_file(photo, 'ingredient_photos'))

        if 'existing_photo_urls' in request.POST or 'new_photos' in request.FILES:
            final_photos = existing_photos + new_photo_urls
            data['photo_urls'] = final_photos
            data['image_url'] = final_photos[0] if final_photos else None

        if 'remove_video' in request.POST and request.POST['remove_video'] == 'true':
            data['video_url'] = None
        elif 'new_video' in request.FILES:
            data['video_url'] = _save_uploaded_file(request.FILES['new_video'], 'ingredient_videos')
        elif 'existing_video_url' in request.POST:
            existing_video = request.POST['existing_video_url']
            data['video_url'] = existing_video if existing_video else None

        if 'remove_video_cover' in request.POST and request.POST['remove_video_cover'] == 'true':
            data['video_cover_url'] = None
        elif 'new_video_cover' in request.FILES:
            data['video_cover_url'] = _save_uploaded_file(request.FILES['new_video_cover'], 'ingredient_covers')
        elif 'existing_video_cover_url' in request.POST:
            existing_cover = request.POST['existing_video_cover_url']
            data['video_cover_url'] = existing_cover if existing_cover else None

        serializer = self.get_serializer(post, data=data, partial=True)
        serializer.is_valid(raise_exception=True)
        updated = serializer.save()

        updated.edited_at = timezone.now()
        updated.save(update_fields=['edited_at', 'updated_at'])

        return Response({
            'success': True,
            'message': 'Post updated successfully',
            'data': {
                'id': str(updated.id),
                'title': updated.title,
                'edited_at': updated.edited_at.isoformat() if updated.edited_at else None
            }
        }, status=status.HTTP_200_OK)

    def post(self, request, id):
        return self._process_update(request, id)

    def put(self, request, id):
        return self._process_update(request, id)


class IngredientPostDeleteView(generics.GenericAPIView):
    """Delete an ingredient post.

    UserPost / ingredient_count handled by signals.delete_ingredient_post.
    UserLike / UserComment cleanup done here (signals don't cover them).
    """
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'id'

    def delete(self, request, id):
        try:
            post = IngredientPost.objects.get(id=id)
        except IngredientPost.DoesNotExist:
            return Response({'success': False, 'error': 'Post not found'}, status=status.HTTP_404_NOT_FOUND)

        if post.author != request.user:
            return Response({'success': False, 'error': 'You can only delete your own posts'}, status=status.HTTP_403_FORBIDDEN)

        post_id_str = str(post.id)

        for photo_url in (post.photo_urls or []):
            _try_delete_file(photo_url)
        _try_delete_file(post.video_url)
        _try_delete_file(post.video_cover_url)

        post.delete()

        try:
            UserLike.objects.filter(
                like_type=UserLike.LikeType.INGREDIENT,
                post_id=post_id_str
            ).delete()
            UserComment.objects.filter(
                comment_type=UserComment.CommentType.INGREDIENT,
                post_id=post_id_str
            ).delete()
        except Exception as e:
            print(f"Sync delete error: {e}")

        return Response({
            'success': True,
            'message': 'Post deleted successfully'
        }, status=status.HTTP_200_OK)


class IngredientPostLikeView(generics.GenericAPIView):
    """Like / unlike an ingredient post and keep UserLike in sync."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, id):
        try:
            post = IngredientPost.objects.get(id=id)
        except IngredientPost.DoesNotExist:
            return Response({'error': 'Post not found'}, status=status.HTTP_404_NOT_FOUND)

        post_id_str = str(post.id)

        if request.user in post.likes.all():
            post.likes.remove(request.user)
            liked = False

            try:
                UserLike.objects.filter(
                    user=request.user,
                    like_type=UserLike.LikeType.INGREDIENT,
                    post_id=post_id_str
                ).delete()
                if request.user.ingredient_likes_given > 0:
                    request.user.ingredient_likes_given -= 1
                    request.user.save()
                author = post.author
                if author.ingredient_likes_received > 0:
                    author.ingredient_likes_received -= 1
                    author.save()
            except Exception as e:
                print(f"UserLike sync error (unlike): {e}")
        else:
            post.likes.add(request.user)
            liked = True

            try:
                UserLike.objects.get_or_create(
                    user=request.user,
                    like_type=UserLike.LikeType.INGREDIENT,
                    post_id=post_id_str
                )
                request.user.ingredient_likes_given += 1
                request.user.save()
                author = post.author
                author.ingredient_likes_received += 1
                author.save()
            except Exception as e:
                print(f"UserLike sync error (like): {e}")

        return Response({
            'liked': liked,
            'likes_count': post.like_count()
        })


class LikedIngredientPostsView(generics.ListAPIView):
    """Posts the current user has liked."""
    serializer_class = IngredientPostSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return IngredientPost.objects.filter(
            likes=self.request.user
        ).order_by('-created_at')


class MyIngredientCommentsView(generics.GenericAPIView):
    """Posts the current user has commented on."""
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        comments = IngredientComment.objects.filter(
            user=request.user
        ).select_related('post').order_by('-created_at')

        data = []
        for c in comments:
            post = c.post
            cover = post.image_url or ''
            if not cover and post.photo_urls:
                cover = post.photo_urls[0] if post.photo_urls else ''

            data.append({
                'id': str(c.id),
                'comment_id': str(c.id),
                'post_id': str(post.id),
                'post_title': post.title,
                'post_image': cover,
                'text': c.text,
                'user_name': request.user.username,
                'created_at': c.created_at.isoformat(),
                'likes': 0,
            })

        return Response(data, status=status.HTTP_200_OK)


class IngredientCommentListView(generics.ListCreateAPIView):
    """List and create comments for an ingredient post."""
    serializer_class = IngredientCommentSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

    def get_queryset(self):
        post_id = self.kwargs.get('post_id')
        return IngredientComment.objects.filter(post_id=post_id).order_by('-created_at')

    def perform_create(self, serializer):
        post_id = self.kwargs.get('post_id')
        post = IngredientPost.objects.get(id=post_id)
        post.comments_count += 1
        post.save(update_fields=['comments_count'])
        comment = serializer.save(user=self.request.user, post=post)

        try:
            UserComment.objects.create(
                user=self.request.user,
                comment_type=UserComment.CommentType.INGREDIENT,
                post_id=str(post.id),
                comment_id=str(comment.id),
                content=comment.text
            )
            self.request.user.ingredient_comments += 1
            self.request.user.save()
        except Exception as e:
            print(f"UserComment sync error: {e}")


class IngredientCommentDetailView(generics.GenericAPIView):
    """DELETE /api/ingredients/comments/{id}/"""
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'id'

    def delete(self, request, id):
        try:
            comment = IngredientComment.objects.get(id=id)
        except IngredientComment.DoesNotExist:
            return Response({'success': False, 'error': 'Comment not found'}, status=status.HTTP_404_NOT_FOUND)

        if comment.user != request.user:
            return Response({'success': False, 'error': 'You can only delete your own comments'}, status=status.HTTP_403_FORBIDDEN)

        post = comment.post
        comment_id_str = str(comment.id)
        post_id_str = str(post.id)

        if post.comments_count > 0:
            post.comments_count -= 1
            post.save(update_fields=['comments_count'])

        comment.delete()

        try:
            UserComment.objects.filter(
                user=request.user,
                comment_type=UserComment.CommentType.INGREDIENT,
                post_id=post_id_str,
                comment_id=comment_id_str
            ).delete()
            if request.user.ingredient_comments > 0:
                request.user.ingredient_comments -= 1
                request.user.save()
        except Exception as e:
            print(f"UserComment sync delete error: {e}")

        return Response({
            'success': True,
            'message': 'Comment deleted successfully'
        }, status=status.HTTP_200_OK)


@require_GET
def stream_video(request, video_path):
    """Simple video streaming (development)."""
    file_path = os.path.join(settings.MEDIA_ROOT, video_path)

    if not os.path.exists(file_path):
        raise Http404("Video not found")

    try:
        with open(file_path, 'rb') as f:
            video_data = f.read()
    except Exception as e:
        return HttpResponse(f'Error reading file: {e}', status=500)

    file_size = len(video_data)

    ext = os.path.splitext(file_path)[1].lower()
    mime_types = {
        '.mp4': 'video/mp4',
        '.mov': 'video/quicktime',
        '.avi': 'video/x-msvideo',
        '.mkv': 'video/x-matroska',
        '.webm': 'video/webm',
        '.3gp': 'video/3gpp',
        '.flv': 'video/x-flv',
        '.wmv': 'video/x-ms-wmv',
        '.m4v': 'video/x-m4v',
        '.mpeg': 'video/mpeg',
    }
    content_type = mime_types.get(ext, 'video/mp4')

    response = HttpResponse(video_data, content_type=content_type, status=200)
    response['Content-Length'] = str(file_size)
    response['Content-Disposition'] = f'inline; filename="{os.path.basename(file_path)}"'

    return response


class UserLikedIngredientPostsView(generics.ListAPIView):
    """Liked ingredient posts of a public user_id."""
    serializer_class = IngredientPostSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        user_id = self.kwargs.get('user_id')
        from users.models import User

        try:
            user = User.objects.get(user_id=user_id)
        except User.DoesNotExist:
            return IngredientPost.objects.none()

        return IngredientPost.objects.filter(likes=user).order_by('-created_at')


class UserIngredientCommentsView(generics.GenericAPIView):
    """Comments on ingredient posts by a public user_id."""
    permission_classes = [permissions.AllowAny]

    def get(self, request, user_id):
        from users.models import User

        try:
            user = User.objects.get(user_id=user_id)
        except User.DoesNotExist:
            return Response([], status=status.HTTP_200_OK)

        comments = IngredientComment.objects.filter(
            user=user
        ).select_related('post').order_by('-created_at')

        data = []
        for c in comments:
            post = c.post
            cover = post.image_url or ''
            if not cover and post.photo_urls:
                cover = post.photo_urls[0] if post.photo_urls else ''

            data.append({
                'id': str(c.id),
                'comment_id': str(c.id),
                'post_id': str(post.id),
                'post_title': post.title,
                'post_image': cover,
                'text': c.text,
                'user_name': user.username,
                'created_at': c.created_at.isoformat(),
                'likes': 0,
            })

        return Response(data, status=status.HTTP_200_OK)