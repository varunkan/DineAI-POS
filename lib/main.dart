import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:ui' show PlatformDispatcher;
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

  // 🔧 GLOBAL ERROR HANDLING: Set up global error handlers to prevent app crashes
  FlutterError.onError = (FlutterErrorDetails details) {
    // CRITICAL: This catches Flutter framework errors but app continues running
    // Production apps should send to crash reporting service like Sentry/Crashlytics
  };

  // Handle platform errors (Android/iOS specific)
  PlatformDispatcher.instance.onError = (error, stack) {
    // CRITICAL: Return true prevents the error from crashing the app
    // This catches Android/iOS level errors that would normally terminate the app
    return true;
  };

  // Handle uncaught asynchronous errors with runZonedGuarded
  await runZonedGuarded(() async {
  if (!EnvironmentConfig.isDevelopment && !EnvironmentConfig.isProduction) {
    EnvironmentConfig.setEnvironment(Environment.production);
  }
  
  // Disable Provider debug check to allow nullable service types
  Provider.debugCheckInvalidValueType = null;
  
  
  // Initialize Firebase first (with error handling)
  try {
    await FirebaseConfig.initialize();
    
      // Test Firebase connection (with timeout and fallback)
  try {
    final connectionResults = await FirebaseConnectionTest.testConnection().timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        return <String, dynamic>{
          'firebase_initialized': true,
          'firestore_available': false,
          'connection_timeout': true,
        };
      },
    );
    FirebaseConnectionTest.printResults(connectionResults);
  } catch (e) {
  }
  } catch (e) {
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
      },
    );
  } catch (e) {
  }
  
  // Connect progress service to auth service
  authService.setProgressService(progressService);
  
  
  runApp(MyApp(
    authService: authService,
    progressService: progressService,
    prefs: prefs,
  ));

  }, (error, stackTrace) {
    // Handle uncaught asynchronous errors

    // In a production app, you might want to:
    // 1. Report the error to a crash reporting service
    // 2. Show a user-friendly error dialog
    // 3. Attempt to recover gracefully

    // For now, we just log it to prevent the app from crashing
  });
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

  // 🔧 RESOURCE MANAGEMENT: Track all timers and async operations for cleanup
  Timer? _backgroundSyncTimer;
  Timer? _healthCheckTimer;
  Timer? _memoryCleanupTimer;
  StreamSubscription<void>? _orderRefreshSubscription;

  // Background operation tracking
  final Set<Future<void>> _activeBackgroundOperations = {};
  bool _isBackgroundSyncActive = false;
  bool _isAppInBackground = false;

  // Service references for recovery
  late DatabaseService _databaseService;
  
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

    // 🔧 RESOURCE CLEANUP: Cancel all timers
    _refreshTimer?.cancel();
    _backgroundSyncTimer?.cancel();
    _healthCheckTimer?.cancel();
    _memoryCleanupTimer?.cancel();

    // Cancel all background operations
    _cancelAllBackgroundOperations();

    // Cancel order refresh subscription
    _orderRefreshSubscription?.cancel();

    // Stop background sync if active
    _isBackgroundSyncActive = false;


    // CRITICAL FIX: Do NOT dispose services here!
    // Services should remain available throughout app lifecycle
    // Only dispose when truly shutting down the app

    super.dispose();
  }

  /// 🔧 Cancel all active background operations
  void _cancelAllBackgroundOperations() {
    try {
      // Mark all active operations as cancelled
      for (final operation in _activeBackgroundOperations) {
        // Note: We can't actually cancel Futures, but we can track them
      }
      _activeBackgroundOperations.clear();

      // Cancel any pending sync operations in services
      _cancelServiceBackgroundOperations();

    } catch (e) {
    }
  }

  /// Cancel background operations in all services
  void _cancelServiceBackgroundOperations() {
    try {
      // Cancel order service background operations
      if (_orderService != null) {
        // Add cancellation logic to order service if needed
      }

      // Cancel menu service background operations
      if (_menuService != null) {
      }

      // Cancel user service background operations
      if (_userService != null) {
      }
    } catch (e) {
    }
  }

  /// Handle authentication state changes
  void _onAuthStateChanged() {
    
    if (mounted) {
      setState(() {
        if (widget.authService.isAuthenticated) {
          // Use post frame callback to ensure widget tree is ready
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _initializeServicesAfterAuth();
          });
        } else {
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
      
      // Clear all services for proper isolation
      await _clearAllServicesForIsolation();
      
      // Preserve service instances and order data for next login
      // This prevents data loss during quick logout/login cycles
      
    } catch (e) {
    }
  }

  /// Handle app lifecycle changes - logout when app is closed
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    
    // Only logout when app is truly being closed or detached
    // Do NOT logout for inactive/hidden states (these are normal during app switching)
    if (state == AppLifecycleState.detached) {
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
      }
    } catch (e) {
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
  }

  /// Initialize services that can be created synchronously (before SharedPreferences)
  void _initializeServiceInstancesSync() {
    // All services are already initialized in _initializeCoreServices()
  }
  
  /// Initialize services that require SharedPreferences asynchronously
  void _initializeServiceInstancesAsync() async {
    // This will be called after SharedPreferences is available
  }

  /// Initialize services after authentication
  Future<void> _initializeServicesAfterAuth() async {

    if (_isInitializing) {
      return;
    }

    if (_servicesInitialized) {
      return;
    }

    _isInitializing = true;

    // 🔧 ERROR BOUNDARY: Wrap entire initialization in try-catch to prevent app hanging
    try {
      
      final tenantDatabase = widget.authService.tenantDatabase;
      if (tenantDatabase == null) {
        throw Exception('Tenant database not available after authentication');
      }
      
      
      // Get shared preferences
      final prefs = await SharedPreferences.getInstance();
      
      // Initialize unified Firebase sync service
      widget.progressService.addMessage('🔄 Initializing unified sync service...');
      _unifiedSyncService = UnifiedSyncService.instance;
      await _unifiedSyncService!.initialize();
      
      // Reset disposal state for core services before reinitialization
      try {
        _orderService?.resetDisposalState();
        _menuService?.resetDisposalState();
      } catch (e) {
      }
      
      // Initialize all services with proper tenant database
      await _initializeAllServices(prefs, tenantDatabase);
      
      _servicesInitialized = true;

      // Trigger UI rebuild
      if (mounted) {
        setState(() {});
      } else {
      }

      // 🚀 LIGHTNING FAST: Start background sync operations immediately after UI is available
      _startLightningFastBackgroundSync();
      
    } catch (e, stackTrace) {
      
      // CRITICAL FIX: Try to reinitialize services if they fail
      try {
        await _reinitializeFailedServices();
        _servicesInitialized = true;
      } catch (reinitError) {
        
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
            }
          } catch (scaffoldError) {
            // Fallback: just log the error
          }
        } else {
        }

        // 🔧 ERROR RECOVERY: Attempt to recover from initialization failures
        await _attemptInitializationRecovery();

      } catch (recoveryError) {
        // At this point, the app might be in a bad state, but we'll let it continue
        // with whatever services did initialize successfully
      }
    } finally {
      _isInitializing = false;
    }
  }
  
  /// Attempt to recover from initialization failures
  Future<void> _attemptInitializationRecovery() async {
    try {

      // Step 1: Check which services failed to initialize
      final failedServices = await _identifyFailedServices();
      if (failedServices.isEmpty) {
        return;
      }


      // Step 2: Attempt to recover each failed service individually
      for (final serviceName in failedServices) {
        try {
          await _recoverService(serviceName);
        } catch (serviceError) {
          // Continue with other services even if one fails
        }
      }

      // Step 3: Re-attempt full initialization if any services were recovered
      if (failedServices.isNotEmpty) {
        await Future.delayed(const Duration(seconds: 2)); // Brief pause
        await _initializeServicesAfterAuth();
      }

    } catch (e) {
      // Don't rethrow - we want the app to continue even if recovery fails
    }
  }

  /// Identify which services failed to initialize properly
  Future<List<String>> _identifyFailedServices() async {
    final failedServices = <String>[];

    try {
      // Check database service
      if (_databaseService?.database == null) {
        failedServices.add('DatabaseService');
      }

      // Check order service
      if (_orderService == null) {
        failedServices.add('OrderService');
      }

      // Check menu service
      if (_menuService == null) {
        failedServices.add('MenuService');
      }

      // Check user service
      if (_userService == null) {
        failedServices.add('UserService');
      }

      // Check printing service (if it exists and should be healthy)
      if (_printingService != null && !_printingService!.isHealthy) {
        failedServices.add('PrintingService');
      }

    } catch (e) {
    }

    return failedServices;
  }

  /// Attempt to recover a specific service
  Future<void> _recoverService(String serviceName) async {
    switch (serviceName) {
      case 'DatabaseService':
        await _recoverDatabaseService();
        break;
      case 'OrderService':
        await _recoverOrderService();
        break;
      case 'MenuService':
        await _recoverMenuService();
        break;
      case 'UserService':
        await _recoverUserService();
        break;
      case 'PrintingService':
        await _recoverPrintingService();
        break;
      default:
    }
  }

  /// Recover database service
  Future<void> _recoverDatabaseService() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final tenantDatabase = widget.authService.tenantDatabase;

      if (tenantDatabase != null) {
        _databaseService = tenantDatabase;
      } else {
        throw Exception('No tenant database available for recovery');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Recover order service
  Future<void> _recoverOrderService() async {
    try {
      if (_databaseService != null && _orderLogService != null && _inventoryService != null) {
        _orderService = OrderService(_databaseService!, _orderLogService!, _inventoryService!);
      } else {
        throw Exception('Required services not available for OrderService recovery');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Recover menu service
  Future<void> _recoverMenuService() async {
    try {
      if (_databaseService != null) {
        _menuService = MenuService(_databaseService!);
        await _menuService!.initialize();
      } else {
        throw Exception('DatabaseService not available for MenuService recovery');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Recover user service
  Future<void> _recoverUserService() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_databaseService != null) {
        _userService = UserService(prefs, _databaseService!);
      } else {
        throw Exception('DatabaseService not available for UserService recovery');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Recover printing service
  Future<void> _recoverPrintingService() async {
    try {
      if (_printingService != null) {
        await _printingService!.reinitializeIfNeeded();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Reinitialize failed services
  Future<void> _reinitializeFailedServices() async {
    try {
      
      // Check which services need reinitialization
      if (_printingService != null && !_printingService!.isHealthy) {
        await _printingService!.reinitializeIfNeeded();
      }
      
      if (_robustKitchenService != null && !_robustKitchenService!.isHealthy) {
        await _robustKitchenService!.reinitializeIfNeeded();
      }
      
      // Reinitialize other critical services as needed
    } catch (e) {
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
        
        // CRITICAL: Set Admin as current user immediately after UserService is initialized
        try {
          final users = _userService!.users;
          User? admin;
          
          for (int i = 0; i < users.length; i++) {
          }
          
          // First try to find an active admin user
          for (final u in users) {
            if (u.role == UserRole.admin && u.isActive) {
              admin = u;
              break;
            }
          }
          
          // Fallback to user with id 'admin'
          if (admin == null) {
            admin = users.where((u) => u.id == 'admin').cast<User?>().firstOrNull;
            if (admin != null) {
            }
          }
          
          // Fallback to first user if no admin found
          if (admin == null) {
            admin = users.isNotEmpty ? users.first : null;
            if (admin != null) {
            }
          }
          
          if (admin != null) {
            _userService!.setCurrentUser(admin);
            
            // Verify the current user was set
            final currentUser = _userService!.currentUser;
            
            // Also set OrderLogService context if available
            if (_orderLogService != null) {
              _orderLogService!.setCurrentUser(admin.id, admin.name);
            }
          } else {
            
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
            
            await _userService!.addUser(adminUser);
            _userService!.setCurrentUser(adminUser);
            
            // Verify the current user was set
            final currentUser = _userService!.currentUser;
            
            // Set OrderLogService context for new admin
            if (_orderLogService != null) {
              _orderLogService!.setCurrentUser(adminUser.id, adminUser.name);
            }
          }
        } catch (e, stackTrace) {
        }
        
      } catch (e) {
        // Continue anyway - app can work without users initially
      }
      
      // Admin user is now set immediately after UserService initialization above
      
      // Initialize TableService early (needed for orders)
      widget.progressService.addMessage('🍽️ Setting up table management...');
      _tableService = TableService(prefs);
      
      // Initialize PaymentService early (needed for UI)
      widget.progressService.addMessage('💳 Setting up payment processing...');
      if (_orderService != null && _inventoryService != null) {
        _paymentService = PaymentService(_orderService!, _inventoryService!);
      } else {
      }
      
      // Initialize PrintingService early (needed for UI)
      widget.progressService.addMessage('🖨️ Configuring printing services...');
      final networkInfo = await _getNetworkInfo();
      _printingService = PrintingService(prefs, networkInfo);
      
      // ENABLE: Trigger immediate auto-reconnect to previously connected printers
      widget.progressService.addMessage('🔗 Reconnecting to previously connected printers...');
      try {
        // Wait a bit for the printing service to fully initialize
        await Future.delayed(const Duration(seconds: 2));
        // Call immediate auto-reconnect for faster reconnection after login
        await _printingService!.immediateAutoReconnect();
      } catch (e) {
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
          }
        } catch (e) {
        }
        
      } else {
      }
      
      // Create new MenuService instance with updated database
      widget.progressService.addMessage('🍽️ Loading menu items...');
      _menuService = MenuService(tenantDatabase);
      
      // CRITICAL: Ensure MenuService is fully initialized before proceeding
      await _menuService!.ensureInitialized();
      await _menuService!.ensureReceiptsCategoryExists();
      
      // Wait a moment for any pending database operations
      await Future.delayed(const Duration(milliseconds: 100));
      
      
      // CRITICAL FIX: Set global MenuService reference for direct reload after sync
      MultiTenantAuthService.setGlobalMenuService(_menuService!);
      
      // CRITICAL FIX: Set callback to reload MenuService when categories are synced from Firebase
      widget.authService.setCategoriesSyncedCallback(() async {
        if (_menuService != null) {
          await _menuService!.reloadMenuData();
        }
      });
      
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
      }
      
      widget.progressService.addMessage('🔧 Setting up printer configurations...');
      _printerConfigurationService = PrinterConfigurationService(tenantDatabase);
      // FIXED: Add timeout to prevent hanging during initialization
      try {
        await _printerConfigurationService!.initializeTable().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            return;
          },
        );

        // Auto-add Bar Printer if missing
        try {
          final existing = _printerConfigurationService!.getConfigurationByIP('192.168.0.204', 9100);
          if (existing == null) {
            final added = await _printerConfigurationService!.addBarPrinterByIP('192.168.0.204', port: 9100);
            // Auto-add successful
          } else {
          }

          // Auto-add Sweet Counter printer if missing (same IP:port, different name)
          final sweetExists = _printerConfigurationService!.configurations.any(
            (c) => c.ipAddress == '192.168.0.181' && c.port == 9100 && c.name == 'Sweet Counter Receipt',
          );
          if (!sweetExists) {
            final addedSweet = await _printerConfigurationService!.addSweetCounterPrinterByIP('192.168.0.181', port: 9100);
            // Auto-add successful
          } else {
          }

          await _printerConfigurationService!.refreshConfigurations();
        } catch (e) {
        }
      } catch (e) {
      }
      
      // 🚨 URGENT: Initialize UnifiedPrinterService for Epson printer discovery
      widget.progressService.addMessage('🚀 Setting up unified printer service...');
      _unifiedPrinterService = UnifiedPrinterService.getInstance(tenantDatabase);
      try {
        await _unifiedPrinterService!.initialize().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            return false;
          },
        );
      } catch (e) {
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
      
      // Initialize cross-platform printer sync service
      widget.progressService.addMessage('🌐 Setting up cross-platform sync...');
      _crossPlatformPrinterSyncService = CrossPlatformPrinterSyncService(
        databaseService: tenantDatabase,
        assignmentService: _enhancedPrinterAssignmentService!,
      );
      await _crossPlatformPrinterSyncService!.initialize();
      
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
              return;
            },
          );
        } catch (e) {
        }
      } else {
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
      } else {
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
      } else {
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
        } else {
        }
      } else {
      }
      
      // Initialize LoyaltyService
      widget.progressService.addMessage('💰 Setting up loyalty service...');
      _loyaltyService = LoyaltyService(tenantDatabase);
      
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
            } else {
            }
          } else {
          }
        } else {
        }
      } else {
      }
      
      // Connect unified sync service to restaurant
      if (_unifiedSyncService != null && widget.authService.currentRestaurant != null && widget.authService.currentSession != null) {
        widget.progressService.addMessage('🔗 Connecting to restaurant for unified sync...');
        try {
          await _unifiedSyncService!.connectToRestaurant(
            widget.authService.currentRestaurant!,
            widget.authService.currentSession!,
          );
          
          // CRITICAL FIX: Set required services for category sync to work
          _unifiedSyncService!.setServices(
            databaseService: tenantDatabase,
            orderService: _orderService,
            menuService: _menuService,
            userService: _userService,
            inventoryService: _inventoryService,
            tableService: _tableService,
          );
          
          // FIXED: Proper Firebase sync with DEBOUNCED UI updates to prevent infinite loops
          _unifiedSyncService!.setCallbacks(
            onOrdersUpdated: () {
              // Use debounced refresh to prevent infinite loops
              _debouncedRefresh();
            },
            onMenuItemsUpdated: () {
              _debouncedRefresh();
            },
            onUsersUpdated: () {
              _debouncedRefresh();
            },
            onInventoryUpdated: () {
              _debouncedRefresh();
            },
            onTablesUpdated: () {
              _debouncedRefresh();
            },
            onSyncProgress: (message) {
            },
            onSyncError: (error) {
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
          }
        } catch (e) {
          // Don't fail initialization - continue in offline mode
        }
      } else {
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
            widget.progressService.addMessage('✅ Real-time synchronization active');
          } else {
            widget.progressService.addMessage('⚠️ Unified sync service not available');
          }
        } catch (e) {
          widget.progressService.addMessage('⚠️ Unified sync connection failed - continuing in local mode');
        }
      } else {
        widget.progressService.addMessage('⚠️ Multi-device sync requires restaurant and user session');
      }
      
      // Initialize auto printer discovery service (requires printing service, printer config service, and multi printer manager)
      widget.progressService.addMessage('🔍 Setting up automatic printer discovery...');
      if (_printingService != null && _printerConfigurationService != null && _enhancedPrinterAssignmentService != null) {
        // Removed: MultiPrinterManager and AutoPrinterDiscoveryService (redundant)
        // Functionality moved to unified printer service
      } else {
      }
      
      
      // CREATE DUMMY DATA FOR TESTING (only if no existing data)
      // ENABLED: Test data creation for registration
      final existingOrderCount = _orderService?.allOrders.length ?? 0;
      if (existingOrderCount == 0) {
        widget.progressService.addMessage('🎯 Creating demo servers and orders...');
        await _createDummyData();
      } else {
      }
      
    } catch (e, stackTrace) {
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
      
      // Check if we already have users (don't clear existing users!)
      final existingUserCount = _userService?.users.length ?? 0;
      if (existingUserCount > 0) {
        
        // Only create demo orders if none exist
        final existingOrderCount = _orderService?.allOrders.length ?? 0;
        if (existingOrderCount == 0) {
          await _createDemoOrder();
        } else {
        }
        return;
      }
      
      // Only if NO users exist, create the default admin user
      
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
      
      // Create a sample order for testing with admin user
      await _createDemoOrder();
      
      
    } catch (e) {
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
      }
    } catch (e) {
    }
  }
  
  /// Clear all services and cached data for restaurant isolation
  Future<void> _clearAllServicesForIsolation() async {
    try {
      
      // Clear all service instances
      _orderService = null;
      _menuService = null;
      _userService = null;
      
      // Clear global MenuService reference
      MultiTenantAuthService.clearGlobalMenuService();
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
      
    } catch (e) {
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
        
        // Show authentication screen if not authenticated
        if (!widget.authService.isAuthenticated) {
          return const RestaurantAuthScreen();
        }
        
        // Show progress screen while services are initializing (only when authenticated)
        if (widget.authService.isAuthenticated && !_servicesInitialized) {
          return InitializationProgressScreen(
            restaurantName: widget.authService.currentRestaurant?.name ?? 'Restaurant',
          );
        }
        
        // CRITICAL: Ensure ALL required services are available before showing main UI
        if (_userService == null || _tableService == null || _paymentService == null || _printerConfigurationService == null) {
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
          }
          
          final userCount = userService?.users.length ?? 0;
          final orderCount = orderService.allOrders.length;
          
          
        } catch (e) {
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
        try {
          return const OrderTypeSelectionScreen();
        } catch (e, stackTrace) {
          
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
      return;
    }
    
    _refreshTimer?.cancel();
    _refreshTimer = Timer(const Duration(milliseconds: 1000), () {
      if (mounted && !_isRefreshing) {
        _isRefreshing = true;
        
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

  /// 🚀 LIGHTNING FAST: Start all background sync operations without blocking UI
  void _startLightningFastBackgroundSync() {
    // Prevent duplicate sync operations
    if (_isBackgroundSyncActive) {
      return;
    }

    _isBackgroundSyncActive = true;

    try {
      // Start order sync in background (most critical)
      if (_orderService != null) {
        final orderSyncFuture = _orderService!.syncOrdersWithFirebase();
        _activeBackgroundOperations.add(orderSyncFuture);
        unawaited(_handleBackgroundOperation(orderSyncFuture, 'Order Sync'));
      }

      // Start menu sync in background
      if (_menuService != null) {
        final menuSyncFuture = _menuService!.syncMenusWithFirebase();
        _activeBackgroundOperations.add(menuSyncFuture);
        unawaited(_handleBackgroundOperation(menuSyncFuture, 'Menu Sync'));
      }

      // Start user sync in background
      if (_userService != null) {
        final userSyncFuture = _userService!.syncUsersWithFirebase();
        _activeBackgroundOperations.add(userSyncFuture);
        unawaited(_handleBackgroundOperation(userSyncFuture, 'User Sync'));
      }

      // Start periodic background sync timer
      _startPeriodicBackgroundSync();


    } catch (e) {
      _isBackgroundSyncActive = false;
      // Don't throw - background sync failure shouldn't affect UI
    }
  }

  /// Handle background operation completion and cleanup with timeout protection
  Future<void> _handleBackgroundOperation(Future<void> operation, String operationName) async {
    try {
      // Add timeout protection to prevent hanging operations
      await operation.timeout(
        const Duration(minutes: 5), // 5 minute timeout for background operations
        onTimeout: () {
          throw TimeoutException('Background operation timed out: $operationName');
        },
      );
    } catch (e) {

      // If it's a timeout, we might want to retry once
      if (e is TimeoutException && operationName.contains('Order')) {
        try {
          await Future.delayed(const Duration(seconds: 30)); // Wait before retry
          // Retry logic would go here, but for now we just log
        } catch (retryError) {
        }
      }
    } finally {
      _activeBackgroundOperations.remove(operation);
      // Check if all operations are complete
      if (_activeBackgroundOperations.isEmpty) {
        _isBackgroundSyncActive = false;
      }
    }
  }

  /// Start periodic background sync (every 5 minutes when app is active)
  void _startPeriodicBackgroundSync() {
    _backgroundSyncTimer?.cancel(); // Cancel existing timer
    _backgroundSyncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      // Only sync if app is not in background and not already syncing
      if (!_isAppInBackground && !_isBackgroundSyncActive) {
        _startLightningFastBackgroundSync();
      }
    });
  }
}
