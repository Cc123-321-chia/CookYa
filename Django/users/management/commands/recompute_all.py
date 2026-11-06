# users/management/commands/recompute_all.py
from django.core.management.base import BaseCommand
from django.db.models import Sum
from users.models import User, PointTransaction


class Command(BaseCommand):
    help = 'Recompute points for all users from PointTransaction records.'

    def add_arguments(self, parser):
        parser.add_argument('--dry-run', action='store_true')

    def handle(self, *args, **options):
        dry = options['dry_run']
        updated = 0
        for u in User.objects.all():
            old = u.points
            if dry:
                new = (
                    PointTransaction.objects
                    .filter(user=u)
                    .aggregate(t=Sum('points'))
                    .get('t')
                ) or 0
                new = max(0, new)
            else:
                new = u.recompute_points()
            if new != old:
                self.stdout.write(f"{u.username}: {old} -> {new}")
                updated += 1
        self.stdout.write(self.style.SUCCESS(
            f"Done. {updated} users {'would be ' if dry else ''}updated."
        ))