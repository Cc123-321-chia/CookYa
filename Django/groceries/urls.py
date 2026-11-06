# groceries/urls.py
from django.urls import path
from . import views

urlpatterns = [
    # Grocery Lists
    path('', views.GroceryListListView.as_view(), name='grocery-list'),
    path('<uuid:id>/', views.GroceryListDetailView.as_view(), name='grocery-detail'),

    # Items
    path('<uuid:list_id>/items/', views.GroceryItemCreateView.as_view(), name='grocery-item-create'),
    path('items/<uuid:id>/', views.GroceryItemUpdateView.as_view(), name='grocery-item-detail'),
    path('items/<uuid:item_id>/toggle/', views.GroceryItemToggleCheckView.as_view(), name='grocery-item-toggle'),
    path('<uuid:list_id>/items/bulk/', views.GroceryItemBulkUpdateView.as_view(), name='grocery-item-bulk'),

    # Meal Plan
    path('from-meal-plan/', views.GroceryListFromMealPlanView.as_view(), name='grocery-from-meal-plan'),
]