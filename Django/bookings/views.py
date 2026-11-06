from rest_framework import status
from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.permissions import IsAuthenticated, AllowAny, IsAdminUser
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from django.utils import timezone
from django.db import models as django_models
from django.db import transaction
from datetime import datetime, timedelta
import json
from .models import (
    CulinaryInstructorProfile, InstructorShopPhoto, CookingClass,
    CookingClassImage, CookingClassVideo, ClassAvailability, AvailabilitySlot,
    SavedClass, Booking, BookingReview, PaymentCard, RefundRequest,
)
from .serializers import (
    CulinaryInstructorProfileSerializer, CookingClassSerializer,
    BookingSerializer, BookingReviewSerializer,
    ClassAvailabilitySerializer, InstructorApplicationAdminSerializer,
    PaymentCardSerializer, PaymentCardCreateSerializer,
    ClassCreateSerializer, RefundRequestSerializer,
)


def is_culinary_instructor(user):
    return user.is_authenticated and user.is_culinary_instructor


def _slot_booked_count_for_date(slot, date, exclude_booking_id=None):
    """Only paid bookings on a SPECIFIC DATE occupy seats."""
    qs = Booking.objects.filter(
        booking_slot=slot,
        date=date,
        payment_status='paid',
        status__in=['pending', 'confirmed', 'completed'],
    )
    if exclude_booking_id:
        qs = qs.exclude(id=exclude_booking_id)
    return qs.aggregate(total=django_models.Sum('quantity'))['total'] or 0


def _class_cutoff_datetime(booking):
    """Cancel cutoff = booking.date at 00:00:00 (local)."""
    return timezone.make_aware(
        datetime.combine(booking.date, datetime.min.time())
    )


def _class_end_datetime(booking):
    """End of the booked class."""
    if booking.end_time is not None:
        return timezone.make_aware(
            datetime.combine(booking.date, booking.end_time)
        )
    return timezone.make_aware(
        datetime.combine(booking.date, datetime.max.time())
    )


def _notify(user, title, content, notification_type='general',
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
        print(f'_notify error: {e}')


def _auto_resolve_overdue_refunds():
    """Lazily auto-resolve refunds whose instructor 24h deadline has passed.
    Auto resolution = FULL REFUND to the user.
    """
    now = timezone.now()
    overdue = RefundRequest.objects.select_related(
        'booking__cooking_class__instructor__user', 'user'
    ).filter(
        status=RefundRequest.Status.PENDING_INSTRUCTOR,
        instructor_responded_at__isnull=True,
        deadline__lt=now,
    )
    for refund in overdue:
        booking = refund.booking
        total = float(booking.cooking_class.price) * booking.quantity

        refund.status = RefundRequest.Status.RESOLVED_FULL
        refund.refund_amount = total
        refund.admin_decision_amount = 'full'
        refund.admin_note = (
            'Instructor did not respond within 24 hours. '
            'Automatic full refund issued.'
        )
        refund.admin_resolved_at = now
        refund.save()

        booking.payment_status = 'refunded'
        booking.save()

        # Notify user
        _notify(
            refund.user,
            title='Full Refund Approved',
            content=(
                f'Your refund request for "{booking.cooking_class.title}" '
                f'has been approved automatically. RM {total:.2f} will be '
                f'refunded to your card.'
            ),
            notification_type='refund_resolved',
            post_type='refund',
            post_id=str(refund.id),
        )
        # Notify instructor
        try:
            _notify(
                booking.cooking_class.instructor.user,
                title='Refund Auto-Resolved',
                content=(
                    f'The refund for "{booking.cooking_class.title}" was '
                    f'auto-resolved (full refund) because you did not respond '
                    f'within 24 hours.'
                ),
                notification_type='refund_resolved',
                post_type='refund',
                post_id=str(refund.id),
            )
        except Exception:
            pass


# ==================== 浏览 Classes ====================

@api_view(['GET'])
@permission_classes([AllowAny])
def list_classes(request):
    classes = CookingClass.objects.select_related('instructor').filter(
        is_active=True
    ).order_by('-created_at')
    serializer = CookingClassSerializer(classes, many=True, context={'request': request})
    return Response({'success': True, 'data': serializer.data})


@api_view(['GET'])
@permission_classes([AllowAny])
def class_detail(request, class_id):
    try:
        cls = CookingClass.objects.select_related('instructor').get(id=class_id)
    except CookingClass.DoesNotExist:
        return Response({'success': False, 'error': 'Class not found'}, status=404)
    serializer = CookingClassSerializer(cls, context={'request': request})
    return Response({'success': True, 'data': serializer.data})


# ==================== Save ====================

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def toggle_save(request, class_id):
    try:
        cls = CookingClass.objects.get(id=class_id)
    except CookingClass.DoesNotExist:
        return Response({'success': False, 'error': 'Class not found'}, status=404)

    saved = SavedClass.objects.filter(user=request.user, cooking_class=cls)
    if saved.exists():
        saved.delete()
        return Response({'success': True, 'saved': False})
    SavedClass.objects.create(user=request.user, cooking_class=cls)
    return Response({'success': True, 'saved': True})


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def my_saved_classes(request):
    saved = SavedClass.objects.filter(user=request.user).select_related('cooking_class__instructor')
    classes = [s.cooking_class for s in saved]
    serializer = CookingClassSerializer(classes, many=True, context={'request': request})
    return Response({'success': True, 'data': serializer.data})


# ==================== 某天的时段 ====================

@api_view(['GET'])
@permission_classes([AllowAny])
def class_day_slots(request, class_id):
    date_str = request.query_params.get('date')
    if not date_str:
        return Response({'success': False, 'error': 'date is required'}, status=400)

    try:
        date = datetime.strptime(date_str, '%Y-%m-%d').date()
    except ValueError:
        return Response({'success': False, 'error': 'Invalid date'}, status=400)

    try:
        cls = CookingClass.objects.get(id=class_id)
    except CookingClass.DoesNotExist:
        return Response({'success': False, 'error': 'Class not found'}, status=404)

    avail = cls.availabilities.filter(start_date__lte=date, end_date__gte=date).first()
    if not avail:
        return Response({'success': True, 'data': []})

    day_of_week = date.weekday()

    slots = avail.slots.all()
    if not avail.is_daily_same:
        slots = slots.filter(day_of_week=day_of_week)

    now = timezone.localtime()

    result = []
    for slot in slots:
        booked = _slot_booked_count_for_date(slot, date)
        remaining = max(slot.max_slots - booked, 0)

        slot_started = False
        if date < now.date():
            slot_started = True
        elif date == now.date():
            slot_start_dt = timezone.make_aware(
                datetime.combine(date, slot.start_time)
            )
            slot_started = now >= slot_start_dt

        result.append({
            'id': slot.id,
            'start_time': slot.start_time.strftime('%H:%M'),
            'end_time': slot.end_time.strftime('%H:%M'),
            'max_slots': slot.max_slots,
            'remaining': remaining,
            'started': slot_started,
        })

    return Response({'success': True, 'data': result})


@api_view(['GET'])
@permission_classes([AllowAny])
def class_week_overview(request, class_id):
    start_str = request.query_params.get('start')
    if not start_str:
        return Response({'success': False, 'error': 'start is required'}, status=400)

    try:
        start_date = datetime.strptime(start_str, '%Y-%m-%d').date()
    except ValueError:
        return Response({'success': False, 'error': 'Invalid date'}, status=400)

    try:
        cls = CookingClass.objects.get(id=class_id)
    except CookingClass.DoesNotExist:
        return Response({'success': False, 'error': 'Class not found'}, status=404)

    result = []
    for i in range(14):
        d = start_date + timezone.timedelta(days=i)
        avail = cls.availabilities.filter(start_date__lte=d, end_date__gte=d).first()

        total_remaining = 0
        if avail:
            slots = avail.slots.all()
            if not avail.is_daily_same:
                slots = slots.filter(day_of_week=d.weekday())

            for slot in slots:
                booked = _slot_booked_count_for_date(slot, d)
                total_remaining += max(slot.max_slots - booked, 0)

        result.append({
            'date': d.strftime('%Y-%m-%d'),
            'remaining': total_remaining,
        })

    return Response({'success': True, 'data': result})


@api_view(['GET'])
@permission_classes([AllowAny])
def class_month_overview(request, class_id):
    year_str = request.query_params.get('year')
    month_str = request.query_params.get('month')
    if not year_str or not month_str:
        return Response(
            {'success': False, 'error': 'year and month are required'},
            status=400,
        )

    try:
        year = int(year_str)
        month = int(month_str)
        if month < 1 or month > 12:
            raise ValueError
    except (TypeError, ValueError):
        return Response(
            {'success': False, 'error': 'Invalid year or month'},
            status=400,
        )

    try:
        cls = CookingClass.objects.get(id=class_id)
    except CookingClass.DoesNotExist:
        return Response(
            {'success': False, 'error': 'Class not found'},
            status=404,
        )

    from calendar import monthrange
    _, days_in_month = monthrange(year, month)

    result = []
    for day in range(1, days_in_month + 1):
        try:
            d = datetime(year, month, day).date()
        except ValueError:
            continue

        avail = cls.availabilities.filter(
            start_date__lte=d, end_date__gte=d
        ).first()

        total_remaining = 0
        if avail:
            slots = avail.slots.all()
            if not avail.is_daily_same:
                slots = slots.filter(day_of_week=d.weekday())
            for slot in slots:
                booked = _slot_booked_count_for_date(slot, d)
                total_remaining += max(slot.max_slots - booked, 0)

        result.append({
            'date': d.strftime('%Y-%m-%d'),
            'remaining': total_remaining,
        })

    return Response({'success': True, 'data': result})


# ==================== Book ====================

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def create_booking(request, class_id):
    if request.user.is_culinary_instructor:
        return Response({
            'success': False,
            'error': "Instructors can't book classes"
        }, status=403)

    try:
        cls = CookingClass.objects.get(id=class_id)
    except CookingClass.DoesNotExist:
        return Response({'success': False, 'error': 'Class not found'}, status=404)

    date_str = request.data.get('date')
    slot_id = request.data.get('slot_id')
    quantity = request.data.get('quantity', 1)

    if not date_str:
        return Response({'success': False, 'error': 'Date is required'}, status=400)
    if not slot_id:
        return Response({'success': False, 'error': 'slot_id is required'}, status=400)

    try:
        quantity = int(quantity)
        if quantity < 1:
            raise ValueError
    except (TypeError, ValueError):
        return Response({'success': False, 'error': 'quantity must be >= 1'}, status=400)

    try:
        date = datetime.strptime(date_str, '%Y-%m-%d').date()
    except ValueError:
        return Response({'success': False, 'error': 'Invalid date'}, status=400)

    try:
        slot = AvailabilitySlot.objects.get(id=slot_id, availability__cooking_class=cls)
    except AvailabilitySlot.DoesNotExist:
        return Response({'success': False, 'error': 'Slot not found'}, status=404)

    avail = slot.availability
    if not (avail.start_date <= date <= avail.end_date):
        return Response({'success': False, 'error': 'Date not in availability range'}, status=400)

    if not avail.is_daily_same and slot.day_of_week != date.weekday():
        return Response({'success': False, 'error': 'Slot not available on this day'}, status=400)

    now = timezone.localtime()
    if date < now.date():
        return Response({'success': False, 'error': 'This date has passed'}, status=400)

    if date == now.date():
        slot_start_dt = timezone.make_aware(
            datetime.combine(date, slot.start_time)
        )
        if now >= slot_start_dt:
            return Response({
                'success': False,
                'error': 'This time slot has already started'
            }, status=400)

    booked = _slot_booked_count_for_date(slot, date)
    remaining = slot.max_slots - booked
    if quantity > remaining:
        return Response({
            'success': False,
            'error': f'Only {remaining} slot(s) left',
            'remaining': remaining
        }, status=400)

    Booking.objects.filter(
        user=request.user,
        cooking_class=cls,
        booking_slot=slot,
        payment_status='unpaid',
        status='pending',
    ).update(status='cancelled', cancelled_at=timezone.now())

    booking = Booking.objects.create(
        user=request.user,
        cooking_class=cls,
        date=date,
        booking_slot=slot,
        start_time=slot.start_time,
        end_time=slot.end_time,
        quantity=quantity,
        status='pending',
        payment_status='unpaid',
    )

    serializer = BookingSerializer(booking, context={'request': request})
    return Response({'success': True, 'data': serializer.data}, status=201)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def my_bookings(request):
    bookings = Booking.objects.filter(
        user=request.user,
    ).exclude(
        payment_status='unpaid',
        status='cancelled',
    ).select_related(
        'cooking_class__instructor'
    ).order_by('-created_at')
    serializer = BookingSerializer(bookings, many=True, context={'request': request})
    return Response({'success': True, 'data': serializer.data})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def cancel_booking(request, booking_id):
    """User cancels their own booking.
    - Allowed only before booking.date at 00:00:00 (class start).
    - Full refund.
    - Notifies the instructor.
    """
    try:
        booking = Booking.objects.select_related(
            'cooking_class__instructor__user'
        ).get(id=booking_id, user=request.user)
    except Booking.DoesNotExist:
        return Response({'success': False, 'error': 'Booking not found'}, status=404)

    if booking.status not in ('pending', 'confirmed'):
        return Response({
            'success': False,
            'error': f'Cannot cancel a {booking.status} booking'
        }, status=400)

    now = timezone.now()
    if now >= _class_cutoff_datetime(booking):
        return Response({
            'success': False,
            'error': (
                'You can no longer cancel. Cancellation is closed on the '
                'class day. If the class has finished, use Confirm Completed '
                'instead.'
            )
        }, status=400)

    booking.status = 'cancelled'
    booking.cancelled_at = now
    if booking.payment_status == 'paid':
        booking.payment_status = 'refunded'
    booking.save()

    # Notify the instructor
    try:
        instructor_user = booking.cooking_class.instructor.user
        _notify(
            instructor_user,
            title='Booking Cancelled',
            content=(
                f'{request.user.username} cancelled their booking for '
                f'"{booking.cooking_class.title}" on {booking.date}. '
                f'The customer has been fully refunded.'
            ),
            notification_type='booking_cancelled',
            post_type='booking',
            post_id=str(booking.id),
        )
    except Exception:
        pass

    return Response({'success': True, 'message': 'Booking cancelled'})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def cancel_unpaid_booking(request, booking_id):
    """Cancel an unpaid booking immediately (payment screen exit)."""
    try:
        booking = Booking.objects.get(id=booking_id, user=request.user)
    except Booking.DoesNotExist:
        return Response(
            {'success': False, 'error': 'Booking not found'},
            status=404,
        )

    if booking.payment_status == 'paid':
        return Response({
            'success': False,
            'error': 'Cannot cancel a paid booking via this endpoint',
        }, status=400)

    if booking.status == 'cancelled':
        return Response({'success': True, 'message': 'Already cancelled'})

    booking.status = 'cancelled'
    booking.cancelled_at = timezone.now()
    booking.save()

    return Response({'success': True, 'message': 'Booking cancelled'})


# ==================== Payment Cards ====================

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def payment_cards(request):
    if request.method == 'GET':
        cards = PaymentCard.objects.filter(user=request.user)
        serializer = PaymentCardSerializer(cards, many=True)
        return Response({'success': True, 'data': serializer.data})

    serializer = PaymentCardCreateSerializer(
        data=request.data,
        context={'request': request}
    )
    if not serializer.is_valid():
        return Response({'success': False, 'error': serializer.errors}, status=400)

    card = serializer.save()
    return Response({
        'success': True,
        'data': PaymentCardSerializer(card).data
    }, status=201)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_payment_card(request, card_id):
    try:
        card = PaymentCard.objects.get(id=card_id, user=request.user)
    except PaymentCard.DoesNotExist:
        return Response({'success': False, 'error': 'Card not found'}, status=404)

    was_default = card.is_default
    card.delete()

    if was_default:
        next_card = PaymentCard.objects.filter(user=request.user).first()
        if next_card:
            next_card.is_default = True
            next_card.save()

    return Response({'success': True, 'message': 'Card deleted'})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def set_default_payment_card(request, card_id):
    try:
        card = PaymentCard.objects.get(id=card_id, user=request.user)
    except PaymentCard.DoesNotExist:
        return Response({'success': False, 'error': 'Card not found'}, status=404)

    PaymentCard.objects.filter(user=request.user).update(is_default=False)
    card.is_default = True
    card.save()

    return Response({'success': True, 'message': 'Default card updated'})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def pay_booking(request, booking_id):
    card_id = request.data.get('card_id')
    if not card_id:
        return Response(
            {'success': False, 'error': 'card_id is required'},
            status=400,
        )

    try:
        with transaction.atomic():
            try:
                booking = Booking.objects.select_for_update().get(
                    id=booking_id, user=request.user
                )
            except Booking.DoesNotExist:
                return Response(
                    {'success': False, 'error': 'Booking not found'},
                    status=404,
                )

            if booking.payment_status == 'paid':
                return Response(
                    {'success': False, 'error': 'Already paid'},
                    status=400,
                )

            if booking.status == 'cancelled':
                return Response(
                    {'success': False, 'error': 'This booking was cancelled'},
                    status=400,
                )

            try:
                card = PaymentCard.objects.get(
                    id=card_id, user=request.user
                )
            except PaymentCard.DoesNotExist:
                return Response(
                    {'success': False, 'error': 'Card not found'},
                    status=404,
                )

            if booking.booking_slot_id:
                slot = AvailabilitySlot.objects.select_for_update().get(
                    id=booking.booking_slot_id
                )

                booked = Booking.objects.filter(
                    booking_slot=slot,
                    date=booking.date,
                    payment_status='paid',
                    status__in=['pending', 'confirmed', 'completed'],
                ).exclude(id=booking.id).aggregate(
                    total=django_models.Sum('quantity')
                )['total'] or 0

                remaining = slot.max_slots - booked
                if booking.quantity > remaining:
                    return Response({
                        'success': False,
                        'error': (
                            f'This slot was just taken by another user. '
                            f'Only {remaining} seat(s) left.'
                        ),
                        'remaining': remaining,
                    }, status=400)

            booking.payment_card = card
            booking.payment_status = 'paid'
            booking.paid_at = timezone.now()
            booking.status = 'confirmed'
            booking.save()

    except Exception as e:
        return Response(
            {'success': False, 'error': f'Payment failed: {str(e)}'},
            status=500,
        )

    serializer = BookingSerializer(booking, context={'request': request})
    return Response({'success': True, 'data': serializer.data})


# ==================== Instructor: Classes CRUD ====================

@api_view(['POST'])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def create_class(request):
    if not is_culinary_instructor(request.user):
        return Response({'success': False, 'error': 'Not an instructor'}, status=403)

    profile = request.user.instructor_profile
    data = request.data

    cls = CookingClass.objects.create(
        instructor=profile,
        title=data.get('title', ''),
        description=data.get('description', ''),
        location=data.get('location', ''),
        price=data.get('price', 0),
        class_type=data.get('class_type', 'in_person'),
        schedule=data.get('schedule', ''),
        is_active=True,
    )

    if 'image' in request.FILES:
        cls.image = request.FILES['image']
        cls.save()

    if 'cover_video' in request.FILES:
        cls.cover_video = request.FILES['cover_video']
        cls.save()

    for f in request.FILES.getlist('images'):
        CookingClassImage.objects.create(cooking_class=cls, image=f)

    for f in request.FILES.getlist('videos'):
        CookingClassVideo.objects.create(cooking_class=cls, video=f)

    def parse_list(key):
        val = data.get(key)
        if not val:
            return []
        if isinstance(val, list):
            return val
        try:
            return json.loads(val)
        except Exception:
            return []

    cls.tags = parse_list('tags')
    cls.dishes = parse_list('dishes')
    cls.certificates = parse_list('certificates')
    cls.save()

    serializer = CookingClassSerializer(cls, context={'request': request})
    return Response({'success': True, 'data': serializer.data}, status=201)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def update_class(request, class_id):
    if not is_culinary_instructor(request.user):
        return Response({'success': False, 'error': 'Not an instructor'}, status=403)

    try:
        cls = CookingClass.objects.get(id=class_id, instructor=request.user.instructor_profile)
    except CookingClass.DoesNotExist:
        return Response({'success': False, 'error': 'Class not found'}, status=404)

    data = request.data

    cls.title = data.get('title', cls.title)
    cls.description = data.get('description', cls.description)
    cls.location = data.get('location', cls.location)
    cls.price = data.get('price', cls.price)
    cls.class_type = data.get('class_type', cls.class_type)
    cls.schedule = data.get('schedule', cls.schedule)

    if 'image' in request.FILES:
        cls.image = request.FILES['image']
    if 'cover_video' in request.FILES:
        cls.cover_video = request.FILES['cover_video']

    cls.save()

    def parse_list(key):
        val = data.get(key)
        if not val:
            return None
        if isinstance(val, list):
            return val
        try:
            return json.loads(val)
        except Exception:
            return None

    tags = parse_list('tags')
    if tags is not None:
        cls.tags = tags
    dishes = parse_list('dishes')
    if dishes is not None:
        cls.dishes = dishes
    certs = parse_list('certificates')
    if certs is not None:
        cls.certificates = certs
    cls.save()

    for f in request.FILES.getlist('new_images'):
        CookingClassImage.objects.create(cooking_class=cls, image=f)

    for f in request.FILES.getlist('new_videos'):
        CookingClassVideo.objects.create(cooking_class=cls, video=f)

    serializer = CookingClassSerializer(cls, context={'request': request})
    return Response({'success': True, 'data': serializer.data})


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_class(request, class_id):
    if not is_culinary_instructor(request.user):
        return Response({'success': False, 'error': 'Not an instructor'}, status=403)

    try:
        cls = CookingClass.objects.get(id=class_id, instructor=request.user.instructor_profile)
    except CookingClass.DoesNotExist:
        return Response({'success': False, 'error': 'Class not found'}, status=404)

    today = timezone.localdate()
    future_bookings = Booking.objects.filter(
        cooking_class=cls,
        date__gte=today,
        status__in=['pending', 'confirmed']
    )

    if future_bookings.exists() and request.data.get('force') != True:
        return Response({
            'success': False,
            'error': f'There are {future_bookings.count()} upcoming booking(s). Deleting will cancel them.',
            'bookings_count': future_bookings.count(),
        }, status=400)

    for b in future_bookings:
        b.status = 'cancelled'
        b.cancelled_at = timezone.now()
        if b.payment_status == 'paid':
            b.payment_status = 'refunded'
        b.save()

    cls.delete()
    return Response({'success': True, 'message': 'Class deleted'})


# ==================== Instructor Orders ====================

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def instructor_orders(request):
    if not is_culinary_instructor(request.user):
        return Response({'success': False, 'error': 'Not an instructor'}, status=403)

    _auto_resolve_overdue_refunds()

    profile = request.user.instructor_profile
    bookings = Booking.objects.filter(
        cooking_class__instructor=profile
    ).select_related('user', 'cooking_class').order_by('-created_at')

    serializer = BookingSerializer(bookings, many=True, context={'request': request})
    return Response({'success': True, 'data': serializer.data})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def instructor_cancel_booking(request, booking_id):
    """Instructor cancels (rejects) a user's booking.
    Allowed before the class day 00:00 cutoff.
    Full refund + notification to user.
    """
    if not is_culinary_instructor(request.user):
        return Response({'success': False, 'error': 'Not an instructor'}, status=403)

    try:
        booking = Booking.objects.select_related(
            'cooking_class__instructor', 'user'
        ).get(
            id=booking_id,
            cooking_class__instructor=request.user.instructor_profile,
        )
    except Booking.DoesNotExist:
        return Response({'success': False, 'error': 'Booking not found'}, status=404)

    if booking.status not in ('pending', 'confirmed'):
        return Response({
            'success': False,
            'error': f'Cannot cancel a {booking.status} booking'
        }, status=400)

    now = timezone.now()
    if now >= _class_cutoff_datetime(booking):
        return Response({
            'success': False,
            'error': 'Cannot cancel on or after the class day.'
        }, status=400)

    booking.status = 'cancelled'
    booking.cancelled_at = now
    was_paid = booking.payment_status == 'paid'
    if was_paid:
        booking.payment_status = 'refunded'
    booking.save()

    # Notify the user
    _notify(
        booking.user,
        title='Booking Cancelled by Instructor',
        content=(
            f'The instructor cancelled your booking for '
            f'"{booking.cooking_class.title}" on {booking.date}. '
            + ('A full refund has been issued.' if was_paid else '')
        ),
        notification_type='booking_cancelled',
        post_type='booking',
        post_id=str(booking.id),
    )

    serializer = BookingSerializer(booking, context={'request': request})
    return Response({'success': True, 'data': serializer.data})


# ==================== Review ====================

def _recalc_class_rating(class_id):
    from django.db.models import Avg

    avg = BookingReview.objects.filter(
        booking__cooking_class_id=class_id
    ).aggregate(avg=Avg('rating'))['avg']

    CookingClass.objects.filter(id=class_id).update(
        rating=round(float(avg), 1) if avg is not None else 0
    )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def create_review(request, booking_id):
    try:
        booking = Booking.objects.get(id=booking_id, user=request.user)
    except Booking.DoesNotExist:
        return Response(
            {'success': False, 'error': 'Booking not found'},
            status=404,
        )

    if hasattr(booking, 'review'):
        return Response(
            {'success': False, 'error': 'Already reviewed'},
            status=400,
        )

    if booking.status != 'completed':
        return Response(
            {'success': False,
             'error': 'You can only review after the class is marked completed'},
            status=400,
        )

    rating = request.data.get('rating')
    comment = request.data.get('comment', '')
    image = request.FILES.get('image')

    if not rating:
        return Response(
            {'success': False, 'error': 'Rating required'},
            status=400,
        )

    try:
        rating_int = int(rating)
        if rating_int < 1 or rating_int > 5:
            raise ValueError
    except (TypeError, ValueError):
        return Response(
            {'success': False, 'error': 'Rating must be 1-5'},
            status=400,
        )

    review = BookingReview.objects.create(
        booking=booking,
        rating=rating_int,
        comment=comment,
        image=image,
    )

    _recalc_class_rating(booking.cooking_class_id)

    serializer = BookingReviewSerializer(review, context={'request': request})
    return Response({'success': True, 'data': serializer.data}, status=201)


@api_view(['GET'])
@permission_classes([AllowAny])
def class_reviews(request, class_id):
    reviews = BookingReview.objects.filter(
        booking__cooking_class_id=class_id
    ).select_related('booking__user').order_by('-created_at')

    filter_type = request.query_params.get('filter', 'all')
    if filter_type == 'image':
        reviews = reviews.exclude(image='')

    serializer = BookingReviewSerializer(reviews, many=True, context={'request': request})
    return Response({'success': True, 'data': serializer.data})


# ==================== Instructor Profile ====================

@api_view(['GET'])
@permission_classes([IsAuthenticated])
def my_instructor_profile(request):
    if not is_culinary_instructor(request.user):
        return Response({'success': False, 'error': 'Not an instructor'}, status=403)

    profile = request.user.instructor_profile
    serializer = CulinaryInstructorProfileSerializer(profile, context={'request': request})
    return Response({'success': True, 'data': serializer.data})


@api_view(['GET'])
@permission_classes([AllowAny])
def instructor_profile_detail(request, instructor_id):
    try:
        profile = CulinaryInstructorProfile.objects.get(id=instructor_id)
    except CulinaryInstructorProfile.DoesNotExist:
        return Response({'success': False, 'error': 'Instructor not found'}, status=404)

    serializer = CulinaryInstructorProfileSerializer(profile, context={'request': request})
    classes = CookingClass.objects.filter(instructor=profile, is_active=True)
    class_serializer = CookingClassSerializer(classes, many=True, context={'request': request})

    return Response({
        'success': True,
        'data': {
            'profile': serializer.data,
            'classes': class_serializer.data,
        }
    })


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def apply_instructor(request):
    if request.user.is_culinary_instructor:
        return Response({'success': False, 'error': 'Already an instructor'}, status=400)

    data = request.data
    profile, created = CulinaryInstructorProfile.objects.get_or_create(
        user=request.user,
        defaults={
            'shop_name': data.get('shop_name', ''),
            'description': data.get('description', ''),
            'address': data.get('address', ''),
            'phone': data.get('phone', ''),
            'email': data.get('email', ''),
        }
    )

    if not created:
        profile.shop_name = data.get('shop_name', profile.shop_name)
        profile.description = data.get('description', profile.description)
        profile.address = data.get('address', profile.address)
        profile.phone = data.get('phone', profile.phone)
        profile.email = data.get('email', profile.email)

    for field in ['avatar', 'cover_photo', 'business_license', 'food_license',
                  'health_certificate', 'chef_certification', 'insurance',
                  'food_safety_certificate']:
        if field in request.FILES:
            setattr(profile, field, request.FILES[field])

    profile.class_title = data.get('class_title', '')
    profile.class_description = data.get('class_description', '')
    profile.price = data.get('price', '')
    profile.schedule = data.get('schedule', '')

    def parse_list(key):
        val = data.get(key)
        if not val:
            return []
        if isinstance(val, list):
            return val
        try:
            return json.loads(val)
        except Exception:
            return []

    profile.tags = parse_list('tags')
    profile.dishes = parse_list('dishes')
    profile.certificates = parse_list('certificates')

    profile.status = 'pending'
    profile.is_approved = False
    profile.reject_reason = None
    profile.save()

    photos = request.FILES.getlist('shop_photos')
    for photo in photos:
        InstructorShopPhoto.objects.create(instructor=profile, image=photo)

    return Response({'success': True, 'message': 'Application submitted'})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def edit_instructor_profile(request):
    if not is_culinary_instructor(request.user):
        return Response(
            {'success': False, 'error': 'Not an instructor'},
            status=403,
        )

    profile = request.user.instructor_profile
    data = request.data

    profile.shop_name = data.get('shop_name', profile.shop_name)
    profile.description = data.get('description', profile.description)
    profile.address = data.get('address', profile.address)
    profile.phone = data.get('phone', profile.phone)
    profile.email = data.get('email', profile.email)

    if 'avatar' in request.FILES:
        profile.avatar = request.FILES['avatar']
    if 'cover_photo' in request.FILES:
        profile.cover_photo = request.FILES['cover_photo']

    if 'class_title' in data:
        profile.class_title = data.get('class_title', '') or ''
    if 'class_description' in data:
        profile.class_description = data.get('class_description', '') or ''
    if 'price' in data:
        profile.price = data.get('price', '') or ''
    if 'schedule' in data:
        profile.schedule = data.get('schedule', '') or ''

    def parse_list(key):
        val = data.get(key)
        if not val:
            return None
        if isinstance(val, list):
            return val
        try:
            return json.loads(val)
        except Exception:
            return None

    tags = parse_list('tags')
    if tags is not None:
        profile.tags = tags
    dishes = parse_list('dishes')
    if dishes is not None:
        profile.dishes = dishes
    certs = parse_list('certificates')
    if certs is not None:
        profile.certificates = certs

    for field in [
        'business_license',
        'food_license',
        'health_certificate',
        'chef_certification',
        'insurance',
        'food_safety_certificate',
    ]:
        if field in request.FILES:
            setattr(profile, field, request.FILES[field])

    profile.save()

    for photo in request.FILES.getlist('shop_photos'):
        InstructorShopPhoto.objects.create(instructor=profile, image=photo)

    serializer = CulinaryInstructorProfileSerializer(
        profile, context={'request': request}
    )
    return Response({
        'success': True,
        'data': serializer.data,
        'message': 'Profile updated',
    })


# ==================== Availability ====================

@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def availability(request, class_id):
    if not is_culinary_instructor(request.user):
        return Response({'success': False, 'error': 'Not an instructor'}, status=403)

    try:
        cls = CookingClass.objects.get(id=class_id, instructor=request.user.instructor_profile)
    except CookingClass.DoesNotExist:
        return Response({'success': False, 'error': 'Class not found'}, status=404)

    if request.method == 'GET':
        avails = cls.availabilities.all().order_by('start_date')
        serializer = ClassAvailabilitySerializer(avails, many=True)
        return Response({'success': True, 'data': serializer.data})

    data = request.data
    start_date = data.get('start_date')
    end_date = data.get('end_date')

    if not start_date or not end_date:
        return Response(
            {'success': False, 'error': 'start_date and end_date are required'},
            status=400,
        )

    overlapping = cls.availabilities.filter(
        start_date__lte=end_date,
        end_date__gte=start_date,
    ).first()
    if overlapping:
        return Response({
            'success': False,
            'error': (
                f'Date range overlaps with an existing availability '
                f'({overlapping.start_date} ~ {overlapping.end_date}).'
            ),
            'conflict': {
                'start_date': str(overlapping.start_date),
                'end_date': str(overlapping.end_date),
            },
        }, status=400)

    avail = ClassAvailability.objects.create(
        cooking_class=cls,
        start_date=start_date,
        end_date=end_date,
        is_daily_same=data.get('is_daily_same', True),
        set_type=data.get('set_type', 'weekly'),
    )

    for s in data.get('slots', []):
        AvailabilitySlot.objects.create(
            availability=avail,
            day_of_week=s.get('day_of_week') if not avail.is_daily_same else None,
            start_time=s.get('start_time'),
            end_time=s.get('end_time'),
            max_slots=s.get('max_slots', 10),
        )

    serializer = ClassAvailabilitySerializer(avail)
    return Response({'success': True, 'data': serializer.data}, status=201)


@api_view(['PUT', 'POST'])
@permission_classes([IsAuthenticated])
def update_availability(request, availability_id):
    if not is_culinary_instructor(request.user):
        return Response({'success': False, 'error': 'Not an instructor'}, status=403)

    try:
        avail = ClassAvailability.objects.get(
            id=availability_id,
            cooking_class__instructor=request.user.instructor_profile,
        )
    except ClassAvailability.DoesNotExist:
        return Response({'success': False, 'error': 'Availability not found'}, status=404)

    data = request.data
    start_date = data.get('start_date', avail.start_date)
    end_date = data.get('end_date', avail.end_date)

    overlapping = ClassAvailability.objects.filter(
        cooking_class=avail.cooking_class,
        start_date__lte=end_date,
        end_date__gte=start_date,
    ).exclude(id=avail.id).first()
    if overlapping:
        return Response({
            'success': False,
            'error': (
                f'Date range overlaps with another availability '
                f'({overlapping.start_date} ~ {overlapping.end_date}).'
            ),
            'conflict': {
                'start_date': str(overlapping.start_date),
                'end_date': str(overlapping.end_date),
            },
        }, status=400)

    avail.start_date = start_date
    avail.end_date = end_date
    avail.is_daily_same = data.get('is_daily_same', avail.is_daily_same)
    avail.set_type = data.get('set_type', avail.set_type)
    avail.save()

    avail.slots.all().delete()
    for s in data.get('slots', []):
        AvailabilitySlot.objects.create(
            availability=avail,
            day_of_week=s.get('day_of_week') if not avail.is_daily_same else None,
            start_time=s.get('start_time'),
            end_time=s.get('end_time'),
            max_slots=s.get('max_slots', 10),
        )

    serializer = ClassAvailabilitySerializer(avail)
    return Response({'success': True, 'data': serializer.data})


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_availability(request, availability_id):
    if not is_culinary_instructor(request.user):
        return Response({'success': False, 'error': 'Not an instructor'}, status=403)

    try:
        avail = ClassAvailability.objects.get(
            id=availability_id,
            cooking_class__instructor=request.user.instructor_profile
        )
    except ClassAvailability.DoesNotExist:
        return Response({'success': False, 'error': 'Availability not found'}, status=404)

    today = timezone.localdate()
    future_bookings = Booking.objects.filter(
        booking_slot__availability=avail,
        date__gte=today,
        status__in=['pending', 'confirmed']
    )

    if future_bookings.exists() and request.data.get('force') != True:
        return Response({
            'success': False,
            'error': f'There are {future_bookings.count()} upcoming booking(s) in this availability.',
            'bookings_count': future_bookings.count(),
        }, status=400)

    for b in future_bookings:
        b.status = 'cancelled'
        b.cancelled_at = timezone.now()
        if b.payment_status == 'paid':
            b.payment_status = 'refunded'
        b.save()

    avail.delete()
    return Response({'success': True, 'message': 'Availability deleted'})


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def delete_availability_slot(request, slot_id):
    if not is_culinary_instructor(request.user):
        return Response({'success': False, 'error': 'Not an instructor'}, status=403)

    try:
        slot = AvailabilitySlot.objects.get(
            id=slot_id,
            availability__cooking_class__instructor=request.user.instructor_profile
        )
    except AvailabilitySlot.DoesNotExist:
        return Response({'success': False, 'error': 'Slot not found'}, status=404)

    today = timezone.localdate()
    future_bookings = Booking.objects.filter(
        booking_slot=slot,
        date__gte=today,
        status__in=['pending', 'confirmed']
    )

    if future_bookings.exists() and request.data.get('force') != True:
        return Response({
            'success': False,
            'error': f'There are {future_bookings.count()} upcoming booking(s) in this slot.',
            'bookings_count': future_bookings.count(),
        }, status=400)

    for b in future_bookings:
        b.status = 'cancelled'
        b.cancelled_at = timezone.now()
        if b.payment_status == 'paid':
            b.payment_status = 'refunded'
        b.save()

    slot.delete()
    return Response({'success': True, 'message': 'Slot deleted'})


# ==================== ADMIN: Instructor Applications ====================

@api_view(['GET'])
@permission_classes([IsAdminUser])
def admin_instructor_applications(request):
    status_filter = request.query_params.get('status', 'all')
    qs = CulinaryInstructorProfile.objects.select_related('user').all().order_by('-applied_at')
    if status_filter != 'all':
        qs = qs.filter(status=status_filter)
    serializer = InstructorApplicationAdminSerializer(
        qs, many=True, context={'request': request}
    )
    return Response({'success': True, 'data': serializer.data})


@api_view(['GET'])
@permission_classes([IsAdminUser])
def admin_instructor_application_detail(request, application_id):
    try:
        profile = CulinaryInstructorProfile.objects.select_related('user').get(id=application_id)
    except CulinaryInstructorProfile.DoesNotExist:
        return Response({'success': False, 'error': 'Not found'}, status=404)
    serializer = InstructorApplicationAdminSerializer(
        profile, context={'request': request}
    )
    return Response({'success': True, 'data': serializer.data})


@api_view(['POST'])
@permission_classes([IsAdminUser])
def admin_approve_instructor(request, application_id):
    try:
        profile = CulinaryInstructorProfile.objects.select_related('user').get(id=application_id)
    except CulinaryInstructorProfile.DoesNotExist:
        return Response({'success': False, 'error': 'Not found'}, status=404)

    profile.status = 'approved'
    profile.is_approved = True
    profile.reject_reason = None
    profile.approved_at = timezone.now()

    if profile.pending_edit_data:
        for k, v in profile.pending_edit_data.items():
            if hasattr(profile, k):
                setattr(profile, k, v)
        profile.pending_edit_data = None

    profile.save()

    user = profile.user
    user.is_culinary_instructor = True
    user.save()

    if not CookingClass.objects.filter(instructor=profile).exists():
        try:
            price_num = float(
                str(profile.price).replace('RM', '').replace('rm', '').strip() or 0
            )
        except ValueError:
            price_num = 0

        new_class = CookingClass.objects.create(
            instructor=profile,
            title=profile.class_title or profile.shop_name or 'Cooking Class',
            description=profile.class_description or profile.description or '',
            image=profile.avatar,
            location=profile.address or '',
            price=price_num,
            rating=0,
            class_type='in_person',
            schedule=profile.schedule or '',
            tags=profile.tags or [],
            dishes=profile.dishes or [],
            certificates=profile.certificates or [],
            is_active=True,
        )

        for photo in profile.shop_photos.all():
            CookingClassImage.objects.create(
                cooking_class=new_class,
                image=photo.image,
            )

    serializer = InstructorApplicationAdminSerializer(
        profile, context={'request': request}
    )
    return Response({'success': True, 'data': serializer.data})


@api_view(['POST'])
@permission_classes([IsAdminUser])
def admin_reject_instructor(request, application_id):
    try:
        profile = CulinaryInstructorProfile.objects.select_related('user').get(id=application_id)
    except CulinaryInstructorProfile.DoesNotExist:
        return Response({'success': False, 'error': 'Not found'}, status=404)

    reason = request.data.get('reason', '').strip()
    if not reason:
        return Response({'success': False, 'error': 'Reason is required'}, status=400)

    profile.status = 'rejected'
    profile.is_approved = False
    profile.reject_reason = reason
    profile.rejected_at = timezone.now()
    profile.save()

    try:
        _notify(
            profile.user,
            title='Instructor Application Approved',
            content=(
                f'Congratulations! Your shop "{profile.shop_name}" has been '
                f'approved. You can now start creating classes and accepting bookings.'
            ),
            notification_type='instructor_approved',
            post_type='instructor_application',
            post_id=str(profile.id),
        )
    except Exception as e:
        print(f'_notify failed: {e}')

    return Response({'success': True, 'message': 'Rejected'})


# ==================== Complete Booking ====================

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def complete_booking(request, booking_id):
    """User marks their own booking as completed.
    Only after class_end_datetime has passed.
    """
    try:
        booking = Booking.objects.get(id=booking_id, user=request.user)
    except Booking.DoesNotExist:
        return Response({'success': False, 'error': 'Booking not found'}, status=404)

    if booking.status not in ('pending', 'confirmed'):
        return Response({
            'success': False,
            'error': f'Cannot complete a {booking.status} booking'
        }, status=400)

    if hasattr(booking, 'review'):
        return Response({
            'success': False,
            'error': 'Already reviewed'
        }, status=400)

    now = timezone.now()
    if now < _class_end_datetime(booking):
        return Response({
            'success': False,
            'error': 'The class has not finished yet.'
        }, status=400)

    booking.status = 'completed'
    booking.save()

    serializer = BookingSerializer(booking, context={'request': request})
    return Response({'success': True, 'data': serializer.data})


# ==================== REFUND FLOW ====================

@api_view(['POST'])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def request_refund(request, booking_id):
    """User submits a refund request.
    Requires booking.status == 'completed' (user already confirmed class).
    One-shot: only one refund ever per booking.
    """
    try:
        booking = Booking.objects.select_related(
            'cooking_class__instructor__user'
        ).get(id=booking_id, user=request.user)
    except Booking.DoesNotExist:
        return Response({'success': False, 'error': 'Booking not found'}, status=404)

    if booking.payment_status != 'paid':
        return Response({
            'success': False,
            'error': 'Only paid bookings can be refunded'
        }, status=400)

    if booking.status != 'completed':
        return Response({
            'success': False,
            'error': (
                'You must mark the booking as completed before requesting '
                'a refund.'
            ),
        }, status=400)

    # One-shot: block if ANY refund exists (active or resolved)
    if RefundRequest.objects.filter(booking=booking).exists():
        return Response({
            'success': False,
            'error': 'A refund request already exists for this booking.'
        }, status=400)

    reason = request.data.get('reason', '').strip()
    note = request.data.get('note', '').strip()
    image = request.FILES.get('image')

    if not reason:
        return Response({'success': False, 'error': 'Reason required'}, status=400)

    valid_reasons = [c[0] for c in RefundRequest.Reason.choices]
    if reason not in valid_reasons:
        return Response({'success': False, 'error': 'Invalid reason'}, status=400)

    deadline = timezone.now() + timedelta(hours=24)

    refund = RefundRequest.objects.create(
        booking=booking,
        user=request.user,
        user_reason=reason,
        user_note=note,
        user_image=image,
        status=RefundRequest.Status.PENDING_INSTRUCTOR,
        deadline=deadline,
    )

    instructor_user = booking.cooking_class.instructor.user
    _notify(
        instructor_user,
        title='Refund Request',
        content=(
            f'{request.user.username} requested a refund for '
            f'"{booking.cooking_class.title}". Please respond within 24 hours.'
        ),
        notification_type='refund_request',
        post_type='refund',
        post_id=str(refund.id),
    )

    serializer = RefundRequestSerializer(refund, context={'request': request})
    return Response({'success': True, 'data': serializer.data}, status=201)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def refund_detail(request, refund_id):
    _auto_resolve_overdue_refunds()

    try:
        refund = RefundRequest.objects.select_related(
            'booking__cooking_class__instructor__user', 'user'
        ).get(id=refund_id)
    except RefundRequest.DoesNotExist:
        return Response({'success': False, 'error': 'Not found'}, status=404)

    is_user = refund.user_id == request.user.id
    is_instructor = (
        refund.booking.cooking_class.instructor.user_id == request.user.id
    )
    if not (is_user or is_instructor):
        return Response({'success': False, 'error': 'Forbidden'}, status=403)

    serializer = RefundRequestSerializer(refund, context={'request': request})
    return Response({'success': True, 'data': serializer.data})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def instructor_respond_refund(request, refund_id):
    """Instructor responds to a refund request.
    - agrees=True  → immediate FULL refund, status='resolved_full'
    - agrees=False → escalate to admin, status='pending_admin'
    Only allowed while status == 'pending_instructor' and not yet responded.
    """
    _auto_resolve_overdue_refunds()

    try:
        refund = RefundRequest.objects.select_related(
            'booking__cooking_class__instructor__user', 'user'
        ).get(id=refund_id)
    except RefundRequest.DoesNotExist:
        return Response({'success': False, 'error': 'Not found'}, status=404)

    if refund.booking.cooking_class.instructor.user_id != request.user.id:
        return Response({'success': False, 'error': 'Forbidden'}, status=403)

    if refund.status != RefundRequest.Status.PENDING_INSTRUCTOR:
        return Response({
            'success': False,
            'error': 'Refund already resolved or escalated'
        }, status=400)

    if refund.instructor_responded_at is not None:
        return Response({
            'success': False,
            'error': 'You have already responded to this refund'
        }, status=400)

    agrees = request.data.get('agrees')
    if agrees is None:
        return Response({'success': False, 'error': 'agrees (bool) required'}, status=400)

    if isinstance(agrees, str):
        agrees = agrees.lower() == 'true'

    response_text = request.data.get('response', '').strip()
    image = request.FILES.get('image')

    refund.instructor_agrees = bool(agrees)
    refund.instructor_response = response_text
    refund.instructor_responded_at = timezone.now()
    if image:
        refund.instructor_image = image

    booking = refund.booking
    total_price = float(booking.cooking_class.price) * booking.quantity
    instructor_shop = booking.cooking_class.instructor.shop_name

    if agrees:
        # Instructor accepts → immediate full refund
        refund.status = RefundRequest.Status.RESOLVED_FULL
        refund.refund_amount = total_price
        refund.admin_decision_amount = 'full'
        refund.admin_note = 'Instructor accepted the refund.'
        refund.admin_resolved_at = timezone.now()
        refund.save()

        booking.payment_status = 'refunded'
        booking.save()

        _notify(
            refund.user,
            title='Refund Approved',
            content=(
                f'Your refund request for "{booking.cooking_class.title}" '
                f'has been approved. RM {total_price:.2f} will be refunded '
                f'to your card.'
            ),
            notification_type='refund_resolved',
            post_type='refund',
            post_id=str(refund.id),
        )
    else:
        # Instructor disputes → escalate to admin
        refund.status = RefundRequest.Status.PENDING_ADMIN
        refund.save()

        _notify(
            refund.user,
            title='Refund Disputed',
            content=(
                f'Instructor {instructor_shop} disputed your refund request. '
                f'We will review both sides and make a decision.'
            ),
            notification_type='refund_update',
            post_type='refund',
            post_id=str(refund.id),
        )

    serializer = RefundRequestSerializer(refund, context={'request': request})
    return Response({'success': True, 'data': serializer.data})


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def my_refund_requests(request):
    _auto_resolve_overdue_refunds()

    refunds = RefundRequest.objects.filter(
        user=request.user
    ).select_related(
        'booking__cooking_class__instructor'
    ).order_by('-created_at')
    serializer = RefundRequestSerializer(refunds, many=True, context={'request': request})
    return Response({'success': True, 'data': serializer.data})


# ==================== ADMIN: Refund ====================

def _get_admin_from_request(request):
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


@api_view(['GET'])
@permission_classes([AllowAny])
def admin_refund_list(request):
    if not _get_admin_from_request(request):
        return Response({'error': 'Admin only'}, status=403)

    _auto_resolve_overdue_refunds()

    qs = RefundRequest.objects.all().select_related(
        'booking__cooking_class__instructor', 'user'
    ).order_by('-created_at')

    status_filter = request.query_params.get('status', 'pending_admin')
    if status_filter != 'all':
        qs = qs.filter(status=status_filter)

    serializer = RefundRequestSerializer(qs, many=True, context={'request': request})
    return Response(serializer.data)


@api_view(['POST'])
@permission_classes([AllowAny])
def admin_resolve_refund(request, refund_id):
    if not _get_admin_from_request(request):
        return Response({'error': 'Admin only'}, status=403)

    try:
        refund = RefundRequest.objects.select_related(
            'booking__cooking_class__instructor__user', 'user'
        ).get(id=refund_id)
    except RefundRequest.DoesNotExist:
        return Response({'error': 'Not found'}, status=404)

    if refund.status != RefundRequest.Status.PENDING_ADMIN:
        return Response({'error': 'Refund not in pending_admin status'}, status=400)

    decision = request.data.get('decision')
    admin_note = request.data.get('admin_note', '').strip()

    if decision not in ('full', 'half', 'none'):
        return Response({'error': 'decision must be "full", "half", or "none"'}, status=400)

    booking = refund.booking
    total_price = float(booking.cooking_class.price) * booking.quantity

    if decision == 'full':
        refund.status = RefundRequest.Status.RESOLVED_FULL
        refund.refund_amount = total_price
        booking.payment_status = 'refunded'
    elif decision == 'half':
        refund.status = RefundRequest.Status.RESOLVED_HALF
        refund.refund_amount = total_price / 2
        booking.payment_status = 'refunded'
    else:
        refund.status = RefundRequest.Status.RESOLVED_NONE
        refund.refund_amount = 0
        # payment stays 'paid'

    refund.admin_decision_amount = decision
    refund.admin_note = admin_note
    refund.admin_resolved_at = timezone.now()
    refund.save()

    booking.save()

    if decision == 'none':
        _notify(
            refund.user,
            title='Refund Rejected',
            content=(
                f'Your refund request for "{booking.cooking_class.title}" '
                f'was rejected. Reason: {admin_note or "Not eligible"}'
            ),
            notification_type='refund_resolved',
            post_type='refund',
            post_id=str(refund.id),
        )
    else:
        amount_label = 'Full refund' if decision == 'full' else 'Half refund'
        _notify(
            refund.user,
            title=f'{amount_label} Approved',
            content=(
                f'Your refund request for "{booking.cooking_class.title}" '
                f'has been approved. RM {refund.refund_amount:.2f} will be '
                f'refunded to your card.'
            ),
            notification_type='refund_resolved',
            post_type='refund',
            post_id=str(refund.id),
        )

    resolved_label = (
        'Full refund' if decision == 'full'
        else ('Half refund' if decision == 'half' else 'No refund')
    )
    _notify(
        booking.cooking_class.instructor.user,
        title='Refund Resolved',
        content=(
            f'Refund for "{booking.cooking_class.title}" has been '
            f'resolved: {resolved_label}.'
        ),
        notification_type='refund_resolved',
        post_type='refund',
        post_id=str(refund.id),
    )

    return Response({'success': True, 'message': f'Refund resolved: {decision}'})


# ==================== Instructor Booking Actions ====================

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def instructor_confirm_booking(request, booking_id):
    if not is_culinary_instructor(request.user):
        return Response(
            {'success': False, 'error': 'Not an instructor'},
            status=403,
        )

    try:
        booking = Booking.objects.select_related(
            'cooking_class__instructor'
        ).get(
            id=booking_id,
            cooking_class__instructor=request.user.instructor_profile,
        )
    except Booking.DoesNotExist:
        return Response(
            {'success': False, 'error': 'Booking not found'},
            status=404,
        )

    if booking.status != 'pending':
        return Response(
            {'success': False,
             'error': f'Cannot confirm a {booking.status} booking'},
            status=400,
        )

    booking.status = 'confirmed'
    booking.save()

    serializer = BookingSerializer(booking, context={'request': request})
    return Response({'success': True, 'data': serializer.data})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def instructor_reject_booking(request, booking_id):
    """Reject = cancel + full refund + notify user.
    Kept as an alias for instructor_cancel_booking.
    """
    return instructor_cancel_booking(request, booking_id)