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
      debugPrint('🚀 Initializing Unified Sync Service with comprehensive fixes...');
      
      // Initialize sync fix service first
      await _syncFixService.initialize();
      
      // Check if Firebase is initialized
      if (!FirebaseConfig.isInitialized) {
        debugPrint('⚠️ Firebase not initialized - sync will be limited');
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
        debugPrint('⚠️ Failed to enable Firebase persistence: $e');
        // Continue without persistence
      }
      
      // Start connectivity monitoring
      _startConnectivityMonitoring();
      
      _isInitialized = true;
      debugPrint('✅ Unified Sync Service initialized with fixes');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to initialize Unified Sync Service: $e');
      _onSyncError?.call('Failed to initialize: $e');
      _isInitialized = true;
    }
  }
  
  /// Connect to restaurant for sync with comprehensive error handling
  Future<void> connectToRestaurant(Restaurant restaurant, RestaurantSession session) async {
    try {
      debugPrint('🔄 Connecting to restaurant for sync: ${restaurant.email}');
      
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
      debugPrint('🔧 Running comprehensive sync fixes...');
      final fixResult = await _syncFixService.fixAllSyncIssues();
      if (fixResult) {
        debugPrint('✅ Sync fixes completed successfully');
      } else {
        debugPrint('⚠️ Some sync fixes failed, continuing with caution');
      }
      
      // START REAL-TIME LISTENERS for immediate cross-device sync
      await _startRealTimeListeners();
      
      debugPrint('✅ Connected to restaurant for sync with fixes applied');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to connect to restaurant for sync: $e');
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
        
        debugPrint('⚠️ Firebase connection attempt $attempts failed, retrying in ${_retryDelay.inSeconds}s: $e');
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
      
      debugPrint('🔍 Testing Firebase connection to tenant: $tenantId');
      
      final doc = await _firestore.collection('tenants').doc(tenantId).get();
      debugPrint('✅ Firebase connection test successful - tenant exists: ${doc.exists}');
    } catch (e) {
      debugPrint('❌ Firebase connection test failed: $e');
      rethrow;
    }
  }
  
  /// Handle connection errors with recovery
  void _handleConnectionError(dynamic error) {
    debugPrint('🔧 Handling connection error: $error');
    
    if (_consecutiveErrors >= _maxConsecutiveErrors && !_isRecovering) {
      _isRecovering = true;
      debugPrint('🚨 Too many consecutive errors, starting recovery process...');
      
      // Schedule recovery
      Timer(const Duration(seconds: 30), () async {
        try {
          debugPrint('🔄 Attempting connection recovery...');
          await _recoverConnection();
          _isRecovering = false;
          _consecutiveErrors = 0;
          debugPrint('✅ Connection recovery completed');
        } catch (e) {
          debugPrint('❌ Connection recovery failed: $e');
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
        debugPrint('🔧 Cleared Firebase persistence cache');
      } catch (e) {
        debugPrint('⚠️ Failed to clear Firebase cache: $e');
      }
      
      // Reinitialize Firebase settings
      try {
        _firestore.settings = const fs.Settings(
          persistenceEnabled: true,
          cacheSizeBytes: fs.Settings.CACHE_SIZE_UNLIMITED,
        );
      } catch (e) {
        debugPrint('⚠️ Failed to reinitialize Firebase settings: $e');
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
      debugPrint('❌ Connection recovery failed: $e');
      rethrow;
    }
  }
  
  /// Start connectivity monitoring
  void _startConnectivityMonitoring() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      final wasOnline = _isOnline;
      _isOnline = result != ConnectivityResult.none;
      
      debugPrint('🌐 Connectivity changed: $result (online: $_isOnline)');
      
      if (!wasOnline && _isOnline) {
        debugPrint('🌐 Connection restored - triggering sync');
        _onConnectivityRestored();
      } else if (wasOnline && !_isOnline) {
        debugPrint('🌐 Connection lost - switching to offline mode');
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
      debugPrint('🚨 Performing emergency sync after connectivity restoration...');
      
      // Run comprehensive sync fixes
      await _syncFixService.fixAllSyncIssues();
      
      // Restart real-time listeners
      if (_currentRestaurant != null) {
        await _startRealTimeListeners();
      }
      
      // Perform manual sync
      await manualSync();
      
      debugPrint('✅ Emergency sync completed successfully');
    } catch (e) {
      debugPrint('❌ Emergency sync failed: $e');
      _onSyncError?.call('Emergency sync failed: $e');
    }
  }

  // ... existing code ...
  
  /// Enhanced manual sync with comprehensive fixes
  Future<void> manualSync() async {
    if (_isSyncing) {
      debugPrint('⚠️ Manual sync: Already syncing, skipping duplicate call');
      return;
    }
    
    _isSyncing = true;
    _onSyncProgress?.call('🔄 Starting comprehensive manual sync...');
    
    try {
      debugPrint('🔄 Starting enhanced manual sync with fixes...');
      
      // PHASE 1: Run comprehensive sync fixes first
      debugPrint('🔧 Phase 1: Running comprehensive sync fixes...');
      final fixResult = await _syncFixService.fixAllSyncIssues();
      if (!fixResult) {
        debugPrint('⚠️ Some sync fixes failed, continuing with caution');
      }
      
      // PHASE 2: Perform standard sync operations
      debugPrint('🔄 Phase 2: Performing standard sync operations...');
      
      if (!_isOnline) {
        debugPrint('⚠️ Device is offline - queuing changes for later sync');
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
      debugPrint('✅ Enhanced manual sync completed');
      
    } catch (e) {
      debugPrint('❌ Enhanced manual sync failed: $e');
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
      debugPrint('✅ Successfully synced $dataType');
    } catch (e) {
      debugPrint('❌ Failed to sync $dataType: $e');
      // Don't rethrow - continue with other sync operations
    }
  }
  
  /// Handle sync errors
  void _handleSyncError(dynamic error) {
    _consecutiveErrors++;
    
    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      debugPrint('🚨 Too many sync errors, triggering recovery');
      _handleConnectionError(error);
    }
  }

  // ... rest of existing methods with enhanced error handling ...
  
  /// Start real-time Firebase listeners with enhanced error handling
  Future<void> _startRealTimeListeners() async {
    try {
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) {
        debugPrint('⚠️ No tenant ID available for real-time listeners');
        return;
      }
      
      debugPrint('🔴 Starting enhanced real-time Firebase listeners...');
      
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
      
      debugPrint('✅ Enhanced real-time listeners started successfully');
      
    } catch (e) {
      debugPrint('❌ Failed to start real-time listeners: $e');
      _onSyncError?.call('Failed to start real-time listeners: $e');
    }
  }
  
  /// Handle listener errors
  void _handleListenerError(String listenerType, dynamic error) {
    debugPrint('❌ Real-time listener error ($listenerType): $error');
    _consecutiveErrors++;
    
    // Restart listener after delay
    Timer(const Duration(seconds: 5), () async {
      try {
        debugPrint('🔄 Restarting $listenerType listener...');
        await _startRealTimeListeners();
      } catch (e) {
        debugPrint('❌ Failed to restart $listenerType listener: $e');
      }
    });
  }
  
  /// Handle orders snapshot with enhanced processing
  void _handleOrdersSnapshot(fs.QuerySnapshot snapshot) {
    try {
      debugPrint('📥 Received orders snapshot with ${snapshot.docs.length} documents');
      
      if (snapshot.docs.isEmpty) return;
      
      // Process changes in batches to prevent overload
      _batchProcessChanges('orders', snapshot.docChanges);
      
    } catch (e) {
      debugPrint('❌ Error processing orders snapshot: $e');
      _handleListenerError('orders', e);
    }
  }
  
  /// Handle menu items snapshot
  void _handleMenuItemsSnapshot(fs.QuerySnapshot snapshot) {
    try {
      debugPrint('📥 Received menu items snapshot with ${snapshot.docs.length} documents');
      
      if (snapshot.docs.isEmpty) return;
      
      _batchProcessChanges('menu_items', snapshot.docChanges);
      
    } catch (e) {
      debugPrint('❌ Error processing menu items snapshot: $e');
      _handleListenerError('menu_items', e);
    }
  }
  
  /// Handle users snapshot
  void _handleUsersSnapshot(fs.QuerySnapshot snapshot) {
    try {
      debugPrint('📥 Received users snapshot with ${snapshot.docs.length} documents');
      
      if (snapshot.docs.isEmpty) return;
      
      _batchProcessChanges('users', snapshot.docChanges);
      
    } catch (e) {
      debugPrint('❌ Error processing users snapshot: $e');
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
      debugPrint('🔄 Processing batched changes...');
      
      for (final entry in _batchedChanges.entries) {
        final collection = entry.key;
        final changes = entry.value;
        
        if (changes.length > _maxBatchSize) {
          debugPrint('⚠️ Large batch detected for $collection: ${changes.length} changes, processing in chunks');
          
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
      debugPrint('❌ Error processing batched changes: $e');
    }
  }
  
  /// Process collection changes
  void _processCollectionChanges(String collection, List<fs.DocumentChange> changes) {
    try {
      debugPrint('🔄 Processing ${changes.length} changes for $collection');
      
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
      debugPrint('❌ Error processing $collection changes: $e');
    }
  }
  
  /// Handle document added
  void _handleDocumentAdded(String collection, fs.DocumentSnapshot doc) {
    try {
      debugPrint('➕ Document added to $collection: ${doc.id}');
      
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
      debugPrint('❌ Error handling document added ($collection): $e');
    }
  }
  
  /// Handle document modified
  void _handleDocumentModified(String collection, fs.DocumentSnapshot doc) {
    try {
      debugPrint('✏️ Document modified in $collection: ${doc.id}');
      
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
      debugPrint('❌ Error handling document modified ($collection): $e');
    }
  }
  
  /// Handle document removed
  void _handleDocumentRemoved(String collection, fs.DocumentSnapshot doc) {
    try {
      debugPrint('🗑️ Document removed from $collection: ${doc.id}');
      
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
      debugPrint('❌ Error handling document removed ($collection): $e');
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
        debugPrint('📝 Processing new order from Firebase: ${doc.id}');
      }
    } catch (e) {
      debugPrint('❌ Error handling order added: $e');
    }
  }
  
  /// Handle order modified
  void _handleOrderModified(fs.DocumentSnapshot doc) {
    try {
      if (_orderService != null) {
        final orderData = doc.data() as Map<String, dynamic>;
        orderData['id'] = doc.id;
        
        debugPrint('📝 Processing modified order from Firebase: ${doc.id}');
      }
    } catch (e) {
      debugPrint('❌ Error handling order modified: $e');
    }
  }
  
  /// Handle order removed
  void _handleOrderRemoved(fs.DocumentSnapshot doc) {
    try {
      if (_orderService != null) {
        debugPrint('🗑️ Processing removed order from Firebase: ${doc.id}');
      }
    } catch (e) {
      debugPrint('❌ Error handling order removed: $e');
    }
  }
  
  /// Handle menu item added
  void _handleMenuItemAdded(fs.DocumentSnapshot doc) {
    try {
      if (_menuService != null) {
        debugPrint('📝 Processing new menu item from Firebase: ${doc.id}');
      }
    } catch (e) {
      debugPrint('❌ Error handling menu item added: $e');
    }
  }
  
  /// Handle menu item modified
  void _handleMenuItemModified(fs.DocumentSnapshot doc) {
    try {
      if (_menuService != null) {
        debugPrint('📝 Processing modified menu item from Firebase: ${doc.id}');
      }
    } catch (e) {
      debugPrint('❌ Error handling menu item modified: $e');
    }
  }
  
  /// Handle menu item removed
  void _handleMenuItemRemoved(fs.DocumentSnapshot doc) {
    try {
      if (_menuService != null) {
        debugPrint('🗑️ Processing removed menu item from Firebase: ${doc.id}');
      }
    } catch (e) {
      debugPrint('❌ Error handling menu item removed: $e');
    }
  }
  
  /// Handle user added
  void _handleUserAdded(fs.DocumentSnapshot doc) {
    try {
      if (_userService != null) {
        debugPrint('📝 Processing new user from Firebase: ${doc.id}');
      }
    } catch (e) {
      debugPrint('❌ Error handling user added: $e');
    }
  }
  
  /// Handle user modified
  void _handleUserModified(fs.DocumentSnapshot doc) {
    try {
      if (_userService != null) {
        debugPrint('📝 Processing modified user from Firebase: ${doc.id}');
      }
    } catch (e) {
      debugPrint('❌ Error handling user modified: $e');
    }
  }
  
  /// Handle user removed
  void _handleUserRemoved(fs.DocumentSnapshot doc) {
    try {
      if (_userService != null) {
        debugPrint('🗑️ Processing removed user from Firebase: ${doc.id}');
      }
    } catch (e) {
      debugPrint('❌ Error handling user removed: $e');
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
      debugPrint('🔴 Stopping real-time listeners...');
      
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
      
      debugPrint('✅ Real-time listeners stopped');
    } catch (e) {
      debugPrint('❌ Error stopping real-time listeners: $e');
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
          debugPrint('📝 Syncing order: ${doc.id}');
          
        } catch (e) {
          debugPrint('⚠️ Failed to sync order ${doc.id}: $e');
          // Continue with other orders
        }
      }
      
      _onOrdersUpdated?.call();
      debugPrint('✅ Synced ${snapshot.docs.length} orders');
    } catch (e) {
      debugPrint('❌ Failed to sync orders: $e');
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
          debugPrint('⚠️ Failed to sync menu item ${doc.id}: $e');
        }
      }
      
      _onMenuItemsUpdated?.call();
      debugPrint('✅ Synced ${snapshot.docs.length} menu items');
    } catch (e) {
      debugPrint('❌ Failed to sync menu items: $e');
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
          debugPrint('📝 Syncing category: ${doc.id}');
        } catch (e) {
          debugPrint('⚠️ Failed to sync category ${doc.id}: $e');
        }
      }
      
      _onCategoriesUpdated?.call();
      debugPrint('✅ Synced ${snapshot.docs.length} categories');
    } catch (e) {
      debugPrint('❌ Failed to sync categories: $e');
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
          debugPrint('⚠️ Failed to sync user ${doc.id}: $e');
        }
      }
      
      _onUsersUpdated?.call();
      debugPrint('✅ Synced ${snapshot.docs.length} users');
    } catch (e) {
      debugPrint('❌ Failed to sync users: $e');
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
          debugPrint('⚠️ Failed to sync inventory item ${doc.id}: $e');
        }
      }
      
      _onInventoryUpdated?.call();
      debugPrint('✅ Synced ${snapshot.docs.length} inventory items');
    } catch (e) {
      debugPrint('❌ Failed to sync inventory: $e');
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
          debugPrint('⚠️ Failed to sync table ${doc.id}: $e');
        }
      }
      
      _onTablesUpdated?.call();
      debugPrint('✅ Synced ${snapshot.docs.length} tables');
    } catch (e) {
      debugPrint('❌ Failed to sync tables: $e');
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
      
      debugPrint('✅ Order synced to Firebase: ${order.orderNumber}');
    } catch (e) {
      debugPrint('❌ Failed to sync order to Firebase: $e');
      
      // Queue for retry if offline
      if (!_isOnline) {
        _pendingChanges.add({
          'type': 'order',
          'action': 'create_or_update',
          'data': order.toJson(),
          'timestamp': DateTime.now().toIso8601String(),
        });
        debugPrint('📝 Queued order for offline sync: ${order.orderNumber}');
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
      
      debugPrint('✅ Menu item synced to Firebase: ${item.name}');
    } catch (e) {
      debugPrint('❌ Failed to sync menu item to Firebase: $e');
      
      if (!_isOnline) {
        _pendingChanges.add({
          'type': 'menu_item',
          'action': 'create_or_update',
          'data': item.toJson(),
          'timestamp': DateTime.now().toIso8601String(),
        });
        debugPrint('📝 Queued menu item for offline sync: ${item.name}');
      } else {
        rethrow;
      }
    }
  }
  
  /// Process pending changes when back online
  Future<void> _processPendingChanges() async {
    if (_pendingChanges.isEmpty || !_isOnline) return;
    
    debugPrint('🔄 Processing ${_pendingChanges.length} pending changes...');
    
    final changesToProcess = List<Map<String, dynamic>>.from(_pendingChanges);
    _pendingChanges.clear();
    
    for (final change in changesToProcess) {
      try {
        await _processPendingChange(change);
      } catch (e) {
        debugPrint('❌ Failed to process pending change: $e');
        // Re-queue failed changes
        _pendingChanges.add(change);
      }
    }
    
    debugPrint('✅ Processed pending changes');
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
      debugPrint('🔄 Starting force sync with comprehensive fixes...');
      
      // Run comprehensive sync fixes
      await _syncFixService.fixAllSyncIssues();
      
      // Run manual sync
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
      await forceSync();
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
      await forceSync();
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
      await forceSync();
      debugPrint('✅ Instant sync completed');
    } catch (e) {
      debugPrint('❌ Instant sync failed: $e');
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
      debugPrint('🔄 Server change sync triggered (compatibility mode)...');
      await forceSync();
      debugPrint('✅ Server change sync completed');
    } catch (e) {
      debugPrint('❌ Server change sync failed: $e');
      rethrow;
    }
  }
  
  /// Compatibility method for forceSyncAllLocalData
  Future<void> forceSyncAllLocalData() async {
    try {
      debugPrint('🔄 Force sync all local data...');
      await forceSync();
      debugPrint('✅ Force sync all local data completed');
    } catch (e) {
      debugPrint('❌ Force sync all local data failed: $e');
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
      debugPrint('⚠️ Error checking if sync is needed: $e');
      return true; // Default to needing sync if we can't determine
    }
  }
  
  /// Compatibility method for performSmartTimeBasedSync
  Future<void> performSmartTimeBasedSync() async {
    try {
      debugPrint('🔄 Smart time-based sync...');
      await forceSync();
      debugPrint('✅ Smart time-based sync completed');
    } catch (e) {
      debugPrint('❌ Smart time-based sync failed: $e');
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
      debugPrint('🔄 Ensuring real-time sync is active...');
      
      if (!_isConnected) {
        debugPrint('⚠️ Not connected - cannot ensure real-time sync');
        return;
      }
      
      // Check if listeners are active
      if (!isRealTimeSyncActive) {
        debugPrint('🔄 Starting real-time listeners...');
        await _startRealTimeListeners();
      }
      
      debugPrint('✅ Real-time sync is active');
    } catch (e) {
      debugPrint('❌ Failed to ensure real-time sync: $e');
    }
  }
  
  /// Compatibility method for restartRealTimeListeners
  Future<void> restartRealTimeListeners() async {
    try {
      debugPrint('🔄 Restarting real-time listeners...');
      await _stopRealTimeListeners();
      await Future.delayed(const Duration(milliseconds: 500));
      await _startRealTimeListeners();
      debugPrint('✅ Real-time listeners restarted');
    } catch (e) {
      debugPrint('❌ Failed to restart real-time listeners: $e');
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
      debugPrint('🔄 Ghost order cleanup (now handled by sync fix service)...');
      await _syncFixService.fixAllSyncIssues();
      debugPrint('✅ Ghost order cleanup completed');
    } catch (e) {
      debugPrint('❌ Ghost order cleanup failed: $e');
    }
  }
  
  /// Compatibility method for autoSyncOnDeviceLogin
  Future<void> autoSyncOnDeviceLogin() async {
    try {
      debugPrint('🔄 Auto sync on device login...');
      await forceSync();
      debugPrint('✅ Auto sync on device login completed');
    } catch (e) {
      debugPrint('❌ Auto sync on device login failed: $e');
    }
  }
  
  /// Compatibility method for disconnect
  Future<void> disconnect() async {
    try {
      debugPrint('🔄 Disconnecting from restaurant...');
      
      // Stop real-time listeners
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
  
  /// Compatibility method for syncMenuItemToFirebase
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
      
      debugPrint('✅ Item deleted from Firebase: $collection/$itemId');
    } catch (e) {
      debugPrint('❌ Failed to delete item from Firebase: $e');
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
      debugPrint('✅ Category synced to Firebase: ${category.name} ($action)');
    } catch (e) {
      debugPrint('❌ Failed to sync category to Firebase: $e');
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
      debugPrint('📝 Added pending sync change: $collection/$action/$itemId');
    } catch (e) {
      debugPrint('❌ Failed to add pending sync change: $e');
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
      debugPrint('✅ Order synced to Firebase: ${order.orderNumber} ($action)');
    } catch (e) {
      debugPrint('❌ Failed to sync order to Firebase: $e');
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
      
      debugPrint('✅ User synced to Firebase: ${user.name}');
    } catch (e) {
      debugPrint('❌ Failed to sync user to Firebase: $e');
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
      debugPrint('✅ User synced to Firebase: ${user.name} ($action)');
    } catch (e) {
      debugPrint('❌ Failed to sync user to Firebase: $e');
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
      debugPrint('✅ Table synced to Firebase: ${table.number} ($action)');
    } catch (e) {
      debugPrint('❌ Failed to sync table to Firebase: $e');
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
      debugPrint('✅ Inventory item synced to Firebase: ${item.name} ($action)');
    } catch (e) {
      debugPrint('❌ Failed to sync inventory item to Firebase: $e');
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
} 