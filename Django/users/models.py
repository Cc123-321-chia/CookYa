# users/models.py
import random
from django.contrib.auth.hashers import make_password, check_password
from django.db import models
from django.contrib.auth.models import AbstractBaseUser, PermissionsMixin, BaseUserManager
from django.utils import timezone


class UserManager(BaseUserManager):
    def create_user(self, username, email, password=None, **extra_fields):
        if not username:
            raise ValueError('Username is required')
        if not email:
            raise ValueError('Email is required')
        email = self.normalize_email(email)
        user_id = self.generate_user_id()
        user = self.model(user_id=user_id, username=username, email=email, **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(self, username, email, password=None, **extra_fields):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('is_active', True)
        return self.create_user(username, email, password, **extra_fields)

    @staticmethod
    def generate_user_id():
        while True:
            user_id = str(random.randint(10000000, 99999999))
            if not User.objects.filter(user_id=user_id).exists():
                return user_id


class User(AbstractBaseUser, PermissionsMixin):
    user_id = models.CharField(max_length=20, unique=True, editable=False, verbose_name='User ID')
    username = models.CharField(max_length=150, unique=True, verbose_name='Display Name')
    email = models.EmailField(unique=True)
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    date_joined = models.DateTimeField(default=timezone.now)
    last_login = models.DateTimeField(null=True, blank=True)

    # Roles
    is_official = models.BooleanField(default=False)
    official_since = models.DateTimeField(null=True, blank=True)
    is_mentor = models.BooleanField(default=False)
    mentor_since = models.DateTimeField(null=True, blank=True)
    is_expert = models.BooleanField(default=False)
    expert_qualification = models.TextField(blank=True, null=True)
    expert_verified_at = models.DateTimeField(null=True, blank=True)
    verified_by = models.ForeignKey(
        'self', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='verified_experts'
    )
    is_culinary_instructor = models.BooleanField(default=False)
    instructor_qualification = models.TextField(blank=True, null=True)
    instructor_verified_at = models.DateTimeField(null=True, blank=True)
    instructor_verified_by = models.ForeignKey(
        'self', on_delete=models.SET_NULL, null=True, blank=True,
        related_name='verified_instructors'
    )

    # Profile
    avatar = models.ImageField(upload_to='avatars/', null=True, blank=True)
    bio = models.TextField(max_length=500, blank=True)

    # Points / level
    level = models.IntegerField(default=1)
    points = models.IntegerField(default=0)
    last_login_date = models.DateField(null=True, blank=True)
    daily_login_streak = models.IntegerField(default=0)

    # Counters
    recipe_count = models.IntegerField(default=0)
    ingredient_count = models.IntegerField(default=0)
    dish_count = models.IntegerField(default=0)
    total_posts = models.IntegerField(default=0)
    recipe_likes_received = models.IntegerField(default=0)
    ingredient_likes_received = models.IntegerField(default=0)
    dish_likes_received = models.IntegerField(default=0)
    total_likes_received = models.IntegerField(default=0)
    recipe_likes_given = models.IntegerField(default=0)
    ingredient_likes_given = models.IntegerField(default=0)
    dish_likes_given = models.IntegerField(default=0)
    total_likes_given = models.IntegerField(default=0)
    recipe_comments = models.IntegerField(default=0)
    ingredient_comments = models.IntegerField(default=0)
    dish_comments = models.IntegerField(default=0)
    total_comments = models.IntegerField(default=0)

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS = ['username']
    objects = UserManager()

    def __str__(self):
        return self.username

    # ==================== Level / points ====================

    def calculate_level(self):
        thresholds = [0, 100, 250, 450, 700, 1000, 1350, 1750, 2500, 3500, 5000]
        for i, threshold in enumerate(thresholds, 1):
            if self.points < threshold:
                return i - 1 if i > 1 else 1
        return len(thresholds)

    def _sync_roles(self):
        if self.is_official:
            self.is_mentor = False
            return
        from .point_rules import PointRules
        should_be_mentor = self.level >= PointRules.MENTOR_MIN_LEVEL
        if self.is_mentor != should_be_mentor:
            self.is_mentor = should_be_mentor
            self.mentor_since = timezone.now() if should_be_mentor else None

    def recompute_points(self, save=True):
        from django.db.models import Sum
        total = (
            PointTransaction.objects
            .filter(user=self)
            .aggregate(t=Sum('points'))
            .get('t')
        ) or 0
        self.points = max(0, total)
        self.level = self.calculate_level()
        self._sync_roles()
        if save:
            super().save(update_fields=[
                'points', 'level', 'is_mentor', 'mentor_since',
            ])
        return self.points

    def add_points(self, points, reason, related_object=None):
        if points <= 0:
            return
        PointTransaction.objects.create(
            user=self,
            points=points,
            reason=reason,
            related_type=related_object._meta.model_name if related_object else None,
            related_id=str(related_object.id) if related_object else None,
        )
        self.recompute_points()

    def remove_points(self, points, reason, related_object=None, note=None):
        if points <= 0:
            return
        PointTransaction.objects.create(
            user=self,
            points=-points,
            reason=reason,
            related_type=related_object._meta.model_name if related_object else None,
            related_id=str(related_object.id) if related_object else None,
            note=note,
        )
        self.recompute_points()

    # ==================== Role helpers ====================

    def get_active_roles(self):
        if self.is_official:
            return [{'role': 'official', 'name': 'Official', 'icon': 'fa-building'}]
        roles = []
        if self.is_mentor:
            roles.append({'role': 'mentor', 'name': 'Mentor', 'icon': 'fa-graduation-cap'})
        if self.is_expert:
            roles.append({'role': 'expert', 'name': 'Expert', 'icon': 'fa-certificate'})
        if self.is_culinary_instructor:
            roles.append({'role': 'culinary_instructor', 'name': 'Culinary Instructor', 'icon': 'fa-chalkboard-teacher'})
        return roles

    def get_role_display_info(self):
        if self.is_official:
            return {
                'primary_role': 'official', 'primary_name': 'Official',
                'primary_icon': 'fa-building', 'primary_color': 'text-blue-500',
                'all_roles': [{'role': 'official', 'name': 'Official', 'icon': 'fa-building', 'color': 'text-blue-500'}],
                'is_official': True, 'is_mentor': False, 'is_expert': False, 'is_culinary_instructor': False,
            }
        roles = []
        colors = {
            'mentor': 'text-purple-500',
            'expert': 'text-gold-500',
            'culinary_instructor': 'text-green-500',
        }
        if self.is_mentor:
            roles.append({'role': 'mentor', 'name': 'Mentor', 'icon': 'fa-graduation-cap', 'color': colors['mentor']})
        if self.is_expert:
            roles.append({'role': 'expert', 'name': 'Expert', 'icon': 'fa-certificate', 'color': colors['expert']})
        if self.is_culinary_instructor:
            roles.append({'role': 'culinary_instructor', 'name': 'Culinary Instructor', 'icon': 'fa-chalkboard-teacher', 'color': colors['culinary_instructor']})
        if not roles:
            return {
                'primary_role': 'user', 'primary_name': 'Regular User',
                'primary_icon': 'fa-user', 'primary_color': 'text-gray-500',
                'all_roles': [{'role': 'user', 'name': 'Regular User', 'icon': 'fa-user', 'color': 'text-gray-500'}],
                'is_official': False, 'is_mentor': False, 'is_expert': False, 'is_culinary_instructor': False,
            }
        primary = roles[0]
        return {
            'primary_role': primary['role'], 'primary_name': primary['name'],
            'primary_icon': primary['icon'], 'primary_color': primary['color'],
            'all_roles': roles,
            'is_official': False, 'is_mentor': self.is_mentor,
            'is_expert': self.is_expert, 'is_culinary_instructor': self.is_culinary_instructor,
        }

    # ==================== Save ====================

    def save(self, *args, **kwargs):
        if self.is_official:
            self.is_mentor = False
            self.is_expert = False
            self.is_culinary_instructor = False

        self.level = self.calculate_level()
        self._sync_roles()

        self.total_posts = (
            self.recipe_count + self.ingredient_count + self.dish_count
        )
        self.total_likes_received = (
            self.recipe_likes_received
            + self.ingredient_likes_received
            + self.dish_likes_received
        )
        self.total_likes_given = (
            self.recipe_likes_given
            + self.ingredient_likes_given
            + self.dish_likes_given
        )
        self.total_comments = (
            self.recipe_comments + self.ingredient_comments + self.dish_comments
        )
        super().save(*args, **kwargs)


class UserFollow(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='followers')
    follower = models.ForeignKey(User, on_delete=models.CASCADE, related_name='following')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'follower')

    def __str__(self):
        return f"{self.follower.username} follows {self.user.username}"


# ==================== Mentorship ====================

class MentorshipRequest(models.Model):
    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        ACCEPTED = 'accepted', 'Accepted'
        DECLINED = 'declined', 'Declined'

    mentee = models.ForeignKey(
        User, on_delete=models.CASCADE,
        related_name='mentorship_requests_sent'
    )
    mentor = models.ForeignKey(
        User, on_delete=models.CASCADE,
        related_name='mentorship_requests_received'
    )
    status = models.CharField(max_length=20, choices=Status.choices, default=Status.PENDING)
    created_at = models.DateTimeField(auto_now_add=True)
    responded_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['mentee', 'status']),
            models.Index(fields=['mentor', 'status']),
        ]

    def __str__(self):
        return f"{self.mentee.username} → {self.mentor.username} [{self.status}]"


class PointTransaction(models.Model):
    class Reason(models.TextChoices):
        UPLOAD_DISH = 'upload_dish', 'Upload Dish'
        CHEF_LIKE_DISH = 'chef_like_dish', 'Chef Liked Dish'
        RECEIVE_LIKE = 'receive_like', 'Received Like'
        POST_RECIPE = 'post_recipe', 'Posted Recipe'
        POST_INGREDIENT = 'post_ingredient', 'Posted Ingredient'
        DAILY_LOGIN = 'daily_login', 'Daily Login'
        ADMIN_ADJUST = 'admin_adjust', 'Admin Adjust'
        POST_REJECTED = 'post_rejected', 'Post Rejected'

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='point_transactions')
    points = models.IntegerField()
    reason = models.CharField(max_length=50, choices=Reason.choices)
    related_type = models.CharField(max_length=50, null=True, blank=True)
    related_id = models.CharField(max_length=50, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    note = models.TextField(blank=True, null=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', '-created_at']),
            models.Index(fields=['user', 'reason']),
        ]

    def __str__(self):
        return f"{self.user.username}: {self.points} points ({self.reason})"


class UserPost(models.Model):
    class PostType(models.TextChoices):
        RECIPE = 'recipe', 'Recipe'
        INGREDIENT = 'ingredient', 'Ingredient'
        DISH = 'dish', 'Dish'

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='posts')
    post_type = models.CharField(max_length=50, choices=PostType.choices)
    post_id = models.CharField(max_length=50)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'post_type', 'post_id')
        indexes = [
            models.Index(fields=['user', 'post_type']),
            models.Index(fields=['post_type', 'post_id']),
        ]

    def __str__(self):
        return f"{self.user.username} posted {self.post_type} #{self.post_id}"


class UserLike(models.Model):
    class LikeType(models.TextChoices):
        RECIPE = 'recipe', 'Recipe'
        INGREDIENT = 'ingredient', 'Ingredient'
        DISH = 'dish', 'Dish'

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='likes')
    like_type = models.CharField(max_length=20, choices=LikeType.choices)
    post_id = models.CharField(max_length=50)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'like_type', 'post_id')
        indexes = [
            models.Index(fields=['user', 'like_type']),
            models.Index(fields=['like_type', 'post_id']),
        ]

    def __str__(self):
        return f"{self.user.username} liked {self.like_type} #{self.post_id}"


class UserComment(models.Model):
    class CommentType(models.TextChoices):
        RECIPE = 'recipe', 'Recipe'
        INGREDIENT = 'ingredient', 'Ingredient'
        DISH = 'dish', 'Dish'

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='comments')
    comment_type = models.CharField(max_length=20, choices=CommentType.choices)
    post_id = models.CharField(max_length=50)
    comment_id = models.CharField(max_length=50)
    content = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'comment_type', 'post_id', 'comment_id')
        indexes = [
            models.Index(fields=['user', 'comment_type']),
            models.Index(fields=['comment_type', 'post_id']),
        ]

    def __str__(self):
        return f"{self.user.username} commented on {self.comment_type} #{self.post_id}"


class Message(models.Model):
    sender_id = models.CharField(max_length=100, db_index=True)
    receiver_id = models.CharField(max_length=100, db_index=True)
    text = models.TextField(blank=True, default='')
    message_type = models.CharField(max_length=30, default='text')
    media = models.FileField(upload_to='chat_media/', null=True, blank=True)
    sticker_id = models.IntegerField(null=True, blank=True)
    related_id = models.CharField(max_length=100, blank=True, default='')
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)

    class Meta:
        ordering = ['created_at']
        indexes = [
            models.Index(fields=['sender_id', 'receiver_id', 'created_at']),
            models.Index(fields=['receiver_id', 'is_read']),
        ]

    def to_dict(self, request=None):
        media_url = None
        if self.media:
            try:
                media_url = self.media.url
                if request:
                    media_url = request.build_absolute_uri(media_url)
            except Exception:
                media_url = None
        return {
            'id': self.id,
            'sender_id': self.sender_id,
            'receiver_id': self.receiver_id,
            'text': self.text,
            'message_type': self.message_type,
            'media_url': media_url,
            'sticker_id': self.sticker_id,
            'related_id': self.related_id,
            'is_read': self.is_read,
            'created_at': self.created_at.isoformat(),
        }


class SystemNotification(models.Model):
    NOTIFICATION_TYPES = (
        ('post_rejected', 'Post Rejected'),
        ('account_suspended', 'Account Suspended'),
        ('general', 'General'),
        ('refund_request', 'Refund Request'),
        ('refund_update', 'Refund Update'),
        ('refund_resolved', 'Refund Resolved'),
        ('mentorship_accepted', 'Mentorship Accepted'),  # ← Added
        ('mentorship_declined', 'Mentorship Declined'),  # ← Added
    )
    REJECT_REASONS = (
        ('violation', 'Violation (Violence / Sexual / Prohibited)'),
        ('unrelated', 'Unrelated to Cooking'),
        ('wrong_category', 'Wrong Category'),
        ('other', 'Other'),
    )

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='system_notifications')
    title = models.CharField(max_length=200)
    content = models.TextField()
    notification_type = models.CharField(max_length=50, choices=NOTIFICATION_TYPES, default='general')
    reject_reason = models.CharField(max_length=30, choices=REJECT_REASONS, blank=True, null=True)
    post_type = models.CharField(max_length=20, blank=True, null=True)
    post_id = models.CharField(max_length=50, blank=True, null=True)
    is_read = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['user', '-created_at']),
            models.Index(fields=['user', 'is_read']),
        ]

    def __str__(self):
        return f"[{self.notification_type}] {self.title} → {self.user.username}"


class AdminUser(models.Model):
    ROLE_CHOICES = (
        ('super_admin', 'Super Admin'),
        ('moderator', 'Moderator'),
    )
    admin_id = models.CharField(max_length=20, unique=True, editable=False)
    name = models.CharField(max_length=100)
    email = models.EmailField(unique=True)
    password = models.CharField(max_length=200)
    role = models.CharField(max_length=20, choices=ROLE_CHOICES, default='moderator')
    is_active = models.BooleanField(default=True)
    last_login = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def set_password(self, raw_password):
        self.password = make_password(raw_password)

    def check_password(self, raw_password):
        return check_password(raw_password, self.password)

    def save(self, *args, **kwargs):
        if not self.admin_id:
            while True:
                new_id = str(random.randint(10000000, 99999999))
                if not AdminUser.objects.filter(admin_id=new_id).exists():
                    self.admin_id = new_id
                    break
        super().save(*args, **kwargs)

    def __str__(self):
        return f"{self.name} ({self.email})"


class Sticker(models.Model):
    name = models.CharField(max_length=100)
    image = models.ImageField(upload_to='stickers/', null=True, blank=True)
    image_url = models.URLField(blank=True, null=True)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return self.name


class CallRoom(models.Model):
    room_id = models.CharField(max_length=64, unique=True, db_index=True)
    caller_id = models.CharField(max_length=100)
    receiver_id = models.CharField(max_length=100)
    call_type = models.CharField(max_length=20, default='video')
    caller_peer_id = models.CharField(max_length=100, blank=True, default='')
    is_active = models.BooleanField(default=True)
    duration_seconds = models.IntegerField(default=0)
    ended_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.room_id} ({self.caller_id} -> {self.receiver_id})"

# ==================== Chat Clear History ====================

class ChatClearRecord(models.Model):
    """
    Records the last time a user cleared their chat history with someone.

    WeChat-style behavior:
    - Only the user who clears loses visibility of old messages.
    - The other user still sees the full conversation.
    - The actual Message rows are NOT deleted, because the other side
      still needs them. Query filters by `cleared_at` instead.
    """
    user = models.ForeignKey(
        User,
        on_delete=models.CASCADE,
        related_name='chat_clears',
    )
    other_user_id = models.CharField(max_length=100)
    cleared_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('user', 'other_user_id')
        indexes = [
            models.Index(fields=['user', 'other_user_id']),
        ]

    def __str__(self):
        return f"{self.user.username} cleared chat with {self.other_user_id} @ {self.cleared_at}"