// screens/booking/booking_status.dart
import 'package:flutter/material.dart';

enum BookingStatus {
  pending,
  confirmed,
  attending,
  completed,
  cancelled,
  rejected,
}

extension BookingStatusExtension on BookingStatus {
  String get label {
    switch (this) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.attending:
        return 'Attending';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.rejected:
        return 'Rejected';
    }
  }

  String get displayText {
    switch (this) {
      case BookingStatus.pending:
        return 'Awaiting Confirmation';
      case BookingStatus.confirmed:
        return 'Booking Confirmed!';
      case BookingStatus.attending:
        return "You're Attending!";
      case BookingStatus.completed:
        return 'Class Completed';
      case BookingStatus.cancelled:
        return 'Booking Cancelled';
      case BookingStatus.rejected:
        return 'Booking Rejected';
    }
  }

  String get subText {
    switch (this) {
      case BookingStatus.pending:
        return 'The shop will confirm your booking within 24 hours';
      case BookingStatus.confirmed:
        return 'Please confirm your attendance 24 hours before the class';
      case BookingStatus.attending:
        return 'You have confirmed your attendance';
      case BookingStatus.completed:
        return 'Thank you for attending!';
      case BookingStatus.cancelled:
        return 'This booking has been cancelled';
      case BookingStatus.rejected:
        return 'The shop could not accept your booking';
    }
  }

  Color get color {
    switch (this) {
      case BookingStatus.pending:
        return Colors.orange;
      case BookingStatus.confirmed:
        return Colors.green;
      case BookingStatus.attending:
        return Colors.blue;
      case BookingStatus.completed:
        return Colors.grey;
      case BookingStatus.cancelled:
        return Colors.red;
      case BookingStatus.rejected:
        return Colors.red.shade700;
    }
  }

  IconData get icon {
    switch (this) {
      case BookingStatus.pending:
        return Icons.hourglass_top;
      case BookingStatus.confirmed:
        return Icons.check_circle;
      case BookingStatus.attending:
        return Icons.event_available;
      case BookingStatus.completed:
        return Icons.done_all;
      case BookingStatus.cancelled:
        return Icons.cancel;
      case BookingStatus.rejected:
        return Icons.block;
    }
  }
}