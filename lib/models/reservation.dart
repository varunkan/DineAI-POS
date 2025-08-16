import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Represents a table reservation in the system
class Reservation {
  final String id;
  final String customerName;
  final String? customerPhone;
  final String? customerEmail;
  final DateTime reservationDate;
  final TimeOfDay reservationTime;
  final int partySize;
  final String? tableId;
  final ReservationStatus status;
  final String? specialRequests;
  final DateTime createdAt;
  final String? createdBy;
  final DateTime? confirmedAt;
  final DateTime? arrivedAt;
  final DateTime? seatedAt;
  final DateTime? completedAt;
  final String? notes;

  /// Creates a [Reservation].
  Reservation({
    String? id,
    required this.customerName,
    this.customerPhone,
    this.customerEmail,
    required this.reservationDate,
    required this.reservationTime,
    required this.partySize,
    this.tableId,
    this.status = ReservationStatus.pending,
    this.specialRequests,
    DateTime? createdAt,
    this.createdBy,
    this.confirmedAt,
    this.arrivedAt,
    this.seatedAt,
    this.completedAt,
    this.notes,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  /// Creates a [Reservation] from JSON.
  factory Reservation.fromJson(Map<String, dynamic> json) {
    return Reservation(
      id: json['id'] as String? ?? '',
      customerName: json['customerName'] as String? ?? '',
      customerPhone: json['customerPhone'] as String?,
      customerEmail: json['customerEmail'] as String?,
      reservationDate: json['reservationDate'] != null 
          ? DateTime.parse(json['reservationDate']) 
          : DateTime.now(),
      reservationTime: TimeOfDay(
        hour: json['reservationTimeHour'] as int? ?? 18,
        minute: json['reservationTimeMinute'] as int? ?? 0,
      ),
      partySize: json['partySize'] as int? ?? 1,
      tableId: json['tableId'] as String?,
      status: ReservationStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (json['status'] ?? 'pending'),
        orElse: () => ReservationStatus.pending,
      ),
      specialRequests: json['specialRequests'] as String?,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      createdBy: json['createdBy'] as String?,
      confirmedAt: json['confirmedAt'] != null 
          ? DateTime.parse(json['confirmedAt']) 
          : null,
      arrivedAt: json['arrivedAt'] != null 
          ? DateTime.parse(json['arrivedAt']) 
          : null,
      seatedAt: json['seatedAt'] != null 
          ? DateTime.parse(json['seatedAt']) 
          : null,
      completedAt: json['completedAt'] != null 
          ? DateTime.parse(json['completedAt']) 
          : null,
      notes: json['notes'] as String?,
    );
  }

  /// Converts this [Reservation] to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'reservationDate': reservationDate.toIso8601String(),
      'reservationTimeHour': reservationTime.hour,
      'reservationTimeMinute': reservationTime.minute,
      'partySize': partySize,
      'tableId': tableId,
      'status': status.toString().split('.').last,
      'specialRequests': specialRequests,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'confirmedAt': confirmedAt?.toIso8601String(),
      'arrivedAt': arrivedAt?.toIso8601String(),
      'seatedAt': seatedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'notes': notes,
    };
  }

  /// Returns a copy of this [Reservation] with updated fields.
  Reservation copyWith({
    String? id,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    DateTime? reservationDate,
    TimeOfDay? reservationTime,
    int? partySize,
    String? tableId,
    ReservationStatus? status,
    String? specialRequests,
    DateTime? createdAt,
    String? createdBy,
    DateTime? confirmedAt,
    DateTime? arrivedAt,
    DateTime? seatedAt,
    DateTime? completedAt,
    String? notes,
    bool clearTableId = false,
    bool clearCreatedBy = false,
  }) {
    return Reservation(
      id: id ?? this.id,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      reservationDate: reservationDate ?? this.reservationDate,
      reservationTime: reservationTime ?? this.reservationTime,
      partySize: partySize ?? this.partySize,
      tableId: clearTableId ? null : (tableId ?? this.tableId),
      status: status ?? this.status,
      specialRequests: specialRequests ?? this.specialRequests,
      createdAt: createdAt ?? this.createdAt,
      createdBy: clearCreatedBy ? null : (createdBy ?? this.createdBy),
      confirmedAt: confirmedAt ?? this.confirmedAt,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      seatedAt: seatedAt ?? this.seatedAt,
      completedAt: completedAt ?? this.completedAt,
      notes: notes ?? this.notes,
    );
  }

  /// Returns the formatted reservation time as a string
  String get formattedTime {
    final hour = reservationTime.hour == 0 ? 12 : 
                 reservationTime.hour > 12 ? reservationTime.hour - 12 : reservationTime.hour;
    final minute = reservationTime.minute.toString().padLeft(2, '0');
    final period = reservationTime.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  /// Returns the formatted reservation date
  String get formattedDate {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[reservationDate.month - 1]} ${reservationDate.day}, ${reservationDate.year}';
  }

  /// Returns true if the reservation is for today
  bool get isToday {
    final now = DateTime.now();
    return reservationDate.year == now.year &&
           reservationDate.month == now.month &&
           reservationDate.day == now.day;
  }

  /// Returns true if the reservation time has passed
  bool get isPastDue {
    final now = DateTime.now();
    final reservationDateTime = DateTime(
      reservationDate.year,
      reservationDate.month,
      reservationDate.day,
      reservationTime.hour,
      reservationTime.minute,
    );
    return now.isAfter(reservationDateTime.add(const Duration(minutes: 15)));
  }
}

/// Represents the status of a reservation
enum ReservationStatus {
  pending,     // Reservation created, awaiting confirmation
  confirmed,   // Reservation confirmed by restaurant
  arrived,     // Customer has arrived
  seated,      // Customer has been seated
  completed,   // Dining completed
  cancelled,   // Reservation cancelled
  noShow,      // Customer didn't show up
}

/// Extension methods for ReservationStatus
extension ReservationStatusExtension on ReservationStatus {
  /// Returns the display name for the status
  String get displayName {
    switch (this) {
      case ReservationStatus.pending:
        return 'Pending';
      case ReservationStatus.confirmed:
        return 'Confirmed';
      case ReservationStatus.arrived:
        return 'Arrived';
      case ReservationStatus.seated:
        return 'Seated';
      case ReservationStatus.completed:
        return 'Completed';
      case ReservationStatus.cancelled:
        return 'Cancelled';
      case ReservationStatus.noShow:
        return 'No Show';
    }
  }

  /// Returns the color associated with the status
  Color get color {
    switch (this) {
      case ReservationStatus.pending:
        return Colors.orange;
      case ReservationStatus.confirmed:
        return Colors.blue;
      case ReservationStatus.arrived:
        return Colors.green;
      case ReservationStatus.seated:
        return Colors.purple;
      case ReservationStatus.completed:
        return Colors.grey;
      case ReservationStatus.cancelled:
        return Colors.red;
      case ReservationStatus.noShow:
        return Colors.red.shade300;
    }
  }
} 