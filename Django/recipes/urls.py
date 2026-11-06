# recipes/urls.py
from django.urls import path
from . import views
from .views import (
    CarouselListView, CarouselAdminListView, CarouselCreateView, CarouselDetailView,
    CarouselSearchView, UserLikedRecipesView, UserRecipeCommentsView,
    HomeworkLikeView,
)

urlpatterns = [
    # ==================== Recipe endpoints ====================
    path('recipes/', views.RecipeListView.as_view(), name='recipe-list'),
    path('recipes/trending/', views.TrendingRecipesView.as_view(), name='trending-recipes'),
    path('recipes/create/', views.RecipeCreateView.as_view(), name='recipe-create'),

    # Special paths must come before <uuid:id>
    path('recipes/liked/', views.LikedRecipesView.as_view(), name='liked-recipes'),
    path('recipes/my-comments/', views.MyRecipeCommentsView.as_view(), name='my-recipe-comments'),
    path('recipes/my-homeworks/', views.MyHomeworkView.as_view(), name='my-homeworks'),
    path('recipes/search-by-keywords/', CarouselSearchView.as_view(), name='search-by-keywords'),

    # ==================== Homework (Dishes) endpoints ====================
    # MUST come before recipes/<uuid:id>/ so 'homeworks' isn't treated as UUID.
    path(
        'recipes/homeworks/<uuid:id>/like/',
        HomeworkLikeView.as_view(),
        name='homework-like',
    ),
    path(
        'recipes/homeworks/<uuid:id>/',
        views.HomeworkDetailView.as_view(),
        name='homework-detail',
    ),
    path(
        'recipes/<uuid:recipe_id>/homeworks/',
        views.HomeworkListView.as_view(),
        name='homework-list',
    ),

    # ==================== Recipe detail / update / delete / like ====================
    path('recipes/<uuid:id>/', views.RecipeDetailView.as_view(), name='recipe-detail'),
    path('recipes/<uuid:id>/update/', views.RecipeUpdateView.as_view(), name='recipe-update'),
    path('recipes/<uuid:id>/delete/', views.RecipeDeleteView.as_view(), name='recipe-delete'),
    path('recipes/<uuid:id>/like/', views.RecipeLikeView.as_view(), name='recipe-like'),

    # ==================== Comment endpoints ====================
    path('recipes/<uuid:recipe_id>/comments/', views.CommentListView.as_view(), name='comment-list'),
    path('comments/<uuid:id>/', views.CommentDetailView.as_view(), name='comment-detail'),

    # ==================== User endpoints ====================
    path('users/<int:user_id>/recipes/', views.UserRecipesView.as_view(), name='user-recipes'),
    path('recipes/users/<str:user_id>/homeworks/', views.UserHomeworkView.as_view(), name='user-homeworks'),

    # ==================== Utilities ====================
    path('cuisines/', views.get_cuisine_types, name='cuisine-types'),

    # ==================== Carousel endpoints ====================
    path('carousel/', CarouselListView.as_view(), name='carousel-list'),
    path('carousel/admin/', CarouselAdminListView.as_view(), name='carousel-admin-list'),
    path('carousel/create/', CarouselCreateView.as_view(), name='carousel-create'),
    path('carousel/reorder/', views.reorder_carousel_items, name='carousel-reorder'),
    path('carousel/<str:id>/', CarouselDetailView.as_view(), name='carousel-detail'),
    path('users/<str:user_id>/liked/', UserLikedRecipesView.as_view(), name='user-liked-recipes'),
    path('users/<str:user_id>/comments/', UserRecipeCommentsView.as_view(), name='user-recipe-comments'),
]