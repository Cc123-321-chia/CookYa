# ingredients/models.py
from django.db import models
from django.conf import settings
import uuid
from django.db import models

User = settings.AUTH_USER_MODEL


class IngredientPost(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    title = models.CharField(max_length=200)
    content = models.TextField()
    image_url = models.CharField(max_length=500, blank=True, null=True)
    photo_urls = models.JSONField(default=list, blank=True)
    video_url = models.CharField(max_length=500, blank=True, null=True)
    video_cover_url = models.CharField(max_length=500, blank=True, null=True)

    author = models.ForeignKey(User, on_delete=models.CASCADE, related_name='ingredient_posts')
    likes = models.ManyToManyField(User, related_name='liked_ingredient_posts', blank=True)
    comments_count = models.IntegerField(default=0)
    is_approved = models.BooleanField(default=False)

    tags = models.JSONField(default=list, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)
    edited_at = models.DateTimeField(null=True, blank=True)

    def like_count(self):
        return self.likes.count()

    @property
    def likes_count(self):
        return self.likes.count()

    def __str__(self):
        return self.title


class IngredientComment(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    post = models.ForeignKey(IngredientPost, on_delete=models.CASCADE, related_name='comments')
    user = models.ForeignKey(User, on_delete=models.CASCADE)
    text = models.TextField()
    image = models.ImageField(upload_to='ingredient_comments/', blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Comment by {self.user.username} on {self.post.title}"