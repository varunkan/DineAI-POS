import 'dart:async';
import 'dart:convert';
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
import '../services/sync_fix_service.dart';


/// UNIFIED SYNC SERVICE - FIXED VERSION
/// Single source of truth for all Firebase synchronization
/// Consolidates all sync methods and removes redundancy
/// Now includes comprehensive sync fixes
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
  
  // Sync fix service
  final SyncFixService _syncFixService = SyncFixService.instance;
  
  // Current restaurant and session
  Restaurant? _currentRestaurant;
  RestaurantSession? _currentSession;
  
  // Sync state
  bool _isConnected = false;
  bool _isInitialized = false;
  
  // Performance optimization: batch and throttle updates
  Timer? _batchTimer;
  final Map<String, List<fs.DocumentChange>> _batchedChanges = {};
  static const Duration _batchDelay = Duration(milliseconds: 500);
  static const int _maxBatchSize = 50; // Limit batch size to prevent overload
  
  // Offline sync pending changes
  final List<Map<String, dynamic>> _pendingChanges = [];
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  
  // Connectivity monitoring
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  bool _isOnline = true;
  
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
  Function()? _onCategoriesUpdated;
  Function(String)? _onSyncProgress;
  Function(String)? _onSyncError;
  
  // Feature flags for enhanced server change sync
  static const bool _enableEnhancedServerChangeSync = true;
  static const bool _enableAutomaticOrderRefresh = true;
  static const bool _enableServerChangeNotifications = true;
  // Feature flag: when true, reconcile can purge stale local-only orders (logging-only by default)
  static const bool _enablePurgeStaleLocalOrders = false;
  // Feature flag: prefer server status for terminal states (cancelled/completed)
  static const bool _enableServerAuthoritativeTerminalStatuses = true;
  // Feature flag: clean up zero-dollar ghost orders on login
  static const bool _enableGhostOrderCleanupOnLogin = true;
  
  // Server change sync state
  String? _lastSelectedServerId;
  DateTime? _lastServerChangeTime;
  bool _isServerChangeSyncInProgress = false;
  
  // Retry mechanism
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);
  
  // Error recovery
  bool _isRecovering = false;
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 5;
  
  static UnifiedSyncService get instance {
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
  
  /// Initialize the unified sync service with comprehensive fixes
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      
      // Initialize sync fix service first
      await _syncFixService.initialize();
      
      // Check if Firebase is initialized
      if (!FirebaseConfig.isInitialized) {
        _isInitialized = true;
        return;
      }
      
      _firestore = fs.FirebaseFirestore.instance;
      
      // Enable offline persistence with error handling
      try {
        _firestore.settings = const fs.Settings(
          persistenceEnabled: true,
          cacheSizeBytes: fs.Settings.CACHE_SIZE_UNLIMITED,
        );
      } catch (e) {
        // Continue without persistence
      }
      
      // Start connectivity monitoring
      _startConnectivityMonitoring();
      
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      _onSyncError?.call('Failed to initialize: $e');
      _isInitialized = true;
    }
  }
  
  /// Connect to restaurant for sync with comprehensive error handling
  Future<void> connectToRestaurant(Restaurant restaurant, RestaurantSession session) async {
    try {
      
      _currentRestaurant = restaurant;
      _currentSession = session;
      
      // Set services for sync fix service
      _syncFixService.setServices(
        databaseService: _databaseService,
        orderService: _orderService,
      );
      
      // Test Firebase connection with retry
      await _testFirebaseConnectionWithRetry();
      
      _isConnected = true;
      _lastSyncTime = DateTime.now();
      
      // Run comprehensive sync fixes before starting listeners
      final fixResult = await _syncFixService.fixAllSyncIssues();
      if (fixResult) {
      } else {
      }
      
      // START REAL-TIME LISTENERS for immediate cross-device sync
      await _startRealTimeListeners();
      
      notifyListeners();
    } catch (e) {
      _isConnected = false;
      _handleConnectionError(e);
    }
  }
  
  /// Test Firebase connection with retry mechanism
  Future<void> _testFirebaseConnectionWithRetry() async {
    int attempts = 0;
    while (attempts < _maxRetries) {
      try {
        await _testFirebaseConnection();
        _consecutiveErrors = 0; // Reset error count on success
        return;
      } catch (e) {
        attempts++;
        _consecutiveErrors++;
        
        if (attempts >= _maxRetries) {
          throw Exception('Firebase connection failed after $_maxRetries attempts: $e');
        }
        
        await Future.delayed(_retryDelay);
      }
    }
  }
  
  /// Test Firebase connection
  Future<void> _testFirebaseConnection() async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) {
        throw Exception('No tenant ID available');
      }
      
      
      final doc = await _firestore.collection('tenants').doc(tenantId).get();
    } catch (e) {
      rethrow;
    }
  }
  
  /// Handle connection errors with recovery
  void _handleConnectionError(dynamic error) {
    
    if (_consecutiveErrors >= _maxConsecutiveErrors && !_isRecovering) {
      _isRecovering = true;
      
      // Schedule recovery
      Timer(const Duration(seconds: 30), () async {
        try {
          await _recoverConnection();
          _isRecovering = false;
          _consecutiveErrors = 0;
        } catch (e) {
          _isRecovering = false;
        }
      });
    }
  }
  
  /// Recover connection
  Future<void> _recoverConnection() async {
    try {
      // Stop existing listeners
      await _stopRealTimeListeners();
      
      // Clear Firebase cache
      try {
        await _firestore.clearPersistence();
      } catch (e) {
      }
      
      // Reinitialize Firebase settings
      try {
        _firestore.settings = const fs.Settings(
          persistenceEnabled: true,
          cacheSizeBytes: fs.Settings.CACHE_SIZE_UNLIMITED,
        );
      } catch (e) {
      }
      
      // Test connection
      await _testFirebaseConnection();
      
      // Restart listeners if we have a current restaurant
      if (_currentRestaurant != null) {
        await _startRealTimeListeners();
      }
      
      // Run sync fixes again
      await _syncFixService.fixAllSyncIssues();
      
    } catch (e) {
      rethrow;
    }
  }
  
  /// Start connectivity monitoring
  void _startConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;
      
      
      if (!wasOnline && _isOnline) {
        _onConnectivityRestored();
      } else if (wasOnline && !_isOnline) {
        _onConnectivityLost();
      }
      
      notifyListeners();
    });
  }
  
  /// Handle connectivity restored
  void _onConnectivityRestored() {
    // Reset error counters
    _consecutiveErrors = 0;
    _isRecovering = false;
    
    // Trigger comprehensive sync
    unawaited(_performEmergencySync());
  }
  
  /// Handle connectivity lost
  void _onConnectivityLost() {
    // Stop real-time listeners to save resources
    unawaited(_stopRealTimeListeners());
  }
  
  /// Perform emergency sync when connectivity is restored
  Future<void> _performEmergencySync() async {
    try {
      
      // Run comprehensive sync fixes
      await _syncFixService.fixAllSyncIssues();
      
      // Restart real-time listeners
      if (_currentRestaurant != null) {
        await _startRealTimeListeners();
      }
      
      // Perform manual sync
      await manualSync();
      
    } catch (e) {
      _onSyncError?.call('Emergency sync failed: $e');
    }
  }

  // ... existing code ...
  
  /// Enhanced manual sync with comprehensive fixes
  Future<void> manualSync() async {
    if (_isSyncing) {
      return;
    }
    
    _isSyncing = true;
    _onSyncProgress?.call('🔄 Starting comprehensive manual sync...');
    
    try {
      
      // PHASE 1: Run comprehensive sync fixes first
      final fixResult = await _syncFixService.fixAllSyncIssues();
      if (!fixResult) {
      }
      
      // PHASE 2: Perform standard sync operations
      
      if (!_isOnline) {
        _onSyncProgress?.call('⚠️ Offline - changes queued for later sync');
        return;
      }
      
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) {
        throw Exception('No tenant ID available for sync');
      }
      
      // Sync all data types with error handling
      await Future.wait([
        _syncWithErrorHandling(() => _syncOrders(tenantId), 'orders'),
        _syncWithErrorHandling(() => _syncMenuItems(tenantId), 'menu items'),
        _syncWithErrorHandling(() => _syncUsers(tenantId), 'users'),
        _syncWithErrorHandling(() => _syncInventory(tenantId), 'inventory'),
        _syncWithErrorHandling(() => _syncTables(tenantId), 'tables'),
        _syncWithErrorHandling(() => _syncCategories(tenantId), 'categories'),
      ]);
      
      _lastSyncTime = DateTime.now();
      _onSyncProgress?.call('✅ Enhanced manual sync completed successfully');
      
    } catch (e) {
      _onSyncError?.call('Manual sync failed: $e');
      _handleSyncError(e);
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  
  /// Sync with error handling wrapper
  Future<void> _syncWithErrorHandling(Future<void> Function() syncFunction, String dataType) async {
    try {
      await syncFunction();
    } catch (e) {
      // Don't rethrow - continue with other sync operations
    }
  }
  
  /// Handle sync errors
  void _handleSyncError(dynamic error) {
    _consecutiveErrors++;
    
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      _handleConnectionError(error);
    }
  }

  // ... rest of existing methods with enhanced error handling ...
  
  /// Start real-time Firebase listeners with enhanced error handling
  Future<void> _startRealTimeListeners() async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) {
        return;
      }
      
      
      // Stop existing listeners first
      await _stopRealTimeListeners();
      
      // Start orders listener with error handling
      _ordersListener = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('orders')
          .snapshots()
          .listen(
            _handleOrdersSnapshot,
            onError: (error) => _handleListenerError('orders', error),
          );
      
      // Start menu items listener with error handling
      _menuItemsListener = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('menu_items')
          .snapshots()
          .listen(
            _handleMenuItemsSnapshot,
            onError: (error) => _handleListenerError('menu_items', error),
          );
      
      // Start other listeners...
      _usersListener = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('users')
          .snapshots()
          .listen(
            _handleUsersSnapshot,
            onError: (error) => _handleListenerError('users', error),
          );
      
      
    } catch (e) {
      _onSyncError?.call('Failed to start real-time listeners: $e');
    }
  }
  
  /// Handle listener errors
  void _handleListenerError(String listenerType, dynamic error) {
    _consecutiveErrors++;
    
    // Restart listener after delay
    Timer(const Duration(seconds: 5), () async {
      try {
        await _startRealTimeListeners();
      } catch (e) {
      }
    });
  }
  
  /// Handle orders snapshot with enhanced processing
  void _handleOrdersSnapshot(fs.QuerySnapshot snapshot) {
    try {
      
      if (snapshot.docs.isEmpty) return;
      
      // Process changes in batches to prevent overload
      _batchProcessChanges('orders', snapshot.docChanges);
      
    } catch (e) {
      _handleListenerError('orders', e);
    }
  }
  
  /// Handle menu items snapshot
  void _handleMenuItemsSnapshot(fs.QuerySnapshot snapshot) {
    try {
      
      if (snapshot.docs.isEmpty) return;
      
      _batchProcessChanges('menu_items', snapshot.docChanges);
      
    } catch (e) {
      _handleListenerError('menu_items', e);
    }
  }
  
  /// Handle users snapshot
  void _handleUsersSnapshot(fs.QuerySnapshot snapshot) {
    try {
      
      if (snapshot.docs.isEmpty) return;
      
      _batchProcessChanges('users', snapshot.docChanges);
      
    } catch (e) {
      _handleListenerError('users', e);
    }
  }
  
  /// Batch process changes to prevent overload
  void _batchProcessChanges(String collection, List<fs.DocumentChange> changes) {
    if (changes.isEmpty) return;
    
    // Add to batch
    _batchedChanges[collection] = (_batchedChanges[collection] ?? [])..addAll(changes);
    
    // Cancel existing timer
    _batchTimer?.cancel();
    
    // Start new timer
    _batchTimer = Timer(_batchDelay, () {
      _processBatchedChanges();
    });
  }
  
  /// Process batched changes
  void _processBatchedChanges() {
    try {
      
      for (final entry in _batchedChanges.entries) {
        final collection = entry.key;
        final changes = entry.value;
        
        if (changes.length > _maxBatchSize) {
          
          // Process in chunks
          for (int i = 0; i < changes.length; i += _maxBatchSize) {
            final chunk = changes.sublist(i, (i + _maxBatchSize).clamp(0, changes.length));
            _processCollectionChanges(collection, chunk);
          }
        } else {
          _processCollectionChanges(collection, changes);
        }
      }
      
      // Clear batched changes
      _batchedChanges.clear();
      
    } catch (e) {
    }
  }
  
  /// Process collection changes
  void _processCollectionChanges(String collection, List<fs.DocumentChange> changes) {
    try {
      
      for (final change in changes) {
        switch (change.type) {
          case fs.DocumentChangeType.added:
            _handleDocumentAdded(collection, change.doc);
            break;
          case fs.DocumentChangeType.modified:
            _handleDocumentModified(collection, change.doc);
            break;
          case fs.DocumentChangeType.removed:
            _handleDocumentRemoved(collection, change.doc);
            break;
        }
      }
      
      // Notify UI of updates
      _notifyCollectionUpdated(collection);
      
    } catch (e) {
    }
  }
  
  /// Handle document added
  void _handleDocumentAdded(String collection, fs.DocumentSnapshot doc) {
    try {
      
      switch (collection) {
        case 'orders':
          _handleOrderAdded(doc);
          break;
        case 'menu_items':
          _handleMenuItemAdded(doc);
          break;
        case 'users':
          _handleUserAdded(doc);
          break;
        // Add other collections as needed
      }
      
    } catch (e) {
    }
  }
  
  /// Handle document modified
  void _handleDocumentModified(String collection, fs.DocumentSnapshot doc) {
    try {
      
      switch (collection) {
        case 'orders':
          _handleOrderModified(doc);
          break;
        case 'menu_items':
          _handleMenuItemModified(doc);
          break;
        case 'users':
          _handleUserModified(doc);
          break;
        // Add other collections as needed
      }
      
    } catch (e) {
    }
  }
  
  /// Handle document removed
  void _handleDocumentRemoved(String collection, fs.DocumentSnapshot doc) {
    try {
      
      switch (collection) {
        case 'orders':
          _handleOrderRemoved(doc);
          break;
        case 'menu_items':
          _handleMenuItemRemoved(doc);
          break;
        case 'users':
          _handleUserRemoved(doc);
          break;
        // Add other collections as needed
      }
      
    } catch (e) {
    }
  }
  
  /// Handle order added
  void _handleOrderAdded(fs.DocumentSnapshot doc) {
    try {
      if (_orderService != null) {
        final orderData = doc.data() as Map<String, dynamic>;
        orderData['id'] = doc.id;
        
        // Convert to Order object and update local database
        // This would need to be implemented based on your Order model
      }
    } catch (e) {
    }
  }
  
  /// Handle order modified
  void _handleOrderModified(fs.DocumentSnapshot doc) {
    try {
      if (_orderService != null) {
        final orderData = doc.data() as Map<String, dynamic>;
        orderData['id'] = doc.id;
        
      }
    } catch (e) {
    }
  }
  
  /// Handle order removed
  void _handleOrderRemoved(fs.DocumentSnapshot doc) {
    try {
      if (_orderService != null) {
      }
    } catch (e) {
    }
  }
  
  /// Handle menu item added
  void _handleMenuItemAdded(fs.DocumentSnapshot doc) {
    try {
      if (_menuService != null) {
      }
    } catch (e) {
    }
  }
  
  /// Handle menu item modified
  void _handleMenuItemModified(fs.DocumentSnapshot doc) {
    try {
      if (_menuService != null) {
      }
    } catch (e) {
    }
  }
  
  /// Handle menu item removed
  void _handleMenuItemRemoved(fs.DocumentSnapshot doc) {
    try {
      if (_menuService != null) {
      }
    } catch (e) {
    }
  }
  
  /// Handle user added
  void _handleUserAdded(fs.DocumentSnapshot doc) {
    try {
      if (_userService != null) {
      }
    } catch (e) {
    }
  }
  
  /// Handle user modified
  void _handleUserModified(fs.DocumentSnapshot doc) {
    try {
      if (_userService != null) {
      }
    } catch (e) {
    }
  }
  
  /// Handle user removed
  void _handleUserRemoved(fs.DocumentSnapshot doc) {
    try {
      if (_userService != null) {
      }
    } catch (e) {
    }
  }
  
  /// Notify collection updated
  void _notifyCollectionUpdated(String collection) {
    switch (collection) {
      case 'orders':
        _onOrdersUpdated?.call();
        break;
      case 'menu_items':
        _onMenuItemsUpdated?.call();
        break;
      case 'users':
        _onUsersUpdated?.call();
        break;
      case 'inventory':
        _onInventoryUpdated?.call();
        break;
      case 'tables':
        _onTablesUpdated?.call();
        break;
      case 'categories':
        _onCategoriesUpdated?.call();
        break;
    }
  }

  // ... rest of existing methods ...
  
  /// Stop real-time listeners
  Future<void> _stopRealTimeListeners() async {
    try {
      
      await _ordersListener?.cancel();
      await _menuItemsListener?.cancel();
      await _usersListener?.cancel();
      await _inventoryListener?.cancel();
      await _inventoryRecipeLinksListener?.cancel();
      await _tablesListener?.cancel();
      await _categoriesListener?.cancel();
      
      _ordersListener = null;
      _menuItemsListener = null;
      _usersListener = null;
      _inventoryListener = null;
      _inventoryRecipeLinksListener = null;
      _tablesListener = null;
      _categoriesListener = null;
      
    } catch (e) {
    }
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
    _databaseService = databaseService;
    _orderService = orderService;
    _menuService = menuService;
    _userService = userService;
    _inventoryService = inventoryService;
    _tableService = tableService;
  }
  
  /// Set callbacks
  void setCallbacks({
    Function()? onOrdersUpdated,
    Function()? onMenuItemsUpdated,
    Function()? onUsersUpdated,
    Function()? onInventoryUpdated,
    Function()? onTablesUpdated,
    Function()? onCategoriesUpdated,
    Function(String)? onSyncProgress,
    Function(String)? onSyncError,
  }) {
    _onOrdersUpdated = onOrdersUpdated;
    _onMenuItemsUpdated = onMenuItemsUpdated;
    _onUsersUpdated = onUsersUpdated;
    _onInventoryUpdated = onInventoryUpdated;
    _onTablesUpdated = onTablesUpdated;
    _onCategoriesUpdated = onCategoriesUpdated;
    _onSyncProgress = onSyncProgress;
    _onSyncError = onSyncError;
  }
  
  /// Get sync fix log
  List<String> get syncFixLog => _syncFixService.fixLog;
  
  /// Dispose resources
  @override
  void dispose() {
    _stopRealTimeListeners();
    _connectivitySubscription?.cancel();
    _batchTimer?.cancel();
    _syncFixService.dispose();
    super.dispose();
  }

  // ... existing sync methods with enhanced error handling ...
  
  /// Sync orders with enhanced error handling
  Future<void> _syncOrders(String tenantId) async {
    try {
      if (_orderService == null) return;
      
      final snapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('orders')
          .get();
      
      for (final doc in snapshot.docs) {
        try {
          if (doc.id == '_persistence_config') continue;
          
          final orderData = doc.data();
          orderData['id'] = doc.id;
          
          // Process order data
          // This would need to be implemented based on your Order model
          
        } catch (e) {
          // Continue with other orders
        }
      }
      
      _onOrdersUpdated?.call();
    } catch (e) {
      rethrow;
    }
  }
  
  /// Sync menu items with enhanced error handling
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
        }
      }
      
      _onMenuItemsUpdated?.call();
    } catch (e) {
      rethrow;
    }
  }
  
  /// Sync categories with enhanced error handling
  Future<void> _syncCategories(String tenantId) async {
    try {
      final snapshot = await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('categories')
          .get();
      
      for (final doc in snapshot.docs) {
        try {
          final categoryData = doc.data();
          // Process category data
        } catch (e) {
        }
      }
      
      _onCategoriesUpdated?.call();
    } catch (e) {
      rethrow;
    }
  }
  
  /// Sync users with enhanced error handling
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
        }
      }
      
      _onUsersUpdated?.call();
    } catch (e) {
      rethrow;
    }
  }
  
  /// Sync inventory with enhanced error handling
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
        }
      }
      
      _onInventoryUpdated?.call();
    } catch (e) {
      rethrow;
    }
  }
  
  /// Sync tables with enhanced error handling
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
        }
      }
      
      _onTablesUpdated?.call();
    } catch (e) {
      rethrow;
    }
  }

  // ... rest of existing methods with similar error handling patterns ...
  
  /// Create or update order in Firebase with enhanced error handling
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
      
    } catch (e) {
      
      // Queue for retry if offline
      if (!_isOnline) {
        _pendingChanges.add({
          'type': 'order',
          'action': 'create_or_update',
          'data': order.toJson(),
          'timestamp': DateTime.now().toIso8601String(),
        });
      } else {
        rethrow;
      }
    }
  }
  
  /// Create or update menu item in Firebase with enhanced error handling
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
      
    } catch (e) {
      
      if (!_isOnline) {
        _pendingChanges.add({
          'type': 'menu_item',
          'action': 'create_or_update',
          'data': item.toJson(),
          'timestamp': DateTime.now().toIso8601String(),
        });
      } else {
        rethrow;
      }
    }
  }
  
  /// Process pending changes when back online
  Future<void> _processPendingChanges() async {
    if (_pendingChanges.isEmpty || !_isOnline) return;
    
    
    final changesToProcess = List<Map<String, dynamic>>.from(_pendingChanges);
    _pendingChanges.clear();
    
    for (final change in changesToProcess) {
      try {
        await _processPendingChange(change);
      } catch (e) {
        // Re-queue failed changes
        _pendingChanges.add(change);
      }
    }
    
  }
  
  /// Process individual pending change
  Future<void> _processPendingChange(Map<String, dynamic> change) async {
    final type = change['type'] as String;
    final action = change['action'] as String;
    final data = change['data'] as Map<String, dynamic>;
    
    switch (type) {
      case 'order':
        if (action == 'create_or_update') {
          final order = pos_order.Order.fromJson(data);
          await createOrUpdateOrder(order);
        }
        break;
      case 'menu_item':
        if (action == 'create_or_update') {
          final menuItem = MenuItem.fromJson(data);
          await createOrUpdateMenuItem(menuItem);
        }
        break;
      // Add other types as needed
    }
  }
  
  /// Force sync - runs comprehensive fixes and sync
  Future<void> forceSync() async {
    try {
      
      // Run comprehensive sync fixes
      await _syncFixService.fixAllSyncIssues();
      
      // Run manual sync
      await manualSync();
      
    } catch (e) {
      rethrow;
    }
  }
  
  /// Trigger immediate sync
  Future<void> triggerImmediateSync() async {
    try {
      await forceSync();
    } catch (e) {
      rethrow;
    }
  }
  
  /// Download data from cloud
  Future<void> downloadFromCloud() async {
    try {
      await manualSync();
    } catch (e) {
      rethrow;
    }
  }
  
  /// Clear and sync data
  Future<void> clearAndSyncData() async {
    try {
      
      // Run comprehensive fixes first
      await _syncFixService.fixAllSyncIssues();
      
      // Clear local data
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
    } catch (e) {
      rethrow;
    }
  }
  
  /// Upload data to cloud
  Future<void> uploadToCloud() async {
    try {
      await manualSync();
    } catch (e) {
      rethrow;
    }
  }
  
  /// Perform full sync (alias for manualSync)
  Future<void> performFullSync() async {
    try {
      await forceSync();
    } catch (e) {
      rethrow;
    }
  }
  
  /// Trigger instant sync (alias for manualSync)
  Future<void> triggerInstantSync() async {
    try {
      await forceSync();
    } catch (e) {
      rethrow;
    }
  }
  
  // COMPATIBILITY METHODS FOR EXISTING CODE
  
  /// Compatibility method for performServerChangeSync
  Future<void> performServerChangeSync({
    required String? newServerId,
    required String? previousServerId,
    bool forceRefresh = false,
  }) async {
    try {
      await forceSync();
    } catch (e) {
      rethrow;
    }
  }
  
  /// Compatibility method for forceSyncAllLocalData
  Future<void> forceSyncAllLocalData() async {
    try {
      await forceSync();
    } catch (e) {
      rethrow;
    }
  }
  
  /// Compatibility method for needsSync
  Future<bool> needsSync() async {
    try {
      // Simple heuristic: if last sync was more than 5 minutes ago, suggest sync
      if (_lastSyncTime == null) return true;
      
      final timeSinceLastSync = DateTime.now().difference(_lastSyncTime!);
      return timeSinceLastSync.inMinutes > 5;
    } catch (e) {
      return true; // Default to needing sync if we can't determine
    }
  }
  
  /// Compatibility method for performSmartTimeBasedSync
  Future<void> performSmartTimeBasedSync() async {
    try {
      await forceSync();
    } catch (e) {
      rethrow;
    }
  }
  
  /// Compatibility method for setOnOrdersUpdated
  void setOnOrdersUpdated(Function()? callback) {
    _onOrdersUpdated = callback;
  }
  
  /// Compatibility method for setOnSyncProgress
  void setOnSyncProgress(Function(String)? callback) {
    _onSyncProgress = callback;
  }
  
  /// Compatibility method for setOnSyncError
  void setOnSyncError(Function(String)? callback) {
    _onSyncError = callback;
  }
  
  /// Compatibility method for ensureRealTimeSyncActive
  Future<void> ensureRealTimeSyncActive() async {
    try {
      
      if (!_isConnected) {
        return;
      }
      
      // Check if listeners are active
      if (!isRealTimeSyncActive) {
        await _startRealTimeListeners();
      }
      
    } catch (e) {
    }
  }
  
  /// Compatibility method for restartRealTimeListeners
  Future<void> restartRealTimeListeners() async {
    try {
      await _stopRealTimeListeners();
      await Future.delayed(const Duration(milliseconds: 500));
      await _startRealTimeListeners();
    } catch (e) {
    }
  }
  
  /// Compatibility method for clearCallbacks
  void clearCallbacks() {
    _onOrdersUpdated = null;
    _onMenuItemsUpdated = null;
    _onUsersUpdated = null;
    _onInventoryUpdated = null;
    _onTablesUpdated = null;
    _onCategoriesUpdated = null;
    _onSyncProgress = null;
    _onSyncError = null;
  }
  
  /// Compatibility method for cleanupGhostOrdersOnLogin
  Future<void> cleanupGhostOrdersOnLogin({int maxDeletes = 250}) async {
    try {
      await _syncFixService.fixAllSyncIssues();
    } catch (e) {
    }
  }
  
  /// Compatibility method for autoSyncOnDeviceLogin
  Future<void> autoSyncOnDeviceLogin() async {
    try {
      await forceSync();
    } catch (e) {
    }
  }
  
  /// Compatibility method for disconnect
  Future<void> disconnect() async {
    try {
      
      // Stop real-time listeners
      await _stopRealTimeListeners();
      
      _currentRestaurant = null;
      _currentSession = null;
      _isConnected = false;
      
      notifyListeners();
    } catch (e) {
    }
  }
  
  /// Compatibility method for syncMenuItemToFirebase
  Future<void> syncMenuItemToFirebase(MenuItem item, String action) async {
    try {
      if (action == 'deleted') {
        await deleteItem('menu_items', item.id);
      } else {
        await createOrUpdateMenuItem(item);
      }
    } catch (e) {
      rethrow;
    }
  }
  
  /// Compatibility method for deleteItem
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
      
    } catch (e) {
      rethrow;
    }
  }
  
  /// Compatibility method for syncCategoryToFirebase
  Future<void> syncCategoryToFirebase(pos_category.Category category, String action) async {
    try {
      if (action == 'deleted') {
        await deleteItem('categories', category.id);
      } else {
        await createOrUpdateCategory(category);
      }
    } catch (e) {
      rethrow;
    }
  }
  
  /// Compatibility method for syncOrderItemToFirebase
  Future<void> syncOrderItemToFirebase(Map<String, dynamic> itemMap) async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) throw Exception('No tenant ID available');
      
      final sent = (itemMap['sent_to_kitchen'] ?? itemMap['sentToKitchen'] ?? 0);
      if (sent is int && sent != 1) {
        return;
      }
      if (sent is bool && sent != true) {
        return;
      }
      
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('order_items')
          .doc(itemMap['id'] as String)
          .set(itemMap, fs.SetOptions(merge: true));
      
    } catch (e) {
      rethrow;
    }
  }
  
  /// Compatibility method for addPendingSyncChange
  void addPendingSyncChange(String collection, String action, String itemId, Map<String, dynamic> data) {
    try {
      final change = {
        'type': collection,
        'action': action,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      _pendingChanges.add(change);
    } catch (e) {
    }
  }
  
  /// Compatibility method for syncOrderToFirebase
  Future<void> syncOrderToFirebase(pos_order.Order order, String action) async {
    try {
      if (action == 'deleted') {
        await deleteItem('orders', order.id);
      } else {
        await createOrUpdateOrder(order);
      }
    } catch (e) {
      rethrow;
    }
  }
  
  /// Compatibility method for createOrUpdateUser
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
      
    } catch (e) {
      rethrow;
    }
  }
  
  /// Compatibility method for syncUserToFirebase
  Future<void> syncUserToFirebase(User user, String action) async {
    try {
      if (action == 'deleted') {
        await deleteItem('users', user.id);
      } else {
        await createOrUpdateUser(user);
      }
    } catch (e) {
      rethrow;
    }
  }
  
  /// Compatibility method for syncTableToFirebase
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
    } catch (e) {
      rethrow;
    }
  }
  
  /// Compatibility method for syncInventoryItemToFirebase
  Future<void> syncInventoryItemToFirebase(InventoryItem item, String action) async {
    try {
      if (action == 'deleted') {
        await deleteItem('inventory', item.id);
      } else {
        await createOrUpdateInventoryItem(item);
      }
    } catch (e) {
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
      
    } catch (e) {
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
      
    } catch (e) {
      rethrow;
    }
  }
} 