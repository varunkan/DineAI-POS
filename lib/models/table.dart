import 'package:uuid/uuid.dart';

enum TableStatus { available, occupied, reserved, cleaning }

/// Represents a restaurant table in the POS system.
class Table {
  final String id;
  final int number;
  final int capacity;
  final TableStatus status;
  final String? userId;
  final String? customerName;
  final DateTime? occupiedAt;
  final DateTime? reservedAt;
  final Map<String, dynamic> metadata;

  /// Creates a [Table].
  Table({
    String? id,
    required this.number,
    required this.capacity,
    this.status = TableStatus.available,
    this.userId,
    this.customerName,
    this.occupiedAt,
    this.reservedAt,
    this.metadata = const {},
  }) : id = id ?? const Uuid().v4();

  /// Returns a copy of this [Table] with updated fields.
  Table copyWith({
    String? id,
    int? number,
    int? capacity,
    TableStatus? status,
    String? userId,
    String? customerName,
    DateTime? occupiedAt,
    DateTime? reservedAt,
    Map<String, dynamic>? metadata,
  }) {
    return Table(
      id: id ?? this.id,
      number: number ?? this.number,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      userId: userId ?? this.userId,
      customerName: customerName ?? this.customerName,
      occupiedAt: occupiedAt ?? this.occupiedAt,
      reservedAt: reservedAt ?? this.reservedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Creates a [Table] from JSON, with null safety and defaults.
  factory Table.fromJson(Map<String, dynamic> json) {
    try {
      return Table(
        id: json['id'] as String? ?? const Uuid().v4(),
        number: json['number'] is int ? json['number'] : int.tryParse(json['number']?.toString() ?? '') ?? 0,
        capacity: json['capacity'] is int ? json['capacity'] : int.tryParse(json['capacity']?.toString() ?? '') ?? 4,
        status: TableStatus.values.firstWhere(
          (e) => e.toString().split('.').last == (json['status'] ?? '').toString(),
          orElse: () => TableStatus.available,
        ),
        userId: json['userId'] as String?,
        customerName: json['customerName'] as String?,
        occupiedAt: json['occupiedAt'] != null ? DateTime.tryParse(json['occupiedAt']) : null,
        reservedAt: json['reservedAt'] != null ? DateTime.tryParse(json['reservedAt']) : null,
        metadata: json['metadata'] is Map<String, dynamic> ? Map<String, dynamic>.from(json['metadata']) : {},
      );
    } catch (e) {
      return Table(number: 0, capacity: 4);
    }
  }

  /// Converts this [Table] to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'number': number,
      'capacity': capacity,
      'status': status.toString().split('.').last,
      'userId': userId,
      'customerName': customerName,
      'occupiedAt': occupiedAt?.toIso8601String(),
      'reservedAt': reservedAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  // Helper methods
  bool get isAvailable => status == TableStatus.available;
  bool get isOccupied => status == TableStatus.occupied;
  bool get isReserved => status == TableStatus.reserved;
  bool get isCleaning => status == TableStatus.cleaning;

  Duration get occupancyDuration {
    if (occupiedAt != null) {
      return DateTime.now().difference(occupiedAt!);
    }
    return Duration.zero;
  }

  String get displayName => 'Table $number';
} 