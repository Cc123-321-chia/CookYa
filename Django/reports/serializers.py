# reports/serializers.py
from rest_framework import serializers
from .models import Report


class ReportCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Report
        fields = ['post_type', 'post_id', 'reason', 'note']

    def validate_post_type(self, value):
        valid = [c[0] for c in Report.PostType.choices]
        if value not in valid:
            raise serializers.ValidationError(f'Must be one of {valid}')
        return value

    def validate_reason(self, value):
        valid = [c[0] for c in Report.Reason.choices]
        if value not in valid:
            raise serializers.ValidationError(f'Must be one of {valid}')
        return value


class ReportSerializer(serializers.ModelSerializer):
    reporter_name = serializers.CharField(
        source='reporter.username', read_only=True
    )
    reviewed_by_name = serializers.CharField(
        source='reviewed_by.username', read_only=True, default=''
    )
    post_detail = serializers.SerializerMethodField()

    class Meta:
        model = Report
        fields = [
            'id', 'reporter', 'reporter_name',
            'post_type', 'post_id', 'post_title',
            'post_author_id', 'post_author_name',
            'reason', 'note', 'status', 'admin_note',
            'reviewed_by', 'reviewed_by_name', 'reviewed_at',
            'created_at',
            'post_detail',
        ]
        read_only_fields = ['id', 'created_at', 'reviewed_at']

    def get_post_detail(self, obj):
        """Return the full content of the reported post so admins can
        review it before deciding keep / remove."""
        request = self.context.get('request')

        def _abs(url):
            if not url:
                return ''
            try:
                if request:
                    return request.build_absolute_uri(url)
                return url
            except Exception:
                return url or ''

        def _tags(value):
            # tags can be a JSON list of strings or a related manager
            if value is None:
                return []
            if hasattr(value, 'all'):
                return [
                    t.name if hasattr(t, 'name') else str(t)
                    for t in value.all()
                ]
            if isinstance(value, list):
                return [
                    (t.get('name') if isinstance(t, dict) else str(t))
                    for t in value
                ]
            return []

        if obj.post_type == 'recipe':
            from recipes.models import Recipe
            try:
                r = Recipe.objects.select_related('author').get(id=obj.post_id)
            except Recipe.DoesNotExist:
                return {'deleted': True}

            return {
                'deleted': False,
                'id': str(r.id),
                'type': 'recipe',
                'title': r.title or '',
                'description': r.description or '',
                'authorName': r.author.username if r.author else '',
                'authorAvatar': _abs(r.author.avatar.url) if r.author and r.author.avatar else '',
                'imageUrl': _abs(r.image_url),
                'photoUrls': [_abs(u) for u in (r.photo_urls or [])],
                'videoUrl': _abs(r.video_url),
                'cuisineType': r.cuisine_type or '',
                'difficultyLevel': (
                    r.get_difficulty_display()
                    if hasattr(r, 'get_difficulty_display') else ''
                ),
                'durationMinutes': r.duration_minutes or 0,
                'tags': _tags(getattr(r, 'tags', None)),
                'ingredients': [
                    {'name': i.name, 'amount': getattr(i, 'amount', '') or ''}
                    for i in (r.ingredients.all() if hasattr(r, 'ingredients') else [])
                ],
                'steps': [
                    {'instruction': getattr(s, 'instruction', '') or '',
                     'note': getattr(s, 'note', '') or ''}
                    for s in (r.steps.all() if hasattr(r, 'steps') else [])
                ],
                'cookingTools': _tags(getattr(r, 'cooking_tools', None)),
                'likes': r.likes.count() if hasattr(r, 'likes') else 0,
                'comments': r.comments_count if hasattr(r, 'comments_count') else 0,
                'createdAt': r.created_at.isoformat() if r.created_at else '',
            }

        if obj.post_type == 'ingredient':
            from ingredients.models import IngredientPost
            try:
                i = IngredientPost.objects.select_related('author').get(id=obj.post_id)
            except IngredientPost.DoesNotExist:
                return {'deleted': True}

            return {
                'deleted': False,
                'id': str(i.id),
                'type': 'ingredient',
                'title': i.title or '',
                'description': i.content or '',
                'authorName': i.author.username if i.author else '',
                'authorAvatar': _abs(i.author.avatar.url) if i.author and i.author.avatar else '',
                'imageUrl': _abs(i.image_url),
                'photoUrls': [_abs(u) for u in (i.photo_urls or [])],
                'videoUrl': _abs(i.video_url),
                'tags': _tags(getattr(i, 'tags', None)),
                'likes': i.likes.count() if hasattr(i, 'likes') else 0,
                'comments': i.comments_count if hasattr(i, 'comments_count') else 0,
                'createdAt': i.created_at.isoformat() if i.created_at else '',
            }

        if obj.post_type == 'comment':
            return {
                'deleted': False,
                'id': str(obj.post_id),
                'type': 'comment',
                'title': obj.post_title or '',
                'description': '',
            }

        return {'deleted': True}