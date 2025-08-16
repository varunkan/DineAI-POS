enum UserRole {
  admin,
  server,
  manager,
  cashier,
}

/// Represents a user in the POS system.
class User {
  final String id;
  final String name;
  final UserRole role;
  final String pin;
  final bool isActive;
  final bool adminPanelAccess;
  final DateTime createdAt;
  final DateTime? lastLogin;

  /// Creates a [User].
  User({
    required this.id,
    required this.name,
    required this.role,
    required this.pin,
    this.isActive = true,
    this.adminPanelAccess = false,
    DateTime? createdAt,
    this.lastLogin,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Returns true if the user is an admin.
  bool get isAdmin => role == UserRole.admin;

  /// Returns true if the user can access the admin panel.
  bool get canAccessAdminPanel => adminPanelAccess;

  /// Creates a [User] from JSON, with null safety and defaults.
  factory User.fromJson(Map<String, dynamic> json) {
    try {
      return User(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        role: UserRole.values.firstWhere(
          (e) => e.toString().split('.').last == (json['role'] ?? '').toString(),
          orElse: () => UserRole.server,
        ),
        pin: json['pin'] as String? ?? '0000',
        isActive: json['is_active'] is bool 
            ? json['is_active'] as bool
            : (json['is_active'] as int? ?? 1) == 1,
        adminPanelAccess: json['admin_panel_access'] is bool 
            ? json['admin_panel_access'] as bool
            : (json['admin_panel_access'] as int? ?? 0) == 1,
        createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']) ?? DateTime.now() : DateTime.now(),
        lastLogin: json['last_login'] != null ? DateTime.tryParse(json['last_login']) : null,
      );
    } catch (e) {
      return User(id: '', name: '', role: UserRole.server, pin: '0000');
    }
  }

  /// Converts this [User] to JSON with SQLite-compatible field names and types.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role.toString().split('.').last,
      'pin': pin,
      'is_active': isActive ? 1 : 0,
      'admin_panel_access': adminPanelAccess ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
    };
  }

  /// Returns a copy of this [User] with updated fields.
  User copyWith({
    String? id,
    String? name,
    UserRole? role,
    String? pin,
    bool? isActive,
    bool? adminPanelAccess,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      pin: pin ?? this.pin,
      isActive: isActive ?? this.isActive,
      adminPanelAccess: adminPanelAccess ?? this.adminPanelAccess,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
} 