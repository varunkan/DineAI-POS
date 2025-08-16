import 'dart:convert';
import 'user.dart'; // Import UserRole from existing user model

/// Restaurant model for multi-tenant POS system
/// Each restaurant is a separate tenant with its own database and users
class Restaurant {
  final String id;
  final String name;
  final String businessType;
  final String address;
  final String phone;
  final String email;
  final String adminUserId;
  final String adminPassword; // Will be hashed in production
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isActive;
  final String databaseName;
  final Map<String, dynamic> settings;

  Restaurant({
    required this.id,
    required this.name,
    required this.businessType,
    required this.address,
    required this.phone,
    required this.email,
    required this.adminUserId,
    required this.adminPassword,
    required this.createdAt,
    required this.updatedAt,
    this.isActive = true,
    required this.databaseName,
    this.settings = const {},
  });

  /// Create a copy of this restaurant with updated fields
  Restaurant copyWith({
    String? id,
    String? name,
    String? businessType,
    String? address,
    String? phone,
    String? email,
    String? adminUserId,
    String? adminPassword,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    String? databaseName,
    Map<String, dynamic>? settings,
  }) {
    return Restaurant(
      id: id ?? this.id,
      name: name ?? this.name,
      businessType: businessType ?? this.businessType,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      adminUserId: adminUserId ?? this.adminUserId,
      adminPassword: adminPassword ?? this.adminPassword,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      databaseName: databaseName ?? this.databaseName,
      settings: settings ?? this.settings,
    );
  }

  /// Convert restaurant to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'business_type': businessType,
      'address': address,
      'phone': phone,
      'email': email,
      'admin_user_id': adminUserId,
      'admin_password': adminPassword,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'is_active': isActive ? 1 : 0,
      'database_name': databaseName,
      'settings': jsonEncode(settings),
    };
  }

  /// Create restaurant from JSON data
  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'] as String,
      name: json['name'] as String,
      businessType: json['business_type'] as String,
      address: json['address'] as String,
      phone: json['phone'] as String,
      email: json['email'] as String,
      adminUserId: json['admin_user_id'] as String,
      adminPassword: json['admin_password'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isActive: json['is_active'] is bool 
          ? json['is_active'] as bool
          : (json['is_active'] as int? ?? 1) == 1,
      databaseName: json['database_name'] as String,
      settings: json['settings'] != null 
        ? jsonDecode(json['settings'] as String) 
        : <String, dynamic>{},
    );
  }

  @override
  String toString() {
    return 'Restaurant(id: $id, name: $name, businessType: $businessType, isActive: $isActive)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Restaurant && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Authentication session for a restaurant user
class RestaurantSession {
  final String restaurantId;
  final String userId;
  final String userName;
  final UserRole userRole;
  final DateTime loginTime;
  final DateTime? lastActivity;
  final bool isActive;

  RestaurantSession({
    required this.restaurantId,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.loginTime,
    this.lastActivity,
    this.isActive = true,
  });

  RestaurantSession copyWith({
    String? restaurantId,
    String? userId,
    String? userName,
    UserRole? userRole,
    DateTime? loginTime,
    DateTime? lastActivity,
    bool? isActive,
  }) {
    return RestaurantSession(
      restaurantId: restaurantId ?? this.restaurantId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userRole: userRole ?? this.userRole,
      loginTime: loginTime ?? this.loginTime,
      lastActivity: lastActivity ?? this.lastActivity,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'restaurant_id': restaurantId,
      'user_id': userId,
      'user_name': userName,
      'user_role': userRole.toString(),
      'login_time': loginTime.toIso8601String(),
      'last_activity': lastActivity?.toIso8601String(),
      'is_active': isActive ? 1 : 0,
    };
  }

  factory RestaurantSession.fromJson(Map<String, dynamic> json) {
    return RestaurantSession(
      restaurantId: json['restaurant_id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String,
      userRole: UserRole.values.firstWhere(
        (role) => role.toString() == json['user_role'],
        orElse: () => UserRole.server,
      ),
      loginTime: DateTime.parse(json['login_time'] as String),
      lastActivity: json['last_activity'] != null 
        ? DateTime.parse(json['last_activity'] as String)
        : null,
      isActive: json['is_active'] is bool 
          ? json['is_active'] as bool
          : (json['is_active'] as int? ?? 1) == 1,
    );
  }
} 