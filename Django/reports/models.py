# reports/models.py
from django.db import models
from django.conf import settings
import uuid

User = settings.AUTH_USER_MODEL


class Report(models.Model):
    """User-submitted reports for recipes/ingredients/comments"""

    class PostType(models.TextChoices):
        RECIPE = 'recipe', 'Recipe'
        INGREDIENT = 'ingredient', 'Ingredient'
        COMMENT = 'comment', 'Comment'

    class Reason(models.TextChoices):
        INAPPROPRIATE = 'inappropriate', 'Inappropriate content'
        SPAM = 'spam', 'Spam / Advertising'
        VIOLENCE = 'violence', 'Violence or dangerous content'
        HARASSMENT = 'harassment', 'Harassment or hate speech'
        COPYRIGHT = 'copyright', 'Copyright violation'
        OTHER = 'other', 'Other'

    class Status(models.TextChoices):
        PENDING = 'pending', 'Pending'
        RESOLVED_KEPT = 'resolved_kept', 'Resolved - Kept'
        RESOLVED_REMOVED = 'resolved_removed', 'Resolved - Removed'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    reporter = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name='reports_made'
    )
    post_type = models.CharField(max_length=20, choices=PostType.choices)
    post_id = models.CharField(max_length=100)
    post_title = models.CharField(max_length=300, blank=True, default='')
    post_author_id = models.CharField(max_length=100, blank=True, default='')
    post_author_name = models.CharField(max_length=200, blank=True, default='')
    reason = models.CharField(max_length=30, choices=Reason.choices)
    note = models.TextField(blank=True, default='')
    status = models.CharField(
        max_length=30, choices=Status.choices, default=Status.PENDING
    )
    admin_note = models.TextField(blank=True, default='')
    reviewed_by = models.ForeignKey(
        User, on_delete=models.SET_NULL,
        null=True, blank=True, related_name='reports_reviewed'
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['status', '-created_at']),
            models.Index(fields=['post_type', 'post_id']),
        ]

    def __str__(self):
        return f'{self.post_type}:{self.post_id} - {self.reason} ({self.status})'