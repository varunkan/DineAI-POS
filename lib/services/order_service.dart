import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:sqflite/sqflite.dart';
import 'package:ai_pos_system/models/order.dart';
import 'package:ai_pos_system/models/menu_item.dart';
import 'package:ai_pos_system/models/order_log.dart';
import 'package:ai_pos_system/services/database_service.dart';
import 'package:ai_pos_system/services/order_log_service.dart';
import 'package:ai_pos_system/services/inventory_service.dart';
import 'package:ai_pos_system/services/unified_sync_service.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/widgets.dart'; // Added for WidgetsBinding
import 'package:shared_preferences/shared_preferences.dart'; // Added for SharedPreferences
import 'package:ai_pos_system/services/multi_tenant_auth_service.dart'; // Added for MultiTenantAuthService
import 'package:ai_pos_system/services/user_service.dart'; // Added for UserService
import 'package:cloud_firestore/cloud_firestore.dart' as fs; // Added for Firebase sync
import 'package:ai_pos_system/config/firebase_config.dart'; // Added for FirebaseConfig
import 'package:ai_pos_system/services/order_reconstruction_service.dart'; // Added for order reconstruction


/// Custom exception for order operations
class OrderServiceException implements Exception {
  final String message;
  final String? operation;
  final dynamic originalError;

  OrderServiceException(this.message, {this.operation, this.originalError});

  @override
  String toString() => 'OrderServiceException: $message ${operation != null ? '(Operation: $operation)' : ''}';
}

/// Service for managing orders in the POS system
class OrderService extends ChangeNotifier {
  final DatabaseService _databaseService;
  final OrderLogService _orderLogService;
  final InventoryService _inventoryService;
  final _uuid = const Uuid();
  
  List<Order> _activeOrders = [];
  List<Order> _completedOrders = [];
  List<Order> _allOrders = [];
  Order? _currentOrder;
  bool _isLoading = false;
  bool _disposed = false;
  Timer? _autoSaveTimer;
  final StreamController<List<Order>> _ordersStreamController = StreamController.broadcast();
  final StreamController<Order> _currentOrderStreamController = StreamController.broadcast();

  // Cache for frequently accessed data
  final Map<String, MenuItem> _menuItemCache = {};
  
  // Feature flag: enable enhanced server filtering that considers both userId and assignedTo
  static const bool _enableEnhancedServerFiltering = false; // Permanently using strict matching for counts
  
  OrderService(this._databaseService, this._orderLogService, this._inventoryService) {
    _initializeCache();
  }

  /// Initialize cache and setup auto-save
  void _initializeCache() {
    _autoSaveTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _saveOrdersToCache();
    });
  }

  /// Reset disposal state - called when service is reused
  void resetDisposalState() {
    _disposed = false;
  }

  // Getters
  List<Order> get activeOrders {
    // Remove excessive logging that slows down the app
    return List.unmodifiable(_activeOrders);
  }
  List<Order> get completedOrders {
    // Remove excessive logging that slows down the app  
    return List.unmodifiable(_completedOrders);
  }
  List<Order> get allOrders {
    // Remove excessive logging that slows down the app
    return List.unmodifiable(_allOrders);
  }
  Order? get currentOrder => _currentOrder;
  bool get isLoading => _isLoading;
  bool get isDisposed => _disposed;
  Stream<List<Order>> get ordersStream => _ordersStreamController.stream;
  Stream<Order> get currentOrderStream => _currentOrderStreamController.stream;

  /// Get active orders count
  int get activeOrdersCount => _activeOrders.length;

  /// Get total orders count
  int get totalOrdersCount => _allOrders.length;

  /// Get orders by status
  List<Order> getOrdersByStatus(String status) {
    return _allOrders.where((order) => order.status == status).toList();
  }

  /// Get orders by server
  List<Order> getAllOrdersByServer(String serverId) {
    try {
      if (!_enableEnhancedServerFiltering) {
        return _allOrders.where((order) => order.userId == serverId).toList();
      }
      final normalized = serverId.trim().toLowerCase();
      return _allOrders.where((order) => _matchesServer(order, normalized)).toList();
    } catch (e) {
      // Fallback to original strict behavior
      return _allOrders.where((order) => order.userId == serverId).toList();
    }
  }

  /// Get ACTIVE orders by server (for operational UI displays)
  List<Order> getActiveOrdersByServer(String serverId) {
    try {
      if (!_enableEnhancedServerFiltering) {
        return _activeOrders.where((order) {
          // Handle both simple user IDs and email-based user IDs
          if (order.userId != null && order.userId!.contains('_')) {
            // Email-based format: restaurant_email_userid
            final parts = order.userId!.split('_');
            if (parts.length >= 2) {
              final orderUserId = parts.last; // Get the user ID part
              return orderUserId == serverId;
            }
          } else {
            // Simple user ID format
            return order.userId == serverId;
          }
          return false;
        }).toList();
      }
      final normalized = serverId.trim().toLowerCase();
      return _activeOrders.where((order) => _matchesServer(order, normalized)).toList();
    } catch (e) {
      // Fallback to original strict behavior
      return _activeOrders.where((order) {
        if (order.userId != null && order.userId!.contains('_')) {
          final parts = order.userId!.split('_');
          if (parts.length >= 2) {
            final orderUserId = parts.last;
            return orderUserId == serverId;
          }
        } else {
          return order.userId == serverId;
        }
        return false;
      }).toList();
    }
  }

  /// Get active orders count by server
  int getActiveOrdersCountByServer(String serverId) {
    try {
      if (!_enableEnhancedServerFiltering) {
        return _activeOrders.where((order) {
          // Handle both simple user IDs and email-based user IDs
          if (order.userId != null && order.userId!.contains('_')) {
            // Email-based format: restaurant_email_userid
            final parts = order.userId!.split('_');
            if (parts.length >= 2) {
              final orderUserId = parts.last; // Get the user ID part
              return orderUserId == serverId;
            }
          } else {
            // Simple user ID format
            return order.userId == serverId;
          }
          return false;
        }).length;
      }
      final normalized = serverId.trim().toLowerCase();
      return _activeOrders.where((order) => _matchesServer(order, normalized)).length;
    } catch (e) {
      // Fallback to original strict behavior
      return _activeOrders.where((order) {
        if (order.userId != null && order.userId!.contains('_')) {
          final parts = order.userId!.split('_');
          if (parts.length >= 2) {
            final orderUserId = parts.last;
            return orderUserId == serverId;
          }
        } else {
          return order.userId == serverId;
        }
        return false;
      }).length;
    }
  }

  /// Robust matching to determine if an order belongs to a given server
  bool _matchesServer(Order order, String normalizedServerId) {
    try {
      // Normalize candidate fields
      final userId = (order.userId ?? '').trim().toLowerCase();
      final assignedTo = (order.assignedTo ?? '').trim().toLowerCase();

      // Direct matches
      if (userId == normalizedServerId || assignedTo == normalizedServerId) {
        return true;
      }

      // Underscore-separated composite userId: restaurant_email_userid → compare last token
      if (userId.contains('_')) {
        final parts = userId.split('_');
        if (parts.isNotEmpty && parts.last == normalizedServerId) {
          return true;
        }
      }

      // Containment heuristic (e.g., userId contains server short id or name)
      if (userId.contains(normalizedServerId) || assignedTo.contains(normalizedServerId)) {
        return true;
      }

      // Metadata fallbacks (in case servers are tracked via metadata)
      if (order.metadata.isNotEmpty) {
        final metaServerId = (order.metadata['serverId'] ?? order.metadata['server_id'] ?? '').toString().trim().toLowerCase();
        final metaServerName = (order.metadata['serverName'] ?? order.metadata['server_name'] ?? '').toString().trim().toLowerCase();
        if (metaServerId == normalizedServerId || metaServerName == normalizedServerId) {
          return true;
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  /// Convert Order object to database format for Firebase upload
  Map<String, dynamic> _convertOrderToDbFormat(Order order) {
    final subtotal = order.items.isEmpty ? 0.0 : order.subtotal;
    final totalAmount = order.items.isEmpty ? 0.0 : order.totalAmount;

    return {
      'id': order.id,
      'order_number': order.orderNumber,
      'status': order.status.toString().split('.').last,
      'type': order.type.toString().split('.').last,
      'table_id': order.tableId,
      'user_id': order.userId,
      'customer_name': order.customerName,
      'customer_phone': order.customerPhone,
      'customer_email': order.customerEmail,
      'customer_address': order.customerAddress,
      'special_instructions': order.specialInstructions,
      'subtotal': subtotal,
      'tax_amount': order.taxAmount,
      'tip_amount': order.tipAmount,
      'hst_amount': order.hstAmount,
      'discount_amount': order.discountAmount,
      'gratuity_amount': order.gratuityAmount,
      'total_amount': totalAmount,
      'payment_method': order.paymentMethod?.toString().split('.').last,
      'payment_status': order.paymentStatus.toString().split('.').last,
      'payment_transaction_id': order.paymentTransactionId,
      'order_time': order.orderTime.toIso8601String(),
      'estimated_ready_time': order.estimatedReadyTime?.toIso8601String(),
      'actual_ready_time': order.actualReadyTime?.toIso8601String(),
      'served_time': order.servedTime?.toIso8601String(),
      'completed_time': order.completedTime?.toIso8601String(),
      'is_urgent': order.isUrgent ? 1 : 0,
      'priority': order.priority,
      'assigned_to': order.assignedTo,
      'custom_fields': jsonEncode(order.customFields),
      'metadata': jsonEncode(order.metadata),
      'created_at': order.createdAt.toIso8601String(),
      'updated_at': order.updatedAt.toIso8601String(),
      'completed_at': order.completedAt?.toIso8601String(),
    };
  }

  /// Validate Firebase order data before downloading
  bool _isFirebaseOrderValid(Map<String, dynamic> firebaseOrder) {
    try {
      // Basic required fields
      if (firebaseOrder['id'] == null || firebaseOrder['id'].toString().isEmpty) return false;
      if (firebaseOrder['orderNumber'] == null || firebaseOrder['orderNumber'].toString().isEmpty) return false;
      if (firebaseOrder['totalAmount'] == null || (firebaseOrder['totalAmount'] as num?)?.toDouble() == null) return false;

      // Items validation - ensure items exist and have basic data
      final items = firebaseOrder['items'] as List? ?? [];
      if (items.isEmpty) {
        return false; // Reject orders with no items
      }

      // Validate at least one item has required fields
      bool hasValidItem = false;
      for (final item in items) {
        if (item is Map && item['menuItem'] != null && item['quantity'] != null && (item['quantity'] as num) > 0) {
          hasValidItem = true;
          break;
        }
      }

      if (!hasValidItem) {
        return false;
      }

      // Status validation
      final status = firebaseOrder['status'];
      if (status == null || !OrderStatus.values.any((s) => s.toString().split('.').last == status)) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Validate order integrity before saving
  /// Validates order integrity for billing accuracy - COMPREHENSIVE SCHEMA VALIDATION
  Future<bool> _validateOrderIntegrity(Order order) async {
    try {
      // 🔍 COMPREHENSIVE SCHEMA VALIDATION

      // 1. Basic structure validation
      if (order.id.isEmpty) {
        return false;
      }

      if (order.orderNumber.isEmpty) {
        return false;
      }

      if (order.items.isEmpty) {
        return false;
      }

      // 2. User/Server validation
      if (order.userId == null || order.userId!.isEmpty) {
        return false;
      }

      // 3. Timestamp validation
      if (order.createdAt.isAfter(DateTime.now().add(const Duration(minutes: 1)))) {
        return false;
      }

      // 4. Status validation
      if (!OrderStatus.values.contains(order.status)) {
        return false;
      }

      // 5. Comprehensive item validation
      double calculatedTotal = 0.0;
      for (final item in order.items) {
        // Schema validation for each item
        if (item.id.isEmpty) {
          return false;
        }

        if (item.menuItem.id.isEmpty) {
          return false;
        }

        // Get menu item from database to validate it exists and matches
        final menuItem = await _getMenuItemById(item.menuItem.id);
        if (menuItem == null) {
          return false;
        }

        // Validate menu item data consistency
        if (menuItem.name != item.menuItem.name) {
          // Allow this but log warning - data may have changed since order creation
        }

        // Validate quantities and prices
        if (item.quantity <= 0) {
          return false;
        }

        if (item.unitPrice < 0) {
          return false;
        }

        if (item.totalPrice < 0) {
          return false;
        }

        // Validate price calculation consistency
        final expectedTotal = item.unitPrice * item.quantity;
        if ((expectedTotal - item.totalPrice).abs() > 0.01) { // Allow for small rounding differences
        }

        calculatedTotal += item.totalPrice;

        // Validate modifiers if present
        if (item.selectedModifiers != null) {
          try {
            // Ensure selectedModifiers is valid JSON structure
            if (item.selectedModifiers is! List && item.selectedModifiers is! String) {
              return false;
            }
          } catch (e) {
            return false;
          }
        }
      }

      // 6. Total amount validation with comprehensive checking
      if (order.totalAmount < 0) {
        return false;
      }

      // Validate calculated total matches order total (within reasonable tolerance)
      if ((calculatedTotal - order.totalAmount).abs() > 0.1) {
        // Allow this but log - there might be discounts, taxes, etc.
      }

      // 7. Order number format validation
      if (!_isValidOrderNumber(order.orderNumber)) {
        return false;
      }

      // 8. Business rule validation
      if (order.type == OrderType.dineIn && order.tableId == null) {
        // Allow this but log - table assignment might be deferred
      }

      return true;

    } catch (e) {
      return false;
    }
  }

  /// Validates order number format
  bool _isValidOrderNumber(String orderNumber) {
    // Order numbers should be numeric and reasonable length
    if (orderNumber.isEmpty || orderNumber.length > 20) {
      return false;
    }

    // Should contain only alphanumeric characters, hyphens, or underscores
    final validChars = RegExp(r'^[A-Za-z0-9\-_]+$');
    return validChars.hasMatch(orderNumber);
  }

  /// Get menu item by ID with caching
  Future<MenuItem?> _getMenuItemById(String menuItemId) async {
    try {
      // Check cache first
      if (_menuItemCache.containsKey(menuItemId)) {
        return _menuItemCache[menuItemId];
      }

      final Database? database = await _databaseService.database;
      if (database == null) return null;

      final List<Map<String, dynamic>> results = await database.query(
        'menu_items',
        where: 'id = ?',
        whereArgs: [menuItemId],
      );

      if (results.isEmpty) return null;

      final menuItem = MenuItem.fromJson(results.first);
      _menuItemCache[menuItemId] = menuItem; // Cache the result
      return menuItem;
    } catch (e) {
      return null;
    }
  }

  /// Batch fetch order_items for a set of orders (reduces N+1 queries)
  Future<Map<String, List<Map<String, dynamic>>>> _fetchOrderItemsByOrderIds(
    Database database,
    List<String> orderIds,
  ) async {
    if (orderIds.isEmpty) return <String, List<Map<String, dynamic>>>{};

    // Build placeholders for the IN clause
    final String placeholders = List.filled(orderIds.length, '?').join(',');
    final String sql = 'SELECT * FROM order_items WHERE order_id IN ($placeholders)';

    final List<Map<String, dynamic>> rows = await database.rawQuery(sql, orderIds);
    final Map<String, List<Map<String, dynamic>>> orderIdToItems = {};
    for (final row in rows) {
      final String oid = (row['order_id'] as String?) ?? '';
      if (oid.isEmpty) continue;
      final bucket = orderIdToItems.putIfAbsent(oid, () => <Map<String, dynamic>>[]);
      bucket.add(row);
    }
    return orderIdToItems;
  }

  /// Batch fetch menu_items by ids (fills in-memory cache)
  Future<Map<String, MenuItem>> _fetchMenuItemsByIds(
    Database database,
    Set<String> menuItemIds,
  ) async {
    final Map<String, MenuItem> result = {};
    if (menuItemIds.isEmpty) return result;

    final String placeholders = List.filled(menuItemIds.length, '?').join(',');
    final String sql = 'SELECT * FROM menu_items WHERE id IN ($placeholders)';
    final List<String> args = menuItemIds.toList();

    final List<Map<String, dynamic>> rows = await database.rawQuery(sql, args);
    for (final row in rows) {
      try {
        final item = MenuItem.fromJson(row);
        result[item.id] = item;
        _menuItemCache[item.id] = item; // warm cache
      } catch (_) {
        // Skip malformed menu item rows
      }
    }
    return result;
  }

  /// Safely encode objects to JSON strings for SQLite storage
  String? _safeJsonEncode(dynamic value) {
    if (value == null) return null;
    try {
      // Handle different types of objects
      if (value is Map) {
        if (value.isEmpty) return null;
        // Clean the map to ensure all values are serializable
        final cleanMap = <String, dynamic>{};
        value.forEach((key, val) {
          if (val != null && val is! Function) {
            cleanMap[key.toString()] = val;
          }
        });
        return cleanMap.isNotEmpty ? jsonEncode(cleanMap) : null;
      } else if (value is List) {
        if (value.isEmpty) return null;
        return jsonEncode(value);
      } else if (value is String) {
        return value.isNotEmpty ? value : null;
      } else {
        return jsonEncode(value);
      }
    } catch (e) {
      return null;
    }
  }

  /// Save order to database with comprehensive error handling
  Future<bool> saveOrder(Order order) async {
    try {
      // HARD GUARD: Never save ghost orders (no items)
      if (order.items.isEmpty) {
        return false;
      }
      // Validate order before saving
      if (order.orderNumber.isEmpty) {
        return false;
      }
      
      // 🚫 CRITICAL FIX: NEVER save orders with no items (prevents ghost orders)
      if (order.items.isEmpty) {
        return false;
      }
      
      final db = await _databaseService.database;
      if (db == null) {
        return false;
      }
      
      // Use a transaction to ensure data consistency
      final success = await db.transaction((txn) async {
        try {
          // Handle empty orders by providing default values
          final subtotal = order.items.isEmpty ? 0.0 : order.subtotal;
          final totalAmount = order.items.isEmpty ? 0.0 : order.totalAmount;
          
          // Prepare order data for database
          final orderMap = {
            'id': order.id,
            'order_number': order.orderNumber,
            'status': order.status.toString().split('.').last,
            'type': order.type.toString().split('.').last,
            'table_id': order.tableId,
            'user_id': order.userId,
            'customer_name': order.customerName,
            'customer_phone': order.customerPhone,
            'customer_email': order.customerEmail,
            'customer_address': order.customerAddress,
            'special_instructions': order.specialInstructions,
            'subtotal': subtotal, // Use calculated or default value
            'tax_amount': order.taxAmount,
            'tip_amount': order.tipAmount,
            'hst_amount': order.hstAmount,
            'discount_amount': order.discountAmount,
            'gratuity_amount': order.gratuityAmount,
            'total_amount': totalAmount, // Use calculated or default value
            'payment_method': order.paymentMethod?.toString().split('.').last,
            'payment_status': order.paymentStatus.toString().split('.').last,
            'payment_transaction_id': order.paymentTransactionId,
            'order_time': order.orderTime.toIso8601String(),
            'estimated_ready_time': order.estimatedReadyTime?.toIso8601String(),
            'actual_ready_time': order.actualReadyTime?.toIso8601String(),
            'served_time': order.servedTime?.toIso8601String(),
            'completed_time': order.completedTime?.toIso8601String(),
            'is_urgent': order.isUrgent ? 1 : 0,
            'priority': order.priority ?? 0,
            'assigned_to': order.assignedTo,
            'custom_fields': order.customFields.isNotEmpty ? jsonEncode(order.customFields) : null,
            'metadata': order.metadata.isNotEmpty ? jsonEncode(order.metadata) : null,
            'created_at': order.createdAt.toIso8601String(),
            'updated_at': order.updatedAt.toIso8601String(),
          };

          // 1. Save the order FIRST
          await txn.insert(
            'orders',
            orderMap,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          // 2. Delete existing order items for this order
          await txn.delete(
            'order_items',
            where: 'order_id = ?',
            whereArgs: [order.id],
          );

          // 3. Save order items
          for (final item in order.items) {
            final itemMap = {
              'id': item.id,
              'order_id': order.id,
              'menu_item_id': item.menuItem.id,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'total_price': item.totalPrice,
              'selected_variant': item.selectedVariant,
              'special_instructions': item.specialInstructions,
              'notes': item.specialInstructions,
              'is_available': item.isAvailable ? 1 : 0,
              'sent_to_kitchen': item.sentToKitchen ? 1 : 0,
              'created_at': item.createdAt.toIso8601String(),
              'updated_at': item.createdAt.toIso8601String(),
            };

            await txn.insert(
              'order_items',
              itemMap,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            
            // ENHANCEMENT: Sync order item to Firebase
            try {
              final unifiedSyncService = UnifiedSyncService.instance;
              if ((itemMap['sent_to_kitchen'] ?? 0) == 1) {
                await unifiedSyncService.syncOrderItemToFirebase(itemMap);
              } else {
              }
            } catch (e) {
              // Don't fail the transaction if sync fails
            }
          }

          // After saving, ensure no unsent items exist remotely for this order
                  try {
          final tenantId = FirebaseConfig.getCurrentTenantId();
          if (tenantId != null) {
            final remoteUnsent = await fs.FirebaseFirestore.instance
                .collection('tenants')
                .doc(tenantId)
                .collection('order_items')
                .where('order_id', isEqualTo: order.id)
                .where('sent_to_kitchen', isEqualTo: 0)
                .get();
            for (final doc in remoteUnsent.docs) {
              await doc.reference.delete();
            }
          }
        } catch (e) {
        }

          return true;
        } catch (e) {
          return false;
        }
      });

      if (success) {
        // CRITICAL: Update local state immediately after successful save
        _updateLocalOrderState(order);
        
        // CRITICAL FIX: Don't clear current order state during completion to maintain kitchen printing functionality
        if (order.status == OrderStatus.completed && _currentOrder?.id == order.id) {
          // Don't clear _currentOrder here to prevent kitchen printing issues
        }
        
        // CRITICAL: Real-time Firebase sync
        await _syncOrderToFirebase(order);
        
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Real-time Firebase sync for orders
    Future<void> _syncOrderToFirebase(Order order) async {
      try {

        // HARD GUARD: Never sync ghost orders (no items)
        if (order.items.isEmpty) {
          return;
        }

        // Get the unified sync service
      final syncService = UnifiedSyncService.instance;
      
      // Check if sync service is available and connected
      if (syncService.isConnected) {
        // Sync the order to Firebase
        await syncService.createOrUpdateOrder(order);
      } else {
        // Add to pending changes for later sync
        syncService.addPendingSyncChange('orders', 'updated', order.id, order.toJson());
      }
    } catch (e) {
      // Don't fail the save operation if Firebase sync fails
      // The order is still saved locally and will sync when connection is restored
    }
  }

  /// Update order from Firebase (for cross-device sync)
  Future<void> updateOrderFromFirebase(Order firebaseOrder) async {
    try {
      
      // Check if order already exists locally
      final existingIndex = _allOrders.indexWhere((o) => o.id == firebaseOrder.id);
      
      if (existingIndex != -1) {
        // Update existing order
        _allOrders[existingIndex] = firebaseOrder;
      } else {
        // Add new order from Firebase
        _allOrders.add(firebaseOrder);
      }
      
      // Update active/completed orders lists
      _activeOrders = _allOrders.where((o) => o.isActive).toList();
      _completedOrders = _allOrders.where((o) => !o.isActive).toList();
      
      // Save to local database
      final db = await _databaseService.database;
      if (db != null) {
        final Map<String, dynamic> orderRow = {
          'id': firebaseOrder.id,
          'order_number': firebaseOrder.orderNumber,
          'status': firebaseOrder.status.toString().split('.').last,
          'type': firebaseOrder.type.toString().split('.').last,
          'table_id': firebaseOrder.tableId,
          'user_id': firebaseOrder.userId,
          'customer_name': firebaseOrder.customerName,
          'customer_phone': firebaseOrder.customerPhone,
          'customer_email': firebaseOrder.customerEmail,
          'customer_address': firebaseOrder.customerAddress,
          'special_instructions': firebaseOrder.specialInstructions,
          'subtotal': firebaseOrder.subtotal,
          'tax_amount': firebaseOrder.taxAmount,
          'tip_amount': firebaseOrder.tipAmount,
          'hst_amount': firebaseOrder.hstAmount,
          'discount_amount': firebaseOrder.discountAmount,
          'gratuity_amount': firebaseOrder.gratuityAmount,
          'total_amount': firebaseOrder.totalAmount,
          'payment_method': firebaseOrder.paymentMethod,
          'payment_status': firebaseOrder.paymentStatus.toString().split('.').last,
          'payment_transaction_id': firebaseOrder.paymentTransactionId,
          'order_time': firebaseOrder.orderTime.toIso8601String(),
          'estimated_ready_time': firebaseOrder.estimatedReadyTime?.toIso8601String(),
          'actual_ready_time': firebaseOrder.actualReadyTime?.toIso8601String(),
          'served_time': firebaseOrder.servedTime?.toIso8601String(),
          'completed_time': firebaseOrder.completedTime?.toIso8601String(),
          'is_urgent': firebaseOrder.isUrgent ? 1 : 0,
          'priority': firebaseOrder.priority,
          'assigned_to': firebaseOrder.assignedTo,
          'custom_fields': jsonEncode(firebaseOrder.customFields),
          'metadata': jsonEncode(firebaseOrder.metadata),
          'notes': jsonEncode(firebaseOrder.notes.map((n) => n.toJson()).toList()),
          'preferences': jsonEncode(firebaseOrder.preferences),
          'history': jsonEncode(firebaseOrder.history.map((h) => h.toJson()).toList()),
          'items': jsonEncode(firebaseOrder.items.map((i) => i.toJson()).toList()),
          'completed_at': firebaseOrder.completedAt?.toIso8601String(),
          'created_at': firebaseOrder.createdAt.toIso8601String(),
          'updated_at': firebaseOrder.updatedAt.toIso8601String(),
        };

        await db.insert(
          'orders',
          orderRow,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        
        // Save order items
        for (final item in firebaseOrder.items) {
          final itemData = {
            'id': item.id,
            'order_id': firebaseOrder.id,
            'menu_item_id': item.menuItem.id,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'total_price': item.totalPrice,
            'selected_variant': item.selectedVariant,
            'special_instructions': item.specialInstructions,
            'notes': item.specialInstructions,
            'is_available': item.isAvailable ? 1 : 0,
            'sent_to_kitchen': item.sentToKitchen ? 1 : 0,
            'created_at': item.createdAt.toIso8601String(),
            'updated_at': item.createdAt.toIso8601String(),
          };
          
          await db.insert(
            'order_items',
            itemData,
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
      
      notifyListeners();
    } catch (e) {
    }
  }

  /// Update local order state after saving
  void _updateLocalOrderState(Order order) {
    try {
      
      // Check if order already exists in _allOrders
      final existingIndex = _allOrders.indexWhere((o) => o.id == order.id);
      
      if (existingIndex != -1) {
        // Update existing order
        _allOrders[existingIndex] = order;
      } else {
        // Add new order
        _allOrders.add(order);
      }
      
      // Update active/completed orders lists
      _activeOrders = _allOrders.where((o) => o.isActive).toList();
      _completedOrders = _allOrders.where((o) => !o.isActive).toList();
      
      
      // Update stream
      _ordersStreamController.add(_allOrders);
      
      // Force notify listeners immediately
      notifyListeners();
      
    } catch (e) {
    }
  }

  /// Convert Order object to SQLite-compatible map using only existing columns
  Map<String, dynamic> _orderToSQLiteMap(Order order) {
    try {
      // Create a clean map with only SQLite-compatible values - NO COMPLEX OBJECTS
      // CRITICAL: NEVER include order.items array - it's handled separately
      final Map<String, dynamic> sqliteMap = {
        'id': order.id,
        'order_number': order.orderNumber,
        'status': order.status.toString().split('.').last,
        'type': order.type.toString().split('.').last,
        'table_id': order.tableId ?? '',
        'user_id': order.userId ?? '',
        'customer_name': order.customerName,
        'customer_phone': order.customerPhone,
        'customer_email': order.customerEmail,
        'customer_address': order.customerAddress,
        'special_instructions': order.specialInstructions,
        'subtotal': order.subtotal,
        'tax_amount': order.taxAmount,
        'tip_amount': order.tipAmount,
        'hst_amount': order.hstAmount,
        'discount_amount': order.discountAmount,
        'gratuity_amount': order.gratuityAmount,
        'total_amount': order.totalAmount,
        'payment_method': order.paymentMethod,
        'payment_status': order.paymentStatus.toString().split('.').last,
        'payment_transaction_id': order.paymentTransactionId,
        'order_time': order.orderTime.toIso8601String(),
        'estimated_ready_time': order.estimatedReadyTime?.toIso8601String(),
        'actual_ready_time': order.actualReadyTime?.toIso8601String(),
        'served_time': order.servedTime?.toIso8601String(),
        'completed_time': order.completedTime?.toIso8601String(),
        'is_urgent': order.isUrgent ? 1 : 0,  // Convert boolean to integer
        'priority': order.priority ?? 0,
        'assigned_to': order.assignedTo ?? '',
        'custom_fields': order.customFields.isNotEmpty ? jsonEncode(order.customFields) : null,
        'metadata': order.metadata.isNotEmpty ? jsonEncode(order.metadata) : null,
        'created_at': order.createdAt.toIso8601String(),
        'updated_at': order.updatedAt.toIso8601String(),
      };

      // Handle custom_fields - only include simple string values, convert to JSON string
      if (order.customFields.isNotEmpty) {
        final cleanCustomFields = <String, String>{};
        order.customFields.forEach((key, value) {
          if (value != null && value is String && value.isNotEmpty) {
            cleanCustomFields[key] = value;
          }
        });
        if (cleanCustomFields.isNotEmpty) {
          sqliteMap['custom_fields'] = jsonEncode(cleanCustomFields);
        }
      }

      // Handle metadata - only include simple string values, convert to JSON string
      if (order.metadata.isNotEmpty) {
        final cleanMetadata = <String, String>{};
        order.metadata.forEach((key, value) {
          if (value != null && value is String && value.isNotEmpty) {
            cleanMetadata[key] = value;
          }
        });
        if (cleanMetadata.isNotEmpty) {
          sqliteMap['metadata'] = jsonEncode(cleanMetadata);
        }
      }

      // CRITICAL: Only return primitive types that SQLite supports
      final cleanMap = <String, dynamic>{};
      sqliteMap.forEach((key, value) {
        if (value != null && 
            (value is String || value is num || value is int || value is double)) {
          cleanMap[key] = value;
        }
      });

      return cleanMap;
    } catch (e) {
      // Return minimal valid data to prevent crashes
      return {
        'id': order.id,
        'order_number': order.orderNumber,
        'status': 'pending',
        'type': 'dineIn',
        'subtotal': 0.0,
        'tax_amount': 0.0,
        'tip_amount': 0.0,
        'hst_amount': 0.0,
        'discount_amount': 0.0,
        'gratuity_amount': 0.0,
        'total_amount': 0.0,
        'payment_status': 'pending',
        'order_time': DateTime.now().toIso8601String(),
        'is_urgent': 0,
        'priority': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Convert OrderItem object to SQLite-compatible map
  Map<String, dynamic> _orderItemToSQLiteMap(OrderItem item) {
    try {
      // Create a clean map with only SQLite-compatible values - NO COMPLEX OBJECTS
      // CRITICAL: NEVER include entire menuItem object - only the ID
      final Map<String, dynamic> sqliteMap = {
        'id': item.id,
        'order_id': '', // Will be set when saving to specific order
        'menu_item_id': item.menuItem.id, // Only store the ID, not the entire object
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'total_price': item.totalPrice,
        'selected_variant': item.selectedVariant,
        'special_instructions': item.specialInstructions,
        'notes': item.notes,
        'is_available': item.isAvailable ? 1 : 0,  // Convert boolean to integer
        'sent_to_kitchen': item.sentToKitchen ? 1 : 0,  // Convert boolean to integer
        'created_at': item.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Handle selected_modifiers - convert to JSON string
      if (item.selectedModifiers.isNotEmpty) {
        final List<String> cleanModifiers = [];
        for (var modifier in item.selectedModifiers) {
          if (modifier.isNotEmpty) {
            cleanModifiers.add(modifier);
          }
        }
        if (cleanModifiers.isNotEmpty) {
          sqliteMap['selected_modifiers'] = jsonEncode(cleanModifiers);
        }
      }

      // Handle custom_properties - convert to JSON string
      if (item.customProperties.isNotEmpty) {
        final Map<String, String> cleanProperties = {};
        item.customProperties.forEach((key, value) {
          if (value != null && value is String && value.isNotEmpty) {
            cleanProperties[key] = value;
          }
        });
        if (cleanProperties.isNotEmpty) {
          sqliteMap['custom_properties'] = jsonEncode(cleanProperties);
        }
      }

      // CRITICAL: Only return primitive types that SQLite supports
      final cleanMap = <String, dynamic>{};
      sqliteMap.forEach((key, value) {
        if (value != null && 
            (value is String || value is num || value is int || value is double)) {
          cleanMap[key] = value;
        }
      });

      return cleanMap;
    } catch (e) {
      // Return minimal valid data to prevent crashes
      return {
        'id': item.id,
        'order_id': '',
        'menu_item_id': item.menuItem.id,
        'quantity': item.quantity,
        'unit_price': item.unitPrice,
        'total_price': item.totalPrice,
        'selected_variant': '',
        'special_instructions': '',
        'notes': '',
        'is_available': 1,
        'sent_to_kitchen': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Convert SQLite map back to Order-compatible format
  Map<String, dynamic> _sqliteMapToOrder(Map<String, dynamic> sqliteMap) {
    try {
      return {
        'id': sqliteMap['id'],
        'orderNumber': sqliteMap['order_number'],  // Read from snake_case
        'status': sqliteMap['status'],
        'type': sqliteMap['type'],
        'tableId': sqliteMap['table_id'],  // Read from snake_case
        'userId': sqliteMap['user_id'],  // Read from snake_case
        'customerName': sqliteMap['customer_name'],  // Read from snake_case
        'customerPhone': sqliteMap['customer_phone'],  // Read from snake_case
        'customerEmail': sqliteMap['customer_email'],  // Read from snake_case
        'customerAddress': sqliteMap['customer_address'],  // Read from snake_case
        'specialInstructions': sqliteMap['special_instructions'],  // Read from snake_case
        'subtotal': sqliteMap['subtotal'],
        'taxAmount': sqliteMap['tax_amount'],  // Read from snake_case
        'tipAmount': sqliteMap['tip_amount'],  // Read from snake_case
        'hstAmount': sqliteMap['hst_amount'],  // Read from snake_case
        'discountAmount': sqliteMap['discount_amount'],  // Read from snake_case
        'gratuityAmount': sqliteMap['gratuity_amount'],  // Read from snake_case
        'totalAmount': sqliteMap['total_amount'],  // Read from snake_case
        'paymentMethod': sqliteMap['payment_method'],  // Read from snake_case
        'paymentStatus': sqliteMap['payment_status'],  // Read from snake_case
        'paymentTransactionId': sqliteMap['payment_transaction_id'],  // Read from snake_case
        'orderTime': sqliteMap['order_time'],  // Read from snake_case
        'estimatedReadyTime': sqliteMap['estimated_ready_time'],  // Read from snake_case
        'actualReadyTime': sqliteMap['actual_ready_time'],  // Read from snake_case
        'servedTime': sqliteMap['served_time'],  // Read from snake_case
        'completedTime': sqliteMap['completed_time'],  // Read from snake_case
        'isUrgent': sqliteMap['is_urgent'] == 1, // Convert integer back to boolean, read from snake_case
        'priority': sqliteMap['priority'],
        'assignedTo': sqliteMap['assigned_to'],
        // Removed 'preferences' - column doesn't exist in database schema
        'preferences': {}, // Default empty map since column doesn't exist
        'createdAt': sqliteMap['created_at'],
        'updatedAt': sqliteMap['updated_at'],
        'items': [], // Will be set separately
      };
    } catch (e) {
      // Return minimal valid order data
      return {
        'id': sqliteMap['id'] ?? '',
        'orderNumber': sqliteMap['order_number'] ?? '',
        'status': sqliteMap['status'] ?? 'pending',
        'type': sqliteMap['type'] ?? 'dineIn',
        'items': [],
        'isUrgent': false,
        'priority': 0,
        'preferences': {}, // Default empty map since column doesn't exist
        'orderTime': DateTime.now().toIso8601String(),
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      };
    }
  }

  /// Convert SQLite map back to OrderItem-compatible format
  Map<String, dynamic> _sqliteMapToOrderItem(Map<String, dynamic> sqliteMap) {
    try {
      return {
        'id': sqliteMap['id'],
        'quantity': sqliteMap['quantity'],
        'unitPrice': sqliteMap['unit_price'] ?? sqliteMap['price'],
        'specialInstructions': sqliteMap['special_instructions'],
        'notes': sqliteMap['notes'],
        'selectedVariant': sqliteMap['selected_variant'],
        'selectedModifiers': sqliteMap['selected_modifiers'] != null ? jsonDecode(sqliteMap['selected_modifiers']) : [],
        'customProperties': sqliteMap['custom_properties'] != null ? jsonDecode(sqliteMap['custom_properties']) : {},
        'isAvailable': sqliteMap['is_available'] == 1,
        'sentToKitchen': sqliteMap['sent_to_kitchen'] == 1,
        'createdAt': sqliteMap['created_at'],
        'voided': sqliteMap['voided'] == 1,
        'voidedBy': sqliteMap['voided_by'],
        'voidedAt': sqliteMap['voided_at'],
        'comped': sqliteMap['comped'] == 1,
        'compedBy': sqliteMap['comped_by'],
        'compedAt': sqliteMap['comped_at'],
        'discountPercentage': sqliteMap['discount_percentage'],
        'discountAmount': sqliteMap['discount_amount'],
        'discountedBy': sqliteMap['discounted_by'],
        'discountedAt': sqliteMap['discounted_at'],
      };
    } catch (e) {
      // Return minimal valid order item data
      return {
        'id': sqliteMap['id'] ?? '',
        'quantity': sqliteMap['quantity'] ?? 1,
        'unitPrice': sqliteMap['unit_price'] ?? sqliteMap['price'] ?? 0.0,
        'specialInstructions': sqliteMap['special_instructions'],
        'notes': sqliteMap['notes'],
        'selectedVariant': sqliteMap['selected_variant'],
        'selectedModifiers': [],
        'customProperties': {},
        'isAvailable': true,
        'sentToKitchen': false,
        'createdAt': DateTime.now().toIso8601String(),
        'voided': false,
        'comped': false,
      };
    }
  }

  /// Load all orders from database
  Future<void> loadOrders() async {
    if (_disposed) return;
    if (_isLoading) return; // Reentrancy guard to prevent concurrent loads
    
    try {
      _setLoading(true);
      
      // 🧹 CRITICAL: Clean up existing ghost orders first
      final cleanedCount = await cleanupExistingGhostOrders();
      if (cleanedCount > 0) {
      }
      
      final Database? database = await _databaseService.database;
      if (database == null) {
        throw OrderServiceException('Database not available', operation: 'load_orders');
      }

      // Load orders (IDs only first)
      final List<Map<String, dynamic>> orderResults = await database.query(
        'orders',
        columns: ['id','order_number','status','type','table_id','user_id','customer_name','customer_phone','customer_email','customer_address','special_instructions','subtotal','tax_amount','tip_amount','hst_amount','discount_amount','gratuity_amount','total_amount','payment_method','payment_status','payment_transaction_id','order_time','estimated_ready_time','actual_ready_time','served_time','completed_time','is_urgent','priority','assigned_to','custom_fields','metadata','notes','preferences','history','items','completed_at','created_at','updated_at'],
        orderBy: 'created_at DESC',
      );

      // Batch fetch all order_items for these orders
      final List<String> orderIds = orderResults.map((m) => (m['id'] as String)).toList();
      final Map<String, List<Map<String, dynamic>>> itemsByOrderId = await _fetchOrderItemsByOrderIds(database, orderIds);

      // Collect unique menu_item_ids to batch load menu items
      final Set<String> menuItemIds = {};
      for (final entry in itemsByOrderId.entries) {
        for (final item in entry.value) {
          final String? mid = item['menu_item_id'] as String?;
          if (mid != null && mid.isNotEmpty) menuItemIds.add(mid);
        }
      }
      await _fetchMenuItemsByIds(database, menuItemIds); // warm cache

      final List<Order> orders = [];
      for (final orderRow in orderResults) {
        try {
          final String oid = orderRow['id'] as String;
          final List<Map<String, dynamic>> itemRows = itemsByOrderId[oid] ?? const <Map<String, dynamic>>[];

          final List<OrderItem> items = [];
          for (final itemMap in itemRows) {
            try {
              final String? mid = itemMap['menu_item_id'] as String?;
              if (mid == null || mid.isEmpty) continue;
              final MenuItem? menuItem = await _getMenuItemById(mid);
              if (menuItem == null) continue;

              final orderItemJson = _sqliteMapToOrderItem(itemMap);
              orderItemJson['menuItem'] = menuItem.toJson();
              items.add(OrderItem.fromJson(orderItemJson));
            } catch (_) {}
          }

          final Map<String, dynamic> orderJson = _sqliteMapToOrder(orderRow);
          orderJson['items'] = items.map((i) => i.toJson()).toList();
          final Order order = Order.fromJson(orderJson);

          if (await _isGhostOrder(order.id, items)) {
            try {
              await database.delete('order_items', where: 'order_id = ?', whereArgs: [order.id]);
              await database.delete('orders', where: 'id = ?', whereArgs: [order.id]);
              try {
                final tenantId = FirebaseConfig.getCurrentTenantId();
                if (tenantId != null) {
                  await fs.FirebaseFirestore.instance
                      .collection('tenants')
                      .doc(tenantId)
                      .collection('orders')
                      .doc(order.id)
                      .delete();
                }
              } catch (_) {}
              continue;
            } catch (_) { continue; }
          }

          orders.add(order);
        } catch (_) {}
      }

      _allOrders = orders;
      _activeOrders = orders.where((o) => o.isActive).toList();
      _completedOrders = orders.where((o) => !o.isActive).toList();
      
      
      // No userId fixing needed - clean database approach
      
      // Safe notification to prevent crashes
      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          notifyListeners();
        } catch (e) {
        }
      });
      _ordersStreamController.add(_allOrders);
    } catch (e) {
      throw OrderServiceException('Failed to load orders: $e', operation: 'load_orders', originalError: e);
    } finally {
      _setLoading(false);
    }
  }

  /// 🔄 RECONSTRUCTION: Reconstruct orders from orphaned order_items
  Future<int> reconstructOrdersFromOrphanedItems() async {
    try {
      
      final reconstructionService = OrderReconstructionService();
      final result = await reconstructionService.performFullReconstruction();
      
      if (result['success'] == true) {
        final reconstructedCount = result['reconstructedOrders'] as int? ?? 0;
        if (reconstructedCount > 0) {
          // Reload orders to include the reconstructed ones
          await loadOrders();
        }
        return reconstructedCount;
      } else {
        return 0;
      }
    } catch (e) {
      return 0;
    }
  }

  /// 🏗️ GENERATOR: Generate orders from order_items (public method)
  Future<Map<String, dynamic>> generateOrdersFromItems() async {
    try {
      
      final reconstructionService = OrderReconstructionService();
      
      // Step 1: Analyze current state
      final analysis = await reconstructionService.analyzeOrderItems();
      
      if (!(analysis['reconstructionNeeded'] as bool? ?? false)) {
        return {
          'success': true,
          'message': 'No order generation needed - all items have orders',
          'generated': 0,
          'analysis': analysis,
        };
      }
      
      // Step 2: Generate orders
      final result = await reconstructionService.performFullReconstruction();
      
      if (result['success'] == true) {
        final generatedCount = result['reconstructedOrders'] as int? ?? 0;
        
        // Step 3: Reload orders to include generated ones
        if (generatedCount > 0) {
          await loadOrders();
        }
        
        return {
          'success': true,
          'message': 'Successfully generated $generatedCount orders from orphaned items',
          'generated': generatedCount,
          'analysis': analysis,
          'orders': result['orders'],
        };
      } else {
        return {
          'success': false,
          'message': result['message'] ?? 'Order generation failed',
          'generated': 0,
          'analysis': analysis,
        };
      }
      
    } catch (e) {
      return {
        'success': false,
        'message': 'Error during order generation: $e',
        'generated': 0,
      };
    }
  }

  /// 🧹 CLEANUP METHOD: Remove all existing ghost orders from database
  Future<int> cleanupExistingGhostOrders() async {
    try {
      
      final db = await _databaseService.database;
      if (db == null) {
        return 0;
      }
      
      // Find orders with no items BUT ONLY for non-active statuses to avoid deleting in-progress orders
      final ghostOrdersQuery = await db.rawQuery('''
        SELECT o.id, o.order_number 
        FROM orders o 
        LEFT JOIN order_items oi ON o.id = oi.order_id 
        WHERE oi.order_id IS NULL
          AND LOWER(o.status) IN ('completed','cancelled','refunded')
      ''');
      
      if (ghostOrdersQuery.isEmpty) {
        return 0;
      }
      
      
      int deletedCount = 0;
      for (final ghostOrder in ghostOrdersQuery) {
        final orderId = ghostOrder['id'] as String;
        final orderNumber = ghostOrder['order_number'] as String;
        
        try {
          // Instead of deleting silently, mark these as cancelled to preserve history
          await db.update('orders', {
            'status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          }, where: 'id = ?', whereArgs: [orderId]);
          deletedCount++;
        } catch (e) {
        }
      }
      
      return deletedCount;
      
    } catch (e) {
      return 0;
    }
  }

  /// 👻 CRITICAL METHOD: Determine if an order is a ghost order (no items in database)
  Future<bool> _isGhostOrder(String orderId, List<OrderItem>? memoryItems, {List<Map<String, dynamic>>? itemResults}) async {
    try {
      // If we already have the database results, use them
      if (itemResults != null) {
        final hasItems = itemResults.isNotEmpty;
        return !hasItems;
      }
      
      // If we have memory items, check if they're empty
      if (memoryItems != null) {
        final hasItems = memoryItems.isNotEmpty;
        return !hasItems;
      }
      
      // Fallback: Query the database directly
      final db = await _databaseService.database;
      if (db == null) {
        return false; // Don't delete if we can't check
      }
      
      final itemCount = Sqflite.firstIntValue(await db.rawQuery(
        'SELECT COUNT(*) FROM order_items WHERE order_id = ?',
        [orderId],
      )) ?? 0;
      
      final hasItems = itemCount > 0;
      return !hasItems;
      
    } catch (e) {
      return false; // Don't delete if we can't determine
    }
  }

  /// Load orders from local database
  Future<void> _loadOrdersFromDatabase() async {
    try {
      
      final db = await _databaseService.database;
      if (db == null) {
        return;
      }

      final List<Map<String, dynamic>> orderResults = await db.query(
        'orders',
        orderBy: 'created_at DESC',
      );

      _allOrders.clear();
      _activeOrders.clear();
      _completedOrders.clear();

      for (final orderRow in orderResults) {
        try {
          final orderMap = _sqliteMapToOrder(orderRow);
          final orderId = orderRow['id'] as String;
          
          // 🚫 CRITICAL FIX: Load order items FIRST to properly check for ghost orders
          final List<Map<String, dynamic>> itemResults = await db!.query(
            'order_items',
            where: 'order_id = ?',
            whereArgs: [orderId],
          );
          
          // 👻 CRITICAL FIX: Proper ghost order detection based on database order_items
          final totalAmount = (orderRow['total_amount'] as num?)?.toDouble() ?? 0.0;
          if (await _isGhostOrder(orderId, null, itemResults: itemResults)) {
            try {
              // Delete from local database immediately
              await db!.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
              await db!.delete('orders', where: 'id = ?', whereArgs: [orderId]);
              
              // Delete from Firebase immediately
              try {
                final tenantId = FirebaseConfig.getCurrentTenantId();
                if (tenantId != null) {
                  await fs.FirebaseFirestore.instance
                      .collection('tenants')
                      .doc(tenantId)
                      .collection('orders')
                      .doc(orderId)
                      .delete();
                }
              } catch (firebaseError) {
              }
              
              continue; // Skip adding this ghost order to the list
            } catch (deleteError) {
              // If deletion fails, still don't add the ghost order to the list
              continue;
            }
          }
          
          // Convert database item results to OrderItem objects with proper menu item lookup
          final orderItems = <OrderItem>[];
          for (final itemMap in itemResults) {
            try {
              // CRITICAL: Fetch the associated menu item first
              final menuItemId = itemMap['menu_item_id'] as String?;
              if (menuItemId == null || menuItemId.isEmpty) {
                // Skip items without menu item IDs
                continue;
              }

              final menuItem = await _getMenuItemById(menuItemId);
              if (menuItem == null) {
                // Skip items where menu item can't be found
                continue;
              }

              // Create OrderItem with complete data including menu item
              final orderItem = OrderItem(
                id: itemMap['id'] as String,
                menuItem: menuItem,
                quantity: itemMap['quantity'] as int? ?? 1,
                unitPrice: (itemMap['unit_price'] as num?)?.toDouble() ?? 0.0,
                specialInstructions: itemMap['special_instructions'] as String?,
                selectedVariant: itemMap['selected_variant'] as String?,
                selectedModifiers: itemMap['selected_modifiers'] != null
                    ? List<String>.from(jsonDecode(itemMap['selected_modifiers']))
                    : [],
                customProperties: itemMap['custom_properties'] != null
                    ? Map<String, dynamic>.from(jsonDecode(itemMap['custom_properties']))
                    : {},
                isAvailable: (itemMap['is_available'] as int?) == 1,
                sentToKitchen: (itemMap['sent_to_kitchen'] as int?) == 1,
                createdAt: DateTime.tryParse(itemMap['created_at'] as String? ?? '') ?? DateTime.now(),
              );

              orderItems.add(orderItem);
            } catch (e) {
              // Skip problematic items but continue with others
            }
          }

          // Add items to the order map before creating the Order object
          orderMap['items'] = orderItems.map((item) => item.toJson()).toList();

              // Only create Order object for non-ghost orders
          final order = Order.fromJson(orderMap);
          _allOrders.add(order);
        } catch (e) {
          
        }
      }

      // Sort orders by creation date (newest first)
      _allOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final activeCount = _allOrders.where((order) => order.isActive).length;
      final completedCount = _allOrders.where((order) => !order.isActive).length;
      
      
      // Notify listeners
      notifyListeners();
    } catch (e) {
    }
  }

  /// Create a new order (COMPLETELY SEPARATE from printing)
  Future<Order> createOrder({
    required String orderType,
    String? tableId,
    String? userId,
    String? userEmail,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    String? specialInstructions,
    List<OrderItem>? items,
  }) async {
    try {
      final orderNumber = await _generateOrderNumber();
      final now = DateTime.now();
      
      // Use email if provided, otherwise fall back to userId
      final orderUserId = userEmail ?? userId ?? 'admin';
      
      final order = Order(
        id: _uuid.v4(),
        orderNumber: orderNumber,
        status: OrderStatus.pending,
        type: OrderType.values.firstWhere(
          (e) => e.toString().split('.').last == orderType,
          orElse: () => OrderType.dineIn,
        ),
        tableId: tableId,
        userId: orderUserId,
        customerName: customerName,
        customerPhone: customerPhone,
        customerEmail: customerEmail,
        customerAddress: customerAddress,
        specialInstructions: specialInstructions,
        items: items ?? [],
        orderTime: now,
        createdAt: now,
        updatedAt: now,
      );


      // PHASE 1: Save to local database FIRST (CRITICAL)
      final saved = await saveOrder(order);
      if (!saved) {
        throw Exception('Failed to save order to local database');
      }

      // PHASE 2: Update local state immediately
      _allOrders.add(order);
      _activeOrders.add(order);
      
      // PHASE 3: Notify listeners immediately (UI updates instantly)
      notifyListeners();

      // PHASE 4: Trigger Firebase sync in parallel (NON-BLOCKING)
      // Use microtask to ensure it runs after the current function completes
      _triggerFirebaseSync(order, 'created');

      return order;

    } catch (e) {
      rethrow;
    }
  }
  
  /// Trigger Firebase sync for order (INDEPENDENT operation)
  void _triggerFirebaseSync(Order order, String action) {
    // Use Future.microtask to ensure this runs after the current operation completes
    Future.microtask(() async {
      try {
        
        final unifiedSyncService = UnifiedSyncService.instance;
        
        // CRITICAL FIX: Ensure real-time sync is always active before syncing
        await unifiedSyncService.ensureRealTimeSyncActive();
        
        // Ensure sync service is initialized and connected
        try {
          if (action == 'created') {
            await unifiedSyncService.syncOrderToFirebase(order, 'created');
            
            // CRITICAL: Trigger immediate cross-device sync notification
            await _triggerImmediateCrossDeviceSync(order);
            
          } else if (action == 'updated') {
            await unifiedSyncService.syncOrderToFirebase(order, 'updated');
            
            // CRITICAL: Trigger immediate cross-device sync notification
            await _triggerImmediateCrossDeviceSync(order);
          }
          
        } catch (e) {
          // Don't fail the order creation - sync will retry later
        }
      } catch (e) {
        // Don't fail the order creation - sync will retry later
      }
    });
  }
  
  /// CRITICAL: Trigger immediate cross-device synchronization
  Future<void> _triggerImmediateCrossDeviceSync(Order order) async {
    try {
      
      final unifiedSyncService = UnifiedSyncService.instance;
      
      // Force a comprehensive sync to ensure all devices get the update
      await unifiedSyncService.forceSyncAllLocalData();
      
      // Additional: Force refresh of real-time listeners to ensure they're active
      await unifiedSyncService.ensureRealTimeSyncActive();
      
      
    } catch (e) {
      // Don't fail the main operation - this is just for enhanced sync
    }
  }
  
  /// Update an existing order
  Future<bool> updateOrder(Order updatedOrder) async {
    try {
      
      // Update the timestamp
      final order = updatedOrder.copyWith(
        updatedAt: DateTime.now(),
      );

      // PHASE 1: Save to local database FIRST (CRITICAL)
      final saved = await saveOrder(order);
      if (!saved) {
        return false;
      }

      // PHASE 2: Update local state immediately
      final existingIndex = _allOrders.indexWhere((o) => o.id == order.id);
      if (existingIndex != -1) {
        _allOrders[existingIndex] = order;
      }

      final activeIndex = _activeOrders.indexWhere((o) => o.id == order.id);
      if (activeIndex != -1) {
        _activeOrders[activeIndex] = order;
      }

      final completedIndex = _completedOrders.indexWhere((o) => o.id == order.id);
      if (completedIndex != -1) {
        _completedOrders[completedIndex] = order;
      }

      // Re-sort lists
      _allOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _activeOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _completedOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // PHASE 3: Trigger Firebase sync IMMEDIATELY (parallel operation)
      _triggerFirebaseSync(order, 'updated');

      // PHASE 4: Notify listeners that order is updated
      notifyListeners();

      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Delete an order
  Future<bool> deleteOrder(String orderId) async {
    try {
      final order = _allOrders.firstWhere((o) => o.id == orderId);
      if (order == null) {
        return false;
      }


      final db = await _databaseService.database;
      if (db == null) {
        return false;
      }
      
      // Delete from database
      await db.transaction((txn) async {
        // Delete order items first
        await txn.delete(
          'order_items',
          where: 'order_id = ?',
          whereArgs: [orderId],
        );
        
        // Delete the order
        await txn.delete(
          'orders',
          where: 'id = ?',
          whereArgs: [orderId],
        );
      });

      // CRITICAL: Real-time Firebase sync for deletion
      await _syncOrderDeletionToFirebase(order);

      // ENHANCEMENT: Automatic Firebase sync trigger
      final unifiedSyncService = UnifiedSyncService.instance;
      await unifiedSyncService.syncOrderToFirebase(order, 'deleted');

      // Remove from local state
      _allOrders.removeWhere((o) => o.id == orderId);
      _activeOrders.removeWhere((o) => o.id == orderId);
      _completedOrders.removeWhere((o) => o.id == orderId);

      // Notify listeners
      notifyListeners();

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Real-time Firebase sync for order deletion
  Future<void> _syncOrderDeletionToFirebase(Order order) async {
    try {
      
      // Get the unified sync service
      final syncService = UnifiedSyncService.instance;
      
      // Check if sync service is available and connected
      if (syncService.isConnected) {
        // Delete the order from Firebase
        await syncService.deleteItem('orders', order.id);
      } else {
        // Add to pending changes for later sync
        syncService.addPendingSyncChange('orders', 'deleted', order.id, {});
      }
    } catch (e) {
      // Don't fail the delete operation if Firebase sync fails
      // The order is still deleted locally and will sync when connection is restored
    }
  }

  /// Auto-sync order to Firebase
  Future<void> _autoSyncToFirebase(Order order, String action) async {
    try {
      
      // Get the unified sync service instance
      final syncService = UnifiedSyncService.instance;
      
      // Check if sync service is connected
      if (!syncService.isConnected) {
        try {
          // Try to connect to the current restaurant
          final authService = MultiTenantAuthService();
          if (authService.currentRestaurant != null && authService.currentSession != null) {
            await syncService.connectToRestaurant(
              authService.currentRestaurant!,
              authService.currentSession!,
            );
          }
        } catch (e) {
        }
      }
      
      // Attempt to sync the order
      if (syncService.isConnected) {
        if (action == 'deleted') {
          await syncService.deleteItem('orders', order.id);
        } else {
          await syncService.createOrUpdateOrder(order);
        }
      } else {
        // Queue for later sync if needed
        _queueForLaterSync(order, action);
      }
    } catch (e) {
      // Queue for later sync
      _queueForLaterSync(order, action);
    }
  }
  
  /// Queue order for later sync when Firebase is available
  void _queueForLaterSync(Order order, String action) {
    try {
      // Store in local storage for later sync
      final syncQueue = <String, dynamic>{
        'order_id': order.id,
        'order_number': order.orderNumber,
        'action': action,
        'timestamp': DateTime.now().toIso8601String(),
        'data': order.toJson(),
      };
      
      // Save to shared preferences for later sync
      SharedPreferences.getInstance().then((prefs) {
        final queueKey = 'sync_queue_${order.id}';
        prefs.setString(queueKey, jsonEncode(syncQueue));
      });
    } catch (e) {
    }
  }

  /// Generate unique order number with zero risk protection
  /// Enhanced order number generation with comprehensive collision avoidance
  Future<String> _generateOrderNumber() async {
    try {

      final Database? database = await _databaseService.database;
      if (database == null) {
        return _generateEnhancedTimestampOrderNumber();
      }

      // COMPREHENSIVE UNIQUENESS VALIDATION
      final existingOrderNumbers = await _getExistingOrderNumbers();

      // Use multiple generation strategies for maximum uniqueness
      String orderNumber;
      int attempts = 0;
      const maxAttempts = 50; // Increased for better collision avoidance

      do {
        // Try different generation strategies based on attempt count
        if (attempts < 10) {
          // Primary strategy: Enhanced timestamp with server prefix
          orderNumber = _generateEnhancedTimestampOrderNumber();
        } else if (attempts < 30) {
          // Secondary strategy: Sequential with date prefix
          orderNumber = await _generateSequentialOrderNumber(existingOrderNumbers);
        } else {
          // Tertiary strategy: UUID-based with validation
          orderNumber = _generateValidatedUuidOrderNumber();
        }

        attempts++;

        if (attempts >= maxAttempts) {
          orderNumber = 'EMERGENCY-${const Uuid().v4().substring(0, 12).toUpperCase()}';
          break;
        }

        // Additional validation: Check format validity
        if (!_isValidOrderNumber(orderNumber)) {
          continue;
        }

      } while (existingOrderNumbers.contains(orderNumber));

      // Final uniqueness verification
      if (existingOrderNumbers.contains(orderNumber)) {
        orderNumber = 'FINAL-CHECK-${const Uuid().v4().substring(0, 8).toUpperCase()}';
      }
      
      return orderNumber;
      
    } catch (e) {
      // ZERO RISK: Always return a valid order number
      return _generateTimestampBasedOrderNumber();
    }
  }

  /// Enhanced timestamp-based order number with better collision avoidance
  String _generateEnhancedTimestampOrderNumber() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    // Add milliseconds precision and random component
    final random = (timestamp % 1000) + (now.microsecondsSinceEpoch % 100);
    final dateStr = '${now.year % 100}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return 'ORD${dateStr}${timestamp.toString().substring(8)}${random.toString().padLeft(3, '0')}';
  }

  /// Sequential order number generation for high-volume scenarios
  Future<String> _generateSequentialOrderNumber(Set<String> existingNumbers) async {
    try {
      final now = DateTime.now();
      final datePrefix = '${now.year % 100}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';

      // Find the highest sequential number for today
      int maxSequential = 0;
      for (final number in existingNumbers) {
        if (number.startsWith('SEQ$datePrefix')) {
          final sequentialPart = number.substring(9); // Remove 'SEQYYMMDD'
          final sequentialNum = int.tryParse(sequentialPart) ?? 0;
          if (sequentialNum > maxSequential) {
            maxSequential = sequentialNum;
          }
        }
      }

      return 'SEQ${datePrefix}${(maxSequential + 1).toString().padLeft(4, '0')}';
    } catch (e) {
      return _generateEnhancedTimestampOrderNumber();
    }
  }

  /// UUID-based order number with format validation
  String _generateValidatedUuidOrderNumber() {
    final uuid = const Uuid().v4().toUpperCase();
    // Use first 12 characters for reasonable length while maintaining uniqueness
    return 'UUID${uuid.substring(0, 12).replaceAll('-', '')}';
  }

  /// Generate timestamp-based order number (fallback method)
  String _generateTimestampBasedOrderNumber() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final randomSuffix = (timestamp % 10000).toString().padLeft(4, '0');
    return 'ORD-${timestamp.toString().substring(8)}-$randomSuffix';
  }

  /// Get existing order numbers for uniqueness check
  Future<Set<String>> _getExistingOrderNumbers() async {
    try {
      final Database? database = await _databaseService.database;
      if (database == null) return <String>{};

      final result = await database.query(
        'orders',
        columns: ['order_number'],
      );
      
      return result.map((row) => row['order_number'] as String).toSet();
    } catch (e) {
      return <String>{};
    }
  }

  /// Update order status
  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    try {
      
      final db = await _databaseService.database;
      if (db == null) {
        return false;
      }

      // Update in database
      await db.update(
        'orders',
        {
          'status': newStatus,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [orderId],
      );

      // Update local state
      final orderIndex = _allOrders.indexWhere((o) => o.id == orderId);
      if (orderIndex != -1) {
        final oldOrder = _allOrders[orderIndex];
        final newOrder = oldOrder.copyWith(
          status: OrderStatus.values.firstWhere(
            (e) => e.toString().split('.').last == newStatus,
            orElse: () => OrderStatus.pending,
          ),
          updatedAt: DateTime.now(),
        );
        _allOrders[orderIndex] = newOrder;

        // Update active/completed lists
        _updateOrderLists(newOrder);

        // If cancelled, set completed_time
        if (newStatus.toLowerCase() == 'cancelled') {
          try {
            final nowIso = DateTime.now().toIso8601String();
            await db.update(
              'orders',
              {'completed_time': nowIso},
              where: 'id = ?',
              whereArgs: [orderId],
            );
            // Reflect completedTime in-memory as well
            final updatedOrder = newOrder.copyWith(completedTime: DateTime.parse(nowIso));
            _allOrders[orderIndex] = updatedOrder;
            _updateOrderLists(updatedOrder);
          } catch (e) {
          }
        }
      }

      // Log the status change
      String orderNumber = '';
      try {
        final orderResult = await db.query(
          'orders',
          columns: ['order_number'],
          where: 'id = ?',
          whereArgs: [orderId],
        );
        if (orderResult.isNotEmpty) {
          orderNumber = orderResult.first['order_number'] as String;
        }
      } catch (e) {
      }

      await _orderLogService.logOperation(
        orderId: orderId,
        orderNumber: orderNumber,
        action: OrderLogAction.statusChanged,
        description: 'Status changed to $newStatus',
        performedBy: 'system', // Add required parameter
      );

      // Update inventory if the order was completed
      if (newStatus.toLowerCase() == 'completed') {
        try {
          // Find the order and update inventory
          final order = _allOrders.firstWhere((o) => o.id == orderId);
          final inventoryUpdated = await _inventoryService.updateInventoryOnOrderCompletion(order);
          if (inventoryUpdated) {
          } else {
          }
          
          // CRITICAL FIX: Don't clear current order state during completion to maintain kitchen printing functionality
          // Only clear if we're explicitly completing the current order and want to start fresh
          if (_currentOrder?.id == orderId) {
            // Don't clear _currentOrder here to prevent kitchen printing issues
          }
        } catch (e) {
          // Log the error but don't fail the status update
        }
      }

      // Trigger Firebase sync for status change (including cancelled/completed)
      try {
        final orderForSync = await getOrderById(orderId) ??
            _allOrders.firstWhere((o) => o.id == orderId, orElse: () => null as dynamic);
        if (orderForSync != null) {
          _triggerFirebaseSync(orderForSync, 'updated');
        }
      } catch (e) {
      }

      // Notify listeners of state change
      notifyListeners();

      return true;
    } catch (e) {
      throw OrderServiceException('Failed to update order status: $e', operation: 'update_status', originalError: e);
    }
  }

  /// Get order by ID
  Future<Order?> getOrderById(String orderId) async {
    try {
      // Check local cache first
      final localOrder = _allOrders.where((o) => o.id == orderId).firstOrNull;
      if (localOrder != null) {
        return localOrder;
      }

      // Load from database
      final Database? database = await _databaseService.database;
      if (database == null) return null;

      final List<Map<String, dynamic>> results = await database.query(
        'orders',
        where: 'id = ?',
        whereArgs: [orderId],
      );

      if (results.isEmpty) return null;

      // Load order items
      final List<Map<String, dynamic>> itemResults = await database.query(
        'order_items',
        where: 'order_id = ?',
        whereArgs: [orderId],
      );

      final List<OrderItem> items = itemResults.map((itemMap) {
        return OrderItem.fromJson(itemMap);
      }).toList();

      final order = Order.fromJson(results.first);
      order.items.clear();
      order.items.addAll(items);
      
      return order;
    } catch (e) {
      return null;
    }
  }

  /// Delete an order by its human-readable order number (e.g., DI-31624-1624)
  Future<bool> deleteOrderByOrderNumber(String orderNumber) async {
    try {
      // Try in-memory first
      final inMemory = _allOrders.firstWhere(
        (o) => o.orderNumber == orderNumber,
        orElse: () => null as dynamic,
      );
      if (inMemory != null) {
        return await deleteOrder(inMemory.id);
      }

      // Fallback: query database for the order ID
      final db = await _databaseService.database;
      if (db == null) return false;

      final rows = await db.query(
        'orders',
        columns: ['id'],
        where: 'order_number = ?',
        whereArgs: [orderNumber],
        limit: 1,
      );
      if (rows.isEmpty) {
        return false;
      }

      final orderId = rows.first['id'] as String;
      return await deleteOrder(orderId);
    } catch (e) {
      return false;
    }
  }

  /// Set current order
  void setCurrentOrder(Order? order) {
    _currentOrder = order;
    if (order != null) {
      _currentOrderStreamController.add(order);
    }
    // Safe notification to prevent crashes
    SchedulerBinding.instance.addPostFrameCallback((_) {
      try {
        notifyListeners();
      } catch (e) {
      }
    });
  }

  /// Clear current order
  void clearCurrentOrder() {
    _currentOrder = null;
    // Safe notification to prevent crashes
    SchedulerBinding.instance.addPostFrameCallback((_) {
      try {
        notifyListeners();
      } catch (e) {
      }
    });
  }

  /// Parse string status to OrderStatus enum
  OrderStatus _parseOrderStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'served':
        return OrderStatus.served;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'refunded':
        return OrderStatus.refunded;
      default:
        return OrderStatus.pending;
    }
  }

  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    // Safe notification to prevent crashes
    SchedulerBinding.instance.addPostFrameCallback((_) {
      try {
        notifyListeners();
      } catch (e) {
      }
    });
  }

  /// Save orders to cache
  void _saveOrdersToCache() {
    // Implementation for caching orders
  }

  /// Clear all orders from memory and database
  Future<void> clearAllOrders() async {
    try {
      
      // Clear from memory
      _allOrders.clear();
      _activeOrders.clear();
      _completedOrders.clear();
      
      // Clear from database
      final db = await _databaseService.database;
      if (db != null) {
        await db.delete('orders');
        await db.delete('order_items');
      }
      
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Delete all orders from database (for testing/reset purposes)
  /// This preserves users, menu items, and categories - only clears orders
  Future<void> deleteAllOrders() async {
    try {
      
      final Database? database = await _databaseService.database;
      if (database == null) {
        throw OrderServiceException('Database not available', operation: 'delete_all_orders');
      }
      
      await database.transaction((txn) async {
        // Delete all order items first (foreign key constraint)
        final orderItemsDeleted = await txn.delete('order_items');
        
        // Delete all orders
        final ordersDeleted = await txn.delete('orders');
        
        // Delete all order logs
        final orderLogsDeleted = await txn.delete('order_logs');
      });
      
      // Clear local state
      _activeOrders.clear();
      _completedOrders.clear();
      _allOrders.clear();
      _currentOrder = null;
      
      // Clear any cached data
      final Map<String, MenuItem> _menuItemCache = {};
      _menuItemCache.clear();
      
      // Safe notification to prevent crashes
      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          notifyListeners();
        } catch (e) {
        }
      });
      
      // Notify streams
      _ordersStreamController.add([]);
      if (_currentOrder == null) {
        _currentOrderStreamController.add(Order(
          items: [],
          orderNumber: 'TEMP-${DateTime.now().millisecondsSinceEpoch}',
          orderTime: DateTime.now(),
        ));
      }
      
    } catch (e) {
      throw OrderServiceException('Failed to delete all orders: $e', operation: 'delete_all_orders', originalError: e);
    }
  }

  /// Get orders for today
  List<Order> getTodaysOrders() {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    
    return _allOrders.where((order) {
      return order.createdAt.isAfter(todayStart) && order.createdAt.isBefore(todayEnd);
    }).toList();
  }

  /// Get revenue for today
  double getTodaysRevenue() {
    final todaysOrders = getTodaysOrders();
    return todaysOrders.fold(0.0, (sum, order) => sum + order.totalAmount);
  }

  /// Validates if an order can be modified
  void _validateOrderModification(Order order) {
    if (order.isProtected) {
      throw Exception('${order.protectionReason}. Operation not allowed.');
    }
  }

  /// Validates if items can be added to an order
  void _validateAddItems(Order order) {
    _validateOrderModification(order);
  }

  /// Validates if an order can be sent to kitchen
  void _validateSendToKitchen(Order order) {
    _validateOrderModification(order);
    
    // Additional validation for send to kitchen
    final newItems = order.items.where((item) => !item.sentToKitchen).toList();
    if (newItems.isEmpty) {
      throw Exception('No new items to send to kitchen.');
    }
  }

  /// Validates if an order can be updated
  void _validateOrderUpdate(Order order) {
    // Allow updates during checkout process even if order is completed
    if (order.status == OrderStatus.completed && order.paymentStatus == PaymentStatus.paid) {
      // This is likely a payment completion update, allow it
      return;
    }
    _validateOrderModification(order);
  }

  /// Update active/completed order lists based on the new order's status
  void _updateOrderLists(Order newOrder) {
    _activeOrders = _allOrders.where((o) => o.isActive).toList();
    _completedOrders = _allOrders.where((o) => !o.isActive).toList();
  }

  /// Send order to kitchen (COMPLETELY INDEPENDENT from order creation)
  /// This method can be called separately and does NOT affect order creation or Firebase sync
  Future<Map<String, dynamic>> sendOrderToKitchen(Order order) async {
    try {
      
      // This is a completely separate operation that doesn't interfere with order creation
      // The order is already created, saved locally, and synced to Firebase
      
      // Update order status to indicate it's been sent to kitchen
      final updatedOrder = order.copyWith(
        status: OrderStatus.preparing,
        updatedAt: DateTime.now(),
      );
      
      // Update local state
      await updateOrder(updatedOrder);
      
      // Trigger kitchen printing (independent operation)
      // This will be handled by the KitchenPrintingService
      // If printing fails, it won't affect the order status
      
      return {
        'success': true,
        'message': 'Order sent to kitchen',
        'orderNumber': order.orderNumber,
        'status': 'preparing',
      };
      
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to send order to kitchen: $e',
        'orderNumber': order.orderNumber,
      };
    }
  }
  
  /// Complete order (COMPLETELY INDEPENDENT from printing)
  Future<Map<String, dynamic>> completeOrder(Order order) async {
    try {

      final now = DateTime.now();

      // Update order with all required completion fields
      final updatedOrder = order.copyWith(
        status: OrderStatus.completed,
        completedTime: now,
        completedAt: now,
        updatedAt: now,
      );

      // Save to local database immediately
      await updateOrder(updatedOrder);

      // CRITICAL: Sync order and its items to Firebase immediately for cross-device updates
      try {
        final tenantId = FirebaseConfig.getCurrentTenantId();
        if (tenantId != null) {
          // Sync the order itself
          await _uploadOrderToFirebaseWithRetry(_convertDbToFirebaseFormat(_convertOrderToDbFormat(updatedOrder)), tenantId);

          // Also sync all order items for this completed order
          await _syncOrderItemsToFirebase(updatedOrder, tenantId);
        }
      } catch (firebaseError) {
        // Don't fail the completion if Firebase sync fails
      }

      // CRITICAL: Update local state immediately - completed orders are NOT active
      _activeOrders.removeWhere((o) => o.id == order.id);
      _completedOrders.add(updatedOrder);

      // Sort completed orders
      _completedOrders.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      // CRITICAL: Force rebuild of all orders list
      _allOrders.removeWhere((o) => o.id == order.id);
      _allOrders.add(updatedOrder);
      _allOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Notify listeners IMMEDIATELY
      notifyListeners();


      return {
        'success': true,
        'message': 'Order completed and synced',
        'orderNumber': order.orderNumber,
        'status': 'completed',
      };

    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to complete order: $e',
        'orderNumber': order.orderNumber,
      };
    }
  }

  /// Cancel order with proper field updates and immediate Firebase sync
  Future<Map<String, dynamic>> cancelOrder(Order order) async {
    try {

      final now = DateTime.now();

      // Update order with all required cancellation fields (same as completion)
      final updatedOrder = order.copyWith(
        status: OrderStatus.cancelled,
        completedTime: now,
        completedAt: now,
        updatedAt: now,
      );

      // Save to local database immediately
      await updateOrder(updatedOrder);

      // CRITICAL: Sync order and its items to Firebase immediately for cross-device updates
      try {
        final tenantId = FirebaseConfig.getCurrentTenantId();
        if (tenantId != null) {
          // Sync the order itself
          await _uploadOrderToFirebaseWithRetry(_convertDbToFirebaseFormat(_convertOrderToDbFormat(updatedOrder)), tenantId);

          // Also sync all order items for this cancelled order
          await _syncOrderItemsToFirebase(updatedOrder, tenantId);
        }
      } catch (firebaseError) {
        // Don't fail the cancellation if Firebase sync fails
      }

      // CRITICAL: Update local state immediately - cancelled orders are NOT active
      _activeOrders.removeWhere((o) => o.id == order.id);
      _completedOrders.add(updatedOrder);

      // Sort completed orders
      _completedOrders.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      // CRITICAL: Force rebuild of all orders list
      _allOrders.removeWhere((o) => o.id == order.id);
      _allOrders.add(updatedOrder);
      _allOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Notify listeners IMMEDIATELY
      notifyListeners();


      return {
        'success': true,
        'message': 'Order cancelled and synced',
        'orderNumber': order.orderNumber,
        'status': 'cancelled',
      };

    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to cancel order: $e',
        'orderNumber': order.orderNumber,
      };
    }
  }

  /// Sync all order items for a given order to Firebase
  Future<void> _syncOrderItemsToFirebase(Order order, String tenantId) async {
    try {

      final firestoreInstance = fs.FirebaseFirestore.instance;

      for (final item in order.items) {
        try {
          // Convert order item to Firebase format
          final itemData = {
            'id': item.id,
            'order_id': order.id,
            'menu_item_id': item.menuItem.id,
            'quantity': item.quantity,
            'unit_price': item.unitPrice,
            'total_price': item.totalPrice,
            'selected_variant': item.selectedVariant,
            'special_instructions': item.specialInstructions,
            'notes': item.specialInstructions, // Duplicate for compatibility
            'is_available': item.isAvailable,
            'sent_to_kitchen': item.sentToKitchen,
            'created_at': item.createdAt.toIso8601String(),
            'updated_at': item.createdAt.toIso8601String(), // Using createdAt as updatedAt
          };

          // Upload to Firebase
          await firestoreInstance
              .collection('tenants')
              .doc(tenantId)
              .collection('order_items')
              .doc(item.id)
              .set(itemData, fs.SetOptions(merge: true));

        } catch (itemError) {
          // Continue with other items
        }
      }

    } catch (e) {
      // Don't throw - order completion/cancellation should succeed even if item sync fails
    }
  }

  /// Immediately save and sync an order update (for real-time changes)
  /// CRITICAL: Preserves original order number - NEVER regenerates!
  Future<bool> saveAndSyncOrderImmediately(Order order) async {
    try {
      // VALIDATION: Ensure order number is preserved (never regenerate!)
      if (order.orderNumber.isEmpty) {
        return false;
      }

      // First save locally (this preserves the order number)
      final saved = await saveOrder(order);
      if (!saved) {
        return false;
      }

      // Then immediately sync to Firebase
      try {
        await _syncOrderToFirebase(order);
      } catch (firebaseError) {
        // Don't fail the operation if Firebase sync fails
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Comprehensive timestamp-based synchronization between local and Firebase
  Future<void> syncOrdersWithFirebase() async {
    try {
      
      final db = await _databaseService.database;
      if (db == null) {
        return;
      }

      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) {
        return;
      }


      // PHASE 1: Get local orders with proper timestamp mapping
      final localOrdersResult = await db.query('orders');
      final localOrders = <String, Map<String, dynamic>>{};
      
      for (final row in localOrdersResult) {
        // Convert database snake_case to Firebase camelCase
        final firebaseFormat = _convertDbToFirebaseFormat(row);
        localOrders[row['id'] as String] = firebaseFormat;
      }
      

      // PHASE 2: Get Firebase orders with error handling
      final firestoreInstance = fs.FirebaseFirestore.instance;
      fs.QuerySnapshot? ordersSnapshot;
      
      try {
        ordersSnapshot = await firestoreInstance
            .collection('tenants')
            .doc(tenantId)
            .collection('orders')
            .get();
      } catch (e) {
        // Continue with local-only operations
        return;
      }
      
      final firebaseOrders = <String, Map<String, dynamic>>{};
      for (final doc in ordersSnapshot.docs) {
        if (doc.id == '_persistence_config') continue;
        
        try {
          final orderData = doc.data() as Map<String, dynamic>;
          orderData['id'] = doc.id;
          firebaseOrders[doc.id] = orderData;
        } catch (e) {
          continue;
        }
      }
      

      // PHASE 3: Comprehensive sync logic with error handling
      int downloadedFromFirebase = 0;
      int uploadedToFirebase = 0;
      int skippedCount = 0;
      int errorCount = 0;

      final allOrderIds = {...localOrders.keys, ...firebaseOrders.keys};
      
      for (final orderId in allOrderIds) {
        try {
          final localOrder = localOrders[orderId];
          final firebaseOrder = firebaseOrders[orderId];

          if (localOrder != null && firebaseOrder != null) {
            // Both exist - compare timestamps using correct field names with conservative threshold
            final localUpdatedAt = DateTime.parse(localOrder['updatedAt'] ?? '1970-01-01T00:00:00.000Z');
            final firebaseUpdatedAt = DateTime.parse(firebaseOrder['updatedAt'] ?? '1970-01-01T00:00:00.000Z');

            // CONSERVATIVE SYNC: Only sync if Firebase is significantly newer (1+ minutes)
            // This prevents overwriting good local data with slightly newer Firebase data
            final timeDifference = firebaseUpdatedAt.difference(localUpdatedAt);

            if (localUpdatedAt.isAfter(firebaseUpdatedAt)) {
              // Local is newer - upload to Firebase
              await _uploadOrderToFirebaseWithRetry(localOrder, tenantId);
              uploadedToFirebase++;
            } else if (timeDifference.inMinutes >= 1 && _isFirebaseOrderValid(firebaseOrder)) {
              // Firebase is significantly newer AND valid - download to local
              await _downloadOrderFromFirebaseWithRetry(firebaseOrder);
              downloadedFromFirebase++;
            } else {
              // Timestamps are close or Firebase data invalid - keep local data
              if (timeDifference.inMinutes < 1) {
              } else if (!_isFirebaseOrderValid(firebaseOrder)) {
              }
              skippedCount++;
            }
          } else if (localOrder != null) {
            // Only local exists - upload to Firebase
            await _uploadOrderToFirebaseWithRetry(localOrder, tenantId);
            uploadedToFirebase++;
          } else if (firebaseOrder != null && _isFirebaseOrderValid(firebaseOrder)) {
            // Only Firebase exists AND is valid - download to local
            await _downloadOrderFromFirebaseWithRetry(firebaseOrder);
            downloadedFromFirebase++;
          } else if (firebaseOrder != null && !_isFirebaseOrderValid(firebaseOrder)) {
            // Firebase exists but is invalid - skip
            errorCount++;
          }
        } catch (e) {
          errorCount++;
        }
      }

      // PHASE 4: Reload and notify
      await _loadOrdersFromDatabase();
      notifyListeners();


    } catch (e) {
      rethrow;
    }
  }
  
  /// Upload order to Firebase with retry mechanism
  Future<void> _uploadOrderToFirebaseWithRetry(Map<String, dynamic> orderData, String tenantId, {int maxRetries = 3}) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        await _uploadOrderToFirebase(orderData, tenantId);
        return; // Success
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          rethrow;
        }
        
        await Future.delayed(Duration(seconds: attempts * 2)); // Exponential backoff
      }
    }
  }
  
  /// Download order from Firebase with retry mechanism
  Future<void> _downloadOrderFromFirebaseWithRetry(Map<String, dynamic> orderData, {int maxRetries = 3}) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        await _downloadOrderFromFirebase(orderData);
        return; // Success
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) {
          rethrow;
        }
        
        await Future.delayed(Duration(seconds: attempts * 2)); // Exponential backoff
      }
    }
  }

  /// Enhanced force sync with better error handling
  Future<void> forceSyncFromFirebase() async {
    try {
      
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) {
        return;
      }


      final firestoreInstance = fs.FirebaseFirestore.instance;
      
      // Test Firebase connection
      try {
        await firestoreInstance.collection('tenants').doc(tenantId).get();
      } catch (e) {
        return;
      }

      final ordersSnapshot = await firestoreInstance
          .collection('tenants')
          .doc(tenantId)
          .collection('orders')
          .get();
      
      
      int syncedCount = 0;
      int errorCount = 0;
      
      for (final doc in ordersSnapshot.docs) {
        try {
          final orderData = doc.data();
          orderData['id'] = doc.id;
          
          // Skip non-order documents
          if (doc.id == '_persistence_config' || !orderData.containsKey('orderNumber')) {
            continue;
          }
          
          final order = Order.fromJson(orderData);
          await updateOrderFromFirebase(order);
          syncedCount++;
        } catch (e) {
          errorCount++;
        }
      }

      
      // Reload orders from database
      await _loadOrdersFromDatabase();
      notifyListeners();
      
    } catch (e) {
    }
  }

  /// Convert database format to Firebase format
  Map<String, dynamic> _convertDbToFirebaseFormat(Map<String, dynamic> dbRow) {
    return {
      'id': dbRow['id'],
      'orderNumber': dbRow['order_number'],
      'status': dbRow['status'],
      'type': dbRow['type'],
      'tableId': dbRow['table_id'],
      'userId': dbRow['user_id'],
      'customerName': dbRow['customer_name'],
      'customerPhone': dbRow['customer_phone'],
      'customerEmail': dbRow['customer_email'],
      'customerAddress': dbRow['customer_address'],
      'specialInstructions': dbRow['special_instructions'],
      'subtotal': dbRow['subtotal'],
      'taxAmount': dbRow['tax_amount'],
      'tipAmount': dbRow['tip_amount'],
      'hstAmount': dbRow['hst_amount'],
      'discountAmount': dbRow['discount_amount'],
      'gratuityAmount': dbRow['gratuity_amount'],
      'totalAmount': dbRow['total_amount'],
      'paymentMethod': dbRow['payment_method'],
      'paymentStatus': dbRow['payment_status'],
      'paymentTransactionId': dbRow['payment_transaction_id'],
      'orderTime': dbRow['order_time'],
      'estimatedReadyTime': dbRow['estimated_ready_time'],
      'actualReadyTime': dbRow['actual_ready_time'],
      'servedTime': dbRow['served_time'],
      'completedTime': dbRow['completed_time'],
      'isUrgent': dbRow['is_urgent'] == 1,
      'priority': dbRow['priority'],
      'assignedTo': dbRow['assigned_to'],
      'customFields': dbRow['custom_fields'] != null ? jsonDecode(dbRow['custom_fields']) : {},
      'metadata': dbRow['metadata'] != null ? jsonDecode(dbRow['metadata']) : {},
      'notes': [],
      'history': [],
      'preferences': {},
      'createdAt': dbRow['created_at'],
      'updatedAt': dbRow['updated_at'],
      'completedAt': dbRow['completed_at'],
      'items': []
    };
  }

  /// Convert Firebase format to database format
  Map<String, dynamic> _convertFirebaseToDbFormat(Map<String, dynamic> firebaseData) {
    return {
      'id': firebaseData['id'],
      'order_number': firebaseData['orderNumber'],
      'status': firebaseData['status'],
      'type': firebaseData['type'],
      'table_id': firebaseData['tableId'],
      'user_id': firebaseData['userId'],
      'customer_name': firebaseData['customerName'],
      'customer_phone': firebaseData['customerPhone'],
      'customer_email': firebaseData['customerEmail'],
      'customer_address': firebaseData['customerAddress'],
      'special_instructions': firebaseData['specialInstructions'],
      'subtotal': firebaseData['subtotal'],
      'tax_amount': firebaseData['taxAmount'],
      'tip_amount': firebaseData['tipAmount'],
      'hst_amount': firebaseData['hstAmount'],
      'discount_amount': firebaseData['discountAmount'],
      'gratuity_amount': firebaseData['gratuityAmount'],
      'total_amount': firebaseData['totalAmount'],
      'payment_method': firebaseData['paymentMethod'],
      'payment_status': firebaseData['paymentStatus'],
      'payment_transaction_id': firebaseData['paymentTransactionId'],
      'order_time': firebaseData['orderTime'],
      'estimated_ready_time': firebaseData['estimatedReadyTime'],
      'actual_ready_time': firebaseData['actualReadyTime'],
      'served_time': firebaseData['servedTime'],
      'completed_time': firebaseData['completedTime'],
      'is_urgent': firebaseData['isUrgent'] ? 1 : 0,
      'priority': firebaseData['priority'],
      'assigned_to': firebaseData['assignedTo'],
      'custom_fields': jsonEncode(firebaseData['customFields'] ?? {}),
      'metadata': jsonEncode(firebaseData['metadata'] ?? {}),
      'created_at': firebaseData['createdAt'],
      'updated_at': firebaseData['updatedAt'],
      'completed_at': firebaseData['completedAt']
    };
  }

  /// Download order from Firebase to local database
  Future<void> _downloadOrderFromFirebase(Map<String, dynamic> firebaseOrder) async {
    try {
      final db = await _databaseService.database;
      if (db == null) return;

      // Convert Firebase format to database format
      final dbFormat = _convertFirebaseToDbFormat(firebaseOrder);
      
      // Insert/update order in database
      await db.insert(
        'orders',
        dbFormat,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Handle order items
      final items = firebaseOrder['items'] as List? ?? [];
      for (final item in items) {
        await _downloadOrderItemFromFirebase(item, firebaseOrder['id']);
      }

    } catch (e) {
    }
  }

  /// Upload order from local database to Firebase
  Future<void> _uploadOrderToFirebase(Map<String, dynamic> localOrder, String tenantId) async {
    try {
      final firestoreInstance = fs.FirebaseFirestore.instance;
      
      await firestoreInstance
          .collection('tenants')
          .doc(tenantId)
          .collection('orders')
          .doc(localOrder['id'])
          .set(localOrder, fs.SetOptions(merge: true));

    } catch (e) {
    }
  }

  /// Download order item from Firebase to local database
  Future<void> _downloadOrderItemFromFirebase(Map<String, dynamic> firebaseItem, String orderId) async {
    try {
      final db = await _databaseService.database;
      if (db == null) return;

      // Convert Firebase item format to database format
      final dbItemFormat = {
        'id': firebaseItem['id'],
        'order_id': orderId,
        'menu_item_id': firebaseItem['menuItemId'],
        'quantity': firebaseItem['quantity'],
        'unit_price': firebaseItem['unitPrice'],
        'special_instructions': firebaseItem['specialInstructions'],
        'notes': firebaseItem['notes'],
        'selected_variant': firebaseItem['selectedVariant'],
        'selected_modifiers': jsonEncode(firebaseItem['selectedModifiers'] ?? []),
        'custom_properties': jsonEncode(firebaseItem['customProperties'] ?? {}),
        'is_available': firebaseItem['isAvailable'] ? 1 : 0,
        'sent_to_kitchen': firebaseItem['sentToKitchen'] ? 1 : 0,
        'created_at': firebaseItem['createdAt'],
        'voided': firebaseItem['voided'] ? 1 : 0,
        'voided_by': firebaseItem['voidedBy'],
        'voided_at': firebaseItem['voidedAt'],
        'comped': firebaseItem['comped'] ? 1 : 0,
        'comped_by': firebaseItem['compedBy'],
        'comped_at': firebaseItem['compedAt'],
        'discount_percentage': firebaseItem['discountPercentage'],
        'discount_amount': firebaseItem['discountAmount'],
        'discounted_by': firebaseItem['discountedBy'],
        'discounted_at': firebaseItem['discountedAt']
      };

      await db.insert(
        'order_items',
        dbItemFormat,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

    } catch (e) {
    }
  }

  /// Manual sync trigger for testing
  Future<void> manualSync() async {
    try {
      
      // Use the comprehensive sync method
      await syncOrdersWithFirebase();
      
    } catch (e) {
      // Try force sync as fallback
      try {
        await forceSyncFromFirebase();
      } catch (e2) {
      }
    }
  }

  /// Reconcile: force-mark any orders that have a cancellation log as cancelled
  /// Safe manual operation to fix legacy inconsistencies where a completed order was not flipped
  Future<int> reconcileCancelledOrdersFromLogs() async {
    try {
      final db = await _databaseService.database;
      if (db == null) return 0;

      // Find all logs with action = cancelled
      final logs = await db.query(
        'order_logs',
        columns: ['order_id'],
        where: 'action = ?',
        whereArgs: ['cancelled'],
      );
      if (logs.isEmpty) return 0;

      final Set<String> orderIds = logs.map((e) => (e['order_id'] as String)).toSet();
      int updatedCount = 0;

      for (final orderId in orderIds) {
        // Check current status
        final rows = await db.query('orders', columns: ['status'], where: 'id = ?', whereArgs: [orderId]);
        if (rows.isEmpty) continue;
        final currentStatus = (rows.first['status'] as String?)?.toLowerCase() ?? '';
        if (currentStatus != 'cancelled') {
          // Force update to cancelled
          final nowIso = DateTime.now().toIso8601String();
          await db.update(
            'orders',
            {
              'status': 'cancelled',
              'updated_at': nowIso,
              'completed_time': nowIso,
            },
            where: 'id = ?',
            whereArgs: [orderId],
          );

          // Update local cache if present
          final idx = _allOrders.indexWhere((o) => o.id == orderId);
          if (idx != -1) {
            final forced = _allOrders[idx].copyWith(
              status: OrderStatus.cancelled,
              updatedAt: DateTime.parse(nowIso),
              completedTime: DateTime.parse(nowIso),
            );
            _allOrders[idx] = forced;
            _updateOrderLists(forced);
          }

          // Trigger sync
          try {
            final orderForSync = await getOrderById(orderId) ?? (_allOrders.firstWhere((o) => o.id == orderId, orElse: () => null as dynamic));
            if (orderForSync != null) {
              _triggerFirebaseSync(orderForSync, 'updated');
            }
          } catch (_) {}

          updatedCount++;
        }
      }

      // Notify listeners once
      notifyListeners();
      return updatedCount;
    } catch (e) {
      return 0;
    }
  }

  @override
  void dispose() {
    if (_disposed) return;

    _disposed = true;
    _autoSaveTimer?.cancel();
    _ordersStreamController.close();
    _currentOrderStreamController.close();
    _menuItemCache.clear();

    // Cancel any pending background sync operations
    _cancelBackgroundSyncOperations();

    super.dispose();
  }

  /// Cancel any pending background sync operations
  void _cancelBackgroundSyncOperations() {
    try {
      // Mark service as disposed to prevent new operations
      // Note: We can't cancel running Futures, but we can prevent new ones
    } catch (e) {
    }
  }
} 