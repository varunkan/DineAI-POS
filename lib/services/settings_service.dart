import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

class SettingsService with ChangeNotifier {
  final SharedPreferences _prefs;
  AppSettings _settings;
  static const String _settingsKey = 'app_settings';

  SettingsService(this._prefs) : _settings = AppSettings() {
    _loadSettings();
  }

  AppSettings get settings => _settings;

  Future<void> _loadSettings() async {
    final String? settingsJson = _prefs.getString(_settingsKey);
    if (settingsJson != null) {
      try {
        final Map<String, dynamic> settingsMap = jsonDecode(settingsJson);
        _settings = AppSettings.fromJson(settingsMap);
        notifyListeners();
      } catch (e) {
        debugPrint('Error loading settings: $e');
        // Keep default settings if loading fails
      }
    }
  }

  Future<void> saveSettings(AppSettings newSettings) async {
    final String settingsJson = jsonEncode(newSettings.toJson());
    await _prefs.setString(_settingsKey, settingsJson);
    _settings = newSettings;
    notifyListeners();
  }

  Future<void> updateSettings(AppSettings updatedSettings) async {
    await saveSettings(updatedSettings);
  }

  // Convenience methods for updating specific settings
  Future<void> updateBusinessInfo({
    String? businessName,
    String? businessAddress,
    String? businessPhone,
    String? businessEmail,
  }) async {
    final newSettings = _settings.copyWith(
      businessName: businessName,
      businessAddress: businessAddress,
      businessPhone: businessPhone,
      businessEmail: businessEmail,
    );
    await saveSettings(newSettings);
  }

  Future<void> updateTaxSettings({
    double? taxRate,
    String? taxName,
    bool? enableTax,
  }) async {
    final newSettings = _settings.copyWith(
      taxRate: taxRate,
      taxName: taxName,
      enableTax: enableTax,
    );
    await saveSettings(newSettings);
  }

  Future<void> updateThemeSettings({
    String? themeMode,
    String? primaryColor,
    String? accentColor,
  }) async {
    final newSettings = _settings.copyWith(
      themeMode: themeMode,
      primaryColor: primaryColor,
      accentColor: accentColor,
    );
    await saveSettings(newSettings);
  }

  Future<void> updateCurrencySettings({
    String? currency,
    String? currencySymbol,
  }) async {
    final newSettings = _settings.copyWith(
      currency: currency,
      currencySymbol: currencySymbol,
    );
    await saveSettings(newSettings);
  }

  Future<void> updatePrinterSettings({
    String? defaultPrinterIp,
    int? defaultPrinterPort,
  }) async {
    final newSettings = _settings.copyWith(
      defaultPrinterIp: defaultPrinterIp,
      defaultPrinterPort: defaultPrinterPort,
    );
    await saveSettings(newSettings);
  }

  Future<void> updateFeatureSettings({
    bool? enableUserManagement,
    bool? enableCategoryManagement,
    bool? enableMenuItemManagement,
    List<String>? enabledFeatures,
  }) async {
    final newSettings = _settings.copyWith(
      enableUserManagement: enableUserManagement,
      enableCategoryManagement: enableCategoryManagement,
      enableMenuItemManagement: enableMenuItemManagement,
      enabledFeatures: enabledFeatures,
    );
    await saveSettings(newSettings);
  }

  Future<void> updateReceiptSettings({
    bool? enableReceiptHeader,
    bool? enableReceiptFooter,
    String? receiptHeaderText,
    String? receiptFooterText,
    bool? enableKitchenPrinting,
    bool? enableCustomerReceipt,
  }) async {
    final newSettings = _settings.copyWith(
      enableReceiptHeader: enableReceiptHeader,
      enableReceiptFooter: enableReceiptFooter,
      receiptHeaderText: receiptHeaderText,
      receiptFooterText: receiptFooterText,
      enableKitchenPrinting: enableKitchenPrinting,
      enableCustomerReceipt: enableCustomerReceipt,
    );
    await saveSettings(newSettings);
  }

  Future<void> updateOrderSettings({
    bool? autoSaveOrders,
    int? autoSaveInterval,
    bool? enableOrderNumbering,
    String? orderNumberPrefix,
    bool? enableTableNumbering,
    String? tableNumberPrefix,
    int? maxTablesPerUser,
  }) async {
    final newSettings = _settings.copyWith(
      autoSaveOrders: autoSaveOrders,
      autoSaveInterval: autoSaveInterval,
      enableOrderNumbering: enableOrderNumbering,
      orderNumberPrefix: orderNumberPrefix,
      enableTableNumbering: enableTableNumbering,
      tableNumberPrefix: tableNumberPrefix,
      maxTablesPerUser: maxTablesPerUser,
    );
    await saveSettings(newSettings);
  }

  Future<void> updateTipSettings({
    bool? enableTips,
    List<double>? tipOptions,
  }) async {
    final newSettings = _settings.copyWith(
      enableTips: enableTips,
      tipOptions: tipOptions,
    );
    await saveSettings(newSettings);
  }

  Future<void> updateGeneralSettings({
    bool? enableSoundEffects,
    bool? enableNotifications,
    String? language,
    String? dateFormat,
    String? timeFormat,
  }) async {
    final newSettings = _settings.copyWith(
      enableSoundEffects: enableSoundEffects,
      enableNotifications: enableNotifications,
      language: language,
      dateFormat: dateFormat,
      timeFormat: timeFormat,
    );
    await saveSettings(newSettings);
  }

  // Helper methods
  bool isFeatureEnabled(String feature) {
    return _settings.enabledFeatures.contains(feature);
  }

  String getCurrencySymbol() {
    return _settings.currencySymbol;
  }

  double getTaxRate() {
    return _settings.enableTax ? _settings.taxRate : 0.0;
  }

  String getTaxName() {
    return _settings.taxName;
  }

  bool get isTaxEnabled => _settings.enableTax;
  bool get isTipsEnabled => _settings.enableTips;
  bool get isUserManagementEnabled => _settings.enableUserManagement;
  bool get isCategoryManagementEnabled => _settings.enableCategoryManagement;
  bool get isMenuItemManagementEnabled => _settings.enableMenuItemManagement;
  bool get isKitchenPrintingEnabled => _settings.enableKitchenPrinting;
  bool get isCustomerReceiptEnabled => _settings.enableCustomerReceipt;
  bool get isAutoSaveEnabled => _settings.autoSaveOrders;
  bool get isOrderNumberingEnabled => _settings.enableOrderNumbering;
  bool get isTableNumberingEnabled => _settings.enableTableNumbering;
  bool get isReceiptHeaderEnabled => _settings.enableReceiptHeader;
  bool get isReceiptFooterEnabled => _settings.enableReceiptFooter;

  // HST Rate setting
  static const String _hstRateKey = 'hst_rate';
  static const double _defaultHstRate = 0.13; // 13% HST
  
  double get hstRate => _prefs.getDouble(_hstRateKey) ?? _defaultHstRate;
  
  Future<void> setHstRate(double rate) async {
    await _prefs.setDouble(_hstRateKey, rate);
    
    // Safely notify listeners
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint('Error notifying listeners during set HST rate: $e');
        }
      });
    } catch (e) {
      debugPrint('Error scheduling notification during set HST rate: $e');
    }
  }

  // Tax Rate setting
  static const String _taxRateKey = 'tax_rate';
  static const double _defaultTaxRate = 0.0; // No additional tax by default
  
  double get taxRate => _prefs.getDouble(_taxRateKey) ?? _defaultTaxRate;
  
  Future<void> setTaxRate(double rate) async {
    await _prefs.setDouble(_taxRateKey, rate);
    
    // Safely notify listeners
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint('Error notifying listeners during set tax rate: $e');
        }
      });
    } catch (e) {
      debugPrint('Error scheduling notification during set tax rate: $e');
    }
  }
} 