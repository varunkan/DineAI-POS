import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/order.dart';
import '../models/menu_item.dart';
import '../models/printer_configuration.dart';
import '../services/printing_service.dart';
import '../services/enhanced_printer_assignment_service.dart';
import '../services/printer_configuration_service.dart';

/// 🍽️ KITCHEN PRINTING SERVICE
/// 
/// This service handles ALL kitchen printing operations COMPLETELY INDEPENDENTLY
/// from order creation and Firebase sync operations.
/// 
/// Key Features:
/// - ✅ COMPLETELY SEPARATE from order creation
/// - ✅ Does NOT interfere with Firebase sync
/// - ✅ Handles printing failures gracefully
/// - ✅ Queues failed prints for retry
/// - ✅ Works offline
/// - ✅ Multiple printer support
class KitchenPrintingService extends ChangeNotifier {
  static const String _logTag = '🍽️ KitchenPrintingService';
  
  final PrintingService _printingService;
  final EnhancedPrinterAssignmentService _assignmentService;
  final PrinterConfigurationService _printerConfigService;
  
  // Service state
  bool _isInitialized = false;
  bool _isPrinting = false;
  
  // Print queue management
  final List<Map<String, dynamic>> _printQueue = [];
  final List<Map<String, dynamic>> _failedPrints = [];
  final Map<String, int> _retryCount = {};
  
  // Statistics
  int _totalPrints = 0;
  int _successfulPrints = 0;
  int _failedPrintsCount = 0;
  int _queuedPrints = 0;
  
  // Configuration
  bool _autoPrintEnabled = true;
  int _maxRetries = 3;
  Duration _retryDelay = const Duration(seconds: 5);
  
  KitchenPrintingService({
    required PrintingService printingService,
    required EnhancedPrinterAssignmentService assignmentService,
    required PrinterConfigurationService printerConfigService,
  }) : _printingService = printingService,
       _assignmentService = assignmentService,
       _printerConfigService = printerConfigService;
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isPrinting => _isPrinting;
  bool get autoPrintEnabled => _autoPrintEnabled;
  int get totalPrints => _totalPrints;
  int get successfulPrints => _successfulPrints;
  int get failedPrintsCount => _failedPrintsCount;
  int get queuedPrints => _printQueue.length;
  List<Map<String, dynamic>> get printQueue => List.unmodifiable(_printQueue);
  List<Map<String, dynamic>> get failedPrints => List.unmodifiable(_failedPrints);
  
  /// Initialize the kitchen printing service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      
      // Load configuration
      final prefs = await SharedPreferences.getInstance();
      _autoPrintEnabled = prefs.getBool('kitchen_auto_print_enabled') ?? true;
      _maxRetries = prefs.getInt('kitchen_max_retries') ?? 3;
      
      _isInitialized = true;
      
    } catch (e) {
      // Continue anyway - service can work with defaults
      _isInitialized = true;
    }
  }
  
  /// Print kitchen ticket for order (COMPLETELY INDEPENDENT operation)
  /// This method does NOT interfere with order creation or Firebase sync
  Future<Map<String, dynamic>> printKitchenTicket(Order order) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    try {
      
      // Increment total prints counter
      _totalPrints++;
      
      // Check if auto-print is enabled
      if (!_autoPrintEnabled) {
        _addToPrintQueue(order, 'auto_print_disabled');
        return {
          'success': false,
          'message': 'Auto-print disabled',
          'queued': true,
          'orderNumber': order.orderNumber,
        };
      }
      
      // Get printer assignments for order items
      final itemsByPrinter = await _getItemsByPrinter(order);
      if (itemsByPrinter.isEmpty) {
        _addToPrintQueue(order, 'no_printer_assignments');
        return {
          'success': false,
          'message': 'No printer assignments found',
          'queued': true,
          'orderNumber': order.orderNumber,
        };
      }
      
      // Attempt to print to each assigned printer
      final printResults = <Map<String, dynamic>>[];
      bool anySuccess = false;
      
      for (final entry in itemsByPrinter.entries) {
        final printerId = entry.key;
        final items = entry.value;
        
        try {
          final result = await _printToPrinter(order, printerId, items);
          printResults.add(result);
          
          if (result['success']) {
            anySuccess = true;
            _successfulPrints++;
          } else {
            _failedPrintsCount++;
          }
        } catch (e) {
          printResults.add({
            'printerId': printerId,
            'success': false,
            'error': e.toString(),
          });
          _failedPrintsCount++;
        }
      }
      
      // If any print succeeded, consider it a success
      if (anySuccess) {
        return {
          'success': true,
          'message': 'Kitchen ticket printed',
          'orderNumber': order.orderNumber,
          'printResults': printResults,
        };
      } else {
        // All prints failed, add to queue for retry
        _addToPrintQueue(order, 'all_prints_failed');
        return {
          'success': false,
          'message': 'All prints failed, queued for retry',
          'queued': true,
          'orderNumber': order.orderNumber,
          'printResults': printResults,
        };
      }
      
    } catch (e) {
      _failedPrintsCount++;
      
      // Add to queue for retry
      _addToPrintQueue(order, 'print_error');
      
      return {
        'success': false,
        'message': 'Print error: $e',
        'queued': true,
        'orderNumber': order.orderNumber,
      };
    }
  }
  
  /// Print to a specific printer
  Future<Map<String, dynamic>> _printToPrinter(Order order, String printerId, List<OrderItem> items) async {
    try {
      // Get printer configuration
      final printer = await _printerConfigService.getConfigurationById(printerId);
      if (printer == null) {
        return {
          'printerId': printerId,
          'success': false,
          'error': 'Printer not found',
        };
      }
      
      // Check if printer is online
      if (!printer.isActive) {
        return {
          'printerId': printerId,
          'success': false,
          'error': 'Printer offline',
        };
      }
      
      // Create print job
      final printJob = {
        'orderId': order.id,
        'orderNumber': order.orderNumber,
        'printerId': printerId,
        'printerName': printer.name,
        'items': items.map((item) => {
          'name': item.menuItem.name,
          'quantity': item.quantity,
          'variants': item.selectedVariant,
          'instructions': item.specialInstructions,
          'notes': item.notes,
        }).toList(),
        'orderData': {
          'tableId': order.tableId,
          'customerName': order.customerName,
          'orderTime': order.orderTime.toIso8601String(),
          'isUrgent': order.isUrgent,
          'priority': order.priority,
        },
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      // Send to printing service
      final printed = await _printingService.printKitchenTicket(order);
      
      if (printed) {
        return {
          'printerId': printerId,
          'success': true,
          'message': 'Printed successfully',
        };
      } else {
        return {
          'printerId': printerId,
          'success': false,
          'error': 'Print service failed',
        };
      }
      
    } catch (e) {
      return {
        'printerId': printerId,
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Get items grouped by printer assignments
  /// CRITICAL FIX: Only include items that haven't been sent to kitchen yet
  Future<Map<String, List<OrderItem>>> _getItemsByPrinter(Order order) async {
    try {
      final itemsByPrinter = <String, List<OrderItem>>{};
      
      // CRITICAL FIX: Filter out items that have already been sent to kitchen
      final newItems = order.items.where((item) => !item.sentToKitchen).toList();
      
      if (newItems.isEmpty) {
        return {};
      }
      
      
      for (final item in newItems) {
        final assignments = await _assignmentService.getAssignmentsForMenuItem(item.menuItem.id, item.menuItem.categoryId ?? '');
        
        for (final assignment in assignments) {
          final printerId = assignment.printerId;
          if (!itemsByPrinter.containsKey(printerId)) {
            itemsByPrinter[printerId] = [];
          }
          itemsByPrinter[printerId]!.add(item);
        }
      }
      
      return itemsByPrinter;
    } catch (e) {
      return {};
    }
  }
  
  /// Add order to print queue
  void _addToPrintQueue(Order order, String reason) {
    final queueItem = {
      'order': order.toJson(),
      'reason': reason,
      'timestamp': DateTime.now().toIso8601String(),
      'retryCount': 0,
    };
    
    _printQueue.add(queueItem);
    _queuedPrints++;
    
    
    notifyListeners();
  }
  
  /// Process print queue (can be called manually or automatically)
  Future<void> processPrintQueue() async {
    if (_isPrinting || _printQueue.isEmpty) return;
    
    _isPrinting = true;
    notifyListeners();
    
    try {
      
      final itemsToProcess = List<Map<String, dynamic>>.from(_printQueue);
      _printQueue.clear();
      _queuedPrints = 0;
      
      for (final queueItem in itemsToProcess) {
        try {
          final order = Order.fromJson(queueItem['order']);
          final retryCount = queueItem['retryCount'] as int;
          
          if (retryCount >= _maxRetries) {
            // Max retries exceeded, move to failed prints
            _failedPrints.add(queueItem);
            continue;
          }
          
          // Attempt to print
          final result = await printKitchenTicket(order);
          
          if (!result['success'] && result['queued'] == true) {
            // Still failed, increment retry count and re-queue
            queueItem['retryCount'] = retryCount + 1;
            _printQueue.add(queueItem);
            _queuedPrints++;
          }
          
          // Small delay between prints
          await Future.delayed(const Duration(milliseconds: 100));
          
        } catch (e) {
          // Re-queue with incremented retry count
          final retryCount = queueItem['retryCount'] as int;
          if (retryCount < _maxRetries) {
            queueItem['retryCount'] = retryCount + 1;
            _printQueue.add(queueItem);
            _queuedPrints++;
          } else {
            _failedPrints.add(queueItem);
          }
        }
      }
      
      
    } catch (e) {
    } finally {
      _isPrinting = false;
      notifyListeners();
    }
  }
  
  /// Enable/disable auto-print
  Future<void> setAutoPrintEnabled(bool enabled) async {
    _autoPrintEnabled = enabled;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('kitchen_auto_print_enabled', enabled);
    } catch (e) {
    }
    
    notifyListeners();
  }
  
  /// Clear failed prints
  void clearFailedPrints() {
    _failedPrints.clear();
    notifyListeners();
  }
  
  /// Retry failed print
  Future<void> retryFailedPrint(Map<String, dynamic> failedPrint) async {
    try {
      final order = Order.fromJson(failedPrint['order']);
      
      // Remove from failed prints
      _failedPrints.remove(failedPrint);
      
      // Add to print queue
      _addToPrintQueue(order, 'manual_retry');
      
    } catch (e) {
    }
  }
  
  /// Get service status
  Map<String, dynamic> getStatus() {
    return {
      'isInitialized': _isInitialized,
      'isPrinting': _isPrinting,
      'autoPrintEnabled': _autoPrintEnabled,
      'totalPrints': _totalPrints,
      'successfulPrints': _successfulPrints,
      'failedPrints': _failedPrintsCount,
      'queuedPrints': _queuedPrints,
      'queueLength': _printQueue.length,
      'failedPrintsCount': _failedPrints.length,
      'maxRetries': _maxRetries,
    };
  }
  
  @override
  void dispose() {
    // Clean up resources
    super.dispose();
  }
} 