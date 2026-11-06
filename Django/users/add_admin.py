# users/add_admin.py
from rest_framework.decorators import (
    api_view, permission_classes, parser_classes,
)
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from django.db.models import Q
from django.contrib.auth import get_user_model
from django.utils import timezone
from recipes.models import Recipe, CarouselItem
from ingredients.models import IngredientPost
from users.models import AdminUser, Sticker
from django.core.files.storage import default_storage
import uuid

User = get_user_model()


def _get_admin_from_request(request):
    """
    Return an admin-like object for permission checks.

    Priority:
    1. DRF-authenticated staff user (via TokenAuthentication on mirror User).
    2. Legacy: raw Token value equals AdminUser.admin_id.
    """
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


def _abs(request, url):
    if not url:
        return ''
    try:
        return request.build_absolute_uri(url)
    except Exception:
        return url or ''


def _recipe_to_dict(request, r):
    return {
        'id': str(r.id),
        'title': r.title,
        'description': r.description or '',
        'authorName': r.author.username,
        'authorAvatar': _abs(request, r.author.avatar.url) if r.author.avatar else '',
        'imageUrl': _abs(request, r.image_url),
        'photoUrls': [_abs(request, u) for u in (r.photo_urls or [])],
        'videoUrl': _abs(request, r.video_url),
        'cuisineType': r.cuisine_type or '',
        'difficultyLevel': r.get_difficulty_display() if hasattr(r, 'get_difficulty_display') else '',
        'durationMinutes': r.duration_minutes or 0,
        'likes': r.likes.count() if hasattr(r, 'likes') else 0,
        'comments': r.comments_count if hasattr(r, 'comments_count') else 0,
        'isApproved': r.is_approved,
        'createdAt': r.created_at.isoformat(),
        'tags': [t.name if hasattr(t, 'name') else str(t) for t in (r.tags.all() if hasattr(r, 'tags') else [])],
        'dishes': [d.name if hasattr(d, 'name') else str(d) for d in (r.dishes.all() if hasattr(r, 'dishes') else [])],
        'ingredients': [
            {'name': i.name, 'amount': getattr(i, 'amount', '') or ''}
            for i in (r.ingredients.all() if hasattr(r, 'ingredients') else [])
        ],
        'steps': [
            {'instruction': getattr(s, 'instruction', '') or '',
             'note': getattr(s, 'note', '') or ''}
            for s in (r.steps.all() if hasattr(r, 'steps') else [])
        ],
        'cookingTools': [t.name if hasattr(t, 'name') else str(t) for t in (r.cooking_tools.all() if hasattr(r, 'cooking_tools') else [])],
    }


def _ingredient_to_dict(request, i):
    return {
        'id': str(i.id),
        'title': i.title,
        'description': i.content or '',
        'content': i.content or '',
        'authorName': i.author.username,
        'authorAvatar': _abs(request, i.author.avatar.url) if i.author.avatar else '',
        'imageUrl': _abs(request, i.image_url),
        'photoUrls': [_abs(request, u) for u in (getattr(i, 'photo_urls', None) or [])],
        'videoUrl': _abs(request, getattr(i, 'video_url', None)),
        'likes': i.likes.count() if hasattr(i, 'likes') else 0,
        'comments': i.comments_count if hasattr(i, 'comments_count') else 0,
        'isApproved': i.is_approved,
        'createdAt': i.created_at.isoformat(),
        'tags': (i.tags if isinstance(i.tags, list) else []),
    }


# ==================== Dashboard ====================

@api_view(['GET'])
@permission_classes([AllowAny])
def dashboard_stats(request):
    if not _check_admin(request):
        return Response({'success': False, 'error': 'Forbidden'}, status=403)
    today = timezone.now().date()
    total_users = User.objects.filter(is_active=True).count()
    total_recipes = Recipe.objects.count()
    total_ingredients = IngredientPost.objects.count()
    total_posts = total_recipes + total_ingredients
    new_users_today = User.objects.filter(date_joined__date=today).count()
    new_recipes_today = Recipe.objects.filter(created_at__date=today).count()
    new_posts_today = (
        Recipe.objects.filter(created_at__date=today).count() +
        IngredientPost.objects.filter(created_at__date=today).count()
    )
    return Response({'success': True, 'data': {
        'totalUsers': total_users, 'totalRecipes': total_recipes,
        'totalIngredients': total_ingredients, 'totalPosts': total_posts,
        'newUsersToday': new_users_today, 'newRecipesToday': new_recipes_today,
        'newPostsToday': new_posts_today,
    }})


@api_view(['GET'])
@permission_classes([AllowAny])
def dashboard_pending(request):
    if not _check_admin(request):
        return Response({'success': False, 'error': 'Forbidden'}, status=403)
    pending_recipes = Recipe.objects.filter(is_approved=False).order_by('-created_at')[:50]
    pending_ingredients = IngredientPost.objects.filter(is_approved=False).order_by('-created_at')[:50]
    data = []

    for r in pending_recipes:
        d = _recipe_to_dict(request, r)
        d['type'] = 'recipe'
        data.append(d)

    for i in pending_ingredients:
        d = _ingredient_to_dict(request, i)
        d['type'] = 'ingredient'
        data.append(d)

    data.sort(key=lambda x: x['createdAt'], reverse=True)
    return Response({'success': True, 'data': data})


# ==================== Admins ====================

@api_view(['GET'])
@permission_classes([AllowAny])
def list_admins(request):
    if not _check_admin(request):
        return Response({'success': False, 'error': 'Forbidden'}, status=403)
    admins = AdminUser.objects.all().order_by('-created_at')
    data = []
    for a in admins:
        data.append({
            'id': a.admin_id, 'userId': a.admin_id, 'name': a.name,
            'email': a.email, 'avatar': '',
            'role': 'Super Admin' if a.role == 'super_admin' else 'Moderator',
            'status': 'Active' if a.is_active else 'Inactive',
            'lastLogin': a.last_login.isoformat() if a.last_login else '',
        })
    return Response({'success': True, 'data': data})


@api_view(['POST'])
@permission_classes([AllowAny])
def add_admin(request):
    if not _check_admin(request):
        return Response({'success': False, 'error': 'Forbidden'}, status=403)
    name = request.data.get('name', '').strip()
    email = request.data.get('email', '').strip()
    password = request.data.get('password', '').strip()
    role_raw = request.data.get('role', 'Moderator')
    if not name or not email or not password:
        return Response({'success': False, 'error': 'Name, email, and password are required'}, status=400)
    if AdminUser.objects.filter(email=email).exists():
        return Response({'success': False, 'error': 'Email already exists'}, status=400)
    role = 'super_admin' if role_raw == 'Super Admin' else 'moderator'
    admin = AdminUser(name=name, email=email, role=role)
    admin.set_password(password)
    admin.save()
    return Response({'success': True, 'message': 'Admin created successfully'})


@api_view(['POST'])
@permission_classes([AllowAny])
def remove_admin(request, user_id):
    if not _check_admin(request):
        return Response({'success': False, 'error': 'Forbidden'}, status=403)
    try:
        admin = AdminUser.objects.get(admin_id=user_id)
    except AdminUser.DoesNotExist:
        return Response({'success': False, 'error': 'Admin not found'}, status=404)
    current = _get_admin_from_request(request)
    if current and getattr(current, 'admin_id', None) == admin.admin_id:
        return Response({'success': False, 'error': 'Cannot remove yourself'}, status=400)
    admin.delete()
    return Response({'success': True, 'message': 'Admin removed'})


# ==================== Recipes ====================

@api_view(['GET'])
@permission_classes([AllowAny])
def admin_list_recipes(request):
    if not _check_admin(request):
        return Response({'success': False, 'error': 'Forbidden'}, status=403)
    qs = Recipe.objects.all().order_by('-created_at')
    data = [_recipe_to_dict(request, r) for r in qs]
    return Response({'success': True, 'data': data})


@api_view(['POST'])
@permission_classes([AllowAny])
def admin_approve_recipe(request, recipe_id):
    if not _check_admin(request):
        return Response({'success': False, 'error': 'Forbidden'}, status=403)
    try:
        r = Recipe.objects.get(id=recipe_id)
    except Recipe.DoesNotExist:
        return Response({'success': False, 'error': 'Not found'}, status=404)
    r.is_approved = True
    r.save()
    return Response({'success': True})


@api_view(['DELETE'])
@permission_classes([AllowAny])
def admin_delete_recipe(request, recipe_id):
    if not _check_admin(request):
        return Response({'success': False, 'error': 'Forbidden'}, status=403)
    try:
        r = Recipe.objects.get(id=recipe_id)
    except Recipe.DoesNotExist:
        return Response({'success': False, 'error': 'Not found'}, status=404)
    r.delete()
    return Response({'success': True})


# ==================== Ingredients ====================

@api_view(['GET'])
@permission_classes([AllowAny])
def admin_list_ingredients(request):
    if not _check_admin(request):
        return Response({'success': False, 'error': 'Forbidden'}, status=403)
    qs = IngredientPost.objects.all().order_by('-created_at')
    data = [_ingredient_to_dict(request, i) for i in qs]
    return Response({'success': True, 'data': data})


@api_view(['POST'])
@permission_classes([AllowAny])
def admin_approve_ingredient(request, post_id):
    if not _check_admin(request):
        return Response({'success': False, 'error': 'Forbidden'}, status=403)
    try:
        i = IngredientPost.objects.get(id=post_id)
    except IngredientPost.DoesNotExist:
        return Response({'success': False, 'error': 'Not found'}, status=404)
    i.is_approved = True
    i.save()
    return Response({'success': True})


@api_view(['DELETE'])
@permission_classes([AllowAny])
def admin_delete_ingredient(request, post_id):
    if not _check_admin(request):
        return Response({'success': False, 'error': 'Forbidden'}, status=403)
    try:
        i = IngredientPost.objects.get(id=post_id)
    except IngredientPost.DoesNotExist:
        return Response({'success': False, 'error': 'Not found'}, status=404)
    i.delete()
    return Response({'success': True})


# ==================== Users ====================

@api_view(['GET'])
@permission_classes([AllowAny])
def admin_list_users(request):
    if not _check_admin(request):
        return Response({'success': False, 'error': 'Forbidden'}, status=403)
    qs = User.objects.filter(is_active=True, is_staff=False).order_by('-date_joined')
    data = []
    for u in qs:
        data.append({
            'id': str(u.id), 'userId': u.user_id, 'username': u.username,
            'email': u.email, 'avatar': _abs(request, u.avatar.url) if u.avatar else '',
            'bio': u.bio, 'level': u.level, 'points': u.points,
            'isOfficial': u.is_official,
            'isMentor': u.is_mentor, 'isExpert': u.is_expert,
            'isCulinaryInstructor': u.is_culinary_instructor,
            'recipeCount': u.recipe_count, 'ingredientCount': u.ingredient_count,
            'followersCount': u.followers.count(),
            'followingCount': u.following.count(),
            'dateJoined': u.date_joined.isoformat(),
        })
    return Response({'success': True, 'data': data})


@api_view(['DELETE'])
@permission_classes([AllowAny])
def admin_delete_user(request, user_id):
    if not _check_admin(request):
        return Response({'success': False, 'error': 'Forbidden'}, status=403)
    try:
        u = User.objects.get(user_id=user_id)
    except User.DoesNotExist:
        return Response({'success': False, 'error': 'Not found'}, status=404)
    u.is_active = False
    u.save()
    return Response({'success': True})


# ==================== Reject Post ====================

REJECT_REASON_LABELS = {
    'violation': 'Violation (Violence / Sexual / Prohibited Content)',
    'unrelated': 'Unrelated to Cooking',
    'wrong_category': 'Wrong Category',
    'other': 'Other',
}


@api_view(['POST'])
@permission_classes([AllowAny])
def reject_post(request):
    from users.models import SystemNotification
    from users.models import UserPost, UserLike, UserComment, PointTransaction

    if not _check_admin(request):
        return Response({'success': False, 'error': 'Forbidden'}, status=403)

    post_type = request.data.get('post_type', '').strip()
    post_id = request.data.get('post_id', '').strip()
    reason = request.data.get('reason', '').strip()
    note = request.data.get('note', '').strip()

    if post_type not in ('recipe', 'ingredient'):
        return Response({'success': False, 'error': 'Invalid post_type'}, status=400)
    if not post_id:
        return Response({'success': False, 'error': 'post_id required'}, status=400)
    if reason not in REJECT_REASON_LABELS:
        return Response({'success': False, 'error': 'Invalid reason'}, status=400)

    if post_type == 'recipe':
        try:
            post = Recipe.objects.get(id=post_id)
        except Recipe.DoesNotExist:
            return Response({'success': False, 'error': 'Recipe not found'}, status=404)
        author = post.author
        post_title = post.title
    else:
        try:
            post = IngredientPost.objects.get(id=post_id)
        except IngredientPost.DoesNotExist:
            return Response({'success': False, 'error': 'Ingredient post not found'}, status=404)
        author = post.author
        post_title = post.title

    reason_label = REJECT_REASON_LABELS[reason]

    post.delete()

    try:
        if post_type == 'recipe':
            UserPost.objects.filter(post_type='recipe', post_id=post_id).delete()
            UserLike.objects.filter(like_type='recipe', post_id=post_id).delete()
            UserComment.objects.filter(comment_type='recipe', post_id=post_id).delete()
            if author.recipe_count > 0:
                author.recipe_count -= 1
        else:
            UserPost.objects.filter(post_type='ingredient', post_id=post_id).delete()
            UserLike.objects.filter(like_type='ingredient', post_id=post_id).delete()
            UserComment.objects.filter(comment_type='ingredient', post_id=post_id).delete()
            if author.ingredient_count > 0:
                author.ingredient_count -= 1
    except Exception as e:
        print(f"Sync delete error: {e}")

    try:
        author.remove_points(
            points=1,
            reason=PointTransaction.Reason.POST_REJECTED,
            note=f'Post rejected: {reason_label}. {note}'.strip(),
        )
    except Exception as e:
        print(f"Remove points error: {e}")
        author.save()

    notification_content = (
        f'Your {post_type} "{post_title}" has been removed.\n'
        f'Reason: {reason_label}\n'
    )
    if note:
        notification_content += f'Additional note: {note}\n'

    SystemNotification.objects.create(
        user=author,
        title=f'Your {post_type} has been removed',
        content=notification_content,
        notification_type='post_rejected',
        reject_reason=reason,
        post_type=post_type,
        post_id=post_id,
    )

    if reason == 'violation':
        author.is_active = False
        author.save()
        SystemNotification.objects.create(
            user=author,
            title='Your account has been suspended',
            content=(
                'Your account has been permanently suspended due to a violation '
                'of our community guidelines (violent, sexual, or prohibited content).\n'
                'If you believe this is a mistake, please contact support.'
            ),
            notification_type='account_suspended',
        )

    return Response({
        'success': True,
        'message': 'Post rejected',
        'reason': reason,
        'account_suspended': reason == 'violation',
    })


# ==================== Sticker Admin ====================

@api_view(['GET'])
@permission_classes([AllowAny])
def admin_list_stickers(request):
    if not _check_admin(request):
        return Response({'success': False, 'error': 'Forbidden'}, status=403)
    qs = Sticker.objects.all().order_by('-created_at')
    data = []
    for s in qs:
        image_url = ''
        if s.image:
            image_url = request.build_absolute_uri(s.image.url)
        elif s.image_url:
            image_url = s.image_url
        data.append({
            'id': s.id,
            'name': s.name,
            'imageUrl': image_url,
            'isActive': s.is_active,
            'createdAt': s.created_at.isoformat(),
        })
    return Response({'success': True, 'data': data})


@api_view(['POST'])
@permission_classes([AllowAny])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def admin_add_sticker(request):
    if not _check_admin(request):
        return Response({'success': False, 'error': 'Forbidden'}, status=403)
    name = request.data.get('name', '').strip()
    if not name:
        return Response({'success': False, 'error': 'Name is required'}, status=400)
    image_file = request.FILES.get('image')
    image_url = request.data.get('image_url', '').strip()
    if not image_file and not image_url:
        return Response({'success': False, 'error': 'Image or image_url required'}, status=400)

    sticker = Sticker(name=name)
    if image_file:
        sticker.image = image_file
    if image_url:
        sticker.image_url = image_url
    sticker.save()
    return Response({'success': True, 'id': sticker.id})


@api_view(['POST'])
@permission_classes([AllowAny])
def admin_toggle_sticker(request, sticker_id):
    if not _check_admin(request):
        return Response({'success': False, 'error': 'Forbidden'}, status=403)
    try:
        s = Sticker.objects.get(id=sticker_id)
    except Sticker.DoesNotExist:
        return Response({'success': False, 'error': 'Not found'}, status=404)
    s.is_active = not s.is_active
    s.save(update_fields=['is_active'])
    return Response({'success': True, 'is_active': s.is_active})


@api_view(['DELETE'])
@permission_classes([AllowAny])
def admin_delete_sticker(request, sticker_id):
    if not _check_admin(request):
        return Response({'success': False, 'error': 'Forbidden'}, status=403)
    try:
        s = Sticker.objects.get(id=sticker_id)
    except Sticker.DoesNotExist:
        return Response({'success': False, 'error': 'Not found'}, status=404)
    if s.image:
        try:
            s.image.delete(save=False)
        except Exception:
            pass
    s.delete()
    return Response({'success': True})