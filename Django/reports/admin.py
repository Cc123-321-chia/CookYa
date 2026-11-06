# reports/admin.py
from django.contrib import admin
from .models import Report


@admin.register(Report)
class ReportAdmin(admin.ModelAdmin):
    list_display = [
        'id', 'post_type', 'post_title', 'reason',
        'status', 'reporter', 'created_at',
    ]
    list_filter = ['status', 'post_type', 'reason', 'created_at']
    search_fields = [
        'post_title', 'post_id', 'reporter__username',
        'post_author_name', 'note',
    ]
    readonly_fields = [
        'id', 'reporter', 'post_type', 'post_id',
        'post_title', 'post_author_id', 'post_author_name',
        'reason', 'note', 'created_at',
    ]
    ordering = ['-created_at']