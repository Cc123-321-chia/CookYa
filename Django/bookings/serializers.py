from rest_framework import serializers
from django.db import models
from django.utils import timezone
from django.contrib.auth import get_user_model
from datetime import datetime
from .models import (
    CulinaryInstructorProfile, InstructorShopPhoto, CookingClass,
    CookingClassImage, CookingClassVideo, ClassAvailability, AvailabilitySlot,
    SavedClass, Booking, BookingReview, PaymentCard, RefundRequest
)

User = get_user_model()


def _absolute_url(request, file_or_url):
    if not file_or_url:
        return None
    try:
        url = file_or_url.url if hasattr(file_or_url, 'url') else str(file_or_url)
    except Exception:
        return None
    if not url:
        return None
    if url.startswith('http://') or url.startswith('https://'):
        return url
    if not url.startswith('/'):
        url = '/' + url
    return request.build_absolute_uri(url) if request else url


def _class_end_datetime(booking):
    if booking.end_time is not None:
        return timezone.make_aware(
            datetime.combine(booking.date, booking.end_time)
        )
    return timezone.make_aware(
        datetime.combine(booking.date, datetime.max.time())
    )


def _class_cutoff_datetime(booking):
    return timezone.make_aware(
        datetime.combine(booking.date, datetime.min.time())
    )


class InstructorShopPhotoSerializer(serializers.ModelSerializer):
    image = serializers.SerializerMethodField()

    class Meta:
        model = InstructorShopPhoto
        fields = ('id', 'image')

    def get_image(self, obj):
        return _absolute_url(self.context.get('request'), obj.image)


class CulinaryInstructorProfileSerializer(serializers.ModelSerializer):
    avatar = serializers.SerializerMethodField()
    cover_photo = serializers.SerializerMethodField()
    shop_photos = InstructorShopPhotoSerializer(many=True, read_only=True)
    applied_at = serializers.DateTimeField(read_only=True)
    approved_at = serializers.DateTimeField(read_only=True)
    user_id = serializers.CharField(source='user.user_id', read_only=True)

    business_license_url = serializers.SerializerMethodField()
    food_license_url = serializers.SerializerMethodField()
    health_certificate_url = serializers.SerializerMethodField()
    chef_certification_url = serializers.SerializerMethodField()
    insurance_url = serializers.SerializerMethodField()
    food_safety_certificate_url = serializers.SerializerMethodField()

    class Meta:
        model = CulinaryInstructorProfile
        fields = (
            'id', 'user_id', 'shop_name', 'description', 'address', 'phone', 'email',
            'avatar', 'cover_photo', 'shop_photos',
            'business_license_url', 'food_license_url', 'health_certificate_url',
            'chef_certification_url', 'insurance_url', 'food_safety_certificate_url',
            'is_approved', 'applied_at', 'approved_at',
            'class_title', 'class_description', 'price', 'schedule',
            'tags', 'dishes', 'certificates',
        )
        read_only_fields = ('is_approved', 'applied_at', 'approved_at')

    def get_avatar(self, obj):
        return _absolute_url(self.context.get('request'), obj.avatar)

    def get_cover_photo(self, obj):
        return _absolute_url(self.context.get('request'), obj.cover_photo)

    def get_business_license_url(self, obj):
        return _absolute_url(self.context.get('request'), obj.business_license)

    def get_food_license_url(self, obj):
        return _absolute_url(self.context.get('request'), obj.food_license)

    def get_health_certificate_url(self, obj):
        return _absolute_url(self.context.get('request'), obj.health_certificate)

    def get_chef_certification_url(self, obj):
        return _absolute_url(self.context.get('request'), obj.chef_certification)

    def get_insurance_url(self, obj):
        return _absolute_url(self.context.get('request'), obj.insurance)

    def get_food_safety_certificate_url(self, obj):
        return _absolute_url(self.context.get('request'), obj.food_safety_certificate)


class CookingClassImageSerializer(serializers.ModelSerializer):
    image = serializers.SerializerMethodField()

    class Meta:
        model = CookingClassImage
        fields = ('id', 'image')

    def get_image(self, obj):
        return _absolute_url(self.context.get('request'), obj.image)


class CookingClassVideoSerializer(serializers.ModelSerializer):
    video = serializers.SerializerMethodField()

    class Meta:
        model = CookingClassVideo
        fields = ('id', 'video')

    def get_video(self, obj):
        return _absolute_url(self.context.get('request'), obj.video)


class AvailabilitySlotSerializer(serializers.ModelSerializer):
    class Meta:
        model = AvailabilitySlot
        fields = ('id', 'day_of_week', 'start_time', 'end_time', 'max_slots')


class ClassAvailabilitySerializer(serializers.ModelSerializer):
    slots = AvailabilitySlotSerializer(many=True, read_only=True)

    class Meta:
        model = ClassAvailability
        fields = ('id', 'start_date', 'end_date', 'is_daily_same', 'set_type', 'slots')


class CookingClassSerializer(serializers.ModelSerializer):
    image = serializers.SerializerMethodField()
    cover_video = serializers.SerializerMethodField()
    images = CookingClassImageSerializer(many=True, read_only=True)
    videos = CookingClassVideoSerializer(many=True, read_only=True)
    availabilities = ClassAvailabilitySerializer(many=True, read_only=True)
    instructor = CulinaryInstructorProfileSerializer(read_only=True)
    is_saved = serializers.SerializerMethodField()
    is_available = serializers.SerializerMethodField()
    is_fully_booked = serializers.SerializerMethodField()

    class Meta:
        model = CookingClass
        fields = (
            'id', 'title', 'description', 'image', 'cover_video', 'images', 'videos',
            'location', 'price', 'rating', 'class_type', 'schedule',
            'tags', 'dishes', 'certificates', 'is_active',
            'instructor', 'availabilities',
            'is_saved', 'is_available', 'is_fully_booked',
        )

    def get_image(self, obj):
        return _absolute_url(self.context.get('request'), obj.image)

    def get_cover_video(self, obj):
        return _absolute_url(self.context.get('request'), obj.cover_video)

    def get_is_saved(self, obj):
        request = self.context.get('request')
        if not request or not request.user.is_authenticated:
            return False
        return SavedClass.objects.filter(user=request.user, cooking_class=obj).exists()

    def _has_any_availability(self, obj):
        return obj.availabilities.exists() and AvailabilitySlot.objects.filter(
            availability__cooking_class=obj
        ).exists()

    def get_is_available(self, obj):
        if not self._has_any_availability(obj):
            return False
        for slot in AvailabilitySlot.objects.filter(availability__cooking_class=obj):
            booked = Booking.objects.filter(
                booking_slot=slot,
                payment_status='paid',
                status__in=['pending', 'confirmed', 'completed']
            ).aggregate(total=models.Sum('quantity'))['total'] or 0
            if slot.max_slots - booked > 0:
                return True
        return False

    def get_is_fully_booked(self, obj):
        if not self._has_any_availability(obj):
            return False
        return not self.get_is_available(obj)


class BookingReviewSerializer(serializers.ModelSerializer):
    image = serializers.SerializerMethodField()
    username = serializers.CharField(source='booking.user.username', read_only=True)
    user_avatar = serializers.SerializerMethodField()

    class Meta:
        model = BookingReview
        fields = ('id', 'rating', 'comment', 'image', 'username', 'user_avatar', 'created_at')

    def get_image(self, obj):
        return _absolute_url(self.context.get('request'), obj.image)

    def get_user_avatar(self, obj):
        return _absolute_url(self.context.get('request'), obj.booking.user.avatar)


class PaymentCardSerializer(serializers.ModelSerializer):
    brand_display = serializers.CharField(source='get_brand_display', read_only=True)

    class Meta:
        model = PaymentCard
        fields = (
            'id', 'brand', 'brand_display', 'last4',
            'exp_month', 'exp_year', 'holder_name',
            'is_default', 'created_at',
        )
        read_only_fields = ('id', 'created_at')


class PaymentCardCreateSerializer(serializers.Serializer):
    card_number = serializers.CharField(max_length=20)
    exp_month = serializers.IntegerField()
    exp_year = serializers.IntegerField()
    holder_name = serializers.CharField(max_length=100, required=False, allow_blank=True)
    is_default = serializers.BooleanField(required=False, default=False)

    def validate_card_number(self, value):
        digits = ''.join(c for c in value if c.isdigit())
        if len(digits) < 12:
            raise serializers.ValidationError('Invalid card number')
        return digits

    def create(self, validated_data):
        user = self.context['request'].user
        digits = validated_data['card_number']

        brand = 'other'
        if digits.startswith('4'):
            brand = 'visa'
        elif digits[:2] in ('51', '52', '53', '54', '55'):
            brand = 'mastercard'
        elif digits[:2] in ('34', '37'):
            brand = 'amex'

        last4 = digits[-4:]

        is_default = validated_data.get('is_default', False)
        if not PaymentCard.objects.filter(user=user).exists():
            is_default = True
        if is_default:
            PaymentCard.objects.filter(user=user).update(is_default=False)

        return PaymentCard.objects.create(
            user=user,
            brand=brand,
            last4=last4,
            exp_month=validated_data['exp_month'],
            exp_year=validated_data['exp_year'],
            holder_name=validated_data.get('holder_name', ''),
            is_default=is_default,
        )


class BookingSerializer(serializers.ModelSerializer):
    cooking_class = CookingClassSerializer(read_only=True)
    username = serializers.CharField(source='user.username', read_only=True)
    user_avatar = serializers.SerializerMethodField()
    user_user_id = serializers.SerializerMethodField()
    review = BookingReviewSerializer(read_only=True)
    display_status = serializers.SerializerMethodField()
    display_status_for_instructor = serializers.SerializerMethodField()
    can_cancel = serializers.SerializerMethodField()
    can_complete = serializers.SerializerMethodField()
    can_refund = serializers.SerializerMethodField()
    can_review = serializers.SerializerMethodField()
    payment_card = PaymentCardSerializer(read_only=True)
    slot_remaining = serializers.SerializerMethodField()
    latest_refund = serializers.SerializerMethodField()

    class Meta:
        model = Booking
        fields = (
            'id', 'cooking_class', 'date',
            'booking_slot', 'start_time', 'end_time',
            'quantity',
            'status', 'display_status', 'display_status_for_instructor',
            'can_cancel', 'can_complete', 'can_refund', 'can_review',
            'payment_status', 'payment_card', 'paid_at', 'cancelled_at',
            'username', 'user_user_id', 'user_avatar', 'review', 'slot_remaining',
            'created_at', 'updated_at', 'latest_refund',
        )

    def get_user_avatar(self, obj):
        return _absolute_url(self.context.get('request'), obj.user.avatar)

    def get_user_user_id(self, obj):
        return obj.user.user_id

    def get_slot_remaining(self, obj):
        if not obj.booking_slot:
            return None
        booked = Booking.objects.filter(
            booking_slot=obj.booking_slot,
            date=obj.date,
            payment_status='paid',
            status__in=['pending', 'confirmed', 'completed']
        ).exclude(id=obj.id).aggregate(total=models.Sum('quantity'))['total'] or 0
        return max(obj.booking_slot.max_slots - booked, 0)

    def get_display_status(self, obj):
        if obj.status == 'cancelled':
            return 'cancelled'
        if hasattr(obj, 'review'):
            return 'reviewed'
        return obj.status

    def get_display_status_for_instructor(self, obj):
        if obj.status == 'cancelled':
            return 'cancelled'
        r = obj.latest_refund_request
        if r and r.status in ('resolved_full', 'resolved_half'):
            return 'refunded'
        if r and r.status in ('pending_instructor', 'pending_admin'):
            return 'pending_refund'
        if hasattr(obj, 'review'):
            return 'reviewed'
        return obj.status

    def _has_active_refund(self, obj):
        return RefundRequest.objects.filter(
            booking=obj,
            status__in=['pending_instructor', 'pending_admin']
        ).exists()

    def _has_any_refund(self, obj):
        return RefundRequest.objects.filter(booking=obj).exists()

    def get_can_cancel(self, obj):
        if obj.payment_status != 'paid':
            return False
        if obj.status not in ('pending', 'confirmed'):
            return False
        if hasattr(obj, 'review'):
            return False
        now = timezone.now()
        return now < _class_cutoff_datetime(obj)

    def get_can_complete(self, obj):
        if obj.payment_status != 'paid':
            return False
        if obj.status not in ('pending', 'confirmed'):
            return False
        if hasattr(obj, 'review'):
            return False
        now = timezone.now()
        return now > _class_end_datetime(obj)

    def get_can_refund(self, obj):
        if obj.payment_status != 'paid':
            return False
        if obj.status != 'completed':
            return False
        if hasattr(obj, 'review'):
            return False
        return not self._has_any_refund(obj)

    def get_can_review(self, obj):
        if obj.status != 'completed':
            return False
        if hasattr(obj, 'review'):
            return False
        return not self._has_any_refund(obj)

    def get_latest_refund(self, obj):
        r = obj.latest_refund_request
        if not r:
            return None
        return {
            'id': str(r.id),
            'status': r.status,
            'refund_amount': float(r.refund_amount) if r.refund_amount else None,
            'admin_decision_amount': r.admin_decision_amount,
            'instructor_submitted_at': (
                r.instructor_responded_at.isoformat()
                if r.instructor_responded_at else None
            ),
            'can_instructor_respond': (
                r.status == 'pending_instructor'
                and r.instructor_responded_at is None
            ),
        }


class InstructorApplicationAdminSerializer(serializers.ModelSerializer):
    user_id = serializers.CharField(source='user.user_id', read_only=True)
    username = serializers.CharField(source='user.username', read_only=True)
    user_email = serializers.CharField(source='user.email', read_only=True)
    user_avatar = serializers.SerializerMethodField()

    avatar = serializers.SerializerMethodField()
    cover_photo = serializers.SerializerMethodField()
    business_license = serializers.SerializerMethodField()
    food_license = serializers.SerializerMethodField()
    health_certificate = serializers.SerializerMethodField()
    chef_certification = serializers.SerializerMethodField()
    insurance = serializers.SerializerMethodField()
    food_safety_certificate = serializers.SerializerMethodField()
    shop_photos = InstructorShopPhotoSerializer(many=True, read_only=True)

    class Meta:
        model = CulinaryInstructorProfile
        fields = (
            'id', 'user_id', 'username', 'user_email', 'user_avatar',
            'shop_name', 'description', 'address', 'phone', 'email',
            'avatar', 'cover_photo', 'shop_photos',
            'business_license', 'food_license', 'health_certificate',
            'chef_certification', 'insurance', 'food_safety_certificate',
            'status', 'is_approved', 'reject_reason',
            'applied_at', 'approved_at', 'rejected_at',
            'class_title', 'class_description', 'price', 'schedule',
            'tags', 'dishes', 'certificates',
        )

    def get_user_avatar(self, obj):
        return _absolute_url(self.context.get('request'), obj.user.avatar)

    def get_avatar(self, obj):
        return _absolute_url(self.context.get('request'), obj.avatar)

    def get_cover_photo(self, obj):
        return _absolute_url(self.context.get('request'), obj.cover_photo)

    def get_business_license(self, obj):
        return _absolute_url(self.context.get('request'), obj.business_license)

    def get_food_license(self, obj):
        return _absolute_url(self.context.get('request'), obj.food_license)

    def get_health_certificate(self, obj):
        return _absolute_url(self.context.get('request'), obj.health_certificate)

    def get_chef_certification(self, obj):
        return _absolute_url(self.context.get('request'), obj.chef_certification)

    def get_insurance(self, obj):
        return _absolute_url(self.context.get('request'), obj.insurance)

    def get_food_safety_certificate(self, obj):
        return _absolute_url(self.context.get('request'), obj.food_safety_certificate)


class ClassCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = CookingClass
        fields = (
            'title', 'description', 'location', 'price', 'class_type',
            'schedule', 'tags', 'dishes', 'certificates',
        )


class RefundRequestSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    user_user_id = serializers.CharField(source='user.user_id', read_only=True)
    user_avatar = serializers.SerializerMethodField()
    user_image = serializers.SerializerMethodField()
    instructor_image = serializers.SerializerMethodField()
    booking_info = serializers.SerializerMethodField()
    instructor_user_id = serializers.SerializerMethodField()

    class Meta:
        model = RefundRequest
        fields = (
            'id', 'booking', 'username', 'user_user_id', 'user_avatar',
            'user_reason', 'user_note', 'user_image',
            'instructor_response', 'instructor_image',
            'instructor_agrees', 'instructor_responded_at',
            'status', 'admin_decision_amount', 'admin_note',
            'admin_resolved_at', 'refund_amount', 'deadline',
            'booking_info', 'instructor_user_id',
            'created_at',
        )

    def get_user_avatar(self, obj):
        return _absolute_url(self.context.get('request'), obj.user.avatar)

    def get_user_image(self, obj):
        return _absolute_url(self.context.get('request'), obj.user_image)

    def get_instructor_image(self, obj):
        return _absolute_url(self.context.get('request'), obj.instructor_image)

    def get_instructor_user_id(self, obj):
        try:
            return obj.booking.cooking_class.instructor.user.user_id
        except Exception:
            return ''

    def get_booking_info(self, obj):
        b = obj.booking
        cls = b.cooking_class
        return {
            'booking_id': b.id,
            'class_title': cls.title,
            'class_image': _absolute_url(self.context.get('request'), cls.image),
            'instructor_name': cls.instructor.shop_name,
            'instructor_avatar': _absolute_url(
                self.context.get('request'), cls.instructor.avatar
            ),
            'date': str(b.date),
            'start_time': b.start_time.strftime('%H:%M') if b.start_time else None,
            'end_time': b.end_time.strftime('%H:%M') if b.end_time else None,
            'quantity': b.quantity,
            'price_per_pax': float(cls.price),
            'total_price': float(cls.price) * b.quantity,
        }