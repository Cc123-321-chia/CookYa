from django.contrib import admin
from .models import (
    CulinaryInstructorProfile,
    InstructorShopPhoto,
    CookingClass,
    CookingClassImage,
    CookingClassVideo,
    ClassAvailability,
    AvailabilitySlot,
    SavedClass,
    Booking,
    BookingReview,
    PaymentCard,
)


@admin.register(CulinaryInstructorProfile)
class CulinaryInstructorProfileAdmin(admin.ModelAdmin):
    list_display = (
        'id', 'shop_name', 'get_username', 'get_email',
        'status', 'is_approved', 'applied_at',
    )
    list_filter = ('status', 'is_approved')
    search_fields = ('shop_name', 'user__username', 'user__email', 'email')
    readonly_fields = ('applied_at', 'approved_at', 'rejected_at')

    def get_username(self, obj):
        return obj.user.username
    get_username.short_description = 'Username'

    def get_email(self, obj):
        return obj.user.email
    get_email.short_description = 'User Email'


@admin.register(PaymentCard)
class PaymentCardAdmin(admin.ModelAdmin):
    list_display = ('id', 'user', 'brand', 'last4', 'exp_month', 'exp_year', 'is_default', 'created_at')
    list_filter = ('brand', 'is_default')
    search_fields = ('user__username', 'user__email', 'last4')


admin.site.register(InstructorShopPhoto)
admin.site.register(CookingClass)
admin.site.register(CookingClassImage)
admin.site.register(CookingClassVideo)
admin.site.register(ClassAvailability)
admin.site.register(AvailabilitySlot)
admin.site.register(SavedClass)
admin.site.register(Booking)
admin.site.register(BookingReview)