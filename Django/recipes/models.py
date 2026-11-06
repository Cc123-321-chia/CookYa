# recipes/models.py
from django.db import models
from django.conf import settings
import uuid

User = settings.AUTH_USER_MODEL


class Recipe(models.Model):
    DIFFICULTY_CHOICES = [
        (1, 'Very Easy'),
        (2, 'Easy'),
        (3, 'Medium'),
        (4, 'Hard'),
        (5, 'Very Hard'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    title = models.CharField(max_length=200)
    description = models.TextField()
    image_url = models.CharField(max_length=500, blank=True, null=True)
    author = models.ForeignKey(User, on_delete=models.CASCADE, related_name='recipes')
    likes = models.ManyToManyField(User, related_name='liked_recipes', blank=True)
    comments_count = models.IntegerField(default=0)
    dishes_count = models.IntegerField(default=0)
    is_approved = models.BooleanField(default=False)

    cuisine_type = models.CharField(max_length=100, blank=True, default='')
    duration_minutes = models.IntegerField(default=30)
    difficulty_level = models.IntegerField(choices=DIFFICULTY_CHOICES, default=2)

    photo_urls = models.JSONField(default=list, blank=True)
    video_url = models.CharField(max_length=500, blank=True, null=True)
    video_cover_url = models.CharField(max_length=500, blank=True, null=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    edited_at = models.DateTimeField(null=True, blank=True)

    def like_count(self):
        return self.likes.count()

    @property
    def likes_count(self):
        return self.likes.count()

    @property
    def formatted_duration(self):
        minutes = self.duration_minutes
        if minutes >= 300:
            return '5+ hours'
        if minutes >= 60:
            hours = minutes / 60.0
            return f'{hours:.1f} hours'
        return f'{minutes} min{"s" if minutes != 1 else ""}'

    @property
    def difficulty_text(self):
        return dict(self.DIFFICULTY_CHOICES).get(self.difficulty_level, 'Medium')

    def __str__(self):
        return self.title

    def get_recommendation_label(self):
        """
        Priority:
          1. 'official' -> an Official liked this recipe
          2. 'expert'   -> an Expert liked this recipe
          3. None
        """
        likers = self.likes.all()
        if any(u.is_official for u in likers):
            return 'official'
        if any(u.is_expert for u in likers):
            return 'expert'
        return None


class Tag(models.Model):
    recipe = models.ForeignKey(Recipe, on_delete=models.CASCADE, related_name='tags')
    name = models.CharField(max_length=50)

    class Meta:
        unique_together = ('recipe', 'name')

    def __str__(self):
        return self.name


class CookingTool(models.Model):
    recipe = models.ForeignKey(Recipe, on_delete=models.CASCADE, related_name='cooking_tools')
    name = models.CharField(max_length=100)

    class Meta:
        unique_together = ('recipe', 'name')

    def __str__(self):
        return self.name


class Ingredient(models.Model):
    recipe = models.ForeignKey(Recipe, on_delete=models.CASCADE, related_name='ingredients')
    name = models.CharField(max_length=200)
    amount = models.CharField(max_length=100, blank=True)

    class Meta:
        ordering = ['id']

    def __str__(self):
        return f"{self.name}: {self.amount}" if self.amount else self.name


class Step(models.Model):
    recipe = models.ForeignKey(Recipe, on_delete=models.CASCADE, related_name='steps')
    step_number = models.IntegerField()
    instruction = models.TextField()
    note = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ['step_number']
        unique_together = ('recipe', 'step_number')

    def __str__(self):
        return f"Step {self.step_number}: {self.instruction[:50]}"


class Comment(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    recipe = models.ForeignKey(Recipe, on_delete=models.CASCADE, related_name='comments')
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    text = models.TextField()
    photo_urls = models.JSONField(default=list, blank=True)  # 🔥 添加照片字段
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Comment by {self.user.username}"

class Homework(models.Model):
    RATING_CHOICES = [
        ('bad', 'Bad'),
        ('ok', 'OK'),
        ('good', 'Good'),
    ]

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    recipe = models.ForeignKey(Recipe, on_delete=models.CASCADE, related_name='homeworks')
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    image = models.ImageField(upload_to='homeworks/')
    review = models.TextField(blank=True)
    rating = models.CharField(max_length=10, choices=RATING_CHOICES)
    created_at = models.DateTimeField(auto_now_add=True)

    # NEW: likes
    likes = models.ManyToManyField(User, related_name='liked_homeworks', blank=True)

    def __str__(self):
        return f"Homework by {self.user.username}"

    def like_count(self):
        return self.likes.count()

    def get_recommendation_label(self):
        """
        Priority:
          1. 'chef'     -> the recipe author liked this homework
          2. 'official' -> an Official liked this homework
          3. None
        """
        recipe_author_id = self.recipe.author_id if self.recipe_id else None
        likers = self.likes.all()
        if recipe_author_id is not None and any(u.id == recipe_author_id for u in likers):
            return 'chef'
        if any(u.is_official for u in likers):
            return 'official'
        return None

class CarouselItem(models.Model):
    """轮播图/Poster 模型 - 独立于 Recipes"""
    title = models.CharField(max_length=200)
    tags = models.JSONField(default=list, blank=True)
    image = models.ImageField(upload_to='carousel/', blank=True, null=True)
    image_url = models.CharField(max_length=500, blank=True, null=True)
    order = models.IntegerField(default=0)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    edited_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['order', 'created_at']
        db_table = 'carousel_items'  # 独立的表

    def __str__(self):
        return self.title

    def get_keywords(self):
        keywords = []
        if self.tags:
            keywords.extend(self.tags)
        if self.title:
            keywords.append(self.title)
        return list(set(keywords))