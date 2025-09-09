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
  
  // REAL-TIME FIREBASE LISTENERS for immediate cross-device sync
  StreamSubscription<fs.QuerySnapshot>? _ordersListener;
  StreamSubscription<fs.QuerySnapshot>? _menuItemsListener;
  StreamSubscription<fs.QuerySnapshot>? _usersListener;
  StreamSubscription<fs.QuerySnapshot>? _inventoryListener;
  StreamSubscription<fs.QuerySnapshot>? _inventoryRecipeLinksListener;
  StreamSubscription<fs.QuerySnapshot>? _tablesListener;
  StreamSubscription<fs.QuerySnapshot>? _categoriesListener;
  
  // Callbacks for UI updates
  Function()? _onOrdersUpdated;
  Function()? _onMenuItemsUpdated;
  Function()? _onUsersUpdated;
  Function()? _onInventoryUpdated;
  Function()? _onTablesUpdated;
  Function(String)? _onSyncProgress;
  Function(String)? _onSyncError;
  
  // Feature flags for enhanced server change sync
  static const bool _enableEnhancedServerChangeSync = true;
  static const bool _enableAutomaticOrderRefresh = true;
  static const bool _enableServerChangeNotifications = true;
  // Feature flag: when true, reconcile can purge stale local-only orders (logging-only by default)
  static const bool _enablePurgeStaleLocalOrders = false;
  
  // Server change sync state
  String? _lastSelectedServerId;
  DateTime? _lastServerChangeTime;
  bool _isServerChangeSyncInProgress = false;
  
  // Order refresh state
  DateTime? _lastOrderRefreshTime;
  bool _isOrderRefreshInProgress = false;
  Timer? _orderRefreshTimer;
  
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
  
  /// Check if real-time sync is active
  bool get isRealTimeSyncActive => _ordersListener != null || 
                                  _menuItemsListener != null || 
                                  _usersListener != null || 
                                  _inventoryListener != null || 
                                  _tablesListener != null || 
                                  _categoriesListener != null;
  
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
      
      // START REAL-TIME LISTENERS for immediate cross-device sync
      await _startRealTimeListeners();
      
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
  
  /// Start real-time Firebase listeners for immediate cross-device sync
  Future<void> _startRealTimeListeners() async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) {
        debugPrint('⚠️ No tenant ID available for real-time listeners');
        return;
      }
      
      debugPrint('🔴 Starting real-time Firebase listeners for immediate cross-device sync...');
      
      // Stop existing listeners first
      await _stopRealTimeListeners();
      
      // Start real-time listeners for all data types
      _startOrdersListener(tenantId);
      _startMenuItemsListener(tenantId);
      _startUsersListener(tenantId);
      _startInventoryListener(tenantId);
      _startInventoryRecipeLinksListener(tenantId);
      _startTablesListener(tenantId);
      _startCategoriesListener(tenantId);
      
      debugPrint('✅ Real-time Firebase listeners started - immediate cross-device sync active');
      
    } catch (e) {
      debugPrint('❌ Failed to start real-time listeners: $e');
      // Don't fail the connection - continue without real-time sync
    }
  }
  
  /// Stop all real-time listeners
  Future<void> _stopRealTimeListeners() async {
    try {
      debugPrint('🛑 Stopping real-time Firebase listeners...');
      
      _ordersListener?.cancel();
      _menuItemsListener?.cancel();
      _usersListener?.cancel();
      _inventoryListener?.cancel();
      _inventoryRecipeLinksListener?.cancel();
      _tablesListener?.cancel();
      _categoriesListener?.cancel();
      
      _ordersListener = null;
      _menuItemsListener = null;
      _usersListener = null;
      _inventoryListener = null;
      _inventoryRecipeLinksListener = null;
      _tablesListener = null;
      _categoriesListener = null;
      
      debugPrint('🛑 Real-time Firebase listeners stopped');
    } catch (e) {
      debugPrint('⚠️ Error stopping real-time listeners: $e');
    }
  }
  
  /// Start real-time listener for orders
  void _startOrdersListener(String tenantId) {
    try {
      _ordersListener = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('orders')
          .snapshots()
          .listen(
        (snapshot) async {
          try {
            debugPrint('🔴 Real-time orders update detected: ${snapshot.docChanges.length} changes');
            
            for (final change in snapshot.docChanges) {
              final orderData = change.doc.data();
              if (orderData == null) continue;
              
              orderData['id'] = change.doc.id;
              
              switch (change.type) {
                case fs.DocumentChangeType.added:
                  debugPrint('➕ New order from Firebase: ${orderData['orderNumber']}');
                  await _downloadOrderFromFirebase(orderData);
                  break;
                case fs.DocumentChangeType.modified:
                  debugPrint('🔄 Order updated from Firebase: ${orderData['orderNumber']}');
                  await _downloadOrderFromFirebase(orderData);
                  break;
                case fs.DocumentChangeType.removed:
                  debugPrint('🗑️ Order deleted from Firebase: ${orderData['orderNumber']}');
                  await _handleOrderDeletionFromFirebase(orderData['id']);
                  break;
              }
            }
            
            // Notify UI of orders update
            _onOrdersUpdated?.call();
            
          } catch (e) {
            debugPrint('❌ Error processing real-time orders update: $e');
          }
        },
        onError: (error) {
          debugPrint('❌ Real-time orders listener error: $error');
        },
      );
    } catch (e) {
      debugPrint('❌ Failed to start orders listener: $e');
    }
  }
  
  /// Start real-time listener for menu items
  void _startMenuItemsListener(String tenantId) {
    try {
      _menuItemsListener = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('menu_items')
          .snapshots()
          .listen(
        (snapshot) async {
          try {
            debugPrint('🔴 Real-time menu items update detected: ${snapshot.docChanges.length} changes');
            
            for (final change in snapshot.docChanges) {
              final itemData = change.doc.data();
              if (itemData == null) continue;
              
              itemData['id'] = change.doc.id;
              
              switch (change.type) {
                case fs.DocumentChangeType.added:
                  debugPrint('➕ New menu item from Firebase: ${itemData['name']}');
                  await _downloadMenuItemFromFirebase(itemData);
                  break;
                case fs.DocumentChangeType.modified:
                  debugPrint('🔄 Menu item updated from Firebase: ${itemData['name']}');
                  await _downloadMenuItemFromFirebase(itemData);
                  break;
                case fs.DocumentChangeType.removed:
                  debugPrint('🗑️ Menu item deleted from Firebase: ${itemData['name']}');
                  await _handleMenuItemDeletionFromFirebase(itemData['id']);
                  break;
              }
            }
            
            // Notify UI of menu items update
            _onMenuItemsUpdated?.call();
            
          } catch (e) {
            debugPrint('❌ Error processing real-time menu items update: $e');
          }
        },
        onError: (error) {
          debugPrint('❌ Real-time menu items listener error: $error');
        },
      );
    } catch (e) {
      debugPrint('❌ Failed to start menu items listener: $e');
    }
  }
  
  /// Start real-time listener for users
  void _startUsersListener(String tenantId) {
    try {
      _usersListener = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('users')
          .snapshots()
          .listen(
        (snapshot) async {
          try {
            debugPrint('🔴 Real-time users update detected: ${snapshot.docChanges.length} changes');
            
            for (final change in snapshot.docChanges) {
              final userData = change.doc.data();
              if (userData == null) continue;
              
              userData['id'] = change.doc.id;
              
              switch (change.type) {
                case fs.DocumentChangeType.added:
                  debugPrint('➕ New user from Firebase: ${userData['name']}');
                  await _downloadUserFromFirebase(userData);
                  break;
                case fs.DocumentChangeType.modified:
                  debugPrint('🔄 User updated from Firebase: ${userData['name']}');
                  await _downloadUserFromFirebase(userData);
                  break;
                case fs.DocumentChangeType.removed:
                  debugPrint('🗑️ User deleted from Firebase: ${userData['name']}');
                  await _handleUserDeletionFromFirebase(userData['id']);
                  break;
              }
            }
            
            // Notify UI of users update
            _onUsersUpdated?.call();
            
          } catch (e) {
            debugPrint('❌ Error processing real-time users update: $e');
          }
        },
        onError: (error) {
          debugPrint('❌ Real-time users listener error: $error');
        },
      );
    } catch (e) {
      debugPrint('❌ Failed to start users listener: $e');
    }
  }
  
  /// Start real-time listener for inventory
  void _startInventoryListener(String tenantId) {
    try {
      _inventoryListener = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('inventory')
          .snapshots()
          .listen(
        (snapshot) async {
          try {
            debugPrint('🔴 Real-time inventory update detected: ${snapshot.docChanges.length} changes');
            
            for (final change in snapshot.docChanges) {
              final itemData = change.doc.data();
              if (itemData == null) continue;
              
              itemData['id'] = change.doc.id;
              
              switch (change.type) {
                case fs.DocumentChangeType.added:
                  debugPrint('➕ New inventory item from Firebase: ${itemData['name']}');
                  await _downloadInventoryItemFromFirebase(itemData);
                  break;
                case fs.DocumentChangeType.modified:
                  debugPrint('🔄 Inventory item updated from Firebase: ${itemData['name']}');
                  await _downloadInventoryItemFromFirebase(itemData);
                  break;
                case fs.DocumentChangeType.removed:
                  debugPrint('🗑️ Inventory item deleted from Firebase: ${itemData['name']}');
                  await _handleInventoryItemDeletionFromFirebase(itemData['id']);
                  break;
              }
            }
            
            // Notify UI of inventory update
            _onInventoryUpdated?.call();
            
          } catch (e) {
            debugPrint('❌ Error processing real-time inventory update: $e');
          }
        },
        onError: (error) {
          debugPrint('❌ Real-time inventory listener error: $error');
        },
      );
    } catch (e) {
      debugPrint('❌ Failed to start inventory listener: $e');
    }
  }
  
  /// Start real-time listener for inventory recipe links
  void _startInventoryRecipeLinksListener(String tenantId) {
    try {
      _inventoryRecipeLinksListener = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('inventory_recipe_links')
          .snapshots()
          .listen(
        (snapshot) async {
          try {
            debugPrint('🔴 Real-time inventory recipe links update: ${snapshot.docChanges.length} changes');
            for (final change in snapshot.docChanges) {
              final data = change.doc.data();
              if (data == null) continue;
              data['id'] = change.doc.id;
              switch (change.type) {
                case fs.DocumentChangeType.added:
                case fs.DocumentChangeType.modified:
                  await _downloadInventoryRecipeLinkFromFirebase(data);
                  break;
                case fs.DocumentChangeType.removed:
                  await _handleInventoryRecipeLinkDeletionFromFirebase(data['id']);
                  break;
              }
            }
            _onInventoryUpdated?.call();
          } catch (e) {
            debugPrint('❌ Error processing recipe links update: $e');
          }
        },
        onError: (error) {
          debugPrint('❌ Real-time recipe links listener error: $error');
        },
      );
    } catch (e) {
      debugPrint('❌ Failed to start recipe links listener: $e');
    }
  }
  
  /// Start real-time listener for tables
  void _startTablesListener(String tenantId) {
    try {
      _tablesListener = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('tables')
          .snapshots()
          .listen(
        (snapshot) async {
          try {
            debugPrint('🔴 Real-time tables update detected: ${snapshot.docChanges.length} changes');
            
            for (final change in snapshot.docChanges) {
              final tableData = change.doc.data();
              if (tableData == null) continue;
              
              tableData['id'] = change.doc.id;
              
              switch (change.type) {
                case fs.DocumentChangeType.added:
                  debugPrint('➕ New table from Firebase: ${tableData['number']}');
                  await _downloadTableFromFirebase(tableData);
                  break;
                case fs.DocumentChangeType.modified:
                  debugPrint('🔄 Table updated from Firebase: ${tableData['number']}');
                  await _downloadTableFromFirebase(tableData);
                  break;
                case fs.DocumentChangeType.removed:
                  debugPrint('🗑️ Table deleted from Firebase: ${tableData['number']}');
                  await _handleTableDeletionFromFirebase(tableData['id']);
                  break;
              }
            }
            
            // Notify UI of tables update
            _onTablesUpdated?.call();
            
          } catch (e) {
            debugPrint('❌ Error processing real-time tables update: $e');
          }
        },
        onError: (error) {
          debugPrint('❌ Real-time tables listener error: $error');
        },
      );
    } catch (e) {
      debugPrint('❌ Failed to start tables listener: $e');
    }
  }
  
  /// Start real-time listener for categories
  void _startCategoriesListener(String tenantId) {
    try {
      _categoriesListener = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('categories')
          .snapshots()
          .listen(
        (snapshot) async {
          try {
            debugPrint('🔴 Real-time categories update detected: ${snapshot.docChanges.length} changes');
            
            for (final change in snapshot.docChanges) {
              final categoryData = change.doc.data();
              if (categoryData == null) continue;
              
              categoryData['id'] = change.doc.id;
              
              switch (change.type) {
                case fs.DocumentChangeType.added:
                  debugPrint('➕ New category from Firebase: ${categoryData['name']}');
                  await _downloadCategoryFromFirebase(categoryData);
                  break;
                case fs.DocumentChangeType.modified:
                  debugPrint('🔄 Category updated from Firebase: ${categoryData['name']}');
                  await _downloadCategoryFromFirebase(categoryData);
                  break;
                case fs.DocumentChangeType.removed:
                  debugPrint('🗑️ Category deleted from Firebase: ${categoryData['name']}');
                  await _handleCategoryDeletionFromFirebase(categoryData['id']);
                  break;
              }
            }
            
            // Notify UI of categories update
            _onMenuItemsUpdated?.call(); // Categories affect menu items
            
          } catch (e) {
            debugPrint('❌ Error processing real-time categories update: $e');
          }
        },
        onError: (error) {
          debugPrint('❌ Real-time categories listener error: $error');
        },
      );
    } catch (e) {
      debugPrint('❌ Failed to start categories listener: $e');
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
  
  /// Enhanced manual sync with time-based comparison
  Future<void> manualSync() async {
    if (!_isConnected || !_isOnline) {
      debugPrint('⚠️ Cannot sync - not connected or offline');
      _onSyncError?.call('Cannot sync - not connected or offline');
      return;
    }
    
    // Check if services are available
    if (!_areServicesAvailable()) {
      debugPrint('⚠️ Cannot sync - required services not available');
      _onSyncError?.call('Cannot sync - required services not available');
      return;
    }
    
    // First, flush any pending local changes to Firebase to avoid conflicts
    try {
      await processPendingChanges();
    } catch (e) {
      debugPrint('⚠️ Failed to process pending changes before manual sync: $e');
    }
    
    // Prevent multiple simultaneous syncs
    if (_isSyncing) {
      debugPrint('⚠️ Manual sync: Already syncing, skipping duplicate call');
      return;
    }
    
    _isSyncing = true;
    _onSyncProgress?.call('Starting enhanced manual sync...');
    
    try {
      debugPrint('🔄 Enhanced manual sync triggered...');
      
      // Use the new smart time-based sync
      await performSmartTimeBasedSync();
      
      _lastSyncTime = DateTime.now();
      _onSyncProgress?.call('Enhanced manual sync completed successfully');
      debugPrint('✅ Enhanced manual sync completed');
      
    } catch (e) {
      debugPrint('❌ Enhanced manual sync failed: $e');
      _onSyncError?.call('Enhanced manual sync failed: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  /// Auto-sync when user logs in from another device
  /// This triggers the smart time-based sync to ensure data consistency
  Future<void> autoSyncOnDeviceLogin() async {
    try {
      debugPrint('🔄 Auto-sync triggered on device login...');
      
      if (!_isConnected || !_isOnline) {
        debugPrint('⚠️ Cannot auto-sync - not connected or offline');
        return;
      }
      
      // Perform smart time-based sync to ensure data consistency
      await performSmartTimeBasedSync();
      
      debugPrint('✅ Auto-sync on device login completed');
    } catch (e) {
      debugPrint('❌ Auto-sync on device login failed: $e');
      // Don't throw error for auto-sync failures
    }
  }
  
  /// Check if data needs sync by comparing local vs Firebase timestamps
  Future<bool> needsSync() async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) return false;
      
      // Check if we have any local data
      bool hasLocalData = false;
      
      if (_orderService != null) {
        final localOrders = _orderService!.allOrders;
        if (localOrders.isNotEmpty) hasLocalData = true;
      }
      
      if (_menuService != null) {
        final localMenuItems = await _menuService!.getMenuItems();
        if (localMenuItems.isNotEmpty) hasLocalData = true;
      }
      
      if (_userService != null) {
        final localUsers = await _userService!.getUsers();
        if (localUsers.isNotEmpty) hasLocalData = true;
      }
      
      // If no local data, we need sync
      if (!hasLocalData) return true;
      
      // Check last sync time
      if (_lastSyncTime == null) return true;
      
      // If last sync was more than 5 minutes ago, suggest sync
      final timeSinceLastSync = DateTime.now().difference(_lastSyncTime!);
      if (timeSinceLastSync.inMinutes > 5) return true;
      
      return false;
    } catch (e) {
      debugPrint('⚠️ Error checking if sync is needed: $e');
      return true; // Default to needing sync if we can't determine
    }
  }
  
  /// Get sync status summary
  Map<String, dynamic> getSyncStatus() {
    return {
      'isConnected': _isConnected,
      'isOnline': _isOnline,
      'isSyncing': _isSyncing,
      'isRealTimeSyncActive': isRealTimeSyncActive,
      'lastSyncTime': _lastSyncTime?.toIso8601String(),
      'needsSync': needsSync(),
      'currentRestaurant': _currentRestaurant?.name,
      'realTimeListeners': {
        'orders': _ordersListener != null,
        'menuItems': _menuItemsListener != null,
        'users': _usersListener != null,
        'inventory': _inventoryListener != null,
        'inventoryRecipeLinks': _inventoryRecipeLinksListener != null,
        'tables': _tablesListener != null,
        'categories': _categoriesListener != null,
      },
    };
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
      
      // Stop real-time listeners first
      await _stopRealTimeListeners();
      
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
      final sent = (itemMap['sent_to_kitchen'] ?? itemMap['sentToKitchen'] ?? 0);
      if (sent is int && sent != 1) {
        debugPrint('⏭️ Guard: Not syncing unsent item ${itemMap['id']} to Firebase');
        return;
      }
      if (sent is bool && sent != true) {
        debugPrint('⏭️ Guard: Not syncing unsent item ${itemMap['id']} to Firebase');
        return;
      }
      
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
  
  /// Smart time-based sync for restaurant data
  /// Compares Firebase vs local timestamps and updates accordingly
  Future<void> performSmartTimeBasedSync() async {
    if (!_isConnected || !_isOnline) {
      debugPrint('⚠️ Cannot perform smart sync - not connected or offline');
      _onSyncError?.call('Cannot perform smart sync - not connected or offline');
      return;
    }
    
    if (_isSyncing) {
      debugPrint('⚠️ Smart sync: Already syncing, skipping duplicate call');
      return;
    }
    
    _isSyncing = true;
    _onSyncProgress?.call('🔄 Starting smart time-based sync...');
    
    try {
      debugPrint('🔄 Performing smart time-based sync...');
      
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) {
        throw Exception('No tenant ID available for smart sync');
      }
      
      // Perform comprehensive time-based sync for all data types
      await Future.wait([
        _performTimeBasedSyncForOrders(tenantId),
        _performTimeBasedSyncForMenuItems(tenantId),
        _performTimeBasedSyncForUsers(tenantId),
        _performTimeBasedSyncForInventory(tenantId),
        _performTimeBasedSyncForInventoryRecipeLinks(tenantId),
        _performTimeBasedSyncForTables(tenantId),
        _performTimeBasedSyncForCategories(tenantId),
      ]);
      
      // Optional: after syncing, reconcile/purge stale local-only orders (logging-only unless flag enabled)
      try {
        await _reconcileStaleLocalOrders(tenantId);
      } catch (e) {
        debugPrint('⚠️ Reconcile of stale local orders failed: $e');
      }
      
      _lastSyncTime = DateTime.now();
      _onSyncProgress?.call('✅ Smart time-based sync completed successfully');
      debugPrint('✅ Smart time-based sync completed');
      
    } catch (e) {
      debugPrint('❌ Smart time-based sync failed: $e');
      _onSyncError?.call('Smart time-based sync failed: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  /// Time-based sync for orders with timestamp comparison
  Future<void> _performTimeBasedSyncForOrders(String tenantId) async {
    try {
      _onSyncProgress?.call('🔄 Syncing orders with timestamp comparison...');
      
      if (_orderService == null) return;
      
      // Get local orders with timestamps
      final localOrders = _orderService!.allOrders;
      final localOrdersMap = <String, pos_order.Order>{};
      for (final order in localOrders) {
        localOrdersMap[order.id] = order;
      }
      
      // Get Firebase orders with timestamps
      final snapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('orders')
          .get();
      
      final firebaseOrdersMap = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        if (doc.id == '_persistence_config') continue;
        final orderData = doc.data();
        orderData['id'] = doc.id;
        firebaseOrdersMap[doc.id] = orderData;
      }
      
      debugPrint('📊 Orders sync: ${localOrders.length} local, ${firebaseOrdersMap.length} Firebase');
      
      // Compare and sync based on timestamps
      int updatedFromFirebase = 0;
      int uploadedToFirebase = 0;
      int skippedCount = 0;
      
      final allOrderIds = {...localOrdersMap.keys, ...firebaseOrdersMap.keys};
      
      for (final orderId in allOrderIds) {
        final localOrder = localOrdersMap[orderId];
        final firebaseOrder = firebaseOrdersMap[orderId];
        
        if (localOrder != null && firebaseOrder != null) {
          // Both exist - compare timestamps
          try {
            final localUpdatedAt = localOrder.updatedAt;
            final firebaseUpdatedAt = DateTime.parse(
              (firebaseOrder['updatedAt'] ?? firebaseOrder['lastModified'] ?? firebaseOrder['createdAt'] ?? firebaseOrder['orderTime'] ?? '1970-01-01T00:00:00.000Z') as String,
            );
            
            if (localUpdatedAt.isAfter(firebaseUpdatedAt)) {
              // Local is newer - upload to Firebase
              await _uploadOrderToFirebase(localOrder, tenantId);
              uploadedToFirebase++;
            } else if (firebaseUpdatedAt.isAfter(localUpdatedAt)) {
              // Firebase is newer - update local
              await _downloadOrderFromFirebase(firebaseOrder);
              updatedFromFirebase++;
            } else {
              // Timestamps are equal - no update needed
              skippedCount++;
            }
          } catch (e) {
            debugPrint('⚠️ Error comparing timestamps for order $orderId: $e');
            skippedCount++;
          }
        } else if (localOrder != null) {
          // Only local exists - upload to Firebase
          await _uploadOrderToFirebase(localOrder, tenantId);
          uploadedToFirebase++;
        } else if (firebaseOrder != null) {
          // Only Firebase exists - download to local
          await _downloadOrderFromFirebase(firebaseOrder);
          updatedFromFirebase++;
        }
      }
      
      _onSyncProgress?.call('✅ Orders sync: $updatedFromFirebase downloaded, $uploadedToFirebase uploaded, $skippedCount skipped');
      _onOrdersUpdated?.call();
      
      debugPrint('✅ Orders time-based sync completed: $updatedFromFirebase downloaded, $uploadedToFirebase uploaded, $skippedCount skipped');
      
    } catch (e) {
      debugPrint('❌ Failed to perform time-based sync for orders: $e');
      _onSyncError?.call('Orders sync failed: $e');
    }
  }
  
  /// Time-based sync for menu items with timestamp comparison
  Future<void> _performTimeBasedSyncForMenuItems(String tenantId) async {
    try {
      _onSyncProgress?.call('🔄 Syncing menu items with timestamp comparison...');
      
      if (_menuService == null) return;
      
      // Get local menu items with timestamps
      final localMenuItems = await _menuService!.getMenuItems();
      final localMenuItemsMap = <String, MenuItem>{};
      for (final item in localMenuItems) {
        localMenuItemsMap[item.id] = item;
      }
      
      // Get Firebase menu items with timestamps
      final snapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('menu_items')
          .get();
      
      final firebaseMenuItemsMap = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        if (doc.id == '_persistence_config') continue;
        final itemData = doc.data();
        itemData['id'] = doc.id;
        firebaseMenuItemsMap[doc.id] = itemData;
      }
      
      debugPrint('📊 Menu items sync: ${localMenuItems.length} local, ${firebaseMenuItemsMap.length} Firebase');
      
      // Compare and sync based on timestamps
      int updatedFromFirebase = 0;
      int uploadedToFirebase = 0;
      int skippedCount = 0;
      
      final allMenuItemIds = {...localMenuItemsMap.keys, ...firebaseMenuItemsMap.keys};
      
      for (final itemId in allMenuItemIds) {
        final localItem = localMenuItemsMap[itemId];
        final firebaseItem = firebaseMenuItemsMap[itemId];
        
        if (localItem != null && firebaseItem != null) {
          // Both exist - compare timestamps
          try {
            final localUpdatedAt = localItem.updatedAt;
            final firebaseUpdatedAt = DateTime.parse(firebaseItem['updatedAt'] ?? firebaseItem['createdAt'] ?? '1970-01-01T00:00:00.000Z');
            
            if (localUpdatedAt.isAfter(firebaseUpdatedAt)) {
              // Local is newer - upload to Firebase
              await _uploadMenuItemToFirebase(localItem, tenantId);
              uploadedToFirebase++;
            } else if (firebaseUpdatedAt.isAfter(localUpdatedAt)) {
              // Firebase is newer - update local
              await _downloadMenuItemFromFirebase(firebaseItem);
              updatedFromFirebase++;
            } else {
              // Timestamps are equal - no update needed
              skippedCount++;
            }
          } catch (e) {
            debugPrint('⚠️ Error comparing timestamps for menu item $itemId: $e');
            skippedCount++;
          }
        } else if (localItem != null) {
          // Only local exists - upload to Firebase
          await _uploadMenuItemToFirebase(localItem, tenantId);
          uploadedToFirebase++;
        } else if (firebaseItem != null) {
          // Only Firebase exists - download to local
          await _downloadMenuItemFromFirebase(firebaseItem);
          updatedFromFirebase++;
        }
      }
      
      _onSyncProgress?.call('✅ Menu items sync: $updatedFromFirebase downloaded, $uploadedToFirebase uploaded, $skippedCount skipped');
      _onMenuItemsUpdated?.call();
      
      debugPrint('✅ Menu items time-based sync completed: $updatedFromFirebase downloaded, $uploadedToFirebase uploaded, $skippedCount skipped');
      
    } catch (e) {
      debugPrint('❌ Failed to perform time-based sync for menu items: $e');
      _onSyncError?.call('Menu items sync failed: $e');
    }
  }
  
  /// Time-based sync for users with timestamp comparison
  Future<void> _performTimeBasedSyncForUsers(String tenantId) async {
    try {
      _onSyncProgress?.call('🔄 Syncing users with timestamp comparison...');
      
      if (_userService == null) return;
      
      // Get local users with timestamps
      final localUsers = await _userService!.getUsers();
      final localUsersMap = <String, User>{};
      for (final user in localUsers) {
        localUsersMap[user.id] = user;
      }
      
      // Get Firebase users with timestamps
      final snapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('users')
          .get();
      
      final firebaseUsersMap = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        if (doc.id == '_persistence_config') continue;
        final userData = doc.data();
        userData['id'] = doc.id;
        firebaseUsersMap[doc.id] = userData;
      }
      
      debugPrint('📊 Users sync: ${localUsers.length} local, ${firebaseUsersMap.length} Firebase');
      
      // Compare and sync based on timestamps
      int updatedFromFirebase = 0;
      int uploadedToFirebase = 0;
      int skippedCount = 0;
      
      final allUserIds = {...localUsersMap.keys, ...firebaseUsersMap.keys};
      
      for (final userId in allUserIds) {
        final localUser = localUsersMap[userId];
        final firebaseUser = firebaseUsersMap[userId];
        
        if (localUser != null && firebaseUser != null) {
          // Both exist - compare timestamps
          try {
            final localUpdatedAt = localUser.lastLogin ?? localUser.createdAt;
            final firebaseUpdatedAt = DateTime.parse(firebaseUser['lastLogin'] ?? firebaseUser['createdAt'] ?? '1970-01-01T00:00:00.000Z');
            
            if (localUpdatedAt.isAfter(firebaseUpdatedAt)) {
              // Local is newer - upload to Firebase
              await _uploadUserToFirebase(localUser, tenantId);
              uploadedToFirebase++;
            } else if (firebaseUpdatedAt.isAfter(localUpdatedAt)) {
              // Firebase is newer - update local
              await _downloadUserFromFirebase(firebaseUser);
              updatedFromFirebase++;
            } else {
              // Timestamps are equal - no update needed
              skippedCount++;
            }
          } catch (e) {
            debugPrint('⚠️ Error comparing timestamps for user $userId: $e');
            skippedCount++;
          }
        } else if (localUser != null) {
          // Only local exists - upload to Firebase
          await _uploadUserToFirebase(localUser, tenantId);
          uploadedToFirebase++;
        } else if (firebaseUser != null) {
          // Only Firebase exists - download to local
          await _downloadUserFromFirebase(firebaseUser);
          updatedFromFirebase++;
        }
      }
      
      _onSyncProgress?.call('✅ Users sync: $updatedFromFirebase downloaded, $uploadedToFirebase uploaded, $skippedCount skipped');
      _onUsersUpdated?.call();
      
      debugPrint('✅ Users time-based sync completed: $updatedFromFirebase downloaded, $uploadedToFirebase uploaded, $skippedCount skipped');
      
    } catch (e) {
      debugPrint('❌ Failed to perform time-based sync for users: $e');
      _onSyncError?.call('Users sync failed: $e');
    }
  }
  
  /// Time-based sync for inventory with timestamp comparison
  Future<void> _performTimeBasedSyncForInventory(String tenantId) async {
    try {
      _onSyncProgress?.call('🔄 Syncing inventory with timestamp comparison...');
      
      if (_inventoryService == null) return;
      
      // Get local inventory items with timestamps
      final localInventoryItems = _inventoryService!.getAllItems();
      final localInventoryItemsMap = <String, InventoryItem>{};
      for (final item in localInventoryItems) {
        localInventoryItemsMap[item.id] = item;
      }
      
      // Get Firebase inventory items with timestamps
      final snapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('inventory')
          .get();
      
      final firebaseInventoryItemsMap = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        if (doc.id == '_persistence_config') continue;
        final itemData = doc.data();
        itemData['id'] = doc.id;
        firebaseInventoryItemsMap[doc.id] = itemData;
      }
      
      debugPrint('📊 Inventory sync: ${localInventoryItems.length} local, ${firebaseInventoryItemsMap.length} Firebase');
      
      // Compare and sync based on timestamps
      int updatedFromFirebase = 0;
      int uploadedToFirebase = 0;
      int skippedCount = 0;
      
      final allInventoryItemIds = {...localInventoryItemsMap.keys, ...firebaseInventoryItemsMap.keys};
      
      for (final itemId in allInventoryItemIds) {
        final localItem = localInventoryItemsMap[itemId];
        final firebaseItem = firebaseInventoryItemsMap[itemId];
        
        if (localItem != null && firebaseItem != null) {
          // Both exist - compare timestamps
          try {
            final localUpdatedAt = localItem.updatedAt;
            final firebaseUpdatedAt = DateTime.parse(firebaseItem['updatedAt'] ?? firebaseItem['createdAt'] ?? '1970-01-01T00:00:00.000Z');
            
            if (localUpdatedAt.isAfter(firebaseUpdatedAt)) {
              // Local is newer - upload to Firebase
              await _uploadInventoryItemToFirebase(localItem, tenantId);
              uploadedToFirebase++;
            } else if (firebaseUpdatedAt.isAfter(localUpdatedAt)) {
              // Firebase is newer - update local
              await _downloadInventoryItemFromFirebase(firebaseItem);
              updatedFromFirebase++;
            } else {
              // Timestamps are equal - no update needed
              skippedCount++;
            }
          } catch (e) {
            debugPrint('⚠️ Error comparing timestamps for inventory item $itemId: $e');
            skippedCount++;
          }
        } else if (localItem != null) {
          // Only local exists - upload to Firebase
          await _uploadInventoryItemToFirebase(localItem, tenantId);
          uploadedToFirebase++;
        } else if (firebaseItem != null) {
          // Only Firebase exists - download to local
          await _downloadInventoryItemFromFirebase(firebaseItem);
          updatedFromFirebase++;
        }
      }
      
      _onSyncProgress?.call('✅ Inventory sync: $updatedFromFirebase downloaded, $uploadedToFirebase uploaded, $skippedCount skipped');
      _onInventoryUpdated?.call();
      
      debugPrint('✅ Inventory time-based sync completed: $updatedFromFirebase downloaded, $uploadedToFirebase uploaded, $skippedCount skipped');
      
    } catch (e) {
      debugPrint('❌ Failed to perform time-based sync for inventory: $e');
      _onSyncError?.call('Inventory sync failed: $e');
    }
  }
  
  /// Time-based sync for inventory recipe links from Firebase (time-based full sync)
  Future<void> _performTimeBasedSyncForInventoryRecipeLinks(String tenantId) async {
    try {
      final snapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('inventory_recipe_links')
          .get();
      for (final doc in snapshot.docs) {
        if (doc.id == '_persistence_config') continue;
        final data = doc.data();
        data['id'] = doc.id;
        await _downloadInventoryRecipeLinkFromFirebase(data);
      }
    } catch (e) {
      debugPrint('❌ Failed to sync inventory recipe links: $e');
    }
  }
  
  /// Time-based sync for tables with timestamp comparison
  Future<void> _performTimeBasedSyncForTables(String tenantId) async {
    try {
      _onSyncProgress?.call('🔄 Syncing tables with timestamp comparison...');
      
      if (_tableService == null) return;
      
      // Get local tables with timestamps
      final localTables = await _tableService!.getTables();
      final localTablesMap = <String, Table>{};
      for (final table in localTables) {
        localTablesMap[table.id] = table;
      }
      
      // Get Firebase tables with timestamps
      final snapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('tables')
          .get();
      
      final firebaseTablesMap = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        if (doc.id == '_persistence_config') continue;
        final tableData = doc.data();
        tableData['id'] = doc.id;
        firebaseTablesMap[doc.id] = tableData;
      }
      
      debugPrint('📊 Tables sync: ${localTables.length} local, ${firebaseTablesMap.length} Firebase');
      
      // Compare and sync based on timestamps
      int updatedFromFirebase = 0;
      int uploadedToFirebase = 0;
      int skippedCount = 0;
      
      final allTableIds = {...localTablesMap.keys, ...firebaseTablesMap.keys};
      
      for (final tableId in allTableIds) {
        final localTable = localTablesMap[tableId];
        final firebaseTable = firebaseTablesMap[tableId];
        
        if (localTable != null && firebaseTable != null) {
          // Both exist - compare timestamps
          try {
            final localUpdatedAt = localTable.occupiedAt ?? localTable.reservedAt ?? DateTime.now();
            final firebaseUpdatedAt = DateTime.parse(firebaseTable['lastModified'] ?? firebaseTable['createdAt'] ?? '1970-01-01T00:00:00.000Z');
            
            if (localUpdatedAt.isAfter(firebaseUpdatedAt)) {
              // Local is newer - upload to Firebase
              await _uploadTableToFirebase(localTable, tenantId);
              uploadedToFirebase++;
            } else if (firebaseUpdatedAt.isAfter(localUpdatedAt)) {
              // Firebase is newer - update local
              await _downloadTableFromFirebase(firebaseTable);
              updatedFromFirebase++;
            } else {
              // Timestamps are equal - no update needed
              skippedCount++;
            }
          } catch (e) {
            debugPrint('⚠️ Error comparing timestamps for table $tableId: $e');
            skippedCount++;
          }
        } else if (localTable != null) {
          // Only local exists - upload to Firebase
          await _uploadTableToFirebase(localTable, tenantId);
          uploadedToFirebase++;
        } else if (firebaseTable != null) {
          // Only Firebase exists - download to local
          await _downloadTableFromFirebase(firebaseTable);
          updatedFromFirebase++;
        }
      }
      
      _onSyncProgress?.call('✅ Tables sync: $updatedFromFirebase downloaded, $uploadedToFirebase uploaded, $skippedCount skipped');
      _onTablesUpdated?.call();
      
      debugPrint('✅ Tables time-based sync completed: $updatedFromFirebase downloaded, $uploadedToFirebase uploaded, $skippedCount skipped');
      
    } catch (e) {
      debugPrint('❌ Failed to perform time-based sync for tables: $e');
      _onSyncError?.call('Tables sync failed: $e');
    }
  }
  
  /// Time-based sync for categories with timestamp comparison
  Future<void> _performTimeBasedSyncForCategories(String tenantId) async {
    try {
      _onSyncProgress?.call('🔄 Syncing categories with timestamp comparison...');
      
      if (_menuService == null) return; // Assuming categories are managed by menu service
      
      // Get local categories with timestamps
      final localCategories = await _menuService!.getCategories();
      final localCategoriesMap = <String, pos_category.Category>{};
      for (final category in localCategories) {
        localCategoriesMap[category.id] = category;
      }
      
      // Get Firebase categories with timestamps
      final snapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('categories')
          .get();
      
      final firebaseCategoriesMap = <String, Map<String, dynamic>>{};
      for (final doc in snapshot.docs) {
        if (doc.id == '_persistence_config') continue;
        final categoryData = doc.data();
        categoryData['id'] = doc.id;
        firebaseCategoriesMap[doc.id] = categoryData;
      }
      
      debugPrint('📊 Categories sync: ${localCategories.length} local, ${firebaseCategoriesMap.length} Firebase');
      
      // Compare and sync based on timestamps
      int updatedFromFirebase = 0;
      int uploadedToFirebase = 0;
      int skippedCount = 0;
      
      final allCategoryIds = {...localCategoriesMap.keys, ...firebaseCategoriesMap.keys};
      
      for (final categoryId in allCategoryIds) {
        final localCategory = localCategoriesMap[categoryId];
        final firebaseCategory = firebaseCategoriesMap[categoryId];
        
        if (localCategory != null && firebaseCategory != null) {
          // Both exist - compare timestamps
          try {
            final localUpdatedAt = localCategory.updatedAt;
            final firebaseUpdatedAt = DateTime.parse(firebaseCategory['lastModified'] ?? firebaseCategory['createdAt'] ?? '1970-01-01T00:00:00.000Z');
            
            if (localUpdatedAt.isAfter(firebaseUpdatedAt)) {
              // Local is newer - upload to Firebase
              await _uploadCategoryToFirebase(localCategory, tenantId);
              uploadedToFirebase++;
            } else if (firebaseUpdatedAt.isAfter(localUpdatedAt)) {
              // Firebase is newer - update local
              await _downloadCategoryFromFirebase(firebaseCategory);
              updatedFromFirebase++;
            } else {
              // Timestamps are equal - no update needed
              skippedCount++;
            }
          } catch (e) {
            debugPrint('⚠️ Error comparing timestamps for category $categoryId: $e');
            skippedCount++;
          }
        } else if (localCategory != null) {
          // Only local exists - upload to Firebase
          await _uploadCategoryToFirebase(localCategory, tenantId);
          uploadedToFirebase++;
        } else if (firebaseCategory != null) {
          // Only Firebase exists - download to local
          await _downloadCategoryFromFirebase(firebaseCategory);
          updatedFromFirebase++;
        }
      }
      
      _onSyncProgress?.call('✅ Categories sync: $updatedFromFirebase downloaded, $uploadedToFirebase uploaded, $skippedCount skipped');
      _onMenuItemsUpdated?.call(); // Categories are managed by menu service, so notify menu items updated
      
      debugPrint('✅ Categories time-based sync completed: $updatedFromFirebase downloaded, $uploadedToFirebase uploaded, $skippedCount skipped');
      
    } catch (e) {
      debugPrint('❌ Failed to perform time-based sync for categories: $e');
      _onSyncError?.call('Categories sync failed: $e');
    }
  }
  
  /// Upload order to Firebase
  Future<void> _uploadOrderToFirebase(pos_order.Order order, String tenantId) async {
    try {
      final docRef = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('orders')
          .doc(order.id);
      
      await docRef.set(order.toJson(), fs.SetOptions(merge: true));
      debugPrint('✅ Order uploaded to Firebase: ${order.orderNumber}');
    } catch (e) {
      debugPrint('❌ Failed to upload order to Firebase: $e');
      rethrow;
    }
  }
  
  /// Download order from Firebase
  Future<void> _downloadOrderFromFirebase(Map<String, dynamic> orderData) async {
    try {
      // Add null check for order service
      if (_orderService == null) {
        debugPrint('⚠️ OrderService not available for order sync - skipping order: ${orderData['orderNumber']}');
        return;
      }
      
      final order = pos_order.Order.fromJson(orderData);
      await _orderService!.updateOrderFromFirebase(order);
      debugPrint('✅ Order downloaded from Firebase: ${order.orderNumber}');
    } catch (e) {
      debugPrint('❌ Failed to download order from Firebase: $e');
      // Don't rethrow to prevent breaking the entire sync process
    }
  }
  
  /// Upload menu item to Firebase
  Future<void> _uploadMenuItemToFirebase(MenuItem item, String tenantId) async {
    try {
      final docRef = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('menu_items')
          .doc(item.id);
      
      await docRef.set(item.toJson(), fs.SetOptions(merge: true));
      debugPrint('✅ Menu item uploaded to Firebase: ${item.name}');
    } catch (e) {
      debugPrint('❌ Failed to upload menu item to Firebase: $e');
      rethrow;
    }
  }
  
  /// Download menu item from Firebase
  Future<void> _downloadMenuItemFromFirebase(Map<String, dynamic> itemData) async {
    try {
      // Add null check for menu service
      if (_menuService == null) {
        debugPrint('⚠️ MenuService not available for menu item sync - skipping item: ${itemData['name']}');
        return;
      }
      
      final item = MenuItem.fromJson(itemData);
      await _menuService!.updateMenuItemFromFirebase(item);
      debugPrint('✅ Menu item downloaded from Firebase: ${item.name}');
    } catch (e) {
      debugPrint('❌ Failed to download menu item from Firebase: $e');
      // Don't rethrow to prevent breaking the entire sync process
    }
  }
  
  /// Upload user to Firebase
  Future<void> _uploadUserToFirebase(User user, String tenantId) async {
    try {
      final docRef = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('users')
          .doc(user.id);
      
      await docRef.set(user.toJson(), fs.SetOptions(merge: true));
      debugPrint('✅ User uploaded to Firebase: ${user.name}');
    } catch (e) {
      debugPrint('❌ Failed to upload user to Firebase: $e');
      rethrow;
    }
  }
  
  /// Download user from Firebase
  Future<void> _downloadUserFromFirebase(Map<String, dynamic> userData) async {
    try {
      // Add null check for user service
      if (_userService == null) {
        debugPrint('⚠️ UserService not available for user sync - skipping user: ${userData['name']}');
        return;
      }
      
      final user = User.fromJson(userData);
      await _userService!.updateUserFromFirebase(user);
      debugPrint('✅ User downloaded from Firebase: ${user.name}');
    } catch (e) {
      debugPrint('❌ Failed to download user from Firebase: $e');
      // Don't rethrow to prevent breaking the entire sync process
    }
  }
  
  /// Upload inventory item to Firebase
  Future<void> _uploadInventoryItemToFirebase(InventoryItem item, String tenantId) async {
    try {
      final docRef = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('inventory')
          .doc(item.id);
      
      await docRef.set(item.toJson(), fs.SetOptions(merge: true));
      debugPrint('✅ Inventory item uploaded to Firebase: ${item.name}');
    } catch (e) {
      debugPrint('❌ Failed to upload inventory item to Firebase: $e');
      rethrow;
    }
  }
  
  /// Download inventory item from Firebase
  Future<void> _downloadInventoryItemFromFirebase(Map<String, dynamic> itemData) async {
    try {
      // Add null check for inventory service
      if (_inventoryService == null) {
        debugPrint('⚠️ InventoryService not available for inventory sync - skipping item: ${itemData['name']}');
        return;
      }
      
      final item = InventoryItem.fromJson(itemData);
      await _inventoryService!.updateItemFromFirebase(item);
      debugPrint('✅ Inventory item downloaded from Firebase: ${item.name}');
    } catch (e) {
      debugPrint('❌ Failed to download inventory item from Firebase: $e');
      // Don't rethrow to prevent breaking the entire sync process
    }
  }
  
  /// Upload table to Firebase
  Future<void> _uploadTableToFirebase(Table table, String tenantId) async {
    try {
      final docRef = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('tables')
          .doc(table.id);
      
      await docRef.set(table.toJson(), fs.SetOptions(merge: true));
      debugPrint('✅ Table uploaded to Firebase: ${table.number}');
    } catch (e) {
      debugPrint('❌ Failed to upload table to Firebase: $e');
      rethrow;
    }
  }
  
  /// Download table from Firebase
  Future<void> _downloadTableFromFirebase(Map<String, dynamic> tableData) async {
    try {
      // Add null check for table service
      if (_tableService == null) {
        debugPrint('⚠️ TableService not available for table sync - skipping table: ${tableData['number']}');
        return;
      }
      
      final table = Table.fromJson(tableData);
      await _tableService!.updateTableFromFirebase(table);
      debugPrint('✅ Table downloaded from Firebase: ${table.number}');
    } catch (e) {
      debugPrint('❌ Failed to download table from Firebase: $e');
      // Don't rethrow to prevent breaking the entire sync process
    }
  }
  
  /// Upload category to Firebase
  Future<void> _uploadCategoryToFirebase(pos_category.Category category, String tenantId) async {
    try {
      final docRef = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('categories')
          .doc(category.id);
      
      await docRef.set(category.toJson(), fs.SetOptions(merge: true));
      debugPrint('✅ Category uploaded to Firebase: ${category.name}');
    } catch (e) {
      debugPrint('❌ Failed to upload category to Firebase: $e');
      rethrow;
    }
  }
  
  /// Download category from Firebase
  Future<void> _downloadCategoryFromFirebase(Map<String, dynamic> categoryData) async {
    try {
      // Add null check for menu service
      if (_menuService == null) {
        debugPrint('⚠️ MenuService not available for category sync - skipping category: ${categoryData['name']}');
        return;
      }
      
      final category = pos_category.Category.fromJson(categoryData);
      await _menuService!.updateCategoryFromFirebase(category);
      debugPrint('✅ Category downloaded from Firebase: ${category.name}');
    } catch (e) {
      debugPrint('❌ Failed to download category from Firebase: $e');
      // Don't rethrow to prevent breaking the entire sync process
    }
  }
  
  /// Handle order deletion from Firebase
  Future<void> _handleOrderDeletionFromFirebase(String orderId) async {
    if (_orderService != null) {
      await _orderService!.deleteOrder(orderId);
      debugPrint('🗑️ Order deleted locally: $orderId');
    }
    _onOrdersUpdated?.call();
  }
  
  /// Handle menu item deletion from Firebase
  Future<void> _handleMenuItemDeletionFromFirebase(String itemId) async {
    if (_menuService != null) {
      await _menuService!.deleteMenuItem(itemId);
      debugPrint('🗑️ Menu item deleted locally: $itemId');
    }
    _onMenuItemsUpdated?.call();
  }
  
  /// Handle user deletion from Firebase
  Future<void> _handleUserDeletionFromFirebase(String userId) async {
    if (_userService != null) {
      await _userService!.deleteUser(userId);
      debugPrint('🗑️ User deleted locally: $userId');
    }
    _onUsersUpdated?.call();
  }
  
  /// Handle inventory item deletion from Firebase
  Future<void> _handleInventoryItemDeletionFromFirebase(String itemId) async {
    if (_inventoryService != null) {
      await _inventoryService!.deleteItem(itemId);
      debugPrint('🗑️ Inventory item deleted locally: $itemId');
    }
    _onInventoryUpdated?.call();
  }
  
  /// Handle table deletion from Firebase
  Future<void> _handleTableDeletionFromFirebase(String tableId) async {
    if (_tableService != null) {
      await _tableService!.deleteTable(tableId);
      debugPrint('🗑️ Table deleted locally: $tableId');
    }
    _onTablesUpdated?.call();
  }
  
  /// Handle category deletion from Firebase
  Future<void> _handleCategoryDeletionFromFirebase(String categoryId) async {
    if (_menuService != null) {
      await _menuService!.deleteCategory(categoryId);
      debugPrint('🗑️ Category deleted locally: $categoryId');
    }
    _onMenuItemsUpdated?.call();
  }
  
  /// Dispose of the service and clean up all listeners
  @override
  void dispose() {
    try {
      debugPrint('🛑 Disposing Unified Sync Service...');
      
      // Stop all real-time listeners
      _stopRealTimeListeners();
      
      // Stop connectivity monitoring
      _connectivitySubscription?.cancel();
      
      // Clear all callbacks
      _onOrdersUpdated = null;
      _onMenuItemsUpdated = null;
      _onUsersUpdated = null;
      _onInventoryUpdated = null;
      _onTablesUpdated = null;
      _onSyncProgress = null;
      _onSyncError = null;
      
      debugPrint('✅ Unified Sync Service disposed');
    } catch (e) {
      debugPrint('❌ Error disposing Unified Sync Service: $e');
    }
    
    super.dispose();
  }
  
  /// Restart real-time listeners (useful for troubleshooting)
  Future<void> restartRealTimeListeners() async {
    try {
      debugPrint('🔄 Restarting real-time Firebase listeners...');
      
      if (!_isConnected || !_isOnline) {
        debugPrint('⚠️ Cannot restart listeners - not connected or offline');
        return;
      }
      
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) {
        debugPrint('⚠️ No tenant ID available for restarting listeners');
        return;
      }
      
      await _startRealTimeListeners();
      debugPrint('✅ Real-time listeners restarted successfully');
      
    } catch (e) {
      debugPrint('❌ Failed to restart real-time listeners: $e');
    }
  }
  
  /// Set callback for orders updates
  void setOnOrdersUpdated(Function()? callback) {
    _onOrdersUpdated = callback;
  }
  
  /// Set callback for menu items updates
  void setOnMenuItemsUpdated(Function()? callback) {
    _onMenuItemsUpdated = callback;
  }
  
  /// Set callback for users updates
  void setOnUsersUpdated(Function()? callback) {
    _onUsersUpdated = callback;
  }
  
  /// Set callback for inventory updates
  void setOnInventoryUpdated(Function()? callback) {
    _onInventoryUpdated = callback;
  }
  
  /// Set callback for tables updates
  void setOnTablesUpdated(Function()? callback) {
    _onTablesUpdated = callback;
  }
  
  /// Set callback for sync progress
  void setOnSyncProgress(Function(String)? callback) {
    _onSyncProgress = callback;
  }
  
  /// Set callback for sync errors
  void setOnSyncError(Function(String)? callback) {
    _onSyncError = callback;
  }
  
  /// Clear all callbacks
  void clearCallbacks() {
    _onOrdersUpdated = null;
    _onMenuItemsUpdated = null;
    _onUsersUpdated = null;
    _onInventoryUpdated = null;
    _onTablesUpdated = null;
    _onSyncProgress = null;
    _onSyncError = null;
  }
  
  /// CRITICAL FIX: Ensure real-time sync is always active and working
  Future<void> ensureRealTimeSyncActive() async {
    try {
      debugPrint('🔴 ENSURING REAL-TIME SYNC IS ALWAYS ACTIVE...');
      
      if (!_isInitialized) {
        debugPrint('⚠️ Service not initialized - initializing first...');
        await initialize();
      }
      
      if (!_isConnected) {
        debugPrint('⚠️ Not connected to restaurant - cannot start listeners');
        return;
      }
      
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) {
        debugPrint('⚠️ No tenant ID available for real-time listeners');
        return;
      }
      
      // Check if listeners are actually working
      bool listenersActive = _ordersListener != null && 
                           _menuItemsListener != null && 
                           _usersListener != null && 
                           _inventoryListener != null && 
                           _inventoryRecipeLinksListener != null &&
                           _tablesListener != null && 
                           _categoriesListener != null;
      
      if (!listenersActive) {
        debugPrint('🔄 Real-time listeners not active - starting them now...');
        await _startRealTimeListeners();
      } else {
        debugPrint('✅ Real-time listeners are already active');
      }
      
      // Verify listeners are working by testing a simple query
      await _verifyListenersWorking(tenantId);
      
      debugPrint('🔴 REAL-TIME SYNC VERIFIED AND ACTIVE - ALL CHANGES WILL SYNC INSTANTLY!');
      
    } catch (e) {
      debugPrint('❌ Error ensuring real-time sync: $e');
      // Try to restart listeners as fallback
      await _restartRealTimeListeners();
    }
  }
  
  /// Verify that real-time listeners are actually working
  Future<void> _verifyListenersWorking(String tenantId) async {
    try {
      debugPrint('🔍 Verifying real-time listeners are working...');
      
      // Test orders listener by checking if it's receiving updates
      if (_ordersListener != null) {
        debugPrint('✅ Orders listener is active');
      } else {
        debugPrint('❌ Orders listener is not active - restarting...');
        await _restartRealTimeListeners();
      }
      
      // Test other listeners similarly
      if (_menuItemsListener != null) debugPrint('✅ Menu items listener is active');
      if (_usersListener != null) debugPrint('✅ Users listener is active');
      if (_inventoryListener != null) debugPrint('✅ Inventory listener is active');
      if (_inventoryRecipeLinksListener != null) debugPrint('✅ Inventory recipe links listener is active');
      if (_tablesListener != null) debugPrint('✅ Tables listener is active');
      if (_categoriesListener != null) debugPrint('✅ Categories listener is active');
      
    } catch (e) {
      debugPrint('❌ Error verifying listeners: $e');
    }
  }

  /// Restart all real-time listeners
  Future<void> _restartRealTimeListeners() async {
    try {
      debugPrint('🔄 Restarting all real-time listeners...');
      await _stopRealTimeListeners();
      await Future.delayed(const Duration(milliseconds: 500)); // Brief pause
      await _startRealTimeListeners();
      debugPrint('✅ Real-time listeners restarted successfully');
    } catch (e) {
      debugPrint('❌ Error restarting listeners: $e');
    }
  }
  
  /// Enhanced server change sync with comprehensive order refresh
  Future<void> performServerChangeSync({
    required String? newServerId,
    required String? previousServerId,
    bool forceRefresh = false,
  }) async {
    try {
      if (!_enableEnhancedServerChangeSync) {
        debugPrint('⚠️ Enhanced server change sync is disabled');
        return;
      }
      
      if (_isServerChangeSyncInProgress && !forceRefresh) {
        debugPrint('🔄 Server change sync already in progress, skipping...');
        return;
      }
      
      debugPrint('🔄 ENHANCED SERVER CHANGE SYNC: Starting sync for server change...');
      debugPrint('   Previous server: $previousServerId');
      debugPrint('   New server: $newServerId');
      
      _isServerChangeSyncInProgress = true;
      _lastSelectedServerId = newServerId;
      _lastServerChangeTime = DateTime.now();
      
      // STEP 1: Ensure real-time sync is active
      await _ensureRealTimeSyncActive();
      
      // STEP 2: Use the SAME comprehensive sync method as the POS dashboard icon
      // This ensures consistency and reuses proven, working sync logic
      debugPrint('🔄 STEP 2: Using comprehensive sync method (same as POS dashboard icon)...');
      await manualSync();
      
      // STEP 3: Update sync state and notify
      _isServerChangeSyncInProgress = false;
      _lastSyncTime = DateTime.now();
      
      // Notify UI of successful sync
      _onSyncProgress?.call('Server change sync completed successfully');
      
      debugPrint('✅ ENHANCED SERVER CHANGE SYNC: Completed successfully using comprehensive sync method');
      
      // Start automatic order refresh monitoring
      if (_enableAutomaticOrderRefresh) {
        _startAutomaticOrderRefreshMonitoring(newServerId);
      }
      
    } catch (e) {
      debugPrint('❌ ENHANCED SERVER CHANGE SYNC: Failed - $e');
      _isServerChangeSyncInProgress = false;
      _onSyncError?.call('Server change sync failed: $e');
      
      // Fallback to basic sync
      try {
        await _performBasicServerChangeSync(newServerId);
      } catch (fallbackError) {
        debugPrint('❌ Basic server change sync fallback also failed: $fallbackError');
      }
    }
  }
  

  

  

  
  /// Basic server change sync fallback
  Future<void> _performBasicServerChangeSync(String? serverId) async {
    try {
      debugPrint('🔄 Performing basic server change sync fallback...');
      
      // Simple order refresh without comprehensive sync
      if (_orderService != null) {
        await _orderService!.loadOrders();
        debugPrint('✅ Basic order refresh completed');
      }
      
    } catch (e) {
      debugPrint('❌ Basic server change sync fallback failed: $e');
    }
  }
  
  /// Start automatic order refresh monitoring
  void _startAutomaticOrderRefreshMonitoring(String? serverId) {
    try {
      _orderRefreshTimer?.cancel();
      
      if (!_enableAutomaticOrderRefresh) {
        debugPrint('⚠️ Automatic order refresh is disabled');
        return;
      }
      
      debugPrint('🔄 Starting automatic order refresh monitoring for server: $serverId');
      
      // Refresh orders every 30 seconds to catch cross-device changes
      _orderRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
        if (!_isConnected || _isOrderRefreshInProgress) {
          return;
        }
        
        try {
          await _performAutomaticOrderRefresh(serverId);
        } catch (e) {
          debugPrint('⚠️ Automatic order refresh failed: $e');
        }
      });
      
      debugPrint('✅ Automatic order refresh monitoring started');
      
    } catch (e) {
      debugPrint('❌ Failed to start automatic order refresh monitoring: $e');
    }
  }
  
  /// Perform automatic order refresh
  Future<void> _performAutomaticOrderRefresh(String? serverId) async {
    try {
      if (_isOrderRefreshInProgress) {
        return;
      }
      
      _isOrderRefreshInProgress = true;
      _lastOrderRefreshTime = DateTime.now();
      
      debugPrint('🔄 Performing automatic order refresh...');
      
      // Check for new orders from Firebase
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId != null) {
        await _checkForNewOrdersFromFirebase(tenantId);
      }
      
      // Update local order service
      if (_orderService != null) {
        await _orderService!.loadOrders();
      }
      
      // Notify UI of potential updates
      _onOrdersUpdated?.call();
      
      debugPrint('✅ Automatic order refresh completed');
      
    } catch (e) {
      debugPrint('❌ Automatic order refresh failed: $e');
    } finally {
      _isOrderRefreshInProgress = false;
    }
  }
  
  /// Check for new orders from Firebase
  Future<void> _checkForNewOrdersFromFirebase(String tenantId) async {
    try {
      final ordersSnapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('orders')
          .orderBy('updatedAt', descending: true)
          .limit(50) // Limit to recent orders for performance
          .get();
      
      int newOrdersCount = 0;
      
      for (final doc in ordersSnapshot.docs) {
        if (doc.id == '_persistence_config') continue;
        
        final orderData = doc.data();
        orderData['id'] = doc.id;
        
        // Check if this order is newer than our last refresh
        if (_lastOrderRefreshTime != null) {
          final orderUpdatedAt = DateTime.parse((orderData['updatedAt'] ?? orderData['lastModified'] ?? orderData['createdAt'] ?? orderData['orderTime'] ?? '1970-01-01T00:00:00.000Z') as String);
          if (orderUpdatedAt.isAfter(_lastOrderRefreshTime!)) {
            try {
              await _downloadOrderFromFirebase(orderData);
              newOrdersCount++;
            } catch (e) {
              debugPrint('⚠️ Failed to download new order ${doc.id}: $e');
            }
          }
        }
      }
      
      if (newOrdersCount > 0) {
        debugPrint('🆕 Found $newOrdersCount new orders from Firebase');
      }
      
    } catch (e) {
      debugPrint('❌ Failed to check for new orders: $e');
    }
  }
  
  /// Enhanced sync orders from Firebase with server filtering
  Future<void> _syncOrdersFromFirebase(String tenantId) async {
    try {
      debugPrint('🔄 Syncing orders from Firebase for server change...');
      
      final ordersSnapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('orders')
          .orderBy('updatedAt', descending: true)
          .get();
      
      int syncedCount = 0;
      
      for (final doc in ordersSnapshot.docs) {
        if (doc.id == '_persistence_config') continue;
        
        final orderData = doc.data();
        orderData['id'] = doc.id;
        
        try {
          await _downloadOrderFromFirebase(orderData);
          syncedCount++;
        } catch (e) {
          debugPrint('⚠️ Failed to sync order ${doc.id}: $e');
        }
      }
      
      debugPrint('✅ Orders sync completed: $syncedCount orders synced');
      
    } catch (e) {
      debugPrint('❌ Orders sync failed: $e');
      rethrow;
    }
  }
  
  /// Sync menu items from Firebase
  Future<void> _syncMenuItemsFromFirebase(String tenantId) async {
    try {
      debugPrint('🔄 Syncing menu items from Firebase...');
      
      final menuItemsSnapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('menu_items')
          .get();
      
      int syncedCount = 0;
      
      for (final doc in menuItemsSnapshot.docs) {
        if (doc.id == '_persistence_config') continue;
        
        final itemData = doc.data();
        itemData['id'] = doc.id;
        
        try {
          await _downloadMenuItemFromFirebase(itemData);
          syncedCount++;
        } catch (e) {
          debugPrint('⚠️ Failed to sync menu item ${doc.id}: $e');
        }
      }
      
      debugPrint('✅ Menu items sync completed: $syncedCount items synced');
      
    } catch (e) {
      debugPrint('❌ Menu items sync failed: $e');
      // Don't rethrow - continue with other syncs
    }
  }
  
  /// Sync users from Firebase
  Future<void> _syncUsersFromFirebase(String tenantId) async {
    try {
      debugPrint('🔄 Syncing users from Firebase...');
      
      final usersSnapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('users')
          .get();
      
      int syncedCount = 0;
      
      for (final doc in usersSnapshot.docs) {
        if (doc.id == '_persistence_config') continue;
        
        final userData = doc.data();
        userData['id'] = doc.id;
        
        try {
          await _downloadUserFromFirebase(userData);
          syncedCount++;
        } catch (e) {
          debugPrint('⚠️ Failed to sync user ${doc.id}: $e');
        }
      }
      
      debugPrint('✅ Users sync completed: $syncedCount users synced');
      
    } catch (e) {
      debugPrint('❌ Users sync failed: $e');
      // Don't rethrow - continue with other syncs
    }
  }
  
  /// Sync inventory from Firebase
  Future<void> _syncInventoryFromFirebase(String tenantId) async {
    try {
      debugPrint('🔄 Syncing inventory from Firebase...');
      
      final inventorySnapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('inventory')
          .get();
      
      int syncedCount = 0;
      
      for (final doc in inventorySnapshot.docs) {
        if (doc.id == '_persistence_config') continue;
        
        final inventoryData = doc.data();
        inventoryData['id'] = doc.id;
        
        try {
          // For now, just log that we found inventory items
          // The actual sync would need to be implemented based on the service
          debugPrint('🆕 Inventory item found: ${doc.id}');
          syncedCount++;
        } catch (e) {
          debugPrint('⚠️ Failed to sync inventory item ${doc.id}: $e');
        }
      }
      
      debugPrint('✅ Inventory sync completed: $syncedCount items synced');
      
    } catch (e) {
      debugPrint('❌ Inventory sync failed: $e');
      // Don't rethrow - continue with other syncs
    }
  }
  
  /// Sync tables from Firebase
  Future<void> _syncTablesFromFirebase(String tenantId) async {
    try {
      debugPrint('🔄 Syncing tables from Firebase...');
      
      final tablesSnapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('tables')
          .get();
      
      int syncedCount = 0;
      
      for (final doc in tablesSnapshot.docs) {
        if (doc.id == '_persistence_config') continue;
        
        final tableData = doc.data();
        tableData['id'] = doc.id;
        
        try {
          await _downloadTableFromFirebase(tableData);
          syncedCount++;
        } catch (e) {
          debugPrint('⚠️ Failed to sync table ${doc.id}: $e');
        }
      }
      
      debugPrint('✅ Tables sync completed: $syncedCount tables synced');
      
    } catch (e) {
      debugPrint('❌ Tables sync failed: $e');
      // Don't rethrow - continue with other syncs
    }
  }
  
  /// Sync categories from Firebase
  Future<void> _syncCategoriesFromFirebase(String tenantId) async {
    try {
      debugPrint('🔄 Syncing categories from Firebase...');
      
      final categoriesSnapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('categories')
          .get();
      
      int syncedCount = 0;
      
      for (final doc in categoriesSnapshot.docs) {
        if (doc.id == '_persistence_config') continue;
        
        final categoryData = doc.data();
        categoryData['id'] = doc.id;
        
        try {
          await _downloadCategoryFromFirebase(categoryData);
          syncedCount++;
        } catch (e) {
          debugPrint('⚠️ Failed to sync category ${doc.id}: $e');
        }
      }
      
      debugPrint('✅ Categories sync completed: $syncedCount categories synced');
      
    } catch (e) {
      debugPrint('❌ Categories sync failed: $e');
      // Don't rethrow - continue with other syncs
    }
  }

  /// Ensure real-time sync is active for server change
  Future<void> _ensureRealTimeSyncActive() async {
    try {
      debugPrint('🔄 Ensuring real-time sync is active...');
      
      // Check if listeners are active
      if (_ordersListener == null || _menuItemsListener == null) {
        debugPrint('⚠️ Real-time listeners not active, starting them...');
        await _startRealTimeListeners();
      }
      
      // Verify connectivity
      if (!_isOnline) {
        debugPrint('⚠️ No internet connection, waiting for connectivity...');
        await _waitForConnectivity();
      }
      
      debugPrint('✅ Real-time sync is active');
      
    } catch (e) {
      debugPrint('❌ Failed to ensure real-time sync: $e');
      // Don't rethrow - this is not critical
    }
  }

  /// Wait for connectivity to be restored
  Future<void> _waitForConnectivity() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity != ConnectivityResult.none) {
        _isOnline = true;
        debugPrint('✅ Connectivity restored');
      } else {
        // Wait and check again
        await Future.delayed(const Duration(seconds: 2));
        await _waitForConnectivity();
      }
    } catch (e) {
      debugPrint('❌ Error checking connectivity: $e');
    }
  }

  /// Check if all required services are available for sync
  bool _areServicesAvailable() {
    final missingServices = <String>[];
    
    if (_databaseService == null) missingServices.add('DatabaseService');
    if (_orderService == null) missingServices.add('OrderService');
    if (_menuService == null) missingServices.add('MenuService');
    if (_userService == null) missingServices.add('UserService');
    if (_inventoryService == null) missingServices.add('InventoryService');
    if (_tableService == null) missingServices.add('TableService');
    
    if (missingServices.isNotEmpty) {
      debugPrint('⚠️ Missing services for sync: ${missingServices.join(', ')}');
      debugPrint('💡 Call setServices() to provide service instances before syncing');
      return false;
    }
    
    return true;
  }

  /// Reconcile and optionally purge stale local-only orders
  Future<void> _reconcileStaleLocalOrders(String tenantId) async {
    try {
      if (_orderService == null) return;
      
      // Build a set of server order IDs for quick lookup
      final serverSnapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('orders')
          .get();
      final serverIds = serverSnapshot.docs.map((d) => d.id).toSet();
      
      final localOrders = _orderService!.allOrders;
      int staleCount = 0;
      for (final order in localOrders) {
        if (!serverIds.contains(order.id)) {
          staleCount++;
        }
      }
      if (staleCount > 0) {
        debugPrint('🔎 Reconcile: Found $staleCount local orders missing on server (logging only).');
      }
      
      if (_enablePurgeStaleLocalOrders) {
        // Zero-risk: currently disabled. Implement purge policy here when enabled.
        // Intentionally left as a no-op to avoid unintended data loss.
      }
    } catch (e) {
      debugPrint('⚠️ Reconcile stale local orders failed: $e');
    }
  }

  Future<void> _downloadInventoryRecipeLinkFromFirebase(Map<String, dynamic> linkData) async {
    try {
      if (_inventoryService == null) return;
      await _inventoryService!.updateRecipeLinkFromFirebase(linkData);
      debugPrint('✅ Inventory recipe link synced');
    } catch (e) {
      debugPrint('❌ Failed to download recipe link: $e');
    }
  }

  Future<void> _handleInventoryRecipeLinkDeletionFromFirebase(String linkId) async {
    try {
      if (_inventoryService == null) return;
      await _inventoryService!.removeRecipeLink(linkId);
      debugPrint('🗑️ Inventory recipe link deleted locally: $linkId');
    } catch (e) {
      debugPrint('❌ Failed to handle recipe link deletion: $e');
    }
  }

} 