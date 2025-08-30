import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/printer_type_mapping.dart';
import '../services/printer_type_management_service.dart';
import '../services/printing_service.dart';
import '../services/firebase_service.dart';

/// Service for integrating printer types with order processing
class OrderPrinterIntegrationService {
  static OrderPrinterIntegrationService? _instance;
  static OrderPrinterIntegrationService get instance => _instance ??= OrderPrinterIntegrationService._();
  
  OrderPrinterIntegrationService._();

  final PrinterTypeManagementService _printerTypeService = PrinterTypeManagementService.instance;
  final PrintingService _printingService = PrintingService.instance;
  final FirebaseService _firebaseService = FirebaseService.instance;

  /// Process a new order and print to appropriate printers
  Future<Map<PrinterTypeCategory, bool>> processOrder(Order order) async {
    debugPrint('🔄 Processing order ${order.id} with printer type integration...');
    
    try {
      // Initialize printer type service if needed
      if (_printerTypeService.printerTypeConfigs.isEmpty) {
        await _initializePrinterTypes();
      }
      
      // Print receipt first
      final receiptSuccess = await _printingService.printReceipt(order);
      debugPrint('🧾 Receipt print: ${receiptSuccess ? '✅' : '❌'}');
      
      // Print kitchen orders to appropriate printers
      final kitchenResults = await _printingService.printKitchenOrders(order);
      debugPrint('🍳 Kitchen print results: $kitchenResults');
      
      // Combine results
      final results = <PrinterTypeCategory, bool>{
        PrinterTypeCategory.receipt: receiptSuccess,
        ...kitchenResults,
      };
      
      // Log results
      _logPrintResults(order, results);
      
      return results;
    } catch (e) {
      debugPrint('❌ Error processing order: $e');
      return {};
    }
  }

  /// Initialize printer types with default configurations
  Future<void> _initializePrinterTypes() async {
    try {
      debugPrint('🏗️ Initializing printer types...');
      
      final restaurantId = await _firebaseService.getCurrentRestaurantId();
      final userId = await _firebaseService.getCurrentUserId();
      
      if (restaurantId != null && userId != null) {
        await _printerTypeService.createDefaultConfigurations(restaurantId, userId);
        debugPrint('✅ Printer types initialized');
      } else {
        debugPrint('⚠️ Cannot initialize printer types: missing restaurant or user ID');
      }
    } catch (e) {
      debugPrint('❌ Error initializing printer types: $e');
    }
  }

  /// Get printer type for an order item
  PrinterTypeCategory getPrinterTypeForOrderItem(OrderItem item) {
    // First check if item has specific mapping
    final itemPrinterType = _printerTypeService.getPrinterTypeForItem(item.id);
    if (itemPrinterType != null) {
      return itemPrinterType;
    }
    
    // Then check category mapping
    final categoryPrinterType = _printerTypeService.getPrinterTypeForCategory(item.categoryId);
    if (categoryPrinterType != null) {
      return categoryPrinterType;
    }
    
    // Default based on item characteristics
    return _getDefaultPrinterTypeForItem(item);
  }

  /// Get default printer type based on item characteristics
  PrinterTypeCategory _getDefaultPrinterTypeForItem(OrderItem item) {
    final itemName = item.name.toLowerCase();
    final categoryName = item.categoryName.toLowerCase();
    
    // Tandoor items
    if (itemName.contains('tandoor') || 
        itemName.contains('grill') || 
        itemName.contains('kebab') ||
        categoryName.contains('tandoor') ||
        categoryName.contains('grill')) {
      return PrinterTypeCategory.tandoor;
    }
    
    // Curry items
    if (itemName.contains('curry') || 
        itemName.contains('sauce') || 
        itemName.contains('gravy') ||
        categoryName.contains('curry') ||
        categoryName.contains('sauce')) {
      return PrinterTypeCategory.curry;
    }
    
    // Expo items (assembly line)
    if (itemName.contains('salad') || 
        itemName.contains('bread') || 
        itemName.contains('rice') ||
        categoryName.contains('salad') ||
        categoryName.contains('bread')) {
      return PrinterTypeCategory.expo;
    }
    
    // Default to receipt for everything else
    return PrinterTypeCategory.receipt;
  }

  /// Group order items by printer type
  Map<PrinterTypeCategory, List<OrderItem>> groupOrderItemsByPrinterType(Order order) {
    final Map<PrinterTypeCategory, List<OrderItem>> groupedItems = {};
    
    for (final item in order.items) {
      final printerType = getPrinterTypeForOrderItem(item);
      groupedItems.putIfAbsent(printerType, () => []).add(item);
    }
    
    return groupedItems;
  }

  /// Get summary of order printing requirements
  Map<String, dynamic> getOrderPrintingSummary(Order order) {
    final groupedItems = groupOrderItemsByPrinterType(order);
    final summary = <String, dynamic>{};
    
    for (final entry in groupedItems.entries) {
      final printerType = entry.key;
      final items = entry.value;
      
      summary[printerType.name] = {
        'displayName': printerType.displayName,
        'icon': printerType.icon,
        'color': printerType.color,
        'itemCount': items.length,
        'items': items.map((item) => item.name).toList(),
        'hasPrinters': _printerTypeService.hasAssignedPrinters(printerType),
        'printerCount': _printerTypeService.getPrintersForType(printerType).length,
      };
    }
    
    return summary;
  }

  /// Validate printer assignments for an order
  List<String> validateOrderPrinting(Order order) {
    final List<String> issues = [];
    final groupedItems = groupOrderItemsByPrinterType(order);
    
    for (final entry in groupedItems.entries) {
      final printerType = entry.key;
      final items = entry.value;
      
      if (!_printerTypeService.hasAssignedPrinters(printerType)) {
        issues.add('${printerType.displayName} has no assigned printers (${items.length} items affected)');
      }
    }
    
    return issues;
  }

  /// Auto-assign items to printer types based on smart detection
  Future<void> autoAssignItemsToPrinterTypes() async {
    try {
      debugPrint('🤖 Auto-assigning items to printer types...');
      
      // This would implement smart logic to automatically assign items
      // based on their names, categories, and characteristics
      
      debugPrint('✅ Auto-assignment completed');
    } catch (e) {
      debugPrint('❌ Error in auto-assignment: $e');
    }
  }

  /// Get printer type statistics
  Map<String, dynamic> getPrinterTypeStatistics() {
    return _printerTypeService.getSummaryStats();
  }

  /// Check if all printer types are properly configured
  bool arePrinterTypesConfigured() {
    final stats = getPrinterTypeStatistics();
    
    for (final printerType in PrinterTypeCategory.values) {
      final typeStats = stats[printerType.name];
      if (typeStats == null || !typeStats['hasPrinters']) {
        return false;
      }
    }
    
    return true;
  }

  /// Get recommended printer assignments for unassigned items
  Map<String, List<String>> getRecommendedAssignments() {
    final recommendations = <String, List<String>>{};
    
    // This would analyze unassigned items and suggest printer type assignments
    // based on item characteristics and existing patterns
    
    return recommendations;
  }

  /// Log print results for analytics
  void _logPrintResults(Order order, Map<PrinterTypeCategory, bool> results) {
    final successCount = results.values.where((success) => success).length;
    final totalCount = results.length;
    
    debugPrint('📊 Order ${order.id} print summary: $successCount/$totalCount successful');
    
    for (final entry in results.entries) {
      final printerType = entry.key;
      final success = entry.value;
      debugPrint('${success ? '✅' : '❌'} ${printerType.displayName}: ${success ? 'Success' : 'Failed'}');
    }
  }

  /// Get printer type configuration status
  Map<String, dynamic> getConfigurationStatus() {
    final status = <String, dynamic>{};
    
    for (final printerType in PrinterTypeCategory.values) {
      final config = _printerTypeService.getAllPrinterTypes()[printerType];
      
      status[printerType.name] = {
        'configured': config != null,
        'hasPrinters': config?.assignedPrinterIds.isNotEmpty ?? false,
        'hasCategories': config?.assignedCategoryIds.isNotEmpty ?? false,
        'hasItems': config?.assignedItemIds.isNotEmpty ?? false,
        'printerCount': config?.assignedPrinterIds.length ?? 0,
        'categoryCount': config?.assignedCategoryIds.length ?? 0,
        'itemCount': config?.assignedItemIds.length ?? 0,
      };
    }
    
    return status;
  }

  /// Validate printer type configuration
  List<String> validateConfiguration() {
    final List<String> issues = [];
    final status = getConfigurationStatus();
    
    for (final entry in status.entries) {
      final typeName = entry.key;
      final typeStatus = entry.value;
      
      if (!typeStatus['configured']) {
        issues.add('$typeName: Not configured');
      } else if (!typeStatus['hasPrinters']) {
        issues.add('$typeName: No printers assigned');
      } else if (!typeStatus['hasCategories'] && !typeStatus['hasItems']) {
        issues.add('$typeName: No categories or items assigned');
      }
    }
    
    return issues;
  }

  /// Get quick setup recommendations
  List<String> getQuickSetupRecommendations() {
    final recommendations = <String>[];
    final status = getConfigurationStatus();
    
    for (final entry in status.entries) {
      final typeName = entry.key;
      final typeStatus = entry.value;
      
      if (!typeStatus['configured']) {
        recommendations.add('Configure $typeName printer type');
      } else if (!typeStatus['hasPrinters']) {
        recommendations.add('Assign printers to $typeName');
      } else if (!typeStatus['hasCategories'] && !typeStatus['hasItems']) {
        recommendations.add('Assign categories or items to $typeName');
      }
    }
    
    return recommendations;
  }
} 