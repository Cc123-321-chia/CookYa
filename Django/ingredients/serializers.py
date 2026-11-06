# ingredients/serializers.py
from rest_framework import serializers
from .models import IngredientPost, IngredientComment


class IngredientCommentSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.username', read_only=True)
    user_id = serializers.CharField(source='user.user_id', read_only=True)
    user_avatar = serializers.SerializerMethodField()

    class Meta:
        model = IngredientComment
        fields = ['id', 'user', 'user_id', 'user_name', 'user_avatar',
                  'text', 'image', 'created_at']
        read_only_fields = ['id', 'user', 'created_at']

    def get_user_avatar(self, obj):
        if obj.user.avatar and hasattr(obj.user.avatar, 'url'):
            return obj.user.avatar.url
        return None


class IngredientPostSerializer(serializers.ModelSerializer):
    author_name = serializers.CharField(source='author.username', read_only=True)
    author_id = serializers.CharField(source='author.id', read_only=True)
    author_user_id = serializers.CharField(source='author.user_id', read_only=True)
    author_avatar = serializers.SerializerMethodField()
    likes_count = serializers.IntegerField(read_only=True)
    comments_count = serializers.IntegerField(read_only=True)
    is_liked = serializers.SerializerMethodField()
    recommendation = serializers.SerializerMethodField()

    class Meta:
        model = IngredientPost
        fields = [
            'id', 'title', 'content', 'image_url', 'photo_urls',
            'video_url', 'video_cover_url',
            'author', 'author_id', 'author_user_id', 'author_name',
            'author_avatar', 'likes_count', 'is_liked', 'comments_count',
            'tags', 'is_approved', 'created_at', 'updated_at', 'edited_at',
            'recommendation',
        ]
        read_only_fields = ['id', 'author', 'created_at']

    def get_author_avatar(self, obj):
        if obj.author.avatar and hasattr(obj.author.avatar, 'url'):
            return obj.author.avatar.url
        return None

    def get_is_liked(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.likes.filter(id=request.user.id).exists()
        return False

    def get_recommendation(self, obj):
        likers = obj.likes.all()
        if any(u.is_official for u in likers):
            return 'official'
        if any(u.is_expert for u in likers):
            return 'expert'
        return None


class IngredientPostCreateSerializer(serializers.ModelSerializer):
    tags = serializers.ListField(child=serializers.CharField(), required=False)

    class Meta:
        model = IngredientPost
        fields = ['title', 'content', 'tags', 'photo_urls', 'image_url',
                  'video_url', 'video_cover_url']

    def create(self, validated_data):
        request = self.context.get('request')
        validated_data['author'] = request.user
        return super().create(validated_data)


class IngredientPostUpdateSerializer(serializers.ModelSerializer):
    tags = serializers.ListField(child=serializers.CharField(), required=False)

    class Meta:
        model = IngredientPost
        fields = ['title', 'content', 'tags', 'photo_urls', 'image_url',
                  'video_url', 'video_cover_url']
        extra_kwargs = {
            'photo_urls': {'required': False},
            'video_url': {'required': False, 'allow_null': True},
            'video_cover_url': {'required': False, 'allow_null': True},
            'image_url': {'required': False, 'allow_null': True},
        }

    def update(self, instance, validated_data):
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()
        return instance