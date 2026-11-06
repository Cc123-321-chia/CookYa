# recipes/admin.py
from django.contrib import admin
from .models import Recipe, Tag, CookingTool, Ingredient, Step, Comment, Homework, CarouselItem


@admin.register(Recipe)
class RecipeAdmin(admin.ModelAdmin):
    list_display = ['id', 'title', 'author', 'cuisine_type', 'duration_minutes', 'difficulty_level', 'created_at']
    list_filter = ['cuisine_type', 'difficulty_level', 'created_at']
    search_fields = ['title', 'description']
    readonly_fields = ['id', 'created_at', 'updated_at']


@admin.register(Tag)
class TagAdmin(admin.ModelAdmin):
    list_display = ['name', 'recipe']
    search_fields = ['name']


@admin.register(CookingTool)
class CookingToolAdmin(admin.ModelAdmin):
    list_display = ['name', 'recipe']
    search_fields = ['name']


@admin.register(Ingredient)
class IngredientAdmin(admin.ModelAdmin):
    list_display = ['name', 'amount', 'recipe']
    search_fields = ['name']


@admin.register(Step)
class StepAdmin(admin.ModelAdmin):
    list_display = ['step_number', 'instruction', 'recipe', 'note']
    list_filter = ['recipe']


@admin.register(Comment)
class CommentAdmin(admin.ModelAdmin):
    list_display = ['user', 'recipe', 'text', 'created_at']
    list_filter = ['created_at']


@admin.register(Homework)
class HomeworkAdmin(admin.ModelAdmin):
    list_display = ['user', 'recipe', 'rating', 'review', 'created_at']
    list_filter = ['rating', 'created_at']
    search_fields = ['review', 'user__username']
    readonly_fields = ['id', 'created_at']


@admin.register(CarouselItem)
class CarouselItemAdmin(admin.ModelAdmin):
    list_display = ['title', 'order', 'is_active', 'created_at']
    list_display_links = ['title']
    list_filter = ['is_active', 'created_at']
    search_fields = ['title']
    ordering = ['order', 'created_at']
    readonly_fields = ['created_at', 'updated_at']
    fieldsets = (
        ('Basic Info', {
            'fields': ('title',)
        }),
        ('Image', {
            'fields': ('image',),
        }),
        ('Display Settings', {
            'fields': ('order', 'is_active'),
        }),
        ('Metadata', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )
    actions = ['make_active', 'make_inactive']

    def make_active(self, request, queryset):
        queryset.update(is_active=True)
        self.message_user(request, f"{queryset.count()} items marked as active.")
    make_active.short_description = "Mark selected items as Active"

    def make_inactive(self, request, queryset):
        queryset.update(is_active=False)
        self.message_user(request, f"{queryset.count()} items marked as inactive.")
    make_inactive.short_description = "Mark selected items as Inactive"