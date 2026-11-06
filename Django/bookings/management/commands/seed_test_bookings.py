# bookings/management/commands/seed_test_bookings.py
from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.utils import timezone
from datetime import datetime, timedelta
import random

from bookings.models import (
    CookingClass, ClassAvailability, AvailabilitySlot,
    Booking, PaymentCard, RefundRequest, BookingReview,
)

User = get_user_model()


class Command(BaseCommand):
    help = 'Seed 2 completed test bookings for UI demo (review + refund)'

    def handle(self, *args, **options):
        try:
            shop_user = User.objects.get(email='shop@gmail.com')
            normal_user = User.objects.get(email='user@gmail.com')
        except User.DoesNotExist:
            self.stdout.write(self.style.ERROR(
                '❌ Cannot find shop@gmail.com or user@gmail.com'
            ))
            return

        try:
            profile = shop_user.instructor_profile
        except Exception:
            self.stdout.write(self.style.ERROR(
                '❌ shop@gmail.com has no instructor profile'
            ))
            return

        # ---------- 1. Pick (or create) a class ----------
        cls = CookingClass.objects.filter(instructor=profile).first()
        if not cls:
            cls = CookingClass.objects.create(
                instructor=profile,
                title='Demo Thai Cooking Class',
                description='Seeded class for UI demo',
                location='Bangkok',
                price=120,
                class_type='in_person',
                schedule='Daily',
            )
            self.stdout.write(self.style.WARNING(
                f'  Created new class id={cls.id}'
            ))
        else:
            self.stdout.write(self.style.SUCCESS(
                f'  Using existing class id={cls.id} ({cls.title})'
            ))

        # ---------- 2. Ensure availability + slot ----------
        today = timezone.localdate()

        avail = ClassAvailability.objects.filter(
            cooking_class=cls,
            start_date__lte=today - timedelta(days=7),
            end_date__gte=today + timedelta(days=7),
        ).first()

        if not avail:
            avail = ClassAvailability.objects.create(
                cooking_class=cls,
                start_date=today - timedelta(days=30),
                end_date=today + timedelta(days=30),
                is_daily_same=True,
                set_type='weekly',
            )

        slot = avail.slots.first()
        if not slot:
            slot = AvailabilitySlot.objects.create(
                availability=avail,
                day_of_week=None,
                start_time=datetime.strptime('14:00', '%H:%M').time(),
                end_time=datetime.strptime('16:00', '%H:%M').time(),
                max_slots=10,
            )

        self.stdout.write(self.style.SUCCESS(
            f'  Availability id={avail.id}, slot id={slot.id} '
            f'({slot.start_time}-{slot.end_time})'
        ))

        # ---------- 3. Ensure a payment card for normal_user ----------
        card = PaymentCard.objects.filter(user=normal_user, is_default=True).first()
        if not card:
            card = PaymentCard.objects.create(
                user=normal_user,
                brand='visa',
                last4='4242',
                exp_month=12,
                exp_year=2028,
                holder_name='Test User',
                is_default=True,
            )
            self.stdout.write(self.style.SUCCESS(
                f'  Created card ****{card.last4}'
            ))
        else:
            self.stdout.write(self.style.SUCCESS(
                f'  Using existing card ****{card.last4}'
            ))

        # ---------- 4. Clean previous seeded bookings ----------
        Booking.objects.filter(
            user=normal_user,
            cooking_class=cls,
            date__lt=today,
        ).delete()

        # ---------- 5. Booking A — for REVIEW ----------
        date_a = today - timedelta(days=3)
        booking_a = Booking.objects.create(
            user=normal_user,
            cooking_class=cls,
            date=date_a,
            booking_slot=slot,
            start_time=slot.start_time,
            end_time=slot.end_time,
            quantity=2,
            status='completed',
            payment_status='paid',
            paid_at=timezone.now() - timedelta(days=5),
            payment_card=card,
        )

        # ---------- 6. Booking B — for REFUND ----------
        date_b = today - timedelta(days=5)
        booking_b = Booking.objects.create(
            user=normal_user,
            cooking_class=cls,
            date=date_b,
            booking_slot=slot,
            start_time=slot.start_time,
            end_time=slot.end_time,
            quantity=1,
            status='completed',
            payment_status='paid',
            paid_at=timezone.now() - timedelta(days=7),
            payment_card=card,
        )

        # ---------- 7. Output ----------
        self.stdout.write(self.style.SUCCESS(
            '\n'
            '═══════════════════════════════════════════════\n'
            '✅ Seeded 2 completed bookings\n'
            '═══════════════════════════════════════════════\n'
            f'  Class:   {cls.title} (id={cls.id})\n'
            f'  Slot:    {slot.start_time.strftime("%H:%M")} – '
            f'{slot.end_time.strftime("%H:%M")}\n'
            f'  User:    {normal_user.email} (user_id={normal_user.user_id})\n'
            f'  Card:    {card.brand} ****{card.last4}\n'
            '───────────────────────────────────────────────\n'
            f'  Booking A → for REVIEW   (id={booking_a.id}, date={date_a})\n'
            f'  Booking B → for REFUND   (id={booking_b.id}, date={date_b})\n'
            '───────────────────────────────────────────────\n'
            '\n'
            'Now login as user@gmail.com and open My Bookings:\n'
            '  • Booking A → tap "Write a Review"\n'
            '  • Booking B → tap "Request Refund"\n'
            '\n'
            'Then login as shop@gmail.com:\n'
            '  • Messages → CookYa System → Refund notification\n'
            '═══════════════════════════════════════════════\n'
        ))