# groceries/models.py
from django.db import models
from django.conf import settings
import uuid

User = settings.AUTH_USER_MODEL


class GroceryList(models.Model):
    """Grocery list model"""
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='grocery_lists')
    title = models.CharField(max_length=200)
    shopping_date = models.DateField()
    is_generated = models.BooleanField(default=False)
    remark = models.TextField(blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.title} - {self.user.username}"

    @property
    def total_items(self):
        return self.items.count()

    @property
    def checked_items(self):
        return self.items.filter(is_checked=True).count()

    @property
    def progress(self):
        total = self.total_items
        if total == 0:
            return 0.0
        return self.checked_items / total


class GroceryItem(models.Model):
    """Grocery item model"""
    class Category(models.TextChoices):
        VEGETABLES = 'Vegetables', 'Vegetables'
        FRUITS = 'Fruits', 'Fruits'
        MEAT = 'Meat', 'Meat'
        SEAFOOD = 'Seafood', 'Seafood'
        DAIRY = 'Dairy', 'Dairy'
        SPICES = 'Spices', 'Spices'
        OTHERS = 'Others', 'Others'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    grocery_list = models.ForeignKey(GroceryList, on_delete=models.CASCADE, related_name='items')
    name = models.CharField(max_length=200)
    category = models.CharField(max_length=50, choices=Category.choices, default=Category.OTHERS)
    quantity = models.FloatField(default=1.0)
    unit = models.CharField(max_length=20, default='pcs')
    is_checked = models.BooleanField(default=False)
    recipe_name = models.CharField(max_length=200, blank=True, null=True)
    added_date = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.name} ({self.quantity} {self.unit})"