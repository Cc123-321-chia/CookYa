from django.urls import path
from . import views

urlpatterns = [
    # Classes - browse
    path('classes/', views.list_classes),
    path('classes/<int:class_id>/', views.class_detail),
    path('classes/<int:class_id>/save/', views.toggle_save),
    path('classes/<int:class_id>/book/', views.create_booking),
    path('classes/<int:class_id>/reviews/', views.class_reviews),
    path('classes/<int:class_id>/availability/', views.availability),
    path('classes/<int:class_id>/day-slots/', views.class_day_slots),
    path('classes/<int:class_id>/week-overview/', views.class_week_overview),
    path('classes/<int:class_id>/month-overview/', views.class_month_overview),

    # Classes - instructor CRUD
    path('instructor/classes/create/', views.create_class),
    path('instructor/classes/<int:class_id>/update/', views.update_class),
    path('instructor/classes/<int:class_id>/delete/', views.delete_class),
    path('instructor/bookings/<int:booking_id>/confirm/', views.instructor_confirm_booking),
    path('instructor/bookings/<int:booking_id>/reject/', views.instructor_reject_booking),
    path('instructor/bookings/<int:booking_id>/cancel/', views.instructor_cancel_booking),

    # My bookings / saved
    path('my-bookings/', views.my_bookings),
    path('my-saved/', views.my_saved_classes),
    path('bookings/<int:booking_id>/cancel/', views.cancel_booking),
    path('bookings/<int:booking_id>/cancel-unpaid/', views.cancel_unpaid_booking),
    path('bookings/<int:booking_id>/review/', views.create_review),
    path('bookings/<int:booking_id>/complete/', views.complete_booking),

    # Payment
    path('payment-cards/', views.payment_cards),
    path('payment-cards/<int:card_id>/', views.delete_payment_card),
    path('payment-cards/<int:card_id>/default/', views.set_default_payment_card),
    path('bookings/<int:booking_id>/pay/', views.pay_booking),

    # Instructor orders
    path('instructor/orders/', views.instructor_orders),

    # Instructor profile
    path('instructor/profile/', views.my_instructor_profile),
    path('instructor/profile/<int:instructor_id>/', views.instructor_profile_detail),
    path('instructor/apply/', views.apply_instructor),
    path('instructor/edit/', views.edit_instructor_profile),

    # Availability management
    path('availability/<int:availability_id>/delete/', views.delete_availability),
    path('availability/<int:availability_id>/update/', views.update_availability),
    path('slots/<int:slot_id>/delete/', views.delete_availability_slot),

    # Admin instructor applications
    path('admin/instructor-applications/', views.admin_instructor_applications),
    path('admin/instructor-applications/<int:application_id>/', views.admin_instructor_application_detail),
    path('admin/instructor-applications/<int:application_id>/approve/', views.admin_approve_instructor),
    path('admin/instructor-applications/<int:application_id>/reject/', views.admin_reject_instructor),

    # Refund flow
    path('bookings/<int:booking_id>/refund/', views.request_refund),
    path('refunds/<uuid:refund_id>/', views.refund_detail),
    path('refunds/<uuid:refund_id>/respond/', views.instructor_respond_refund),
    path('my-refunds/', views.my_refund_requests),

    # Admin
    path('admin/refunds/', views.admin_refund_list),
    path('admin/refunds/<uuid:refund_id>/resolve/', views.admin_resolve_refund),
]