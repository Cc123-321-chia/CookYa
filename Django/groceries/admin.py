# groceries/admin.py
from django.contrib import admin
from .models import GroceryList, GroceryItem


class GroceryItemInline(admin.TabularInline):
    model = GroceryItem
    extra = 0
    fields = ['name', 'category', 'quantity', 'unit', 'is_checked', 'recipe_name']


@admin.register(GroceryList)
class GroceryListAdmin(admin.ModelAdmin):
    list_display = ['title', 'user', 'shopping_date', 'is_generated', 'total_items', 'created_at']
    list_filter = ['is_generated', 'shopping_date', 'created_at']
    search_fields = ['title', 'user__username', 'user__email']
    readonly_fields = ['id', 'created_at', 'updated_at']
    inlines = [GroceryItemInline]


@admin.register(GroceryItem)
class GroceryItemAdmin(admin.ModelAdmin):
    list_display = ['name', 'grocery_list', 'category', 'quantity', 'unit', 'is_checked']
    list_filter = ['category', 'is_checked']
    search_fields = ['name', 'grocery_list__title']