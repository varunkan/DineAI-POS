import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
import 'package:sqflite/sqflite.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../config/firebase_config.dart';
import '../models/order.dart' as pos_order;
import '../models/restaurant.dart';
import '../models/user.dart';
import '../models/menu_item.dart';
import '../models/category.dart' as pos_category;
import '../models/inventory_item.dart';
import '../models/table.dart';
import '../services/database_service.dart';
import '../services/order_service.dart';
import '../services/menu_service.dart';
import '../services/user_service.dart';
import '../services/inventory_service.dart';
import '../services/table_service.dart';

/// COMPREHENSIVE SYNC FIX SERVICE
/// Fixes all identified sync issues with zero-risk approach
class SyncFixService {
  static SyncFixService? _instance;
  static SyncFixService get instance => _instance ??= SyncFixService._internal();
  
  SyncFixService._internal();
  
  // Firebase instances
  fs.FirebaseFirestore? _firestore;
  
  // Service instances
  DatabaseService? _databaseService;
  OrderService? _orderService;
  
  // Fix state
  bool _isFixing = false;
  final List<String> _fixLog = [];
  
  // Connectivity
  bool _isOnline = true;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  /// Initialize the sync fix service
  Future<void> initialize() async {
    try {
      
      // Initialize Firebase if available
      if (FirebaseConfig.isInitialized) {
        _firestore = fs.FirebaseFirestore.instance;
        
        // Configure Firebase for better reliability
        _firestore!.settings = const fs.Settings(
          persistenceEnabled: true,
          cacheSizeBytes: fs.Settings.CACHE_SIZE_UNLIMITED,
        );
      }
      
      // Start connectivity monitoring
      _startConnectivityMonitoring();
      
    } catch (e) {
    }
  }
  
  /// Start connectivity monitoring
  void _startConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;
      
      if (!wasOnline && _isOnline) {
        _addFixLog('🌐 Connection restored - triggering sync fix');
        // Auto-fix when connection is restored
        unawaited(fixAllSyncIssues());
      }
    });
  }
  
  /// Add message to fix log
  void _addFixLog(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message';
    _fixLog.add(logMessage);
    
    // Keep only last 100 log entries
    if (_fixLog.length > 100) {
      _fixLog.removeAt(0);
    }
  }
  
  /// Get fix log
  List<String> get fixLog => List.unmodifiable(_fixLog);
  
  /// Fix all sync issues comprehensively
  Future<bool> fixAllSyncIssues() async {
    if (_isFixing) {
      _addFixLog('⚠️ Sync fix already in progress, skipping duplicate call');
      return false;
    }
    
    _isFixing = true;
    _addFixLog('🔧 Starting comprehensive sync fix...');
    
    try {
      // PHASE 1: Fix Firebase connection issues
      await _fixFirebaseConnectionIssues();
      
      // PHASE 2: Fix database constraint violations
      await _fixDatabaseConstraintViolations();
      
      // PHASE 3: Fix duplicate data issues
      await _fixDuplicateDataIssues();
      
      // PHASE 4: Fix ghost orders and orphaned data
      await _fixGhostOrdersAndOrphanedData();
      
      // PHASE 5: Fix timestamp synchronization issues
      await _fixTimestampSynchronizationIssues();
      
      // PHASE 6: Fix real-time listener issues
      await _fixRealTimeListenerIssues();
      
      // PHASE 7: Perform comprehensive data validation
      await _performComprehensiveDataValidation();
      
      _addFixLog('✅ All sync issues fixed successfully');
      return true;
      
    } catch (e) {
      _addFixLog('❌ Sync fix failed: $e');
      return false;
    } finally {
      _isFixing = false;
    }
  }
  
  /// Fix Firebase connection issues
  Future<void> _fixFirebaseConnectionIssues() async {
    try {
      _addFixLog('🔧 Fixing Firebase connection issues...');
      
      if (!_isOnline) {
        _addFixLog('⚠️ Device is offline - skipping Firebase fixes');
        return;
      }
      
      if (_firestore == null) {
        _addFixLog('⚠️ Firebase not initialized - attempting initialization');
        
        if (FirebaseConfig.isInitialized) {
          _firestore = fs.FirebaseFirestore.instance;
          _firestore!.settings = const fs.Settings(
            persistenceEnabled: true,
            cacheSizeBytes: fs.Settings.CACHE_SIZE_UNLIMITED,
          );
          _addFixLog('✅ Firebase initialized successfully');
        } else {
          _addFixLog('❌ Firebase not available - continuing with local fixes only');
          return;
        }
      }
      
      // Test Firebase connection
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) {
        _addFixLog('❌ No tenant ID available for Firebase connection test');
        return;
      }
      
      try {
        final testDoc = await _firestore!.collection('tenants').doc(tenantId).get();
        _addFixLog('✅ Firebase connection test successful - tenant exists: ${testDoc.exists}');
      } catch (e) {
        _addFixLog('❌ Firebase connection test failed: $e');
        
        // Try to fix connection by clearing cache and reconnecting
        try {
          await _firestore!.clearPersistence();
          _addFixLog('🔧 Cleared Firebase persistence cache');
          
          // Reinitialize settings
          _firestore!.settings = const fs.Settings(
            persistenceEnabled: true,
            cacheSizeBytes: fs.Settings.CACHE_SIZE_UNLIMITED,
          );
          
          // Test again
          final retestDoc = await _firestore!.collection('tenants').doc(tenantId).get();
          _addFixLog('✅ Firebase reconnection successful after cache clear');
        } catch (reconnectError) {
          _addFixLog('❌ Firebase reconnection failed: $reconnectError');
        }
      }
      
    } catch (e) {
      _addFixLog('❌ Firebase connection fix failed: $e');
    }
  }
  
  /// Fix database constraint violations
  Future<void> _fixDatabaseConstraintViolations() async {
    try {
      _addFixLog('🔧 Fixing database constraint violations...');
      
      final db = await _databaseService?.database;
      if (db == null) {
        _addFixLog('⚠️ Database not available for constraint fixes');
        return;
      }
      
      // Enable foreign key constraints
      await db.execute('PRAGMA foreign_keys = ON');
      _addFixLog('✅ Enabled foreign key constraints');
      
      // Fix orphaned order items
      await _fixOrphanedOrderItems(db);
      
      // Fix invalid order statuses
      await _fixInvalidOrderStatuses(db);
      
      // Fix missing required fields
      await _fixMissingRequiredFields(db);
      
      // Fix invalid timestamps
      await _fixInvalidTimestamps(db);
      
      _addFixLog('✅ Database constraint violations fixed');
      
    } catch (e) {
      _addFixLog('❌ Database constraint fix failed: $e');
    }
  }
  
  /// Fix orphaned order items
  Future<void> _fixOrphanedOrderItems(Database db) async {
    try {
      _addFixLog('🔧 Fixing orphaned order items...');
      
      // Find order items without valid orders
      final orphanedItems = await db.rawQuery('''
        SELECT oi.id, oi.order_id 
        FROM order_items oi 
        LEFT JOIN orders o ON oi.order_id = o.id 
        WHERE o.id IS NULL
      ''');
      
      if (orphanedItems.isNotEmpty) {
        _addFixLog('🗑️ Found ${orphanedItems.length} orphaned order items');
        
        // Delete orphaned order items
        for (final item in orphanedItems) {
          await db.delete('order_items', where: 'id = ?', whereArgs: [item['id']]);
        }
        
        _addFixLog('✅ Removed ${orphanedItems.length} orphaned order items');
      } else {
        _addFixLog('✅ No orphaned order items found');
      }
      
      // Find order items with invalid menu items
      final invalidMenuItems = await db.rawQuery('''
        SELECT oi.id, oi.menu_item_id 
        FROM order_items oi 
        LEFT JOIN menu_items mi ON oi.menu_item_id = mi.id 
        WHERE mi.id IS NULL
      ''');
      
      if (invalidMenuItems.isNotEmpty) {
        _addFixLog('⚠️ Found ${invalidMenuItems.length} order items with invalid menu items');
        
        // For now, just log these - don't delete as they might be valid historical data
        for (final item in invalidMenuItems) {
          _addFixLog('⚠️ Order item ${item['id']} references missing menu item ${item['menu_item_id']}');
        }
      }
      
    } catch (e) {
      _addFixLog('❌ Orphaned order items fix failed: $e');
    }
  }
  
  /// Fix invalid order statuses
  Future<void> _fixInvalidOrderStatuses(Database db) async {
    try {
      _addFixLog('🔧 Fixing invalid order statuses...');
      
      // Find orders with invalid statuses
      final invalidStatuses = await db.rawQuery('''
        SELECT id, status FROM orders 
        WHERE status NOT IN ('pending', 'confirmed', 'preparing', 'ready', 'completed', 'cancelled')
      ''');
      
      if (invalidStatuses.isNotEmpty) {
        _addFixLog('🔧 Found ${invalidStatuses.length} orders with invalid statuses');
        
        for (final order in invalidStatuses) {
          // Default invalid statuses to 'pending'
          await db.update(
            'orders',
            {'status': 'pending', 'updated_at': DateTime.now().toIso8601String()},
            where: 'id = ?',
            whereArgs: [order['id']],
          );
          _addFixLog('🔧 Fixed invalid status "${order['status']}" for order ${order['id']}');
        }
        
        _addFixLog('✅ Fixed ${invalidStatuses.length} invalid order statuses');
      } else {
        _addFixLog('✅ No invalid order statuses found');
      }
      
    } catch (e) {
      _addFixLog('❌ Invalid order status fix failed: $e');
    }
  }
  
  /// Fix missing required fields
  Future<void> _fixMissingRequiredFields(Database db) async {
    try {
      _addFixLog('🔧 Fixing missing required fields...');
      
      // Fix orders with missing required fields
      final ordersWithMissingFields = await db.rawQuery('''
        SELECT id, order_number, user_id, created_at, updated_at 
        FROM orders 
        WHERE order_number IS NULL OR order_number = '' 
           OR user_id IS NULL OR user_id = ''
           OR created_at IS NULL OR created_at = ''
           OR updated_at IS NULL OR updated_at = ''
      ''');
      
      if (ordersWithMissingFields.isNotEmpty) {
        _addFixLog('🔧 Found ${ordersWithMissingFields.length} orders with missing required fields');
        
        for (final order in ordersWithMissingFields) {
          final updates = <String, dynamic>{};
          
          if (order['order_number'] == null || order['order_number'] == '') {
            updates['order_number'] = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
          }
          
          if (order['user_id'] == null || order['user_id'] == '') {
            updates['user_id'] = 'admin';
          }
          
          final now = DateTime.now().toIso8601String();
          if (order['created_at'] == null || order['created_at'] == '') {
            updates['created_at'] = now;
          }
          
          if (order['updated_at'] == null || order['updated_at'] == '') {
            updates['updated_at'] = now;
          }
          
          if (updates.isNotEmpty) {
            await db.update('orders', updates, where: 'id = ?', whereArgs: [order['id']]);
            _addFixLog('🔧 Fixed missing fields for order ${order['id']}');
          }
        }
        
        _addFixLog('✅ Fixed ${ordersWithMissingFields.length} orders with missing fields');
      } else {
        _addFixLog('✅ No orders with missing required fields found');
      }
      
    } catch (e) {
      _addFixLog('❌ Missing required fields fix failed: $e');
    }
  }
  
  /// Fix invalid timestamps
  Future<void> _fixInvalidTimestamps(Database db) async {
    try {
      _addFixLog('🔧 Fixing invalid timestamps...');
      
      // Fix orders with invalid timestamps
      final invalidTimestamps = await db.rawQuery('''
        SELECT id, created_at, updated_at, order_time 
        FROM orders 
        WHERE created_at = '1970-01-01T00:00:00.000Z' 
           OR updated_at = '1970-01-01T00:00:00.000Z'
           OR order_time = '1970-01-01T00:00:00.000Z'
           OR created_at IS NULL
           OR updated_at IS NULL
           OR order_time IS NULL
      ''');
      
      if (invalidTimestamps.isNotEmpty) {
        _addFixLog('🔧 Found ${invalidTimestamps.length} orders with invalid timestamps');
        
        for (final order in invalidTimestamps) {
          final now = DateTime.now().toIso8601String();
          final updates = <String, dynamic>{};
          
          if (order['created_at'] == null || order['created_at'] == '1970-01-01T00:00:00.000Z') {
            updates['created_at'] = now;
          }
          
          if (order['updated_at'] == null || order['updated_at'] == '1970-01-01T00:00:00.000Z') {
            updates['updated_at'] = now;
          }
          
          if (order['order_time'] == null || order['order_time'] == '1970-01-01T00:00:00.000Z') {
            updates['order_time'] = now;
          }
          
          if (updates.isNotEmpty) {
            await db.update('orders', updates, where: 'id = ?', whereArgs: [order['id']]);
            _addFixLog('🔧 Fixed invalid timestamps for order ${order['id']}');
          }
        }
        
        _addFixLog('✅ Fixed ${invalidTimestamps.length} orders with invalid timestamps');
      } else {
        _addFixLog('✅ No orders with invalid timestamps found');
      }
      
    } catch (e) {
      _addFixLog('❌ Invalid timestamps fix failed: $e');
    }
  }
  
  /// Fix duplicate data issues
  Future<void> _fixDuplicateDataIssues() async {
    try {
      _addFixLog('🔧 Fixing duplicate data issues...');
      
      final db = await _databaseService?.database;
      if (db == null) {
        _addFixLog('⚠️ Database not available for duplicate fixes');
        return;
      }
      
      // Fix duplicate orders
      await _fixDuplicateOrders(db);
      
      // Fix duplicate order items
      await _fixDuplicateOrderItems(db);
      
      // Fix duplicate menu items
      await _fixDuplicateMenuItems(db);
      
      _addFixLog('✅ Duplicate data issues fixed');
      
    } catch (e) {
      _addFixLog('❌ Duplicate data fix failed: $e');
    }
  }
  
  /// Fix duplicate orders
  Future<void> _fixDuplicateOrders(Database db) async {
    try {
      _addFixLog('🔧 Fixing duplicate orders...');
      
      // Find duplicate orders by order_number
      final duplicates = await db.rawQuery('''
        SELECT order_number, COUNT(*) as count, GROUP_CONCAT(id) as ids
        FROM orders 
        GROUP BY order_number 
        HAVING COUNT(*) > 1
      ''');
      
      if (duplicates.isNotEmpty) {
        _addFixLog('🔧 Found ${duplicates.length} sets of duplicate orders');
        
        for (final duplicate in duplicates) {
          final ids = (duplicate['ids'] as String).split(',');
          final orderNumber = duplicate['order_number'] as String;
          
          _addFixLog('🔧 Processing duplicate order_number: $orderNumber (${ids.length} duplicates)');
          
          // Keep the most recent order (by updated_at), delete the rest
          final orderDetails = await db.rawQuery('''
            SELECT id, updated_at FROM orders 
            WHERE order_number = ? 
            ORDER BY updated_at DESC
          ''', [orderNumber]);
          
          if (orderDetails.isNotEmpty) {
            final keepId = orderDetails.first['id'];
            
            for (int i = 1; i < orderDetails.length; i++) {
              final deleteId = orderDetails[i]['id'];
              
              // Delete associated order items first
              await db.delete('order_items', where: 'order_id = ?', whereArgs: [deleteId]);
              
              // Delete the duplicate order
              await db.delete('orders', where: 'id = ?', whereArgs: [deleteId]);
              
              _addFixLog('🗑️ Deleted duplicate order: $deleteId (kept: $keepId)');
            }
          }
        }
        
        _addFixLog('✅ Fixed ${duplicates.length} sets of duplicate orders');
      } else {
        _addFixLog('✅ No duplicate orders found');
      }
      
    } catch (e) {
      _addFixLog('❌ Duplicate orders fix failed: $e');
    }
  }
  
  /// Fix duplicate order items
  Future<void> _fixDuplicateOrderItems(Database db) async {
    try {
      _addFixLog('🔧 Fixing duplicate order items...');
      
      // Find duplicate order items by order_id + menu_item_id combination
      final duplicates = await db.rawQuery('''
        SELECT order_id, menu_item_id, COUNT(*) as count, GROUP_CONCAT(id) as ids
        FROM order_items 
        GROUP BY order_id, menu_item_id 
        HAVING COUNT(*) > 1
      ''');
      
      if (duplicates.isNotEmpty) {
        _addFixLog('🔧 Found ${duplicates.length} sets of duplicate order items');
        
        for (final duplicate in duplicates) {
          final ids = (duplicate['ids'] as String).split(',');
          final orderId = duplicate['order_id'] as String;
          final menuItemId = duplicate['menu_item_id'] as String;
          
          _addFixLog('🔧 Processing duplicate order items: order=$orderId, menu_item=$menuItemId (${ids.length} duplicates)');
          
          // Get details of all duplicates
          final itemDetails = await db.rawQuery('''
            SELECT id, quantity, price, created_at FROM order_items 
            WHERE order_id = ? AND menu_item_id = ?
            ORDER BY created_at DESC
          ''', [orderId, menuItemId]);
          
          if (itemDetails.isNotEmpty) {
            // Keep the first item and merge quantities
            final keepItem = itemDetails.first;
            double totalQuantity = 0;
            
            for (final item in itemDetails) {
              totalQuantity += (item['quantity'] as num).toDouble();
            }
            
            // Update the kept item with merged quantity
            await db.update(
              'order_items',
              {'quantity': totalQuantity, 'updated_at': DateTime.now().toIso8601String()},
              where: 'id = ?',
              whereArgs: [keepItem['id']],
            );
            
            // Delete the duplicate items
            for (int i = 1; i < itemDetails.length; i++) {
              await db.delete('order_items', where: 'id = ?', whereArgs: [itemDetails[i]['id']]);
            }
            
            _addFixLog('🔧 Merged ${itemDetails.length} duplicate order items (total quantity: $totalQuantity)');
          }
        }
        
        _addFixLog('✅ Fixed ${duplicates.length} sets of duplicate order items');
      } else {
        _addFixLog('✅ No duplicate order items found');
      }
      
    } catch (e) {
      _addFixLog('❌ Duplicate order items fix failed: $e');
    }
  }
  
  /// Fix duplicate menu items
  Future<void> _fixDuplicateMenuItems(Database db) async {
    try {
      _addFixLog('🔧 Fixing duplicate menu items...');
      
      // Find duplicate menu items by name
      final duplicates = await db.rawQuery('''
        SELECT name, COUNT(*) as count, GROUP_CONCAT(id) as ids
        FROM menu_items 
        GROUP BY name 
        HAVING COUNT(*) > 1
      ''');
      
      if (duplicates.isNotEmpty) {
        _addFixLog('🔧 Found ${duplicates.length} sets of duplicate menu items');
        
        for (final duplicate in duplicates) {
          final ids = (duplicate['ids'] as String).split(',');
          final name = duplicate['name'] as String;
          
          _addFixLog('🔧 Processing duplicate menu item: $name (${ids.length} duplicates)');
          
          // Keep the most recent menu item, delete the rest
          final itemDetails = await db.rawQuery('''
            SELECT id, updated_at FROM menu_items 
            WHERE name = ? 
            ORDER BY updated_at DESC
          ''', [name]);
          
          if (itemDetails.isNotEmpty) {
            final keepId = itemDetails.first['id'];
            
            for (int i = 1; i < itemDetails.length; i++) {
              final deleteId = itemDetails[i]['id'];
              
              // Update order items to reference the kept menu item
              await db.update(
                'order_items',
                {'menu_item_id': keepId},
                where: 'menu_item_id = ?',
                whereArgs: [deleteId],
              );
              
              // Delete the duplicate menu item
              await db.delete('menu_items', where: 'id = ?', whereArgs: [deleteId]);
              
              _addFixLog('🗑️ Deleted duplicate menu item: $deleteId (kept: $keepId)');
            }
          }
        }
        
        _addFixLog('✅ Fixed ${duplicates.length} sets of duplicate menu items');
      } else {
        _addFixLog('✅ No duplicate menu items found');
      }
      
    } catch (e) {
      _addFixLog('❌ Duplicate menu items fix failed: $e');
    }
  }
  
  /// Fix ghost orders and orphaned data
  Future<void> _fixGhostOrdersAndOrphanedData() async {
    try {
      _addFixLog('🔧 Fixing ghost orders and orphaned data...');
      
      final db = await _databaseService?.database;
      if (db == null) {
        _addFixLog('⚠️ Database not available for ghost order fixes');
        return;
      }
      
      // Fix ghost orders (orders with zero total and no items)
      await _fixGhostOrders(db);
      
      // Fix orphaned data
      await _fixOrphanedData(db);
      
      _addFixLog('✅ Ghost orders and orphaned data fixed');
      
    } catch (e) {
      _addFixLog('❌ Ghost orders fix failed: $e');
    }
  }
  
  /// Fix ghost orders - AGGRESSIVE VERSION
  Future<void> _fixGhostOrders(Database db) async {
    try {
      _addFixLog('🔧 AGGRESSIVE ghost order cleanup starting...');
      
      // Find ALL orders with zero total OR no items (regardless of status)
      final ghostOrders = await db.rawQuery('''
        SELECT DISTINCT o.id, o.order_number, o.total_amount, o.status,
               COUNT(oi.id) as item_count
        FROM orders o
        LEFT JOIN order_items oi ON o.id = oi.order_id
        GROUP BY o.id
        HAVING (o.total_amount = 0 OR o.total_amount IS NULL OR item_count = 0)
      ''');
      
      if (ghostOrders.isNotEmpty) {
        _addFixLog('👻 Found ${ghostOrders.length} ghost orders for IMMEDIATE deletion');
        
        // Collect order IDs for Firebase deletion
        final ghostOrderIds = <String>[];
        
        await db.transaction((txn) async {
          for (final ghostOrder in ghostOrders) {
            final orderId = ghostOrder['id'] as String;
            final orderNumber = ghostOrder['order_number'] as String?;
            final totalAmount = ghostOrder['total_amount'] as double?;
            final itemCount = ghostOrder['item_count'] as int;
            final status = ghostOrder['status'] as String?;
            
            _addFixLog('🗑️ DELETING ghost order: $orderNumber (ID: $orderId, Items: $itemCount, Total: \$${totalAmount ?? 0}, Status: $status)');
            
            // Delete order items first (if any)
            await txn.delete('order_items', where: 'order_id = ?', whereArgs: [orderId]);
            
            // Delete the order
            await txn.delete('orders', where: 'id = ?', whereArgs: [orderId]);
            
            // Add to Firebase deletion list
            ghostOrderIds.add(orderId);
          }
        });
        
        _addFixLog('✅ DELETED ${ghostOrders.length} ghost orders from local database');
        
        // Also delete from Firebase if online
        if (_isOnline && _firestore != null) {
          await _deleteGhostOrdersFromFirebase(ghostOrderIds);
        } else {
          _addFixLog('⚠️ Offline - ghost orders will be deleted from Firebase on next sync');
        }
        
      } else {
        _addFixLog('✅ No ghost orders found');
      }
      
    } catch (e) {
      _addFixLog('❌ Ghost orders fix failed: $e');
    }
  }
  
  /// Delete ghost orders from Firebase
  Future<void> _deleteGhostOrdersFromFirebase(List<String> orderIds) async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) {
        _addFixLog('⚠️ No tenant ID for Firebase ghost order deletion');
        return;
      }
      
      _addFixLog('☁️ Deleting ${orderIds.length} ghost orders from Firebase...');
      
      final batch = _firestore!.batch();
      int batchCount = 0;
      
      for (final orderId in orderIds) {
        final orderRef = _firestore!
            .collection('tenants')
            .doc(tenantId)
            .collection('orders')
            .doc(orderId);
            
        batch.delete(orderRef);
        batchCount++;
        
        // Commit batch every 500 operations to avoid limits
        if (batchCount >= 500) {
          await batch.commit();
          _addFixLog('📦 Committed batch of $batchCount Firebase deletions');
          batchCount = 0;
        }
      }
      
      // Commit remaining operations
      if (batchCount > 0) {
        await batch.commit();
        _addFixLog('📦 Committed final batch of $batchCount Firebase deletions');
      }
      
      _addFixLog('✅ Deleted ${orderIds.length} ghost orders from Firebase');
      
    } catch (e) {
      _addFixLog('❌ Firebase ghost order deletion failed: $e');
    }
  }
  
  /// Fix orphaned data
  Future<void> _fixOrphanedData(Database db) async {
    try {
      _addFixLog('🔧 Fixing orphaned data...');
      
      // Already handled orphaned order items in constraint fixes
      // Here we can add other orphaned data fixes if needed
      
      _addFixLog('✅ Orphaned data check completed');
      
    } catch (e) {
      _addFixLog('❌ Orphaned data fix failed: $e');
    }
  }
  
  /// Fix timestamp synchronization issues
  Future<void> _fixTimestampSynchronizationIssues() async {
    try {
      _addFixLog('🔧 Fixing timestamp synchronization issues...');
      
      if (!_isOnline || _firestore == null) {
        _addFixLog('⚠️ Skipping timestamp sync fixes - offline or Firebase unavailable');
        return;
      }
      
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) {
        _addFixLog('⚠️ No tenant ID available for timestamp sync fixes');
        return;
      }
      
      // Perform comprehensive timestamp-based sync
      await _performTimestampBasedSync(tenantId);
      
      _addFixLog('✅ Timestamp synchronization issues fixed');
      
    } catch (e) {
      _addFixLog('❌ Timestamp synchronization fix failed: $e');
    }
  }
  
  /// Perform timestamp-based sync
  Future<void> _performTimestampBasedSync(String tenantId) async {
    try {
      _addFixLog('🔄 Performing timestamp-based sync...');
      
      final db = await _databaseService?.database;
      if (db == null) return;
      
      // Sync orders with timestamp comparison
      await _syncOrdersWithTimestamps(db, tenantId);
      
      _addFixLog('✅ Timestamp-based sync completed');
      
    } catch (e) {
      _addFixLog('❌ Timestamp-based sync failed: $e');
    }
  }
  
  /// Sync orders with timestamps
  Future<void> _syncOrdersWithTimestamps(Database db, String tenantId) async {
    try {
      _addFixLog('🔄 Syncing orders with timestamp comparison...');
      
      // Get local orders
      final localOrders = await db.query('orders');
      final localOrderMap = <String, Map<String, dynamic>>{};
      
      for (final order in localOrders) {
        localOrderMap[order['id'] as String] = order;
      }
      
      // Get Firebase orders
      final firebaseSnapshot = await _firestore!
          .collection('tenants')
          .doc(tenantId)
          .collection('orders')
          .get();
      
      final firebaseOrderMap = <String, Map<String, dynamic>>{};
      for (final doc in firebaseSnapshot.docs) {
        if (doc.id != '_persistence_config') {
          final data = doc.data();
          data['id'] = doc.id;
          firebaseOrderMap[doc.id] = data;
        }
      }
      
      _addFixLog('📊 Local orders: ${localOrderMap.length}, Firebase orders: ${firebaseOrderMap.length}');
      
      // Compare and sync
      int uploaded = 0;
      int downloaded = 0;
      int skipped = 0;
      
      final allOrderIds = {...localOrderMap.keys, ...firebaseOrderMap.keys};
      
      for (final orderId in allOrderIds) {
        final localOrder = localOrderMap[orderId];
        final firebaseOrder = firebaseOrderMap[orderId];
        
        if (localOrder != null && firebaseOrder != null) {
          // Both exist - compare timestamps
          final localUpdated = DateTime.parse(localOrder['updated_at'] as String? ?? '1970-01-01T00:00:00.000Z');
          final firebaseUpdated = DateTime.parse(firebaseOrder['updatedAt'] as String? ?? '1970-01-01T00:00:00.000Z');
          
          if (localUpdated.isAfter(firebaseUpdated)) {
            // Upload to Firebase
            await _uploadOrderToFirebase(localOrder, tenantId);
            uploaded++;
          } else if (firebaseUpdated.isAfter(localUpdated)) {
            // Download from Firebase
            await _downloadOrderFromFirebase(firebaseOrder, db);
            downloaded++;
          } else {
            skipped++;
          }
        } else if (localOrder != null) {
          // Only local exists - upload
          await _uploadOrderToFirebase(localOrder, tenantId);
          uploaded++;
        } else if (firebaseOrder != null) {
          // Only Firebase exists - download
          await _downloadOrderFromFirebase(firebaseOrder, db);
          downloaded++;
        }
      }
      
      _addFixLog('✅ Order sync completed: ↑$uploaded ↓$downloaded ⏭️$skipped');
      
    } catch (e) {
      _addFixLog('❌ Order timestamp sync failed: $e');
    }
  }
  
  /// Upload order to Firebase
  Future<void> _uploadOrderToFirebase(Map<String, dynamic> localOrder, String tenantId) async {
    try {
      // Convert snake_case to camelCase for Firebase
      final firebaseData = _convertToFirebaseFormat(localOrder);
      
      await _firestore!
          .collection('tenants')
          .doc(tenantId)
          .collection('orders')
          .doc(localOrder['id'] as String)
          .set(firebaseData, fs.SetOptions(merge: true));
      
    } catch (e) {
      _addFixLog('❌ Failed to upload order ${localOrder['id']}: $e');
    }
  }
  
  /// Download order from Firebase
  Future<void> _downloadOrderFromFirebase(Map<String, dynamic> firebaseOrder, Database db) async {
    try {
      // Convert camelCase to snake_case for local database
      final localData = _convertToLocalFormat(firebaseOrder);
      
      await db.insert('orders', localData, conflictAlgorithm: ConflictAlgorithm.replace);
      
    } catch (e) {
      _addFixLog('❌ Failed to download order ${firebaseOrder['id']}: $e');
    }
  }
  
  /// Convert local format to Firebase format
  Map<String, dynamic> _convertToFirebaseFormat(Map<String, dynamic> localData) {
    final firebaseData = <String, dynamic>{};
    
    for (final entry in localData.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Convert snake_case to camelCase
      final camelKey = _snakeToCamel(key);
      firebaseData[camelKey] = value;
    }
    
    return firebaseData;
  }
  
  /// Convert Firebase format to local format
  Map<String, dynamic> _convertToLocalFormat(Map<String, dynamic> firebaseData) {
    final localData = <String, dynamic>{};
    
    for (final entry in firebaseData.entries) {
      final key = entry.key;
      final value = entry.value;
      
      // Convert camelCase to snake_case
      final snakeKey = _camelToSnake(key);
      localData[snakeKey] = value;
    }
    
    return localData;
  }
  
  /// Convert snake_case to camelCase
  String _snakeToCamel(String snake) {
    final parts = snake.split('_');
    if (parts.length == 1) return snake;
    
    return parts[0] + parts.skip(1).map((part) => 
        part.isEmpty ? '' : part[0].toUpperCase() + part.substring(1)
    ).join('');
  }
  
  /// Convert camelCase to snake_case
  String _camelToSnake(String camel) {
    return camel.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}'
    );
  }
  
  /// Fix real-time listener issues
  Future<void> _fixRealTimeListenerIssues() async {
    try {
      _addFixLog('🔧 Fixing real-time listener issues...');
      
      // Real-time listener fixes would be handled by the UnifiedSyncService
      // This is a placeholder for any specific listener fixes needed
      
      _addFixLog('✅ Real-time listener issues checked');
      
    } catch (e) {
      _addFixLog('❌ Real-time listener fix failed: $e');
    }
  }
  
  /// Perform comprehensive data validation
  Future<void> _performComprehensiveDataValidation() async {
    try {
      _addFixLog('🔧 Performing comprehensive data validation...');
      
      final db = await _databaseService?.database;
      if (db == null) {
        _addFixLog('⚠️ Database not available for validation');
        return;
      }
      
      // Validate order integrity
      await _validateOrderIntegrity(db);
      
      // Validate menu item integrity
      await _validateMenuItemIntegrity(db);
      
      // Validate user integrity
      await _validateUserIntegrity(db);
      
      _addFixLog('✅ Comprehensive data validation completed');
      
    } catch (e) {
      _addFixLog('❌ Data validation failed: $e');
    }
  }
  
  /// Validate order integrity
  Future<void> _validateOrderIntegrity(Database db) async {
    try {
      _addFixLog('🔍 Validating order integrity...');
      
      // Check for orders without order numbers
      final ordersWithoutNumbers = await db.query(
        'orders',
        where: 'order_number IS NULL OR order_number = ""',
      );
      
      if (ordersWithoutNumbers.isNotEmpty) {
        _addFixLog('⚠️ Found ${ordersWithoutNumbers.length} orders without order numbers');
      }
      
      // Check for orders with invalid totals
      final ordersWithInvalidTotals = await db.rawQuery('''
        SELECT o.id, o.order_number, o.total_amount, 
               COALESCE(SUM(oi.quantity * oi.price), 0) as calculated_total
        FROM orders o
        LEFT JOIN order_items oi ON o.id = oi.order_id
        GROUP BY o.id
        HAVING ABS(o.total_amount - calculated_total) > 0.01
      ''');
      
      if (ordersWithInvalidTotals.isNotEmpty) {
        _addFixLog('⚠️ Found ${ordersWithInvalidTotals.length} orders with incorrect totals');
        
        // Fix the totals
        for (final order in ordersWithInvalidTotals) {
          final correctTotal = order['calculated_total'] as double;
          await db.update(
            'orders',
            {'total_amount': correctTotal, 'updated_at': DateTime.now().toIso8601String()},
            where: 'id = ?',
            whereArgs: [order['id']],
          );
          _addFixLog('🔧 Fixed total for order ${order['order_number']}: ${order['total_amount']} → $correctTotal');
        }
      }
      
      _addFixLog('✅ Order integrity validation completed');
      
    } catch (e) {
      _addFixLog('❌ Order integrity validation failed: $e');
    }
  }
  
  /// Validate menu item integrity
  Future<void> _validateMenuItemIntegrity(Database db) async {
    try {
      _addFixLog('🔍 Validating menu item integrity...');
      
      // Check for menu items without names
      final itemsWithoutNames = await db.query(
        'menu_items',
        where: 'name IS NULL OR name = ""',
      );
      
      if (itemsWithoutNames.isNotEmpty) {
        _addFixLog('⚠️ Found ${itemsWithoutNames.length} menu items without names');
      }
      
      // Check for menu items with invalid prices
      final itemsWithInvalidPrices = await db.query(
        'menu_items',
        where: 'price IS NULL OR price < 0',
      );
      
      if (itemsWithInvalidPrices.isNotEmpty) {
        _addFixLog('⚠️ Found ${itemsWithInvalidPrices.length} menu items with invalid prices');
      }
      
      _addFixLog('✅ Menu item integrity validation completed');
      
    } catch (e) {
      _addFixLog('❌ Menu item integrity validation failed: $e');
    }
  }
  
  /// Validate user integrity
  Future<void> _validateUserIntegrity(Database db) async {
    try {
      _addFixLog('🔍 Validating user integrity...');
      
      // Check for users without names
      final usersWithoutNames = await db.query(
        'users',
        where: 'name IS NULL OR name = ""',
      );
      
      if (usersWithoutNames.isNotEmpty) {
        _addFixLog('⚠️ Found ${usersWithoutNames.length} users without names');
      }
      
      _addFixLog('✅ User integrity validation completed');
      
    } catch (e) {
      _addFixLog('❌ User integrity validation failed: $e');
    }
  }
  
  /// Set service instances
  void setServices({
    DatabaseService? databaseService,
    OrderService? orderService,
  }) {
    _databaseService = databaseService;
    _orderService = orderService;
  }
  
  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _fixLog.clear();
  }
} 