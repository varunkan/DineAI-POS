/// Represents application settings for the POS system.
class AppSettings {
  final String businessName;
  final String businessAddress;
  final String businessPhone;
  final String businessEmail;
  final String currency;
  final String currencySymbol;
  final double taxRate;
  final String taxName;
  final bool enableTax;
  final bool enableTips;
  final List<double> tipOptions;
  final String defaultPrinterIp;
  final int defaultPrinterPort;
  final String themeMode; // 'light', 'dark', 'system'
  final String primaryColor;
  final String accentColor;
  final bool enableSoundEffects;
  final bool enableNotifications;
  final String language;
  final String dateFormat;
  final String timeFormat;
  final bool autoSaveOrders;
  final int autoSaveInterval; // in minutes
  final bool enableOrderNumbering;
  final String orderNumberPrefix;
  final bool enableTableNumbering;
  final String tableNumberPrefix;
  final bool enableReceiptHeader;
  final bool enableReceiptFooter;
  final String receiptHeaderText;
  final String receiptFooterText;
  final bool enableKitchenPrinting;
  final bool enableCustomerReceipt;
  final int maxTablesPerUser;
  final bool enableUserManagement;
  final bool enableCategoryManagement;
  final bool enableMenuItemManagement;
  final List<String> enabledFeatures;

  /// Creates an [AppSettings] instance.
  AppSettings({
    this.businessName = 'Restaurant POS',
    this.businessAddress = '',
    this.businessPhone = '',
    this.businessEmail = '',
    this.currency = 'USD',
    this.currencySymbol = '\$',
    this.taxRate = 13.0,
    this.taxName = 'HST',
    this.enableTax = true,
    this.enableTips = false,
    this.tipOptions = const [10.0, 15.0, 18.0, 20.0],
    this.defaultPrinterIp = '',
    this.defaultPrinterPort = 9100,
    this.themeMode = 'system',
    this.primaryColor = '#6750A4',
    this.accentColor = '#FF6B6B',
    this.enableSoundEffects = true,
    this.enableNotifications = true,
    this.language = 'en',
    this.dateFormat = 'MM/dd/yyyy',
    this.timeFormat = 'hh:mm a',
    this.autoSaveOrders = true,
    this.autoSaveInterval = 5,
    this.enableOrderNumbering = true,
    this.orderNumberPrefix = 'ORD',
    this.enableTableNumbering = true,
    this.tableNumberPrefix = 'TBL',
    this.enableReceiptHeader = true,
    this.enableReceiptFooter = true,
    this.receiptHeaderText = 'Thank you for dining with us!',
    this.receiptFooterText = 'Please come again!',
    this.enableKitchenPrinting = true,
    this.enableCustomerReceipt = true,
    this.maxTablesPerUser = 10,
    this.enableUserManagement = true,
    this.enableCategoryManagement = true,
    this.enableMenuItemManagement = true,
    this.enabledFeatures = const [
      'user_management',
      'category_management',
      'menu_management',
      'table_management',
      'order_management',
      'printing',
      'settings',
    ],
  });

  /// Creates [AppSettings] from JSON, with null safety and defaults.
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      businessName: json['businessName'] ?? 'Restaurant POS',
      businessAddress: json['businessAddress'] ?? '',
      businessPhone: json['businessPhone'] ?? '',
      businessEmail: json['businessEmail'] ?? '',
      currency: json['currency'] ?? 'USD',
      currencySymbol: json['currencySymbol'] ?? '\$',
      taxRate: (json['taxRate'] ?? 13.0).toDouble(),
      taxName: json['taxName'] ?? 'HST',
      enableTax: json['enableTax'] ?? true,
      enableTips: json['enableTips'] ?? false,
      tipOptions: json['tipOptions'] is List ? List<double>.from(json['tipOptions']) : [10.0, 15.0, 18.0, 20.0],
      defaultPrinterIp: json['defaultPrinterIp'] ?? '',
      defaultPrinterPort: json['defaultPrinterPort'] ?? 9100,
      themeMode: json['themeMode'] ?? 'system',
      primaryColor: json['primaryColor'] ?? '#6750A4',
      accentColor: json['accentColor'] ?? '#FF6B6B',
      enableSoundEffects: json['enableSoundEffects'] ?? true,
      enableNotifications: json['enableNotifications'] ?? true,
      language: json['language'] ?? 'en',
      dateFormat: json['dateFormat'] ?? 'MM/dd/yyyy',
      timeFormat: json['timeFormat'] ?? 'hh:mm a',
      autoSaveOrders: json['autoSaveOrders'] ?? true,
      autoSaveInterval: json['autoSaveInterval'] ?? 5,
      enableOrderNumbering: json['enableOrderNumbering'] ?? true,
      orderNumberPrefix: json['orderNumberPrefix'] ?? 'ORD',
      enableTableNumbering: json['enableTableNumbering'] ?? true,
      tableNumberPrefix: json['tableNumberPrefix'] ?? 'TBL',
      enableReceiptHeader: json['enableReceiptHeader'] ?? true,
      enableReceiptFooter: json['enableReceiptFooter'] ?? true,
      receiptHeaderText: json['receiptHeaderText'] ?? 'Thank you for dining with us!',
      receiptFooterText: json['receiptFooterText'] ?? 'Please come again!',
      enableKitchenPrinting: json['enableKitchenPrinting'] ?? true,
      enableCustomerReceipt: json['enableCustomerReceipt'] ?? true,
      maxTablesPerUser: json['maxTablesPerUser'] ?? 10,
      enableUserManagement: json['enableUserManagement'] ?? true,
      enableCategoryManagement: json['enableCategoryManagement'] ?? true,
      enableMenuItemManagement: json['enableMenuItemManagement'] ?? true,
      enabledFeatures: json['enabledFeatures'] is List ? List<String>.from(json['enabledFeatures']) : [
        'user_management',
        'category_management',
        'menu_management',
        'table_management',
        'order_management',
        'printing',
        'settings',
      ],
    );
  }

  /// Converts this [AppSettings] to JSON.
  Map<String, dynamic> toJson() {
    return {
      'businessName': businessName,
      'businessAddress': businessAddress,
      'businessPhone': businessPhone,
      'businessEmail': businessEmail,
      'currency': currency,
      'currencySymbol': currencySymbol,
      'taxRate': taxRate,
      'taxName': taxName,
      'enableTax': enableTax,
      'enableTips': enableTips,
      'tipOptions': tipOptions,
      'defaultPrinterIp': defaultPrinterIp,
      'defaultPrinterPort': defaultPrinterPort,
      'themeMode': themeMode,
      'primaryColor': primaryColor,
      'accentColor': accentColor,
      'enableSoundEffects': enableSoundEffects,
      'enableNotifications': enableNotifications,
      'language': language,
      'dateFormat': dateFormat,
      'timeFormat': timeFormat,
      'autoSaveOrders': autoSaveOrders,
      'autoSaveInterval': autoSaveInterval,
      'enableOrderNumbering': enableOrderNumbering,
      'orderNumberPrefix': orderNumberPrefix,
      'enableTableNumbering': enableTableNumbering,
      'tableNumberPrefix': tableNumberPrefix,
      'enableReceiptHeader': enableReceiptHeader,
      'enableReceiptFooter': enableReceiptFooter,
      'receiptHeaderText': receiptHeaderText,
      'receiptFooterText': receiptFooterText,
      'enableKitchenPrinting': enableKitchenPrinting,
      'enableCustomerReceipt': enableCustomerReceipt,
      'maxTablesPerUser': maxTablesPerUser,
      'enableUserManagement': enableUserManagement,
      'enableCategoryManagement': enableCategoryManagement,
      'enableMenuItemManagement': enableMenuItemManagement,
      'enabledFeatures': enabledFeatures,
    };
  }

  /// Returns a copy of this [AppSettings] with updated fields.
  AppSettings copyWith({
    String? businessName,
    String? businessAddress,
    String? businessPhone,
    String? businessEmail,
    String? currency,
    String? currencySymbol,
    double? taxRate,
    String? taxName,
    bool? enableTax,
    bool? enableTips,
    List<double>? tipOptions,
    String? defaultPrinterIp,
    int? defaultPrinterPort,
    String? themeMode,
    String? primaryColor,
    String? accentColor,
    bool? enableSoundEffects,
    bool? enableNotifications,
    String? language,
    String? dateFormat,
    String? timeFormat,
    bool? autoSaveOrders,
    int? autoSaveInterval,
    bool? enableOrderNumbering,
    String? orderNumberPrefix,
    bool? enableTableNumbering,
    String? tableNumberPrefix,
    bool? enableReceiptHeader,
    bool? enableReceiptFooter,
    String? receiptHeaderText,
    String? receiptFooterText,
    bool? enableKitchenPrinting,
    bool? enableCustomerReceipt,
    int? maxTablesPerUser,
    bool? enableUserManagement,
    bool? enableCategoryManagement,
    bool? enableMenuItemManagement,
    List<String>? enabledFeatures,
  }) {
    return AppSettings(
      businessName: businessName ?? this.businessName,
      businessAddress: businessAddress ?? this.businessAddress,
      businessPhone: businessPhone ?? this.businessPhone,
      businessEmail: businessEmail ?? this.businessEmail,
      currency: currency ?? this.currency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      taxRate: taxRate ?? this.taxRate,
      taxName: taxName ?? this.taxName,
      enableTax: enableTax ?? this.enableTax,
      enableTips: enableTips ?? this.enableTips,
      tipOptions: tipOptions ?? this.tipOptions,
      defaultPrinterIp: defaultPrinterIp ?? this.defaultPrinterIp,
      defaultPrinterPort: defaultPrinterPort ?? this.defaultPrinterPort,
      themeMode: themeMode ?? this.themeMode,
      primaryColor: primaryColor ?? this.primaryColor,
      accentColor: accentColor ?? this.accentColor,
      enableSoundEffects: enableSoundEffects ?? this.enableSoundEffects,
      enableNotifications: enableNotifications ?? this.enableNotifications,
      language: language ?? this.language,
      dateFormat: dateFormat ?? this.dateFormat,
      timeFormat: timeFormat ?? this.timeFormat,
      autoSaveOrders: autoSaveOrders ?? this.autoSaveOrders,
      autoSaveInterval: autoSaveInterval ?? this.autoSaveInterval,
      enableOrderNumbering: enableOrderNumbering ?? this.enableOrderNumbering,
      orderNumberPrefix: orderNumberPrefix ?? this.orderNumberPrefix,
      enableTableNumbering: enableTableNumbering ?? this.enableTableNumbering,
      tableNumberPrefix: tableNumberPrefix ?? this.tableNumberPrefix,
      enableReceiptHeader: enableReceiptHeader ?? this.enableReceiptHeader,
      enableReceiptFooter: enableReceiptFooter ?? this.enableReceiptFooter,
      receiptHeaderText: receiptHeaderText ?? this.receiptHeaderText,
      receiptFooterText: receiptFooterText ?? this.receiptFooterText,
      enableKitchenPrinting: enableKitchenPrinting ?? this.enableKitchenPrinting,
      enableCustomerReceipt: enableCustomerReceipt ?? this.enableCustomerReceipt,
      maxTablesPerUser: maxTablesPerUser ?? this.maxTablesPerUser,
      enableUserManagement: enableUserManagement ?? this.enableUserManagement,
      enableCategoryManagement: enableCategoryManagement ?? this.enableCategoryManagement,
      enableMenuItemManagement: enableMenuItemManagement ?? this.enableMenuItemManagement,
      enabledFeatures: enabledFeatures ?? this.enabledFeatures,
    );
  }
} 