# recipes/serializers.py
from rest_framework import serializers
from .models import (
    Recipe, Tag, CookingTool, Ingredient,
    Step, Comment, Homework, CarouselItem
)
from django.contrib.auth import get_user_model

User = get_user_model()


# ==================== Helper ====================
def _absolute_url(request, url_or_field):
    if not url_or_field:
        return ''
    try:
        if hasattr(url_or_field, 'url'):
            url = url_or_field.url
        else:
            url = str(url_or_field)
    except Exception:
        return ''
    if not url:
        return ''
    if url.startswith('http://') or url.startswith('https://'):
        return url
    if not url.startswith('/'):
        url = '/' + url
    if request:
        return request.build_absolute_uri(url)
    return url


# ==================== Basic Serializers ====================
class TagSerializer(serializers.ModelSerializer):
    class Meta:
        model = Tag
        fields = ['name']


class CookingToolSerializer(serializers.ModelSerializer):
    class Meta:
        model = CookingTool
        fields = ['name']


class IngredientSerializer(serializers.ModelSerializer):
    class Meta:
        model = Ingredient
        fields = ['name', 'amount']


class StepSerializer(serializers.ModelSerializer):
    class Meta:
        model = Step
        fields = ['step_number', 'instruction', 'note']


# ==================== Comment ====================
class CommentSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.username', read_only=True)
    user_id = serializers.CharField(source='user.user_id', read_only=True)
    user_avatar = serializers.SerializerMethodField()
    likes = serializers.SerializerMethodField()
    photo_urls = serializers.JSONField(required=False, default=list)

    class Meta:
        model = Comment
        fields = ['id', 'user', 'user_id', 'user_name', 'user_avatar', 'text', 'photo_urls', 'created_at', 'likes']
        read_only_fields = ['id', 'user', 'created_at']

    def get_user_avatar(self, obj):
        request = self.context.get('request')
        return _absolute_url(request, obj.user.avatar) if obj.user else ''

    def get_likes(self, obj):
        return 0


class CommentCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Comment
        fields = ['text', 'photo_urls']

    def create(self, validated_data):
        request = self.context.get('request')
        recipe = self.context.get('recipe')
        return Comment.objects.create(
            user=request.user,
            recipe=recipe,
            text=validated_data.get('text', ''),
            photo_urls=validated_data.get('photo_urls', [])
        )


# ==================== Homework (Dishes) ====================
class HomeworkSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.username', read_only=True)
    user_id = serializers.CharField(source='user.user_id', read_only=True)
    user_avatar = serializers.SerializerMethodField()
    image_url = serializers.SerializerMethodField()
    recipe_title = serializers.CharField(source='recipe.title', read_only=True)
    recipe_id = serializers.CharField(source='recipe.id', read_only=True)
    likes_count = serializers.SerializerMethodField()
    is_liked = serializers.SerializerMethodField()
    recommendation = serializers.SerializerMethodField()

    class Meta:
        model = Homework
        fields = [
            'id', 'user', 'user_id', 'user_name', 'user_avatar',
            'recipe', 'recipe_id', 'recipe_title',
            'image', 'image_url', 'review', 'rating', 'created_at',
            'likes_count', 'is_liked', 'recommendation',
        ]
        read_only_fields = ['id', 'user', 'created_at']

    def get_user_avatar(self, obj):
        request = self.context.get('request')
        return _absolute_url(request, obj.user.avatar) if obj.user else ''

    def get_image_url(self, obj):
        request = self.context.get('request')
        return _absolute_url(request, obj.image)

    def get_likes_count(self, obj):
        return obj.likes.count()

    def get_is_liked(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.likes.filter(id=request.user.id).exists()
        return False

    def get_recommendation(self, obj):
        return obj.get_recommendation_label()


class HomeworkCreateSerializer(serializers.ModelSerializer):
    image_url = serializers.CharField(write_only=True, required=False)

    class Meta:
        model = Homework
        fields = ['image', 'image_url', 'review', 'rating']
        extra_kwargs = {
            'image': {'required': False},
            'review': {'required': False},
            'rating': {'required': False},
        }

    def create(self, validated_data):
        import base64
        import uuid
        from django.core.files.base import ContentFile

        request = self.context.get('request')
        recipe = self.context.get('recipe')

        image_url = validated_data.pop('image_url', None)
        image = validated_data.get('image')

        if image_url and not image:
            if ';base64,' in image_url:
                fmt, imgstr = image_url.split(';base64,')
                ext = fmt.split('/')[-1] or 'jpg'
                filename = f"{uuid.uuid4().hex}.{ext}"
                image = ContentFile(base64.b64decode(imgstr), name=filename)

        return Homework.objects.create(
            user=request.user,
            recipe=recipe,
            review=validated_data.get('review', ''),
            rating=validated_data.get('rating', 'good'),
            image=image
        )


class HomeworkUpdateSerializer(serializers.ModelSerializer):
    image_url = serializers.CharField(write_only=True, required=False)

    class Meta:
        model = Homework
        fields = ['image', 'image_url', 'review', 'rating']
        extra_kwargs = {
            'image': {'required': False},
            'review': {'required': False},
            'rating': {'required': False},
        }

    def update(self, instance, validated_data):
        import base64
        import uuid
        from django.core.files.base import ContentFile

        image_url = validated_data.pop('image_url', None)

        if image_url:
            if ';base64,' in image_url:
                fmt, imgstr = image_url.split(';base64,')
                ext = fmt.split('/')[-1] or 'jpg'
                filename = f"{uuid.uuid4().hex}.{ext}"
                instance.image = ContentFile(base64.b64decode(imgstr), name=filename)

        if 'review' in validated_data:
            instance.review = validated_data['review']
        if 'rating' in validated_data:
            instance.rating = validated_data['rating']
        if 'image' in validated_data:
            instance.image = validated_data['image']

        instance.save()
        return instance


# ==================== Recipe ====================
class RecipeListSerializer(serializers.ModelSerializer):
    tags = serializers.SerializerMethodField()
    author_name = serializers.CharField(source='author.username', read_only=True)
    author_avatar = serializers.SerializerMethodField()
    likes_count = serializers.SerializerMethodField()
    is_liked = serializers.SerializerMethodField()
    recommendation = serializers.SerializerMethodField()

    class Meta:
        model = Recipe
        fields = [
            'id', 'title', 'description', 'image_url', 'author_name',
            'author_avatar', 'likes_count', 'is_liked', 'comments_count', 'dishes_count',
            'cuisine_type', 'duration_minutes', 'difficulty_level',
            'tags', 'is_approved', 'created_at', 'recommendation'
        ]

    def get_tags(self, obj):
        return [tag.name for tag in obj.tags.all()]

    def get_author_avatar(self, obj):
        request = self.context.get('request')
        return _absolute_url(request, obj.author.avatar) if obj.author else ''

    def get_likes_count(self, obj):
        return obj.likes.count()

    def get_is_liked(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.likes.filter(id=request.user.id).exists()
        return False

    def get_recommendation(self, obj):
        return obj.get_recommendation_label()


class RecipeDetailSerializer(serializers.ModelSerializer):
    tags = TagSerializer(many=True, read_only=True)
    cooking_tools = CookingToolSerializer(many=True, read_only=True)
    ingredients = IngredientSerializer(many=True, read_only=True)
    steps = StepSerializer(many=True, read_only=True)
    comments = CommentSerializer(many=True, read_only=True)
    homeworks = HomeworkSerializer(many=True, read_only=True)
    recommendation = serializers.SerializerMethodField()
    author_id = serializers.CharField(source='author.id', read_only=True)
    author_user_id = serializers.CharField(source='author.user_id', read_only=True)   # 🔥 新增
    author_name = serializers.CharField(source='author.username', read_only=True)
    author_avatar = serializers.SerializerMethodField()
    likes_count = serializers.SerializerMethodField()
    is_liked = serializers.SerializerMethodField()
    formatted_duration = serializers.CharField(read_only=True)
    difficulty_text = serializers.CharField(read_only=True)

    class Meta:
        model = Recipe
        fields = [
            'id', 'title', 'description', 'image_url', 'photo_urls',
            'video_url', 'video_cover_url',
            'author_id', 'author_user_id', 'author_name',
            'author_avatar', 'likes_count', 'is_liked', 'comments_count', 'dishes_count',
            'cuisine_type', 'duration_minutes', 'formatted_duration',
            'difficulty_level', 'difficulty_text', 'tags', 'is_approved', 'cooking_tools',
            'ingredients', 'steps', 'comments', 'homeworks',
            'created_at', 'updated_at', 'edited_at', 'recommendation'
        ]

    def get_author_avatar(self, obj):
        request = self.context.get('request')
        return _absolute_url(request, obj.author.avatar) if obj.author else ''

    def get_likes_count(self, obj):
        return obj.likes.count()

    def get_is_liked(self, obj):
        request = self.context.get('request')
        if request and request.user.is_authenticated:
            return obj.likes.filter(id=request.user.id).exists()
        return False

    def get_recommendation(self, obj):
        return obj.get_recommendation_label()


class RecipeCreateSerializer(serializers.ModelSerializer):
    tags = serializers.ListField(child=serializers.CharField(), write_only=True, required=False)
    cooking_tools = serializers.ListField(child=serializers.CharField(), write_only=True, required=False)
    ingredients = serializers.ListField(child=serializers.DictField(), write_only=True, required=False)
    steps = serializers.ListField(child=serializers.DictField(), write_only=True)

    class Meta:
        model = Recipe
        fields = [
            'title', 'description', 'cuisine_type', 'duration_minutes',
            'difficulty_level', 'tags', 'cooking_tools', 'ingredients', 'steps',
            'photo_urls', 'video_url', 'video_cover_url', 'image_url'
        ]
        extra_kwargs = {
            'photo_urls': {'required': False},
            'video_url': {'required': False, 'allow_null': True},
            'video_cover_url': {'required': False, 'allow_null': True},
            'image_url': {'required': False, 'allow_null': True},
        }

    def create(self, validated_data):
        tags_data = validated_data.pop('tags', [])
        tools_data = validated_data.pop('cooking_tools', [])
        ingredients_data = validated_data.pop('ingredients', [])
        steps_data = validated_data.pop('steps', [])

        request = self.context.get('request')
        author = request.user if request else None

        recipe = Recipe.objects.create(author=author, **validated_data)

        for tag_name in tags_data:
            if tag_name and tag_name.strip():
                Tag.objects.create(recipe=recipe, name=tag_name.strip())

        for tool_name in tools_data:
            if tool_name and tool_name.strip():
                CookingTool.objects.create(recipe=recipe, name=tool_name.strip())

        for ing_data in ingredients_data:
            Ingredient.objects.create(
                recipe=recipe,
                name=ing_data.get('name', ''),
                amount=ing_data.get('amount', '')
            )

        for idx, step_data in enumerate(steps_data, start=1):
            Step.objects.create(
                recipe=recipe,
                step_number=idx,
                instruction=step_data.get('instruction', ''),
                note=step_data.get('note', None)
            )

        return recipe


class RecipeUpdateSerializer(serializers.ModelSerializer):
    tags = serializers.ListField(child=serializers.CharField(), write_only=True, required=False)
    cooking_tools = serializers.ListField(child=serializers.CharField(), write_only=True, required=False)
    ingredients = serializers.ListField(child=serializers.DictField(), write_only=True, required=False)
    steps = serializers.ListField(child=serializers.DictField(), write_only=True, required=False)

    class Meta:
        model = Recipe
        fields = [
            'title', 'description', 'cuisine_type', 'duration_minutes',
            'difficulty_level', 'tags', 'cooking_tools', 'ingredients', 'steps',
            'photo_urls', 'video_url', 'video_cover_url', 'image_url'
        ]
        extra_kwargs = {
            'photo_urls': {'required': False},
            'video_url': {'required': False, 'allow_null': True},
            'video_cover_url': {'required': False, 'allow_null': True},
            'image_url': {'required': False, 'allow_null': True},
        }

    def update(self, instance, validated_data):
        tags_data = validated_data.pop('tags', None)
        tools_data = validated_data.pop('cooking_tools', None)
        ingredients_data = validated_data.pop('ingredients', None)
        steps_data = validated_data.pop('steps', None)

        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        instance.save()

        if tags_data is not None:
            instance.tags.all().delete()
            for tag_name in tags_data:
                if tag_name and tag_name.strip():
                    Tag.objects.create(recipe=instance, name=tag_name.strip())

        if tools_data is not None:
            instance.cooking_tools.all().delete()
            for tool_name in tools_data:
                if tool_name and tool_name.strip():
                    CookingTool.objects.create(recipe=instance, name=tool_name.strip())

        if ingredients_data is not None:
            instance.ingredients.all().delete()
            for ing_data in ingredients_data:
                Ingredient.objects.create(
                    recipe=instance,
                    name=ing_data.get('name', ''),
                    amount=ing_data.get('amount', '')
                )

        if steps_data is not None:
            instance.steps.all().delete()
            for idx, step_data in enumerate(steps_data, start=1):
                Step.objects.create(
                    recipe=instance,
                    step_number=idx,
                    instruction=step_data.get('instruction', ''),
                    note=step_data.get('note', None) or None
                )

        return instance


# ==================== Carousel ====================
class CarouselItemSerializer(serializers.ModelSerializer):
    keywords = serializers.SerializerMethodField()
    image_url_display = serializers.SerializerMethodField()

    class Meta:
        model = CarouselItem
        fields = [
            'id', 'title', 'tags', 'image', 'image_url',
            'image_url_display', 'keywords', 'order', 'is_active',
            'created_at', 'updated_at', 'edited_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def get_keywords(self, obj):
        return obj.get_keywords()

    def get_image_url_display(self, obj):
        request = self.context.get('request')
        if obj.image:
            return _absolute_url(request, obj.image)
        return obj.image_url or ''