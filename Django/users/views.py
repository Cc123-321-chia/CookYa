# users/views.py
import random
from rest_framework import status
from rest_framework.decorators import (
    api_view, permission_classes, parser_classes, authentication_classes,
)
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.authtoken.models import Token
from django.contrib.auth import authenticate, get_user_model
from django.db.models import Count, Sum
from django.utils import timezone
from django.db import models
from django.utils.dateparse import parse_datetime
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
from rest_framework.views import APIView
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
import uuid


from .serializers import (
    RegisterSerializer, LoginSerializer, UserSerializer,
    ChangePasswordSerializer, FollowSerializer,
    UserPostSerializer, UserLikeSerializer, UserCommentSerializer,
    PointTransactionSerializer, SystemNotificationSerializer,
    StickerSerializer,
)
from .models import (
    UserFollow, UserPost, UserLike, UserComment, PointTransaction,
    Message, AdminUser, SystemNotification,
    Sticker as StickerModel, CallRoom, MentorshipRequest,ChatClearRecord,
)

User = get_user_model()


# ==================== Authentication ====================

@api_view(['POST'])
@authentication_classes([])
@permission_classes([AllowAny])
def register(request):
    serializer = RegisterSerializer(data=request.data)
    if serializer.is_valid():
        user = serializer.save()
        token, created = Token.objects.get_or_create(user=user)
        return Response({
            'success': True,
            'message': 'Registration successful',
            'data': {
                'user': UserSerializer(user, context={'request': request}).data,
                'token': token.key
            }
        }, status=status.HTTP_201_CREATED)
    return Response({'success': False, 'error': serializer.errors}, status=status.HTTP_400_BAD_REQUEST)


@api_view(['POST'])
@authentication_classes([])
@permission_classes([AllowAny])
def login(request):
    serializer = LoginSerializer(data=request.data)
    if not serializer.is_valid():
        return Response({'success': False, 'error': 'Invalid input'}, status=status.HTTP_400_BAD_REQUEST)

    email = serializer.validated_data['email']
    password = serializer.validated_data['password']

    # 先检查 is_active（被 suspend 的账号）
    try:
        user_check = User.objects.get(email=email)
        if not user_check.is_active:
            return Response({
                'success': False,
                'error': 'Your account has been suspended. Please contact support.'
            }, status=status.HTTP_403_FORBIDDEN)
    except User.DoesNotExist:
        pass

    user = authenticate(request, email=email, password=password)

    if user is not None:
        if user.is_staff or user.is_superuser:
            return Response({
                'success': False,
                'error': 'This account is for Admin panel only. Please use an App account.'
            }, status=status.HTTP_403_FORBIDDEN)

        user.level = user.calculate_level()
        user.save()
        token, created = Token.objects.get_or_create(user=user)
        return Response({
            'success': True,
            'message': 'Login successful',
            'data': {
                'user': UserSerializer(user, context={'request': request}).data,
                'token': token.key
            }
        })
    else:
        return Response({'success': False, 'error': 'Invalid email or password'}, status=status.HTTP_401_UNAUTHORIZED)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def logout(request):
    try:
        request.user.auth_token.delete()
    except:
        pass
    return Response({'success': True, 'message': 'Logged out successfully'})


# ==================== User Profile ====================

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_profile(request):
    serializer = UserSerializer(request.user, context={'request': request})
    return Response({'success': True, 'data': serializer.data})


@api_view(['GET'])
@permission_classes([AllowAny])
def get_user_profile(request, user_id):
    try:
        user = User.objects.get(user_id=user_id)
        serializer = UserSerializer(user, context={'request': request})
        return Response({'success': True, 'data': serializer.data})
    except User.DoesNotExist:
        return Response({'success': False, 'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)


@api_view(['PUT', 'POST'])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def update_profile(request):
    user = request.user
    user.username = request.data.get('username', user.username)
    user.bio = request.data.get('bio', user.bio)
    if 'avatar' in request.FILES:
        user.avatar = request.FILES['avatar']
    user.save()
    return Response({
        'success': True,
        'message': 'Profile updated',
        'data': UserSerializer(user, context={'request': request}).data
    })


# ==================== Password / Email ====================

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def password_reset_request(request):
    email = request.data.get('email')
    if not email:
        return Response({'success': False, 'error': 'Email is required'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        user = User.objects.get(email=email)
        return Response({'success': True, 'message': 'Password reset link would be sent to your email'})
    except User.DoesNotExist:
        return Response({'success': False, 'error': 'No user found with this email'}, status=status.HTTP_404_NOT_FOUND)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def change_password(request):
    new_password = request.data.get('new_password')
    confirm_password = request.data.get('confirm_password')
    if not new_password or not confirm_password:
        return Response({'error': 'Password fields are required'}, status=400)
    if new_password != confirm_password:
        return Response({'error': 'Passwords do not match'}, status=400)
    request.user.set_password(new_password)
    request.user.save()
    return Response({'success': True, 'message': 'Password changed successfully'})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def change_email(request):
    new_email = request.data.get('new_email')
    if not new_email:
        return Response({'error': 'Email is required'}, status=400)
    if User.objects.filter(email=new_email).exists():
        return Response({'error': 'Email already exists'}, status=400)
    request.user.email = new_email
    request.user.save()
    return Response({'success': True, 'message': 'Email changed successfully'})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def delete_account(request):
    password = request.data.get('password')
    if not password:
        return Response({'error': 'Password is required'}, status=400)
    if not request.user.check_password(password):
        return Response({'error': 'Wrong password'}, status=400)
    request.user.delete()
    return Response({'success': True, 'message': 'Account deleted successfully'})


# ==================== Follow ====================

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def follow_user(request, user_id):
    try:
        user_to_follow = User.objects.get(user_id=user_id)
        if user_to_follow == request.user:
            return Response({'success': False, 'error': 'Cannot follow yourself'}, status=status.HTTP_400_BAD_REQUEST)
        follow, created = UserFollow.objects.get_or_create(user=user_to_follow, follower=request.user)
        if created:
            return Response({'success': True, 'message': f'You are now following {user_to_follow.username}'})
        else:
            return Response({'success': False, 'error': 'Already following this user'}, status=status.HTTP_400_BAD_REQUEST)
    except User.DoesNotExist:
        return Response({'success': False, 'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def unfollow_user(request, user_id):
    try:
        user_to_unfollow = User.objects.get(user_id=user_id)
        deleted = UserFollow.objects.filter(user=user_to_unfollow, follower=request.user).delete()
        if deleted[0] > 0:
            return Response({'success': True, 'message': f'Unfollowed {user_to_unfollow.username}'})
        else:
            return Response({'success': False, 'error': 'Not following this user'}, status=status.HTTP_400_BAD_REQUEST)
    except User.DoesNotExist:
        return Response({'success': False, 'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_followers(request, user_id):
    try:
        user = User.objects.get(user_id=user_id)
        followers = UserFollow.objects.filter(user=user)
        serializer = FollowSerializer(followers, many=True, context={'request': request})
        return Response({'success': True, 'count': followers.count(), 'data': serializer.data})
    except User.DoesNotExist:
        return Response({'success': False, 'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_following(request, user_id):
    try:
        user = User.objects.get(user_id=user_id)
        following = UserFollow.objects.filter(follower=user)
        serializer = FollowSerializer(following, many=True, context={'request': request})
        return Response({'success': True, 'count': following.count(), 'data': serializer.data})
    except User.DoesNotExist:
        return Response({'success': False, 'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)


# ==================== User Activity Views ====================

class CurrentUserView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        serializer = UserSerializer(request.user, context={'request': request})
        return Response({'success': True, 'data': serializer.data})


class UserStatsView(APIView):
    permission_classes = [AllowAny]

    def get(self, request, user_id):
        try:
            user = User.objects.get(user_id=user_id)
            serializer = UserSerializer(user, context={'request': request})
            return Response({'success': True, 'data': serializer.data})
        except User.DoesNotExist:
            return Response({'success': False, 'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)


class UserPostsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        post_type = request.query_params.get('type')
        queryset = UserPost.objects.filter(user=request.user)
        if post_type:
            queryset = queryset.filter(post_type=post_type)
        queryset = queryset.order_by('-created_at')
        serializer = UserPostSerializer(queryset, many=True, context={'request': request})
        return Response({'success': True, 'count': queryset.count(), 'data': serializer.data})


class UserLikesView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        like_type = request.query_params.get('type')
        queryset = UserLike.objects.filter(user=request.user)
        if like_type:
            queryset = queryset.filter(like_type=like_type)
        queryset = queryset.order_by('-created_at')
        serializer = UserLikeSerializer(queryset, many=True, context={'request': request})
        return Response({'success': True, 'count': queryset.count(), 'data': serializer.data})


class UserCommentsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        comment_type = request.query_params.get('type')
        queryset = UserComment.objects.filter(user=request.user)
        if comment_type:
            queryset = queryset.filter(comment_type=comment_type)
        queryset = queryset.order_by('-created_at')
        serializer = UserCommentSerializer(queryset, many=True, context={'request': request})
        return Response({'success': True, 'count': queryset.count(), 'data': serializer.data})


class UserActivitySummaryView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        posts = UserPost.objects.filter(user=user).order_by('-created_at')[:5]
        likes = UserLike.objects.filter(user=user).order_by('-created_at')[:5]
        comments = UserComment.objects.filter(user=user).order_by('-created_at')[:5]
        activities = []
        for post in posts:
            activities.append({'type': 'post', 'post_type': post.post_type, 'post_id': post.post_id, 'created_at': post.created_at.isoformat()})
        for like in likes:
            activities.append({'type': 'like', 'like_type': like.like_type, 'post_id': like.post_id, 'created_at': like.created_at.isoformat()})
        for comment in comments:
            activities.append({'type': 'comment', 'comment_type': comment.comment_type, 'post_id': comment.post_id, 'content': comment.content, 'created_at': comment.created_at.isoformat()})
        activities.sort(key=lambda x: x['created_at'], reverse=True)
        activities = activities[:20]
        return Response({'success': True, 'data': {
            'total_posts': user.total_posts,
            'total_likes_given': user.total_likes_given,
            'total_comments': user.total_comments,
            'recent_activities': activities
        }})


class CheckUserLikeView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        like_type = request.query_params.get('type')
        post_id = request.query_params.get('post_id')
        if not like_type or not post_id:
            return Response({'success': False, 'error': 'type and post_id are required'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            post_id = int(post_id)
        except ValueError:
            return Response({'success': False, 'error': 'post_id must be an integer'}, status=status.HTTP_400_BAD_REQUEST)
        exists = UserLike.objects.filter(user=request.user, like_type=like_type, post_id=post_id).exists()
        return Response({'success': True, 'data': {'liked': exists}})


class CheckUserFollowView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, user_id):
        try:
            target_user = User.objects.get(user_id=user_id)
        except User.DoesNotExist:
            return Response({'success': False, 'error': 'User not found'}, status=status.HTTP_404_NOT_FOUND)
        is_following = UserFollow.objects.filter(user=target_user, follower=request.user).exists()
        return Response({'success': True, 'data': {'is_following': is_following}})


class UserPointsView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        user = request.user
        recent_transactions = PointTransaction.objects.filter(user=user)[:10]
        total_earned = PointTransaction.objects.filter(user=user, points__gt=0).aggregate(total=models.Sum('points'))['total'] or 0
        return Response({'success': True, 'data': {
            'current_points': user.points,
            'current_level': user.level,
            'total_earned': total_earned,
            'daily_login_streak': user.daily_login_streak,
            'recent_transactions': PointTransactionSerializer(recent_transactions, many=True).data
        }})


class PointsLeaderboardView(APIView):
    permission_classes = [AllowAny]

    def get(self, request):
        limit = request.query_params.get('limit', 20)
        top_users = User.objects.filter(is_active=True).order_by('-points')[:int(limit)]
        return Response({'success': True, 'data': [
            {
                'rank': idx + 1, 'user_id': user.user_id, 'username': user.username,
                'role_info': user.get_role_display_info(), 'points': user.points,
                'level': user.level, 'avatar': user.avatar.url if user.avatar else None,
            } for idx, user in enumerate(top_users)
        ]})


# ==================== Admin Login (AdminUser table) ====================

@api_view(['POST'])
@authentication_classes([])
@permission_classes([AllowAny])
def admin_login(request):
    email = request.data.get('email', '').strip()
    password = request.data.get('password', '')
    if not email or not password:
        return Response({'error': 'Email and password are required'}, status=status.HTTP_400_BAD_REQUEST)
    try:
        admin = AdminUser.objects.get(email=email)
    except AdminUser.DoesNotExist:
        return Response({'error': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)
    if not admin.check_password(password):
        return Response({'error': 'Invalid credentials'}, status=status.HTTP_401_UNAUTHORIZED)
    if not admin.is_active:
        return Response({'error': 'Account disabled'}, status=status.HTTP_403_FORBIDDEN)
    admin.last_login = timezone.now()
    admin.save(update_fields=['last_login'])

    # Mirror the AdminUser into users_user so DRF TokenAuthentication works.
    mirror_user = User.objects.filter(username=f'admin_{admin.admin_id}').first()
    if mirror_user is None:
        while True:
            candidate = str(random.randint(10000000, 99999999))
            if not User.objects.filter(user_id=candidate).exists():
                break

        mirror_user = User.objects.create(
            username=f'admin_{admin.admin_id}',
            user_id=candidate,
            email=admin.email,
            is_staff=True,
            is_superuser=(admin.role == 'super_admin'),
            is_active=admin.is_active,
        )
        mirror_user.set_unusable_password()
        mirror_user.save()
    else:
        changed = False
        if not mirror_user.is_staff:
            mirror_user.is_staff = True
            changed = True
        if admin.role == 'super_admin' and not mirror_user.is_superuser:
            mirror_user.is_superuser = True
            changed = True
        if changed:
            mirror_user.save(update_fields=['is_staff', 'is_superuser'])

    drf_token, _ = Token.objects.get_or_create(user=mirror_user)

    return Response({
        'success': True,
        'token': drf_token.key,
        'user': {
            'admin_id': admin.admin_id,
            'name': admin.name,
            'email': admin.email,
            'role': admin.role,
        }
    }, status=status.HTTP_200_OK)


# ==================== System Notifications ====================

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_system_notifications(request):
    notifs = SystemNotification.objects.filter(user=request.user).order_by('-created_at')
    serializer = SystemNotificationSerializer(notifs, many=True)
    unread_count = notifs.filter(is_read=False).count()
    return Response({
        'success': True,
        'unread_count': unread_count,
        'data': serializer.data,
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_system_notification_read(request, notification_id):
    try:
        notif = SystemNotification.objects.get(id=notification_id, user=request.user)
    except SystemNotification.DoesNotExist:
        return Response({'success': False, 'error': 'Not found'}, status=404)
    notif.is_read = True
    notif.save()
    return Response({'success': True})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_all_system_notifications_read(request):
    SystemNotification.objects.filter(user=request.user, is_read=False).update(is_read=True)
    return Response({'success': True})


# ==================== Chat ====================

@api_view(['POST'])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def send_message(request):
    receiver_id = request.data.get('receiver_id')
    if not receiver_id:
        return Response({'success': False, 'error': 'receiver_id required'}, status=400)

    msg_type = request.data.get('message_type', 'text')
    text = request.data.get('text', '').strip()
    media = request.FILES.get('media')
    sticker_id = request.data.get('sticker_id')

    if msg_type == 'text' and not text:
        return Response({'success': False, 'error': 'text required'}, status=400)
    if msg_type in ('image', 'video') and not media:
        return Response({'success': False, 'error': 'media required'}, status=400)
    if msg_type == 'sticker' and sticker_id is None:
        return Response({'success': False, 'error': 'sticker_id required'}, status=400)

    sender_id = request.user.user_id
    msg = Message(
        sender_id=sender_id,
        receiver_id=receiver_id,
        text=text,
        message_type=msg_type,
    )
    if media:
        msg.media = media
    if sticker_id:
        try:
            msg.sticker_id = int(sticker_id)
        except ValueError:
            pass
    msg.save()
    return Response({'success': True, 'data': msg.to_dict(request=request)}, status=201)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_messages(request, other_user_id):
    """
    Return messages between current user and other_user_id.

    If the current user has cleared this chat, only messages created
    AFTER `cleared_at` are returned. The other user is unaffected.
    """
    me = request.user.user_id
    since = request.query_params.get('since')

    qs = Message.objects.filter(
        models.Q(sender_id=me, receiver_id=other_user_id) |
        models.Q(sender_id=other_user_id, receiver_id=me)
    )

    # Hide messages older than the clear point (only for current user).
    clear = ChatClearRecord.objects.filter(
        user=request.user, other_user_id=other_user_id
    ).first()
    if clear:
        qs = qs.filter(created_at__gt=clear.cleared_at)

    if since:
        since_dt = parse_datetime(since)
        if since_dt:
            qs = qs.filter(created_at__gt=since_dt)

    data = [m.to_dict(request=request) for m in qs.order_by('created_at')[:500]]
    return Response({'success': True, 'data': data})


def _build_last_message_preview(msg):
    """
    Build a friendly preview string for the conversation list.

    Examples:
    - text:    "Hello there!"
    - sticker: "[Sticker]"
    - image:   "[Photo]"
    - video:   "[Video]"
    - call:    "[Video Call]"
    - invite:  "[Video Call]"
    - end:     "[Video Call]"
    - mentorship: "Mentorship request"
    """
    t = msg.message_type
    text = (msg.text or '').strip()

    if t == 'text':
        # Sticker sent as "sticker:<id>" inside a text message
        if text.startswith('sticker:'):
            return '[Sticker]'
        return text if text else '[Message]'

    if t == 'sticker':
        return '[Sticker]'
    if t == 'image':
        return '[Photo]'
    if t == 'video':
        return '[Video]'
    if t == 'call_invite':
        return '[Video Call]'
    if t == 'call_end':
        return '[Video Call]'
    if t == 'mentorship_request':
        if 'accepted' in text.lower():
            return 'Mentorship accepted'
        if 'declined' in text.lower():
            return 'Mentorship declined'
        return 'Mentorship request'

    # Fallback
    return text if text else '[Message]'

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_conversations(request):
    """
    Return the list of conversations for the current user.

    Conversations whose latest visible message is older than the user's
    `cleared_at` are hidden from the list. The other user is unaffected.
    """
    me = request.user.user_id
    me_user = request.user

    # Collect all partner IDs who have ever exchanged messages with me.
    partner_ids = set()
    msgs = Message.objects.filter(
        models.Q(sender_id=me) | models.Q(receiver_id=me)
    ).values('sender_id', 'receiver_id')
    for m in msgs:
        pid = m['receiver_id'] if m['sender_id'] == me else m['sender_id']
        partner_ids.add(pid)

    conversations = []
    for pid in partner_ids:
        qs = Message.objects.filter(
            models.Q(sender_id=me, receiver_id=pid) |
            models.Q(sender_id=pid, receiver_id=me)
        )

        # Hide messages before the user's clear point.
        clear = ChatClearRecord.objects.filter(
            user=request.user, other_user_id=pid
        ).first()
        if clear:
            qs = qs.filter(created_at__gt=clear.cleared_at)

        last = qs.order_by('-created_at').first()
        if not last:
            # No visible messages left -> hide this conversation entirely.
            continue

        unread_count = qs.filter(
            sender_id=pid, receiver_id=me, is_read=False
        ).count()

        is_my_mentor = False
        is_my_mentee = False
        try:
            partner = User.objects.get(user_id=pid)
            is_my_mentor = MentorshipRequest.objects.filter(
                mentee=me_user, mentor=partner,
                status=MentorshipRequest.Status.ACCEPTED,
            ).exists()
            is_my_mentee = MentorshipRequest.objects.filter(
                mentee=partner, mentor=me_user,
                status=MentorshipRequest.Status.ACCEPTED,
            ).exists()
        except User.DoesNotExist:
            pass

        # Build a friendly preview string for the conversation list.
        preview = _build_last_message_preview(last)

        conversations.append({
            'other_user_id': pid,
            'last_message': preview,
            'last_message_time': last.created_at.isoformat(),
            'unread_count': unread_count,
            'is_my_mentor': is_my_mentor,
            'is_my_mentee': is_my_mentee,
        })

    conversations.sort(key=lambda x: x['last_message_time'], reverse=True)
    return Response({'success': True, 'data': conversations})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def mark_messages_read(request, other_user_id):
    me = request.user.user_id
    updated = Message.objects.filter(
        sender_id=other_user_id,
        receiver_id=me,
        is_read=False,
    ).update(is_read=True)
    return Response({'success': True, 'updated': updated})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def initiate_call(request):
    receiver_id = request.data.get('receiver_id')
    call_type = request.data.get('call_type', 'video')
    peer_id = request.data.get('peer_id')
    if not receiver_id or not peer_id:
        return Response({'success': False, 'error': 'receiver_id and peer_id required'}, status=400)
    channel_layer = get_channel_layer()
    async_to_sync(channel_layer.group_send)(
        f'call_{receiver_id}',
        {
            'type': 'call_notify',
            'caller_id': str(request.user.user_id),
            'caller_name': request.user.username,
            'caller_avatar': request.user.avatar.url if request.user.avatar else '',
            'call_type': call_type,
            'peer_id': peer_id,
        }
    )
    return Response({'success': True, 'message': 'Call notification sent'})


# ==================== Call Rooms (link-based) ====================

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_call_room(request):
    receiver_id = request.data.get('receiver_id')
    call_type = request.data.get('call_type', 'video')
    if not receiver_id:
        return Response({'success': False, 'error': 'receiver_id required'}, status=400)

    room_id = str(uuid.uuid4())
    room = CallRoom.objects.create(
        room_id=room_id,
        caller_id=request.user.user_id,
        receiver_id=receiver_id,
        call_type=call_type,
    )

    # 同时在聊天里插入一条“通话邀请”消息
    msg = Message.objects.create(
        sender_id=request.user.user_id,
        receiver_id=receiver_id,
        text=f'Video call invite: {room_id}',
        message_type='call_invite',
    )
    msg.save()

    return Response({
        'success': True,
        'data': {
            'room_id': room_id,
            'call_type': call_type,
            'message': msg.to_dict(request=request),
        }
    }, status=201)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_call_room(request, room_id):
    try:
        room = CallRoom.objects.get(room_id=room_id)
    except CallRoom.DoesNotExist:
        return Response({'success': False, 'error': 'Room not found'}, status=404)
    return Response({
        'success': True,
        'data': {
            'room_id': room.room_id,
            'caller_id': room.caller_id,
            'receiver_id': room.receiver_id,
            'call_type': room.call_type,
            'caller_peer_id': room.caller_peer_id,
            'is_active': room.is_active,
        }
    })

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_call_room_peer_id(request, room_id):
    try:
        room = CallRoom.objects.get(room_id=room_id)
    except CallRoom.DoesNotExist:
        return Response({'success': False, 'error': 'Room not found'}, status=404)
    peer_id = request.data.get('peer_id', '').strip()
    if not peer_id:
        return Response({'success': False, 'error': 'peer_id required'}, status=400)
    room.caller_peer_id = peer_id
    room.save(update_fields=['caller_peer_id'])
    return Response({'success': True})

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def end_call_room(request, room_id):
    try:
        room = CallRoom.objects.get(room_id=room_id)
    except CallRoom.DoesNotExist:
        return Response({'success': False, 'error': 'Room not found'}, status=404)

    duration = request.data.get('duration_seconds', 0)
    try:
        room.duration_seconds = int(duration)
    except (ValueError, TypeError):
        room.duration_seconds = 0
    room.is_active = False
    room.ended_at = timezone.now()
    room.save(update_fields=['is_active', 'ended_at', 'duration_seconds'])

    # 让前端能渲染「已结束 + 时长」，text 里存 duration_seconds
    Message.objects.create(
        sender_id=room.caller_id,
        receiver_id=room.receiver_id,
        text=f'Call ended: {room.duration_seconds}',
        message_type='call_end',
    )
    return Response({'success': True, 'duration': room.duration_seconds})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_sfx(request, room_id):
    """一方触发音效 → 通过 WebSocket 推给对方，让对方也播"""
    try:
        room = CallRoom.objects.get(room_id=room_id)
    except CallRoom.DoesNotExist:
        return Response({'success': False, 'error': 'Room not found'}, status=404)
    if not room.is_active:
        return Response({'success': False, 'error': 'Room not active'}, status=400)

    sfx = request.data.get('sfx', '').strip()
    if sfx not in ('cheer', 'applause', 'cook', 'confetti'):
        return Response({'success': False, 'error': 'Invalid sfx'}, status=400)

    # 推送给自己之外的另一个 user
    other_user = room.receiver_id if request.user.user_id == room.caller_id else room.caller_id
    channel_layer = get_channel_layer()
    async_to_sync(channel_layer.group_send)(
        f'call_{other_user}',
        {
            'type': 'call_sfx',
            'sfx': sfx,
        }
    )
    return Response({'success': True})

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_liked_recipes_for_call(request):
    """拉当前用户点赞过的 recipe，给视频通话的 Recipe 按钮用"""
    from recipes.models import Recipe
    from .models import UserLike

    liked_ids = list(
        UserLike.objects.filter(user=request.user, like_type='recipe')
        .values_list('post_id', flat=True)
    )

    recipes = Recipe.objects.filter(id__in=liked_ids).order_by('-created_at')[:30]
    data = []
    for r in recipes:
        data.append({
            'id': str(r.id),
            'title': r.title,
            'duration': f'{r.duration_minutes} mins' if hasattr(r, 'duration_minutes') else '',
            'difficulty': r.get_difficulty_display() if hasattr(r, 'get_difficulty_display') else '',
            'ingredients': getattr(r, 'ingredients', '') or '',
            'steps': getattr(r, 'steps', '') or '',
        })
    return Response({'success': True, 'data': data})


# ==================== Stickers ====================

@api_view(['GET'])
@permission_classes([AllowAny])
def list_stickers(request):
    """前端聊天面板用：只返回启用的 sticker"""
    stickers = StickerModel.objects.filter(is_active=True).order_by('name')
    serializer = StickerSerializer(
        stickers, many=True, context={'request': request},
    )
    return Response({'success': True, 'data': serializer.data})

# ==================== Discovery: Mentors & All Users ====================

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_mentors(request):
    """Return all users with is_mentor=True, excluding current user."""
    users = User.objects.filter(is_mentor=True, is_active=True).exclude(id=request.user.id)
    serializer = UserSerializer(users, many=True, context={'request': request})
    return Response({'success': True, 'data': serializer.data})


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_all_users(request):
    """Return all active users, excluding current user."""
    users = User.objects.filter(is_active=True).exclude(id=request.user.id).order_by('-points')
    serializer = UserSerializer(users, many=True, context={'request': request})
    return Response({'success': True, 'data': serializer.data})


# ==================== Mentorship requests ====================

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_mentorship_request(request):
    mentor_user_id = request.data.get('mentor_user_id')
    if not mentor_user_id:
        return Response(
            {'success': False, 'error': 'mentor_user_id required'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        mentor = User.objects.get(user_id=mentor_user_id)
    except User.DoesNotExist:
        return Response(
            {'success': False, 'error': 'Mentor not found'},
            status=status.HTTP_404_NOT_FOUND,
        )

    if not mentor.is_mentor:
        return Response(
            {'success': False, 'error': 'This user is not a mentor'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if mentor.id == request.user.id:
        return Response(
            {'success': False, 'error': 'You cannot request yourself'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    # Already accepted?
    if MentorshipRequest.objects.filter(
        mentee=request.user, mentor=mentor,
        status=MentorshipRequest.Status.ACCEPTED,
    ).exists():
        return Response(
            {'success': False, 'error': 'You are already this user\'s mentee'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    # Pending for this mentor already?
    pending = MentorshipRequest.objects.filter(
        mentee=request.user, mentor=mentor,
        status=MentorshipRequest.Status.PENDING,
    ).first()
    if pending:
        return Response(
            {'success': False, 'error': 'You already have a pending request to this mentor'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    req = MentorshipRequest.objects.create(mentee=request.user, mentor=mentor)

    # Auto-send a chat message
    msg = Message.objects.create(
        sender_id=request.user.user_id,
        receiver_id=mentor.user_id,
        text='Can you be my mentor?',
        message_type='mentorship_request',
        related_id=str(req.id),
    )

    return Response({
        'success': True,
        'data': {
            'request_id': req.id,
            'message': msg.to_dict(request=request),
        }
    }, status=status.HTTP_201_CREATED)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def accept_mentorship_request(request, request_id):
    try:
        req = MentorshipRequest.objects.get(
            id=request_id, mentor=request.user,
            status=MentorshipRequest.Status.PENDING,
        )
    except MentorshipRequest.DoesNotExist:
        return Response(
            {'success': False, 'error': 'Request not found or already handled'},
            status=status.HTTP_404_NOT_FOUND,
        )

    req.status = MentorshipRequest.Status.ACCEPTED
    req.responded_at = timezone.now()
    req.save(update_fields=['status', 'responded_at'])

    # Update the original chat message so both ends see the result.
    Message.objects.filter(
        sender_id=req.mentee.user_id,
        receiver_id=req.mentor.user_id,
        message_type='mentorship_request',
        related_id=str(req.id),
    ).update(text='Mentorship accepted')

    SystemNotification.objects.create(
        user=req.mentee,
        title='Mentorship Accepted',
        content=f'{req.mentor.username} accepted your mentorship request!',
        notification_type='mentorship_accepted',
        post_type='mentorship',
        post_id=str(req.id),
    )

    return Response({'success': True, 'data': {'request_id': req.id}})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def decline_mentorship_request(request, request_id):
    try:
        req = MentorshipRequest.objects.get(
            id=request_id, mentor=request.user,
            status=MentorshipRequest.Status.PENDING,
        )
    except MentorshipRequest.DoesNotExist:
        return Response(
            {'success': False, 'error': 'Request not found or already handled'},
            status=status.HTTP_404_NOT_FOUND,
        )

    req.status = MentorshipRequest.Status.DECLINED
    req.responded_at = timezone.now()
    req.save(update_fields=['status', 'responded_at'])

    Message.objects.filter(
        sender_id=req.mentee.user_id,
        receiver_id=req.mentor.user_id,
        message_type='mentorship_request',
        related_id=str(req.id),
    ).update(text='Mentorship declined')

    SystemNotification.objects.create(
        user=req.mentee,
        title='Mentorship Declined',
        content=f'{req.mentor.username} declined your mentorship request.',
        notification_type='mentorship_declined',
        post_type='mentorship',
        post_id=str(req.id),
    )

    return Response({'success': True, 'data': {'request_id': req.id}})

# ==================== Mentorship status ====================

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def check_mentorship_status(request, user_id):
    """
    GET /api/users/check-mentorship/<user_id>/
    Returns:
        {
          "is_my_mentor": bool,   # <user_id> is the mentor of the current user
          "is_my_mentee": bool,   # <user_id> is the mentee of the current user
        }
    """
    try:
        other = User.objects.get(user_id=user_id)
    except User.DoesNotExist:
        return Response(
            {'success': False, 'error': 'User not found'},
            status=status.HTTP_404_NOT_FOUND,
        )

    is_my_mentor = MentorshipRequest.objects.filter(
        mentee=request.user, mentor=other,
        status=MentorshipRequest.Status.ACCEPTED,
    ).exists()

    is_my_mentee = MentorshipRequest.objects.filter(
        mentee=other, mentor=request.user,
        status=MentorshipRequest.Status.ACCEPTED,
    ).exists()

    return Response({
        'success': True,
        'data': {
            'is_my_mentor': is_my_mentor,
            'is_my_mentee': is_my_mentee,
        }
    })

# ==================== Chat history management ====================

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def clear_chat_history(request, other_user_id):
    """
    Clear chat history between current user and other_user_id.

    WeChat-style:
    - Only affects the current user.
    - Messages before `cleared_at` become invisible to the current user.
    - The other user still sees the full conversation.
    - Message rows are NOT deleted (the other side still needs them).
    """
    ChatClearRecord.objects.update_or_create(
        user=request.user,
        other_user_id=other_user_id,
        defaults={},  # auto_now updates cleared_at automatically
    )
    return Response({
        'success': True,
        'message': 'Chat history cleared for you',
    })