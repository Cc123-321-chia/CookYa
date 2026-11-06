# users/management/commands/recompute_points.py
from django.core.management.base import BaseCommand
from django.db.models import Count
from users.models import User, PointTransaction
from users.point_rules import PointRules


class Command(BaseCommand):
    help = 'Recompute user points from post counts and likes received.'

    def add_arguments(self, parser):
        parser.add_argument('--dry-run', action='store_true')

    def handle(self, *args, **options):
        dry = options['dry_run']
        updated = 0
        for u in User.objects.all():
            base = (
                u.recipe_count * PointRules.POST_RECIPE
                + u.ingredient_count * PointRules.POST_INGREDIENT
                + u.dish_count * PointRules.UPLOAD_DISH
                + u.total_likes_received * PointRules.RECEIVE_LIKE
            )
            if u.points == base:
                continue
            self.stdout.write(
                f"{u.user_id} {u.username}: {u.points} -> {base}"
            )
            if not dry:
                u.points = base
                u.level = u.calculate_level()
                u._sync_roles()
                u.save()
            updated += 1
        self.stdout.write(self.style.SUCCESS(
            f"Done. {updated} users {'would be ' if dry else ''}updated."
        ))