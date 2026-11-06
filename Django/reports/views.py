# reports/views.py
from rest_framework import generics, status, permissions
from rest_framework.response import Response
from rest_framework.views import APIView
from django.utils import timezone

from .models import Report
from .serializers import ReportSerializer, ReportCreateSerializer


# ==================== 鉴权 Helper ====================

def _get_admin_from_request(request):
    """
    Return an admin-like object for permission checks.

    Priority:
    1. DRF-authenticated staff user (via TokenAuthentication on mirror User).
    2. Legacy: raw Token value equals AdminUser.admin_id.
    """
    from users.models import AdminUser

    user = getattr(request, 'user', None)
    if user is not None and getattr(user, 'is_authenticated', False) \
            and (getattr(user, 'is_staff', False) or getattr(user, 'is_superuser', False)):
        admin_row = AdminUser.objects.filter(email=user.email).first()
        return admin_row if admin_row is not None else user

    auth = request.headers.get('Authorization', '')
    if not auth.startswith('Token '):
        return None
    token = auth.replace('Token ', '').strip()
    if not token:
        return None
    try:
        return AdminUser.objects.get(admin_id=token, is_active=True)
    except AdminUser.DoesNotExist:
        return None


def _get_user_from_request(request):
    """普通用户 token 鉴权（DRF Token 表）"""
    from rest_framework.authtoken.models import Token
    auth = request.headers.get('Authorization', '')
    if not auth.startswith('Token '):
        return None
    token = auth.replace('Token ', '').strip()
    if not token:
        return None
    try:
        return Token.objects.select_related('user').get(key=token).user
    except Token.DoesNotExist:
        return None


def _get_post_author_info(post_type, post_id):
    try:
        if post_type == 'recipe':
            from recipes.models import Recipe
            post = Recipe.objects.select_related('author').get(id=post_id)
            return post.title, str(post.author.user_id), post.author.username
        elif post_type == 'ingredient':
            from ingredients.models import IngredientPost
            post = IngredientPost.objects.select_related('author').get(id=post_id)
            return post.title, str(post.author.user_id), post.author.username
        elif post_type == 'comment':
            from recipes.models import Comment
            c = Comment.objects.select_related('user', 'recipe').get(id=post_id)
            title = f'Comment on: {c.recipe.title}' if c.recipe else 'Comment'
            return title, str(c.user.user_id), c.user.username
    except Exception as e:
        print(f'_get_post_author_info error: {e}')
    return '', '', ''


def _notify_user(user, title, content, notification_type='general',
                 post_type=None, post_id=None):
    try:
        from users.models import SystemNotification
        SystemNotification.objects.create(
            user=user,
            title=title,
            content=content,
            notification_type=notification_type,
            post_type=post_type,
            post_id=post_id,
        )
    except Exception as e:
        print(f'_notify_user error: {e}')


# ==================== Report Create (user submits) ====================

class ReportCreateView(generics.CreateAPIView):
    """User submits a report. Auth: normal user token."""
    permission_classes = [permissions.AllowAny]
    serializer_class = ReportCreateSerializer

    def create(self, request, *args, **kwargs):
        user = _get_user_from_request(request)
        if user is None:
            return Response(
                {'error': 'Authentication required'},
                status=status.HTTP_401_UNAUTHORIZED,
            )

        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        post_type = serializer.validated_data['post_type']
        post_id = serializer.validated_data['post_id']

        existing = Report.objects.filter(
            reporter=user,
            post_type=post_type,
            post_id=post_id,
            status=Report.Status.PENDING,
        ).exists()
        if existing:
            return Response(
                {'error': 'You already reported this post. Please wait for review.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        title, author_id, author_name = _get_post_author_info(post_type, post_id)

        report = Report.objects.create(
            reporter=user,
            post_type=post_type,
            post_id=post_id,
            post_title=title,
            post_author_id=author_id,
            post_author_name=author_name,
            reason=serializer.validated_data['reason'],
            note=serializer.validated_data.get('note', ''),
        )

        return Response(
            {'success': True, 'data': ReportSerializer(report).data},
            status=status.HTTP_201_CREATED,
        )


# ==================== Report List (admin) ====================

class ReportListView(generics.ListAPIView):
    """Admin lists all reports. Auth: AdminUser admin_id."""
    permission_classes = [permissions.AllowAny]
    serializer_class = ReportSerializer

    def get_queryset(self):
        admin = _get_admin_from_request(self.request)
        if not admin:
            return Report.objects.none()
        qs = Report.objects.all().order_by('-created_at')
        status_filter = self.request.query_params.get('status')
        if status_filter and status_filter != 'all':
            qs = qs.filter(status=status_filter)
        return qs


# ==================== Report Resolve (admin) ====================

class ReportResolveView(APIView):
    """Admin resolves a report. Auth: AdminUser admin_id."""
    permission_classes = [permissions.AllowAny]

    def post(self, request, report_id):
        admin = _get_admin_from_request(request)
        if not admin:
            return Response(
                {'error': 'Admin only'},
                status=status.HTTP_403_FORBIDDEN,
            )

        try:
            report = Report.objects.get(id=report_id)
        except Report.DoesNotExist:
            return Response(
                {'error': 'Report not found'},
                status=status.HTTP_404_NOT_FOUND,
            )

        if report.status != Report.Status.PENDING:
            return Response(
                {'error': 'Report already resolved'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        action = request.data.get('action')
        admin_note = request.data.get('admin_note', '').strip()

        if action not in ('keep', 'remove'):
            return Response(
                {'error': 'action must be "keep" or "remove"'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # ============ KEEP ============
        if action == 'keep':
            report.status = Report.Status.RESOLVED_KEPT
            report.admin_note = admin_note
            report.reviewed_at = timezone.now()
            report.save()

            _notify_user(
                report.reporter,
                title='Your report has been reviewed',
                content=(
                    f'Thank you for reporting. After review, we determined '
                    f'that the content does not violate our guidelines and '
                    f'will remain visible.'
                ),
                notification_type='general',
                post_type=report.post_type,
                post_id=report.post_id,
            )

            return Response({
                'success': True,
                'message': 'Report kept. Reporter notified.',
            })

        # ============ REMOVE ============
        removed = _delete_post_by_report(report)
        if not removed:
            return Response(
                {'error': 'Failed to delete post (may already be deleted)'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        report.status = Report.Status.RESOLVED_REMOVED
        report.admin_note = admin_note
        report.reviewed_at = timezone.now()
        report.save()

        _notify_user(
            report.reporter,
            title='Your report has been resolved',
            content=(
                f'The reported content has been removed for violating our '
                f'community guidelines. Thank you for keeping CookYa safe.'
            ),
            notification_type='general',
            post_type=report.post_type,
            post_id=report.post_id,
        )

        try:
            from users.models import User
            author = User.objects.get(user_id=report.post_author_id)
        except Exception as e:
            print(f'Author lookup error: {e}')
            author = None

        if author:
            reason_text = admin_note or report.get_reason_display()

            _notify_user(
                author,
                title='Your post was removed',
                content=(
                    f'Your {report.post_type} "{report.post_title}" was removed '
                    f'for violating our community guidelines.\n\n'
                    f'Reason: {reason_text}'
                ),
                notification_type='post_rejected',
                post_type=report.post_type,
                post_id=report.post_id,
            )

        return Response({
            'success': True,
            'message': 'Post removed. Reporter and author notified.',
        })


def _delete_post_by_report(report):
    try:
        if report.post_type == 'recipe':
            from recipes.models import Recipe
            Recipe.objects.filter(id=report.post_id).delete()
            return True
        elif report.post_type == 'ingredient':
            from ingredients.models import IngredientPost
            IngredientPost.objects.filter(id=report.post_id).delete()
            return True
        elif report.post_type == 'comment':
            from recipes.models import Comment
            Comment.objects.filter(id=report.post_id).delete()
            return True
    except Exception as e:
        print(f'Delete post error: {e}')
    return False