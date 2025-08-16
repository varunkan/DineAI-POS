

/// Store/Restaurant model for multi-tenant POS system
class Store {
  final String id;
  final String name;
  final String code; // Unique store code (e.g., "REST001")
  final String address;
  final String phone;
  final String email;
  final String timezone;
  final String currency;
  final String databasePath; // Store-specific database path
  final StoreSettings settings;
  final StoreBranding branding;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Store({
    required this.id,
    required this.name,
    required this.code,
    required this.address,
    required this.phone,
    required this.email,
    this.timezone = 'America/Toronto',
    this.currency = 'CAD',
    required this.databasePath,
    required this.settings,
    required this.branding,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      id: json['id'],
      name: json['name'],
      code: json['code'],
      address: json['address'],
      phone: json['phone'],
      email: json['email'],
      timezone: json['timezone'] ?? 'America/Toronto',
      currency: json['currency'] ?? 'CAD',
      databasePath: json['database_path'],
      settings: StoreSettings.fromJson(json['settings'] ?? {}),
      branding: StoreBranding.fromJson(json['branding'] ?? {}),
      isActive: (json['is_active'] ?? 1) == 1,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'address': address,
      'phone': phone,
      'email': email,
      'timezone': timezone,
      'currency': currency,
      'database_path': databasePath,
      'settings': settings.toJson(),
      'branding': branding.toJson(),
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Store copyWith({
    String? name,
    String? code,
    String? address,
    String? phone,
    String? email,
    String? timezone,
    String? currency,
    String? databasePath,
    StoreSettings? settings,
    StoreBranding? branding,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return Store(
      id: id,
      name: name ?? this.name,
      code: code ?? this.code,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      timezone: timezone ?? this.timezone,
      currency: currency ?? this.currency,
      databasePath: databasePath ?? this.databasePath,
      settings: settings ?? this.settings,
      branding: branding ?? this.branding,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Store && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Store(id: $id, name: $name, code: $code)';
}

/// Store-specific settings and configuration
class StoreSettings {
  final double taxRate;
  final double serviceChargeRate;
  final bool enableTipping;
  final double defaultTipRate;
  final List<double> tipPresets;
  final String receiptHeader;
  final String receiptFooter;
  final bool enableInventoryTracking;
  final bool enableReservations;
  final bool enableDelivery;
  final Map<String, dynamic> customSettings;

  StoreSettings({
    this.taxRate = 0.13, // Default HST rate for Ontario
    this.serviceChargeRate = 0.0,
    this.enableTipping = true,
    this.defaultTipRate = 0.15,
    this.tipPresets = const [0.10, 0.15, 0.18, 0.20],
    this.receiptHeader = '',
    this.receiptFooter = 'Thank you for dining with us!',
    this.enableInventoryTracking = true,
    this.enableReservations = true,
    this.enableDelivery = false,
    this.customSettings = const {},
  });

  factory StoreSettings.fromJson(Map<String, dynamic> json) {
    return StoreSettings(
      taxRate: (json['tax_rate'] ?? 0.13).toDouble(),
      serviceChargeRate: (json['service_charge_rate'] ?? 0.0).toDouble(),
      enableTipping: json['enable_tipping'] ?? true,
      defaultTipRate: (json['default_tip_rate'] ?? 0.15).toDouble(),
      tipPresets: (json['tip_presets'] as List<dynamic>?)
          ?.map((e) => (e as num).toDouble())
          .toList() ?? [0.10, 0.15, 0.18, 0.20],
      receiptHeader: json['receipt_header'] ?? '',
      receiptFooter: json['receipt_footer'] ?? 'Thank you for dining with us!',
      enableInventoryTracking: json['enable_inventory_tracking'] ?? true,
      enableReservations: json['enable_reservations'] ?? true,
      enableDelivery: json['enable_delivery'] ?? false,
      customSettings: Map<String, dynamic>.from(json['custom_settings'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tax_rate': taxRate,
      'service_charge_rate': serviceChargeRate,
      'enable_tipping': enableTipping,
      'default_tip_rate': defaultTipRate,
      'tip_presets': tipPresets,
      'receipt_header': receiptHeader,
      'receipt_footer': receiptFooter,
      'enable_inventory_tracking': enableInventoryTracking,
      'enable_reservations': enableReservations,
      'enable_delivery': enableDelivery,
      'custom_settings': customSettings,
    };
  }
}

/// Store branding and visual customization
class StoreBranding {
  final String logoPath;
  final String primaryColor;
  final String secondaryColor;
  final String backgroundColor;
  final String textColor;
  final String fontFamily;
  final Map<String, dynamic> customBranding;

  StoreBranding({
    this.logoPath = '',
    this.primaryColor = '#2196F3',
    this.secondaryColor = '#FF9800',
    this.backgroundColor = '#FFFFFF',
    this.textColor = '#000000',
    this.fontFamily = 'Default',
    this.customBranding = const {},
  });

  factory StoreBranding.fromJson(Map<String, dynamic> json) {
    return StoreBranding(
      logoPath: json['logo_path'] ?? '',
      primaryColor: json['primary_color'] ?? '#2196F3',
      secondaryColor: json['secondary_color'] ?? '#FF9800',
      backgroundColor: json['background_color'] ?? '#FFFFFF',
      textColor: json['text_color'] ?? '#000000',
      fontFamily: json['font_family'] ?? 'Default',
      customBranding: Map<String, dynamic>.from(json['custom_branding'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'logo_path': logoPath,
      'primary_color': primaryColor,
      'secondary_color': secondaryColor,
      'background_color': backgroundColor,
      'text_color': textColor,
      'font_family': fontFamily,
      'custom_branding': customBranding,
    };
  }
}

/// Store authentication credentials for login
class StoreAuth {
  final String storeId;
  final String storeCode;
  final String username;
  final String password;
  final DateTime? lastLoginAt;

  StoreAuth({
    required this.storeId,
    required this.storeCode,
    required this.username,
    required this.password,
    this.lastLoginAt,
  });

  factory StoreAuth.fromJson(Map<String, dynamic> json) {
    return StoreAuth(
      storeId: json['store_id'],
      storeCode: json['store_code'],
      username: json['username'],
      password: json['password'],
      lastLoginAt: json['last_login_at'] != null 
          ? DateTime.parse(json['last_login_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'store_id': storeId,
      'store_code': storeCode,
      'username': username,
      'password': password,
      'last_login_at': lastLoginAt?.toIso8601String(),
    };
  }
} 