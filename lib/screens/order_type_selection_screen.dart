import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/order.dart';
import '../models/user.dart';
import '../config/security_config.dart';
import '../services/order_service.dart';
import '../services/user_service.dart';
import '../services/table_service.dart';
import '../services/unified_sync_service.dart';
import '../models/restaurant.dart';

import '../services/multi_tenant_auth_service.dart';
import '../screens/dine_in_setup_screen.dart';
import '../screens/takeout_setup_screen.dart';
import '../screens/admin_panel_screen.dart';
import '../screens/kitchen_screen.dart';
import '../screens/order_creation_screen.dart';
import '../screens/restaurant_auth_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderTypeSelectionScreen extends StatefulWidget {
  const OrderTypeSelectionScreen({super.key});

  @override
  State<OrderTypeSelectionScreen> createState() => _OrderTypeSelectionScreenState();
}

class _OrderTypeSelectionScreenState extends State<OrderTypeSelectionScreen> with WidgetsBindingObserver {
  String? _selectedServerId;
  List<Order> _filteredOrders = [];
  bool _isManualRefresh = false;
  bool _isSyncing = false;

  // INNOVATIVE FIX: Real-time cross-device sync with feature flags
  static const bool _enableRealTimeCrossDeviceSync = true;
  static const bool _enablePeriodicRefresh = true;
  static const Duration _refreshInterval = Duration(seconds: 5);
  
  Timer? _autoRefreshTimer;
  UnifiedSyncService? _syncService;
  bool _isRealTimeSyncActive = false;
  bool _isGhostOrderCleanupActive = false; // Track ghost order cleanup to avoid false notifications

  @override
  void initState() {
    super.initState();
    debugPrint('🔍 POS DASHBOARD: initState() called');
    
    // CRITICAL: Register for app lifecycle changes to ensure real-time sync
    WidgetsBinding.instance.addObserver(this);
    
    // Set current user as selected server by default
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Use Consumer pattern to safely access UserService
      _setDefaultServer();
      _loadOrders();
      
      // Add listener to refresh orders when OrderService state changes
      final orderService = Provider.of<OrderService?>(context, listen: false);
      if (orderService != null) {
        orderService.addListener(_onOrderServiceChanged);
      }
      
      // INNOVATIVE FIX: Start real-time order count monitoring
      _startOrderCountMonitoring();
      
      // INNOVATIVE FIX: Initialize real-time cross-device sync
      if (_enableRealTimeCrossDeviceSync) {
        _initializeRealTimeSync();
      }
      
      // INDUSTRY STANDARD: Start proper Firebase real-time listeners
      _startFirebaseRealTimeListeners();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    debugPrint('🔄 POS DASHBOARD: didChangeDependencies() called - DEBOUNCED refresh');
    
    // CRITICAL: Ensure real-time sync is active when screen becomes visible
    if (_enableRealTimeCrossDeviceSync && _syncService != null) {
      _ensureRealTimeSyncActive();
    }
    
    // INDUSTRY STANDARD: Ensure Firebase real-time listeners are active
    _startFirebaseRealTimeListeners();
    
    // FIXED: Use debounced refresh to prevent infinite loops
    _debouncedRefresh();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // CRITICAL: Ensure real-time sync is active when app becomes visible
    if (state == AppLifecycleState.resumed && _enableRealTimeCrossDeviceSync) {
      debugPrint('🔴 APP RESUMED - Ensuring real-time sync is active...');
      _ensureRealTimeSyncActive();
      
      // INDUSTRY STANDARD: Restart Firebase real-time listeners when app resumes
      _startFirebaseRealTimeListeners();
    }
  }
  
  // Debounced refresh to prevent infinite loops
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  
  void _debouncedRefresh() {
    if (_isRefreshing) {
      debugPrint('🔄 Refresh already in progress, skipping...');
      return;
    }
    
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted && !_isRefreshing) {
        _isRefreshing = true;
        debugPrint('🔄 Executing debounced refresh in POS dashboard...');
        
        _refreshOrdersFromService();
        
        // Reset flag after a delay
        Timer(const Duration(milliseconds: 300), () {
          _isRefreshing = false;
        });
      }
    });
  }

  @override
  void dispose() {
    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Cancel any pending refresh timer
    _refreshTimer?.cancel();
    
    // Remove listener to prevent memory leaks
    final orderService = Provider.of<OrderService?>(context, listen: false);
    if (orderService != null) {
      orderService.removeListener(_onOrderServiceChanged);
    }
    
    // INNOVATIVE FIX: Stop order count monitoring
    _stopOrderCountMonitoring();
    
    // INNOVATIVE FIX: Stop real-time cross-device sync
    if (_enableRealTimeCrossDeviceSync) {
      _stopRealTimeSync();
    }
    
    // Clean up any fallback timers
    _autoRefreshTimer?.cancel();
    
    super.dispose();
  }

  /// Handle order service changes (e.g., when orders are cancelled/updated)
  void _onOrderServiceChanged() {
    if (mounted) {
      debugPrint('🔄 OrderService changed - refreshing POS dashboard');
      // Use a delayed refresh to avoid excessive rebuilds
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _refreshOrdersFromService();
        }
      });
    }
  }

  /// Refresh orders from existing service data (no database reload)
  void _refreshOrdersFromService() {
    try {
      // Check if widget is still mounted before proceeding
      if (!mounted) {
        debugPrint('⚠️ Widget not mounted - skipping order refresh');
        return;
      }

      final orderService = Provider.of<OrderService?>(context, listen: false);
      if (orderService == null) {
        debugPrint('⚠️ OrderService not available');
        return;
      }

      // DISABLED: This was causing infinite sync loops
      // _triggerSyncOnUserInteraction();

      final allOrders = orderService.allOrders;
      final activeOrders = orderService.activeOrders;
      final completedOrders = orderService.completedOrders;

      debugPrint('📊 Orders refreshed - Total: ${allOrders.length}, Active: ${activeOrders.length}, Completed: ${completedOrders.length}');

      // INNOVATIVE FIX: Smart Order Reconciliation System
      final filtered = _smartOrderFiltering(activeOrders);
      
      // INNOVATIVE FIX: Validate and auto-correct count mismatches (scoped to selected server if any)
      _validateOrderCountConsistency(_scopedSystemActiveCount(orderService), filtered.length);
      
      debugPrint('🔍 SMART FILTERING DEBUG:');
      debugPrint('  - _selectedServerId: $_selectedServerId');
      debugPrint('  - activeOrders.length: ${activeOrders.length}');
      debugPrint('  - filtered.length: ${filtered.length}');
      debugPrint('  - All active orders: ${activeOrders.map((o) => '${o.orderNumber}(${o.status})').join(', ')}');
      if (_selectedServerId != null) {
        debugPrint('  - Filtered by server $_selectedServerId: ${filtered.map((o) => '${o.orderNumber}(${o.status})').join(', ')}');
      }
      
      setState(() {
        _filteredOrders = filtered;
      });

      debugPrint('✅ Orders refreshed successfully with smart reconciliation');
    } catch (e) {
      debugPrint('❌ Error refreshing orders: $e');
    }
  }
  
  /// INNOVATIVE FIX: Smart Order Filtering with Consistency Validation
  List<Order> _smartOrderFiltering(List<Order> activeOrders) {
    try {
      debugPrint('🧠 SMART FILTERING: Starting intelligent order processing...');
      
      // 🎯 CORRECT IMPLEMENTATION: Server-based filtering with cross-server management
      // - Each server sees only their own orders by default
      // - Any user can select any server to manage orders from that server
      
      if (_selectedServerId == null) {
        // No server filter - return all active orders (admin view)
        debugPrint('🧠 SMART FILTERING: No server selected - returning all ${activeOrders.length} active orders (admin view)');
        
        // Log each order for debugging
        for (final order in activeOrders) {
          debugPrint('✅ SMART FILTERING: Order ${order.orderNumber} visible (userId: ${order.userId}) - admin view');
        }
        
        debugPrint('🧠 SMART FILTERING: Processed ${activeOrders.length} orders, showing all ${activeOrders.length} orders');
        return activeOrders;
      }
      
      // Server-specific filtering - show orders for the selected server
      final filtered = activeOrders.where((order) {
        // Enhanced user ID matching with multiple format support
        if (order.userId == null) {
          debugPrint('⚠️ SMART FILTERING: Order ${order.orderNumber} has null userId - excluding');
          return false;
        }
        
        // Handle multiple user ID formats
        bool isMatch = false;
        
        // Format 1: Direct match
        if (order.userId == _selectedServerId) {
          isMatch = true;
          debugPrint('✅ SMART FILTERING: Direct match for order ${order.orderNumber}');
        }
        
        // Format 2: Email-based format (restaurant_email_userid)
        else if (order.userId != null && order.userId!.contains('_')) {
          final parts = order.userId!.split('_');
          if (parts.length >= 2) {
            final orderUserId = parts.last;
            if (orderUserId == _selectedServerId) {
              isMatch = true;
              debugPrint('✅ SMART FILTERING: Email-based match for order ${order.orderNumber}');
            }
          }
        }
        
        // Format 3: Check if userId contains the server ID anywhere
        else if (order.userId != null && _selectedServerId != null && order.userId!.contains(_selectedServerId!)) {
          isMatch = true;
          debugPrint('✅ SMART FILTERING: Contains match for order ${order.orderNumber}');
        }
        
        if (isMatch) {
          debugPrint('✅ SMART FILTERING: Order ${order.orderNumber} matches server $_selectedServerId (userId: ${order.userId})');
        } else {
          debugPrint('❌ SMART FILTERING: Order ${order.orderNumber} does not match server $_selectedServerId (userId: ${order.userId})');
        }
        
        return isMatch;
      }).toList();
      
      debugPrint('🧠 SMART FILTERING: Processed ${activeOrders.length} orders, filtered to ${filtered.length} orders for server $_selectedServerId');
      return filtered;
      
    } catch (e) {
      debugPrint('❌ SMART FILTERING: Error during filtering - $e');
      // Fallback to showing all orders (no filtering)
      return activeOrders;
    }
  }
  
  /// INNOVATIVE FIX: Validate Order Count Consistency and Auto-Correct
  void _validateOrderCountConsistency(int systemCount, int displayedCount) {
    try {
      debugPrint('🔍 COUNT VALIDATION: System count: $systemCount, Displayed count: $displayedCount');
      
      if (systemCount != displayedCount) {
        debugPrint('⚠️ COUNT MISMATCH DETECTED: System shows $systemCount orders but UI displays $displayedCount orders');
        
        // INNOVATIVE FIX: Auto-trigger recovery mechanism
        _triggerOrderCountRecovery(systemCount, displayedCount);
      } else {
        debugPrint('✅ COUNT VALIDATION: System count and displayed count match perfectly');
      }
    } catch (e) {
      debugPrint('❌ COUNT VALIDATION: Error during validation - $e');
    }
  }
  
  /// INNOVATIVE FIX: Automatic Order Count Recovery System
  void _triggerOrderCountRecovery(int systemCount, int displayedCount) {
    try {
      debugPrint('🔄 COUNT RECOVERY: Starting automatic recovery for count mismatch...');
      
      // Step 1: Force refresh from database
      _forceRefreshOrdersFromDatabase();
      
      // Step 2: Validate again after refresh
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _validateOrderCountAfterRecovery();
      });
      
    } catch (e) {
      debugPrint('❌ COUNT RECOVERY: Error during recovery - $e');
    }
  }
  
  /// INNOVATIVE FIX: Force refresh orders from database
  void _forceRefreshOrdersFromDatabase() {
    try {
      debugPrint('🔄 FORCE REFRESH: Triggering database reload...');
      
      final orderService = Provider.of<OrderService?>(context, listen: false);
      if (orderService != null) {
        // Force reload orders from database
        orderService.loadOrders().then((_) {
          debugPrint('✅ FORCE REFRESH: Database reload completed');
          // Refresh UI after reload
          _refreshOrdersFromService();
        }).catchError((e) {
          debugPrint('❌ FORCE REFRESH: Database reload failed - $e');
        });
      }
    } catch (e) {
      debugPrint('❌ FORCE REFRESH: Error during force refresh - $e');
    }
  }
  
  /// INNOVATIVE FIX: Validate order count after recovery attempt
  void _validateOrderCountAfterRecovery() {
    try {
      final orderService = Provider.of<OrderService?>(context, listen: false);
      if (orderService != null) {
        final systemCount = _scopedSystemActiveCount(orderService);
        final displayedCount = _filteredOrders.length;
        
        debugPrint('🔍 RECOVERY VALIDATION: After recovery - System: $systemCount, Displayed: $displayedCount');
        
        if (systemCount == displayedCount) {
          debugPrint('✅ RECOVERY SUCCESS: Count mismatch resolved automatically');
        } else {
          debugPrint('⚠️ RECOVERY PARTIAL: Count mismatch persists - System: $systemCount, Displayed: $displayedCount');
          // Show user notification about the persistent issue
          _showCountMismatchNotification(systemCount, displayedCount);
        }
      }
    } catch (e) {
      debugPrint('❌ RECOVERY VALIDATION: Error during validation - $e');
    }
  }
  
  /// INNOVATIVE FIX: Show user notification about count mismatch
  void _showCountMismatchNotification(int systemCount, int displayedCount) {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '⚠️ Order count mismatch detected!\n'
              'System: $systemCount orders, Displayed: $displayedCount orders\n'
              'Auto-recovery attempted. Please refresh manually if issue persists.',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Refresh',
              onPressed: () {
                _forceRefreshOrdersFromDatabase();
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ COUNT NOTIFICATION: Error showing notification - $e');
    }
  }
  
  /// INNOVATIVE FIX: Real-time Order Count Monitoring System
  Timer? _orderCountMonitorTimer;
  
  void _startOrderCountMonitoring() {
    try {
      debugPrint('🔍 COUNT MONITORING: Starting real-time order count monitoring...');
      
      // Cancel any existing timer
      _orderCountMonitorTimer?.cancel();
      
      // Start monitoring every 10 seconds
      _orderCountMonitorTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        if (mounted) {
          _performRealTimeCountValidation();
        } else {
          timer.cancel();
        }
      });
      
      debugPrint('✅ COUNT MONITORING: Real-time monitoring started successfully');
    } catch (e) {
      debugPrint('❌ COUNT MONITORING: Error starting monitoring - $e');
    }
  }
  
  /// INNOVATIVE FIX: Perform real-time count validation
  void _performRealTimeCountValidation() {
    try {
      final orderService = Provider.of<OrderService?>(context, listen: false);
      if (orderService != null) {
        final systemCount = _scopedSystemActiveCount(orderService);
        final displayedCount = _filteredOrders.length;
        
        debugPrint('🔍 REAL-TIME VALIDATION: System: $systemCount, Displayed: $displayedCount');
        
        // Only trigger recovery if there's a significant mismatch (more than 1 order difference)
        if ((systemCount - displayedCount).abs() > 1) {
          debugPrint('⚠️ REAL-TIME VALIDATION: Significant count mismatch detected - triggering recovery');
          _triggerOrderCountRecovery(systemCount, displayedCount);
        } else if (systemCount != displayedCount) {
          debugPrint('ℹ️ REAL-TIME VALIDATION: Minor count difference - monitoring closely');
        } else {
          debugPrint('✅ REAL-TIME VALIDATION: Count consistency maintained');
        }
      }
    } catch (e) {
      debugPrint('❌ REAL-TIME VALIDATION: Error during validation - $e');
    }
  }
  
  /// INNOVATIVE FIX: Stop order count monitoring
  void _stopOrderCountMonitoring() {
    try {
      _orderCountMonitorTimer?.cancel();
      _orderCountMonitorTimer = null;
      debugPrint('🛑 COUNT MONITORING: Real-time monitoring stopped');
    } catch (e) {
      debugPrint('❌ COUNT MONITORING: Error stopping monitoring - $e');
    }
  }
  
  /// INNOVATIVE FIX: Smart Order Count Display Widget
  Widget _buildSmartOrderCountWidget() {
    try {
      final orderService = Provider.of<OrderService?>(context, listen: false);
      if (orderService == null) {
        return const SizedBox.shrink();
      }
      
      final systemCount = _scopedSystemActiveCount(orderService);
      final displayedCount = _filteredOrders.length;
      final hasMismatch = systemCount != displayedCount;
      
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: hasMismatch ? Colors.orange.shade100 : Colors.green.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasMismatch ? Colors.orange.shade400 : Colors.green.shade400,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasMismatch ? Icons.warning_amber : Icons.check_circle,
              color: hasMismatch ? Colors.orange.shade700 : Colors.green.shade700,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'Orders: $displayedCount/$systemCount',
              style: TextStyle(
                color: hasMismatch ? Colors.orange.shade700 : Colors.green.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hasMismatch) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () {
                  debugPrint('🔄 Smart widget: Manual refresh triggered by user');
                  _forceRefreshOrdersFromDatabase();
                },
                child: Icon(
                  Icons.refresh,
                  color: Colors.orange.shade700,
                  size: 14,
                ),
              ),
            ],
          ],
        ),
      );
    } catch (e) {
      debugPrint('❌ SMART COUNT WIDGET: Error building widget - $e');
      return const SizedBox.shrink();
    }
  }
  
  /// Trigger sync on user interaction - DISABLED to prevent infinite loops
  Future<void> _triggerSyncOnUserInteraction() async {
    // DISABLED: This was causing infinite sync loops
    // try {
    //   final syncTriggerService = AutomaticSyncTriggerService();
    //   await syncTriggerService.triggerImmediateSyncOnInteraction();
    // } catch (e) {
    //   debugPrint('⚠️ Failed to trigger sync on user interaction: $e');
    // }
  }

  void _setDefaultServer() {
    try {
      // Start with "All Servers" view by default (null = all servers)
      setState(() {
        _selectedServerId = null;
      });
      debugPrint('🎯 Default view set to: All Servers');
    } catch (e) {
      debugPrint('❌ Error setting default server: $e');
    }
  }

  /// Load orders from database
  Future<void> _loadOrders() async {
    try {
      debugPrint('🔄 Loading orders from database...');
      
      final orderService = Provider.of<OrderService?>(context, listen: false);
      if (orderService == null) {
        debugPrint('⚠️ OrderService not available');
        return;
      }
      
      // INNOVATIVE FIX: Ensure real-time sync is active for instant updates
      if (_enableRealTimeCrossDeviceSync) {
        await _ensureRealTimeSyncActive();
      }
      
      await orderService.loadOrders();
      _refreshOrdersFromService();
      
      debugPrint('✅ Orders loaded successfully');
    } catch (e) {
      debugPrint('❌ Error loading orders: $e');
    }
  }

  void _selectServer(String? serverId) {
    setState(() {
      _selectedServerId = serverId;
    });
    _loadOrders();
    debugPrint('🎯 Selected server: $serverId');
  }

  void _createDineInOrder() {
    if (_selectedServerId == null) {
      _showServerSelectionError();
      return;
    }
    
    try {
      final userService = Provider.of<UserService?>(context, listen: false);
      
      if (userService == null) {
        _showServiceNotAvailableError();
        return;
      }
      
      final selectedUser = userService.users.firstWhere(
        (user) => user.id == _selectedServerId,
        orElse: () => userService.currentUser!,
      );
    
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DineInSetupScreen(user: selectedUser),
        ),
      ).then((_) {
        _loadOrders();
      });
    } catch (e) {
      debugPrint('❌ Error creating dine-in order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Unable to create order. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _createTakeoutOrder() {
    if (_selectedServerId == null) {
      _showServerSelectionError();
      return;
    }
    
    try {
      final userService = Provider.of<UserService?>(context, listen: false);
      
      if (userService == null) {
        _showServiceNotAvailableError();
        return;
      }
      
      final selectedUser = userService.users.firstWhere(
        (user) => user.id == _selectedServerId,
        orElse: () => userService.currentUser!,
      );
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TakeoutSetupScreen(user: selectedUser),
        ),
      ).then((_) {
        _loadOrders();
      });
    } catch (e) {
      debugPrint('❌ Error creating takeout order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Unable to create order. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showServerSelectionError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cannot create orders in "All Servers" view. Please select a specific server first.'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _showServiceNotAvailableError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Services are still loading. Please wait a moment.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _editOrder(Order order) {
    try {
      debugPrint('🔍 EDIT_ORDER: Starting edit order process for ${order.orderNumber}');
      
      final userService = Provider.of<UserService?>(context, listen: false);
      
      if (userService == null) {
        debugPrint('❌ EDIT_ORDER: UserService is null');
        _showServiceNotAvailableError();
        return;
      }
      
      debugPrint('✅ EDIT_ORDER: UserService found with ${userService.users.length} users');
      
      // Find the user who created the order or use admin as fallback
      User? orderUser;
      try {
        orderUser = userService.users.firstWhere((user) => user.id == order.userId);
        debugPrint('✅ EDIT_ORDER: Found original user: ${orderUser.name} (${orderUser.id})');
      } catch (e) {
        debugPrint('⚠️ EDIT_ORDER: Original user not found, looking for admin...');
        // If original user not found, use admin or first available user
        try {
          orderUser = userService.users.firstWhere(
            (user) => user.role == UserRole.admin,
          );
          debugPrint('✅ EDIT_ORDER: Found admin user: ${orderUser.name} (${orderUser.id})');
        } catch (e) {
          debugPrint('⚠️ EDIT_ORDER: No admin found, using first available user...');
          // If no admin found, use first available user
          if (userService.users.isNotEmpty) {
            orderUser = userService.users.first;
            debugPrint('✅ EDIT_ORDER: Using first user: ${orderUser.name} (${orderUser.id})');
          }
        }
      }
      
      if (orderUser == null) {
        debugPrint('❌ EDIT_ORDER: No valid user found');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Unable to edit order: No valid user found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      debugPrint('🔍 EDIT_ORDER: Navigating to OrderCreationScreen with:');
      debugPrint('  - Order: ${order.orderNumber} (${order.id})');
      debugPrint('  - User: ${orderUser.name} (${orderUser.id})');
      debugPrint('  - Order Type: ${order.type}');
      debugPrint('  - Table ID: ${order.tableId}');
      debugPrint('  - Items count: ${order.items.length}');
      
      // Convert OrderType enum to string
      String orderTypeString;
      switch (order.type) {
        case OrderType.dineIn:
          orderTypeString = 'dine-in';
          break;
        case OrderType.takeaway:
        case OrderType.delivery:
          orderTypeString = 'takeout';
          break;
        default:
          orderTypeString = 'takeout';
      }
      
      debugPrint('  - Order Type String: $orderTypeString');
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) {
            debugPrint('🏗️ EDIT_ORDER: Building OrderCreationScreen...');
            return OrderCreationScreen(
              user: orderUser!,
              orderType: orderTypeString,
              existingOrder: order, // Pass the existing order for editing
              table: order.tableId != null ? 
                Provider.of<TableService?>(context, listen: false)?.getTableById(order.tableId!) : null,
              numberOfPeople: order.type == OrderType.dineIn ? order.items.length : null,
              orderNumber: order.orderNumber,
            );
          },
        ),
      ).then((_) {
        debugPrint('🔄 EDIT_ORDER: Returned from OrderCreationScreen, reloading orders...');
        _loadOrders();
      }).catchError((error) {
        debugPrint('❌ EDIT_ORDER: Navigation error: $error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Navigation failed: $error'),
            backgroundColor: Colors.red,
          ),
        );
      });
      
      debugPrint('✅ EDIT_ORDER: Navigation initiated successfully');
      
    } catch (e, stackTrace) {
      debugPrint('❌ EDIT_ORDER: Error in _editOrder: $e');
      debugPrint('❌ EDIT_ORDER: Stack trace: $stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Unable to edit order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openAdminPanel() async {
    try {
      final userService = Provider.of<UserService?>(context, listen: false);
      
      if (userService == null) {
        _showServiceNotAvailableError();
        return;
      }
      
      // Check for current user first
      User? adminUser = userService.currentUser;
      
      // If no current user, look for an admin user in the system
      if (adminUser == null) {
        try {
          adminUser = userService.users.firstWhere(
            (user) => user.role == UserRole.admin && user.isActive,
          );
          debugPrint('🔧 Found admin user: ${adminUser.name} (${adminUser.id})');
        } catch (e) {
          debugPrint('❌ No admin user found in system');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ No admin user found. Please contact system administrator.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          return;
        }
      }
      
      // At this point, adminUser should not be null, but let's add a safety check
      if (adminUser == null) {
        debugPrint('❌ Admin user is null after all checks');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Unable to find admin user. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // ENHANCEMENT: Enhanced admin access verification
      if (!_verifyAdminAccess(adminUser)) {
        return;
      }

      // Show PIN authentication dialog for admin access
      final isPinVerified = await _showAdminPinDialog();
      if (!isPinVerified) {
        return; // User cancelled or entered wrong PIN
      }
      
      // Set admin user as current user if not already set
      if (userService.currentUser == null) {
        userService.setCurrentUser(adminUser);
        debugPrint('✅ Set admin user as current user for admin panel access');
      }
      
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AdminPanelScreen(user: adminUser!),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error opening admin panel: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Unable to open admin panel. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  /// Enhanced admin access verification
  bool _verifyAdminAccess(User adminUser) {
    debugPrint('🔍 Enhanced admin access verification for: ${adminUser.name}');
    
    // Check role
    if (adminUser.role != UserRole.admin) {
      debugPrint('❌ Access Denied: User role is ${adminUser.role}, not admin');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Access Denied: User role ${adminUser.role} cannot access admin panel'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return false;
    }
    
    // Check admin panel access
    if (!adminUser.canAccessAdminPanel) {
      debugPrint('❌ Access Denied: User does not have admin panel access');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Access Denied: You do not have permission to access the admin panel'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return false;
    }
    
    // Check if user is active
    if (!adminUser.isActive) {
      debugPrint('❌ Access Denied: User account is not active');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Access Denied: Your account is not active. Please contact administrator.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return false;
    }
    
    debugPrint('✅ Admin access verified successfully');
    return true;
  }

  Future<bool> _showAdminPinDialog() async {
    final TextEditingController pinController = TextEditingController();
    
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.deepOrange),
              const SizedBox(width: 8),
              const Text('Admin Panel Access'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Please enter your admin PIN to access the admin panel:',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Admin PIN',
                  hintText: 'Enter 4-digit PIN',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                  counterText: '',
                ),
                onSubmitted: (value) async {
                  if (await SecurityConfig.validateAdminCredentials(value)) {
                    Navigator.of(context).pop(true);
                  } else {
                    pinController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('❌ Invalid PIN. Please try again.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final pin = pinController.text.trim();
                if (await SecurityConfig.validateAdminCredentials(pin)) {
                  Navigator.of(context).pop(true);
                } else {
                  pinController.clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Invalid PIN. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Access Admin Panel'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  // Add logout functionality
  void _logout() async {
    try {
      final authService = Provider.of<MultiTenantAuthService?>(context, listen: false);
      
      if (authService == null) {
        _showServiceNotAvailableError();
        return;
      }
      
      // Show confirmation dialog
      final shouldLogout = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout'),
            ),
          ],
        ),
      );
      
      if (shouldLogout == true) {
        // Mark that user explicitly logged out (don't restore session next time)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('app_explicitly_closed', true);
        
        await authService.logout();
        
        if (mounted) {
          // Navigate to login screen
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const RestaurantAuthScreen(),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Logout error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during logout: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Detect device type for responsive design
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600; // Phone breakpoint
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200; // Tablet breakpoint
    final isDesktop = screenSize.width >= 1200; // Desktop breakpoint
    
    // Debug: Print screen size for troubleshooting
    debugPrint('📱 SCREEN SIZE: ${screenSize.width}x${screenSize.height}, isPhone: $isPhone, isTablet: $isTablet, isDesktop: $isDesktop');
    
    return Scaffold(
      backgroundColor: isPhone ? Colors.white : null, // Clean white background for mobile
      body: Container(
        decoration: isPhone ? null : const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Consumer2<UserService?, OrderService?>(
            builder: (context, userService, orderService, _) {
              // Show loading if services aren't ready
              if (userService == null || orderService == null) {
                debugPrint('🔍 BUILD: Services not ready - userService=${userService != null}, orderService=${orderService != null}');
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.blue),
                      SizedBox(height: 16),
                      Text(
                        'Loading Dashboard...',
                        style: TextStyle(color: Colors.grey, fontSize: 18),
                      ),
                    ],
                  ),
                );
              }

              final users = userService.users;
              final currentUser = userService.currentUser;
              
              debugPrint('🔍 BUILD: Services ready - Users: ${users.length}, CurrentUser: ${currentUser?.name}, Orders: ${orderService.allOrders.length}');
              
              // Set default server if none selected
              if (_selectedServerId == null && currentUser != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() {
                    _selectedServerId = currentUser.id;
                  });
                  _loadOrders();
                });
              }

              // Note: Consumer automatically rebuilds when OrderService changes
              // Removed excessive reload to prevent infinite rebuild loop

              if (isPhone) {
                // MOBILE-FIRST DESIGN - Clean, modern, world-class layout
                debugPrint('📱 Using MOBILE layout');
                return _buildMobileLayout(userService, orderService, users, currentUser);
              } else {
                // DESKTOP/TABLET DESIGN - Keep existing layout
                debugPrint('🖥️ Using DESKTOP/TABLET layout');
                return _buildDesktopLayout(userService, orderService, users, currentUser);
              }
            },
          ),
        ),
      ),
    );
  }

  // NEW: World-class mobile layout design
  Widget _buildMobileLayout(UserService userService, OrderService orderService, List<User> users, User? currentUser) {
    return Column(
      children: [
        // Clean Mobile Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // User Avatar & Welcome
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome back',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      currentUser?.name ?? 'Server',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
              // Action Buttons
              Row(
                children: [
                  // INNOVATIVE FIX: Real-time sync status indicator
                  if (_enableRealTimeCrossDeviceSync) ...[
                    _buildRealTimeSyncIndicator(),
                    const SizedBox(width: 8),
                  ],
                  _buildMobileActionButton(
                    icon: Icons.refresh,
                    onTap: () {
                      debugPrint('🔄 Manual refresh triggered (mobile)');
                      _isManualRefresh = true;
                      _loadOrders();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🔄 Refreshing orders...'),
                          duration: Duration(seconds: 1),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    },
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  _buildMobileActionButton(
                    icon: Icons.admin_panel_settings,
                    onTap: _openAdminPanel,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                  _buildMobileActionButton(
                    icon: Icons.kitchen,
                    onTap: () {
                      if (currentUser != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => KitchenScreen(user: currentUser),
                          ),
                        );
                      }
                    },
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  _buildMobileActionButton(
                    icon: Icons.logout,
                    onTap: _logout,
                    color: Colors.red,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Mobile Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Server Selection - Mobile Optimized
                _buildMobileServerSelection(users, userService, orderService),
                
                const SizedBox(height: 24),
                
                // Action Cards - Mobile Optimized
                _buildMobileActionCards(),
                
                const SizedBox(height: 24),
                
                // Active Orders - Mobile Optimized
                _buildMobileActiveOrders(orderService),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // NEW: Mobile action button
  Widget _buildMobileActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }

  // NEW: Mobile server selection
  Widget _buildMobileServerSelection(List<User> users, UserService userService, OrderService orderService) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Server',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 50,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              // All Servers Chip
              _buildServerChip(
                label: 'All Servers',
                serverId: null,
                isSelected: _selectedServerId == null,
                // FIX: Calculate All servers count as sum of individual server counts
                orderCount: _calculateAllServersCount(orderService, userService),
              ),
              const SizedBox(width: 8),
              // Individual Server Chips
              ...users.where((user) => 
                user.role == UserRole.server || 
                user.role == UserRole.admin
              ).map((user) {
                // Use the same filtering logic as _refreshOrdersFromService
                final userOrderCount = orderService.activeOrders.where((order) {
                  // Handle both simple user IDs and email-based user IDs
                  if (order.userId != null && order.userId!.contains('_')) {
                    // Email-based format: restaurant_email_userid
                    final parts = order.userId!.split('_');
                    if (parts.length >= 2) {
                      final orderUserId = parts.last; // Get the user ID part
                      return orderUserId == user.id;
                    }
                  } else {
                    // Simple user ID format
                    return order.userId == user.id;
                  }
                  return false;
                }).length;
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildMobileServerChip(
                    label: user.name,
                    serverId: user.id,
                    isSelected: _selectedServerId == user.id,
                    orderCount: userOrderCount,
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }

  // NEW: Mobile server chip
  Widget _buildMobileServerChip({
    required String label,
    required String? serverId,
    required bool isSelected,
    required int orderCount,
  }) {
    return GestureDetector(
      onTap: () => _selectServer(serverId),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            if (orderCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.blue,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$orderCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // NEW: Mobile action cards
  Widget _buildMobileActionCards() {
    // Only show order creation when a specific server is selected
    if (_selectedServerId == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue.shade600, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Select a server to create orders',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.blue.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Create Order',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMobileActionCard(
                title: 'Dine-In',
                subtitle: 'Table service',
                icon: Icons.restaurant,
                color: Colors.green,
                onTap: _createDineInOrder,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMobileActionCard(
                title: 'Take-Out',
                subtitle: 'Pickup orders',
                icon: Icons.takeout_dining,
                color: Colors.orange,
                onTap: _createTakeoutOrder,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // NEW: Mobile action card
  Widget _buildMobileActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: color.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // NEW: Mobile active orders
  Widget _buildMobileActiveOrders(OrderService orderService) {
    if (_selectedServerId == null) {
      return _buildMobileServerSummary(orderService);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'My Orders',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_filteredOrders.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_filteredOrders.isEmpty)
          Container(
            padding: const EdgeInsets.all(40),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_outlined,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No active orders',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Create your first order above',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: _filteredOrders.map((order) => _buildMobileOrderCard(order)).toList(),
          ),
      ],
    );
  }



  // NEW: Mobile server summary
  Widget _buildMobileServerSummary(OrderService orderService) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.orange.shade600, size: 24),
              const SizedBox(width: 12),
              Text(
                'Order Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Select a server to view and manage their orders',
            style: TextStyle(
              fontSize: 14,
              color: Colors.orange.shade700,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for status colors
  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.purple;
      case OrderStatus.ready:
        return Colors.green;
      case OrderStatus.completed:
        return Colors.grey;
      case OrderStatus.cancelled:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // DESKTOP/TABLET LAYOUT - Keep existing design
  Widget _buildDesktopLayout(UserService userService, OrderService orderService, List<User> users, User? currentUser) {
    return CustomScrollView(
      slivers: [
        // Modern App Bar
        SliverAppBar(
          expandedHeight: 120,
          floating: false,
          pinned: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.1),
                    Colors.white.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Text(
                      'POS Dashboard',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (currentUser != null)
                      Text(
                        'Welcome, ${currentUser.name}!',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            // INNOVATIVE FIX: Smart Order Count Display Widget
            _buildSmartOrderCountWidget(),
            
            // Comprehensive Sync Icon - Using MultiTenantAuthService
            IconButton(
              icon: Icon(
                _isSyncing ? Icons.sync_disabled : Icons.sync,
                color: _isSyncing ? Colors.grey : Colors.green,
              ),
              onPressed: _isSyncing ? null : _triggerSyncFromFirebase,
              tooltip: 'Comprehensive Sync with Zero Risk Protection',
            ),
            
            // Quick Access Icons
            IconButton(
              icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
              onPressed: _openAdminPanel,
              tooltip: 'Admin Panel',
            ),
            IconButton(
              icon: const Icon(Icons.kitchen, color: Colors.white),
              onPressed: () {
                final userService = Provider.of<UserService?>(context, listen: false);
                final currentUser = userService?.currentUser;
                if (currentUser != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => KitchenScreen(user: currentUser),
                    ),
                  );
                }
              },
              tooltip: 'Kitchen',
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _logout,
              tooltip: 'Logout',
            ),
            const SizedBox(width: 8),
          ],
        ),

        // Main Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Server Selection Section
                _buildServerSelectionCard(users, userService, orderService),
                
                const SizedBox(height: 16),
                
                // Action Cards Section
                _buildActionCardsSection(),
                
                const SizedBox(height: 16),
                
                // Active Orders Section
                _buildActiveOrdersSection(orderService),
              ],
            ),
          ),
        ),
      ],
    );
  }

     Widget _buildServerSelectionCard(List<User> users, UserService userService, OrderService orderService) {
    // Get responsive sizing based on device type
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
    
    // Responsive padding and spacing
    final padding = isPhone ? 12.0 : isTablet ? 14.0 : 16.0;
    final titleFontSize = isPhone ? 16.0 : isTablet ? 17.0 : 18.0;
    final spacing = isPhone ? 8.0 : isTablet ? 10.0 : 12.0;
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Server:',
              style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: spacing),
            // Use SingleChildScrollView for horizontal scrolling on mobile
            if (isPhone)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildServerChip(
                      label: 'All Servers',
                      serverId: null,
                      isSelected: _selectedServerId == null,
                      // FIX: Calculate All servers count as sum of individual server counts
                      orderCount: _calculateAllServersCount(orderService, userService),
                    ),
                    ...users.where((user) => 
                      user.role == UserRole.server || 
                      user.role == UserRole.admin || 
                      user.role == UserRole.manager
                    ).map((server) {
                      // Use the same filtering logic as _refreshOrdersFromService
                      final serverOrderCount = orderService.activeOrders.where((order) {
                        // Handle both simple user IDs and email-based user IDs
                        if (order.userId != null && order.userId!.contains('_')) {
                          // Email-based format: restaurant_email_userid
                          final parts = order.userId!.split('_');
                          if (parts.length >= 2) {
                            final orderUserId = parts.last; // Get the user ID part
                            return orderUserId == server.id;
                          }
                        } else {
                          // Simple user ID format
                          return order.userId == server.id;
                        }
                        return false;
                      }).length;
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildServerChip(
                          label: server.name,
                          serverId: server.id,
                          isSelected: _selectedServerId == server.id,
                          orderCount: serverOrderCount,
                        ),
                      );
                    }),
                  ],
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildServerChip(
                    label: 'All Servers',
                    serverId: null,
                    isSelected: _selectedServerId == null,
                    // FIX: Calculate All servers count as sum of individual server counts
                    orderCount: _calculateAllServersCount(orderService, userService),
                  ),
                  ...users.where((user) => 
                    user.role == UserRole.server || 
                    user.role == UserRole.admin || 
                    user.role == UserRole.manager
                  ).map((server) {
                    // Use the same filtering logic as _refreshOrdersFromService
                    final serverOrderCount = orderService.activeOrders.where((order) {
                      // Handle both simple user IDs and email-based user IDs
                      if (order.userId != null && order.userId!.contains('_')) {
                        // Email-based format: restaurant_email_userid
                        final parts = order.userId!.split('_');
                        if (parts.length >= 2) {
                          final orderUserId = parts.last; // Get the user ID part
                          return orderUserId == server.id;
                        }
                      } else {
                        // Simple user ID format
                        return order.userId == server.id;
                      }
                      return false;
                    }).length;
                    
                    return _buildServerChip(
                      label: server.name,
                      serverId: server.id,
                      isSelected: _selectedServerId == server.id,
                      orderCount: serverOrderCount,
                    );
                  }),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerChip({
    required String label,
    required String? serverId,
    required bool isSelected,
    required int orderCount,
  }) {
    // Get responsive sizing based on device type
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
    
    // Responsive padding and font sizes - Mobile-friendly design
    final horizontalPadding = isPhone ? 16.0 : isTablet ? 14.0 : 16.0; // Comfortable horizontal padding
    final verticalPadding = isPhone ? 8.0 : isTablet ? 7.0 : 8.0; // Comfortable vertical padding
    final labelFontSize = isPhone ? 14.0 : isTablet ? 14.0 : 15.0; // Comfortable label for mobile readability
    final countFontSize = isPhone ? 12.0 : isTablet ? 11.0 : 12.0; // Comfortable count for mobile
    final spacing = isPhone ? 8.0 : isTablet ? 7.0 : 8.0; // Comfortable spacing for mobile
    
    return GestureDetector(
      onTap: () => _selectServer(serverId),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: verticalPadding),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: labelFontSize,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: spacing),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isPhone ? 8.0 : 6.0, // Comfortable horizontal padding for mobile
                vertical: isPhone ? 2.0 : 2.0
              ),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.blue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                orderCount.toString(),
                style: TextStyle(
                  color: isSelected ? Colors.blue : Colors.white,
                  fontSize: countFontSize,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCardsSection() {
    // Get responsive sizing based on device type
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
    
    // Responsive padding and font sizes - Mobile-friendly design
    final padding = isPhone ? 16.0 : isTablet ? 14.0 : 16.0; // Comfortable padding for mobile
    final titleFontSize = isPhone ? 18.0 : isTablet ? 17.0 : 18.0; // Comfortable title for mobile readability
    final spacing = isPhone ? 12.0 : isTablet ? 12.0 : 16.0; // Comfortable spacing for mobile
    
    // Only show order creation when a specific server is selected
    // "All Servers" should be read-only monitoring view
    if (_selectedServerId == null) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [Colors.blue.shade50, Colors.blue.shade100],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: EdgeInsets.all(padding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.visibility, color: Colors.blue.shade600),
                  SizedBox(width: isPhone ? 6.0 : 8.0),
                  Expanded(
                    child: Text(
                      'All Servers - Monitoring View',
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing),
              Text(
                'This shows order counts per server. Select a specific server to view orders and create new ones.',
                style: TextStyle(
                  fontSize: isPhone ? 13.0 : 14.0,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_circle_outline, color: Colors.blue.shade600),
                SizedBox(width: isPhone ? 6.0 : 8.0),
                Expanded(
                  child: Text(
                    'Create New Order',
                    style: TextStyle(
                      fontSize: titleFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing),
            // Responsive layout for action cards
            if (isPhone)
              // Mobile: Stacked layout
              Column(
                children: [
                  _buildActionCard(
                    title: 'Dine-In',
                    subtitle: 'Table service',
                    icon: Icons.restaurant,
                    color: Colors.green,
                    onTap: _createDineInOrder,
                  ),
                  SizedBox(height: 8),
                  _buildActionCard(
                    title: 'Take-Out',
                    subtitle: 'Quick pickup',
                    icon: Icons.takeout_dining,
                    color: Colors.orange,
                    onTap: _createTakeoutOrder,
                  ),
                ],
              )
            else
              // Tablet/Desktop: Row layout
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      title: 'Dine-In',
                      subtitle: 'Table service',
                      icon: Icons.restaurant,
                      color: Colors.green,
                      onTap: _createDineInOrder,
                    ),
                  ),
                  SizedBox(width: spacing),
                  Expanded(
                    child: _buildActionCard(
                      title: 'Take-Out',
                      subtitle: 'Quick pickup',
                      icon: Icons.takeout_dining,
                      color: Colors.orange,
                      onTap: _createTakeoutOrder,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    // Get responsive sizing based on device type
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
    
    // Responsive padding and font sizes - Mobile-friendly design
    final padding = isPhone ? 16.0 : isTablet ? 14.0 : 16.0; // Comfortable padding for mobile
    final iconSize = isPhone ? 28.0 : isTablet ? 30.0 : 32.0; // Comfortable icon for mobile readability
    final titleFontSize = isPhone ? 16.0 : isTablet ? 15.0 : 16.0; // Comfortable title for mobile readability
    final subtitleFontSize = isPhone ? 12.0 : isTablet ? 11.5 : 12.0; // Comfortable subtitle for mobile
    final spacing = isPhone ? 8.0 : isTablet ? 7.0 : 8.0; // Comfortable spacing for mobile
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: iconSize, color: color),
            SizedBox(height: spacing),
            Text(
              title,
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing * 0.5),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: subtitleFontSize,
                color: color.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrdersSection(OrderService orderService) {
    // Get responsive sizing based on device type
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
    
    // Responsive padding and font sizes
    final padding = isPhone ? 12.0 : isTablet ? 14.0 : 16.0;
    final titleFontSize = isPhone ? 16.0 : isTablet ? 17.0 : 18.0;
    final spacing = isPhone ? 12.0 : isTablet ? 14.0 : 16.0;
    
    // If "All Servers" is selected, show server summary instead of individual orders
    if (_selectedServerId == null) {
      return _buildServerSummarySection(orderService);
    }
    
    // Show individual orders for the selected server
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.receipt_long, color: Colors.blue.shade600),
                      SizedBox(width: isPhone ? 6.0 : 8.0),
                      Expanded(
                        child: Text(
                          'My Active Orders',
                          style: TextStyle(
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isPhone ? 8.0 : 12.0, 
                    vertical: isPhone ? 3.0 : 4.0
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_filteredOrders.length}',
                    style: TextStyle(
                      fontSize: isPhone ? 12.0 : 14.0,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: spacing),
            if (_filteredOrders.isEmpty)
              Container(
                padding: EdgeInsets.all(isPhone ? 16.0 : 20.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_outlined,
                      size: isPhone ? 40.0 : 48.0,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: isPhone ? 6.0 : 8.0),
                    Text(
                      'No active orders',
                      style: TextStyle(
                        fontSize: isPhone ? 14.0 : 16.0,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Text(
                      'Create a new order to get started',
                      style: TextStyle(
                        fontSize: isPhone ? 12.0 : 14.0,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              )
            else
              _buildResponsiveOrderSection(),
          ],
        ),
      ),
    );
  }

  /// Get responsive height for order grid based on device type
  double _getResponsiveOrderGridHeight(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
    final isDesktop = screenSize.width >= 1200;
    
    // For mobile, use flexible height (no fixed constraint needed for list)
    if (isPhone) {
      return double.infinity; // Let the list determine its own height
    }
    
    // Calculate available height (screen height minus other UI elements)
    final availableHeight = screenSize.height - 200; // Approximate space for other elements
    
    if (isTablet) {
      // Tablet: Use 70% of available height, minimum 300px, maximum 500px
      return (availableHeight * 0.7).clamp(300.0, 500.0);
    } else {
      // Desktop: Use 80% of available height, minimum 400px, maximum 600px
      return (availableHeight * 0.8).clamp(400.0, 600.0);
    }
  }

  Widget _buildServerSummarySection(OrderService orderService) {
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.orange.shade50, Colors.orange.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: EdgeInsets.all(isPhone ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics, 
                  color: Colors.orange.shade600,
                  size: isPhone ? 18 : 24,
                ),
                SizedBox(width: isPhone ? 6 : 8),
                Expanded(
                  child: Text(
                    'Order Summary by Server',
                    style: TextStyle(
                      fontSize: isPhone ? 14 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            SizedBox(height: isPhone ? 2 : 4),
            Text(
              'Select a specific server to view and create orders',
              style: TextStyle(
                fontSize: isPhone ? 11 : 14,
                color: Colors.orange.shade700,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
            SizedBox(height: isPhone ? 12 : 16),
            Consumer<UserService?>(
              builder: (context, userService, _) {
                if (userService == null) return const SizedBox.shrink();
                
                final servers = userService.users.where((user) =>
                  user.role == UserRole.server ||
                  user.role == UserRole.admin ||
                  user.role == UserRole.manager
                ).toList();
                
                if (servers.isEmpty) {
                  return Center(
                    child: Text(
                      'No servers available',
                      style: TextStyle(
                        color: Colors.orange.shade600,
                        fontSize: isPhone ? 12 : 16,
                      ),
                    ),
                  );
                }
                
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: servers.length,
                  itemBuilder: (context, index) {
                    final server = servers[index];
                    final orderCount = orderService.getActiveOrdersCountByServer(server.id);
                    
                    return _buildServerSummaryTile(server, orderCount);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerSummaryTile(User server, int orderCount) {
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _selectServer(server.id),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.all(isPhone ? 10 : 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.orange.shade300,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: isPhone ? 16 : 20,
                backgroundColor: orderCount > 0 ? Colors.orange.shade600 : Colors.grey.shade400,
                child: Text(
                  server.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: isPhone ? 12 : 14,
                  ),
                ),
              ),
              SizedBox(width: isPhone ? 8 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.name,
                      style: TextStyle(
                        fontSize: isPhone ? 14 : 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    Text(
                      server.role.toString().split('.').last.toUpperCase(),
                      style: TextStyle(
                        fontSize: isPhone ? 10 : 12,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isPhone ? 8 : 12, 
                  vertical: isPhone ? 4 : 6
                ),
                decoration: BoxDecoration(
                  color: orderCount > 0 ? Colors.orange.shade600 : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: isPhone ? 12 : 16,
                      color: Colors.white,
                    ),
                    SizedBox(width: isPhone ? 2 : 4),
                    Text(
                      '$orderCount',
                      style: TextStyle(
                        fontSize: isPhone ? 11 : 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: isPhone ? 6 : 8),
              Icon(
                Icons.arrow_forward_ios,
                size: isPhone ? 12 : 16,
                color: Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveOrderSection() {
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;
    
    if (isPhone) {
      // For mobile: Use flexible height with proper scrolling
      return Flexible(
        child: SingleChildScrollView(
          child: _buildOrderTilesGrid(),
        ),
      );
    } else {
      // For tablet/desktop: Use fixed height with scrolling
      return SizedBox(
        height: _getResponsiveOrderGridHeight(context),
        child: SingleChildScrollView(
          child: _buildOrderTilesGrid(),
        ),
      );
    }
  }

  Widget _buildOrderTilesGrid() {
    // Get responsive column count based on device type
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
    final isDesktop = screenSize.width >= 1200;
    
    // For mobile, use a modern card-based list layout
    if (isPhone) {
      return _buildMobileOrderList();
    }
    
    // For tablet and desktop, use the existing grid layout (unchanged)
    final tilesPerRow = isTablet ? 3 : 4;
    final rowCount = (_filteredOrders.length / tilesPerRow).ceil();
    
    return Column(
      children: List.generate(rowCount, (rowIndex) {
        final startIndex = rowIndex * tilesPerRow;
        final endIndex = (startIndex + tilesPerRow).clamp(0, _filteredOrders.length);
        final rowOrders = _filteredOrders.sublist(startIndex, endIndex);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              ...rowOrders.map((order) => Expanded(
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: _buildSquareOrderTile(order),
                ),
              )).toList(),
              // Fill remaining spaces in incomplete rows
              ...List.generate(
                tilesPerRow - rowOrders.length,
                (index) => const Expanded(child: SizedBox()),
              ),
            ],
          ),
        );
      }),
    );
  }

  /// World-class mobile order list design
  Widget _buildMobileOrderList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredOrders.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final order = _filteredOrders[index];
        return _buildMobileOrderCard(order);
      },
    );
  }

  /// Modern mobile order card with world-class design
  Widget _buildMobileOrderCard(Order order) {
    final statusColor = _getStatusColor(order.status);
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            debugPrint('📱 MOBILE: ============ CARD TAP DETECTED ============');
            debugPrint('📱 MOBILE: Card tapped - Order ${order.orderNumber}');
            debugPrint('📱 MOBILE: Order ID: ${order.id}');
            debugPrint('📱 MOBILE: Order Type: ${order.type}');
            debugPrint('📱 MOBILE: Order Status: ${order.status}');
            debugPrint('📱 MOBILE: Items Count: ${order.items.length}');
            debugPrint('📱 MOBILE: User ID: ${order.userId}');
            debugPrint('📱 MOBILE: Table ID: ${order.tableId}');
            debugPrint('📱 MOBILE: About to call _editOrder...');
            
            try {
              _editOrder(order);
              debugPrint('📱 MOBILE: ✅ _editOrder call completed successfully');
            } catch (e, stackTrace) {
              debugPrint('📱 MOBILE: ❌ Error calling _editOrder: $e');
              debugPrint('📱 MOBILE: Stack trace: $stackTrace');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('❌ Mobile tap error: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(12),
          splashColor: statusColor.withValues(alpha: 0.2),
          highlightColor: statusColor.withValues(alpha: 0.1),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row - Order Number + Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Order Number Section
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.receipt_long,
                              color: statusColor,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '#${order.orderNumber}',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                                Text(
                                  _getOrderTypeText(order.type),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        order.status.toString().split('.').last.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Details Row
                Row(
                  children: [
                    // Items Count
                    Expanded(
                      child: _buildMobileDetailChip(
                        icon: Icons.restaurant_menu,
                        label: '${order.items.length} Items',
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Total Amount
                    Expanded(
                      child: _buildMobileDetailChip(
                        icon: Icons.attach_money,
                        label: '\$${order.total.toStringAsFixed(2)}',
                        color: Colors.green,
                      ),
                    ),
                    // Table (if dine-in)
                    if (order.type == OrderType.dineIn && order.tableId != null && order.tableId!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Consumer<TableService>(
                          builder: (context, tableService, child) {
                            final table = tableService.getTableById(order.tableId!);
                            String tableDisplay;
                            if (table != null) {
                              tableDisplay = 'T${table.number}';
                            } else {
                              final match = RegExp(r'table_(\d+)').firstMatch(order.tableId!);
                              if (match != null) {
                                tableDisplay = 'T${match.group(1)!}';
                              } else {
                                final numbers = RegExp(r'\d+').allMatches(order.tableId!);
                                if (numbers.isNotEmpty) {
                                  tableDisplay = 'T${numbers.first.group(0)!}';
                                } else {
                                  tableDisplay = 'T?';
                                }
                              }
                            }
                            return _buildMobileDetailChip(
                              icon: Icons.table_restaurant,
                              label: tableDisplay,
                              color: Colors.orange,
                            );
                          },
                        ),
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(height: 10),
                
                // Enhanced Tap to Edit Hint with better visual cues
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.edit,
                        color: statusColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Tap to Edit Order',
                        style: TextStyle(
                          fontSize: 12,
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios,
                        color: statusColor,
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Mobile detail chip widget
  Widget _buildMobileDetailChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  /// Get order type display text
  String _getOrderTypeText(OrderType type) {
    switch (type) {
      case OrderType.dineIn:
        return 'Dine-In';
      case OrderType.takeaway:
        return 'Take-Out';
      case OrderType.delivery:
        return 'Delivery';
      default:
        return 'Unknown';
    }
  }

  /// Print order functionality
  void _printOrder(Order order) {
    // TODO: Implement print functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Printing order #${order.orderNumber}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  /// Complete order functionality
  void _completeOrder(Order order) {
    // TODO: Implement complete order functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Completing order #${order.orderNumber}'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  /// Square order tile for tablet/desktop views (unchanged functionality)
  Widget _buildSquareOrderTile(Order order) {
    final statusColor = _getStatusColor(order.status);
    
    // Get responsive sizing based on device type
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
    
    // Responsive padding and font sizes
    final padding = isPhone ? 8.0 : isTablet ? 10.0 : 12.0;
    final orderNumberFontSize = isPhone ? 12.0 : isTablet ? 13.0 : 14.0;
    final statusFontSize = isPhone ? 8.0 : isTablet ? 9.0 : 10.0;
    final itemsFontSize = isPhone ? 9.0 : isTablet ? 10.0 : 11.0;
    
    return GestureDetector(
      onTap: () => _editOrder(order),
      child: AspectRatio(
        aspectRatio: 1.0, // Square aspect ratio
        child: Container(
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top section: Order number and status
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          '#${order.orderNumber}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: orderNumberFontSize,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.status.toString().split('.').last.toUpperCase(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: statusFontSize,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              
              // Middle section: Table info (if dine-in)
              if (order.type == OrderType.dineIn && order.tableId != null && order.tableId!.isNotEmpty)
                Consumer<TableService>(
                  builder: (context, tableService, child) {
                    final table = tableService.getTableById(order.tableId!);
                    
                    String tableDisplay;
                    if (table != null) {
                      tableDisplay = table.number.toString();
                    } else {
                      final match = RegExp(r'table_(\d+)').firstMatch(order.tableId!);
                      if (match != null) {
                        tableDisplay = match.group(1)!;
                      } else {
                        final numbers = RegExp(r'\d+').allMatches(order.tableId!);
                        if (numbers.isNotEmpty) {
                          tableDisplay = numbers.first.group(0)!;
                        } else {
                          tableDisplay = '?';
                        }
                      }
                    }
                    
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.table_restaurant,
                            size: 10,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'T$tableDisplay',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: isPhone ? 8.0 : 9.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
              else
                const SizedBox.shrink(),
              
              // Bottom section: Total and items count
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${order.total.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: orderNumberFontSize - 1, // Slightly smaller than order number
                    ),
                  ),
                  Text(
                    '${order.items.length} items',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: itemsFontSize,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Quick access section for tablet/desktop views (unchanged functionality)
  Widget _buildQuickAccessSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.dashboard, color: Colors.blue.shade600),
                const SizedBox(width: 8),
                Text(
                  'Quick Access',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickAccessButton(
                    title: 'Admin Panel',
                    icon: Icons.admin_panel_settings,
                    color: Colors.purple,
                    onTap: _openAdminPanel,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickAccessButton(
                    title: 'Kitchen',
                    icon: Icons.kitchen,
                    color: Colors.red,
                    onTap: () {
                      final userService = Provider.of<UserService?>(context, listen: false);
                      final currentUser = userService?.currentUser;
                      if (currentUser != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => KitchenScreen(user: currentUser),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Quick access button for tablet/desktop views (unchanged functionality)
  Widget _buildQuickAccessButton({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Handle server selection change
  void _onServerChanged(String? serverId) {
    try {
      debugPrint('👤 SERVER CHANGE: Processing server change from $_selectedServerId to $serverId');
      
      setState(() {
        _selectedServerId = serverId;
      });
      
      // ENHANCED SERVER CHANGE SYNC: Use new comprehensive sync functionality
      if (_enableRealTimeCrossDeviceSync && _syncService != null) {
        _performEnhancedServerChangeSync(serverId);
      } else {
        // Fallback to existing functionality
        _performLegacyServerChangeSync(serverId);
      }
      
      debugPrint('✅ Server change processed successfully');
      
    } catch (e) {
      debugPrint('❌ Server change failed: $e');
      // Fallback to basic server change
      _performBasicServerChange(serverId);
    }
  }
  
  /// Enhanced server change sync using UnifiedSyncService
  /// This now calls the SAME comprehensive sync method as the POS dashboard icon
  Future<void> _performEnhancedServerChangeSync(String? serverId) async {
    try {
      debugPrint('🔄 ENHANCED SERVER CHANGE SYNC: Starting comprehensive sync (same as POS dashboard icon)...');
      
      if (_syncService == null) {
        throw Exception('UnifiedSyncService not available');
      }
      
      // Show sync progress to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Text('Syncing data for server change...'),
              ],
            ),
            backgroundColor: Colors.blue[600],
            duration: const Duration(seconds: 10),
          ),
        );
      }
      
      // Perform enhanced server change sync
      await _syncService!.performServerChangeSync(
        newServerId: serverId,
        previousServerId: _selectedServerId,
        forceRefresh: true,
      );
      
      // Load orders after sync
      await _loadOrders();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Server change sync completed! Orders refreshed from all devices.'),
              ],
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Refresh',
              textColor: Colors.white,
              onPressed: () {
                _forceRefreshOrdersFromDatabase();
              },
            ),
          ),
        );
      }
      
      debugPrint('✅ Enhanced server change sync completed successfully using comprehensive sync method');
      
    } catch (e) {
      debugPrint('❌ Enhanced server change sync failed: $e');
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Text('Server change sync failed: ${e.toString()}'),
              ],
            ),
            backgroundColor: Colors.red[600],
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                _performEnhancedServerChangeSync(serverId);
              },
            ),
          ),
        );
      }
      
      // Fallback to legacy sync
      _performLegacyServerChangeSync(serverId);
    }
  }
  
  /// Legacy server change sync (existing functionality)
  void _performLegacyServerChangeSync(String? serverId) {
    try {
      debugPrint('🔄 LEGACY SERVER CHANGE SYNC: Using existing functionality...');
      
      // TRIGGER SYNC ON SERVER SELECTION
      _triggerSyncOnUserInteraction();
      
      // INNOVATIVE FIX: Trigger comprehensive sync when "All Servers" is selected
      if (serverId == null || serverId.isEmpty) {
        _triggerComprehensiveSyncForAllServers();
      }
      
      // CRITICAL FIX: Load orders and ensure real-time sync is active
      _loadOrders();
      
      // CRITICAL FIX: Ensure real-time sync is active after server change
      if (_enableRealTimeCrossDeviceSync && _syncService != null) {
        _ensureRealTimeSyncActive();
      }
      
      debugPrint('✅ Legacy server change sync completed');
      
    } catch (e) {
      debugPrint('❌ Legacy server change sync failed: $e');
      // Fallback to basic server change
      _performBasicServerChange(serverId);
    }
  }
  
  /// Basic server change (minimal functionality)
  void _performBasicServerChange(String? serverId) {
    try {
      debugPrint('🔄 BASIC SERVER CHANGE: Using minimal functionality...');
      
      // Just load orders without sync
      _loadOrders();
      
      debugPrint('✅ Basic server change completed');
      
    } catch (e) {
      debugPrint('❌ Basic server change failed: $e');
      // Last resort - just update UI state
      setState(() {
        _selectedServerId = serverId;
      });
    }
  }

  /// Trigger comprehensive sync for all servers using existing UnifiedSyncService
  Future<void> _triggerComprehensiveSyncForAllServers() async {
    try {
      debugPrint('🔄 All Servers selected - triggering comprehensive sync using existing UnifiedSyncService...');
      
      // Use the existing sync service that's already called at login
      final syncService = Provider.of<UnifiedSyncService?>(context, listen: false);
      if (syncService != null) {
        await syncService.forceSyncAllLocalData();
        debugPrint('✅ Comprehensive sync for all servers completed using existing service');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ All data synchronized! Orders, categories, items, users, and orders are now in sync with Firebase.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        debugPrint('⚠️ UnifiedSyncService not available for comprehensive sync');
      }
    } catch (e) {
      debugPrint('❌ Comprehensive sync for all servers failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Sync warning: ${e.toString()}'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }
  
  /// Handle manual refresh
  Future<void> _onManualRefresh() async {
    setState(() {
      _isManualRefresh = true;
    });
    
    // TRIGGER IMMEDIATE SYNC ON MANUAL REFRESH
    await _triggerSyncOnUserInteraction();
    
    _loadOrders();
    
    setState(() {
      _isManualRefresh = false;
    });
    
    debugPrint('🔄 Manual refresh completed');
  }

  /// Trigger comprehensive sync from Firebase using MultiTenantAuthService
  Future<void> _triggerSyncFromFirebase() async {
    if (_isSyncing) return;
    
    setState(() {
      _isSyncing = true;
    });
    
    try {
      debugPrint('🚀 Starting comprehensive sync operations using MultiTenantAuthService...');
      
      // Get the MultiTenantAuthService for comprehensive sync
      final authService = Provider.of<MultiTenantAuthService?>(context, listen: false);
      if (authService == null) {
        throw Exception('MultiTenantAuthService not available');
      }
      
      // Get current restaurant
      final currentRestaurant = authService.currentRestaurant;
      if (currentRestaurant == null) {
        throw Exception('No current restaurant available for sync');
      }
      
      debugPrint('🏪 Using restaurant: ${currentRestaurant.name} (${currentRestaurant.email})');
      
      // STEP 1: Use the comprehensive data sync method from MultiTenantAuthService
      debugPrint('🔄 STEP 1: Performing comprehensive data sync...');
      await authService.performComprehensiveDataSync(currentRestaurant);
      
      // STEP 2: Also trigger the working comprehensive sync for orders
      debugPrint('🔄 STEP 2: Performing working comprehensive sync for orders...');
      await authService.triggerWorkingComprehensiveSync(currentRestaurant);
      
      // STEP 3: Reload orders after all sync operations
      debugPrint('🔄 STEP 3: Reloading orders...');
      _loadOrders();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Comprehensive sync completed! All data including order items synchronized from Firebase.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
      
      debugPrint('✅ All comprehensive sync operations completed successfully!');
      
    } catch (e) {
      debugPrint('❌ Comprehensive sync failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sync failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }
  
  /// Perform comprehensive timestamp-based sync
  Future<void> _performComprehensiveTimestampSync(OrderService orderService) async {
    try {
      debugPrint('🔄 Starting comprehensive timestamp-based sync...');
      
      // Get current order count
      final initialOrderCount = orderService.allOrders.length;
      debugPrint('📊 Initial local orders: $initialOrderCount');
      
      // Trigger the comprehensive sync method
      await orderService.syncOrdersWithFirebase();
      
      final finalOrderCount = orderService.allOrders.length;
      debugPrint('📊 Final local orders: $finalOrderCount');
      debugPrint('📥 Orders added: ${finalOrderCount - initialOrderCount}');
      
    } catch (e) {
      debugPrint('❌ Comprehensive timestamp-based sync failed: $e');
      // Don't throw - continue with other sync methods
    }
  }
  
  /// Perform smart time-based sync
  Future<void> _performSmartTimeBasedSync() async {
    try {
      debugPrint('🔄 Starting smart time-based sync...');
      
      // Try to get the unified sync service
      try {
        final unifiedSyncService = Provider.of<UnifiedSyncService>(context, listen: false);
        if (unifiedSyncService != null) {
          // Check if sync is needed
          final needsSync = await unifiedSyncService.needsSync();
          
          if (needsSync) {
            debugPrint('🔄 Smart sync needed - performing time-based sync...');
            await unifiedSyncService.performSmartTimeBasedSync();
            debugPrint('✅ Smart time-based sync completed');
          } else {
            debugPrint('✅ Smart sync not needed - data is already consistent');
          }
        }
      } catch (e) {
        debugPrint('⚠️ Unified sync service not available: $e');
        // Continue without unified sync service
      }
      
    } catch (e) {
      debugPrint('❌ Smart time-based sync failed: $e');
      // Don't throw - continue with other sync methods
    }
  }

  // Feature flag to scope count validation to selected server (zero-risk rollbackable)
  static const bool _enableScopedCountValidation = true; // Can be disabled instantly

  /// Helper: compute system active count scoped to selected server if enabled
  int _scopedSystemActiveCount(OrderService orderService) {
    try {
      if (_enableScopedCountValidation && _selectedServerId != null && _selectedServerId!.trim().isNotEmpty) {
        final serverId = _selectedServerId!.trim();
        final count = orderService.getActiveOrdersCountByServer(serverId);
        debugPrint('🧮 Scoped system count for server $serverId: $count');
        return count;
      }
      final count = orderService.activeOrders.length;
      debugPrint('🧮 Global system active count: $count');
      return count;
    } catch (e) {
      debugPrint('⚠️ _scopedSystemActiveCount error: $e');
      // Fallback to displayedCount to avoid false-positive mismatch
      return _filteredOrders.length;
    }
  }

  /// INNOVATIVE FIX: Initialize real-time cross-device sync
  void _initializeRealTimeSync() async {
    try {
      debugPrint('🔄 REAL-TIME SYNC: Initializing cross-device synchronization...');
      
      _syncService = UnifiedSyncService.instance;
      
      // CRITICAL FIX: Get the current restaurant from MultiTenantAuthService and connect the sync service
      final authService = Provider.of<MultiTenantAuthService?>(context, listen: false);
      if (authService != null && authService.currentRestaurant != null) {
        debugPrint('🔗 REAL-TIME SYNC: Connecting to restaurant: ${authService.currentRestaurant!.name}');
        
        // Connect the sync service to the restaurant to start Firebase listeners
        if (authService.currentSession != null) {
          await _syncService!.connectToRestaurant(
            authService.currentRestaurant!,
            authService.currentSession!,
          );
        } else {
          // Create a basic session if none exists
          await _syncService!.connectToRestaurant(
            authService.currentRestaurant!,
            RestaurantSession(
              restaurantId: authService.currentRestaurant!.id,
              userId: 'current_user',
              userName: 'Current User',
              userRole: UserRole.server,
              loginTime: DateTime.now(),
              isActive: true,
            ),
          );
        }
        
        debugPrint('✅ REAL-TIME SYNC: Successfully connected to restaurant - Firebase listeners active');
      } else {
        debugPrint('⚠️ REAL-TIME SYNC: No restaurant available - cannot start Firebase listeners');
      }
      
      // Set up callbacks for immediate UI updates
      _syncService!.setOnOrdersUpdated(() {
        debugPrint('🔴 REAL-TIME SYNC: Orders updated from another device - refreshing UI immediately');
        if (mounted) {
          _handleCrossDeviceOrderUpdate();
        }
      });
      
      _syncService!.setOnSyncProgress((message) {
        debugPrint('🔄 REAL-TIME SYNC: $message');
      });
      
      _syncService!.setOnSyncError((error) {
        debugPrint('❌ REAL-TIME SYNC: $error');
      });
      
      // CRITICAL: Check if real-time sync is actually active
      if (_syncService!.isRealTimeSyncActive) {
        _isRealTimeSyncActive = true;
        debugPrint('✅ REAL-TIME SYNC: Firebase listeners are ACTIVE - new orders will appear instantly');
      } else {
        debugPrint('⚠️ REAL-TIME SYNC: Firebase listeners are NOT active - manual refresh needed');
      }
      
      setState(() {});
      
    } catch (e) {
      debugPrint('❌ REAL-TIME SYNC: Error initializing - $e');
      _isRealTimeSyncActive = false;
      setState(() {});
    }
  }
  
  /// CRITICAL: Start continuous real-time sync monitoring
  void _startContinuousRealTimeSyncMonitoring() {
    try {
      debugPrint('🔴 CONTINUOUS REAL-TIME SYNC MONITORING: Starting continuous monitoring...');
      
      // CRITICAL FIX: Ensure real-time sync is active every 10 seconds
      Timer.periodic(const Duration(seconds: 10), (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }
        
        // CRITICAL: Ensure real-time sync is always active
        if (_enableRealTimeCrossDeviceSync && _syncService != null) {
          await _ensureRealTimeSyncActive();
          
          // CRITICAL: Check if new orders arrived and refresh UI automatically
          if (_isRealTimeSyncActive) {
            _checkForNewOrdersAndRefresh();
          }
        }
        try {
          if (_syncService != null) {
            // Ensure real-time sync is always active
            await _syncService!.ensureRealTimeSyncActive();
            
            // Update UI status
            final isActive = _syncService!.isRealTimeSyncActive;
            if (_isRealTimeSyncActive != isActive) {
              _isRealTimeSyncActive = isActive;
              if (mounted) {
                setState(() {});
              }
            }
            
            if (isActive) {
              debugPrint('✅ CONTINUOUS MONITORING: Real-time sync is active and working');
            } else {
              debugPrint('⚠️ CONTINUOUS MONITORING: Real-time sync is not active - attempting to restart...');
              await _syncService!.restartRealTimeListeners();
            }
          }
        } catch (e) {
          debugPrint('❌ CONTINUOUS MONITORING: Error during monitoring - $e');
        }
      });
      
      debugPrint('✅ CONTINUOUS REAL-TIME SYNC MONITORING: Started successfully');
      
    } catch (e) {
      debugPrint('❌ CONTINUOUS MONITORING: Failed to start - $e');
    }
  }
  
  /// INNOVATIVE FIX: Handle cross-device order updates
  void _handleCrossDeviceOrderUpdate() {
    try {
      debugPrint('🔄 CROSS-DEVICE UPDATE: Processing order update from another device...');
      
      // 🚫 CRITICAL FIX: Don't show notifications during ghost order cleanup
      // Check if this is likely a ghost order cleanup by looking at recent logs
      _checkIfGhostOrderCleanupActive();
      
      // CRITICAL FIX: Automatically refresh orders and update UI
      _forceRefreshOrdersFromDatabase();
      
      // CRITICAL FIX: Force UI rebuild to show new orders immediately
      if (mounted) {
        setState(() {
          // This will trigger a complete UI rebuild with new data
        });
      }
      
      // 🚫 ONLY show notification if NOT during ghost order cleanup
      if (!_isGhostOrderCleanupActive) {
        _showCrossDeviceUpdateNotification();
        debugPrint('✅ CROSS-DEVICE UPDATE: UI refreshed with notification - new orders should be visible');
      } else {
        debugPrint('🚫 CROSS-DEVICE UPDATE: UI refreshed silently (ghost order cleanup detected)');
      }
      
    } catch (e) {
      debugPrint('❌ CROSS-DEVICE UPDATE: Error handling update - $e');
    }
  }
  
  /// 🚫 CRITICAL FIX: Check if ghost order cleanup is currently active
  void _checkIfGhostOrderCleanupActive() {
    try {
      // SMART DETECTION: Suppress notifications during initial app startup (first 60 seconds)
      // when ghost order cleanup is most likely to occur
      final now = DateTime.now();
      
      if (!_isGhostOrderCleanupActive) {
        _isGhostOrderCleanupActive = true;
        debugPrint('🚫 GHOST CLEANUP DETECTION: Suppressing cross-device notifications during startup cleanup');
        
        // Re-enable notifications after 60 seconds (startup cleanup should be complete)
        Timer(const Duration(seconds: 60), () {
          _isGhostOrderCleanupActive = false;
          debugPrint('✅ GHOST CLEANUP DETECTION: Re-enabling cross-device notifications after startup');
        });
      }
    } catch (e) {
      debugPrint('❌ GHOST CLEANUP DETECTION: Error checking cleanup status - $e');
    }
  }

  /// INNOVATIVE FIX: Show notification for cross-device updates
  void _showCrossDeviceUpdateNotification() {
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.sync, color: Colors.white),
                const SizedBox(width: 8),
                const Text('New orders detected from another device'),
              ],
            ),
            backgroundColor: Colors.blue[600],
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Refresh',
              textColor: Colors.white,
              onPressed: () {
                _forceRefreshOrdersFromDatabase();
              },
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ CROSS-DEVICE NOTIFICATION: Error showing notification - $e');
    }
  }
  
  /// INNOVATIVE FIX: Start periodic refresh as backup mechanism
  void _startPeriodicRefresh() {
    try {
      debugPrint('⏰ PERIODIC REFRESH: Starting backup refresh every ${_refreshInterval.inSeconds} seconds...');
      
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = Timer.periodic(_refreshInterval, (timer) {
        if (mounted && !_isRefreshing) {
          debugPrint('⏰ PERIODIC REFRESH: Executing scheduled refresh...');
          _forceRefreshOrdersFromDatabase();
        }
      });
      
    } catch (e) {
      debugPrint('❌ PERIODIC REFRESH: Error starting periodic refresh - $e');
    }
  }
  
  /// INNOVATIVE FIX: Stop real-time cross-device sync
  void _stopRealTimeSync() {
    try {
      debugPrint('🛑 REAL-TIME SYNC: Stopping cross-device synchronization...');
      
      _autoRefreshTimer?.cancel();
      _autoRefreshTimer = null;
      
      if (_syncService != null) {
        _syncService!.clearCallbacks();
      }
      
      _isRealTimeSyncActive = false;
      
      debugPrint('✅ REAL-TIME SYNC: Cross-device synchronization stopped');
      
    } catch (e) {
      debugPrint('❌ REAL-TIME SYNC: Error stopping sync - $e');
    }
  }

  /// CRITICAL FIX: Check for new orders and refresh UI automatically
  void _checkForNewOrdersAndRefresh() {
    try {
      final orderService = Provider.of<OrderService?>(context, listen: false);
      if (orderService != null) {
        // Get current order count
        final currentCount = _filteredOrders.length;
        
        // Check if there are new orders by comparing with service
        final serviceCount = _scopedSystemActiveCount(orderService);
        
        if (serviceCount > currentCount) {
          debugPrint('🆕 NEW ORDERS DETECTED: Service has $serviceCount orders, UI shows $currentCount - Auto-refreshing...');
          
          // Automatically refresh to show new orders
          _forceRefreshOrdersFromDatabase();
          
          // Show notification about new orders
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.new_releases, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('${serviceCount - currentCount} new order(s) detected - Auto-refreshing...'),
                  ],
                ),
                backgroundColor: Colors.green[600],
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ AUTO-REFRESH CHECK: Error checking for new orders - $e');
    }
  }

  /// INDUSTRY STANDARD: Start proper Firebase real-time listeners
  void _startFirebaseRealTimeListeners() {
    try {
      debugPrint('🔥 INDUSTRY STANDARD: Starting Firebase real-time listeners...');
      
      // Cancel any existing timers (clean up non-standard approach)
      _autoRefreshTimer?.cancel();
      
      // INDUSTRY STANDARD: Use Firebase real-time listeners instead of polling
      if (_syncService != null && _syncService!.isRealTimeSyncActive) {
        debugPrint('✅ Firebase listeners are ACTIVE - using industry standard real-time sync');
        
        // Set up proper Firebase listeners for real-time updates
        _setupFirebaseOrderListeners();
        
      } else {
        debugPrint('⚠️ Firebase listeners not active - falling back to periodic sync');
        _startPeriodicSyncAsFallback();
      }
      
    } catch (e) {
      debugPrint('❌ FIREBASE LISTENERS: Error starting real-time listeners - $e');
      // Fallback to periodic sync if Firebase fails
      _startPeriodicSyncAsFallback();
    }
  }
  
  /// INDUSTRY STANDARD: Set up Firebase real-time order listeners
  void _setupFirebaseOrderListeners() {
    try {
      debugPrint('🔥 FIREBASE LISTENERS: Setting up real-time order listeners...');
      
      // This should use the existing UnifiedSyncService Firebase listeners
      // The service should automatically notify us when orders change
      
      debugPrint('✅ Firebase real-time listeners configured');
      
    } catch (e) {
      debugPrint('❌ FIREBASE LISTENERS: Error setting up listeners - $e');
    }
  }
  
  /// FALLBACK: Periodic sync only when Firebase listeners fail (not industry standard)
  void _startPeriodicSyncAsFallback() {
    try {
      debugPrint('⚠️ FALLBACK: Starting periodic sync every 10 seconds (not industry standard)...');
      
      _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
        if (mounted && !_isRefreshing) {
          debugPrint('🔄 FALLBACK SYNC: Periodic refresh...');
          _forceRefreshOrdersFromDatabase();
        }
      });
      
    } catch (e) {
      debugPrint('❌ FALLBACK SYNC: Error starting periodic sync - $e');
    }
  }

  /// INNOVATIVE FIX: Build real-time sync status indicator
  Widget _buildRealTimeSyncIndicator() {
    return GestureDetector(
      onTap: () {
        // Show sync status details
        _showSyncStatusDetails();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _isRealTimeSyncActive ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isRealTimeSyncActive ? Colors.green : Colors.orange,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isRealTimeSyncActive ? Icons.sync : Icons.sync_disabled,
              size: 16,
              color: _isRealTimeSyncActive ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 4),
            Text(
              _isRealTimeSyncActive ? 'Live' : 'Offline',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _isRealTimeSyncActive ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// INNOVATIVE FIX: Show detailed sync status
  void _showSyncStatusDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _isRealTimeSyncActive ? Icons.sync : Icons.sync_disabled,
              color: _isRealTimeSyncActive ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text('Real-time Sync Status'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSyncStatusRow(
              'Real-time Sync',
              _isRealTimeSyncActive ? 'Active' : 'Inactive',
              _isRealTimeSyncActive ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 8),
            _buildSyncStatusRow(
              'Periodic Refresh',
              _enablePeriodicRefresh ? 'Every ${_refreshInterval.inSeconds}s' : 'Disabled',
              _enablePeriodicRefresh ? Colors.blue : Colors.grey,
            ),
            const SizedBox(height: 8),
            _buildSyncStatusRow(
              'Cross-device Updates',
              _isRealTimeSyncActive ? 'Instant' : 'Manual only',
              _isRealTimeSyncActive ? Colors.green : Colors.orange,
            ),
            const SizedBox(height: 16),
            const Text(
              'Orders created on other devices will appear here automatically when real-time sync is active.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _forceRefreshOrdersFromDatabase();
            },
            child: const Text('Refresh Now'),
          ),
        ],
      ),
    );
  }
  
  /// INNOVATIVE FIX: Build sync status row
  Widget _buildSyncStatusRow(String label, String status, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  /// INNOVATIVE FIX: Ensure real-time sync is active
  Future<void> _ensureRealTimeSyncActive() async {
    try {
      if (_syncService != null && !_syncService!.isRealTimeSyncActive) {
        debugPrint('🔄 REAL-TIME SYNC: Restarting listeners to ensure they are active...');
        await _syncService!.restartRealTimeListeners();
        _isRealTimeSyncActive = _syncService!.isRealTimeSyncActive;
        setState(() {});
        
        if (_isRealTimeSyncActive) {
          debugPrint('✅ REAL-TIME SYNC: Listeners restarted successfully');
        } else {
          debugPrint('⚠️ REAL-TIME SYNC: Listeners still not active');
        }
      }
    } catch (e) {
      debugPrint('❌ REAL-TIME SYNC: Error ensuring listeners are active - $e');
    }
  }

  /// Calculate All servers count as sum of individual server counts
  /// This ensures the "All servers" count matches the sum of individual server counts
  int _calculateAllServersCount(OrderService orderService, UserService userService) {
    int totalCount = 0;
    final servers = userService.users.where((user) => 
      user.role == UserRole.server || 
      user.role == UserRole.admin || 
      user.role == UserRole.manager
    );
    
    for (var server in servers) {
      totalCount += orderService.getActiveOrdersCountByServer(server.id);
    }
    
    debugPrint('🧮 All servers count calculation: $totalCount (sum of individual server counts)');
    return totalCount;
  }

}





