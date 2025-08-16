class LoyaltyTransaction {
  final String id;
  final String customerId;
  final double points;
  final String type; // 'earned' or 'redeemed'
  final String description;
  final DateTime createdAt;

  LoyaltyTransaction({
    required this.id,
    required this.customerId,
    required this.points,
    required this.type,
    required this.description,
    required this.createdAt,
  });

  factory LoyaltyTransaction.fromJson(Map<String, dynamic> json) {
    return LoyaltyTransaction(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      points: (json['points'] as num).toDouble(),
      type: json['type'] as String,
      description: json['description'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'points': points,
      'type': type,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'LoyaltyTransaction(id: $id, customerId: $customerId, points: $points, type: $type)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LoyaltyTransaction && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 