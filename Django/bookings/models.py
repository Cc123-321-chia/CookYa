from django.db import models
from django.conf import settings
from django.utils import timezone
import uuid


class CulinaryInstructorProfile(models.Model):
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('approved', 'Approved'),
        ('rejected', 'Rejected'),
    )

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='instructor_profile'
    )
    shop_name = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    address = models.TextField(blank=True)
    phone = models.CharField(max_length=50, blank=True)
    email = models.EmailField(blank=True)

    avatar = models.ImageField(upload_to='instructor/avatar/', null=True, blank=True)
    cover_photo = models.ImageField(upload_to='instructor/cover/', null=True, blank=True)

    business_license = models.ImageField(upload_to='instructor/license/', null=True, blank=True)
    food_license = models.ImageField(upload_to='instructor/license/', null=True, blank=True)
    health_certificate = models.ImageField(upload_to='instructor/license/', null=True, blank=True)
    chef_certification = models.ImageField(upload_to='instructor/license/', null=True, blank=True)
    insurance = models.ImageField(upload_to='instructor/license/', null=True, blank=True)
    food_safety_certificate = models.ImageField(upload_to='instructor/license/', null=True, blank=True)

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    is_approved = models.BooleanField(default=False)

    reject_reason = models.TextField(blank=True, null=True)

    applied_at = models.DateTimeField(auto_now_add=True)
    approved_at = models.DateTimeField(null=True, blank=True)
    rejected_at = models.DateTimeField(null=True, blank=True)

    # apply 时填的初始 class 资料（approve 后自动建第一个 class）
    class_title = models.CharField(max_length=200, blank=True)
    class_description = models.TextField(blank=True)
    price = models.CharField(max_length=50, blank=True)
    schedule = models.CharField(max_length=200, blank=True)
    tags = models.JSONField(default=list, blank=True)
    dishes = models.JSONField(default=list, blank=True)
    certificates = models.JSONField(default=list, blank=True)

    pending_edit_data = models.JSONField(null=True, blank=True)

    def __str__(self):
        return self.shop_name


class InstructorShopPhoto(models.Model):
    instructor = models.ForeignKey(
        CulinaryInstructorProfile,
        on_delete=models.CASCADE,
        related_name='shop_photos'
    )
    image = models.ImageField(upload_to='instructor/shop/')
    created_at = models.DateTimeField(auto_now_add=True)


class CookingClass(models.Model):
    CLASS_TYPE_CHOICES = (
        ('in_person', 'In-Person'),
        ('home_visit', 'Home Visit'),
    )

    instructor = models.ForeignKey(
        CulinaryInstructorProfile,
        on_delete=models.CASCADE,
        related_name='classes'
    )
    title = models.CharField(max_length=200)
    description = models.TextField(blank=True)
    image = models.ImageField(upload_to='classes/', null=True, blank=True)
    cover_video = models.FileField(upload_to='classes/videos/', null=True, blank=True)
    location = models.CharField(max_length=200, blank=True)
    price = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    rating = models.FloatField(default=0)
    class_type = models.CharField(max_length=20, choices=CLASS_TYPE_CHOICES, default='in_person')
    schedule = models.CharField(max_length=200, blank=True)
    tags = models.JSONField(default=list, blank=True)
    dishes = models.JSONField(default=list, blank=True)
    certificates = models.JSONField(default=list, blank=True)
    is_active = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.title


class CookingClassImage(models.Model):
    cooking_class = models.ForeignKey(
        CookingClass,
        on_delete=models.CASCADE,
        related_name='images'
    )
    image = models.ImageField(upload_to='classes/gallery/')
    created_at = models.DateTimeField(auto_now_add=True)


class CookingClassVideo(models.Model):
    cooking_class = models.ForeignKey(
        CookingClass,
        on_delete=models.CASCADE,
        related_name='videos'
    )
    video = models.FileField(upload_to='classes/videos/')
    created_at = models.DateTimeField(auto_now_add=True)


class ClassAvailability(models.Model):
    SET_TYPE_CHOICES = (
        ('weekly', 'Weekly'),
        ('monthly', 'Monthly'),
    )

    cooking_class = models.ForeignKey(
        CookingClass,
        on_delete=models.CASCADE,
        related_name='availabilities'
    )
    start_date = models.DateField()
    end_date = models.DateField()
    is_daily_same = models.BooleanField(default=True)
    set_type = models.CharField(max_length=20, choices=SET_TYPE_CHOICES, default='weekly')

    created_at = models.DateTimeField(auto_now_add=True)


class AvailabilitySlot(models.Model):
    availability = models.ForeignKey(
        ClassAvailability,
        on_delete=models.CASCADE,
        related_name='slots'
    )
    day_of_week = models.IntegerField(null=True, blank=True)  # 0=Mon, 6=Sun
    start_time = models.TimeField()
    end_time = models.TimeField()
    max_slots = models.IntegerField(default=10)

    def __str__(self):
        return f"{self.start_time}-{self.end_time} (max {self.max_slots})"


class SavedClass(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='saved_classes'
    )
    cooking_class = models.ForeignKey(
        CookingClass,
        on_delete=models.CASCADE,
        related_name='saved_by'
    )
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('user', 'cooking_class')


class PaymentCard(models.Model):
    BRAND_CHOICES = (
        ('visa', 'Visa'),
        ('mastercard', 'Mastercard'),
        ('amex', 'American Express'),
        ('other', 'Other'),
    )

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='payment_cards'
    )
    brand = models.CharField(max_length=20, choices=BRAND_CHOICES, default='visa')
    last4 = models.CharField(max_length=4)
    exp_month = models.IntegerField()
    exp_year = models.IntegerField()
    holder_name = models.CharField(max_length=100, blank=True)
    is_default = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-is_default', '-created_at']

    def __str__(self):
        return f"{self.brand} ****{self.last4}"


class Booking(models.Model):
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('confirmed', 'Confirmed'),
        ('cancelled', 'Cancelled'),
        ('completed', 'Completed'),
    )

    PAYMENT_STATUS_CHOICES = (
        ('unpaid', 'Unpaid'),
        ('paid', 'Paid'),
        ('refunded', 'Refunded'),
    )

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='bookings'
    )
    cooking_class = models.ForeignKey(
        CookingClass,
        on_delete=models.CASCADE,
        related_name='bookings'
    )
    date = models.DateField()

    booking_slot = models.ForeignKey(
        AvailabilitySlot,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='bookings'
    )
    start_time = models.TimeField(null=True, blank=True)
    end_time = models.TimeField(null=True, blank=True)

    quantity = models.IntegerField(default=1)

    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')

    payment_status = models.CharField(
        max_length=20,
        choices=PAYMENT_STATUS_CHOICES,
        default='unpaid'
    )
    payment_card = models.ForeignKey(
        PaymentCard,
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='bookings'
    )
    paid_at = models.DateTimeField(null=True, blank=True)
    cancelled_at = models.DateTimeField(null=True, blank=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('user', 'cooking_class', 'date', 'booking_slot')

    @property
    def active_refund_request(self):
        return self.refund_requests.filter(
            status__in=['pending_instructor', 'pending_admin']
        ).first()

    @property
    def latest_refund_request(self):
        return self.refund_requests.order_by('-created_at').first()


class BookingReview(models.Model):
    booking = models.OneToOneField(
        Booking,
        on_delete=models.CASCADE,
        related_name='review'
    )
    rating = models.IntegerField()
    comment = models.TextField(blank=True)
    image = models.ImageField(upload_to='reviews/', null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

class RefundRequest(models.Model):
    """Refund request flow: user → instructor → admin"""

    class Status(models.TextChoices):
        PENDING_INSTRUCTOR = 'pending_instructor', 'Pending Instructor'
        PENDING_ADMIN = 'pending_admin', 'Pending Admin'  # 用户/开班者回应后，或24h超时
        RESOLVED_FULL = 'resolved_full', 'Resolved - Full Refund'
        RESOLVED_HALF = 'resolved_half', 'Resolved - Half Refund'
        RESOLVED_NONE = 'resolved_none', 'Resolved - No Refund'

    class Reason(models.TextChoices):
        CLASS_NOT_AS_DESCRIBED = 'not_as_described', 'Class not as described'
        INSTRUCTOR_NO_SHOW = 'instructor_no_show', 'Instructor did not show up'
        QUALITY_ISSUE = 'quality_issue', 'Poor quality / not satisfied'
        PERSONAL_EMERGENCY = 'personal_emergency', 'Personal emergency'
        OTHER = 'other', 'Other'

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    booking = models.ForeignKey(
        Booking, on_delete=models.CASCADE, related_name='refund_requests'
    )
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE,
        related_name='refund_requests_made'
    )

    # User side
    user_reason = models.CharField(max_length=50, choices=Reason.choices)
    user_note = models.TextField(blank=True, default='')
    user_image = models.ImageField(upload_to='refunds/user/', null=True, blank=True)

    # Instructor side
    instructor_response = models.TextField(blank=True, default='')
    instructor_image = models.ImageField(upload_to='refunds/instructor/', null=True, blank=True)
    instructor_agrees = models.BooleanField(null=True, blank=True)  # True/False/None
    instructor_responded_at = models.DateTimeField(null=True, blank=True)

    # Status
    status = models.CharField(
        max_length=30, choices=Status.choices,
        default=Status.PENDING_INSTRUCTOR
    )

    # Admin side
    admin_decision_amount = models.CharField(
        max_length=20, blank=True, default='',  # 'full', 'half', 'none'
    )
    admin_note = models.TextField(blank=True, default='')
    admin_resolved_at = models.DateTimeField(null=True, blank=True)

    # Refund amount actual
    refund_amount = models.DecimalField(
        max_digits=10, decimal_places=2, null=True, blank=True
    )

    # Auto-escalate timer
    deadline = models.DateTimeField(null=True, blank=True)  # instructor 1天 deadline

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at']
        indexes = [
            models.Index(fields=['status', '-created_at']),
            models.Index(fields=['booking']),
        ]

    def __str__(self):
        return f'Refund #{self.id} for Booking #{self.booking_id} ({self.status})'