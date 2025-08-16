import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

import 'package:ai_pos_system/models/order_log.dart';
import 'package:ai_pos_system/models/order.dart';
import 'package:ai_pos_system/services/database_service.dart';
import 'package:uuid/uuid.dart';

/// Service for comprehensive order operation logging and audit trail
class OrderLogService extends ChangeNotifier {
  final DatabaseService _databaseService;
  final List<OrderLog> _logs = [];
  final List<OrderLog> _orderLogs = []; // Add missing field
  final Map<String, List<OrderLog>> _orderLogsCache = {};
  bool _isInitialized = false;
  String? _currentSessionId;
  String? _currentDeviceId;
  String? _currentUserId;
  String? _currentUserName;

  OrderLogService(this._databaseService) {
    initialize();
  }

  /// Gets all logs
  List<OrderLog> get allLogs => List.unmodifiable(_logs);

  /// Gets logs for a specific order
  List<OrderLog> getLogsForOrder(String orderId) {
    final logs = _orderLogsCache[orderId] ?? [];
    debugPrint('🔍 getLogsForOrder($orderId): Found ${logs.length} logs');
    for (final log in logs) {
      debugPrint('  - ${log.action}: ${log.description} (${log.timestamp})');
    }
    return logs;
  }

  /// Reload logs for a specific order from database
  Future<void> reloadLogsForOrder(String orderId) async {
    try {
      if (_databaseService.isWeb) {
        // Web platform - use Hive storage
        final webLogs = await _databaseService.getWebOrderLogs();
        final orderLogs = <OrderLog>[];
        
        for (final row in webLogs) {
          final log = OrderLog.fromJson(row);
          if (log.orderId == orderId) {
            orderLogs.add(log);
          }
        }
        
        _orderLogsCache[orderId] = orderLogs;
        debugPrint('✅ Reloaded ${orderLogs.length} logs for order $orderId from web storage');
      } else {
        // Mobile/Desktop platform - use SQLite
        final db = await _databaseService.database;
        if (db == null) return;
        
        final results = await db.query(
          'order_logs',
          where: 'order_id = ?',
          whereArgs: [orderId],
          orderBy: 'timestamp DESC',
        );

        final orderLogs = <OrderLog>[];
        for (final row in results) {
          final log = OrderLog.fromJson(row);
          orderLogs.add(log);
        }
        
        _orderLogsCache[orderId] = orderLogs;
        debugPrint('✅ Reloaded ${orderLogs.length} logs for order $orderId from database');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to reload logs for order $orderId: $e');
    }
  }

  /// Gets recent logs (last 100)
  List<OrderLog> get recentLogs {
    final sorted = List<OrderLog>.from(_logs);
    sorted.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(100).toList();
  }

  /// Gets logs by action type
  List<OrderLog> getLogsByAction(OrderLogAction action) {
    return _logs.where((log) => log.action == action).toList();
  }

  /// Gets logs by user
  List<OrderLog> getLogsByUser(String userId) {
    return _logs.where((log) => log.performedBy == userId).toList();
  }

  /// Gets logs within date range
  List<OrderLog> getLogsByDateRange(DateTime start, DateTime end) {
    return _logs.where((log) => 
      log.timestamp.isAfter(start) && log.timestamp.isBefore(end)
    ).toList();
  }

  /// Gets financial operation logs
  List<OrderLog> get financialLogs {
    return _logs.where((log) => log.isFinancialOperation).toList();
  }

  /// Gets kitchen operation logs
  List<OrderLog> get kitchenLogs {
    return _logs.where((log) => log.isKitchenOperation).toList();
  }

  /// Initialize the service
  Future<void> initialize() async {
    try {
      await _createOrderLogsTable();
      await _generateSessionId();
      await _detectDeviceId();
      await _loadRecentLogs();
      _isInitialized = true;
      debugPrint('✅ OrderLogService initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize OrderLogService: $e');
    }
  }

  /// Create the order logs table
  Future<void> _createOrderLogsTable() async {
    if (_databaseService.isWeb) {
      // Web platform - table creation is handled by web storage initialization
      debugPrint('✅ Order logs table created with indexes (web)');
      return;
    }
    
    final db = await _databaseService.database;
    if (db == null) return;
    
    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_logs (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        order_number TEXT NOT NULL,
        action TEXT NOT NULL,
        level TEXT NOT NULL DEFAULT 'info',
        performed_by TEXT NOT NULL,
        performed_by_name TEXT,
        timestamp TEXT NOT NULL,
        description TEXT NOT NULL,
        before_data TEXT,
        after_data TEXT,
        metadata TEXT,
        notes TEXT,
        device_id TEXT,
        session_id TEXT,
        ip_address TEXT,
        is_system_action INTEGER NOT NULL DEFAULT 0,
        error_message TEXT,
        amount_before REAL,
        amount_after REAL,
        table_id TEXT,
        customer_id TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Create indexes for performance
    await db.execute('CREATE INDEX IF NOT EXISTS idx_order_logs_order_id ON order_logs(order_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_order_logs_timestamp ON order_logs(timestamp DESC)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_order_logs_action ON order_logs(action)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_order_logs_performed_by ON order_logs(performed_by)');

    debugPrint('✅ Order logs table created with indexes');
  }

  /// Generate a unique session ID
  Future<void> _generateSessionId() async {
    _currentSessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Detect device ID
  Future<void> _detectDeviceId() async {
    try {
      if (kIsWeb) {
        _currentDeviceId = 'web_${DateTime.now().millisecondsSinceEpoch}';
      } else if (Platform.isAndroid || Platform.isIOS) {
        _currentDeviceId = 'mobile_${DateTime.now().millisecondsSinceEpoch}';
      } else {
        _currentDeviceId = 'desktop_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (e) {
      _currentDeviceId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// Load recent logs from database
  Future<void> _loadRecentLogs() async {
    try {
      if (_databaseService.isWeb) {
        // Web platform - use Hive storage
        final webLogs = await _databaseService.getWebOrderLogs();
        _logs.clear();
        _orderLogsCache.clear();

        for (final row in webLogs) {
          final log = OrderLog.fromJson(row);
          _logs.add(log);
          
          // Cache logs by order ID
          if (!_orderLogsCache.containsKey(log.orderId)) {
            _orderLogsCache[log.orderId] = [];
          }
          _orderLogsCache[log.orderId]!.add(log);
        }

        debugPrint('✅ Loaded ${_logs.length} order logs from web storage');
      } else {
        // Mobile/Desktop platform - use SQLite
        final db = await _databaseService.database;
        if (db == null) return;
        
        final results = await db.query(
          'order_logs',
          orderBy: 'timestamp DESC',
          limit: 1000, // Load last 1000 logs
        );

        _logs.clear();
        _orderLogsCache.clear();

        for (final row in results) {
          final log = OrderLog.fromJson(row);
          _logs.add(log);
          
          // Cache logs by order ID
          if (!_orderLogsCache.containsKey(log.orderId)) {
            _orderLogsCache[log.orderId] = [];
          }
          _orderLogsCache[log.orderId]!.add(log);
        }

        debugPrint('✅ Loaded ${_logs.length} order logs from database');
      }
    } catch (e) {
      debugPrint('❌ Failed to load order logs: $e');
    }
  }

  /// Set current user context
  void setCurrentUser(String userId, String userName) {
    _currentUserId = userId;
    _currentUserName = userName;
  }

  /// Log an order operation
  Future<bool> logOperation({
    required String orderId,
    required String orderNumber,
    required OrderLogAction action,
    required String description,
    required String performedBy,
    LogLevel level = LogLevel.info,
    Map<String, dynamic>? metadata,
    String? notes,
    String? deviceId,
    String? sessionId,
    String? ipAddress,
    bool isSystemAction = false,
    String? errorMessage,
    double? amountBefore,
    double? amountAfter,
    String? tableId,
    String? customerId,
  }) async {
    try {
      // Check if the order exists before logging
      // final orderService = Provider.of<OrderService?>(navigatorKey.currentContext!, listen: false);
      // if (orderService != null) {
      //   final orderExists = orderService.allOrders.any((order) => order.id == orderId);
      //   if (!orderExists) {
      //     debugPrint('⚠️ Order $orderId does not exist - skipping log entry');
      //     return false;
      //   }
      // }

      final log = OrderLog(
        id: const Uuid().v4(),
        orderId: orderId,
        orderNumber: orderNumber,
        action: action,
        level: level,
        performedBy: performedBy,
        timestamp: DateTime.now(),
        description: description,
        metadata: metadata ?? {},
        notes: notes,
        deviceId: deviceId,
        sessionId: sessionId,
        ipAddress: ipAddress,
        isSystemAction: isSystemAction,
        errorMessage: errorMessage,
        amountBefore: amountBefore,
        amountAfter: amountAfter,
        tableId: tableId,
        customerId: customerId,
      );

      final db = await _databaseService.database;
      if (db == null) {
        debugPrint('❌ Database not available for logging');
        return false;
      }

      final logMap = {
        'id': log.id,
        'order_id': log.orderId,
        'order_number': log.orderNumber,
        'action': log.action.toString().split('.').last,
        'level': log.level.toString().split('.').last,
        'performed_by': log.performedBy,
        'performed_by_name': log.performedByName,
        'timestamp': log.timestamp.toIso8601String(),
        'description': log.description,
        'before_data': jsonEncode(log.beforeData),
        'after_data': jsonEncode(log.afterData),
        'metadata': jsonEncode(log.metadata),
        'notes': log.notes,
        'device_id': log.deviceId,
        'session_id': log.sessionId,
        'ip_address': log.ipAddress,
        'is_system_action': log.isSystemAction ? 1 : 0,
        'error_message': log.errorMessage,
        'amount_before': log.amountBefore,
        'amount_after': log.amountAfter,
        'table_id': log.tableId,
        'customer_id': log.customerId,
        'created_at': log.timestamp.toIso8601String(),
      };

      await db.insert(
        'order_logs',
        logMap,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      _orderLogs.add(log);
      _orderLogs.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      debugPrint('📝 Logged operation: ${action.toString().split('.').last} for order $orderNumber');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to log operation: $e');
      // Don't throw - logging should not break the main flow
      return false;
    }
  }

  /// Save log to database
  Future<void> _saveLogToDatabase(OrderLog log) async {
    if (_databaseService.isWeb) {
      // Web platform - use Hive storage
      await _databaseService.saveWebOrderLog({
        'id': log.id,
        'order_id': log.orderId,
        'order_number': log.orderNumber,
        'action': log.action.toString().split('.').last,
        'level': log.level.toString().split('.').last,
        'performed_by': log.performedBy,
        'performed_by_name': log.performedByName,
        'timestamp': log.timestamp.toIso8601String(),
        'description': log.description,
        'before_data': jsonEncode(log.beforeData),
        'after_data': jsonEncode(log.afterData),
        'metadata': jsonEncode(log.metadata),
        'notes': log.notes,
        'device_id': log.deviceId,
        'session_id': log.sessionId,
        'ip_address': log.ipAddress,
        'is_system_action': log.isSystemAction,
        'error_message': log.errorMessage,
        'amount_before': log.amountBefore,
        'amount_after': log.amountAfter,
        'table_id': log.tableId,
        'customer_id': log.customerId,
        'created_at': DateTime.now().toIso8601String(),
      });
    } else {
      // Mobile/Desktop platform - use SQLite
      final db = await _databaseService.database;
      if (db == null) return;
      
      await db.insert('order_logs', {
        'id': log.id,
        'order_id': log.orderId,
        'order_number': log.orderNumber,
        'action': log.action.toString().split('.').last,
        'level': log.level.toString().split('.').last,
        'performed_by': log.performedBy,
        'performed_by_name': log.performedByName,
        'timestamp': log.timestamp.toIso8601String(),
        'description': log.description,
        'before_data': jsonEncode(log.beforeData),
        'after_data': jsonEncode(log.afterData),
        'metadata': jsonEncode(log.metadata),
        'notes': log.notes,
        'device_id': log.deviceId,
        'session_id': log.sessionId,
        'ip_address': log.ipAddress,
        'is_system_action': log.isSystemAction ? 1 : 0,
        'error_message': log.errorMessage,
        'amount_before': log.amountBefore,
        'amount_after': log.amountAfter,
        'table_id': log.tableId,
        'customer_id': log.customerId,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }

  /// Add log to cache
  void _addLogToCache(OrderLog log) {
    _logs.insert(0, log); // Add to beginning for newest first
    
    // Maintain cache size
    if (_logs.length > 1000) {
      _logs.removeLast();
    }

    // Add to order-specific cache
    if (!_orderLogsCache.containsKey(log.orderId)) {
      _orderLogsCache[log.orderId] = [];
    }
    _orderLogsCache[log.orderId]!.add(log);
  }

  /// Trigger haptic feedback
  void _triggerHapticFeedback() {
    try {
      HapticFeedback.mediumImpact();
    } catch (e) {
      // Ignore haptic feedback errors
    }
  }

  // Convenience methods for common operations

  /// Log order creation
  Future<bool> logOrderCreated(Order order, String performedBy) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.created,
      description: 'Order created',
      performedBy: performedBy,
      metadata: {
        'order_type': order.type.toString(),
        'item_count': order.items.length,
        'total_amount': order.totalAmount,
      },
    );
  }

  /// Log order update
  Future<bool> logOrderUpdated(Order order, String performedBy, Map<String, dynamic> changes) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.updated,
      description: 'Order updated',
      performedBy: performedBy,
      metadata: changes,
    );
  }

  /// Log order status change
  Future<bool> logOrderStatusChanged(Order order, OrderStatus oldStatus, OrderStatus newStatus, String performedBy) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.statusChanged,
      description: 'Order status changed from ${oldStatus.toString().split('.').last} to ${newStatus.toString().split('.').last}',
      performedBy: performedBy,
      metadata: {
        'old_status': oldStatus.toString(),
        'new_status': newStatus.toString(),
      },
    );
  }

  /// Log item added to order
  Future<bool> logItemAdded(Order order, OrderItem item, String performedBy) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.itemAdded,
      description: 'Item added: ${item.menuItem.name} x${item.quantity}',
      performedBy: performedBy,
      metadata: {
        'item_id': item.id,
        'item_name': item.menuItem.name,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'total_price': item.totalPrice,
      },
    );
  }

  /// Log item removed from order
  Future<bool> logItemRemoved(Order order, OrderItem item, String performedBy) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.itemRemoved,
      description: 'Item removed: ${item.menuItem.name} x${item.quantity}',
      performedBy: performedBy,
      metadata: {
        'item_id': item.id,
        'item_name': item.menuItem.name,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'total_price': item.totalPrice,
      },
    );
  }

  /// Log item modified in order
  Future<bool> logItemModified(Order order, OrderItem oldItem, OrderItem newItem, String performedBy) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.itemModified,
      description: 'Item modified: ${newItem.menuItem.name}',
      performedBy: performedBy,
      metadata: {
        'item_id': newItem.id,
        'item_name': newItem.menuItem.name,
        'old_quantity': oldItem.quantity,
        'new_quantity': newItem.quantity,
        'old_unit_price': oldItem.unitPrice,
        'new_unit_price': newItem.unitPrice,
      },
    );
  }

  /// Log item voided
  Future<bool> logItemVoided(Order order, OrderItem item, String performedBy, String reason) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.itemVoided,
      description: 'Item voided: ${item.menuItem.name} - $reason',
      performedBy: performedBy,
      metadata: {
        'item_id': item.id,
        'item_name': item.menuItem.name,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'total_price': item.totalPrice,
        'void_reason': reason,
      },
    );
  }

  /// Log discount applied
  Future<bool> logDiscountApplied(Order order, double discountAmount, String performedBy) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.discountApplied,
      description: 'Discount applied: \$${discountAmount.toStringAsFixed(2)}',
      performedBy: performedBy,
      amountBefore: order.totalAmount + discountAmount,
      amountAfter: order.totalAmount,
      metadata: {
        'discount_amount': discountAmount,
      },
    );
  }

  /// Log discount removed
  Future<bool> logDiscountRemoved(Order order, double discountAmount, String performedBy) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.discountRemoved,
      description: 'Discount removed: \$${discountAmount.toStringAsFixed(2)}',
      performedBy: performedBy,
      amountBefore: order.totalAmount - discountAmount,
      amountAfter: order.totalAmount,
      metadata: {
        'discount_amount': discountAmount,
      },
    );
  }

  /// Log gratuity added
  Future<bool> logGratuityAdded(Order order, double gratuityAmount, String performedBy) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.gratuityAdded,
      description: 'Gratuity added: \$${gratuityAmount.toStringAsFixed(2)}',
      performedBy: performedBy,
      amountBefore: order.totalAmount - gratuityAmount,
      amountAfter: order.totalAmount,
      metadata: {
        'gratuity_amount': gratuityAmount,
      },
    );
  }

  /// Log gratuity modified
  Future<bool> logGratuityModified(Order order, double oldGratuity, double newGratuity, String performedBy) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.gratuityModified,
      description: 'Gratuity modified: \$${oldGratuity.toStringAsFixed(2)} → \$${newGratuity.toStringAsFixed(2)}',
      performedBy: performedBy,
      amountBefore: order.totalAmount - newGratuity + oldGratuity,
      amountAfter: order.totalAmount,
      metadata: {
        'old_gratuity': oldGratuity,
        'new_gratuity': newGratuity,
      },
    );
  }

  /// Log sent to kitchen
  Future<bool> logSentToKitchen(Order order, String performedBy) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.sentToKitchen,
      description: 'Order sent to kitchen',
      performedBy: performedBy,
      metadata: {
        'item_count': order.items.length,
        'items_sent': order.items.map((item) => {
          'id': item.id,
          'name': item.menuItem.name,
          'quantity': item.quantity,
        }).toList(),
      },
    );
  }

  /// Log kitchen status change
  Future<bool> logKitchenStatusChanged(Order order, String oldStatus, String newStatus, String performedBy) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.kitchenStatusChanged,
      description: 'Kitchen status changed: $oldStatus → $newStatus',
      performedBy: performedBy,
      metadata: {
        'old_status': oldStatus,
        'new_status': newStatus,
      },
    );
  }

  /// Log payment processed
  Future<bool> logPaymentProcessed(Order order, double amount, String paymentMethod, String performedBy) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.paymentProcessed,
      description: 'Payment processed: \$${amount.toStringAsFixed(2)} via $paymentMethod',
      performedBy: performedBy,
      amountBefore: order.totalAmount,
      amountAfter: 0.0,
      metadata: {
        'payment_amount': amount,
        'payment_method': paymentMethod,
      },
    );
  }

  /// Log payment refunded
  Future<bool> logPaymentRefunded(Order order, double amount, String performedBy) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.paymentRefunded,
      description: 'Payment refunded: \$${amount.toStringAsFixed(2)}',
      performedBy: performedBy,
      amountBefore: 0.0,
      amountAfter: order.totalAmount,
      metadata: {
        'refund_amount': amount,
      },
    );
  }

  /// Log note added
  Future<bool> logNoteAdded(Order order, String note, String performedBy) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.noteAdded,
      description: 'Note added: $note',
      performedBy: performedBy,
      metadata: {
        'note': note,
      },
    );
  }

  /// Log order cancelled
  Future<bool> logOrderCancelled(Order order, String performedBy, String reason) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.cancelled,
      description: 'Order cancelled: $reason',
      performedBy: performedBy,
      metadata: {
        'cancellation_reason': reason,
      },
    );
  }

  /// Log order refunded
  Future<bool> logOrderRefunded(Order order, String performedBy, String reason) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.refunded,
      description: 'Order refunded: $reason',
      performedBy: performedBy,
      metadata: {
        'refund_reason': reason,
      },
    );
  }

  /// Log order completed
  Future<bool> logOrderCompleted(Order order, String performedBy) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.completed,
      description: 'Order completed',
      performedBy: performedBy,
      metadata: {
        'completion_time': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Log order reopened
  Future<bool> logOrderReopened(Order order, String performedBy) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.reopened,
      description: 'Order reopened',
      performedBy: performedBy,
    );
  }

  /// Log order transferred
  Future<bool> logOrderTransferred(Order order, String fromTable, String toTable, String performedBy) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.transferred,
      description: 'Order transferred: Table $fromTable → Table $toTable',
      performedBy: performedBy,
      metadata: {
        'from_table': fromTable,
        'to_table': toTable,
      },
    );
  }

  /// Log order split
  Future<bool> logOrderSplit(Order originalOrder, List<Order> splitOrders, String performedBy) async {
    return await logOperation(
      orderId: originalOrder.id,
      orderNumber: originalOrder.orderNumber,
      action: OrderLogAction.split,
      description: 'Order split into ${splitOrders.length} orders',
      performedBy: performedBy,
      metadata: {
        'split_orders': splitOrders.map((order) => {
          'id': order.id,
          'order_number': order.orderNumber,
          'item_count': order.items.length,
        }).toList(),
      },
    );
  }

  /// Log order merged
  Future<bool> logOrderMerged(List<Order> sourceOrders, Order mergedOrder, String performedBy) async {
    return await logOperation(
      orderId: mergedOrder.id,
      orderNumber: mergedOrder.orderNumber,
      action: OrderLogAction.merged,
      description: 'Orders merged from ${sourceOrders.length} source orders',
      performedBy: performedBy,
      metadata: {
        'source_orders': sourceOrders.map((order) => {
          'id': order.id,
          'order_number': order.orderNumber,
          'item_count': order.items.length,
        }).toList(),
      },
    );
  }

  /// Log order printed
  Future<bool> logOrderPrinted(Order order, String performedBy, String printType) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.printed,
      description: 'Order printed: $printType',
      performedBy: performedBy,
      metadata: {
        'print_type': printType,
      },
    );
  }

  /// Log email sent
  Future<bool> logEmailSent(Order order, String performedBy, String emailType) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.emailSent,
      description: 'Email sent: $emailType',
      performedBy: performedBy,
      metadata: {
        'email_type': emailType,
      },
    );
  }

  /// Log custom action
  Future<bool> logCustomAction(Order order, String action, String description, String performedBy, Map<String, dynamic>? metadata) async {
    return await logOperation(
      orderId: order.id,
      orderNumber: order.orderNumber,
      action: OrderLogAction.customAction,
      description: description,
      performedBy: performedBy,
      metadata: metadata ?? {},
    );
  }

  /// Get analytics data
  Map<String, dynamic> getAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final filteredLogs = _logs.where((log) {
      if (startDate != null && log.timestamp.isBefore(startDate)) return false;
      if (endDate != null && log.timestamp.isAfter(endDate)) return false;
      return true;
    }).toList();

    final actionCounts = <String, int>{};
    final userCounts = <String, int>{};
    final hourlyActivity = <int, int>{};
    double totalFinancialImpact = 0.0;

    for (final log in filteredLogs) {
      // Count actions
      final actionKey = log.action.toString().split('.').last;
      actionCounts[actionKey] = (actionCounts[actionKey] ?? 0) + 1;

      // Count by user
      final userKey = log.performedByName ?? log.performedBy;
      userCounts[userKey] = (userCounts[userKey] ?? 0) + 1;

      // Hourly activity
      final hour = log.timestamp.hour;
      hourlyActivity[hour] = (hourlyActivity[hour] ?? 0) + 1;

      // Financial impact
      if (log.financialImpact != null) {
        totalFinancialImpact += log.financialImpact!;
      }
    }

    return {
      'total_logs': filteredLogs.length,
      'action_counts': actionCounts,
      'user_counts': userCounts,
      'hourly_activity': hourlyActivity,
      'total_financial_impact': totalFinancialImpact,
      'financial_operations': filteredLogs.where((log) => log.isFinancialOperation).length,
      'kitchen_operations': filteredLogs.where((log) => log.isKitchenOperation).length,
      'error_count': filteredLogs.where((log) => log.level == LogLevel.error).length,
      'warning_count': filteredLogs.where((log) => log.level == LogLevel.warning).length,
    };
  }

  /// Clean up old logs (keep last 30 days)
  Future<void> cleanupOldLogs() async {
    try {
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final db = await _databaseService.database;
      if (db == null) return;
      
      final deletedCount = await db.delete(
        'order_logs',
        where: 'timestamp < ?',
        whereArgs: [cutoffDate.toIso8601String()],
      );

      // Reload logs after cleanup
      await _loadRecentLogs();
      
      debugPrint('✅ Cleaned up $deletedCount old log entries');
    } catch (e) {
      debugPrint('❌ Failed to cleanup old logs: $e');
    }
  }

  /// Export logs to JSON
  Map<String, dynamic> exportLogs({
    DateTime? startDate,
    DateTime? endDate,
    String? orderId,
    String? userId,
  }) {
    var filteredLogs = _logs.where((log) {
      if (startDate != null && log.timestamp.isBefore(startDate)) return false;
      if (endDate != null && log.timestamp.isAfter(endDate)) return false;
      if (orderId != null && log.orderId != orderId) return false;
      if (userId != null && log.performedBy != userId) return false;
      return true;
    }).toList();

    return {
      'export_date': DateTime.now().toIso8601String(),
      'total_logs': filteredLogs.length,
      'filters': {
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
        'order_id': orderId,
        'user_id': userId,
      },
      'logs': filteredLogs.map((log) => log.toJson()).toList(),
    };
  }

  /// Delete old order logs (older than specified days)
  Future<int> deleteOldLogs({int daysToKeep = 30}) async {
    if (kIsWeb) {
      // Web platform - clean up web storage
      try {
        final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
        final allLogs = await _databaseService.getWebOrderLogs();
        
        int deletedCount = 0;
        final updatedLogs = <Map<String, dynamic>>[];
        
        for (final log in allLogs) {
          final logDate = DateTime.tryParse(log['timestamp']?.toString() ?? '') ?? DateTime.now();
          if (logDate.isAfter(cutoffDate)) {
            updatedLogs.add(log);
          } else {
            deletedCount++;
          }
        }
        
        // Save updated logs back to web storage
        await _databaseService.saveWebOrderLogs(updatedLogs);
        
        debugPrint('🧹 Deleted $deletedCount old order logs from web storage');
        return deletedCount;
      } catch (e) {
        debugPrint('❌ Error deleting old web order logs: $e');
        return 0;
      }
    }
    
    try {
      final db = await _databaseService.database;
      if (db == null) {
        debugPrint('❌ Database not available for deleting old logs');
        return 0;
      }
      
      final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
      final deletedCount = await db.delete(
        'order_logs',
        where: 'timestamp < ?',
        whereArgs: [cutoffDate.toIso8601String()],
      );
      
      debugPrint('🧹 Deleted $deletedCount old order logs');
      return deletedCount;
    } catch (e) {
      debugPrint('❌ Error deleting old order logs: $e');
      return 0;
    }
  }

  @override
  void dispose() {
    _logs.clear();
    _orderLogsCache.clear();
    super.dispose();
  }
} 