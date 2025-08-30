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
import 'unified_sync_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs; // Added for Firebase sync
import 'package:ai_pos_system/config/firebase_config.dart'; // Added for FirebaseConfig


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
    debugPrint('🔧 OrderService initialized');
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
    debugPrint('🔄 OrderService disposal state reset');
  }

  // Getters
  List<Order> get activeOrders {
    debugPrint('📋 activeOrders getter called - returning ${_activeOrders.length} orders');
    debugPrint('📋 Active orders: ${_activeOrders.map((o) => '${o.orderNumber}(${o.status})').join(', ')}');
    return List.unmodifiable(_activeOrders);
  }
  List<Order> get completedOrders {
    debugPrint('📋 completedOrders getter called - returning ${_completedOrders.length} orders');
    return List.unmodifiable(_completedOrders);
  }
  List<Order> get allOrders {
    debugPrint('📋 allOrders getter called - returning ${_allOrders.length} orders');
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
      debugPrint('⚠️ getAllOrdersByServer fallback due to error: $e');
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
      debugPrint('⚠️ getActiveOrdersByServer fallback due to error: $e');
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
      debugPrint('⚠️ getActiveOrdersCountByServer fallback due to error: $e');
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
      debugPrint('⚠️ _matchesServer error: $e');
      return false;
    }
  }

  /// Validate order integrity before saving
  Future<bool> _validateOrderIntegrity(Order order) async {
    try {
      // Check if order has valid items
      if (order.items.isEmpty) {
        debugPrint('❌ Order has no items');
        return false;
      }

      // Validate menu item references
      for (var item in order.items) {
        if (item.menuItem.id.isEmpty) {
          debugPrint('❌ Order item has empty menu item ID');
          return false;
        }
        
        // Check if menu item exists
        final menuItem = await _getMenuItemById(item.menuItem.id);
        if (menuItem == null) {
          debugPrint('❌ Menu item ${item.menuItem.id} not found');
          return false;
        }
      }

      // Validate order total
      if (order.totalAmount <= 0) {
        debugPrint('❌ Order total amount is invalid: ${order.totalAmount}');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error validating order integrity: $e');
      return false;
    }
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
      debugPrint('❌ Error getting menu item: $e');
      return null;
    }
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
      debugPrint('❌ Error encoding JSON for SQLite: $e');
      return null;
    }
  }

  /// Save order to database with comprehensive error handling
  Future<bool> saveOrder(Order order) async {
    try {
      debugPrint('💾 Saving order to database: ${order.orderNumber}');
      
      // Validate order before saving
      if (order.orderNumber.isEmpty) {
        debugPrint('❌ Order validation failed: empty order number');
        return false;
      }
      
      final db = await _databaseService.database;
      if (db == null) {
        debugPrint('❌ Database not available');
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
          debugPrint('✅ Order saved to database: ${order.orderNumber}');

          // 2. Delete existing order items for this order
          await txn.delete(
            'order_items',
            where: 'order_id = ?',
            whereArgs: [order.id],
          );
          debugPrint('🗑️ Cleared existing order items for: ${order.orderNumber}');

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
              final unifiedSyncService = UnifiedSyncService();
              await unifiedSyncService.syncOrderItemToFirebase(itemMap);
              debugPrint('✅ Order item synced to Firebase: ${itemMap['id']}');
            } catch (e) {
              debugPrint('⚠️ Failed to sync order item: $e');
              // Don't fail the transaction if sync fails
            }
          }
          debugPrint('✅ Saved ${order.items.length} order items for: ${order.orderNumber}');

          return true;
        } catch (e) {
          debugPrint('❌ Transaction failed: $e');
          rethrow;
        }
      });

      if (success) {
        // CRITICAL: Update local state immediately after successful save
        _updateLocalOrderState(order);
        
        // CRITICAL FIX: Don't clear current order state during completion to maintain kitchen printing functionality
        if (order.status == OrderStatus.completed && _currentOrder?.id == order.id) {
          debugPrint('⚠️ Current order is being completed - maintaining state for kitchen printing');
          // Don't clear _currentOrder here to prevent kitchen printing issues
        }
        
        // CRITICAL: Real-time Firebase sync
        await _syncOrderToFirebase(order);
        
        debugPrint('✅ Order saved successfully: ${order.orderNumber}');
        return true;
      } else {
        debugPrint('❌ Failed to save order: ${order.orderNumber}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Failed to save order: $e');
      return false;
    }
  }

  /// Real-time Firebase sync for orders
  Future<void> _syncOrderToFirebase(Order order) async {
    try {
      debugPrint('🔄 Syncing order to Firebase: ${order.orderNumber}');
      
      // Get the unified sync service
      final syncService = UnifiedSyncService();
      
      // Check if sync service is available and connected
      if (syncService.isConnected) {
        // Sync the order to Firebase
        await syncService.createOrUpdateOrder(order);
        debugPrint('✅ Order synced to Firebase: ${order.orderNumber}');
      } else {
        debugPrint('⚠️ Firebase sync service not connected - order will sync when connection is restored');
        // Add to pending changes for later sync
        syncService.addPendingSyncChange('orders', 'updated', order.id, order.toJson());
      }
    } catch (e) {
      debugPrint('❌ Failed to sync order to Firebase: $e');
      // Don't fail the save operation if Firebase sync fails
      // The order is still saved locally and will sync when connection is restored
    }
  }

  /// Update order from Firebase (for cross-device sync)
  Future<void> updateOrderFromFirebase(Order firebaseOrder) async {
    try {
      debugPrint('🔄 Updating order from Firebase: ${firebaseOrder.orderNumber}');
      
      // Check if order already exists locally
      final existingIndex = _allOrders.indexWhere((o) => o.id == firebaseOrder.id);
      
      if (existingIndex != -1) {
        // Update existing order
        _allOrders[existingIndex] = firebaseOrder;
        debugPrint('🔄 Updated existing order from Firebase: ${firebaseOrder.orderNumber}');
      } else {
        // Add new order from Firebase
        _allOrders.add(firebaseOrder);
        debugPrint('➕ Added new order from Firebase: ${firebaseOrder.orderNumber}');
      }
      
      // Update active/completed orders lists
      _activeOrders = _allOrders.where((o) => o.isActive).toList();
      _completedOrders = _allOrders.where((o) => !o.isActive).toList();
      
      // Save to local database
      final db = await _databaseService.database;
      if (db != null) {
        final orderData = firebaseOrder.toJson();
        await db.insert(
          'orders',
          orderData,
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
      
      debugPrint('✅ Order updated from Firebase: ${firebaseOrder.orderNumber}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to update order from Firebase: $e');
    }
  }

  /// Update local order state after saving
  void _updateLocalOrderState(Order order) {
    try {
      debugPrint('🔄 _updateLocalOrderState called for order: ${order.orderNumber}');
      debugPrint('📊 Current state before update: ${_allOrders.length} total, ${_activeOrders.length} active, ${_completedOrders.length} completed');
      debugPrint('🔍 Order status: ${order.status}, isActive: ${order.isActive}');
      
      // Check if order already exists in _allOrders
      final existingIndex = _allOrders.indexWhere((o) => o.id == order.id);
      
      if (existingIndex != -1) {
        // Update existing order
        _allOrders[existingIndex] = order;
        debugPrint('🔄 Updated existing order in local state: ${order.orderNumber}');
      } else {
        // Add new order
        _allOrders.add(order);
        debugPrint('➕ Added new order to local state: ${order.orderNumber}');
      }
      
      // Update active/completed orders lists
      _activeOrders = _allOrders.where((o) => o.isActive).toList();
      _completedOrders = _allOrders.where((o) => !o.isActive).toList();
      
      debugPrint('📊 Local state updated: ${_allOrders.length} total, ${_activeOrders.length} active, ${_completedOrders.length} completed');
      debugPrint('📋 Active orders: ${_activeOrders.map((o) => '${o.orderNumber}(${o.status})').join(', ')}');
      
      // Update stream
      _ordersStreamController.add(_allOrders);
      
      // Force notify listeners immediately
      notifyListeners();
      debugPrint('🔔 Listeners notified for order: ${order.orderNumber}');
      
    } catch (e) {
      debugPrint('❌ Error updating local order state: $e');
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
      debugPrint('❌ Error converting Order to SQLite map: $e');
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
      debugPrint('❌ Error converting OrderItem to SQLite map: $e');
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
      debugPrint('❌ Error converting SQLite map to Order format: $e');
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
      debugPrint('❌ Error converting SQLite map to OrderItem format: $e');
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
    
    try {
      _setLoading(true);
      debugPrint('📥 Loading orders from database');
      
      final Database? database = await _databaseService.database;
      if (database == null) {
        throw OrderServiceException('Database not available', operation: 'load_orders');
      }

      // Load orders with items
      final List<Map<String, dynamic>> orderResults = await database.query(
        'orders',
        orderBy: 'created_at DESC',  // Use snake_case column name
      );

      debugPrint('📋 Found ${orderResults.length} orders in database');

      final List<Order> orders = [];
      for (var orderMap in orderResults) {
        try {
          // Load order items
          final List<Map<String, dynamic>> itemResults = await database.query(
            'order_items',
            where: 'order_id = ?',
            whereArgs: [orderMap['id']],
          );

          debugPrint('📦 Order ${orderMap['order_number']} has ${itemResults.length} items');

          // Convert order items to proper format
          final List<OrderItem> items = [];
          for (var itemMap in itemResults) {
            try {
              // Get the menu item for this order item
              final menuItem = await _getMenuItemById(itemMap['menu_item_id']);
              if (menuItem != null) {
                // Convert SQLite map to OrderItem-compatible format
                final orderItemJson = _sqliteMapToOrderItem(itemMap);
                orderItemJson['menuItem'] = menuItem.toJson();
                
                final orderItem = OrderItem.fromJson(orderItemJson);
                items.add(orderItem);
              } else {
                debugPrint('⚠️ Menu item ${itemMap['menu_item_id']} not found for order item ${itemMap['id']}');
              }
            } catch (e) {
              debugPrint('❌ Error loading order item ${itemMap['id']}: $e');
            }
          }

          // Convert database map to Order-compatible format
          final orderJson = _sqliteMapToOrder(orderMap);
          orderJson['items'] = items.map((item) => item.toJson()).toList();
          
          // Create order with items
          final order = Order.fromJson(orderJson);
          orders.add(order);
          
          debugPrint('✅ Loaded order: ${order.orderNumber} with ${items.length} items');
        } catch (e) {
          debugPrint('❌ Error loading order ${orderMap['id']}: $e');
        }
      }

      // Update local state
      _allOrders = orders;
      _activeOrders = orders.where((o) => o.isActive).toList();
      _completedOrders = orders.where((o) => !o.isActive).toList();
      
      debugPrint('✅ Loaded ${orders.length} orders (${_activeOrders.length} active, ${_completedOrders.length} completed)');
      
      // No userId fixing needed - clean database approach
      
      // Safe notification to prevent crashes
      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint('❌ Error notifying listeners: $e');
        }
      });
      _ordersStreamController.add(_allOrders);
    } catch (e) {
      debugPrint('❌ Error loading orders: $e');
      throw OrderServiceException('Failed to load orders: $e', operation: 'load_orders', originalError: e);
    } finally {
      _setLoading(false);
    }
  }

  /// Load orders from local database
  Future<void> _loadOrdersFromDatabase() async {
    try {
      debugPrint('📥 Loading orders from database');
      
      final db = await _databaseService.database;
      if (db == null) {
        debugPrint('❌ Database not available');
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
          final order = Order.fromJson(orderMap);
          _allOrders.add(order);
          
          debugPrint('✅ Loaded order: ${order.orderNumber} with ${order.items.length} items');
        } catch (e) {
          debugPrint('❌ Failed to load order ${orderRow['order_number']}: $e');
        }
      }

      // Sort orders by creation date (newest first)
      _allOrders.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      final activeCount = _allOrders.where((order) => order.isActive).length;
      final completedCount = _allOrders.where((order) => !order.isActive).length;
      
      debugPrint('✅ Loaded ${_allOrders.length} orders ($activeCount active, $completedCount completed)');
      
      // Notify listeners
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to load orders from database: $e');
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

      debugPrint('🆕 Created new order: $orderNumber for user: ${customerName ?? 'Admin'} (ID: $orderUserId)');
      debugPrint('🆕 New order ID: ${order.id}');

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

      debugPrint('✅ Order created successfully: $orderNumber');
      return order;

    } catch (e) {
      debugPrint('❌ Error creating order: $e');
      rethrow;
    }
  }
  
  /// Trigger Firebase sync for order (INDEPENDENT operation)
  void _triggerFirebaseSync(Order order, String action) {
    // Use Future.microtask to ensure this runs after the current operation completes
    Future.microtask(() async {
      try {
        debugPrint('🔄 Starting independent Firebase sync for order: ${order.orderNumber} ($action)');
        
        final unifiedSyncService = UnifiedSyncService();
        
        // CRITICAL FIX: Ensure real-time sync is always active before syncing
        await unifiedSyncService.ensureRealTimeSyncActive();
        
        // Ensure sync service is initialized and connected
        try {
          if (action == 'created') {
            await unifiedSyncService.syncOrderToFirebase(order, 'created');
            
            // CRITICAL: Trigger immediate cross-device sync notification
            debugPrint('🔴 ORDER CREATED - TRIGGERING IMMEDIATE CROSS-DEVICE SYNC!');
            await _triggerImmediateCrossDeviceSync(order);
            
          } else if (action == 'updated') {
            await unifiedSyncService.syncOrderToFirebase(order, 'updated');
            
            // CRITICAL: Trigger immediate cross-device sync notification
            debugPrint('🔴 ORDER UPDATED - TRIGGERING IMMEDIATE CROSS-DEVICE SYNC!');
            await _triggerImmediateCrossDeviceSync(order);
          }
          
          debugPrint('✅ Order synced to Firebase: ${order.orderNumber} ($action)');
        } catch (e) {
          debugPrint('⚠️ Firebase sync failed for order ${order.orderNumber}: $e');
          // Don't fail the order creation - sync will retry later
        }
      } catch (e) {
        debugPrint('⚠️ Firebase sync trigger failed for order ${order.orderNumber}: $e');
        // Don't fail the order creation - sync will retry later
      }
    });
  }
  
  /// CRITICAL: Trigger immediate cross-device synchronization
  Future<void> _triggerImmediateCrossDeviceSync(Order order) async {
    try {
      debugPrint('🔴 IMMEDIATE CROSS-DEVICE SYNC: Ensuring all devices get updated instantly...');
      
      final unifiedSyncService = UnifiedSyncService();
      
      // Force a comprehensive sync to ensure all devices get the update
      await unifiedSyncService.forceSyncAllLocalData();
      
      // Additional: Force refresh of real-time listeners to ensure they're active
      await unifiedSyncService.ensureRealTimeSyncActive();
      
      debugPrint('✅ IMMEDIATE CROSS-DEVICE SYNC COMPLETED - All devices should see the new order instantly!');
      
    } catch (e) {
      debugPrint('⚠️ Immediate cross-device sync failed: $e');
      // Don't fail the main operation - this is just for enhanced sync
    }
  }
  
  /// Update an existing order
  Future<bool> updateOrder(Order updatedOrder) async {
    try {
      debugPrint('🔄 Updating order: ${updatedOrder.orderNumber}');
      
      // Update the timestamp
      final order = updatedOrder.copyWith(
        updatedAt: DateTime.now(),
      );

      // PHASE 1: Save to local database FIRST (CRITICAL)
      final saved = await saveOrder(order);
      if (!saved) {
        debugPrint('❌ Failed to save updated order to local database');
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

      debugPrint('✅ Order updated successfully: ${order.orderNumber}');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating order: $e');
      return false;
    }
  }
  
  /// Delete an order
  Future<bool> deleteOrder(String orderId) async {
    try {
      final order = _allOrders.firstWhere((o) => o.id == orderId);
      if (order == null) {
        debugPrint('❌ Order not found: $orderId');
        return false;
      }

      debugPrint('🗑️ Deleting order: ${order.orderNumber}');

      final db = await _databaseService.database;
      if (db == null) {
        debugPrint('❌ Database not available');
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
      final unifiedSyncService = UnifiedSyncService();
      await unifiedSyncService.syncOrderToFirebase(order, 'deleted');

      // Remove from local state
      _allOrders.removeWhere((o) => o.id == orderId);
      _activeOrders.removeWhere((o) => o.id == orderId);
      _completedOrders.removeWhere((o) => o.id == orderId);

      // Notify listeners
      notifyListeners();

      debugPrint('✅ Order deleted and synced: ${order.orderNumber}');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting order: $e');
      return false;
    }
  }

  /// Real-time Firebase sync for order deletion
  Future<void> _syncOrderDeletionToFirebase(Order order) async {
    try {
      debugPrint('🔄 Syncing order deletion to Firebase: ${order.orderNumber}');
      
      // Get the unified sync service
      final syncService = UnifiedSyncService();
      
      // Check if sync service is available and connected
      if (syncService.isConnected) {
        // Delete the order from Firebase
        await syncService.deleteItem('orders', order.id);
        debugPrint('✅ Order deletion synced to Firebase: ${order.orderNumber}');
      } else {
        debugPrint('⚠️ Firebase sync service not connected - deletion will sync when connection is restored');
        // Add to pending changes for later sync
        syncService.addPendingSyncChange('orders', 'deleted', order.id, {});
      }
    } catch (e) {
      debugPrint('❌ Failed to sync order deletion to Firebase: $e');
      // Don't fail the delete operation if Firebase sync fails
      // The order is still deleted locally and will sync when connection is restored
    }
  }

  /// Auto-sync order to Firebase
  Future<void> _autoSyncToFirebase(Order order, String action) async {
    try {
      debugPrint('🔄 Starting auto-sync to Firebase: ${order.orderNumber} ($action)');
      
      // Get the unified sync service instance
      final syncService = UnifiedSyncService();
      
      // Check if sync service is connected
      if (!syncService.isConnected) {
        debugPrint('⚠️ Firebase sync service not connected, attempting to connect...');
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
          debugPrint('⚠️ Failed to connect sync service: $e');
        }
      }
      
      // Attempt to sync the order
      if (syncService.isConnected) {
        if (action == 'deleted') {
          await syncService.deleteItem('orders', order.id);
        } else {
          await syncService.createOrUpdateOrder(order);
        }
        debugPrint('✅ Order auto-synced to Firebase: ${order.orderNumber} ($action)');
      } else {
        debugPrint('⚠️ Firebase sync service not available - order will be synced when connection is restored');
        // Queue for later sync if needed
        _queueForLaterSync(order, action);
      }
    } catch (e) {
      debugPrint('⚠️ Failed to auto-sync order to Firebase: $e');
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
        debugPrint('📋 Order queued for later sync: ${order.orderNumber}');
      });
    } catch (e) {
      debugPrint('❌ Failed to queue order for sync: $e');
    }
  }

  /// Generate unique order number with zero risk protection
  Future<String> _generateOrderNumber() async {
    try {
      debugPrint('🔢 Generating unique order number...');
      
      final Database? database = await _databaseService.database;
      if (database == null) {
        debugPrint('⚠️ Database not available, using timestamp-based fallback');
        return _generateTimestampBasedOrderNumber();
      }

      // ZERO RISK: Create backup of current order numbers
      final existingOrderNumbers = await _getExistingOrderNumbers();
      debugPrint('📋 Found ${existingOrderNumbers.length} existing order numbers');

      // Generate a unique order number using timestamp + random suffix
      String orderNumber;
      int attempts = 0;
      const maxAttempts = 10;
      
      do {
        orderNumber = _generateTimestampBasedOrderNumber();
        attempts++;
        
        if (attempts > maxAttempts) {
          debugPrint('⚠️ Max attempts reached, using UUID-based fallback');
          orderNumber = 'ORD-${const Uuid().v4().substring(0, 8).toUpperCase()}';
          break;
        }
      } while (existingOrderNumbers.contains(orderNumber));
      
      debugPrint('✅ Generated unique order number: $orderNumber (attempts: $attempts)');
      return orderNumber;
      
    } catch (e) {
      debugPrint('❌ Error generating order number: $e');
      // ZERO RISK: Always return a valid order number
      return _generateTimestampBasedOrderNumber();
    }
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
      debugPrint('⚠️ Error getting existing order numbers: $e');
      return <String>{};
    }
  }

  /// Update order status
  Future<bool> updateOrderStatus(String orderId, String newStatus) async {
    try {
      debugPrint('🔄 Updating order status: $orderId → $newStatus');
      
      final db = await _databaseService.database;
      if (db == null) {
        debugPrint('❌ Database not available');
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
        debugPrint('⚠️ Could not get order number for logging: $e');
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
          debugPrint('📦 Order marked as completed - updating inventory for: ${order.orderNumber}');
          final inventoryUpdated = await _inventoryService.updateInventoryOnOrderCompletion(order);
          if (inventoryUpdated) {
            debugPrint('✅ Inventory updated successfully for completed order: ${order.orderNumber}');
          } else {
            debugPrint('⚠️ No inventory updates made for order: ${order.orderNumber}');
          }
          
          // CRITICAL FIX: Don't clear current order state during completion to maintain kitchen printing functionality
          // Only clear if we're explicitly completing the current order and want to start fresh
          if (_currentOrder?.id == orderId) {
            debugPrint('⚠️ Current order is being completed - maintaining state for kitchen printing');
            // Don't clear _currentOrder here to prevent kitchen printing issues
          }
        } catch (e) {
          debugPrint('❌ Error updating inventory for completed order $orderId: $e');
          // Log the error but don't fail the status update
        }
      }

      debugPrint('✅ Order status updated successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating order status: $e');
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
      debugPrint('❌ Error getting order by ID: $e');
      return null;
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
        debugPrint('❌ Error notifying listeners: $e');
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
        debugPrint('❌ Error notifying listeners: $e');
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
        debugPrint('❌ Error notifying listeners: $e');
      }
    });
  }

  /// Save orders to cache
  void _saveOrdersToCache() {
    // Implementation for caching orders
    debugPrint('💾 Saving orders to cache');
  }

  /// Clear all orders from memory and database
  Future<void> clearAllOrders() async {
    try {
      debugPrint('🗑️ Clearing all orders...');
      
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
      
      debugPrint('✅ All orders cleared');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error clearing orders: $e');
      rethrow;
    }
  }

  /// Delete all orders from database (for testing/reset purposes)
  /// This preserves users, menu items, and categories - only clears orders
  Future<void> deleteAllOrders() async {
    try {
      debugPrint('🗑️ Starting to delete all orders...');
      
      final Database? database = await _databaseService.database;
      if (database == null) {
        throw OrderServiceException('Database not available', operation: 'delete_all_orders');
      }
      
      await database.transaction((txn) async {
        // Delete all order items first (foreign key constraint)
        final orderItemsDeleted = await txn.delete('order_items');
        debugPrint('✅ Deleted $orderItemsDeleted order items');
        
        // Delete all orders
        final ordersDeleted = await txn.delete('orders');
        debugPrint('✅ Deleted $ordersDeleted orders');
        
        // Delete all order logs
        final orderLogsDeleted = await txn.delete('order_logs');
        debugPrint('✅ Deleted $orderLogsDeleted order logs');
      });
      
      // Clear local state
      _activeOrders.clear();
      _completedOrders.clear();
      _allOrders.clear();
      _currentOrder = null;
      
      // Clear any cached data
      final Map<String, MenuItem> _menuItemCache = {};
      _menuItemCache.clear();
      
      debugPrint('✅ All orders deleted successfully - users and menu items preserved');
      // Safe notification to prevent crashes
      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint('❌ Error notifying listeners: $e');
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
      debugPrint('❌ Error deleting all orders: $e');
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
      debugPrint('🍽️ Sending order to kitchen: ${order.orderNumber}');
      
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
      
      debugPrint('✅ Order sent to kitchen: ${order.orderNumber}');
      return {
        'success': true,
        'message': 'Order sent to kitchen',
        'orderNumber': order.orderNumber,
        'status': 'preparing',
      };
      
    } catch (e) {
      debugPrint('❌ Error sending order to kitchen: $e');
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
      debugPrint('✅ Completing order: ${order.orderNumber}');
      
      // Update order status to completed
      final updatedOrder = order.copyWith(
        status: OrderStatus.completed,
        updatedAt: DateTime.now(),
      );
      
      // Update local state
      await updateOrder(updatedOrder);
      
      // Move from active to completed lists
      _activeOrders.removeWhere((o) => o.id == order.id);
      _completedOrders.add(updatedOrder);
      
      // Sort completed orders
      _completedOrders.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      // Notify listeners
      notifyListeners();
      
      debugPrint('✅ Order completed: ${order.orderNumber}');
      return {
        'success': true,
        'message': 'Order completed',
        'orderNumber': order.orderNumber,
        'status': 'completed',
      };
      
    } catch (e) {
      debugPrint('❌ Error completing order: $e');
      return {
        'success': false,
        'message': 'Failed to complete order: $e',
        'orderNumber': order.orderNumber,
      };
    }
  }

  /// Comprehensive timestamp-based synchronization between local and Firebase
  Future<void> syncOrdersWithFirebase() async {
    try {
      debugPrint('🔄 Starting comprehensive timestamp-based order synchronization...');
      
      final db = await _databaseService.database;
      if (db == null) {
        debugPrint('❌ Database not available for sync');
        return;
      }

      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) {
        debugPrint('❌ No tenant ID available for sync');
        return;
      }

      debugPrint('🔍 Syncing orders for tenant: $tenantId');

      // PHASE 1: Get local orders with proper timestamp mapping
      final localOrdersResult = await db.query('orders');
      final localOrders = <String, Map<String, dynamic>>{};
      
      for (final row in localOrdersResult) {
        // Convert database snake_case to Firebase camelCase
        final firebaseFormat = _convertDbToFirebaseFormat(row);
        localOrders[row['id'] as String] = firebaseFormat;
      }
      
      debugPrint('📊 Found ${localOrders.length} orders in local database');

      // PHASE 2: Get Firebase orders
      final firestoreInstance = fs.FirebaseFirestore.instance;
      final ordersSnapshot = await firestoreInstance
          .collection('tenants')
          .doc(tenantId)
          .collection('orders')
          .get();
      
      final firebaseOrders = <String, Map<String, dynamic>>{};
      for (final doc in ordersSnapshot.docs) {
        if (doc.id == '_persistence_config') continue;
        
        final orderData = doc.data();
        orderData['id'] = doc.id;
        firebaseOrders[doc.id] = orderData;
      }
      
      debugPrint('📊 Found ${firebaseOrders.length} orders in Firebase');

      // PHASE 3: Comprehensive sync logic
      int downloadedFromFirebase = 0;
      int uploadedToFirebase = 0;
      int skippedCount = 0;

      final allOrderIds = {...localOrders.keys, ...firebaseOrders.keys};
      
      for (final orderId in allOrderIds) {
        final localOrder = localOrders[orderId];
        final firebaseOrder = firebaseOrders[orderId];

        if (localOrder != null && firebaseOrder != null) {
          // Both exist - compare timestamps using correct field names
          final localUpdatedAt = DateTime.parse(localOrder['updatedAt'] ?? '1970-01-01T00:00:00.000Z');
          final firebaseUpdatedAt = DateTime.parse(firebaseOrder['updatedAt'] ?? '1970-01-01T00:00:00.000Z');
          
          if (localUpdatedAt.isAfter(firebaseUpdatedAt)) {
            // Local is newer - upload to Firebase
            await _uploadOrderToFirebase(localOrder, tenantId);
            uploadedToFirebase++;
          } else if (firebaseUpdatedAt.isAfter(localUpdatedAt)) {
            // Firebase is newer - download to local
            await _downloadOrderFromFirebase(firebaseOrder);
            downloadedFromFirebase++;
          } else {
            // Timestamps are equal - no update needed
            skippedCount++;
          }
        } else if (localOrder != null) {
          // Only local exists - upload to Firebase
          await _uploadOrderToFirebase(localOrder, tenantId);
          uploadedToFirebase++;
        } else if (firebaseOrder != null) {
          // Only Firebase exists - download to local
          await _downloadOrderFromFirebase(firebaseOrder);
          downloadedFromFirebase++;
        }
      }

      // PHASE 4: Reload and notify
      await _loadOrdersFromDatabase();
      notifyListeners();

      debugPrint('✅ Comprehensive sync completed:');
      debugPrint('   📥 Downloaded from Firebase: $downloadedFromFirebase');
      debugPrint('   📤 Uploaded to Firebase: $uploadedToFirebase');
      debugPrint('   ⏭️ Skipped (no changes): $skippedCount');

    } catch (e) {
      debugPrint('❌ Comprehensive sync failed: $e');
      rethrow; // Re-throw to allow error handling in calling code
    }
  }

  /// Enhanced force sync with better error handling
  Future<void> forceSyncFromFirebase() async {
    try {
      debugPrint('🔄 Enhanced force syncing orders from Firebase...');
      
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) {
        debugPrint('❌ No tenant ID available for sync');
        return;
      }

      debugPrint('🔍 Using tenant ID: $tenantId');

      final firestoreInstance = fs.FirebaseFirestore.instance;
      
      // Test Firebase connection
      try {
        await firestoreInstance.collection('tenants').doc(tenantId).get();
        debugPrint('✅ Firebase connection test successful');
      } catch (e) {
        debugPrint('❌ Firebase connection test failed: $e');
        return;
      }

      final ordersSnapshot = await firestoreInstance
          .collection('tenants')
          .doc(tenantId)
          .collection('orders')
          .get();
      
      debugPrint('📊 Found ${ordersSnapshot.docs.length} orders in Firebase');
      
      int syncedCount = 0;
      int errorCount = 0;
      
      for (final doc in ordersSnapshot.docs) {
        try {
          final orderData = doc.data();
          orderData['id'] = doc.id;
          
          // Skip non-order documents
          if (doc.id == '_persistence_config' || !orderData.containsKey('orderNumber')) {
            debugPrint('⏭️ Skipping non-order document: ${doc.id}');
            continue;
          }
          
          final order = Order.fromJson(orderData);
          await updateOrderFromFirebase(order);
          syncedCount++;
          debugPrint('✅ Synced order: ${order.orderNumber}');
        } catch (e) {
          errorCount++;
          debugPrint('❌ Failed to sync order ${doc.id}: $e');
        }
      }

      debugPrint('✅ Enhanced force sync completed:');
      debugPrint('   📥 Successfully synced: $syncedCount orders');
      debugPrint('   ❌ Failed to sync: $errorCount orders');
      
      // Reload orders from database
      await _loadOrdersFromDatabase();
      notifyListeners();
      
    } catch (e) {
      debugPrint('❌ Enhanced force sync failed: $e');
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

      debugPrint('⬇️ Downloaded order from Firebase: ${firebaseOrder['orderNumber']}');
    } catch (e) {
      debugPrint('❌ Failed to download order from Firebase: $e');
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

      debugPrint('⬆️ Uploaded order to Firebase: ${localOrder['orderNumber']}');
    } catch (e) {
      debugPrint('❌ Failed to upload order to Firebase: $e');
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

      debugPrint('⬇️ Downloaded order item from Firebase: ${firebaseItem['id']}');
    } catch (e) {
      debugPrint('❌ Failed to download order item from Firebase: $e');
    }
  }

  /// Manual sync trigger for testing
  Future<void> manualSync() async {
    try {
      debugPrint('🔄 Manual sync triggered...');
      
      // Use the comprehensive sync method
      await syncOrdersWithFirebase();
      
      debugPrint('✅ Manual sync completed');
    } catch (e) {
      debugPrint('❌ Manual sync failed: $e');
      // Try force sync as fallback
      try {
        await forceSyncFromFirebase();
        debugPrint('✅ Force sync completed as fallback');
      } catch (e2) {
        debugPrint('❌ Force sync also failed: $e2');
      }
    }
  }


  @override
  void dispose() {
    if (_disposed) return;
    
    debugPrint('🧹 Disposing OrderService');
    _disposed = true;
    _autoSaveTimer?.cancel();
    _ordersStreamController.close();
    _currentOrderStreamController.close();
    _menuItemCache.clear();
    super.dispose();
  }
} 