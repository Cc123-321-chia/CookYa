# users/admin.py
from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin
from django.utils import timezone
from django.utils.html import format_html
from .models import (
    User, UserFollow, UserPost, UserLike, UserComment, PointTransaction,
    MentorshipRequest, Message, SystemNotification,
)


# ==================== Mentorship status sync helper ====================

def _sync_mentorship_message_text(req):
    """
    Keep the chat message in sync with the MentorshipRequest status,
    so both the mentor's and mentee's chat bubbles show the result.
    """
    if req.status == MentorshipRequest.Status.PENDING:
        return 0

    new_text = (
        'Mentorship accepted'
        if req.status == MentorshipRequest.Status.ACCEPTED
        else 'Mentorship declined'
    )
    return Message.objects.filter(
        sender_id=req.mentee.user_id,
        receiver_id=req.mentor.user_id,
        message_type='mentorship_request',
        related_id=str(req.id),
    ).update(text=new_text)


# ==================== Custom User Admin ====================

class CustomUserAdmin(BaseUserAdmin):
    list_display = (
        'user_id', 'username', 'email', 'level', 'points',
        'is_official', 'is_mentor', 'is_expert', 'is_culinary_instructor', 'is_staff',
        'mentor_of_count', 'mentee_of_count',
    )
    list_filter = (
        'is_official', 'is_mentor', 'is_expert', 'is_culinary_instructor',
        'level', 'is_staff', 'is_active'
    )
    search_fields = ('user_id', 'username', 'email')
    ordering = ('-date_joined',)

    fieldsets = (
        (None, {'fields': ('user_id', 'username', 'email', 'password')}),
        ('Personal Info', {'fields': ('avatar', 'bio')}),
        ('Permissions', {'fields': ('is_active', 'is_staff', 'is_superuser', 'groups', 'user_permissions')}),
        ('Important Dates', {'fields': ('last_login', 'date_joined')}),
        ('CookYa Info', {
            'fields': ('level', 'points')
        }),
        ('Roles', {
            'fields': (
                'is_official', 'official_since',
                'is_mentor', 'mentor_since',
                'is_expert', 'expert_qualification', 'expert_verified_at', 'verified_by',
                'is_culinary_instructor', 'instructor_qualification', 'instructor_verified_at', 'instructor_verified_by'
            )
        }),
        ('Statistics - Posts', {
            'fields': ('recipe_count', 'ingredient_count', 'dish_count', 'total_posts')
        }),
        ('Statistics - Likes Received', {
            'fields': ('recipe_likes_received', 'ingredient_likes_received', 'dish_likes_received', 'total_likes_received')
        }),
        ('Statistics - Likes Given', {
            'fields': ('recipe_likes_given', 'ingredient_likes_given', 'dish_likes_given', 'total_likes_given')
        }),
        ('Statistics - Comments', {
            'fields': ('recipe_comments', 'ingredient_comments', 'dish_comments', 'total_comments')
        }),
    )

    readonly_fields = (
        'user_id', 'level', 'points',
        'recipe_count', 'ingredient_count', 'dish_count', 'total_posts',
        'recipe_likes_received', 'ingredient_likes_received', 'dish_likes_received', 'total_likes_received',
        'recipe_likes_given', 'ingredient_likes_given', 'dish_likes_given', 'total_likes_given',
        'recipe_comments', 'ingredient_comments', 'dish_comments', 'total_comments',
        'expert_verified_at', 'instructor_verified_at', 'mentor_since', 'official_since', 'date_joined', 'last_login'
    )

    add_fieldsets = (
        (None, {
            'classes': ('wide',),
            'fields': ('username', 'email', 'password1', 'password2'),
        }),
    )

    actions = [
        'make_official', 'revoke_official',
        'verify_expert', 'revoke_expert',
        'verify_instructor', 'revoke_instructor',
        'make_mentor', 'revoke_mentor',
    ]

    def mentor_of_count(self, obj):
        return MentorshipRequest.objects.filter(
            mentor=obj, status=MentorshipRequest.Status.ACCEPTED
        ).count()
    mentor_of_count.short_description = '# mentees'

    def mentee_of_count(self, obj):
        return MentorshipRequest.objects.filter(
            mentee=obj, status=MentorshipRequest.Status.ACCEPTED
        ).count()
    mentee_of_count.short_description = '# mentors'

    # ---- Role actions (unchanged from your version) ----

    def make_official(self, request, queryset):
        for user in queryset:
            user.is_official = True
            user.official_since = timezone.now()
            user.is_mentor = False
            user.is_expert = False
            user.is_culinary_instructor = False
            user.save()
        self.message_user(request, f"{queryset.count()} users set as official.")
    make_official.short_description = "Make selected users official"

    def revoke_official(self, request, queryset):
        queryset.update(is_official=False, official_since=None)
        self.message_user(request, f"{queryset.count()} users' official status revoked.")
    revoke_official.short_description = "Revoke official status"

    def verify_expert(self, request, queryset):
        for user in queryset:
            user.is_expert = True
            user.expert_verified_at = timezone.now()
            user.verified_by = request.user
            user.save()
        self.message_user(request, f"{queryset.count()} users verified as experts.")
    verify_expert.short_description = "Verify selected users as experts"

    def revoke_expert(self, request, queryset):
        queryset.update(is_expert=False, expert_verified_at=None, verified_by=None)
        self.message_user(request, f"{queryset.count()} users' expert status revoked.")
    revoke_expert.short_description = "Revoke expert status"

    def verify_instructor(self, request, queryset):
        for user in queryset:
            user.is_culinary_instructor = True
            user.instructor_verified_at = timezone.now()
            user.instructor_verified_by = request.user
            user.save()
        self.message_user(request, f"{queryset.count()} users verified as culinary instructors.")
    verify_instructor.short_description = "Verify selected users as culinary instructors"

    def revoke_instructor(self, request, queryset):
        queryset.update(is_culinary_instructor=False, instructor_verified_at=None, instructor_verified_by=None)
        self.message_user(request, f"{queryset.count()} users' instructor status revoked.")
    revoke_instructor.short_description = "Revoke culinary instructor status"

    def make_mentor(self, request, queryset):
        for user in queryset:
            user.is_mentor = True
            user.mentor_since = timezone.now()
            user.save()
        self.message_user(request, f"{queryset.count()} users set as mentors.")
    make_mentor.short_description = "Make selected users mentors"

    def revoke_mentor(self, request, queryset):
        queryset.update(is_mentor=False, mentor_since=None)
        self.message_user(request, f"{queryset.count()} users' mentor status revoked.")
    revoke_mentor.short_description = "Revoke mentor status"


# ==================== MentorshipRequest Admin ====================

@admin.register(MentorshipRequest)
class MentorshipRequestAdmin(admin.ModelAdmin):
    list_display = (
        'id',
        'mentee_display',
        'mentor_display',
        'status_badge',
        'created_at',
        'responded_at',
    )
    list_filter = ('status', 'created_at', 'responded_at')
    search_fields = (
        'mentee__username', 'mentee__user_id',
        'mentor__username', 'mentor__user_id',
    )
    list_select_related = ('mentee', 'mentor')
    ordering = ('-created_at',)
    list_per_page = 50

    fields = ('mentee', 'mentor', 'status', 'created_at', 'responded_at')
    readonly_fields = ('created_at', 'responded_at')

    actions = [
        'action_mark_accepted',
        'action_mark_declined',
        'action_mark_pending',
        'action_delete_selected',
    ]

    def mentee_display(self, obj):
        return f'{obj.mentee.username} ({obj.mentee.user_id})'
    mentee_display.short_description = 'Mentee'
    mentee_display.admin_order_field = 'mentee__username'

    def mentor_display(self, obj):
        return f'{obj.mentor.username} ({obj.mentor.user_id})'
    mentor_display.short_description = 'Mentor'
    mentor_display.admin_order_field = 'mentor__username'

    def status_badge(self, obj):
        colors = {
            'pending': '#FFB347',
            'accepted': '#00B894',
            'declined': '#E53935',
        }
        color = colors.get(obj.status, '#999')
        return format_html(
            '<span style="background:{};color:white;padding:2px 8px;'
            'border-radius:8px;font-size:11px;">{}</span>',
            color, obj.status,
        )
    status_badge.short_description = 'Status'
    status_badge.admin_order_field = 'status'

    # ---- Actions ----

    def action_mark_accepted(self, request, queryset):
        n = 0
        for req in queryset:
            req.status = MentorshipRequest.Status.ACCEPTED
            req.responded_at = timezone.now()
            req.save(update_fields=['status', 'responded_at'])
            _sync_mentorship_message_text(req)
            n += 1
        self.message_user(request, f'{n} request(s) marked as ACCEPTED (messages synced)')
    action_mark_accepted.short_description = 'Mark selected as ACCEPTED'

    def action_mark_declined(self, request, queryset):
        n = 0
        for req in queryset:
            req.status = MentorshipRequest.Status.DECLINED
            req.responded_at = timezone.now()
            req.save(update_fields=['status', 'responded_at'])
            _sync_mentorship_message_text(req)
            n += 1
        self.message_user(request, f'{n} request(s) marked as DECLINED (messages synced)')
    action_mark_declined.short_description = 'Mark selected as DECLINED'

    def action_mark_pending(self, request, queryset):
        queryset.update(status=MentorshipRequest.Status.PENDING, responded_at=None)
        self.message_user(request, f'{queryset.count()} request(s) reset to PENDING')
    action_mark_pending.short_description = 'Reset selected to PENDING'

    def action_delete_selected(self, request, queryset):
        count = queryset.count()
        queryset.delete()
        self.message_user(request, f'{count} request(s) deleted (relationship removed)')
    action_delete_selected.short_description = 'Delete selected requests (unlink)'

    # ---- Single-object save also syncs the message ----

    def save_model(self, request, obj, form, change):
        """
        When an admin edits a MentorshipRequest from its detail page
        and changes the status, sync the chat message text.
        """
        old_status = None
        if change:
            try:
                old_status = MentorshipRequest.objects.get(pk=obj.pk).status
            except MentorshipRequest.DoesNotExist:
                pass

        super().save_model(request, obj, form, change)

        # Sync the message whenever status became accepted/declined
        # (or transitioned from one terminal state to another).
        if obj.status != MentorshipRequest.Status.PENDING and (
            not change or old_status != obj.status
        ):
            _sync_mentorship_message_text(obj)


# ==================== Message Admin (useful for testing) ====================

@admin.register(Message)
class MessageAdmin(admin.ModelAdmin):
    list_display = (
        'id', 'sender_id', 'receiver_id', 'message_type',
        'short_text', 'related_id', 'is_read', 'created_at',
    )
    list_filter = ('message_type', 'is_read')
    search_fields = ('sender_id', 'receiver_id', 'text', 'related_id')
    ordering = ('-created_at',)
    list_per_page = 50

    def short_text(self, obj):
        return obj.text[:60] + '…' if len(obj.text) > 60 else obj.text
    short_text.short_description = 'text'


# ==================== SystemNotification Admin (useful for testing) ====================

@admin.register(SystemNotification)
class SystemNotificationAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'title', 'notification_type', 'is_read', 'created_at')
    list_filter = ('notification_type', 'is_read')
    search_fields = ('user__username', 'title')
    ordering = ('-created_at',)


# ==================== Existing registrations (unchanged) ====================

admin.site.register(User, CustomUserAdmin)
admin.site.register(UserFollow)
admin.site.register(UserPost)
admin.site.register(UserLike)
admin.site.register(UserComment)
admin.site.register(PointTransaction)