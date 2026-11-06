# users/serializers.py
from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import (
    User, UserFollow, UserPost, UserLike, UserComment,
    PointTransaction, MentorshipRequest,
)

User = get_user_model()


def _absolute_url(request, url_or_field):
    if not url_or_field:
        return None
    try:
        if hasattr(url_or_field, 'url'):
            url = url_or_field.url
        else:
            url = str(url_or_field)
    except Exception:
        return None

    if not url:
        return None
    if url.startswith('http://') or url.startswith('https://'):
        return url
    if not url.startswith('/'):
        url = '/' + url
    if request:
        return request.build_absolute_uri(url)
    return url


# ============ User Serializer ============
class UserSerializer(serializers.ModelSerializer):
    followers_count = serializers.SerializerMethodField()
    following_count = serializers.SerializerMethodField()
    role_info = serializers.SerializerMethodField()
    avatar = serializers.SerializerMethodField()
    is_mentor_of_current = serializers.SerializerMethodField()
    has_pending_request = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = (
            'id', 'user_id', 'username', 'email', 'avatar', 'bio', 'level', 'points',
            'is_official', 'is_mentor', 'is_expert', 'is_culinary_instructor',
            'role_info',
            'recipe_count', 'ingredient_count', 'dish_count', 'total_posts',
            'recipe_likes_received', 'ingredient_likes_received', 'dish_likes_received', 'total_likes_received',
            'recipe_likes_given', 'ingredient_likes_given', 'dish_likes_given', 'total_likes_given',
            'recipe_comments', 'ingredient_comments', 'dish_comments', 'total_comments',
            'followers_count', 'following_count',
            'is_mentor_of_current', 'has_pending_request',
        )
        read_only_fields = (
            'user_id', 'level', 'points',
            'is_official', 'is_mentor', 'is_expert', 'is_culinary_instructor',
            'recipe_count', 'ingredient_count', 'dish_count', 'total_posts',
            'recipe_likes_received', 'ingredient_likes_received', 'dish_likes_received', 'total_likes_received',
            'recipe_likes_given', 'ingredient_likes_given', 'dish_likes_given', 'total_likes_given',
            'recipe_comments', 'ingredient_comments', 'dish_comments', 'total_comments'
        )

    def get_avatar(self, obj):
        request = self.context.get('request')
        return _absolute_url(request, obj.avatar) or ''

    def get_followers_count(self, obj):
        return UserFollow.objects.filter(user=obj).count()

    def get_following_count(self, obj):
        return UserFollow.objects.filter(follower=obj).count()

    def get_role_info(self, obj):
        return obj.get_role_display_info()

    def get_is_mentor_of_current(self, obj):
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return False
        return MentorshipRequest.objects.filter(
            mentee=request.user, mentor=obj, status=MentorshipRequest.Status.ACCEPTED,
        ).exists()

    def get_has_pending_request(self, obj):
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return False
        return MentorshipRequest.objects.filter(
            mentee=request.user, mentor=obj, status=MentorshipRequest.Status.PENDING,
        ).exists()


# ============ Register / Login / Password ============
class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, required=True, min_length=4)
    confirm_password = serializers.CharField(write_only=True, required=True)
    email = serializers.EmailField(required=True)

    class Meta:
        model = User
        fields = ('username', 'email', 'password', 'confirm_password')

    def validate(self, attrs):
        if attrs['password'] != attrs['confirm_password']:
            raise serializers.ValidationError({"confirm_password": "Passwords don't match."})
        if User.objects.filter(email=attrs['email']).exists():
            raise serializers.ValidationError({"email": "Email already exists."})
        if User.objects.filter(username=attrs['username']).exists():
            raise serializers.ValidationError({"username": "Username already exists."})
        return attrs

    def create(self, validated_data):
        validated_data.pop('confirm_password')
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password']
        )
        return user


class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField(required=True)
    password = serializers.CharField(required=True, write_only=True)


class ChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(required=True)
    new_password = serializers.CharField(required=True, min_length=4)
    confirm_password = serializers.CharField(required=True)

    def validate(self, attrs):
        if attrs['new_password'] != attrs['confirm_password']:
            raise serializers.ValidationError({"confirm_password": "Passwords don't match."})
        return attrs


# ============ Follow ============
class FollowSerializer(serializers.ModelSerializer):
    follower_username = serializers.CharField(source='follower.username', read_only=True)
    follower_user_id = serializers.CharField(source='follower.user_id', read_only=True)
    follower_avatar = serializers.SerializerMethodField()
    follower_level = serializers.IntegerField(source='follower.level', read_only=True)
    follower_bio = serializers.CharField(source='follower.bio', read_only=True)
    follower_is_mentor = serializers.BooleanField(source='follower.is_mentor', read_only=True)

    user_username = serializers.CharField(source='user.username', read_only=True)
    user_user_id = serializers.CharField(source='user.user_id', read_only=True)
    user_avatar = serializers.SerializerMethodField()
    user_level = serializers.IntegerField(source='user.level', read_only=True)
    user_bio = serializers.CharField(source='user.bio', read_only=True)
    user_is_mentor = serializers.BooleanField(source='user.is_mentor', read_only=True)

    class Meta:
        model = UserFollow
        fields = (
            'id', 'user', 'follower',
            'follower_username', 'follower_user_id', 'follower_avatar',
            'follower_level', 'follower_bio', 'follower_is_mentor',
            'user_username', 'user_user_id', 'user_avatar',
            'user_level', 'user_bio', 'user_is_mentor',
            'created_at',
        )

    def get_follower_avatar(self, obj):
        request = self.context.get('request')
        return _absolute_url(request, obj.follower.avatar) or ''

    def get_user_avatar(self, obj):
        request = self.context.get('request')
        return _absolute_url(request, obj.user.avatar) or ''


# ============ UserPost / UserLike / UserComment ============
class UserPostSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    user_id = serializers.CharField(source='user.user_id', read_only=True)
    role_info = serializers.SerializerMethodField()
    title = serializers.SerializerMethodField()
    image = serializers.SerializerMethodField()
    author = serializers.SerializerMethodField()

    class Meta:
        model = UserPost
        fields = ('id', 'post_type', 'post_id', 'username', 'user_id', 'role_info', 'title', 'image', 'author', 'created_at')

    def get_role_info(self, obj):
        return obj.user.get_role_display_info()

    def get_title(self, obj):
        try:
            if obj.post_type == 'recipe':
                from recipes.models import Recipe
                return Recipe.objects.get(id=obj.post_id).title
            elif obj.post_type == 'ingredient':
                from ingredients.models import IngredientPost
                return IngredientPost.objects.get(id=obj.post_id).title
            else:
                from dishes.models import Dish
                return Dish.objects.get(id=obj.post_id).title
        except Exception:
            return 'Deleted Content'

    def get_image(self, obj):
        request = self.context.get('request')
        try:
            if obj.post_type == 'recipe':
                from recipes.models import Recipe
                r = Recipe.objects.get(id=obj.post_id)
                return _absolute_url(request, r.image)
            elif obj.post_type == 'ingredient':
                from ingredients.models import IngredientPost
                i = IngredientPost.objects.get(id=obj.post_id)
                return _absolute_url(request, i.image)
            else:
                from dishes.models import Dish
                d = Dish.objects.get(id=obj.post_id)
                return _absolute_url(request, d.image)
        except Exception:
            return None

    def get_author(self, obj):
        try:
            if obj.post_type == 'recipe':
                from recipes.models import Recipe
                return Recipe.objects.get(id=obj.post_id).author.username
            elif obj.post_type == 'ingredient':
                from ingredients.models import IngredientPost
                return IngredientPost.objects.get(id=obj.post_id).author.username
            else:
                from dishes.models import Dish
                return Dish.objects.get(id=obj.post_id).author.username
        except Exception:
            return None


class UserLikeSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    user_id = serializers.CharField(source='user.user_id', read_only=True)
    role_info = serializers.SerializerMethodField()
    title = serializers.SerializerMethodField()
    image = serializers.SerializerMethodField()
    author = serializers.SerializerMethodField()

    class Meta:
        model = UserLike
        fields = ('id', 'like_type', 'post_id', 'username', 'user_id', 'role_info', 'title', 'image', 'author', 'created_at')

    def get_role_info(self, obj):
        return obj.user.get_role_display_info()

    def get_title(self, obj):
        try:
            if obj.like_type == 'recipe':
                from recipes.models import Recipe
                return Recipe.objects.get(id=obj.post_id).title
            elif obj.like_type == 'ingredient':
                from ingredients.models import IngredientPost
                return IngredientPost.objects.get(id=obj.post_id).title
            else:
                from dishes.models import Dish
                return Dish.objects.get(id=obj.post_id).title
        except Exception:
            return 'Deleted Content'

    def get_image(self, obj):
        request = self.context.get('request')
        try:
            if obj.like_type == 'recipe':
                from recipes.models import Recipe
                r = Recipe.objects.get(id=obj.post_id)
                return _absolute_url(request, r.image)
            elif obj.like_type == 'ingredient':
                from ingredients.models import IngredientPost
                i = IngredientPost.objects.get(id=obj.post_id)
                return _absolute_url(request, i.image)
            else:
                from dishes.models import Dish
                d = Dish.objects.get(id=obj.post_id)
                return _absolute_url(request, d.image)
        except Exception:
            return None

    def get_author(self, obj):
        try:
            if obj.like_type == 'recipe':
                from recipes.models import Recipe
                return Recipe.objects.get(id=obj.post_id).author.username
            elif obj.like_type == 'ingredient':
                from ingredients.models import IngredientPost
                return IngredientPost.objects.get(id=obj.post_id).author.username
            else:
                from dishes.models import Dish
                return Dish.objects.get(id=obj.post_id).author.username
        except Exception:
            return None


class UserCommentSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    user_id = serializers.CharField(source='user.user_id', read_only=True)
    role_info = serializers.SerializerMethodField()
    title = serializers.SerializerMethodField()
    image = serializers.SerializerMethodField()
    post_author = serializers.SerializerMethodField()

    class Meta:
        model = UserComment
        fields = ('id', 'comment_type', 'post_id', 'comment_id', 'content',
                  'username', 'user_id', 'role_info', 'title', 'image', 'post_author', 'created_at')

    def get_role_info(self, obj):
        return obj.user.get_role_display_info()

    def get_title(self, obj):
        try:
            if obj.comment_type == 'recipe':
                from recipes.models import Recipe
                return Recipe.objects.get(id=obj.post_id).title
            elif obj.comment_type == 'ingredient':
                from ingredients.models import IngredientPost
                return IngredientPost.objects.get(id=obj.post_id).title
            else:
                from dishes.models import Dish
                return Dish.objects.get(id=obj.post_id).title
        except Exception:
            return 'Deleted Content'

    def get_image(self, obj):
        request = self.context.get('request')
        try:
            if obj.comment_type == 'recipe':
                from recipes.models import Recipe
                r = Recipe.objects.get(id=obj.post_id)
                return _absolute_url(request, r.image)
            elif obj.comment_type == 'ingredient':
                from ingredients.models import IngredientPost
                i = IngredientPost.objects.get(id=obj.post_id)
                return _absolute_url(request, i.image)
            else:
                from dishes.models import Dish
                d = Dish.objects.get(id=obj.post_id)
                return _absolute_url(request, d.image)
        except Exception:
            return None

    def get_post_author(self, obj):
        try:
            if obj.comment_type == 'recipe':
                from recipes.models import Recipe
                return Recipe.objects.get(id=obj.post_id).author.username
            elif obj.comment_type == 'ingredient':
                from ingredients.models import IngredientPost
                return IngredientPost.objects.get(id=obj.post_id).author.username
            else:
                from dishes.models import Dish
                return Dish.objects.get(id=obj.post_id).author.username
        except Exception:
            return None


# ============ PointTransaction / Notification / Sticker ============
class PointTransactionSerializer(serializers.ModelSerializer):
    reason_display = serializers.SerializerMethodField()

    class Meta:
        model = PointTransaction
        fields = ('id', 'points', 'reason', 'reason_display', 'related_type', 'related_id', 'created_at', 'note')

    def get_reason_display(self, obj):
        from .point_rules import PointRules
        return PointRules.get_reason_display(obj.reason)


class SystemNotificationSerializer(serializers.ModelSerializer):
    created_at_str = serializers.SerializerMethodField()

    class Meta:
        from .models import SystemNotification
        model = SystemNotification
        fields = (
            'id', 'title', 'content', 'notification_type',
            'reject_reason', 'post_type', 'post_id',
            'is_read', 'created_at', 'created_at_str',
        )

    def get_created_at_str(self, obj):
        return obj.created_at.isoformat()


class StickerSerializer(serializers.ModelSerializer):
    image = serializers.SerializerMethodField()

    class Meta:
        from .models import Sticker
        model = Sticker
        fields = ('id', 'name', 'image', 'is_active', 'created_at')

    def get_image(self, obj):
        request = self.context.get('request')
        return _absolute_url(request, obj.image) or obj.image_url or ''