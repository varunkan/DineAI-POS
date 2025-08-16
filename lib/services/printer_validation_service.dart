import 'package:flutter/foundation.dart';
import '../models/order.dart';
import '../models/printer_configuration.dart';

import 'database_service.dart';
import 'printer_configuration_service.dart';
import 'enhanced_printer_assignment_service.dart';
import 'enhanced_printer_manager.dart';

/// Service to validate printer assignments and connectivity before sending orders to kitchen
class PrinterValidationService extends ChangeNotifier {
  static const String _logTag = '🔒 PrinterValidationService';
  
  final DatabaseService _databaseService;
  final PrinterConfigurationService _printerConfigService;
  final EnhancedPrinterAssignmentService _assignmentService;
  final EnhancedPrinterManager _printerManager;
  
  PrinterValidationService({
    required DatabaseService databaseService,
    required PrinterConfigurationService printerConfigService,
    required EnhancedPrinterAssignmentService assignmentService,
    required EnhancedPrinterManager printerManager,
  }) : _databaseService = databaseService,
       _printerConfigService = printerConfigService,
       _assignmentService = assignmentService,
       _printerManager = printerManager;

  /// Comprehensive validation before sending order to kitchen
  Future<PrinterValidationResult> validateOrderForKitchen(Order order) async {
    try {
      debugPrint('$_logTag 🔍 Validating order ${order.orderNumber} for kitchen submission...');
      
      // 1. Check if order has items
      if (order.items.isEmpty) {
        return PrinterValidationResult.failure(
          'Order has no items to send to kitchen',
          ValidationFailureType.noItems,
        );
      }

      // 2. Check if there are new items to send
      final newItems = order.items.where((item) => !item.sentToKitchen).toList();
      if (newItems.isEmpty) {
        return PrinterValidationResult.failure(
          'All items have already been sent to kitchen',
          ValidationFailureType.allItemsSent,
        );
      }

      // 3. Validate printer assignments for all items
      final assignmentResult = await _validateAssignmentCoverage(order);
      if (!assignmentResult.isValid) {
        return assignmentResult;
      }

      // 4. Check printer availability and connectivity
      final connectivityResult = await _validatePrinterConnectivity(order);
      if (!connectivityResult.isValid) {
        return connectivityResult;
      }

      // 5. Validate that all required printers are configured
      final configurationResult = await _validatePrinterConfiguration(order);
      if (!configurationResult.isValid) {
        return configurationResult;
      }

      debugPrint('$_logTag ✅ Order ${order.orderNumber} passed all validation checks');
      return PrinterValidationResult.success(
        'Order validated successfully for kitchen submission',
        _getValidationSummary(order),
      );

    } catch (e) {
      debugPrint('$_logTag ❌ Validation error for order ${order.orderNumber}: $e');
      return PrinterValidationResult.failure(
        'Validation failed: ${e.toString()}',
        ValidationFailureType.systemError,
      );
    }
  }

  /// Validate that all order items have printer assignments
  Future<PrinterValidationResult> _validateAssignmentCoverage(Order order) async {
    final List<String> unassignedItems = [];
    final Map<String, List<String>> itemAssignments = {};

    for (final item in order.items) {
      if (!item.sentToKitchen) {
        final assignments = _assignmentService.getAssignmentsForMenuItem(
          item.menuItem.id,
          item.menuItem.categoryId ?? '',
        );

        if (assignments.isEmpty) {
          unassignedItems.add(item.menuItem.name);
        } else {
          itemAssignments[item.menuItem.name] = assignments.map((a) => a.printerName).toList();
        }
      }
    }

    if (unassignedItems.isNotEmpty) {
      return PrinterValidationResult.failure(
        'The following items have no printer assignments:\n• ${unassignedItems.join('\n• ')}\n\nPlease assign these items to printers in Admin Panel → Printer Assignment.',
        ValidationFailureType.missingAssignments,
        details: {
          'unassignedItems': unassignedItems,
          'totalItems': order.items.length,
        },
      );
    }

    debugPrint('$_logTag ✅ All order items have printer assignments');
    return PrinterValidationResult.success(
      'All items have printer assignments',
      itemAssignments,
    );
  }

  /// Validate printer connectivity and availability
  Future<PrinterValidationResult> _validatePrinterConnectivity(Order order) async {
    // Get all printers needed for this order
    final Set<String> requiredPrinterIds = {};
    
    for (final item in order.items) {
      if (!item.sentToKitchen) {
        final assignments = _assignmentService.getAssignmentsForMenuItem(
          item.menuItem.id,
          item.menuItem.categoryId ?? '',
        );
        
        for (final assignment in assignments) {
          requiredPrinterIds.add(assignment.printerId);
        }
      }
    }

    if (requiredPrinterIds.isEmpty) {
      return PrinterValidationResult.failure(
        'No printers found for order items',
        ValidationFailureType.noPrintersFound,
      );
    }

    // Test connectivity to all required printers
    final Map<String, bool> connectivityResults = {};
    final List<String> offlinePrinters = [];
    final List<String> onlinePrinters = [];

    for (final printerId in requiredPrinterIds) {
      final printer = await _printerConfigService.getConfigurationById(printerId);
      
      if (printer == null) {
        offlinePrinters.add('Unknown Printer ($printerId)');
        connectivityResults[printerId] = false;
        continue;
      }

      // Test printer connection
      final isOnline = await _testPrinterConnection(printer);
      connectivityResults[printerId] = isOnline;
      
      if (isOnline) {
        onlinePrinters.add(printer.name);
      } else {
        offlinePrinters.add('${printer.name} (${printer.fullAddress})');
      }
    }

    // Check if any critical printers are offline
    if (offlinePrinters.isNotEmpty) {
      return PrinterValidationResult.failure(
        'The following printers are offline or unreachable:\n• ${offlinePrinters.join('\n• ')}\n\nPlease check printer connections and try again.',
        ValidationFailureType.printersOffline,
        details: {
          'offlinePrinters': offlinePrinters,
          'onlinePrinters': onlinePrinters,
          'connectivityResults': connectivityResults,
        },
      );
    }

    debugPrint('$_logTag ✅ All required printers are online: ${onlinePrinters.join(', ')}');
    return PrinterValidationResult.success(
      'All required printers are online',
      {
        'onlinePrinters': onlinePrinters,
        'totalPrinters': requiredPrinterIds.length,
      },
    );
  }

  /// Validate printer configuration completeness
  Future<PrinterValidationResult> _validatePrinterConfiguration(Order order) async {
    final List<String> configurationIssues = [];
    
    // Check if printer configuration service is initialized
    if (!_printerConfigService.isInitialized) {
      return PrinterValidationResult.failure(
        'Printer configuration service is not initialized',
        ValidationFailureType.serviceNotReady,
      );
    }

    // Check if assignment service is initialized
    if (!_assignmentService.isInitialized) {
      return PrinterValidationResult.failure(
        'Printer assignment service is not initialized',
        ValidationFailureType.serviceNotReady,
      );
    }

    // Check if there are any active printers at all
    final activePrinters = _printerConfigService.activeConfigurations;
    if (activePrinters.isEmpty) {
      return PrinterValidationResult.failure(
        'No active printers configured. Please configure at least one printer in Admin Panel → Printer Assignment.',
        ValidationFailureType.noPrintersConfigured,
      );
    }

    // Validate each required printer has proper configuration
    final Set<String> requiredPrinterIds = {};
    for (final item in order.items) {
      if (!item.sentToKitchen) {
        final assignments = _assignmentService.getAssignmentsForMenuItem(
          item.menuItem.id,
          item.menuItem.categoryId ?? '',
        );
        
        for (final assignment in assignments) {
          requiredPrinterIds.add(assignment.printerId);
        }
      }
    }

    for (final printerId in requiredPrinterIds) {
      final printer = await _printerConfigService.getConfigurationById(printerId);
      
      if (printer == null) {
        configurationIssues.add('Printer $printerId not found in configuration');
        continue;
      }

      if (!printer.isActive) {
        configurationIssues.add('${printer.name} is disabled');
      }

      if (printer.ipAddress.isEmpty || printer.port <= 0) {
        configurationIssues.add('${printer.name} has invalid network configuration');
      }
    }

    if (configurationIssues.isNotEmpty) {
      return PrinterValidationResult.failure(
        'Printer configuration issues found:\n• ${configurationIssues.join('\n• ')}',
        ValidationFailureType.configurationIssues,
        details: {'issues': configurationIssues},
      );
    }

    debugPrint('$_logTag ✅ All printer configurations are valid');
    return PrinterValidationResult.success(
      'All printer configurations are valid',
      {'validatedPrinters': requiredPrinterIds.length},
    );
  }

  /// Test connection to a specific printer
  Future<bool> _testPrinterConnection(PrinterConfiguration printer) async {
    try {
      // Use the printer manager to test the connection
      if (_printerManager.isInitialized) {
        final testResults = await _printerManager.testAllPrinters();
        return testResults[printer.id] ?? false;
      }
      
      // Fallback: basic network connectivity test
      return await _basicConnectivityTest(printer);
      
    } catch (e) {
      debugPrint('$_logTag ❌ Connection test failed for ${printer.name}: $e');
      return false;
    }
  }

  /// Basic network connectivity test
  Future<bool> _basicConnectivityTest(PrinterConfiguration printer) async {
    try {
      // This is a simplified test - in production you might want more sophisticated testing
      return printer.isActive && printer.ipAddress.isNotEmpty && printer.port > 0;
    } catch (e) {
      return false;
    }
  }

  /// Get validation summary for successful validation
  Map<String, dynamic> _getValidationSummary(Order order) {
    final newItems = order.items.where((item) => !item.sentToKitchen).toList();
    final Set<String> requiredPrinterIds = {};
    
    for (final item in newItems) {
      final assignments = _assignmentService.getAssignmentsForMenuItem(
        item.menuItem.id,
        item.menuItem.categoryId ?? '',
      );
      
      for (final assignment in assignments) {
        requiredPrinterIds.add(assignment.printerId);
      }
    }

    return {
      'totalItems': order.items.length,
      'newItems': newItems.length,
      'requiredPrinters': requiredPrinterIds.length,
      'orderNumber': order.orderNumber,
      'validatedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Quick validation for UI feedback (non-blocking)
  Future<bool> quickValidation(Order order) async {
    try {
      final result = await validateOrderForKitchen(order);
      return result.isValid;
    } catch (e) {
      debugPrint('$_logTag ⚠️ Quick validation error: $e');
      return false;
    }
  }
}

/// Result of printer validation
class PrinterValidationResult {
  final bool isValid;
  final String message;
  final ValidationFailureType? failureType;
  final Map<String, dynamic>? details;

  const PrinterValidationResult._({
    required this.isValid,
    required this.message,
    this.failureType,
    this.details,
  });

  factory PrinterValidationResult.success(String message, [Map<String, dynamic>? details]) {
    return PrinterValidationResult._(
      isValid: true,
      message: message,
      details: details,
    );
  }

  factory PrinterValidationResult.failure(
    String message,
    ValidationFailureType failureType, {
    Map<String, dynamic>? details,
  }) {
    return PrinterValidationResult._(
      isValid: false,
      message: message,
      failureType: failureType,
      details: details,
    );
  }

  @override
  String toString() => 'PrinterValidationResult(isValid: $isValid, message: $message)';
}

/// Types of validation failures
enum ValidationFailureType {
  noItems,
  allItemsSent,
  missingAssignments,
  printersOffline,
  noPrintersFound,
  noPrintersConfigured,
  configurationIssues,
  serviceNotReady,
  systemError,
} 