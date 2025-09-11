import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/printer_type_mapping.dart';
// Removed unused imports
import 'database_service.dart';
import 'firebase_auth_service.dart';
import '../services/multi_tenant_auth_service.dart';

/// Service for managing printer type configurations and assignments
class PrinterTypeManagementService extends ChangeNotifier {
  static PrinterTypeManagementService? _instance;
  static PrinterTypeManagementService get instance => _instance ??= PrinterTypeManagementService._();
  
  PrinterTypeManagementService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseService _databaseService = DatabaseService();
  final FirebaseAuthService _firebaseService = FirebaseAuthService.instance;

  // Local storage keys
  static const String _printerTypeConfigsKey = 'printer_type_configs';
  static const String _printerTypeAssignmentsKey = 'printer_type_assignments';
  static const String _itemPrinterTypeMappingsKey = 'item_printer_type_mappings';

  // Local cache
  List<PrinterTypeConfiguration> _printerTypeConfigs = [];
  List<PrinterTypeAssignment> _printerTypeAssignments = [];
  List<ItemPrinterTypeMapping> _itemPrinterTypeMappings = [];

  // Getters
  List<PrinterTypeConfiguration> get printerTypeConfigs => List.unmodifiable(_printerTypeConfigs);
  List<PrinterTypeAssignment> get printerTypeAssignments => List.unmodifiable(_printerTypeAssignments);
  List<ItemPrinterTypeMapping> get itemPrinterTypeMappings => List.unmodifiable(_itemPrinterTypeMappings);

  /// Initialize the service
  Future<void> initialize() async {
    debugPrint('🔧 Initializing Printer Type Management Service...');
    
    try {
      // Load from local storage first
      await _loadFromLocalStorage();
      
      // Then sync from Firebase
      await _syncFromFirebase();
      
      debugPrint('✅ Printer Type Management Service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing Printer Type Management Service: $e');
    }
  }

  /// Load data from local storage
  Future<void> _loadFromLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load printer type configurations
      final configsJson = prefs.getString(_printerTypeConfigsKey);
      if (configsJson != null) {
        final List<dynamic> configsList = jsonDecode(configsJson);
        _printerTypeConfigs = configsList
            .map((json) => PrinterTypeConfiguration.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      }
      
      // Load printer type assignments
      final assignmentsJson = prefs.getString(_printerTypeAssignmentsKey);
      if (assignmentsJson != null) {
        final List<dynamic> assignmentsList = jsonDecode(assignmentsJson);
        _printerTypeAssignments = assignmentsList
            .map((json) => PrinterTypeAssignment.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      }
      
      // Load item printer type mappings
      final mappingsJson = prefs.getString(_itemPrinterTypeMappingsKey);
      if (mappingsJson != null) {
        final List<dynamic> mappingsList = jsonDecode(mappingsJson);
        _itemPrinterTypeMappings = mappingsList
            .map((json) => ItemPrinterTypeMapping.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      }
      
      debugPrint('📱 Loaded ${_printerTypeConfigs.length} printer type configs from local storage');
    } catch (e) {
      debugPrint('⚠️ Error loading from local storage: $e');
    }
  }

  // Local JSON parsing is handled via model fromJson methods

  /// Save data to local storage
  Future<void> _saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Save printer type configurations
      final configsJson = jsonEncode(_printerTypeConfigs.map((c) => c.toJson()).toList());
      await prefs.setString(_printerTypeConfigsKey, configsJson);
      
      // Save printer type assignments
      final assignmentsJson = jsonEncode(_printerTypeAssignments.map((a) => a.toJson()).toList());
      await prefs.setString(_printerTypeAssignmentsKey, assignmentsJson);
      
      // Save item printer type mappings
      final mappingsJson = jsonEncode(_itemPrinterTypeMappings.map((m) => m.toJson()).toList());
      await prefs.setString(_itemPrinterTypeMappingsKey, mappingsJson);
      
      debugPrint('💾 Saved data to local storage');
    } catch (e) {
      debugPrint('❌ Error saving to local storage: $e');
    }
  }

  /// Sync data from Firebase
  Future<void> _syncFromFirebase() async {
    try {
      final restaurantId = MultiTenantAuthService().currentRestaurant?.id ?? '';
      if (restaurantId.isEmpty) {
        debugPrint('⚠️ No restaurant ID available for Firebase sync');
        return;
      }

      debugPrint('🔄 Syncing printer type data from Firebase...');
      
      // Sync printer type configurations
      final configsSnapshot = await _firestore
          .collection('printer_type_configs')
          .where('restaurantId', isEqualTo: restaurantId)
          .get();
      
      _printerTypeConfigs = configsSnapshot.docs
          .map((doc) => PrinterTypeConfiguration.fromFirestore(doc))
          .toList();
      
      // Sync printer type assignments
      final assignmentsSnapshot = await _firestore
          .collection('printer_type_assignments')
          .where('printerTypeConfigId', whereIn: _printerTypeConfigs.map((c) => c.id).toList())
          .get();
      
      _printerTypeAssignments = assignmentsSnapshot.docs
          .map((doc) => PrinterTypeAssignment.fromFirestore(doc))
          .toList();
      
      // Sync item printer type mappings
      final mappingsSnapshot = await _firestore
          .collection('item_printer_type_mappings')
          .where('restaurantId', isEqualTo: restaurantId)
          .get();
      
      _itemPrinterTypeMappings = mappingsSnapshot.docs
          .map((doc) => ItemPrinterTypeMapping.fromFirestore(doc))
          .toList();
      
      // Save to local storage
      await _saveToLocalStorage();
      
      notifyListeners();
      debugPrint('✅ Synced ${_printerTypeConfigs.length} printer type configs from Firebase');
    } catch (e) {
      debugPrint('❌ Error syncing from Firebase: $e');
    }
  }

  /// Create default printer type configurations
  Future<void> createDefaultConfigurations(String restaurantId, String userId) async {
    try {
      debugPrint('🏗️ Creating default printer type configurations...');
      
      final now = DateTime.now();
      
      // Create receipt printer configuration
      final receiptConfig = PrinterTypeConfiguration(
        id: 'receipt_${DateTime.now().millisecondsSinceEpoch}',
        type: PrinterTypeCategory.receipt,
        name: 'Receipt Printer',
        description: 'Main receipt printer for customer orders',
        assignedPrinterIds: [],
        assignedCategoryIds: [],
        assignedItemIds: [],
        isActive: true,
        createdAt: now,
        updatedAt: now,
        createdBy: userId,
        restaurantId: restaurantId,
      );
      
      // Create tandoor printer configuration
      final tandoorConfig = PrinterTypeConfiguration(
        id: 'tandoor_${DateTime.now().millisecondsSinceEpoch}',
        type: PrinterTypeCategory.tandoor,
        name: 'Tandoor Printer',
        description: 'Printer for tandoor/grill items',
        assignedPrinterIds: [],
        assignedCategoryIds: [],
        assignedItemIds: [],
        isActive: true,
        createdAt: now,
        updatedAt: now,
        createdBy: userId,
        restaurantId: restaurantId,
      );
      
      // Create curry printer configuration
      final curryConfig = PrinterTypeConfiguration(
        id: 'curry_${DateTime.now().millisecondsSinceEpoch}',
        type: PrinterTypeCategory.curry,
        name: 'Curry Printer',
        description: 'Printer for curry and sauce items',
        assignedPrinterIds: [],
        assignedCategoryIds: [],
        assignedItemIds: [],
        isActive: true,
        createdAt: now,
        updatedAt: now,
        createdBy: userId,
        restaurantId: restaurantId,
      );
      
      // Create expo printer configuration
      final expoConfig = PrinterTypeConfiguration(
        id: 'expo_${DateTime.now().millisecondsSinceEpoch}',
        type: PrinterTypeCategory.expo,
        name: 'Expo Printer',
        description: 'Printer for expo/assembly line',
        assignedPrinterIds: [],
        assignedCategoryIds: [],
        assignedItemIds: [],
        isActive: true,
        createdAt: now,
        updatedAt: now,
        createdBy: userId,
        restaurantId: restaurantId,
      );
      
      // Add to local list
      _printerTypeConfigs.addAll([receiptConfig, tandoorConfig, curryConfig, expoConfig]);
      
      // Save to Firebase
      await _saveConfigurationsToFirebase([receiptConfig, tandoorConfig, curryConfig, expoConfig]);
      
      // Save to local storage
      await _saveToLocalStorage();
      
      notifyListeners();
      debugPrint('✅ Created default printer type configurations');
    } catch (e) {
      debugPrint('❌ Error creating default configurations: $e');
    }
  }

  /// Save configurations to Firebase
  Future<void> _saveConfigurationsToFirebase(List<PrinterTypeConfiguration> configs) async {
    try {
      final batch = _firestore.batch();
      
      for (final config in configs) {
        final docRef = _firestore.collection('printer_type_configs').doc(config.id);
        batch.set(docRef, config.toFirestore());
      }
      
      await batch.commit();
      debugPrint('🔥 Saved ${configs.length} configurations to Firebase');
    } catch (e) {
      debugPrint('❌ Error saving to Firebase: $e');
      rethrow;
    }
  }

  /// Assign a printer to a printer type
  Future<void> assignPrinterToType({
    required String printerId,
    required PrinterTypeCategory printerType,
    required bool isPrimary,
    required String userId,
  }) async {
    try {
      debugPrint('🔗 Assigning printer $printerId to ${printerType.displayName}...');
      
      // Find the configuration for this printer type
      final config = _printerTypeConfigs.firstWhere(
        (c) => c.type == printerType,
        orElse: () => throw Exception('No configuration found for ${printerType.displayName}'),
      );
      
      // Create assignment
      final assignment = PrinterTypeAssignment(
        id: 'assignment_${DateTime.now().millisecondsSinceEpoch}',
        printerTypeConfigId: config.id,
        printerId: printerId,
        printerType: printerType,
        isPrimary: isPrimary,
        assignedAt: DateTime.now(),
        assignedBy: userId,
      );
      
      // Add to local list
      _printerTypeAssignments.add(assignment);
      
      // Update configuration
      final updatedConfig = config.copyWith(
        assignedPrinterIds: [...config.assignedPrinterIds, printerId],
        updatedAt: DateTime.now(),
      );
      
      final configIndex = _printerTypeConfigs.indexWhere((c) => c.id == config.id);
      if (configIndex != -1) {
        _printerTypeConfigs[configIndex] = updatedConfig;
      }
      
      // Save to Firebase
      await _firestore
          .collection('printer_type_assignments')
          .doc(assignment.id)
          .set(assignment.toFirestore());
      
      await _firestore
          .collection('printer_type_configs')
          .doc(config.id)
          .update(updatedConfig.toFirestore());
      
      // Save to local storage
      await _saveToLocalStorage();
      
      notifyListeners();
      debugPrint('✅ Printer assigned successfully');
    } catch (e) {
      debugPrint('❌ Error assigning printer: $e');
      rethrow;
    }
  }

  /// Assign a category to a printer type
  Future<void> assignCategoryToType({
    required String categoryId,
    required PrinterTypeCategory printerType,
    required String userId,
  }) async {
    try {
      debugPrint('🏷️ Assigning category $categoryId to ${printerType.displayName}...');
      
      // Find the configuration for this printer type
      final config = _printerTypeConfigs.firstWhere(
        (c) => c.type == printerType,
        orElse: () => throw Exception('No configuration found for ${printerType.displayName}'),
      );
      
      // Update configuration
      final updatedConfig = config.copyWith(
        assignedCategoryIds: [...config.assignedCategoryIds, categoryId],
        updatedAt: DateTime.now(),
      );
      
      final configIndex = _printerTypeConfigs.indexWhere((c) => c.id == config.id);
      if (configIndex != -1) {
        _printerTypeConfigs[configIndex] = updatedConfig;
      }
      
      // Save to Firebase
      await _firestore
          .collection('printer_type_configs')
          .doc(config.id)
          .update(updatedConfig.toFirestore());
      
      // Save to local storage
      await _saveToLocalStorage();
      
      notifyListeners();
      debugPrint('✅ Category assigned successfully');
    } catch (e) {
      debugPrint('❌ Error assigning category: $e');
      rethrow;
    }
  }

  /// Assign an item to a printer type
  Future<void> assignItemToType({
    required String itemId,
    required String itemName,
    required String categoryId,
    required String categoryName,
    required PrinterTypeCategory printerType,
    required String userId,
    required String restaurantId,
  }) async {
    try {
      debugPrint('🍽️ Assigning item $itemName to ${printerType.displayName}...');
      
      // Find the configuration for this printer type
      final config = _printerTypeConfigs.firstWhere(
        (c) => c.type == printerType,
        orElse: () => throw Exception('No configuration found for ${printerType.displayName}'),
      );
      
      // Create mapping
      final mapping = ItemPrinterTypeMapping(
        id: 'mapping_${DateTime.now().millisecondsSinceEpoch}',
        itemId: itemId,
        itemName: itemName,
        categoryId: categoryId,
        categoryName: categoryName,
        printerType: printerType,
        printerTypeConfigId: config.id,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: userId,
        restaurantId: restaurantId,
      );
      
      // Add to local list
      _itemPrinterTypeMappings.add(mapping);
      
      // Update configuration
      final updatedConfig = config.copyWith(
        assignedItemIds: [...config.assignedItemIds, itemId],
        updatedAt: DateTime.now(),
      );
      
      final configIndex = _printerTypeConfigs.indexWhere((c) => c.id == config.id);
      if (configIndex != -1) {
        _printerTypeConfigs[configIndex] = updatedConfig;
      }
      
      // Save to Firebase
      await _firestore
          .collection('item_printer_type_mappings')
          .doc(mapping.id)
          .set(mapping.toFirestore());
      
      await _firestore
          .collection('printer_type_configs')
          .doc(config.id)
          .update(updatedConfig.toFirestore());
      
      // Save to local storage
      await _saveToLocalStorage();
      
      notifyListeners();
      debugPrint('✅ Item assigned successfully');
    } catch (e) {
      debugPrint('❌ Error assigning item: $e');
      rethrow;
    }
  }

  /// Get printer type for an item
  PrinterTypeCategory? getPrinterTypeForItem(String itemId) {
    try {
      final mapping = _itemPrinterTypeMappings.firstWhere(
        (m) => m.itemId == itemId && m.isActive,
        orElse: () => throw Exception('No mapping found'),
      );
      return mapping.printerType;
    } catch (e) {
      return null;
    }
  }

  /// Get printer type for a category
  PrinterTypeCategory? getPrinterTypeForCategory(String categoryId) {
    try {
      final config = _printerTypeConfigs.firstWhere(
        (c) => c.isCategoryAssigned(categoryId) && c.isActive,
        orElse: () => throw Exception('No configuration found'),
      );
      return config.type;
    } catch (e) {
      return null;
    }
  }

  /// Get printers for a printer type
  List<String> getPrintersForType(PrinterTypeCategory printerType) {
    try {
      final config = _printerTypeConfigs.firstWhere(
        (c) => c.type == printerType && c.isActive,
        orElse: () => throw Exception('No configuration found'),
      );
      return config.assignedPrinterIds;
    } catch (e) {
      return [];
    }
  }

  /// Get primary printer for a printer type
  String? getPrimaryPrinterForType(PrinterTypeCategory printerType) {
    try {
      final assignment = _printerTypeAssignments.firstWhere(
        (a) => a.printerType == printerType && a.isPrimary,
        orElse: () => throw Exception('No primary printer found'),
      );
      return assignment.printerId;
    } catch (e) {
      return null;
    }
  }

  /// Remove printer assignment
  Future<void> removePrinterAssignment(String printerId, PrinterTypeCategory printerType) async {
    try {
      debugPrint('🔌 Removing printer $printerId from ${printerType.displayName}...');
      
      // Remove assignment
      _printerTypeAssignments.removeWhere((a) => 
        a.printerId == printerId && a.printerType == printerType);
      
      // Update configuration
      final config = _printerTypeConfigs.firstWhere(
        (c) => c.type == printerType,
        orElse: () => throw Exception('No configuration found'),
      );
      
      final updatedConfig = config.copyWith(
        assignedPrinterIds: config.assignedPrinterIds.where((id) => id != printerId).toList(),
        updatedAt: DateTime.now(),
      );
      
      final configIndex = _printerTypeConfigs.indexWhere((c) => c.id == config.id);
      if (configIndex != -1) {
        _printerTypeConfigs[configIndex] = updatedConfig;
      }
      
      // Save to Firebase
      await _firestore
          .collection('printer_type_assignments')
          .where('printerId', isEqualTo: printerId)
          .where('printerType', isEqualTo: printerType.toString())
          .get()
          .then((snapshot) {
        for (final doc in snapshot.docs) {
          doc.reference.delete();
        }
      });
      
      await _firestore
          .collection('printer_type_configs')
          .doc(config.id)
          .update(updatedConfig.toFirestore());
      
      // Save to local storage
      await _saveToLocalStorage();
      
      notifyListeners();
      debugPrint('✅ Printer assignment removed successfully');
    } catch (e) {
      debugPrint('❌ Error removing printer assignment: $e');
      rethrow;
    }
  }

  /// Get all printer types with their configurations
  Map<PrinterTypeCategory, PrinterTypeConfiguration> getAllPrinterTypes() {
    final Map<PrinterTypeCategory, PrinterTypeConfiguration> result = {};
    
    for (final config in _printerTypeConfigs) {
      if (config.isActive) {
        result[config.type] = config;
      }
    }
    
    return result;
  }

  /// Check if a printer type has any assigned printers
  bool hasAssignedPrinters(PrinterTypeCategory printerType) {
    try {
      final config = _printerTypeConfigs.firstWhere(
        (c) => c.type == printerType && c.isActive,
        orElse: () => throw Exception('No configuration found'),
      );
      return config.assignedPrinterIds.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Get summary statistics
  Map<String, dynamic> getSummaryStats() {
    final stats = <String, dynamic>{};
    
    for (final printerType in PrinterTypeCategory.values) {
      final config = _printerTypeConfigs.firstWhere(
        (c) => c.type == printerType && c.isActive,
        orElse: () => PrinterTypeConfiguration(
          id: 'default',
          type: printerType,
          name: 'Default ${printerType.displayName}',
          description: 'Default configuration for ${printerType.displayName}',
          isActive: true,
          assignedPrinterIds: [],
          assignedCategoryIds: [],
          assignedItemIds: [],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: 'system',
          restaurantId: 'default',
        ),
      );
      
      if (config != null) {
        stats[printerType.name] = {
          'printerCount': config.assignedPrinterIds.length,
          'categoryCount': config.assignedCategoryIds.length,
          'itemCount': config.assignedItemIds.length,
          'hasPrinters': config.assignedPrinterIds.isNotEmpty,
        };
      }
    }
    
    return stats;
  }
} 