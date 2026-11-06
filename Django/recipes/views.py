# recipes/views.py
from rest_framework import generics, status, permissions
from rest_framework.decorators import api_view, permission_classes, authentication_classes
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.permissions import IsAuthenticated
from django.db.models import Q
from django.core.files.storage import default_storage
from django.core.files.base import ContentFile
from django.utils import timezone
import uuid
import os
import base64
import re
import json
from .models import Recipe, Comment, Homework, CarouselItem
from .serializers import (
    RecipeListSerializer, RecipeDetailSerializer,
    RecipeCreateSerializer, RecipeUpdateSerializer,
    CommentSerializer, HomeworkSerializer,
    CommentCreateSerializer, HomeworkCreateSerializer,
    HomeworkUpdateSerializer,
    CarouselItemSerializer
)

# Sync helpers for the users app
from users.models import UserLike, UserComment, UserPost, AdminUser


# ==================== Admin auth helpers ====================

def _get_admin_from_request(request):
    """
    Return an admin-like object for permission checks.

    Priority:
    1. DRF-authenticated staff user (via TokenAuthentication on mirror User).
    2. Legacy: raw Token value equals AdminUser.admin_id.
    """
    from users.models import AdminUser

    user = getattr(request, 'user', None)
    if user is not None and getattr(user, 'is_authenticated', False) \
            and (getattr(user, 'is_staff', False) or getattr(user, 'is_superuser', False)):
        admin_row = AdminUser.objects.filter(email=user.email).first()
        return admin_row if admin_row is not None else user

    auth = request.headers.get('Authorization', '')
    if not auth.startswith('Token '):
        return None
    token = auth.replace('Token ', '').strip()
    if not token:
        return None
    try:
        return AdminUser.objects.get(admin_id=token, is_active=True)
    except AdminUser.DoesNotExist:
        return None


def _check_admin(request):
    return _get_admin_from_request(request) is not None


# ==================== File helpers (store relative /media/... paths) ====================

def _save_uploaded_file(file, folder):
    filename = f"{folder}/{uuid.uuid4().hex}_{file.name}"
    saved_path = default_storage.save(filename, file)
    return default_storage.url(saved_path)


def _save_base64_file(base64_string, folder='recipes/'):
    if not base64_string or base64_string == 'null':
        return None
    format, imgstr = base64_string.split(';base64,')
    ext = format.split('/')[-1]
    filename = f"{folder}/{uuid.uuid4().hex}.{ext}"
    file_content = ContentFile(base64.b64decode(imgstr))
    saved_path = default_storage.save(filename, file_content)
    return default_storage.url(saved_path)


def _try_delete_file(url):
    """Best-effort deletion of a media file, accepting /media/..., media/..., or full URLs."""
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


# ==================== Recipe Views ====================

class RecipeListView(generics.ListAPIView):
    """List all recipes with filtering."""
    serializer_class = RecipeListSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        queryset = Recipe.objects.all().order_by('-created_at')

        search = self.request.query_params.get('search')
        if search:
            queryset = queryset.filter(
                Q(title__icontains=search) |
                Q(description__icontains=search) |
                Q(author__username__icontains=search) |
                Q(tags__name__icontains=search) |
                Q(ingredients__name__icontains=search) |
                Q(cuisine_type__icontains=search) |
                Q(cooking_tools__name__icontains=search)
            ).distinct()

            if any(char.isdigit() for char in search):
                numbers = re.findall(r'\d+', search)
                for num in numbers:
                    try:
                        num_int = int(num)
                        number_query = Q(duration_minutes=num_int) | Q(difficulty_level=num_int)
                        queryset = queryset | Recipe.objects.filter(number_query)
                    except Exception:
                        pass
                queryset = queryset.distinct()

        cuisine = self.request.query_params.get('cuisine')
        if cuisine:
            cuisine_list = cuisine.split(',')
            cuisine_query = Q()
            for c in cuisine_list:
                cuisine_query |= Q(cuisine_type__icontains=c.strip())
            queryset = queryset.filter(cuisine_query).distinct()

        difficulty = self.request.query_params.get('difficulty')
        if difficulty:
            queryset = queryset.filter(difficulty_level=difficulty)

        max_duration = self.request.query_params.get('max_duration')
        if max_duration:
            queryset = queryset.filter(duration_minutes__lte=int(max_duration))

        ingredients = self.request.query_params.get('ingredients')
        if ingredients:
            ingredient_list = ingredients.split(',')
            ingredient_query = Q()
            for ing in ingredient_list:
                ingredient_query |= Q(ingredients__name__icontains=ing.strip())
            queryset = queryset.filter(ingredient_query).distinct()

        tools = self.request.query_params.get('tools')
        if tools:
            tool_list = tools.split(',')
            tool_query = Q()
            for tool in tool_list:
                tool_query |= Q(cooking_tools__name__icontains=tool.strip())
            queryset = queryset.filter(tool_query).distinct()

        author = self.request.query_params.get('author')
        if author:
            queryset = queryset.filter(author_id=author)

        return queryset


class RecipeDetailView(generics.RetrieveAPIView):
    """Get single recipe details."""
    queryset = Recipe.objects.all()
    serializer_class = RecipeDetailSerializer
    permission_classes = [permissions.AllowAny]
    lookup_field = 'id'


class RecipeCreateView(generics.CreateAPIView):
    """Create a new recipe with photos and video.

    Points, UserPost, and recipe_count are handled by
    users.signals.handle_recipe_post — do NOT duplicate them here.
    """
    serializer_class = RecipeCreateSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context

    def create(self, request, *args, **kwargs):
        data = {}

        json_fields = ['tags', 'cooking_tools', 'ingredients', 'steps']
        for field in json_fields:
            if field in request.POST:
                try:
                    data[field] = json.loads(request.POST[field])
                except Exception:
                    data[field] = []

        simple_fields = ['title', 'description', 'cuisine_type', 'duration_minutes', 'difficulty_level']
        for field in simple_fields:
            if field in request.POST:
                if field in ['duration_minutes', 'difficulty_level']:
                    data[field] = int(request.POST[field])
                else:
                    data[field] = request.POST[field]

        photo_urls = []

        if 'photos' in request.FILES:
            for photo in request.FILES.getlist('photos'):
                photo_urls.append(_save_uploaded_file(photo, 'recipes'))

        if 'photos_base64' in request.POST:
            try:
                base64_photos = json.loads(request.POST['photos_base64'])
                for photo_base64 in base64_photos:
                    url = _save_base64_file(photo_base64, 'recipes')
                    if url:
                        photo_urls.append(url)
            except Exception:
                pass

        data['photo_urls'] = photo_urls

        video_url = None
        if 'video' in request.FILES:
            video_url = _save_uploaded_file(request.FILES['video'], 'videos')
        elif 'video_base64' in request.POST and request.POST['video_base64']:
            video_url = _save_base64_file(request.POST['video_base64'], 'videos/')

        data['video_url'] = video_url

        video_cover_url = None
        if 'video_cover' in request.FILES:
            video_cover_url = _save_uploaded_file(request.FILES['video_cover'], 'covers')
        elif 'video_cover_base64' in request.POST and request.POST['video_cover_base64']:
            video_cover_url = _save_base64_file(request.POST['video_cover_base64'], 'covers/')

        data['video_cover_url'] = video_cover_url

        if photo_urls:
            data['image_url'] = photo_urls[0]
        elif video_cover_url:
            data['image_url'] = video_cover_url
        elif video_url:
            data['image_url'] = video_url

        serializer = self.get_serializer(data=data)
        serializer.is_valid(raise_exception=True)

        recipe = serializer.save()
        # UserPost, recipe_count, and points are handled by
        # users.signals.handle_recipe_post. Do NOT duplicate them here.

        return Response({
            'success': True,
            'message': 'Recipe created successfully',
            'data': {
                'id': str(recipe.id),
                'title': recipe.title
            }
        }, status=status.HTTP_201_CREATED)


class RecipeUpdateView(generics.GenericAPIView):
    """Update a recipe (POST or PUT; front-end uses POST for multipart)."""
    queryset = Recipe.objects.all()
    serializer_class = RecipeUpdateSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    lookup_field = 'id'

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context

    def _get_recipe(self, id):
        try:
            return Recipe.objects.get(id=id)
        except Recipe.DoesNotExist:
            return None

    def _process_update(self, request, id):
        recipe = self._get_recipe(id)
        if recipe is None:
            return Response({
                'success': False,
                'error': 'Recipe not found'
            }, status=status.HTTP_404_NOT_FOUND)

        if recipe.author != request.user:
            return Response({
                'success': False,
                'error': 'You can only edit your own recipes'
            }, status=status.HTTP_403_FORBIDDEN)

        data = {}

        json_fields = ['tags', 'cooking_tools', 'ingredients', 'steps']
        for field in json_fields:
            if field in request.POST:
                try:
                    data[field] = json.loads(request.POST[field])
                except Exception:
                    pass

        simple_fields = ['title', 'description', 'cuisine_type', 'duration_minutes', 'difficulty_level']
        for field in simple_fields:
            if field in request.POST:
                if field in ['duration_minutes', 'difficulty_level']:
                    try:
                        data[field] = int(request.POST[field])
                    except Exception:
                        pass
                else:
                    data[field] = request.POST[field]

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
                new_photo_urls.append(_save_uploaded_file(photo, 'recipes'))

        if 'existing_photo_urls' in request.POST or 'new_photos' in request.FILES:
            final_photos = existing_photos + new_photo_urls
            data['photo_urls'] = final_photos
            if final_photos:
                data['image_url'] = final_photos[0]

        if 'remove_video' in request.POST and request.POST['remove_video'] == 'true':
            data['video_url'] = None
        elif 'new_video' in request.FILES:
            data['video_url'] = _save_uploaded_file(request.FILES['new_video'], 'videos')
        elif 'existing_video_url' in request.POST:
            existing_video = request.POST['existing_video_url']
            data['video_url'] = existing_video if existing_video else None

        if 'remove_video_cover' in request.POST and request.POST['remove_video_cover'] == 'true':
            data['video_cover_url'] = None
        elif 'new_video_cover' in request.FILES:
            data['video_cover_url'] = _save_uploaded_file(request.FILES['new_video_cover'], 'covers')
        elif 'existing_video_cover_url' in request.POST:
            existing_cover = request.POST['existing_video_cover_url']
            data['video_cover_url'] = existing_cover if existing_cover else None

        serializer = self.get_serializer(recipe, data=data, partial=True)
        serializer.is_valid(raise_exception=True)
        updated = serializer.save()

        updated.edited_at = timezone.now()
        updated.save(update_fields=['edited_at', 'updated_at'])

        return Response({
            'success': True,
            'message': 'Recipe updated successfully',
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


class RecipeDeleteView(generics.DestroyAPIView):
    """Delete a recipe.

    UserPost / recipe_count are handled by users.signals.delete_recipe_post.
    UserLike / UserComment cleanup is done here (signals don't cover them).
    """
    queryset = Recipe.objects.all()
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'id'

    def destroy(self, request, *args, **kwargs):
        try:
            recipe = self.get_queryset().get(id=kwargs['id'])
        except Recipe.DoesNotExist:
            return Response({
                'success': False,
                'error': 'Recipe not found'
            }, status=status.HTTP_404_NOT_FOUND)

        if recipe.author != request.user:
            return Response({
                'success': False,
                'error': 'You can only delete your own recipes'
            }, status=status.HTTP_403_FORBIDDEN)

        recipe_id_str = str(recipe.id)

        for photo_url in recipe.photo_urls or []:
            _try_delete_file(photo_url)
        _try_delete_file(recipe.video_url)
        _try_delete_file(recipe.video_cover_url)

        recipe.delete()

        # Cascade clean-up for like/comment records. UserPost + recipe_count
        # are handled by the post_delete signal.
        try:
            UserLike.objects.filter(
                like_type=UserLike.LikeType.RECIPE,
                post_id=recipe_id_str
            ).delete()
            UserComment.objects.filter(
                comment_type=UserComment.CommentType.RECIPE,
                post_id=recipe_id_str
            ).delete()
        except Exception as e:
            print(f"Sync delete error: {e}")

        return Response({
            'success': True,
            'message': 'Recipe deleted successfully'
        }, status=status.HTTP_200_OK)


class RecipeLikeView(generics.GenericAPIView):
    """Like / unlike a recipe and keep UserLike in sync."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, id):
        try:
            recipe = Recipe.objects.get(id=id)
        except Recipe.DoesNotExist:
            return Response({'error': 'Recipe not found'}, status=status.HTTP_404_NOT_FOUND)

        recipe_id_str = str(recipe.id)

        if request.user in recipe.likes.all():
            recipe.likes.remove(request.user)
            liked = False

            try:
                UserLike.objects.filter(
                    user=request.user,
                    like_type=UserLike.LikeType.RECIPE,
                    post_id=recipe_id_str
                ).delete()
                if request.user.recipe_likes_given > 0:
                    request.user.recipe_likes_given -= 1
                    request.user.save()
                author = recipe.author
                if author.recipe_likes_received > 0:
                    author.recipe_likes_received -= 1
                    author.save()
            except Exception as e:
                print(f"UserLike sync error (unlike): {e}")
        else:
            recipe.likes.add(request.user)
            liked = True

            try:
                UserLike.objects.get_or_create(
                    user=request.user,
                    like_type=UserLike.LikeType.RECIPE,
                    post_id=recipe_id_str
                )
                request.user.recipe_likes_given += 1
                request.user.save()
                author = recipe.author
                author.recipe_likes_received += 1
                author.save()
            except Exception as e:
                print(f"UserLike sync error (like): {e}")

        return Response({
            'success': True,
            'liked': liked,
            'likes_count': recipe.like_count()
        })


class LikedRecipesView(generics.ListAPIView):
    serializer_class = RecipeListSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Recipe.objects.filter(
            likes=self.request.user
        ).order_by('-created_at')


class MyRecipeCommentsView(generics.GenericAPIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        comments = Comment.objects.filter(
            user=request.user,
            recipe__isnull=False
        ).select_related('recipe').order_by('-created_at')

        data = []
        for c in comments:
            recipe = c.recipe
            cover = recipe.image_url or ''
            if not cover and recipe.photo_urls:
                cover = recipe.photo_urls[0] if recipe.photo_urls else ''

            data.append({
                'id': str(c.id),
                'comment_id': str(c.id),
                'post_id': str(recipe.id),
                'recipe_title': recipe.title,
                'recipe_image': cover,
                'text': c.text,
                'user_name': request.user.username,
                'photo_urls': c.photo_urls,
                'created_at': c.created_at.isoformat(),
                'likes': 0,
            })

        return Response(data, status=status.HTTP_200_OK)


# ==================== Comment Views ====================

class CommentListView(generics.ListCreateAPIView):
    """List and create comments for a recipe."""
    serializer_class = CommentSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_queryset(self):
        recipe_id = self.kwargs.get('recipe_id')
        return Comment.objects.filter(recipe_id=recipe_id).order_by('-created_at')

    def create(self, request, *args, **kwargs):
        recipe_id = self.kwargs.get('recipe_id')

        try:
            recipe = Recipe.objects.get(id=recipe_id)
        except Recipe.DoesNotExist:
            return Response({'error': 'Recipe not found'}, status=status.HTTP_404_NOT_FOUND)

        text = request.data.get('text') or request.data.get('content') or ''

        if not text.strip():
            return Response({'error': 'Comment text is required'}, status=status.HTTP_400_BAD_REQUEST)

        photo_urls = []

        if 'photo_urls' in request.data:
            photo_urls_data = request.data.get('photo_urls')
            if isinstance(photo_urls_data, list):
                photo_urls = photo_urls_data
            elif isinstance(photo_urls_data, str):
                try:
                    photo_urls = json.loads(photo_urls_data)
                except Exception:
                    photo_urls = []

        if 'photos' in request.FILES:
            for photo in request.FILES.getlist('photos'):
                photo_urls.append(_save_uploaded_file(photo, 'comments'))

        if 'photos_base64' in request.data:
            try:
                base64_photos = request.data.get('photos_base64')
                if isinstance(base64_photos, str):
                    base64_photos = json.loads(base64_photos)
                for photo_base64 in base64_photos:
                    url = _save_base64_file(photo_base64, 'comments/')
                    if url:
                        photo_urls.append(url)
            except Exception as e:
                print(f"Base64 photo error: {e}")

        comment = Comment.objects.create(
            user=request.user,
            recipe=recipe,
            text=text.strip(),
            photo_urls=photo_urls
        )

        recipe.comments_count += 1
        recipe.save()

        try:
            UserComment.objects.create(
                user=request.user,
                comment_type=UserComment.CommentType.RECIPE,
                post_id=str(recipe.id),
                comment_id=str(comment.id),
                content=comment.text
            )
            request.user.recipe_comments += 1
            request.user.save()
        except Exception as e:
            print(f"UserComment sync error: {e}")

        serializer = CommentSerializer(comment, context={'request': request})
        return Response(serializer.data, status=status.HTTP_201_CREATED)


class CommentDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Retrieve, update or delete a comment."""
    queryset = Comment.objects.all()
    serializer_class = CommentSerializer
    permission_classes = [permissions.IsAuthenticated]
    lookup_field = 'id'

    def destroy(self, request, *args, **kwargs):
        comment = self.get_object()

        if comment.user != request.user:
            return Response({'error': 'You can only delete your own comments'}, status=status.HTTP_403_FORBIDDEN)

        recipe = comment.recipe
        comment_id_str = str(comment.id)
        recipe_id_str = str(recipe.id)

        if recipe.comments_count > 0:
            recipe.comments_count -= 1
            recipe.save()

        comment.delete()

        try:
            UserComment.objects.filter(
                user=request.user,
                comment_type=UserComment.CommentType.RECIPE,
                post_id=recipe_id_str,
                comment_id=comment_id_str
            ).delete()
            if request.user.recipe_comments > 0:
                request.user.recipe_comments -= 1
                request.user.save()
        except Exception as e:
            print(f"UserComment sync delete error: {e}")

        return Response({
            'success': True,
            'message': 'Comment deleted successfully'
        }, status=status.HTTP_200_OK)


# ==================== Homework (Dishes) Views ====================

class HomeworkListView(generics.ListCreateAPIView):
    """List and create homework (dishes) for a recipe.

    UserPost creation, dish_count, and points are all handled by
    users.signals.handle_dish_post — do NOT duplicate them here.
    """
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_serializer_class(self):
        if self.request.method == 'POST':
            return HomeworkCreateSerializer
        return HomeworkSerializer

    def get_queryset(self):
        recipe_id = self.kwargs.get('recipe_id')
        return Homework.objects.filter(recipe_id=recipe_id).select_related('user', 'recipe').order_by('-created_at')

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context

    def create(self, request, *args, **kwargs):
        recipe_id = self.kwargs.get('recipe_id')

        try:
            recipe = Recipe.objects.get(id=recipe_id)
        except Recipe.DoesNotExist:
            return Response({'error': 'Recipe not found'}, status=status.HTTP_404_NOT_FOUND)

        existing = Homework.objects.filter(user=request.user, recipe=recipe).first()

        if existing:
            return Response({
                'error': 'You have already submitted a dish for this recipe',
                'homework_id': str(existing.id)
            }, status=status.HTTP_400_BAD_REQUEST)

        data = {}

        if 'review' in request.POST:
            data['review'] = request.POST['review']
        if 'rating' in request.POST:
            data['rating'] = request.POST['rating']

        if 'image' in request.FILES:
            data['image'] = request.FILES['image']
        elif 'image_base64' in request.POST and request.POST['image_base64']:
            data['image_url'] = request.POST['image_base64']

        serializer = HomeworkCreateSerializer(
            data=data,
            context={'request': request, 'recipe': recipe}
        )

        if serializer.is_valid():
            homework = serializer.save()
            recipe.dishes_count += 1
            recipe.save(update_fields=['dishes_count'])

            # UserPost + dish_count + points handled by signals.handle_dish_post.

            return Response(
                HomeworkSerializer(homework, context={'request': request}).data,
                status=status.HTTP_201_CREATED
            )

        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class HomeworkDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Retrieve, update or delete a homework."""
    queryset = Homework.objects.all()
    serializer_class = HomeworkSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    lookup_field = 'id'

    def get_serializer_class(self):
        if self.request.method in ['PUT', 'PATCH']:
            return HomeworkUpdateSerializer
        return HomeworkSerializer

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context

    def update(self, request, *args, **kwargs):
        homework = self.get_object()

        if homework.user != request.user:
            return Response({'error': 'You can only edit your own dishes'}, status=status.HTTP_403_FORBIDDEN)

        data = {}

        if 'review' in request.POST:
            data['review'] = request.POST['review']
        if 'rating' in request.POST:
            data['rating'] = request.POST['rating']

        if 'image' in request.FILES:
            data['image'] = request.FILES['image']
        elif 'image_base64' in request.POST and request.POST['image_base64']:
            data['image_url'] = request.POST['image_base64']

        serializer = HomeworkUpdateSerializer(
            homework,
            data=data,
            partial=True,
            context={'request': request}
        )

        if serializer.is_valid():
            serializer.save()
            return Response(
                HomeworkSerializer(homework, context={'request': request}).data
            )

        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def destroy(self, request, *args, **kwargs):
        homework = self.get_object()

        if homework.user != request.user:
            return Response({'error': 'You can only delete your own dishes'}, status=status.HTTP_403_FORBIDDEN)

        recipe = homework.recipe

        if recipe.dishes_count > 0:
            recipe.dishes_count -= 1
            recipe.save(update_fields=['dishes_count'])

        if homework.image:
            try:
                if default_storage.exists(homework.image.path):
                    default_storage.delete(homework.image.path)
            except Exception:
                pass

        homework.delete()

        # UserPost + dish_count handled by signals.delete_dish_post.

        return Response({
            'success': True,
            'message': 'Dish deleted successfully'
        }, status=status.HTTP_200_OK)


class MyHomeworkView(generics.ListAPIView):
    serializer_class = HomeworkSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Homework.objects.filter(
            user=self.request.user
        ).select_related('recipe').order_by('-created_at')

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context


class UserHomeworkView(generics.ListAPIView):
    serializer_class = HomeworkSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        user_id = self.kwargs.get('user_id')
        return Homework.objects.filter(
            user__user_id=user_id
        ).select_related('recipe').order_by('-created_at')

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context


# ==================== User Recipe Views ====================

class UserRecipesView(generics.ListAPIView):
    """Get recipes created by a user."""
    serializer_class = RecipeListSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        user_id = self.kwargs.get('user_id')
        return Recipe.objects.filter(author_id=user_id).order_by('-created_at')


class TrendingRecipesView(generics.ListAPIView):
    """Get trending recipes (most liked)."""
    serializer_class = RecipeListSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        return Recipe.objects.all().order_by('-likes__count')[:10]


@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def get_cuisine_types(request):
    """Get all unique cuisine types."""
    cuisines = Recipe.objects.exclude(cuisine_type='').values_list('cuisine_type', flat=True).distinct()
    return Response(list(cuisines))


# ==================== Carousel Views ====================

class CarouselListView(generics.ListAPIView):
    """Public: only active carousel items."""
    serializer_class = CarouselItemSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        return CarouselItem.objects.filter(is_active=True).order_by('order', 'created_at')


class CarouselAdminListView(generics.ListCreateAPIView):
    """Admin: list all + create."""
    serializer_class = CarouselItemSerializer
    permission_classes = [permissions.AllowAny]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_queryset(self):
        return CarouselItem.objects.all().order_by('order', 'created_at')

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context

    def list(self, request, *args, **kwargs):
        if not _check_admin(request):
            return Response({'success': False, 'error': 'Forbidden'}, status=403)
        return super().list(request, *args, **kwargs)

    def create(self, request, *args, **kwargs):
        if not _check_admin(request):
            return Response({'success': False, 'error': 'Forbidden'}, status=403)
        return super().create(request, *args, **kwargs)


class CarouselSearchView(generics.ListAPIView):
    """Search recipes using keyword list with OR logic."""
    serializer_class = RecipeListSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        keywords = self.request.query_params.get('keywords', '')
        if not keywords:
            return Recipe.objects.none()

        keyword_list = [k.strip() for k in keywords.split(',') if k.strip()]
        if not keyword_list:
            return Recipe.objects.none()

        query = Q()
        for keyword in keyword_list:
            query |= Q(title__icontains=keyword)
            query |= Q(description__icontains=keyword)
            query |= Q(tags__name__icontains=keyword)
            query |= Q(ingredients__name__icontains=keyword)
            query |= Q(cuisine_type__icontains=keyword)
            query |= Q(author__username__icontains=keyword)
            query |= Q(cooking_tools__name__icontains=keyword)

        return Recipe.objects.filter(query).distinct().order_by('-created_at')


class CarouselCreateView(generics.CreateAPIView):
    """Admin: create carousel item (multipart upload)."""
    serializer_class = CarouselItemSerializer
    permission_classes = [permissions.AllowAny]
    parser_classes = [MultiPartParser, FormParser]

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context

    def create(self, request, *args, **kwargs):
        if not _check_admin(request):
            return Response({'success': False, 'error': 'Forbidden'}, status=403)
        return super().create(request, *args, **kwargs)


class CarouselDetailView(generics.RetrieveUpdateDestroyAPIView):
    """Public GET / Admin PATCH/DELETE."""
    queryset = CarouselItem.objects.all()
    serializer_class = CarouselItemSerializer
    permission_classes = [permissions.AllowAny]
    lookup_field = 'id'

    def update(self, request, *args, **kwargs):
        if not _check_admin(request):
            return Response({'success': False, 'error': 'Forbidden'}, status=403)
        return super().update(request, *args, **kwargs)

    def partial_update(self, request, *args, **kwargs):
        if not _check_admin(request):
            return Response({'success': False, 'error': 'Forbidden'}, status=403)
        kwargs['partial'] = True
        return self.update(request, *args, **kwargs)

    def destroy(self, request, *args, **kwargs):
        if not _check_admin(request):
            return Response({'success': False, 'error': 'Forbidden'}, status=403)
        return super().destroy(request, *args, **kwargs)


@api_view(['POST'])
@permission_classes([permissions.AllowAny])
def reorder_carousel_items(request):
    """POST /api/carousel/reorder/"""
    if not _check_admin(request):
        return Response({'success': False, 'error': 'Forbidden'}, status=403)

    ids = request.data.get('ids', [])
    if not isinstance(ids, list):
        return Response({'success': False, 'error': 'ids must be a list'}, status=400)

    for i, item_id in enumerate(ids):
        CarouselItem.objects.filter(id=item_id).update(order=i)

    return Response({'success': True, 'message': 'Reordered'})


class UserLikedRecipesView(generics.ListAPIView):
    serializer_class = RecipeListSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        user_id = self.kwargs.get('user_id')
        from users.models import User

        try:
            user = User.objects.get(user_id=user_id)
        except User.DoesNotExist:
            return Recipe.objects.none()

        return Recipe.objects.filter(likes=user).order_by('-created_at')


class UserRecipeCommentsView(generics.GenericAPIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request, user_id):
        from users.models import User

        try:
            user = User.objects.get(user_id=user_id)
        except User.DoesNotExist:
            return Response([], status=status.HTTP_200_OK)

        comments = Comment.objects.filter(
            user=user,
            recipe__isnull=False
        ).select_related('recipe').order_by('-created_at')

        data = []
        for c in comments:
            recipe = c.recipe
            cover = recipe.image_url or ''
            if not cover and recipe.photo_urls:
                cover = recipe.photo_urls[0] if recipe.photo_urls else ''

            data.append({
                'id': str(c.id),
                'comment_id': str(c.id),
                'post_id': str(recipe.id),
                'recipe_title': recipe.title,
                'recipe_image': cover,
                'text': c.text,
                'user_name': user.username,
                'photo_urls': c.photo_urls,
                'created_at': c.created_at.isoformat(),
                'likes': 0,
            })

        return Response(data, status=status.HTTP_200_OK)

class HomeworkLikeView(generics.GenericAPIView):
    """Like / unlike a homework (community dish)."""
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, id):
        try:
            homework = Homework.objects.get(id=id)
        except Homework.DoesNotExist:
            return Response({'error': 'Homework not found'}, status=status.HTTP_404_NOT_FOUND)

        if request.user in homework.likes.all():
            homework.likes.remove(request.user)
            liked = False
        else:
            homework.likes.add(request.user)
            liked = True

        return Response({
            'success': True,
            'liked': liked,
            'likes_count': homework.likes.count(),
        })