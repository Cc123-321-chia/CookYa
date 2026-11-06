# ingredients/urls.py
from django.urls import path, re_path
from . import views
from .views import UserLikedIngredientPostsView, UserIngredientCommentsView

urlpatterns = [
    path('', views.IngredientPostListView.as_view(), name='ingredient-list'),
    path('create/', views.IngredientPostCreateView.as_view(), name='ingredient-create'),

    # 🔥 liked / my-comments 要放在 <uuid:id> 前面
    path('liked/', views.LikedIngredientPostsView.as_view(), name='ingredient-liked'),
    path('my-comments/', views.MyIngredientCommentsView.as_view(), name='ingredient-my-comments'),

    # 🔥 comment delete
    path('comments/<uuid:id>/', views.IngredientCommentDetailView.as_view(), name='ingredient-comment-detail'),

    path('<uuid:id>/', views.IngredientPostDetailView.as_view(), name='ingredient-detail'),
    path('<uuid:id>/update/', views.IngredientPostUpdateView.as_view(), name='ingredient-update'),
    path('<uuid:id>/delete/', views.IngredientPostDeleteView.as_view(), name='ingredient-delete'),
    path('<uuid:id>/like/', views.IngredientPostLikeView.as_view(), name='ingredient-like'),
    path('<uuid:post_id>/comments/', views.IngredientCommentListView.as_view(), name='ingredient-comments'),
    path('users/<str:user_id>/liked/', UserLikedIngredientPostsView.as_view(), name='user-liked-ingredients'),
    path('users/<str:user_id>/comments/', UserIngredientCommentsView.as_view(), name='user-ingredient-comments'),

    re_path(r'^video/(?P<video_path>.+)$', views.stream_video, name='stream-video'),
]