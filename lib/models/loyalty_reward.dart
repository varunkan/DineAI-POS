class LoyaltyReward {
  final String id;
  final String name;
  final String description;
  final double pointsRequired;
  final double value;
  final String type; // 'discount', 'freeItem', 'percentage'
  final bool isActive;
  final DateTime? expiryDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  LoyaltyReward({
    required this.id,
    required this.name,
    required this.description,
    required this.pointsRequired,
    required this.value,
    required this.type,
    required this.isActive,
    this.expiryDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LoyaltyReward.fromJson(Map<String, dynamic> json) {
    return LoyaltyReward(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      pointsRequired: (json['points_required'] as num).toDouble(),
      value: (json['value'] as num).toDouble(),
      type: json['type'] as String,
      isActive: (json['is_active'] as int?) == 1,
      expiryDate: json['expiry_date'] != null ? DateTime.parse(json['expiry_date'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'points_required': pointsRequired,
      'value': value,
      'type': type,
      'is_active': isActive ? 1 : 0,
      'expiry_date': expiryDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  @override
  String toString() {
    return 'LoyaltyReward(id: $id, name: $name, pointsRequired: $pointsRequired, value: $value)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LoyaltyReward && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 