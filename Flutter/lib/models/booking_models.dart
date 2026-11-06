class InstructorProfile {
  final String id;
  final String userId;
  final String shopName;
  final String description;
  final String address;
  final String phone;
  final String email;
  final String avatar;
  final String coverPhoto;
  final List<String> shopPhotos;
  final bool isApproved;
  final String appliedAt;
  final String approvedAt;
  final String classTitle;
  final String classDescription;
  final String price;
  final String schedule;
  final List<String> tags;
  final List<String> dishes;
  final List<String> certificates;

  final String businessLicenseUrl;
  final String foodLicenseUrl;
  final String healthCertificateUrl;
  final String chefCertificationUrl;
  final String insuranceUrl;
  final String foodSafetyCertificateUrl;

  InstructorProfile({
    required this.id,
    required this.userId,
    required this.shopName,
    required this.description,
    required this.address,
    required this.phone,
    required this.email,
    required this.avatar,
    required this.coverPhoto,
    required this.shopPhotos,
    required this.isApproved,
    required this.appliedAt,
    required this.approvedAt,
    this.classTitle = '',
    this.classDescription = '',
    this.price = '',
    this.schedule = '',
    this.tags = const [],
    this.dishes = const [],
    this.certificates = const [],
    this.businessLicenseUrl = '',
    this.foodLicenseUrl = '',
    this.healthCertificateUrl = '',
    this.chefCertificationUrl = '',
    this.insuranceUrl = '',
    this.foodSafetyCertificateUrl = '',
  });

  factory InstructorProfile.fromJson(Map<String, dynamic> json) {
    return InstructorProfile(
      id: json['id'].toString(),
      userId: json['user_id']?.toString() ?? '',
      shopName: json['shop_name'] ?? '',
      description: json['description'] ?? '',
      address: json['address'] ?? '',
      phone: json['phone'] ?? '',
      email: json['email'] ?? '',
      avatar: json['avatar'] ?? '',
      coverPhoto: json['cover_photo'] ?? '',
      shopPhotos: (json['shop_photos'] as List?)
              ?.map((e) => e['image'] as String)
              .toList() ??
          [],
      isApproved: json['is_approved'] ?? false,
      appliedAt: json['applied_at'] ?? '',
      approvedAt: json['approved_at'] ?? '',
      classTitle: json['class_title'] ?? '',
      classDescription: json['class_description'] ?? '',
      price: json['price'] ?? '',
      schedule: json['schedule'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      dishes: List<String>.from(json['dishes'] ?? []),
      certificates: List<String>.from(json['certificates'] ?? []),
      businessLicenseUrl: json['business_license_url'] ?? '',
      foodLicenseUrl: json['food_license_url'] ?? '',
      healthCertificateUrl: json['health_certificate_url'] ?? '',
      chefCertificationUrl: json['chef_certification_url'] ?? '',
      insuranceUrl: json['insurance_url'] ?? '',
      foodSafetyCertificateUrl: json['food_safety_certificate_url'] ?? '',
    );
  }

  List<MapEntry<String, String>> get complianceDocuments {
    final list = <MapEntry<String, String>>[];
    if (businessLicenseUrl.isNotEmpty) {
      list.add(MapEntry('Business License', businessLicenseUrl));
    }
    if (foodLicenseUrl.isNotEmpty) {
      list.add(MapEntry('Food License', foodLicenseUrl));
    }
    if (healthCertificateUrl.isNotEmpty) {
      list.add(MapEntry('Health Certificate', healthCertificateUrl));
    }
    if (chefCertificationUrl.isNotEmpty) {
      list.add(MapEntry('Chef Certification', chefCertificationUrl));
    }
    if (insuranceUrl.isNotEmpty) {
      list.add(MapEntry('Insurance', insuranceUrl));
    }
    if (foodSafetyCertificateUrl.isNotEmpty) {
      list.add(MapEntry('Food Safety Certificate', foodSafetyCertificateUrl));
    }
    return list;
  }
}

class AvailabilitySlot {
  final String id;
  final int? dayOfWeek;
  final String startTime;
  final String endTime;
  final int maxSlots;

  AvailabilitySlot({
    required this.id,
    this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.maxSlots,
  });

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) {
    return AvailabilitySlot(
      id: json['id'].toString(),
      dayOfWeek: json['day_of_week'] is int ? json['day_of_week'] : null,
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      maxSlots: (json['max_slots'] ?? 0) is int
          ? json['max_slots']
          : int.tryParse(json['max_slots'].toString()) ?? 0,
    );
  }

  String get timeRange => '$startTime - $endTime';
}

class ClassAvailability {
  final String id;
  final String startDate;
  final String endDate;
  final bool isDailySame;
  final String setType;
  final List<AvailabilitySlot> slots;

  ClassAvailability({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.isDailySame,
    required this.setType,
    required this.slots,
  });

  factory ClassAvailability.fromJson(Map<String, dynamic> json) {
    return ClassAvailability(
      id: json['id'].toString(),
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      isDailySame: json['is_daily_same'] ?? true,
      setType: json['set_type'] ?? 'weekly',
      slots: (json['slots'] as List?)
              ?.map((e) => AvailabilitySlot.fromJson(e))
              .toList() ??
          [],
    );
  }
}

class ClassVideo {
  final String id;
  final String video;

  ClassVideo({required this.id, required this.video});

  factory ClassVideo.fromJson(Map<String, dynamic> json) {
    return ClassVideo(
      id: json['id'].toString(),
      video: json['video'] ?? '',
    );
  }
}

class CookingClassModel {
  final String id;
  final String title;
  final String description;
  final String image;
  final String coverVideo;
  final String location;
  final double price;
  final double rating;
  final String classType;
  final String schedule;
  final List<String> tags;
  final List<String> dishes;
  final List<String> certificates;
  final List<String> images;
  final List<ClassVideo> videos;
  final InstructorProfile instructor;
  final List<ClassAvailability> availabilities;
  final bool isSaved;
  final bool isAvailable;
  final bool isFullyBooked;
  final bool isActive;

  CookingClassModel({
    required this.id,
    required this.title,
    required this.description,
    required this.image,
    required this.coverVideo,
    required this.location,
    required this.price,
    required this.rating,
    required this.classType,
    required this.schedule,
    required this.tags,
    required this.dishes,
    required this.certificates,
    required this.images,
    required this.videos,
    required this.instructor,
    required this.availabilities,
    required this.isSaved,
    required this.isAvailable,
    required this.isFullyBooked,
    required this.isActive,
  });

  factory CookingClassModel.fromJson(Map<String, dynamic> json) {
    return CookingClassModel(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      image: json['image'] ?? '',
      coverVideo: json['cover_video'] ?? '',
      location: json['location'] ?? '',
      price: double.tryParse(json['price'].toString()) ?? 0,
      rating: (json['rating'] ?? 0).toDouble(),
      classType: json['class_type'] ?? 'in_person',
      schedule: json['schedule'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      dishes: List<String>.from(json['dishes'] ?? []),
      certificates: List<String>.from(json['certificates'] ?? []),
      images: (json['images'] as List?)
              ?.map((e) => e['image'] as String)
              .toList() ??
          [],
      videos: (json['videos'] as List?)
              ?.map((e) => ClassVideo.fromJson(e))
              .toList() ??
          [],
      instructor: InstructorProfile.fromJson(json['instructor'] ?? {}),
      availabilities: (json['availabilities'] as List?)
              ?.map((e) => ClassAvailability.fromJson(e))
              .toList() ??
          [],
      isSaved: json['is_saved'] ?? false,
      isAvailable: json['is_available'] ?? false,
      isFullyBooked: json['is_fully_booked'] ?? false,
      isActive: json['is_active'] ?? true,
    );
  }

  String get priceDisplay {
    if (price == price.roundToDouble()) {
      return 'RM ${price.toInt()}';
    }
    return 'RM ${price.toStringAsFixed(2)}';
  }
}

class BookingReviewModel {
  final String id;
  final int rating;
  final String comment;
  final String image;
  final String username;
  final String userAvatar;
  final String createdAt;

  BookingReviewModel({
    required this.id,
    required this.rating,
    required this.comment,
    required this.image,
    required this.username,
    required this.userAvatar,
    required this.createdAt,
  });

  factory BookingReviewModel.fromJson(Map<String, dynamic> json) {
    return BookingReviewModel(
      id: json['id'].toString(),
      rating: json['rating'] ?? 0,
      comment: json['comment'] ?? '',
      image: json['image'] ?? '',
      username: json['username'] ?? '',
      userAvatar: json['user_avatar'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }
}

class PaymentCard {
  final String id;
  final String brand;
  final String brandDisplay;
  final String last4;
  final int expMonth;
  final int expYear;
  final String holderName;
  final bool isDefault;

  PaymentCard({
    required this.id,
    required this.brand,
    required this.brandDisplay,
    required this.last4,
    required this.expMonth,
    required this.expYear,
    required this.holderName,
    required this.isDefault,
  });

  factory PaymentCard.fromJson(Map<String, dynamic> json) {
    return PaymentCard(
      id: json['id'].toString(),
      brand: json['brand'] ?? 'other',
      brandDisplay: json['brand_display'] ?? 'Card',
      last4: json['last4'] ?? '****',
      expMonth: json['exp_month'] ?? 1,
      expYear: json['exp_year'] ?? 2000,
      holderName: json['holder_name'] ?? '',
      isDefault: json['is_default'] ?? false,
    );
  }

  String get maskedNumber => '**** **** **** $last4';
  String get expiry =>
      '${expMonth.toString().padLeft(2, '0')}/${expYear.toString().substring(2)}';
}

class DaySlotOption {
  final String id;
  final String startTime;
  final String endTime;
  final int maxSlots;
  final int remaining;
  final bool started;

  DaySlotOption({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.maxSlots,
    required this.remaining,
    this.started = false,
  });

  factory DaySlotOption.fromJson(Map<String, dynamic> json) {
    return DaySlotOption(
      id: json['id'].toString(),
      startTime: json['start_time'] ?? '',
      endTime: json['end_time'] ?? '',
      maxSlots: json['max_slots'] ?? 0,
      remaining: json['remaining'] ?? 0,
      started: json['started'] == true,
    );
  }

  String get timeRange => '$startTime - $endTime';
  bool get isDisabled => remaining <= 0 || started;
}

class WeekDayOverview {
  final String date;
  final int remaining;

  WeekDayOverview({required this.date, required this.remaining});

  factory WeekDayOverview.fromJson(Map<String, dynamic> json) {
    return WeekDayOverview(
      date: json['date'] ?? '',
      remaining: json['remaining'] ?? 0,
    );
  }
}

class BookingModel {
  final String id;
  final CookingClassModel cookingClass;
  final String date;
  final String? startTime;
  final String? endTime;
  final int quantity;
  final String status;
  final String displayStatus;
  final String displayStatusForInstructor;
  final bool canCancel;
  final bool canComplete;
  final bool canRefund;
  final bool canReview;
  final String username;
  final String userUserId;
  final String userAvatar;
  final BookingReviewModel? review;
  final String paymentStatus;
  final PaymentCard? paymentCard;
  final Map<String, dynamic>? latestRefund;

  BookingModel({
    required this.id,
    required this.cookingClass,
    required this.date,
    this.startTime,
    this.endTime,
    this.quantity = 1,
    required this.status,
    required this.displayStatus,
    required this.displayStatusForInstructor,
    required this.canCancel,
    required this.canComplete,
    required this.canRefund,
    required this.canReview,
    required this.username,
    this.userUserId = '',
    required this.userAvatar,
    this.review,
    this.paymentStatus = 'unpaid',
    this.paymentCard,
    this.latestRefund,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'].toString(),
      cookingClass: CookingClassModel.fromJson(json['cooking_class'] ?? {}),
      date: json['date'] ?? '',
      startTime: json['start_time'],
      endTime: json['end_time'],
      quantity: json['quantity'] ?? 1,
      status: json['status'] ?? 'pending',
      displayStatus: json['display_status'] ?? 'pending',
      displayStatusForInstructor:
          json['display_status_for_instructor'] ?? 'pending',
      canCancel: json['can_cancel'] == true,
      canComplete: json['can_complete'] == true,
      canRefund: json['can_refund'] == true,
      canReview: json['can_review'] == true,
      username: json['username'] ?? '',
      userUserId: json['user_user_id']?.toString() ?? '',
      userAvatar: json['user_avatar'] ?? '',
      review: json['review'] != null
          ? BookingReviewModel.fromJson(json['review'])
          : null,
      paymentStatus: json['payment_status'] ?? 'unpaid',
      paymentCard: json['payment_card'] != null
          ? PaymentCard.fromJson(json['payment_card'])
          : null,
      latestRefund: json['latest_refund'] != null
          ? Map<String, dynamic>.from(json['latest_refund'])
          : null,
    );
  }

  String get refundStatus => latestRefund?['status']?.toString() ?? '';

  bool get hasActiveRefund =>
      refundStatus == 'pending_instructor' || refundStatus == 'pending_admin';

  bool get hasResolvedRefund =>
      refundStatus == 'resolved_full' ||
      refundStatus == 'resolved_half' ||
      refundStatus == 'resolved_none';
}

class RefundRequestModel {
  final String id;
  final String bookingId;
  final String username;
  final String userUserId;
  final String userAvatar;
  final String userReason;
  final String userNote;
  final String userImage;
  final String instructorResponse;
  final String instructorImage;
  final bool? instructorAgrees;
  final String? instructorRespondedAt;
  final String status;
  final String adminDecisionAmount;
  final String adminNote;
  final String? adminResolvedAt;
  final double? refundAmount;
  final String? deadline;
  final Map<String, dynamic> bookingInfo;
  final String instructorUserId;
  final String createdAt;

  RefundRequestModel({
    required this.id,
    required this.bookingId,
    required this.username,
    this.userUserId = '',
    required this.userAvatar,
    required this.userReason,
    required this.userNote,
    required this.userImage,
    required this.instructorResponse,
    required this.instructorImage,
    this.instructorAgrees,
    this.instructorRespondedAt,
    required this.status,
    required this.adminDecisionAmount,
    required this.adminNote,
    this.adminResolvedAt,
    this.refundAmount,
    this.deadline,
    required this.bookingInfo,
    required this.instructorUserId,
    required this.createdAt,
  });

  factory RefundRequestModel.fromJson(Map<String, dynamic> json) {
    return RefundRequestModel(
      id: json['id'].toString(),
      bookingId: json['booking']?.toString() ?? '',
      username: json['username'] ?? '',
      userUserId: json['user_user_id']?.toString() ?? '',
      userAvatar: json['user_avatar'] ?? '',
      userReason: json['user_reason'] ?? '',
      userNote: json['user_note'] ?? '',
      userImage: json['user_image'] ?? '',
      instructorResponse: json['instructor_response'] ?? '',
      instructorImage: json['instructor_image'] ?? '',
      instructorAgrees: json['instructor_agrees'] is bool
          ? json['instructor_agrees']
          : null,
      instructorRespondedAt: json['instructor_responded_at'],
      status: json['status'] ?? 'pending_instructor',
      adminDecisionAmount: json['admin_decision_amount'] ?? '',
      adminNote: json['admin_note'] ?? '',
      adminResolvedAt: json['admin_resolved_at'],
      refundAmount: json['refund_amount'] != null
          ? double.tryParse(json['refund_amount'].toString())
          : null,
      deadline: json['deadline'],
      bookingInfo: Map<String, dynamic>.from(json['booking_info'] ?? {}),
      instructorUserId: json['instructor_user_id'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }

  String get reasonLabel {
    const map = {
      'not_as_described': 'Class not as described',
      'instructor_no_show': 'Instructor did not show up',
      'quality_issue': 'Poor quality / not satisfied',
      'personal_emergency': 'Personal emergency',
      'other': 'Other',
    };
    return map[userReason] ?? userReason;
  }

  String get statusLabel {
    const map = {
      'pending_instructor': 'Pending Instructor',
      'pending_admin': 'Pending Admin Review',
      'resolved_full': 'Full Refund Approved',
      'resolved_half': 'Half Refund Approved',
      'resolved_none': 'Refund Rejected',
    };
    return map[status] ?? status;
  }
}