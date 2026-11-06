# users/urls.py
from django.urls import path
from . import views, add_admin
from .views import send_message, get_messages, get_conversations, initiate_call

urlpatterns = [
    # ==================== Authentication ====================
    path('register/', views.register, name='register'),
    path('login/', views.login, name='login'),
    path('logout/', views.logout, name='logout'),

    # ==================== Profile ====================
    path('profile/', views.get_profile, name='profile'),
    path('profile/update/', views.update_profile, name='update_profile'),
    path('profile/<str:user_id>/', views.get_user_profile, name='user_profile'),

    # ==================== Password ====================
    path('change-password/', views.change_password, name='change_password'),
    path('password-reset/', views.password_reset_request, name='password_reset'),

    # ==================== Email & Account ====================
    path('change-email/', views.change_email, name='change_email'),
    path('delete-account/', views.delete_account, name='delete_account'),

    # ==================== Follow ====================
    path('follow/<str:user_id>/', views.follow_user, name='follow'),
    path('unfollow/<str:user_id>/', views.unfollow_user, name='unfollow'),
    path('followers/<str:user_id>/', views.get_followers, name='followers'),
    path('following/<str:user_id>/', views.get_following, name='following'),

    # ==================== Discovery: mentors / all users ====================
    path('mentors/', views.list_mentors, name='list-mentors'),
    path('all-users/', views.list_all_users, name='list-all-users'),

    # ==================== Mentorship requests ====================
    path('mentorship-request/', views.create_mentorship_request, name='create-mentorship-request'),
    path('mentorship-request/<int:request_id>/accept/', views.accept_mentorship_request, name='accept-mentorship-request'),
    path('mentorship-request/<int:request_id>/decline/', views.decline_mentorship_request, name='decline-mentorship-request'),
    path('check-mentorship/<str:user_id>/', views.check_mentorship_status, name='check-mentorship'),

    # ==================== User Details & Stats ====================
    path('users/me/', views.CurrentUserView.as_view(), name='current-user'),
    path('users/<str:user_id>/stats/', views.UserStatsView.as_view(), name='user-stats'),

    # ==================== User Activity ====================
    path('my-posts/', views.UserPostsView.as_view(), name='my-posts'),
    path('my-likes/', views.UserLikesView.as_view(), name='my-likes'),
    path('my-comments/', views.UserCommentsView.as_view(), name='my-comments'),
    path('my-activity-summary/', views.UserActivitySummaryView.as_view(), name='my-activity-summary'),

    # ==================== Check Status ====================
    path('check-like/', views.CheckUserLikeView.as_view(), name='check-like'),
    path('check-follow/<str:user_id>/', views.CheckUserFollowView.as_view(), name='check-follow'),

    # ==================== Points ====================
    path('my-points/', views.UserPointsView.as_view(), name='my-points'),
    path('leaderboard/', views.PointsLeaderboardView.as_view(), name='leaderboard'),

    # ==================== Admin Login ====================
    path('admin/login/', views.admin_login, name='admin-login'),

    # ==================== Chat ====================
    path('chat/send/', send_message, name='send_message'),
    path('chat/messages/<str:other_user_id>/', get_messages, name='get_messages'),
    path('chat/conversations/', get_conversations, name='get_conversations'),
    path('chat/initiate-call/', initiate_call, name='initiate-call'),
    path('chat/call/create/', views.create_call_room, name='create-call-room'),
    path('chat/call/<str:room_id>/', views.get_call_room, name='get-call-room'),
    path('chat/call/<str:room_id>/peer/', views.update_call_room_peer_id, name='update-call-room-peer'),
    path('chat/call/<str:room_id>/end/', views.end_call_room, name='end-call-room'),
    path('chat/call/liked-recipes/', views.get_liked_recipes_for_call, name='call-liked-recipes'),
    path('chat/call/<str:room_id>/sfx/', views.send_sfx, name='send-sfx'),
    path('chat/clear/<str:other_user_id>/', views.clear_chat_history, name='clear_chat_history'),

    # ==================== Admin Panel ====================
    path('admin/dashboard/stats/', add_admin.dashboard_stats, name='admin-dashboard-stats'),
    path('admin/dashboard/pending/', add_admin.dashboard_pending, name='admin-dashboard-pending'),
    path('admin/admins/', add_admin.list_admins, name='admin-list-admins'),
    path('admin/admins/add/', add_admin.add_admin, name='admin-add'),
    path('admin/admins/<str:user_id>/remove/', add_admin.remove_admin, name='admin-remove'),
    path('admin/recipes/', add_admin.admin_list_recipes, name='admin-list-recipes'),
    path('admin/recipes/<str:recipe_id>/approve/', add_admin.admin_approve_recipe, name='admin-approve-recipe'),
    path('admin/recipes/<str:recipe_id>/', add_admin.admin_delete_recipe, name='admin-delete-recipe'),
    path('admin/ingredients/', add_admin.admin_list_ingredients, name='admin-list-ingredients'),
    path('admin/ingredients/<str:post_id>/approve/', add_admin.admin_approve_ingredient, name='admin-approve-ingredient'),
    path('admin/ingredients/<str:post_id>/', add_admin.admin_delete_ingredient, name='admin-delete-ingredient'),
    path('admin/users/', add_admin.admin_list_users, name='admin-list-users'),
    path('admin/users/<str:user_id>/', add_admin.admin_delete_user, name='admin-delete-user'),

    # ==================== System Notifications ====================
    path('system-notifications/', views.get_system_notifications, name='system-notifications'),
    path('system-notifications/<int:notification_id>/read/', views.mark_system_notification_read, name='system-notification-read'),
    path('system-notifications/read-all/', views.mark_all_system_notifications_read, name='system-notifications-read-all'),
    path('chat/messages/<str:other_user_id>/read/', views.mark_messages_read, name='mark_messages_read'),
    path('stickers/', views.list_stickers, name='list-stickers'),
    path('admin/stickers/', add_admin.admin_list_stickers, name='admin-list-stickers'),
    path('admin/stickers/add/', add_admin.admin_add_sticker, name='admin-add-sticker'),
    path('admin/stickers/<int:sticker_id>/toggle/', add_admin.admin_toggle_sticker, name='admin-toggle-sticker'),
    path('admin/stickers/<int:sticker_id>/', add_admin.admin_delete_sticker, name='admin-delete-sticker'),

    # ==================== Admin Reject Post ====================
    path('admin/reject-post/', add_admin.reject_post, name='admin-reject-post'),
]