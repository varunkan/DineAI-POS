import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;
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

/// UNIFIED SYNC SERVICE
/// Single source of truth for all Firebase synchronization
/// Consolidates all sync methods and removes redundancy
class UnifiedSyncService extends ChangeNotifier {
  static UnifiedSyncService? _instance;
  
  // Firebase instances
  late fs.FirebaseFirestore _firestore;
  
  // Service instances
  DatabaseService? _databaseService;
  OrderService? _orderService;
  MenuService? _menuService;
  UserService? _userService;
  InventoryService? _inventoryService;
  TableService? _tableService;
  
  // Current restaurant and session
  Restaurant? _currentRestaurant;
  RestaurantSession? _currentSession;
  
  // Sync state
  bool _isConnected = false;
  bool _isInitialized = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  
  // Connectivity monitoring
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isOnline = true;
  
  // Pending changes for offline sync
  final List<Map<String, dynamic>> _pendingChanges = [];
  
  // Callbacks for UI updates
  Function()? _onOrdersUpdated;
  Function()? _onMenuItemsUpdated;
  Function()? _onUsersUpdated;
  Function()? _onInventoryUpdated;
  Function()? _onTablesUpdated;
  Function(String)? _onSyncProgress;
  Function(String)? _onSyncError;
  
  factory UnifiedSyncService() {
    _instance ??= UnifiedSyncService._internal();
    return _instance!;
  }
  
  UnifiedSyncService._internal();
  
  // Getters
  bool get isConnected => _isConnected;
  bool get isInitialized => _isInitialized;
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
  bool get isOnline => _isOnline;
  
  // Active devices getter for compatibility with old service
  List<String> get activeDevices => ['Current Device']; // Placeholder implementation
  
  /// Initialize the unified sync service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      debugPrint('🚀 Initializing Unified Sync Service...');
      
      // Check if Firebase is initialized
      if (!FirebaseConfig.isInitialized) {
        debugPrint('⚠️ Firebase not initialized - sync will be limited');
        _isInitialized = true;
        return;
      }
      
      _firestore = fs.FirebaseFirestore.instance;
      
      // Enable offline persistence
      _firestore.settings = const fs.Settings(
        persistenceEnabled: true,
        cacheSizeBytes: fs.Settings.CACHE_SIZE_UNLIMITED,
      );
      
      // Start connectivity monitoring
      _startConnectivityMonitoring();
      
      _isInitialized = true;
      debugPrint('✅ Unified Sync Service initialized');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to initialize Unified Sync Service: $e');
      _onSyncError?.call('Failed to initialize: $e');
      _isInitialized = true;
    }
  }
  
  /// Connect to restaurant for sync
  Future<void> connectToRestaurant(Restaurant restaurant, RestaurantSession session) async {
    try {
      debugPrint('🔄 Connecting to restaurant for sync: ${restaurant.email}');
      
      _currentRestaurant = restaurant;
      _currentSession = session;
      
      // Test Firebase connection
      await _testFirebaseConnection();
      
      _isConnected = true;
      _lastSyncTime = DateTime.now();
      
      debugPrint('✅ Connected to restaurant for sync');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to connect to restaurant for sync: $e');
      _isConnected = false;
    }
  }
  
  /// Test Firebase connection
  Future<void> _testFirebaseConnection() async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) {
        throw Exception('No tenant ID available');
      }
      
      debugPrint('🔍 Testing Firebase connection to tenant: $tenantId');
      
      final doc = await _firestore.collection('tenants').doc(tenantId).get();
      debugPrint('✅ Firebase connection test successful - tenant exists: ${doc.exists}');
    } catch (e) {
      debugPrint('❌ Firebase connection test failed: $e');
      rethrow;
    }
  }
  
  /// Start connectivity monitoring
  void _startConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;
      
      if (wasOnline != _isOnline) {
        debugPrint('🌐 Connectivity changed: ${_isOnline ? 'Online' : 'Offline'}');
        notifyListeners();
      }
    });
  }
  
  /// Set service instances
  void setServices({
    DatabaseService? databaseService,
    OrderService? orderService,
    MenuService? menuService,
    UserService? userService,
    InventoryService? inventoryService,
    TableService? tableService,
  }) {
    _databaseService = databaseService ?? _databaseService;
    _orderService = orderService ?? _orderService;
    _menuService = menuService ?? _menuService;
    _userService = userService ?? _userService;
    _inventoryService = inventoryService ?? _inventoryService;
    _tableService = tableService ?? _tableService;
  }
  
  /// Set UI callbacks
  void setCallbacks({
    Function()? onOrdersUpdated,
    Function()? onMenuItemsUpdated,
    Function()? onUsersUpdated,
    Function()? onInventoryUpdated,
    Function()? onTablesUpdated,
    Function(String)? onSyncProgress,
    Function(String)? onSyncError,
  }) {
    _onOrdersUpdated = onOrdersUpdated ?? _onOrdersUpdated;
    _onMenuItemsUpdated = onMenuItemsUpdated ?? _onMenuItemsUpdated;
    _onUsersUpdated = onUsersUpdated ?? _onUsersUpdated;
    _onInventoryUpdated = onInventoryUpdated ?? _onInventoryUpdated;
    _onTablesUpdated = onTablesUpdated ?? _onTablesUpdated;
    _onSyncProgress = onSyncProgress ?? _onSyncProgress;
    _onSyncError = onSyncError ?? _onSyncError;
  }
  
  /// Manual sync trigger (for sync button)
  Future<void> manualSync() async {
    if (!_isConnected || !_isOnline) {
      debugPrint('⚠️ Cannot sync - not connected or offline');
      _onSyncError?.call('Cannot sync - not connected or offline');
      return;
    }
    
    // Prevent multiple simultaneous syncs
    if (_isSyncing) {
      debugPrint('⚠️ Manual sync: Already syncing, skipping duplicate call');
      return;
    }
    
    _isSyncing = true;
    _onSyncProgress?.call('Starting manual sync...');
    
    try {
      debugPrint('🔄 Manual sync triggered...');
      
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) {
        throw Exception('No tenant ID available for sync');
      }
      
      // Sync orders first (most important)
      if (_orderService != null) {
        _onSyncProgress?.call('Syncing orders...');
        await _orderService!.syncOrdersWithFirebase();
        _onOrdersUpdated?.call();
      }
      
      // Sync other data types
      await Future.wait([
        _syncMenuItems(tenantId),
        _syncUsers(tenantId),
        _syncInventory(tenantId),
        _syncTables(tenantId),
      ]);
      
      _lastSyncTime = DateTime.now();
      _onSyncProgress?.call('Manual sync completed successfully');
      debugPrint('✅ Manual sync completed');
    } catch (e) {
      debugPrint('❌ Manual sync failed: $e');
      _onSyncError?.call('Manual sync failed: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  /// Sync menu items
  Future<void> _syncMenuItems(String tenantId) async {
    try {
      if (_menuService == null) return;
      
      final snapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('menu_items')
          .get();
      
      for (final doc in snapshot.docs) {
        try {
          final menuItemData = doc.data();
          final menuItem = MenuItem.fromJson(menuItemData);
          await _menuService!.updateMenuItemFromFirebase(menuItem);
        } catch (e) {
          debugPrint('⚠️ Failed to sync menu item ${doc.id}: $e');
        }
      }
      
      _onMenuItemsUpdated?.call();
      debugPrint('✅ Synced ${snapshot.docs.length} menu items');
    } catch (e) {
      debugPrint('❌ Failed to sync menu items: $e');
    }
  }
  
  /// Sync users
  Future<void> _syncUsers(String tenantId) async {
    try {
      if (_userService == null) return;
      
      final snapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('users')
          .get();
      
      for (final doc in snapshot.docs) {
        try {
          final userData = doc.data();
          final user = User.fromJson(userData);
          await _userService!.updateUserFromFirebase(user);
        } catch (e) {
          debugPrint('⚠️ Failed to sync user ${doc.id}: $e');
        }
      }
      
      _onUsersUpdated?.call();
      debugPrint('✅ Synced ${snapshot.docs.length} users');
    } catch (e) {
      debugPrint('❌ Failed to sync users: $e');
    }
  }
  
  /// Sync inventory
  Future<void> _syncInventory(String tenantId) async {
    try {
      if (_inventoryService == null) return;
      
      final snapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('inventory')
          .get();
      
      for (final doc in snapshot.docs) {
        try {
          final inventoryData = doc.data();
          final inventoryItem = InventoryItem.fromJson(inventoryData);
          await _inventoryService!.updateItemFromFirebase(inventoryItem);
        } catch (e) {
          debugPrint('⚠️ Failed to sync inventory item ${doc.id}: $e');
        }
      }
      
      _onInventoryUpdated?.call();
      debugPrint('✅ Synced ${snapshot.docs.length} inventory items');
    } catch (e) {
      debugPrint('❌ Failed to sync inventory: $e');
    }
  }
  
  /// Sync tables
  Future<void> _syncTables(String tenantId) async {
    try {
      if (_tableService == null) return;
      
      final snapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('tables')
          .get();
      
      for (final doc in snapshot.docs) {
        try {
          final tableData = doc.data();
          final table = Table.fromJson(tableData);
          await _tableService!.updateTableFromFirebase(table);
        } catch (e) {
          debugPrint('⚠️ Failed to sync table ${doc.id}: $e');
        }
      }
      
      _onTablesUpdated?.call();
      debugPrint('✅ Synced ${snapshot.docs.length} tables');
    } catch (e) {
      debugPrint('❌ Failed to sync tables: $e');
    }
  }
  
  /// Force sync from Firebase (download only)
  Future<void> forceSyncFromFirebase() async {
    if (!_isConnected || !_isOnline) {
      debugPrint('⚠️ Cannot force sync - not connected or offline');
      return;
    }
    
    if (_isSyncing) {
      debugPrint('⚠️ Force sync: Already syncing, skipping duplicate call');
      return;
    }
    
    _isSyncing = true;
    _onSyncProgress?.call('Force syncing from Firebase...');
    
    try {
      debugPrint('🔄 Force syncing from Firebase...');
      
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) {
        throw Exception('No tenant ID available for sync');
      }
      
      // Force sync orders
      if (_orderService != null) {
        _onSyncProgress?.call('Force syncing orders...');
        await _orderService!.forceSyncFromFirebase();
        _onOrdersUpdated?.call();
      }
      
      // Force sync other data types
      await Future.wait([
        _syncMenuItems(tenantId),
        _syncUsers(tenantId),
        _syncInventory(tenantId),
        _syncTables(tenantId),
      ]);
      
      _lastSyncTime = DateTime.now();
      _onSyncProgress?.call('Force sync completed successfully');
      debugPrint('✅ Force sync completed');
    } catch (e) {
      debugPrint('❌ Force sync failed: $e');
      _onSyncError?.call('Force sync failed: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  /// Disconnect from current restaurant
  Future<void> disconnect() async {
    try {
      debugPrint('🔄 Disconnecting from restaurant...');
      
      _currentRestaurant = null;
      _currentSession = null;
      _isConnected = false;
      
      debugPrint('✅ Disconnected from restaurant');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to disconnect: $e');
    }
  }

  // ===== COMPATIBILITY METHODS FOR OLD SERVICE =====
  
  /// Create or update user in Firebase
  Future<void> createOrUpdateUser(User user) async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) throw Exception('No tenant ID available');
      
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('users')
          .doc(user.id)
          .set(user.toJson(), fs.SetOptions(merge: true));
      
      debugPrint('✅ User synced to Firebase: ${user.name}');
    } catch (e) {
      debugPrint('❌ Failed to sync user to Firebase: $e');
      rethrow;
    }
  }
  
  /// Create or update order in Firebase
  Future<void> createOrUpdateOrder(pos_order.Order order) async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) throw Exception('No tenant ID available');
      
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('orders')
          .doc(order.id)
          .set(order.toJson(), fs.SetOptions(merge: true));
      
      debugPrint('✅ Order synced to Firebase: ${order.orderNumber}');
    } catch (e) {
      debugPrint('❌ Failed to sync order to Firebase: $e');
      rethrow;
    }
  }
  
  /// Create or update menu item in Firebase
  Future<void> createOrUpdateMenuItem(MenuItem item) async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) throw Exception('No tenant ID available');
      
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('menu_items')
          .doc(item.id)
          .set(item.toJson(), fs.SetOptions(merge: true));
      
      debugPrint('✅ Menu item synced to Firebase: ${item.name}');
    } catch (e) {
      debugPrint('❌ Failed to sync menu item to Firebase: $e');
      rethrow;
    }
  }
  
  /// Create or update category in Firebase
  Future<void> createOrUpdateCategory(pos_category.Category category) async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) throw Exception('No tenant ID available');
      
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('categories')
          .doc(category.id)
          .set(category.toJson(), fs.SetOptions(merge: true));
      
      debugPrint('✅ Category synced to Firebase: ${category.name}');
    } catch (e) {
      debugPrint('❌ Failed to sync category to Firebase: $e');
      rethrow;
    }
  }
  
  /// Create or update inventory item in Firebase
  Future<void> createOrUpdateInventoryItem(InventoryItem item) async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) throw Exception('No tenant ID available');
      
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('inventory')
          .doc(item.id)
          .set(item.toJson(), fs.SetOptions(merge: true));
      
      debugPrint('✅ Inventory item synced to Firebase: ${item.name}');
    } catch (e) {
      debugPrint('❌ Failed to sync inventory item to Firebase: $e');
      rethrow;
    }
  }
  
  /// Delete item from Firebase
  Future<void> deleteItem(String collection, String itemId) async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) throw Exception('No tenant ID available');
      
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection(collection)
          .doc(itemId)
          .delete();
      
      debugPrint('✅ Item deleted from Firebase: $collection/$itemId');
    } catch (e) {
      debugPrint('❌ Failed to delete item from Firebase: $e');
      rethrow;
    }
  }
  
  /// Add pending sync change for later processing
  void addPendingSyncChange(String collection, String action, String itemId, Map<String, dynamic> data) {
    try {
      final change = {
        'collection': collection,
        'action': action,
        'itemId': itemId,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      _pendingChanges.add(change);
      debugPrint('📝 Added pending sync change: $collection/$action/$itemId');
    } catch (e) {
      debugPrint('❌ Failed to add pending sync change: $e');
    }
  }
  
  /// Process pending sync changes
  Future<void> processPendingChanges() async {
    if (_pendingChanges.isEmpty) return;
    
    try {
      debugPrint('🔄 Processing ${_pendingChanges.length} pending sync changes...');
      
      final changes = List<Map<String, dynamic>>.from(_pendingChanges);
      _pendingChanges.clear();
      
      for (final change in changes) {
        try {
          final collection = change['collection'] as String;
          final action = change['action'] as String;
          final itemId = change['itemId'] as String;
          final data = change['data'] as Map<String, dynamic>;
          
          final tenantId = FirebaseConfig.getCurrentTenantId();
          if (tenantId == null) continue;
          
          final docRef = _firestore
              .collection('tenants')
              .doc(tenantId)
              .collection(collection)
              .doc(itemId);
          
          if (action == 'deleted') {
            await docRef.delete();
          } else {
            await docRef.set(data, fs.SetOptions(merge: true));
          }
          
          debugPrint('✅ Processed pending change: $collection/$action/$itemId');
        } catch (e) {
          debugPrint('⚠️ Failed to process pending change: $e');
          // Re-add to pending changes for later retry
          _pendingChanges.add(change);
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to process pending changes: $e');
    }
  }

  // ===== INDIVIDUAL SYNC METHODS =====
  
  /// Sync order to Firebase
  Future<void> syncOrderToFirebase(pos_order.Order order, String action) async {
    try {
      if (action == 'deleted') {
        await deleteItem('orders', order.id);
      } else {
        await createOrUpdateOrder(order);
      }
      debugPrint('✅ Order synced to Firebase: ${order.orderNumber} ($action)');
    } catch (e) {
      debugPrint('❌ Failed to sync order to Firebase: $e');
      rethrow;
    }
  }
  
  /// Sync order item to Firebase
  Future<void> syncOrderItemToFirebase(Map<String, dynamic> itemMap) async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) throw Exception('No tenant ID available');
      
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('order_items')
          .doc(itemMap['id'] as String)
          .set(itemMap, fs.SetOptions(merge: true));
      
      debugPrint('✅ Order item synced to Firebase: ${itemMap['id']}');
    } catch (e) {
      debugPrint('❌ Failed to sync order item to Firebase: $e');
      rethrow;
    }
  }
  
  /// Sync user to Firebase
  Future<void> syncUserToFirebase(User user, String action) async {
    try {
      if (action == 'deleted') {
        await deleteItem('users', user.id);
      } else {
        await createOrUpdateUser(user);
      }
      debugPrint('✅ User synced to Firebase: ${user.name} ($action)');
    } catch (e) {
      debugPrint('❌ Failed to sync user to Firebase: $e');
      rethrow;
    }
  }
  
  /// Sync menu item to Firebase
  Future<void> syncMenuItemToFirebase(MenuItem item, String action) async {
    try {
      if (action == 'deleted') {
        await deleteItem('menu_items', item.id);
      } else {
        await createOrUpdateMenuItem(item);
      }
      debugPrint('✅ Menu item synced to Firebase: ${item.name} ($action)');
    } catch (e) {
      debugPrint('❌ Failed to sync menu item to Firebase: $e');
      rethrow;
    }
  }
  
  /// Sync category to Firebase
  Future<void> syncCategoryToFirebase(pos_category.Category category, String action) async {
    try {
      if (action == 'deleted') {
        await deleteItem('categories', category.id);
      } else {
        await createOrUpdateCategory(category);
      }
      debugPrint('✅ Category synced to Firebase: ${category.name} ($action)');
    } catch (e) {
      debugPrint('❌ Failed to sync category to Firebase: $e');
      rethrow;
    }
  }
  
  /// Sync inventory item to Firebase
  Future<void> syncInventoryItemToFirebase(InventoryItem item, String action) async {
    try {
      if (action == 'deleted') {
        await deleteItem('inventory', item.id);
      } else {
        await createOrUpdateInventoryItem(item);
      }
      debugPrint('✅ Inventory item synced to Firebase: ${item.name} ($action)');
    } catch (e) {
      debugPrint('❌ Failed to sync inventory item to Firebase: $e');
      rethrow;
    }
  }
  
  /// Sync table to Firebase
  Future<void> syncTableToFirebase(Table table, String action) async {
    try {
      if (action == 'deleted') {
        await deleteItem('tables', table.id);
      } else {
        final tenantId = FirebaseConfig.getCurrentTenantId();
        if (tenantId == null) throw Exception('No tenant ID available');
        
        await _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('tables')
            .doc(table.id)
            .set(table.toJson(), fs.SetOptions(merge: true));
      }
      debugPrint('✅ Table synced to Firebase: ${table.number} ($action)');
    } catch (e) {
      debugPrint('❌ Failed to sync table to Firebase: $e');
      rethrow;
    }
  }
  
  // ===== ADDITIONAL METHODS FOR COMPATIBILITY =====
  
  /// Force sync all local data to Firebase
  Future<void> forceSyncAllLocalData() async {
    try {
      debugPrint('🔄 Force syncing all local data to Firebase...');
      await manualSync();
      debugPrint('✅ Force sync completed');
    } catch (e) {
      debugPrint('❌ Force sync failed: $e');
      rethrow;
    }
  }
  
  /// Trigger immediate sync
  Future<void> triggerImmediateSync() async {
    try {
      debugPrint('🔄 Triggering immediate sync...');
      await manualSync();
      debugPrint('✅ Immediate sync completed');
    } catch (e) {
      debugPrint('❌ Immediate sync failed: $e');
      rethrow;
    }
  }
  
  /// Download data from cloud
  Future<void> downloadFromCloud() async {
    try {
      debugPrint('🔄 Downloading data from cloud...');
      await manualSync();
      debugPrint('✅ Download from cloud completed');
    } catch (e) {
      debugPrint('❌ Download from cloud failed: $e');
      rethrow;
    }
  }
  
  /// Clear and sync data
  Future<void> clearAndSyncData() async {
    try {
      debugPrint('🔄 Clearing and syncing data...');
      // Clear local data first
      final db = await _databaseService?.database;
      if (db != null) {
        await db.delete('orders');
        await db.delete('menu_items');
        await db.delete('users');
        await db.delete('categories');
        await db.delete('inventory');
        await db.delete('tables');
      }
      // Then sync from Firebase
      await manualSync();
      debugPrint('✅ Clear and sync completed');
    } catch (e) {
      debugPrint('❌ Clear and sync failed: $e');
      rethrow;
    }
  }
  
  /// Upload data to cloud
  Future<void> uploadToCloud() async {
    try {
      debugPrint('🔄 Uploading data to cloud...');
      await manualSync();
      debugPrint('✅ Upload to cloud completed');
    } catch (e) {
      debugPrint('❌ Upload to cloud failed: $e');
      rethrow;
    }
  }
  
  /// Perform full sync (alias for manualSync)
  Future<void> performFullSync() async {
    try {
      debugPrint('🔄 Performing full sync...');
      await manualSync();
      debugPrint('✅ Full sync completed');
    } catch (e) {
      debugPrint('❌ Full sync failed: $e');
      rethrow;
    }
  }
  
  /// Trigger instant sync (alias for manualSync)
  Future<void> triggerInstantSync() async {
    try {
      debugPrint('🔄 Triggering instant sync...');
      await manualSync();
      debugPrint('✅ Instant sync completed');
    } catch (e) {
      debugPrint('❌ Instant sync failed: $e');
      rethrow;
    }
  }
  
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
} 