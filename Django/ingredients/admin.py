# ingredients/admin.py
from django.contrib import admin
from .models import IngredientPost, IngredientComment

@admin.register(IngredientPost)
class IngredientPostAdmin(admin.ModelAdmin):
    list_display = ['id', 'title', 'author', 'likes_count', 'comments_count', 'created_at']
    list_filter = ['created_at']
    search_fields = ['title', 'content', 'author__username']
    readonly_fields = ['id', 'created_at', 'updated_at']

    def likes_count(self, obj):
        return obj.likes.count()
    likes_count.short_description = 'Likes'

@admin.register(IngredientComment)
class IngredientCommentAdmin(admin.ModelAdmin):
    list_display = ['id', 'post', 'user', 'text', 'created_at']
    list_filter = ['created_at']
    search_fields = ['text', 'user__username', 'post__title']