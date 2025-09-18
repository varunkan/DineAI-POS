import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'config/environment_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:network_info_plus/network_info_plus.dart';

// Multi-tenant authentication
import 'services/multi_tenant_auth_service.dart';
import 'screens/restaurant_auth_screen.dart';
import 'screens/order_type_selection_screen.dart';
import 'services/initialization_progress_service.dart';
import 'widgets/initialization_progress_screen.dart';

// All POS services
import 'models/order.dart';
import 'models/user.dart';
import 'services/database_service.dart';
import 'services/menu_service.dart';
import 'services/order_service.dart';
import 'services/user_service.dart';
import 'services/printing_service.dart';
import 'services/table_service.dart';
import 'services/order_log_service.dart';
import 'services/payment_service.dart';
import 'services/inventory_service.dart';
import 'services/activity_log_service.dart';
import 'services/printer_configuration_service.dart';
import 'services/enhanced_printer_assignment_service.dart';
import 'services/cross_platform_printer_sync_service.dart';
import 'services/printer_validation_service.dart';
import 'services/robust_kitchen_service.dart';

import 'services/enhanced_printer_manager.dart';
import 'services/unified_printer_service.dart';
import 'services/unified_sync_service.dart';
import 'services/sync_fix_service.dart';
import 'services/kitchen_printing_service.dart';
import 'services/loyalty_service.dart';

// Tenant-specific printer services
import 'services/tenant_printer_service.dart';

import 'services/tenant_printer_integration_service.dart';

import 'config/firebase_config.dart';
import 'utils/firebase_connection_test.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set environment (default to production if not set)
  if (!EnvironmentConfig.isDevelopment && !EnvironmentConfig.isProduction) {
    EnvironmentConfig.setEnvironment(Environment.production);
  }
  
  // Disable Provider debug check to allow nullable service types
  Provider.debugCheckInvalidValueType = null;
  
  debugPrint('🚀 Starting Multi-Tenant AI POS System...');
  debugPrint('🌍 Environment: ${EnvironmentConfig.environment.name.toUpperCase()}');
  debugPrint('🗄️ Database: ${EnvironmentConfig.databaseName}');
  
  // Initialize Firebase first (with error handling)
  debugPrint('🔥 Initializing Firebase...');
  try {
    await FirebaseConfig.initialize();
    
      // Test Firebase connection (with timeout and fallback)
  debugPrint('🔍 Testing Firebase connection...');
  try {
    final connectionResults = await FirebaseConnectionTest.testConnection().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        debugPrint('⚠️ Firebase connection test timed out, continuing...');
        return <String, dynamic>{
          'firebase_initialized': true,
          'firestore_available': false,
          'connection_timeout': true,
        };
      },
    );
    FirebaseConnectionTest.printResults(connectionResults);
  } catch (e) {
    debugPrint('⚠️ Firebase connection test failed, continuing in offline mode: $e');
  }
  } catch (e) {
    debugPrint('⚠️ Firebase initialization failed, continuing in offline mode: $e');
  }
  
  // Initialize Flutter services
  final prefs = await SharedPreferences.getInstance();
  final authService = MultiTenantAuthService();
  final progressService = InitializationProgressService();
  
  // Pre-initialize auth service (with timeout to prevent hanging)
  try {
    await authService.initialize().timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        debugPrint('⚠️ Auth service initialization timed out, continuing...');
      },
    );
  } catch (e) {
    debugPrint('⚠️ Auth service initialization failed, continuing: $e');
  }
  
  // Connect progress service to auth service
  authService.setProgressService(progressService);
  
  debugPrint('🚪 Starting with normal session behavior');
  
  runApp(MyApp(
    authService: authService,
    progressService: progressService,
    prefs: prefs,
  ));
}

class MyApp extends StatefulWidget {
  final MultiTenantAuthService authService;
  final InitializationProgressService progressService;
  final SharedPreferences prefs;
  
  const MyApp({
    Key? key,
    required this.authService,
    required this.progressService,
    required this.prefs,
  }) : super(key: key);
  
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  // Global navigator key for navigation
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  
  // Service initialization state
  bool _servicesInitialized = false;
  bool _isInitializing = false; // Add flag to prevent duplicate initialization
  
  // Service instances - nullable to allow clearing for restaurant isolation
  MenuService? _menuService;
  OrderService? _orderService;
  UserService? _userService;
  TableService? _tableService;
  PaymentService? _paymentService;
  PrintingService? _printingService;
  OrderLogService? _orderLogService;
  ActivityLogService? _activityLogService;
  LoyaltyService? _loyaltyService;
  InventoryService? _inventoryService;
  PrinterConfigurationService? _printerConfigurationService;
  UnifiedPrinterService? _unifiedPrinterService;
  UnifiedSyncService? _unifiedSyncService;
  EnhancedPrinterAssignmentService? _enhancedPrinterAssignmentService;
  CrossPlatformPrinterSyncService? _crossPlatformPrinterSyncService;
  EnhancedPrinterManager? _enhancedPrinterManager;
  PrinterValidationService? _printerValidationService;
  RobustKitchenService? _robustKitchenService;
  // FreeCloudPrintingService removed
  KitchenPrintingService? _kitchenPrintingService;
  
  // Tenant-specific printer services
  TenantPrinterService? _tenantPrinterService;
  // TenantCloudPrintingService removed
  TenantPrinterIntegrationService? _tenantPrinterIntegrationService;
  
  // Debounced refresh to prevent infinite loops
  Timer? _refreshTimer;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize core services immediately
    _initializeCoreServices();
    
    // Add app lifecycle observer for auto-logout on app close
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize service instances for Provider tree
    _initializeServiceInstancesSync();
    
    // Initialize services that need SharedPreferences asynchronously
    _initializeServiceInstancesAsync();
    
    // Add listener to auth service for authentication state changes
    widget.authService.addListener(_onAuthStateChanged);
    
    // Initialize services after authentication (if already authenticated)
    if (widget.authService.isAuthenticated) {
      // Use post frame callback to ensure widget tree is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initializeServicesAfterAuth();
      });
    }
  }

  @override
  void dispose() {
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Remove auth listener
    widget.authService.removeListener(_onAuthStateChanged);
    
    // CRITICAL FIX: Do NOT dispose services here!
    // Services should remain available throughout app lifecycle
    // Only dispose when truly shutting down the app
    
    super.dispose();
  }

  /// Handle authentication state changes
  void _onAuthStateChanged() {
    debugPrint('🔄 Auth state changed - isAuthenticated: ${widget.authService.isAuthenticated}');
    
    if (mounted) {
      setState(() {
        if (widget.authService.isAuthenticated) {
          debugPrint('🔓 Authentication state changed - initializing services...');
          // Use post frame callback to ensure widget tree is ready
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializeServicesAfterAuth();
          });
        } else {
          debugPrint('🔒 Authentication state changed - user logged out');
          // Only cleanup if we were previously authenticated
          if (_servicesInitialized) {
            _cleanupServices();
          }
        }
      });
    }
  }
  
  /// Cleanup services when logging out
  void _cleanupServices() async {
    try {
      debugPrint('🧹 Starting service cleanup after logout...');
      
      // Clear all services for proper isolation
      await _clearAllServicesForIsolation();
      
      // Preserve service instances and order data for next login
      // This prevents data loss during quick logout/login cycles
      debugPrint('📋 Preserving service instances and order data for next login...');
      
      debugPrint('✅ Service cleanup completed - all services preserved');
    } catch (e) {
      debugPrint('❌ Service cleanup failed: $e');
    }
  }

  /// Handle app lifecycle changes - logout when app is closed
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    debugPrint('📱 App lifecycle state changed: $state');
    
    // Only logout when app is truly being closed or detached
    // Do NOT logout for inactive/hidden states (these are normal during app switching)
    if (state == AppLifecycleState.detached) {
      debugPrint('🚪 App truly closing - logging out for security...');
      _logoutOnAppClose();
    }
    // Note: We don't logout on paused/hidden/inactive as these are normal app lifecycle events
  }

  /// Logout when app is closed (for security)
  void _logoutOnAppClose() async {
    try {
      if (widget.authService.isAuthenticated) {
        // Mark that app was explicitly closed
        await widget.prefs.setBool('app_explicitly_closed', true);
        
        await widget.authService.logout();
        debugPrint('✅ Auto-logout completed due to app close');
      }
    } catch (e) {
      debugPrint('❌ Error during auto-logout: $e');
    }
  }

  /// Initialize core services with dummy database instances
  void _initializeCoreServices() {
    final dummyDb = DatabaseService();
    _menuService = MenuService(dummyDb);
    _orderLogService = OrderLogService(dummyDb);
    _activityLogService = ActivityLogService(dummyDb);
    _loyaltyService = LoyaltyService(dummyDb);
    _inventoryService = InventoryService();
    _orderService = OrderService(dummyDb, _orderLogService!, _inventoryService!);
    debugPrint('✅ Core services initialized with dummy instances');
  }

  /// Initialize services that can be created synchronously (before SharedPreferences)
  void _initializeServiceInstancesSync() {
    // All services are already initialized in _initializeCoreServices()
    debugPrint('✅ Sync service instances ready');
  }
  
  /// Initialize services that require SharedPreferences asynchronously
  void _initializeServiceInstancesAsync() async {
    // This will be called after SharedPreferences is available
    debugPrint('✅ Async service instances ready');
  }

  /// Initialize services after authentication
  Future<void> _initializeServicesAfterAuth() async {
    debugPrint('🔧 _initializeServicesAfterAuth called - isInitializing: $_isInitializing, servicesInitialized: $_servicesInitialized');
    
    if (_isInitializing) {
      debugPrint('⚠️ Service initialization already in progress');
      return;
    }
    
    if (_servicesInitialized) {
      debugPrint('⚠️ Services already initialized');
      return;
    }
    
    _isInitializing = true;
    
    try {
      debugPrint('🔧 Starting POS service initialization after authentication...');
      
      final tenantDatabase = widget.authService.tenantDatabase;
      if (tenantDatabase == null) {
        throw Exception('Tenant database not available after authentication');
      }
      
      debugPrint('✅ Using tenant database: ${tenantDatabase.runtimeType}');
      
      // Get shared preferences
      final prefs = await SharedPreferences.getInstance();
      debugPrint('✅ SharedPreferences initialized');
      
      // Initialize unified Firebase sync service
      widget.progressService.addMessage('🔄 Initializing unified sync service...');
      _unifiedSyncService = UnifiedSyncService.instance;
      await _unifiedSyncService!.initialize();
      debugPrint('✅ Unified Firebase sync service initialized');
      debugPrint('✅ Automatic sync trigger service initialized');
      
      // Reset disposal state for core services before reinitialization
      try {
        _orderService?.resetDisposalState();
        _menuService?.resetDisposalState();
      } catch (e) {
        debugPrint('⚠️ Could not reset service disposal states: $e');
      }
      
      // Initialize all services with proper tenant database
      await _initializeAllServices(prefs, tenantDatabase);
      
      _servicesInitialized = true;
      debugPrint('🎉 All POS services initialized successfully');
      debugPrint('🔍 BUILD: _servicesInitialized set to true, about to trigger UI rebuild');
      
      // Trigger UI rebuild
      if (mounted) {
        debugPrint('🔍 BUILD: Widget is mounted, calling setState()');
        setState(() {});
        debugPrint('🔍 BUILD: setState() called successfully');
      } else {
        debugPrint('⚠️ BUILD: Widget not mounted, cannot call setState()');
      }
      
    } catch (e, stackTrace) {
      debugPrint('❌ Failed to initialize services after auth: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // CRITICAL FIX: Try to reinitialize services if they fail
      try {
        debugPrint('🔄 Attempting to reinitialize failed services...');
        await _reinitializeFailedServices();
        _servicesInitialized = true;
        debugPrint('✅ Services reinitialized successfully');
      } catch (reinitError) {
        debugPrint('❌ Failed to reinitialize services: $reinitError');
        
        // Show error to user - FIXED: Use safer approach with proper context check
        if (mounted && context.mounted) {
          try {
            // Check if ScaffoldMessenger is available
            final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
            if (scaffoldMessenger != null) {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text('Failed to initialize services: $e'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            } else {
              debugPrint('⚠️ ScaffoldMessenger not available - skipping error display');
            }
          } catch (scaffoldError) {
            debugPrint('⚠️ Could not show error snackbar: $scaffoldError');
            // Fallback: just log the error
          }
        } else {
          debugPrint('⚠️ Context not mounted - skipping error display');
        }
      }
    } finally {
      _isInitializing = false;
    }
  }
  
  /// Reinitialize failed services
  Future<void> _reinitializeFailedServices() async {
    try {
      debugPrint('🔄 Reinitializing failed services...');
      
      // Check which services need reinitialization
      if (_printingService != null && !_printingService!.isHealthy) {
        debugPrint('🔄 Reinitializing printing service...');
        await _printingService!.reinitializeIfNeeded();
      }
      
      if (_robustKitchenService != null && !_robustKitchenService!.isHealthy) {
        debugPrint('🔄 Reinitializing robust kitchen service...');
        await _robustKitchenService!.reinitializeIfNeeded();
      }
      
      // Reinitialize other critical services as needed
      debugPrint('✅ Failed services reinitialized');
    } catch (e) {
      debugPrint('❌ Error reinitializing failed services: $e');
      throw e;
    }
  }

  /// Initialize all services with proper error handling
  Future<void> _initializeAllServices(SharedPreferences prefs, DatabaseService tenantDatabase) async {
    try {
      // IMPORTANT: Reinitialize ALL services with proper authenticated instances
      
      // Initialize UserService early (needed for UI)
      widget.progressService.addMessage('👥 Setting up user management...');
      try {
        _userService = UserService(prefs, tenantDatabase);
        // UserService loads users automatically in constructor, wait for it to complete
        await Future.delayed(const Duration(milliseconds: 500));
        debugPrint('✅ UserService initialized with ${_userService!.users.length} users');
        
        // CRITICAL: Set Admin as current user immediately after UserService is initialized
        try {
          final users = _userService!.users;
          User? admin;
          
          debugPrint('🔍 ADMIN SETUP: Found ${users.length} users in UserService');
          for (int i = 0; i < users.length; i++) {
            debugPrint('🔍 ADMIN SETUP: User $i: id=${users[i].id}, name=${users[i].name}, role=${users[i].role}, isActive=${users[i].isActive}');
          }
          
          // First try to find an active admin user
          for (final u in users) {
            if (u.role == UserRole.admin && u.isActive) {
              admin = u;
              debugPrint('🔍 ADMIN SETUP: Found active admin user: ${u.name} (${u.id})');
              break;
            }
          }
          
          // Fallback to user with id 'admin'
          if (admin == null) {
            admin = users.where((u) => u.id == 'admin').cast<User?>().firstOrNull;
            if (admin != null) {
              debugPrint('🔍 ADMIN SETUP: Found user with id "admin": ${admin.name}');
            }
          }
          
          // Fallback to first user if no admin found
          if (admin == null) {
            admin = users.isNotEmpty ? users.first : null;
            if (admin != null) {
              debugPrint('🔍 ADMIN SETUP: Using first user as fallback: ${admin.name} (${admin.id})');
            }
          }
          
          if (admin != null) {
            debugPrint('🔍 ADMIN SETUP: About to set current user: ${admin.name} (${admin.id})');
            _userService!.setCurrentUser(admin);
            debugPrint('✅ Set Admin as current user: ${admin.name} (${admin.role})');
            
            // Verify the current user was set
            final currentUser = _userService!.currentUser;
            debugPrint('🔍 ADMIN SETUP: Verification - currentUser after setting: ${currentUser?.name ?? 'NULL'}');
            
            // Also set OrderLogService context if available
            if (_orderLogService != null) {
              _orderLogService!.setCurrentUser(admin.id, admin.name);
              debugPrint('✅ OrderLogService context set for admin user');
            }
          } else {
            debugPrint('⚠️ No users available to set as current user - will create default admin');
            
            // Create default admin user if none exists
            final adminUser = User(
              id: 'admin',
              name: 'Admin',
              role: UserRole.admin,
              pin: '1234',
              isActive: true,
              adminPanelAccess: true,
              createdAt: DateTime.now(),
            );
            
            debugPrint('🔍 ADMIN SETUP: Creating default admin user');
            await _userService!.addUser(adminUser);
            _userService!.setCurrentUser(adminUser);
            debugPrint('✅ Created and set default admin user as current');
            
            // Verify the current user was set
            final currentUser = _userService!.currentUser;
            debugPrint('🔍 ADMIN SETUP: Verification - currentUser after creating: ${currentUser?.name ?? 'NULL'}');
            
            // Set OrderLogService context for new admin
            if (_orderLogService != null) {
              _orderLogService!.setCurrentUser(adminUser.id, adminUser.name);
            }
          }
        } catch (e, stackTrace) {
          debugPrint('⚠️ Unable to set Admin as current user: $e');
          debugPrint('⚠️ Stack trace: $stackTrace');
        }
        
      } catch (e) {
        debugPrint('❌ UserService initialization failed: $e');
        // Continue anyway - app can work without users initially
      }
      
      // Admin user is now set immediately after UserService initialization above
      
      // Initialize TableService early (needed for orders)
      widget.progressService.addMessage('🍽️ Setting up table management...');
      _tableService = TableService(prefs);
      debugPrint('✅ TableService initialized');
      
      // Initialize PaymentService early (needed for UI)
      widget.progressService.addMessage('💳 Setting up payment processing...');
      if (_orderService != null && _inventoryService != null) {
        _paymentService = PaymentService(_orderService!, _inventoryService!);
        debugPrint('✅ PaymentService initialized');
      } else {
        debugPrint('⚠️ PaymentService initialization skipped - dependencies not ready');
      }
      
      // Initialize PrintingService early (needed for UI)
      widget.progressService.addMessage('🖨️ Configuring printing services...');
      final networkInfo = await _getNetworkInfo();
      _printingService = PrintingService(prefs, networkInfo);
      debugPrint('✅ PrintingService initialized');
      
      // ENABLE: Trigger immediate auto-reconnect to previously connected printers
      widget.progressService.addMessage('🔗 Reconnecting to previously connected printers...');
      try {
        // Wait a bit for the printing service to fully initialize
        await Future.delayed(const Duration(seconds: 2));
        debugPrint('🚀 Triggering immediate auto-reconnect to previously connected printers...');
        // Call immediate auto-reconnect for faster reconnection after login
        await _printingService!.immediateAutoReconnect();
        debugPrint('✅ Immediate auto-reconnect process completed');
      } catch (e) {
        debugPrint('⚠️ Immediate auto-reconnect failed: $e');
      }
      
      // Trigger UI rebuild with basic services ready
      if (mounted) {
        setState(() {});
      }
      
      // Create new OrderService instance with updated database and reload orders
      widget.progressService.addMessage('📋 Reloading existing orders from database...');
      _orderLogService = OrderLogService(tenantDatabase);
      if (_orderLogService != null && _inventoryService != null) {
        _orderService = OrderService(tenantDatabase, _orderLogService!, _inventoryService!);
        await _orderService!.loadOrders();
        
        // Set current user context for order logs if available
        try {
          final cu = _userService?.currentUser;
          if (cu != null) {
            _orderLogService!.setCurrentUser(cu.id, cu.name);
            debugPrint('✅ OrderLogService user context set: ${cu.name}');
          }
        } catch (e) {
          debugPrint('⚠️ Could not set OrderLogService user context: $e');
        }
        
        debugPrint('✅ OrderService reinitialized with existing orders');
      } else {
        debugPrint('⚠️ OrderService initialization failed - dependencies not ready');
      }
      
      // Create new MenuService instance with updated database
      widget.progressService.addMessage('🍽️ Loading menu items...');
      _menuService = MenuService(tenantDatabase);
      await _menuService!.ensureInitialized();
      await _menuService!.ensureReceiptsCategoryExists();
      debugPrint('✅ MenuService reinitialized');
      
      // Create new ActivityLogService instance with updated database
      widget.progressService.addMessage('📝 Initializing activity logging...');
      _activityLogService = ActivityLogService(tenantDatabase);
      await _activityLogService!.initialize();
      
      // Set current user context for logging
      final currentSession = widget.authService.currentSession;
      if (currentSession != null) {
        _activityLogService!.setCurrentUser(
          currentSession.userId,
          currentSession.userName,
          currentSession.userRole.toString(),
          restaurantId: widget.authService.currentRestaurant?.id,
        );
      }
      
      debugPrint('✅ ActivityLogService reinitialized');
      
      // Log successful authentication
      try {
        final currentSession = widget.authService.currentSession;
        if (currentSession != null) {
          await _activityLogService!.logLogin(
            userId: currentSession.userId,
            userName: currentSession.userName,
            userRole: currentSession.userRole.toString(),
            screenName: 'Main App',
            metadata: {
              'restaurant_name': widget.authService.currentRestaurant?.name,
              'initialization_time': DateTime.now().toIso8601String(),
            },
          );
        }
      } catch (e) {
        debugPrint('⚠️ Failed to log authentication: $e');
      }
      
      widget.progressService.addMessage('🔧 Setting up printer configurations...');
      _printerConfigurationService = PrinterConfigurationService(tenantDatabase);
      // FIXED: Add timeout to prevent hanging during initialization
      try {
        await _printerConfigurationService!.initializeTable().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            debugPrint('⚠️ PrinterConfigurationService initialization timed out, continuing...');
            return;
          },
        );
        debugPrint('✅ PrinterConfigurationService initialized');

        // Auto-add Bar Printer if missing
        try {
          final existing = _printerConfigurationService!.getConfigurationByIP('192.168.0.204', 9100);
          if (existing == null) {
            final added = await _printerConfigurationService!.addBarPrinterByIP('192.168.0.204', port: 9100);
            debugPrint(added
              ? '✅ Auto-added Bar Printer (192.168.0.204:9100)'
              : '⚠️ Failed to auto-add Bar Printer');
          } else {
            debugPrint('ℹ️ Bar Printer already configured: ${existing.fullAddress}');
          }

          // Auto-add Sweet Counter printer if missing (same IP:port, different name)
          final sweetExists = _printerConfigurationService!.configurations.any(
            (c) => c.ipAddress == '192.168.0.181' && c.port == 9100 && c.name == 'Sweet Counter Receipt',
          );
          if (!sweetExists) {
            final addedSweet = await _printerConfigurationService!.addSweetCounterPrinterByIP('192.168.0.181', port: 9100);
            debugPrint(addedSweet
              ? '✅ Auto-added Sweet Counter Receipt (192.168.0.181:9100)'
              : '⚠️ Failed to auto-add Sweet Counter Receipt');
          } else {
            debugPrint('ℹ️ Sweet Counter Receipt already configured at 192.168.0.181:9100');
          }

          await _printerConfigurationService!.refreshConfigurations();
        } catch (e) {
          debugPrint('⚠️ Auto-add Bar/Sweet printers failed: $e');
        }
      } catch (e) {
        debugPrint('⚠️ PrinterConfigurationService initialization failed, continuing: $e');
      }
      
      // 🚨 URGENT: Initialize UnifiedPrinterService for Epson printer discovery
      widget.progressService.addMessage('🚀 Setting up unified printer service...');
      _unifiedPrinterService = UnifiedPrinterService.getInstance(tenantDatabase);
      try {
        await _unifiedPrinterService!.initialize().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('⚠️ UnifiedPrinterService initialization timed out, continuing...');
            return false;
          },
        );
        debugPrint('✅ UnifiedPrinterService initialized');
      } catch (e) {
        debugPrint('⚠️ UnifiedPrinterService initialization failed, continuing: $e');
      }
      
      widget.progressService.addMessage('🎛️ Setting up printer assignments...');
      
      // Initialize enhanced printer assignment service (with full multi-printer support)
      widget.progressService.addMessage('🎯 Setting up enhanced printer assignments...');
      _enhancedPrinterAssignmentService = EnhancedPrinterAssignmentService(
        databaseService: tenantDatabase,
        printerConfigService: _printerConfigurationService!,
        unifiedPrinterService: _unifiedPrinterService, // 🚨 URGENT: Pass UnifiedPrinterService for Epson printer support
      );
      
      // Initialize the enhanced assignment service
      await _enhancedPrinterAssignmentService!.initialize();
      debugPrint('✅ EnhancedPrinterAssignmentService initialized with multi-printer support');
      
      // Initialize cross-platform printer sync service
      widget.progressService.addMessage('🌐 Setting up cross-platform sync...');
      _crossPlatformPrinterSyncService = CrossPlatformPrinterSyncService(
        databaseService: tenantDatabase,
        assignmentService: _enhancedPrinterAssignmentService!,
      );
      await _crossPlatformPrinterSyncService!.initialize();
      debugPrint('✅ CrossPlatformPrinterSyncService initialized with automatic persistence');
      
      // Initialize enhanced printer manager (handles all printer functionality)
      widget.progressService.addMessage('🚀 Setting up Enhanced Printer Management System...');
      if (_printingService != null && _printerConfigurationService != null && _enhancedPrinterAssignmentService != null) {
        _enhancedPrinterManager = EnhancedPrinterManager(
          databaseService: tenantDatabase,
          printerConfigService: _printerConfigurationService!,
          printingService: _printingService!,
          assignmentService: _enhancedPrinterAssignmentService!,
        );
        
        // Initialize enhanced printer manager (no automatic discovery)
        try {
          await _enhancedPrinterManager!.initialize().timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              debugPrint('⚠️ EnhancedPrinterManager initialization timed out, continuing...');
              return;
            },
          );
          debugPrint('✅ EnhancedPrinterManager initialized - manual discovery only');
        } catch (e) {
          debugPrint('⚠️ EnhancedPrinterManager initialization failed, continuing: $e');
        }
      } else {
        debugPrint('⚠️ Could not initialize EnhancedPrinterManager - required services not available');
      }
      
      // Initialize printer validation service (requires all printer services)
      widget.progressService.addMessage('🔒 Setting up printer validation system...');
      if (_printerConfigurationService != null && _enhancedPrinterAssignmentService != null && _enhancedPrinterManager != null) {
        _printerValidationService = PrinterValidationService(
          databaseService: tenantDatabase,
          printerConfigService: _printerConfigurationService!,
          assignmentService: _enhancedPrinterAssignmentService!,
          printerManager: _enhancedPrinterManager!,
        );
        debugPrint('✅ PrinterValidationService initialized - kitchen validation system ready');
      } else {
        debugPrint('⚠️ Could not initialize PrinterValidationService - required services not available');
      }
      
      // Initialize robust kitchen service (unifies all send to kitchen operations)
      widget.progressService.addMessage('🍽️ Setting up robust kitchen service...');
      if (_printingService != null && _enhancedPrinterAssignmentService != null && _printerConfigurationService != null) {
        _robustKitchenService = RobustKitchenService(
          databaseService: tenantDatabase,
          printingService: _printingService!,
          assignmentService: _enhancedPrinterAssignmentService!,
          printerConfigService: _printerConfigurationService!,
          orderLogService: _orderLogService,
        );
        debugPrint('✅ RobustKitchenService initialized - comprehensive send to kitchen system ready');
      } else {
        debugPrint('⚠️ Could not initialize RobustKitchenService - required services not available');
      }
      
      // Free cloud printing service removed
      // Initialize KitchenPrintingService
      widget.progressService.addMessage('🍳 Setting up kitchen printing service...');
      if (_printingService != null && _enhancedPrinterAssignmentService != null && _printerConfigurationService != null) {
        _kitchenPrintingService = KitchenPrintingService(
          printingService: _printingService!,
          assignmentService: _enhancedPrinterAssignmentService!,
          printerConfigService: _printerConfigurationService!,
        );
        if (_kitchenPrintingService != null) {
          await _kitchenPrintingService!.initialize();
          debugPrint('✅ KitchenPrintingService initialized');
        } else {
          debugPrint('⚠️ KitchenPrintingService creation failed');
        }
      } else {
        debugPrint('⚠️ Could not initialize KitchenPrintingService - required services not available');
      }
      
      // Initialize LoyaltyService
      widget.progressService.addMessage('💰 Setting up loyalty service...');
      _loyaltyService = LoyaltyService(tenantDatabase);
      debugPrint('✅ LoyaltyService initialized');
      
      // Initialize tenant-specific printer services
      widget.progressService.addMessage('🏪 Setting up tenant-specific printer system...');
      if (_printingService != null && _enhancedPrinterAssignmentService != null && _printerConfigurationService != null) {
        // Initialize tenant printer service
        _tenantPrinterService = TenantPrinterService(
          databaseService: tenantDatabase,
          printerConfigService: _printerConfigurationService!,
          assignmentService: _enhancedPrinterAssignmentService!,
          printingService: _printingService!,
          authService: widget.authService,
        );
        
        // CRITICAL FIX: DISABLE TenantCloudPrintingService to prevent spinner issues
        // _tenantCloudPrintingService = TenantCloudPrintingService(
        //   databaseService: tenantDatabase,
        //   tenantPrinterService: _tenantPrinterService!,
        //   printingService: _printingService!,
        //   authService: widget.authService,
        // );
        debugPrint('⚠️ TenantCloudPrintingService DISABLED to prevent spinner issues');
        
        // Initialize tenant printer integration service - FIXED: Add null check
        if (_tenantPrinterService != null) {
          _tenantPrinterIntegrationService = TenantPrinterIntegrationService(
            databaseService: tenantDatabase,
            tenantPrinterService: _tenantPrinterService!,
            // cloudPrintingService removed
            assignmentService: _enhancedPrinterAssignmentService!,
            printingService: _printingService!,
            authService: widget.authService,
          );
          
          // Initialize tenant printer system
          if (widget.authService.currentSession != null) {
            final tenantId = widget.authService.currentSession!.restaurantId;
            final restaurantId = widget.authService.currentRestaurant?.id ?? tenantId;
            
            final tenantInitialized = await _tenantPrinterIntegrationService!.initialize(
              tenantId: tenantId,
              restaurantId: restaurantId,
            );
            
            if (tenantInitialized) {
              debugPrint('✅ Tenant printer system initialized successfully for tenant: $tenantId');
            } else {
              debugPrint('⚠️ Tenant printer system initialization failed, continuing with local printing only');
            }
          } else {
            debugPrint('⚠️ No current session - tenant printer system will be initialized on login');
          }
        } else {
          debugPrint('⚠️ TenantPrinterService initialization failed - skipping tenant printer integration');
        }
      } else {
        debugPrint('⚠️ Could not initialize tenant printer services - required services not available');
        debugPrint('⚠️ _printingService: ${_printingService != null}');
        debugPrint('⚠️ _enhancedPrinterAssignmentService: ${_enhancedPrinterAssignmentService != null}');
        debugPrint('⚠️ _printerConfigurationService: ${_printerConfigurationService != null}');
      }
      
      // Connect unified sync service to restaurant
      if (_unifiedSyncService != null && widget.authService.currentRestaurant != null && widget.authService.currentSession != null) {
        widget.progressService.addMessage('🔗 Connecting to restaurant for unified sync...');
        try {
          await _unifiedSyncService!.connectToRestaurant(
            widget.authService.currentRestaurant!,
            widget.authService.currentSession!,
          );
          debugPrint('✅ Unified sync service connected to restaurant');
          
          // CRITICAL FIX: Set required services for category sync to work
          _unifiedSyncService!.setServices(
            databaseService: tenantDatabase,
            orderService: _orderService,
            menuService: _menuService,
            userService: _userService,
            inventoryService: _inventoryService,
            tableService: _tableService,
          );
          debugPrint('✅ Unified sync service configured with all required services');
          
          // FIXED: Proper Firebase sync with DEBOUNCED UI updates to prevent infinite loops
          _unifiedSyncService!.setCallbacks(
            onOrdersUpdated: () {
              debugPrint('🔄 Orders updated from Firebase - DEBOUNCED refresh');
              // Use debounced refresh to prevent infinite loops
              _debouncedRefresh();
            },
            onMenuItemsUpdated: () {
              debugPrint('🔄 Menu items updated from Firebase - DEBOUNCED refresh');
              _debouncedRefresh();
            },
            onUsersUpdated: () {
              debugPrint('🔄 Users updated from Firebase - DEBOUNCED refresh');
              _debouncedRefresh();
            },
            onInventoryUpdated: () {
              debugPrint('🔄 Inventory updated from Firebase - DEBOUNCED refresh');
              _debouncedRefresh();
            },
            onTablesUpdated: () {
              debugPrint('🔄 Tables updated from Firebase - DEBOUNCED refresh');
              _debouncedRefresh();
            },
            onSyncProgress: (message) {
              debugPrint('🔄 Sync progress: $message');
            },
            onSyncError: (error) {
              debugPrint('❌ Sync error: $error');
            },
          );

          // Non-blocking initial reconcile to align local DB with server state
          try {
            unawaited(_unifiedSyncService!.manualSync());
            // Real-time sync is automatically handled by the new unified sync service
            // Kick off ghost-order cleanup (non-blocking)
            try {
              // Ghost order cleanup is now handled by the sync fix service
            } catch (_) {}
            // ONE-OFF: Remove a specific problematic order if it exists
            try {
              final orderService = _orderService;
              if (orderService != null) {
                // Do not await; run in background to avoid blocking UI
                unawaited(orderService.deleteOrderByOrderNumber('DI-31624-1624'));
              }
            } catch (_) {}
          } catch (e) {
            debugPrint('⚠️ Initial reconcile trigger failed: $e');
          }
        } catch (e) {
          debugPrint('❌ Failed to connect unified sync service: $e');
          // Don't fail initialization - continue in offline mode
        }
      } else {
        debugPrint('⚠️ Unified sync service or restaurant/session not available');
      }
      
      // Initialize cloud sync service for real-time updates across devices
      widget.progressService.addMessage('☁️ Setting up cloud synchronization...');
      final currentRestaurant = widget.authService.currentRestaurant;
      final currentUserSession = widget.authService.currentSession;
      
      if (currentRestaurant != null && currentUserSession != null) {
        try {
          // Use the already initialized unified sync service
          if (_unifiedSyncService != null) {
            await _unifiedSyncService!.connectToRestaurant(currentRestaurant, currentUserSession);
            debugPrint('✅ Unified Firebase sync connected to restaurant');
            widget.progressService.addMessage('✅ Real-time synchronization active');
          } else {
            debugPrint('⚠️ Unified sync service not available');
            widget.progressService.addMessage('⚠️ Unified sync service not available');
          }
        } catch (e) {
          debugPrint('❌ Failed to connect unified sync: $e');
          widget.progressService.addMessage('⚠️ Unified sync connection failed - continuing in local mode');
        }
      } else {
        debugPrint('⚠️ No restaurant or user session available for multi-device sync initialization');
        widget.progressService.addMessage('⚠️ Multi-device sync requires restaurant and user session');
      }
      
      // Initialize auto printer discovery service (requires printing service, printer config service, and multi printer manager)
      widget.progressService.addMessage('🔍 Setting up automatic printer discovery...');
      if (_printingService != null && _printerConfigurationService != null && _enhancedPrinterAssignmentService != null) {
        // Removed: MultiPrinterManager and AutoPrinterDiscoveryService (redundant)
        // Functionality moved to unified printer service
        debugPrint('ℹ️ Printer discovery will be handled by unified printer service');
      } else {
        debugPrint('⚠️ Printer services not available - will be handled by unified service');
      }
      
      debugPrint('🎉 All POS services initialized successfully');
      
      // CREATE DUMMY DATA FOR TESTING (only if no existing data)
      // ENABLED: Test data creation for registration
      final existingOrderCount = _orderService?.allOrders.length ?? 0;
      if (existingOrderCount == 0) {
        widget.progressService.addMessage('🎯 Creating demo servers and orders...');
        await _createDummyData();
      } else {
        debugPrint('📋 Found $existingOrderCount existing orders - skipping dummy data creation');
      }
      
    } catch (e, stackTrace) {
      debugPrint('❌ Error initializing services: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  /// Get network info (using the real NetworkInfo from network_info_plus)
  Future<NetworkInfo> _getNetworkInfo() async {
    // Return the real NetworkInfo instance from network_info_plus package
    return NetworkInfo();
  }
  
  /// Create dummy data for testing
  Future<void> _createDummyData() async {
    try {
      debugPrint('🎯 Creating demo data for testing...');
      
      // Check if we already have users (don't clear existing users!)
      final existingUserCount = _userService?.users.length ?? 0;
      if (existingUserCount > 0) {
        debugPrint('👥 Found $existingUserCount existing users - preserving them and skipping user creation');
        
        // Only create demo orders if none exist
        final existingOrderCount = _orderService?.allOrders.length ?? 0;
        if (existingOrderCount == 0) {
          debugPrint('📋 No existing orders - creating demo order...');
          await _createDemoOrder();
        } else {
          debugPrint('📋 Found $existingOrderCount existing orders - skipping demo order creation');
        }
        return;
      }
      
      // Only if NO users exist, create the default admin user
      debugPrint('🔧 No users found - creating default admin user...');
      
      // Create default admin user
      final adminUser = User(
        id: 'admin',
        name: 'Admin',
        role: UserRole.admin,
        pin: '1234',
        isActive: true,
        adminPanelAccess: true,
        createdAt: DateTime.now(),
      );
      
      await _userService!.addUser(adminUser);
      debugPrint('✅ Default admin user created');
      
      // Create a sample order for testing with admin user
      await _createDemoOrder();
      
      debugPrint('🎉 Demo data created with default admin user!');
      
    } catch (e) {
      debugPrint('⚠️ Error creating demo data (not critical): $e');
      // Don't throw error - demo data creation failure shouldn't stop the app
    }
  }
  
  /// Create a demo order for testing
  Future<void> _createDemoOrder() async {
    try {
      final sampleOrder = await _orderService!.createOrder(
        orderType: 'dineIn',
        customerName: 'Demo Customer',
        userId: 'admin', // Use admin user ID
      );
      
      // Add a sample item to the order (if menu items exist)
      final menuItems = await _menuService!.getMenuItems();
      if (menuItems.isNotEmpty) {
        final orderItem = OrderItem(
          id: 'demo-item-${DateTime.now().millisecondsSinceEpoch}',
          menuItem: menuItems.first,
          quantity: 1,
        );
        
        // Create new order with the item using copyWith
        final updatedOrder = sampleOrder.copyWith(
          items: [orderItem],
        );
        
        await _orderService!.saveOrder(updatedOrder);
        debugPrint('✅ Demo order created with admin user');
      }
    } catch (e) {
      debugPrint('⚠️ Could not create demo order: $e');
    }
  }
  
  /// Clear all services and cached data for restaurant isolation
  Future<void> _clearAllServicesForIsolation() async {
    try {
      debugPrint('🧹 Clearing all services for restaurant isolation...');
      
      // Clear all service instances
      _orderService = null;
      _menuService = null;
      _userService = null;
      _tableService = null;
      _paymentService = null;
      _printingService = null;
      _orderLogService = null;
      _activityLogService = null;
      _loyaltyService = null;
      _inventoryService = null;
      _printerConfigurationService = null;
      _unifiedSyncService = null;
      _enhancedPrinterAssignmentService = null;
      _crossPlatformPrinterSyncService = null;
      _enhancedPrinterManager = null;
      _printerValidationService = null;
      _robustKitchenService = null;
      // _freeCloudPrintingService removed
      _kitchenPrintingService = null;
      _tenantPrinterService = null;
      // _tenantCloudPrintingService removed
      _tenantPrinterIntegrationService = null;
      
      // Reset initialization flags
      _servicesInitialized = false;
      _isInitializing = false;
      
      debugPrint('✅ All services cleared for isolation');
    } catch (e) {
      debugPrint('❌ Error clearing services: $e');
    }
  }

  // Helper methods removed - admin user is now set immediately after UserService initialization

  @override
  Widget build(BuildContext context) {
    // Build providers list with null safety
    final providers = <ChangeNotifierProvider>[
      // Core service providers - always available
      ChangeNotifierProvider<MultiTenantAuthService>.value(value: widget.authService),
      ChangeNotifierProvider<InitializationProgressService>.value(value: widget.progressService),
      ChangeNotifierProvider<MenuService?>.value(value: _menuService),
      ChangeNotifierProvider<OrderService?>.value(value: _orderService),
      ChangeNotifierProvider<OrderLogService?>.value(value: _orderLogService),
      ChangeNotifierProvider<ActivityLogService?>.value(value: _activityLogService),
      ChangeNotifierProvider<LoyaltyService?>.value(value: _loyaltyService),
      ChangeNotifierProvider<InventoryService?>.value(value: _inventoryService),
    ];
    
    // Add authenticated services (with null support for safe access)
    providers.add(ChangeNotifierProvider<UserService?>.value(value: _userService));
    providers.add(ChangeNotifierProvider<TableService?>.value(value: _tableService));
    providers.add(ChangeNotifierProvider<PaymentService?>.value(value: _paymentService));
    providers.add(ChangeNotifierProvider<PrintingService?>.value(value: _printingService));
    providers.add(ChangeNotifierProvider<PrinterConfigurationService?>.value(value: _printerConfigurationService));
    providers.add(ChangeNotifierProvider<UnifiedPrinterService?>.value(value: _unifiedPrinterService));
    providers.add(ChangeNotifierProvider<EnhancedPrinterAssignmentService?>.value(value: _enhancedPrinterAssignmentService));
    providers.add(ChangeNotifierProvider<CrossPlatformPrinterSyncService?>.value(value: _crossPlatformPrinterSyncService));
    // Removed: AutoPrinterDiscoveryService provider (redundant)
    providers.add(ChangeNotifierProvider<EnhancedPrinterManager?>.value(value: _enhancedPrinterManager));
    providers.add(ChangeNotifierProvider<PrinterValidationService?>.value(value: _printerValidationService));
    providers.add(ChangeNotifierProvider<RobustKitchenService?>.value(value: _robustKitchenService));
    // FreeCloudPrintingService provider removed
    providers.add(ChangeNotifierProvider<UnifiedSyncService?>.value(value: _unifiedSyncService));
    providers.add(ChangeNotifierProvider<TenantPrinterService?>.value(value: _tenantPrinterService));
    // Cloud printing provider removed
    providers.add(ChangeNotifierProvider<TenantPrinterIntegrationService?>.value(value: _tenantPrinterIntegrationService));
    providers.add(ChangeNotifierProvider<KitchenPrintingService?>.value(value: _kitchenPrintingService));
    
    return MultiProvider(
      providers: [
        ...providers,
        // Add DatabaseService provider (tenant database) - not a ChangeNotifier
        if (widget.authService.tenantDatabase != null)
          Provider<DatabaseService>.value(value: widget.authService.tenantDatabase!),
      ],
      child: MaterialApp(
        title: 'AI POS System',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
          // Tablet-specific theme adjustments
          appBarTheme: AppBarTheme(
            elevation: 0,
            centerTitle: true,
            titleTextStyle: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          // Responsive text scaling for tablets
          textTheme: Theme.of(context).textTheme.apply(
            bodyColor: Colors.black87,
            displayColor: Colors.black87,
          ),
        ),
        navigatorKey: _navigatorKey,
        home: ScaffoldMessenger(
          child: _buildMainScreen(),
        ),
      ),
    );
  }

  Widget _buildMainScreen() {
    return Builder(
      builder: (context) {
        debugPrint('🔍 BUILD: _buildMainScreen called');
        debugPrint('🔍 BUILD: isAuthenticated=${widget.authService.isAuthenticated}, servicesInitialized=$_servicesInitialized, userService=${_userService != null}');
        debugPrint('🔍 BUILD: Current restaurant: ${widget.authService.currentRestaurant?.name ?? 'null'}');
        
        // Show authentication screen if not authenticated
        if (!widget.authService.isAuthenticated) {
          debugPrint('🔍 BUILD: Showing RestaurantAuthScreen - user not authenticated');
          return const RestaurantAuthScreen();
        }
        
        // Show progress screen while services are initializing (only when authenticated)
        if (widget.authService.isAuthenticated && !_servicesInitialized) {
          debugPrint('🔍 BUILD: Showing InitializationProgressScreen - authenticated but services not ready');
          return InitializationProgressScreen(
            restaurantName: widget.authService.currentRestaurant?.name ?? 'Restaurant',
          );
        }
        
        // CRITICAL: Ensure ALL required services are available before showing main UI
        if (_userService == null || _tableService == null || _paymentService == null || _printerConfigurationService == null) {
          debugPrint('🔍 BUILD: Services not ready - userService=${_userService != null}, tableService=${_tableService != null}, paymentService=${_paymentService != null}, printerConfigService=${_printerConfigurationService != null}');
          return Scaffold(
            backgroundColor: Colors.blue.shade50,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Finalizing services...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Almost ready!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.blue.shade500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        // ADDITIONAL CHECK: Validate that Provider services are actually accessible
        try {
          final orderService = Provider.of<OrderService>(context, listen: false);
          
          // Try to get UserService safely - now using nullable provider
          UserService? userService;
          try {
            userService = Provider.of<UserService?>(context, listen: false);
          } catch (e) {
            debugPrint('🔍 BUILD: UserService not available in Provider tree: $e');
          }
          
          final userCount = userService?.users.length ?? 0;
          final orderCount = orderService.allOrders.length;
          
          debugPrint('🔍 BUILD: Provider validation passed - Users: $userCount, Orders: $orderCount');
          
        } catch (e) {
          debugPrint('❌ BUILD: Provider services not accessible: $e');
          return Scaffold(
            backgroundColor: Colors.orange.shade50,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.orange.shade600),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Connecting services...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.orange.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please wait a moment...',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange.shade500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        // All services are ready - show main screen with extra safety
        debugPrint('🔍 BUILD: All services ready, showing OrderTypeSelectionScreen');
        try {
          return const OrderTypeSelectionScreen();
        } catch (e, stackTrace) {
          debugPrint('❌ BUILD: Error showing OrderTypeSelectionScreen: $e');
          debugPrint('Stack trace: $stackTrace');
          
          // Fallback error screen
          return Scaffold(
            backgroundColor: Colors.red.shade50,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Application Error',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Error: $e',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      // Retry initialization
                      _initializeServicesAfterAuth();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
  
  /// Debounced refresh to prevent infinite UI loops
  void _debouncedRefresh() {
    if (_isRefreshing) {
      debugPrint('🔄 Refresh already in progress, skipping...');
      return;
    }
    
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted && !_isRefreshing) {
        _isRefreshing = true;
        debugPrint('🔄 Executing debounced refresh...');
        
        // Use post frame callback to ensure safe UI update
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              // Trigger UI refresh
            });
          }
          
          // Reset flag after UI update
          Timer(const Duration(milliseconds: 200), () {
            _isRefreshing = false;
          });
        });
      }
    });
  }
}
