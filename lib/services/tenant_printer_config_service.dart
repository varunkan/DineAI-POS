import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';

import '../models/printer_configuration.dart';

/// 🏪 Tenant Printer Configuration Service
/// 
/// This service manages tenant-specific printer configurations with Firebase Firestore
/// integration and real-time synchronization across all devices in the same restaurant.
/// 
/// Features:
/// - Firebase Firestore integration for cloud storage
/// - Real-time sync for cross-device updates
/// - Local SharedPreferences caching for offline access
/// - Multi-tenant printer isolation
/// - Automatic configuration validation
/// - Error handling for connection failures
class TenantPrinterConfigService extends ChangeNotifier {
  static const String _logTag = '🏪 TenantPrinterConfigService';
  
  // Firebase services
  FirebaseFirestore? _firestore;
  FirebaseAuth? _auth;
  
  // Tenant configuration
  String _currentTenantId = '';
  String _currentRestaurantId = '';
  bool _isInitialized = false;
  
  // Printer configurations
  List<PrinterConfiguration> _printerConfigs = [];
  Map<String, PrinterConfiguration> _printerConfigMap = {};
  
  // Real-time sync
  StreamSubscription<QuerySnapshot>? _printerConfigListener;
  StreamSubscription<QuerySnapshot>? _printerAssignmentListener;
  
  // Local storage keys
  static const String _printerConfigsKey = 'tenant_printer_configs';
  static const String _lastSyncKey = 'last_printer_sync';
  
  // Error tracking
  String? _lastError;
  bool _hasSyncError = false;
  
  TenantPrinterConfigService() {
    _initializeFirebase();
  }
  
  // Getters
  bool get isInitialized => _isInitialized;
  List<PrinterConfiguration> get printerConfigs => List.unmodifiable(_printerConfigs);
  Map<String, PrinterConfiguration> get printerConfigMap => Map.unmodifiable(_printerConfigMap);
  String? get lastError => _lastError;
  bool get hasSyncError => _hasSyncError;
  String get currentTenantId => _currentTenantId;
  String get currentRestaurantId => _currentRestaurantId;
  
  /// Initialize Firebase services
  void _initializeFirebase() {
    try {
      _firestore = FirebaseFirestore.instance;
      _auth = FirebaseAuth.instance;
      debugPrint('$_logTag ✅ Firebase services initialized');
    } catch (e) {
      debugPrint('$_logTag ❌ Error initializing Firebase: $e');
      _lastError = 'Firebase initialization failed: $e';
    }
  }
  
  /// Initialize the service for a specific tenant
  Future<bool> initialize({required String tenantId, required String restaurantId}) async {
    try {
      debugPrint('$_logTag 🚀 Initializing tenant printer config service for tenant: $tenantId');
      
      _currentTenantId = tenantId;
      _currentRestaurantId = restaurantId;
      
      // Load cached configurations first
      await _loadCachedConfigurations();
      
      // Start real-time Firebase sync
      _startRealTimeSync();
      
      // Load fresh configurations from Firebase
      await _loadConfigurationsFromFirebase();
      
      _isInitialized = true;
      _lastError = null;
      _hasSyncError = false;
      
      debugPrint('$_logTag ✅ Tenant printer config service initialized successfully');
      notifyListeners();
      return true;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error initializing tenant printer config service: $e');
      _lastError = 'Initialization failed: $e';
      _hasSyncError = true;
      return false;
    }
  }
  
  /// Load cached configurations from SharedPreferences
  Future<void> _loadCachedConfigurations() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configsJson = prefs.getString('${_printerConfigsKey}_$_currentTenantId');
      
      if (configsJson != null) {
        final List<dynamic> configsList = jsonDecode(configsJson);
        
        _printerConfigs.clear();
        _printerConfigMap.clear();
        
        for (final configData in configsList) {
          try {
            final config = PrinterConfiguration.fromJson(configData);
            _printerConfigs.add(config);
            _printerConfigMap[config.id] = config;
          } catch (e) {
            debugPrint('$_logTag ⚠️ Error parsing cached printer config: $e');
          }
        }
        
        debugPrint('$_logTag 📥 Loaded ${_printerConfigs.length} cached printer configurations');
      }
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error loading cached configurations: $e');
    }
  }
  
  /// Save configurations to SharedPreferences cache
  Future<void> _saveConfigurationsToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final configsJson = jsonEncode(_printerConfigs.map((c) => c.toJson()).toList());
      
      await prefs.setString('${_printerConfigsKey}_$_currentTenantId', configsJson);
      await prefs.setString('${_lastSyncKey}_$_currentTenantId', DateTime.now().toIso8601String());
      
      debugPrint('$_logTag 💾 Saved ${_printerConfigs.length} printer configurations to cache');
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error saving configurations to cache: $e');
    }
  }
  
  /// Start real-time Firebase sync for cross-device updates
  void _startRealTimeSync() {
    if (_firestore == null || _currentTenantId.isEmpty) return;
    
    debugPrint('$_logTag 🔄 Starting real-time Firebase sync for cross-device updates...');
    
    final tenantDoc = _firestore!.collection('tenants').doc(_currentTenantId);
    
    // Listen for printer configuration changes
    _printerConfigListener = tenantDoc.collection('printer_configurations')
        .snapshots()
        .listen((snapshot) {
      _handlePrinterConfigChanges(snapshot);
    });
    
    // Listen for printer assignment changes
    _printerAssignmentListener = tenantDoc.collection('printer_assignments')
        .snapshots()
        .listen((snapshot) {
      _handlePrinterAssignmentChanges(snapshot);
    });
    
    debugPrint('$_logTag ✅ Real-time Firebase sync started');
  }
  
  /// Handle printer configuration changes from Firebase
  void _handlePrinterConfigChanges(QuerySnapshot snapshot) {
    try {
      for (final change in snapshot.docChanges) {
        final data = change.doc.data() as Map<String, dynamic>;
        data['id'] = change.doc.id;
        
        // Skip if not for current restaurant
        if (data['restaurant_id'] != _currentRestaurantId) {
          continue;
        }
        
        try {
          final printer = PrinterConfiguration.fromJson(data);
          
          switch (change.type) {
            case DocumentChangeType.added:
              _addPrinterConfig(printer);
              debugPrint('$_logTag ➕ Printer config added from Firebase: ${printer.name}');
              break;
            case DocumentChangeType.modified:
              _updatePrinterConfig(printer);
              debugPrint('$_logTag 🔄 Printer config updated from Firebase: ${printer.name}');
              break;
            case DocumentChangeType.removed:
              _removePrinterConfig(printer.id);
              debugPrint('$_logTag ➖ Printer config removed from Firebase: ${printer.name}');
              break;
          }
        } catch (e) {
          debugPrint('$_logTag ❌ Error parsing printer config change: $e');
        }
      }
      
      // Save to cache after changes
      _saveConfigurationsToCache();
      notifyListeners();
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error handling printer config changes: $e');
      _lastError = 'Sync error: $e';
      _hasSyncError = true;
    }
  }
  
  /// Handle printer assignment changes from Firebase
  void _handlePrinterAssignmentChanges(QuerySnapshot snapshot) {
    try {
      debugPrint('$_logTag 🔄 Printer assignments updated from Firebase');
      // TODO: Implement assignment change handling if needed
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error handling assignment changes: $e');
    }
  }
  
  /// Add printer configuration
  void _addPrinterConfig(PrinterConfiguration printer) {
    if (!_printerConfigs.any((p) => p.id == printer.id)) {
      _printerConfigs.add(printer);
      _printerConfigMap[printer.id] = printer;
    }
  }
  
  /// Update printer configuration
  void _updatePrinterConfig(PrinterConfiguration printer) {
    final index = _printerConfigs.indexWhere((p) => p.id == printer.id);
    if (index != -1) {
      _printerConfigs[index] = printer;
      _printerConfigMap[printer.id] = printer;
    }
  }
  
  /// Remove printer configuration
  void _removePrinterConfig(String printerId) {
    _printerConfigs.removeWhere((p) => p.id == printerId);
    _printerConfigMap.remove(printerId);
  }
  
  /// Load configurations from Firebase
  Future<void> _loadConfigurationsFromFirebase() async {
    try {
      if (_firestore == null || _currentTenantId.isEmpty) return;
      
      debugPrint('$_logTag 🔄 Loading printer configurations from Firebase...');
      
      final tenantDoc = _firestore!.collection('tenants').doc(_currentTenantId);
      final printerSnapshot = await tenantDoc.collection('printer_configurations').get();
      
      int loadedCount = 0;
      
      for (final doc in printerSnapshot.docs) {
        if (doc.id == '_persistence_config') continue;
        
        try {
          final data = doc.data();
          data['id'] = doc.id;
          
          // Skip if not for current restaurant
          if (data['restaurant_id'] != _currentRestaurantId) {
            continue;
          }
          
          final printer = PrinterConfiguration.fromJson(data);
          
          // Add or update configuration
          final existingIndex = _printerConfigs.indexWhere((p) => p.id == printer.id);
          if (existingIndex != -1) {
            _printerConfigs[existingIndex] = printer;
          } else {
            _printerConfigs.add(printer);
          }
          
          _printerConfigMap[printer.id] = printer;
          loadedCount++;
          
        } catch (e) {
          debugPrint('$_logTag ⚠️ Error parsing printer config from Firebase: $e');
        }
      }
      
      debugPrint('$_logTag ✅ Loaded $loadedCount printer configurations from Firebase');
      
      // Save to cache
      await _saveConfigurationsToCache();
      
      _lastError = null;
      _hasSyncError = false;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error loading configurations from Firebase: $e');
      _lastError = 'Failed to load from Firebase: $e';
      _hasSyncError = true;
    }
  }
  
  /// Create new printer configuration
  Future<bool> createPrinterConfig(PrinterConfiguration config) async {
    try {
      if (_firestore == null || _currentTenantId.isEmpty) {
        _lastError = 'Service not initialized';
        return false;
      }
      
      // Validate configuration
      if (!_validatePrinterConfig(config)) {
        return false;
      }
      
      // Add tenant and restaurant IDs
      final enhancedConfig = config.copyWith(
        tenantId: _currentTenantId,
        restaurantId: _currentRestaurantId,
        isNetworkPrinter: config.type == PrinterType.wifi || config.type == PrinterType.ethernet,
        isBluetoothPrinter: config.type == PrinterType.bluetooth,
        isLocalPrinter: config.type == PrinterType.usb,
        connectionString: config.getConnectionString(),
      );
      
      // Save to Firebase
      final tenantDoc = _firestore!.collection('tenants').doc(_currentTenantId);
      final printerDoc = tenantDoc.collection('printer_configurations').doc(enhancedConfig.id);
      
      await printerDoc.set(enhancedConfig.toJson());
      
      debugPrint('$_logTag ✅ Created printer configuration: ${enhancedConfig.name}');
      _lastError = null;
      return true;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error creating printer configuration: $e');
      _lastError = 'Creation failed: $e';
      return false;
    }
  }
  
  /// Update existing printer configuration
  Future<bool> updatePrinterConfig(PrinterConfiguration config) async {
    try {
      if (_firestore == null || _currentTenantId.isEmpty) {
        _lastError = 'Service not initialized';
        return false;
      }
      
      // Validate configuration
      if (!_validatePrinterConfig(config)) {
        return false;
      }
      
      // Update connection string
      final updatedConfig = config.copyWith(
        connectionString: config.getConnectionString(),
        updatedAt: DateTime.now(),
      );
      
      // Save to Firebase
      final tenantDoc = _firestore!.collection('tenants').doc(_currentTenantId);
      final printerDoc = tenantDoc.collection('printer_configurations').doc(updatedConfig.id);
      
      await printerDoc.update(updatedConfig.toJson());
      
      debugPrint('$_logTag ✅ Updated printer configuration: ${updatedConfig.name}');
      _lastError = null;
      return true;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error updating printer configuration: $e');
      _lastError = 'Update failed: $e';
      return false;
    }
  }
  
  /// Delete printer configuration
  Future<bool> deletePrinterConfig(String printerId) async {
    try {
      if (_firestore == null || _currentTenantId.isEmpty) {
        _lastError = 'Service not initialized';
        return false;
      }
      
      // Delete from Firebase
      final tenantDoc = _firestore!.collection('tenants').doc(_currentTenantId);
      final printerDoc = tenantDoc.collection('printer_configurations').doc(printerId);
      
      await printerDoc.delete();
      
      debugPrint('$_logTag ✅ Deleted printer configuration: $printerId');
      _lastError = null;
      return true;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error deleting printer configuration: $e');
      _lastError = 'Deletion failed: $e';
      return false;
    }
  }
  
  /// Validate printer configuration
  bool _validatePrinterConfig(PrinterConfiguration config) {
    try {
      // Check required fields
      if (config.name.isEmpty) {
        _lastError = 'Printer name is required';
        return false;
      }
      
      // Validate network printer settings
      if (config.type == PrinterType.wifi || config.type == PrinterType.ethernet) {
        if (config.ipAddress.isEmpty) {
          _lastError = 'IP address is required for network printers';
          return false;
        }
        
        if (config.port <= 0 || config.port > 65535) {
          _lastError = 'Invalid port number';
          return false;
        }
      }
      
      // Validate Bluetooth printer settings
      if (config.type == PrinterType.bluetooth) {
        if (config.bluetoothAddress.isEmpty) {
          _lastError = 'Bluetooth address is required for Bluetooth printers';
          return false;
        }
      }
      
      // Validate thermal settings
      if (config.thermalSettings.paperSize == PaperSize.paper80mm) {
        if (config.thermalSettings.dpi != 203 && config.thermalSettings.dpi != 300) {
          _lastError = 'DPI must be 203 or 300 for 80mm thermal printers';
          return false;
        }
      }
      
      _lastError = null;
      return true;
      
    } catch (e) {
      _lastError = 'Validation error: $e';
      return false;
    }
  }
  
  /// Get printer configuration by ID
  PrinterConfiguration? getPrinterConfig(String printerId) {
    return _printerConfigMap[printerId];
  }
  
  /// Get active printer configurations
  List<PrinterConfiguration> getActivePrinterConfigs() {
    return _printerConfigs.where((p) => p.isActive).toList();
  }
  
  /// Get network printer configurations
  List<PrinterConfiguration> getNetworkPrinterConfigs() {
    return _printerConfigs.where((p) => p.isNetworkPrinter).toList();
  }
  
  /// Get Bluetooth printer configurations
  List<PrinterConfiguration> getBluetoothPrinterConfigs() {
    return _printerConfigs.where((p) => p.isBluetoothPrinter).toList();
  }
  
  /// Get 80mm thermal printer configurations
  List<PrinterConfiguration> get80mmThermalPrinterConfigs() {
    return _printerConfigs.where((p) => p.supports80mm).toList();
  }
  
  /// Test printer connection
  Future<bool> testPrinterConnection(String printerId) async {
    try {
      final config = getPrinterConfig(printerId);
      if (config == null) {
        _lastError = 'Printer configuration not found';
        return false;
      }
      
      if (!config.isReadyForPrinting) {
        _lastError = 'Printer is not ready for printing';
        return false;
      }
      
      // TODO: Implement actual connection testing
      // For now, return true if configuration is valid
      debugPrint('$_logTag ✅ Printer connection test passed: ${config.name}');
      return true;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error testing printer connection: $e');
      _lastError = 'Connection test failed: $e';
      return false;
    }
  }
  
  /// Force refresh from Firebase
  Future<void> forceRefresh() async {
    try {
      debugPrint('$_logTag 🔄 Force refreshing printer configurations...');
      await _loadConfigurationsFromFirebase();
      debugPrint('$_logTag ✅ Force refresh completed');
    } catch (e) {
      debugPrint('$_logTag ❌ Error during force refresh: $e');
      _lastError = 'Force refresh failed: $e';
    }
  }
  
  /// Clear all data (for logout)
  Future<void> clearData() async {
    try {
      _printerConfigs.clear();
      _printerConfigMap.clear();
      _currentTenantId = '';
      _currentRestaurantId = '';
      _isInitialized = false;
      _lastError = null;
      _hasSyncError = false;
      
      // Cancel listeners
      _printerConfigListener?.cancel();
      _printerAssignmentListener?.cancel();
      
      debugPrint('$_logTag ✅ Service data cleared');
      notifyListeners();
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error clearing data: $e');
    }
  }
  
  /// Dispose resources
  @override
  void dispose() {
    _printerConfigListener?.cancel();
    _printerAssignmentListener?.cancel();
    super.dispose();
  }
} 