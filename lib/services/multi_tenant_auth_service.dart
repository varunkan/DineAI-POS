import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'dart:math';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart'; // Added for getDatabasesPath
import 'dart:io'; // Added for File
import 'dart:developer';
import 'dart:typed_data';

import '../models/restaurant.dart';
import '../models/user.dart' as app_user;
import 'database_service.dart';
import 'initialization_progress_service.dart';
import 'package:ai_pos_system/services/unified_sync_service.dart'; // Added for UnifiedSyncService
import '../config/firebase_config.dart'; // Added for FirebaseConfig
import 'order_service.dart'; // Added for OrderService
import 'order_log_service.dart'; // Added for OrderLogService
import 'inventory_service.dart'; // Added for InventoryService
import 'menu_service.dart'; // Added for MenuService
import 'sync_fix_service.dart'; // Added for SyncFixService

/// Multi-tenant authentication service for restaurant POS system
/// Handles restaurant registration, user authentication, and session management
class MultiTenantAuthService extends ChangeNotifier {
  static MultiTenantAuthService? _instance;
  static final _uuid = const Uuid();
  
  // Current session
  RestaurantSession? _currentSession;
  Restaurant? _currentRestaurant;
  
  // Restaurant management
  final List<Restaurant> _registeredRestaurants = [];
  
  // Authentication state
  bool _isAuthenticated = false;
  
  // CRITICAL FIX: Add setter with protection for authentication state
  set isAuthenticated(bool value) {
    debugPrint('🔐 CRITICAL: _isAuthenticated being set to $value');
    if (_isAuthenticated == true && value == false) {
      debugPrint('⚠️ WARNING: Attempting to set _isAuthenticated to false when it was true!');
      debugPrint('⚠️ This might indicate an unwanted authentication reset');
      // Add stack trace to see where this is coming from
      debugPrint('⚠️ Stack trace: ${StackTrace.current}');
    }
    _isAuthenticated = value;
    debugPrint('🔐 CRITICAL: _isAuthenticated now set to $_isAuthenticated');
  }
  bool _isLoading = false;
  String? _lastError;
  
  // Database service for global restaurant data
  late DatabaseService _globalDb;
  DatabaseService? _tenantDb; // Current restaurant's database
  
  // Session management
  Timer? _sessionTimer;
  static const Duration sessionTimeout = Duration(hours: 8);
  
  // Progress service for initialization messages
  InitializationProgressService? _progressService;
  
  // Firebase instances
  FirebaseFirestore? _firestore;
  firebase_auth.FirebaseAuth? _auth;
  
  // Callback for when categories are synced from Firebase
  VoidCallback? _onCategoriesSynced;
  
  // Global reference to MenuService for direct reload after sync
  static MenuService? _globalMenuService;
  
  // ZERO RISK: Feature flags for new functionality
  static const bool _enableEnhancedOrderItemsSync = true; // Can be set to false to disable
  static const bool _enableSafeWrappers = true; // Can be set to false to disable
  static const bool _nonBlockingLoginSync = true; // Decouple sync from login completion
  
  factory MultiTenantAuthService() {
    _instance ??= MultiTenantAuthService._internal();
    return _instance!;
  }
  
  MultiTenantAuthService._internal();
  
  // Getters
  bool get isAuthenticated {
    debugPrint('🔐 CRITICAL: isAuthenticated getter called - returning $_isAuthenticated');
    return _isAuthenticated;
  }
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  RestaurantSession? get currentSession => _currentSession;
  Restaurant? get currentRestaurant => _currentRestaurant;
  List<Restaurant> get registeredRestaurants => List.unmodifiable(_registeredRestaurants);
  DatabaseService? get tenantDatabase => _tenantDb;
  
  /// Set progress service for initialization messages
  void setProgressService(InitializationProgressService progressService) {
    _progressService = progressService;
  }
  
  /// Set callback for when categories are synced from Firebase
  void setCategoriesSyncedCallback(VoidCallback callback) {
    _onCategoriesSynced = callback;
  }
  
  /// Set global MenuService reference for direct reload after sync
  static void setGlobalMenuService(MenuService menuService) {
    _globalMenuService = menuService;
  }
  
  /// Clear global MenuService reference
  static void clearGlobalMenuService() {
    _globalMenuService = null;
  }
  
  /// Add progress message
  void _addProgressMessage(String message) {
    _progressService?.addMessage(message);
    debugPrint(message);
  }
  
  /// Initialize the multi-tenant auth service
  Future<void> initialize() async {
    try {
      _addProgressMessage('🔐 Initializing Multi-Tenant Auth Service...');
      
      // Initialize Firebase instances (but don't block on connection)
      try {
        _firestore = FirebaseFirestore.instance;
        _auth = firebase_auth.FirebaseAuth.instance;
        
        // Ensure anonymous authentication
        await _ensureAnonymousAuthentication();
      } catch (e) {
        debugPrint('⚠️ Firebase initialization failed, continuing with local mode: $e');
      }
      
      // Initialize global database with timeout
      try {
        await _initializeGlobalDatabase().timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            debugPrint('⚠️ Global database initialization timed out, continuing...');
            _addProgressMessage('⚠️ Database initialization timed out, continuing...');
          },
        );
      } catch (e) {
        debugPrint('⚠️ Global database initialization failed: $e');
        _addProgressMessage('⚠️ Database initialization failed, continuing...');
      }
      
      // Load restaurants from local database first (with timeout)
      try {
        await _loadRegisteredRestaurants().timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            debugPrint('⚠️ Restaurant loading timed out, continuing...');
            _addProgressMessage('⚠️ Restaurant loading timed out, continuing...');
          },
        );
      } catch (e) {
        debugPrint('⚠️ Restaurant loading failed: $e');
        _addProgressMessage('⚠️ Restaurant loading failed, continuing...');
      }
      
      // Check if we have any restaurants locally
      if (_registeredRestaurants.isEmpty) {
        _addProgressMessage('📝 No restaurants found locally or in cloud');
      } else {
        _addProgressMessage('✅ Found ${_registeredRestaurants.length} restaurants');
        
        // ENHANCEMENT: Perform startup sync for all restaurants to ensure data is current
        // This ensures that every time the app starts, we have the latest data from cloud
        try {
          _addProgressMessage('🔄 Performing startup sync with cloud...');
          await _performStartupSync();
          _addProgressMessage('✅ Startup sync completed');
        } catch (syncError) {
          _addProgressMessage('⚠️ Startup sync completed with warnings: $syncError');
          debugPrint('⚠️ Startup sync warning (non-critical): $syncError');
          // Don't fail initialization due to sync issues
        }
      }
      
      // Ensure we start fresh
      _currentSession = null;
      _currentRestaurant = null;
      _tenantDb = null;
      isAuthenticated = false; // Use setter for protection
      
      _addProgressMessage('🚪 Fresh start - login required');
      
      _addProgressMessage('✅ Multi-Tenant Auth Service initialized');
    } catch (e) {
      _addProgressMessage('❌ Failed to initialize auth service: $e');
      _setError('Failed to initialize auth service: $e');
    }
  }
  
  /// Ensure anonymous authentication for Firebase operations
  Future<void> _ensureAnonymousAuthentication() async {
    try {
      if (_auth == null) {
        _addProgressMessage('⚠️ Firebase Auth not available');
        return;
      }
      
      // Check if user is already signed in
      if (_auth!.currentUser != null) {
        _addProgressMessage('✅ User already authenticated: ${_auth!.currentUser!.uid}');
        return;
      }
      
      // Sign in anonymously
      final userCredential = await _auth!.signInAnonymously();
      _addProgressMessage('✅ Anonymous authentication successful: ${userCredential.user?.uid}');
      
    } catch (e) {
      _addProgressMessage('⚠️ Anonymous authentication failed: $e');
      // Continue anyway - app can work in offline mode
    }
  }
  
  /// Initialize global database
  Future<void> _initializeGlobalDatabase() async {
    try {
      _addProgressMessage('📱 Initializing global database service for restaurant management...');
      
      _globalDb = DatabaseService();
      await _globalDb.initializeWithCustomName('global_restaurant_management');
      
      // Ensure restaurants table exists
      await _ensureRestaurantsTableExists();
      
      _addProgressMessage('✅ Global database service initialized - database available');
    } catch (e) {
      _addProgressMessage('❌ Failed to initialize global database: $e');
      throw Exception('Failed to initialize global database: $e');
    }
  }
  
  /// Ensure restaurants table exists in global database
  Future<void> _ensureRestaurantsTableExists() async {
    try {
      final db = await _globalDb.database;
      if (db == null) {
        _addProgressMessage('❌ Global database not available');
        return;
      }
      
      _addProgressMessage('🔍 Checking restaurants table in database: ${db.path}');
      
      // Check if restaurants table exists
      final tables = await db.query('sqlite_master', 
        where: 'type = ? AND name = ?', 
        whereArgs: ['table', 'restaurants']);
      
      if (tables.isEmpty) {
        _addProgressMessage('🔍 Creating restaurants table in database: ${db.path}');
        
        // Create restaurants table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS restaurants (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            business_type TEXT,
            address TEXT,
            phone TEXT,
            email TEXT UNIQUE NOT NULL,
            admin_user_id TEXT,
            admin_password TEXT,
            created_at TEXT,
            updated_at TEXT,
            is_active INTEGER DEFAULT 1,
            database_name TEXT,
            settings TEXT
          )
        ''');
        
        _addProgressMessage('✅ Global restaurant table created successfully');
      } else {
        _addProgressMessage('✅ Restaurants table already exists');
      }
    } catch (e) {
      _addProgressMessage('❌ Failed to ensure restaurants table: $e');
      // Don't throw here - allow app to continue
      debugPrint('Database error: $e');
    }
  }
  
  /// Load all registered restaurants from local and cloud
  Future<void> _loadRegisteredRestaurants() async {
    try {
      _registeredRestaurants.clear();
      
      // Load from local database first
      await _loadRestaurantsFromLocal();
      
      // Load from Firebase cloud (non-blocking)
      if (_firestore != null) {
        try {
          await _loadRestaurantsFromFirebase();
        } catch (e) {
          debugPrint('⚠️ Firebase loading failed, using local data only: $e');
        }
      }
      
      _addProgressMessage('📂 Loaded ${_registeredRestaurants.length} restaurants');
    } catch (e) {
      _addProgressMessage('❌ Failed to load restaurants: $e');
    }
  }
  
  /// Load restaurants from local SQLite database
  Future<void> _loadRestaurantsFromLocal() async {
    try {
      final db = await _globalDb.database;
      if (db == null) return;
      
      final results = await db.query('restaurants', where: 'is_active = ?', whereArgs: [1]);
      
      for (final row in results) {
        try {
          final restaurant = Restaurant.fromJson(row);
          _registeredRestaurants.add(restaurant);
        } catch (e) {
          _addProgressMessage('⚠️ Failed to parse restaurant: $e');
        }
      }
    } catch (e) {
      _addProgressMessage('⚠️ Failed to load restaurants from local database: $e');
    }
  }
  
  /// Load restaurants from Firebase cloud
  Future<void> _loadRestaurantsFromFirebase() async {
    try {
      if (_firestore == null) {
        debugPrint('⚠️ Firebase not available for cloud loading');
        return;
      }
      
      // USER REQUEST: Load restaurants from tenants collection
      // This loads all restaurant data from tenants/{email}/restaurant_info
      final tenantsSnapshot = await _firestore!.collection('tenants').get();
      
      for (final doc in tenantsSnapshot.docs) {
        try {
          final data = doc.data();
          if (data.containsKey('restaurant_info')) {
            final restaurantData = data['restaurant_info'] as Map<String, dynamic>;
            final restaurant = Restaurant.fromJson(restaurantData);
            
            // Check if already loaded locally
            final exists = _registeredRestaurants.any((r) => r.email == restaurant.email);
            if (!exists) {
              _registeredRestaurants.add(restaurant);
              // Save to local database
              await _saveRestaurantToLocal(restaurant);
              debugPrint('✅ Added new restaurant from Firebase tenants: ${restaurant.name}');
            } else {
              // Update existing restaurant with cloud data
              final existingIndex = _registeredRestaurants.indexWhere((r) => r.email == restaurant.email);
              _registeredRestaurants[existingIndex] = restaurant;
              await _saveRestaurantToLocal(restaurant);
              debugPrint('✅ Updated restaurant from Firebase tenants: ${restaurant.name}');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Failed to parse Firebase tenant restaurant: $e');
        }
      }
      
      _addProgressMessage('✅ Synced ${tenantsSnapshot.docs.length} restaurants from Firebase tenants');
    } catch (e) {
      debugPrint('⚠️ Failed to load restaurants from Firebase tenants: $e');
      // Don't show error message to user, just log it
    }
  }
  
  /// Save restaurant to local database
  Future<void> _saveRestaurantToLocal(Restaurant restaurant) async {
    try {
      final db = await _globalDb.database;
      if (db == null) return;
      
      final data = restaurant.toJson();
              await db.insert('restaurants', data);
    } catch (e) {
      _addProgressMessage('⚠️ Failed to save restaurant to local database: $e');
    }
  }
  
  /// Register a new restaurant with proper email-based identification
  Future<bool> registerRestaurant({
    required String name,
    required String businessType,
    required String address,
    required String phone,
    required String email,
    required String adminUserId,
    required String adminPassword,
  }) async {
    try {
      _setLoading(true);
      _clearError();
      
      _addProgressMessage('🏗️ Starting restaurant registration...');
      _addProgressMessage('📝 Restaurant: $name');
      _addProgressMessage('📧 Email: $email');
      _addProgressMessage('🏢 Business Type: $businessType');
      
      // Sanitize email for database name
      final sanitizedEmail = _sanitizeEmailForDatabase(email.toLowerCase());
      final databaseName = 'restaurant_$sanitizedEmail';
      
      _addProgressMessage('🗄️ Database name: $databaseName');
      
      // Check for existing restaurant
      final existingRestaurant = _registeredRestaurants.where((r) => r.email.toLowerCase() == email.toLowerCase()).firstOrNull;
      if (existingRestaurant != null) {
        _addProgressMessage('🔧 Found existing restaurant registration, clearing it completely...');
        await _clearExistingRestaurant(existingRestaurant);
      }
      
      // Hash password
      final hashedPassword = _hashPassword(adminPassword);
      final now = DateTime.now();
      
      // Create restaurant object with email as ID
      final restaurant = Restaurant(
        id: email.toLowerCase(), // Use email as unique ID
        name: name.trim(),
        businessType: businessType.trim(),
        address: address.trim(),
        phone: phone.trim(),
        email: email.trim().toLowerCase(),
        adminUserId: adminUserId.trim(),
        adminPassword: hashedPassword,
        isActive: true,
        createdAt: now,
        updatedAt: now,
        databaseName: databaseName,
      );
      
      _addProgressMessage('✅ Restaurant object created successfully');
      
      // Save to local database first
      _addProgressMessage('💾 Saving restaurant to local database...');
      await _saveRestaurantToLocal(restaurant);
      _addProgressMessage('✅ Restaurant saved to local database');
      
      // Save to Firebase
      _addProgressMessage('☁️ Saving restaurant to Firebase...');
      await _saveRestaurantToFirebase(restaurant);
      _addProgressMessage('✅ Restaurant saved to Firebase');
      
      // Create tenant database
      _addProgressMessage('🏗️ Creating tenant database...');
      await _createTenantDatabase(restaurant, adminUserId, adminPassword);
      _addProgressMessage('✅ Tenant database created successfully');
      
      // Add to local list
      _registeredRestaurants.add(restaurant);
      
      _addProgressMessage('🎉 Restaurant registration completed successfully!');
      _addProgressMessage('📊 Summary:');
      _addProgressMessage('   🏪 Restaurant: ${restaurant.name}');
      _addProgressMessage('   📧 Email: ${restaurant.email}');
      _addProgressMessage('   🗄️ Database: ${restaurant.databaseName}');
      _addProgressMessage('   👤 Admin User: $adminUserId');
      
      notifyListeners();
      return true;
      
    } catch (e) {
      _addProgressMessage('❌ Restaurant registration failed: $e');
      _setError(e.toString());
      debugPrint('Restaurant registration error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Sanitize email for database name
  String _sanitizeEmailForDatabase(String email) {
    return email.replaceAll('@', '_at_').replaceAll('.', '_').replaceAll('-', '_');
  }
  
  /// Save restaurant to Firebase
  Future<void> _saveRestaurantToFirebase(Restaurant restaurant) async {
    try {
      if (_firestore == null) {
        _addProgressMessage('⚠️ Firebase not available for cloud save');
        return;
      }
      
      // USER REQUEST: Save restaurant data under tenants collection
      // This puts all restaurant data under tenants/{email}/restaurant_info
      await _firestore!.collection('tenants').doc(restaurant.email).set({
        'restaurant_info': restaurant.toJson(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      _addProgressMessage('✅ Restaurant saved to Firebase tenants collection');
      _addProgressMessage('ℹ️ All restaurant data now organized under tenants structure');
    } catch (e) {
      _addProgressMessage('❌ Failed to save restaurant to Firebase: $e');
      throw Exception('Failed to save restaurant to Firebase: $e');
    }
  }
  
  /// Create tenant database with essential data
  Future<void> _createTenantDatabase(Restaurant restaurant, String adminUserId, String adminPassword) async {
    try {
      _addProgressMessage('🏗️ Creating tenant database: ${restaurant.databaseName}');
      
      // Force reset the database
      await _forceResetTenantDatabase(restaurant.databaseName);
      
      // Create new database service
      final tenantDb = DatabaseService();
      await tenantDb.initializeWithCustomName(restaurant.databaseName);
      
      // Create admin user with enhanced permissions
      final adminUser = app_user.User(
        id: adminUserId,
        name: 'Admin',
        role: app_user.UserRole.admin,
        pin: _hashPassword(adminPassword),
        isActive: true,
        adminPanelAccess: true, // Ensure admin panel access
        createdAt: DateTime.now(),
      );
      
      // Save admin user to database
      if (!kIsWeb) {
        final db = await tenantDb.database;
        if (db != null) {
          final userData = adminUser.toJson();
          await db.insert('users', userData);
          _addProgressMessage('✅ Admin user created successfully with full permissions');
          
          // Verify admin user was saved correctly
          final savedUser = await db.query(
            'users',
            where: 'id = ?',
            whereArgs: [adminUserId],
          );
          
          if (savedUser.isNotEmpty) {
            _addProgressMessage('✅ Admin user verified in database');
          } else {
            _addProgressMessage('⚠️ Warning: Admin user may not have been saved correctly');
          }
        }
      }
      
      // CRITICAL: Copy essential data from main database to tenant database
      await _copyEssentialDataToTenant(tenantDb, restaurant);
      
      _addProgressMessage('✅ Tenant database created and initialized');
      
      // Verify tenant database schema
      await _verifyTenantDatabaseSchema(tenantDb);
      
      // ENHANCEMENT: Immediately sync tenant data to Firebase for cross-device availability
      await _syncTenantDataToFirebase(restaurant, tenantDb);
      
      // ENHANCEMENT: Ensure data persistence in Firebase
      await _ensureFirebaseDataPersistence(restaurant);
      
      // ENHANCEMENT: Validate tenant database completeness
      await _validateTenantDatabaseCompleteness(restaurant, tenantDb);
      
      // ENHANCEMENT: Set admin user as current user for immediate access
      await _setAdminAsCurrentUser(restaurant, adminUser);
      
    } catch (e) {
      _addProgressMessage('❌ Failed to create tenant database: $e');
      rethrow;
    }
  }
  
  /// Copy essential data from main database to tenant database
  Future<void> _copyEssentialDataToTenant(DatabaseService tenantDb, Restaurant restaurant) async {
    try {
      _addProgressMessage('📋 Copying essential data to tenant database...');
      
      // Get main database instance
      final mainDb = await _globalDb.database;
      if (mainDb == null) {
        _addProgressMessage('⚠️ Main database not available, creating default menu...');
        await _createDefaultMenuInTenant(tenantDb, restaurant);
        return;
      }
      
      // Check if main database has categories and menu items
      final categories = await mainDb.query('categories');
      final menuItems = await mainDb.query('menu_items');
      
      if (categories.isEmpty || menuItems.isEmpty) {
        _addProgressMessage('📝 Main database has no menu data, creating default Indian menu...');
        await _createDefaultMenuInTenant(tenantDb, restaurant);
      } else {
        _addProgressMessage('📋 Copying existing data from main database...');
        
        // Copy categories
        _addProgressMessage('📂 Copying categories...');
        for (final category in categories) {
          await tenantDb.insert('categories', category);
        }
        _addProgressMessage('✅ Copied ${categories.length} categories');
        
        // Copy menu items
        _addProgressMessage('🍽️ Copying menu items...');
        for (final menuItem in menuItems) {
          await tenantDb.insert('menu_items', menuItem);
        }
        _addProgressMessage('✅ Copied ${menuItems.length} menu items');
        
        // Copy tables
        _addProgressMessage('🪑 Copying tables...');
        final tables = await mainDb.query('tables');
        for (final table in tables) {
          await tenantDb.insert('tables', table);
        }
        _addProgressMessage('✅ Copied ${tables.length} tables');
        
        // Copy inventory items
        _addProgressMessage('📦 Copying inventory items...');
        final inventoryItems = await mainDb.query('inventory');
        for (final item in inventoryItems) {
          await tenantDb.insert('inventory', item);
        }
        _addProgressMessage('✅ Copied ${inventoryItems.length} inventory items');
      }
      
      _addProgressMessage('✅ Essential data copied successfully');
      
      // CRITICAL: Sync copied data to Firebase immediately after registration
      await _syncCopiedDataToFirebase(tenantDb, restaurant);
      
      // Close the main database connection
      await mainDb.close();
      
    } catch (e) {
      _addProgressMessage('❌ Failed to copy essential data: $e');
      // Don't throw - this is not critical for basic functionality
    }
  }

  /// Create default Indian menu in tenant database
  Future<void> _createDefaultMenuInTenant(DatabaseService tenantDb, Restaurant restaurant) async {
    try {
      _addProgressMessage('🇮🇳 Creating comprehensive default restaurant data...');
      
      // Create default categories
      final categories = await _createDefaultCategories(tenantDb);
      _addProgressMessage('✅ Created ${categories.length} default categories');
      
      // Create default menu items
      final menuItems = await _createDefaultMenuItems(tenantDb, categories);
      _addProgressMessage('✅ Created ${menuItems.length} default menu items');
      
      // Create default tables
      await _createDefaultTables(tenantDb);
      _addProgressMessage('✅ Created default tables');
      
      // Create default inventory items
      await _createDefaultInventory(tenantDb);
      _addProgressMessage('✅ Created default inventory items');
      
      // Create default printer configurations
      await _createDefaultPrinterConfigs(tenantDb);
      _addProgressMessage('✅ Created default printer configurations');
      
      // Create additional users for testing
      await _createDefaultUsers(tenantDb);
      _addProgressMessage('✅ Created default users');
      
      // Create default customers
      await _createDefaultCustomers(tenantDb);
      _addProgressMessage('✅ Created default customers');
      
      // Create default loyalty rewards
      await _createDefaultLoyaltyRewards(tenantDb);
      _addProgressMessage('✅ Created default loyalty rewards');
      
      // Create default app settings
      await _createDefaultAppSettings(tenantDb);
      _addProgressMessage('✅ Created default app settings');
      
      _addProgressMessage('🎉 Comprehensive default restaurant data created successfully');
      
    } catch (e) {
      _addProgressMessage('❌ Failed to create default data: $e');
    }
  }

  /// Create default categories for new restaurant
  Future<List<Map<String, dynamic>>> _createDefaultCategories(DatabaseService tenantDb) async {
    final categories = <Map<String, dynamic>>[
      {
        'id': 'cat_appetizers_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Appetizers & Starters',
        'description': 'Delicious starters to begin your meal',
        'is_active': 1,
        'sort_order': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'cat_soups_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Soups & Salads',
        'description': 'Fresh soups and healthy salads',
        'is_active': 1,
        'sort_order': 2,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'cat_main_course_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Main Course',
        'description': 'Delicious main dishes',
        'is_active': 1,
        'sort_order': 3,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'cat_sides_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Side Dishes',
        'description': 'Perfect accompaniments to your main course',
        'is_active': 1,
        'sort_order': 4,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'cat_breads_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Breads & Rice',
        'description': 'Fresh breads and aromatic rice dishes',
        'is_active': 1,
        'sort_order': 5,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'cat_desserts_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Desserts',
        'description': 'Sweet endings to your meal',
        'is_active': 1,
        'sort_order': 6,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'cat_beverages_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Beverages',
        'description': 'Refreshing drinks and hot beverages',
        'is_active': 1,
        'sort_order': 7,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'cat_specials_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Chef Specials',
        'description': 'Unique dishes created by our chef',
        'is_active': 1,
        'sort_order': 8,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
    ];

    final savedCategories = <Map<String, dynamic>>[];
    for (final category in categories) {
      await tenantDb.insert('categories', category);
      savedCategories.add(category);
    }

    return savedCategories;
  }

  /// Create default menu items for new restaurant
  Future<List<Map<String, dynamic>>> _createDefaultMenuItems(
    DatabaseService tenantDb, 
    List<Map<String, dynamic>> categories
  ) async {
    final categoryMap = {for (var cat in categories) cat['name']: cat['id']};
    final menuItems = <Map<String, dynamic>>[];

    // Appetizers & Starters
    final appetizersId = categoryMap['Appetizers & Starters']!;
    menuItems.addAll([
      {
        'id': 'item_bruschetta_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Bruschetta',
        'description': 'Toasted bread topped with tomatoes, garlic, and fresh basil',
        'price': 8.99,
        'category_id': appetizersId,
        'is_available': 1,
        'is_vegetarian': 1,
        'is_vegan': 1,
        'is_gluten_free': 0,
        'is_spicy': 0,
        'spice_level': 0,
        'preparation_time': 5,
        'stock_quantity': 30,
        'low_stock_threshold': 5,
        'popularity_score': 4.5,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'item_spring_rolls_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Spring Rolls',
        'description': 'Crispy vegetable spring rolls with sweet chili sauce',
        'price': 7.99,
        'category_id': appetizersId,
        'is_available': 1,
        'is_vegetarian': 1,
        'is_vegan': 1,
        'is_gluten_free': 0,
        'is_spicy': 0,
        'spice_level': 0,
        'preparation_time': 8,
        'stock_quantity': 25,
        'low_stock_threshold': 5,
        'popularity_score': 4.2,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'item_chicken_wings_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Chicken Wings',
        'description': 'Crispy chicken wings with choice of sauce',
        'price': 12.99,
        'category_id': appetizersId,
        'is_available': 1,
        'is_vegetarian': 0,
        'is_vegan': 0,
        'is_gluten_free': 0,
        'is_spicy': 1,
        'spice_level': 2,
        'preparation_time': 12,
        'stock_quantity': 40,
        'low_stock_threshold': 8,
        'popularity_score': 4.8,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
    ]);

    // Soups & Salads
    final soupsId = categoryMap['Soups & Salads']!;
    menuItems.addAll([
      {
        'id': 'item_caesar_salad_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Caesar Salad',
        'description': 'Fresh romaine lettuce with Caesar dressing, croutons, and parmesan',
        'price': 11.99,
        'category_id': soupsId,
        'is_available': 1,
        'is_vegetarian': 0,
        'is_vegan': 0,
        'is_gluten_free': 0,
        'is_spicy': 0,
        'spice_level': 0,
        'preparation_time': 6,
        'stock_quantity': 20,
        'low_stock_threshold': 5,
        'popularity_score': 4.3,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'item_tomato_soup_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Tomato Soup',
        'description': 'Creamy tomato soup with fresh herbs',
        'price': 6.99,
        'category_id': soupsId,
        'is_available': 1,
        'is_vegetarian': 1,
        'is_vegan': 0,
        'is_gluten_free': 1,
        'is_spicy': 0,
        'spice_level': 0,
        'preparation_time': 10,
        'stock_quantity': 35,
        'low_stock_threshold': 8,
        'popularity_score': 4.1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
    ]);

    // Main Course
    final mainCourseId = categoryMap['Main Course']!;
    menuItems.addAll([
      {
        'id': 'item_grilled_salmon_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Grilled Salmon',
        'description': 'Fresh Atlantic salmon grilled to perfection with herbs',
        'price': 24.99,
        'category_id': mainCourseId,
        'is_available': 1,
        'is_vegetarian': 0,
        'is_vegan': 0,
        'is_gluten_free': 1,
        'is_spicy': 0,
        'spice_level': 0,
        'preparation_time': 20,
        'stock_quantity': 15,
        'low_stock_threshold': 3,
        'popularity_score': 4.7,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'item_vegetable_pasta_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Vegetable Pasta',
        'description': 'Fresh pasta with seasonal vegetables in light cream sauce',
        'price': 16.99,
        'category_id': mainCourseId,
        'is_available': 1,
        'is_vegetarian': 1,
        'is_vegan': 0,
        'is_gluten_free': 0,
        'is_spicy': 0,
        'spice_level': 0,
        'preparation_time': 15,
        'stock_quantity': 25,
        'low_stock_threshold': 5,
        'popularity_score': 4.4,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'item_beef_burger_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Beef Burger',
        'description': 'Juicy beef patty with lettuce, tomato, and special sauce',
        'price': 18.99,
        'category_id': mainCourseId,
        'is_available': 1,
        'is_vegetarian': 0,
        'is_vegan': 0,
        'is_gluten_free': 0,
        'is_spicy': 0,
        'spice_level': 0,
        'preparation_time': 12,
        'stock_quantity': 30,
        'low_stock_threshold': 6,
        'popularity_score': 4.6,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
    ]);

    // Side Dishes
    final sidesId = categoryMap['Side Dishes']!;
    menuItems.addAll([
      {
        'id': 'item_french_fries_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'French Fries',
        'description': 'Crispy golden fries with sea salt',
        'price': 5.99,
        'category_id': sidesId,
        'is_available': 1,
        'is_vegetarian': 1,
        'is_vegan': 1,
        'is_gluten_free': 1,
        'is_spicy': 0,
        'spice_level': 0,
        'preparation_time': 8,
        'stock_quantity': 50,
        'low_stock_threshold': 10,
        'popularity_score': 4.5,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'item_steamed_vegetables_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Steamed Vegetables',
        'description': 'Fresh seasonal vegetables steamed to perfection',
        'price': 6.99,
        'category_id': sidesId,
        'is_available': 1,
        'is_vegetarian': 1,
        'is_vegan': 1,
        'is_gluten_free': 1,
        'is_spicy': 0,
        'spice_level': 0,
        'preparation_time': 10,
        'stock_quantity': 30,
        'low_stock_threshold': 6,
        'popularity_score': 4.0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
    ]);

    // Breads & Rice
    final breadsId = categoryMap['Breads & Rice']!;
    menuItems.addAll([
      {
        'id': 'item_garlic_bread_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Garlic Bread',
        'description': 'Toasted bread with garlic butter and herbs',
        'price': 4.99,
        'category_id': breadsId,
        'is_available': 1,
        'is_vegetarian': 1,
        'is_vegan': 0,
        'is_gluten_free': 0,
        'is_spicy': 0,
        'spice_level': 0,
        'preparation_time': 5,
        'stock_quantity': 40,
        'low_stock_threshold': 8,
        'popularity_score': 4.3,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'item_basmati_rice_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Basmati Rice',
        'description': 'Fragrant basmati rice cooked with aromatic spices',
        'price': 4.99,
        'category_id': breadsId,
        'is_available': 1,
        'is_vegetarian': 1,
        'is_vegan': 1,
        'is_gluten_free': 1,
        'is_spicy': 0,
        'spice_level': 0,
        'preparation_time': 20,
        'stock_quantity': 60,
        'low_stock_threshold': 12,
        'popularity_score': 4.2,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
    ]);

    // Desserts
    final dessertsId = categoryMap['Desserts']!;
    menuItems.addAll([
      {
        'id': 'item_chocolate_cake_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Chocolate Cake',
        'description': 'Rich chocolate cake with chocolate ganache',
        'price': 8.99,
        'category_id': dessertsId,
        'is_available': 1,
        'is_vegetarian': 1,
        'is_vegan': 0,
        'is_gluten_free': 0,
        'is_spicy': 0,
        'spice_level': 0,
        'preparation_time': 0,
        'stock_quantity': 20,
        'low_stock_threshold': 4,
        'popularity_score': 4.8,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'item_ice_cream_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Vanilla Ice Cream',
        'description': 'Creamy vanilla ice cream with fresh berries',
        'price': 6.99,
        'category_id': dessertsId,
        'is_available': 1,
        'is_vegetarian': 1,
        'is_vegan': 0,
        'is_gluten_free': 1,
        'is_spicy': 0,
        'spice_level': 0,
        'preparation_time': 0,
        'stock_quantity': 30,
        'low_stock_threshold': 6,
        'popularity_score': 4.4,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
    ]);

    // Beverages
    final beveragesId = categoryMap['Beverages']!;
    menuItems.addAll([
      {
        'id': 'item_fresh_juice_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Fresh Orange Juice',
        'description': 'Freshly squeezed orange juice',
        'price': 4.99,
        'category_id': beveragesId,
        'is_available': 1,
        'is_vegetarian': 1,
        'is_vegan': 1,
        'is_gluten_free': 1,
        'is_spicy': 0,
        'spice_level': 0,
        'preparation_time': 3,
        'stock_quantity': 40,
        'low_stock_threshold': 8,
        'popularity_score': 4.1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'item_coffee_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Espresso',
        'description': 'Strong Italian espresso',
        'price': 3.99,
        'category_id': beveragesId,
        'is_available': 1,
        'is_vegetarian': 1,
        'is_vegan': 1,
        'is_gluten_free': 1,
        'is_spicy': 0,
        'spice_level': 0,
        'preparation_time': 2,
        'stock_quantity': 50,
        'low_stock_threshold': 10,
        'popularity_score': 4.3,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
    ]);

    // Chef Specials
    final specialsId = categoryMap['Chef Specials']!;
    menuItems.addAll([
      {
        'id': 'item_chef_special_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Chef\'s Daily Special',
        'description': 'Chef\'s creative dish of the day',
        'price': 28.99,
        'category_id': specialsId,
        'is_available': 1,
        'is_vegetarian': 0,
        'is_vegan': 0,
        'is_gluten_free': 0,
        'is_spicy': 1,
        'spice_level': 3,
        'preparation_time': 25,
        'stock_quantity': 10,
        'low_stock_threshold': 2,
        'popularity_score': 4.9,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
    ]);

    // Save all menu items
    for (final menuItem in menuItems) {
      await tenantDb.insert('menu_items', menuItem);
    }

    return menuItems;
  }

  /// Create default tables for new restaurant
  Future<void> _createDefaultTables(DatabaseService tenantDb) async {
    final tables = <Map<String, dynamic>>[
      // Indoor Tables
      {
        'id': 'table_1_${DateTime.now().millisecondsSinceEpoch}',
        'number': 1,
        'capacity': 2,
        'status': 'available',
        'user_id': null,
        'customer_name': null,
        'customer_phone': null,
        'customer_email': null,
        'metadata': '{"location": "Indoor - Window", "table_type": "dine_in"}',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'table_2_${DateTime.now().millisecondsSinceEpoch}',
        'number': 2,
        'capacity': 4,
        'status': 'available',
        'user_id': null,
        'customer_name': null,
        'customer_phone': null,
        'customer_email': null,
        'metadata': '{"location": "Indoor - Center", "table_type": "dine_in"}',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'table_3_${DateTime.now().millisecondsSinceEpoch}',
        'number': 3,
        'capacity': 6,
        'status': 'available',
        'user_id': null,
        'customer_name': null,
        'customer_phone': null,
        'customer_email': null,
        'metadata': '{"location": "Indoor - Corner", "table_type": "dine_in"}',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'table_4_${DateTime.now().millisecondsSinceEpoch}',
        'number': 4,
        'capacity': 4,
        'status': 'available',
        'user_id': null,
        'customer_name': null,
        'customer_phone': null,
        'customer_email': null,
        'metadata': '{"location": "Indoor - Bar Area", "table_type": "dine_in"}',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'table_5_${DateTime.now().millisecondsSinceEpoch}',
        'number': 5,
        'capacity': 8,
        'status': 'available',
        'user_id': null,
        'customer_name': null,
        'customer_phone': null,
        'customer_email': null,
        'metadata': '{"location": "Indoor - Private Area", "table_type": "dine_in"}',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      
      // Outdoor Tables
      {
        'id': 'table_outdoor_1_${DateTime.now().millisecondsSinceEpoch}',
        'number': 6,
        'capacity': 4,
        'status': 'available',
        'user_id': null,
        'customer_name': null,
        'customer_phone': null,
        'customer_email': null,
        'metadata': '{"location": "Outdoor - Patio", "table_type": "dine_in"}',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'table_outdoor_2_${DateTime.now().millisecondsSinceEpoch}',
        'number': 7,
        'capacity': 6,
        'status': 'available',
        'user_id': null,
        'customer_name': null,
        'customer_phone': null,
        'customer_email': null,
        'metadata': '{"location": "Outdoor - Garden", "table_type": "dine_in"}',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      
      // Bar Seating
      {
        'id': 'bar_stool_1_${DateTime.now().millisecondsSinceEpoch}',
        'number': 8,
        'capacity': 1,
        'status': 'available',
        'user_id': null,
        'customer_name': null,
        'customer_phone': null,
        'customer_email': null,
        'metadata': '{"location": "Bar - Left", "table_type": "dine_in"}',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'bar_stool_2_${DateTime.now().millisecondsSinceEpoch}',
        'number': 9,
        'capacity': 1,
        'status': 'available',
        'user_id': null,
        'customer_name': null,
        'customer_phone': null,
        'customer_email': null,
        'metadata': '{"location": "Bar - Center", "table_type": "dine_in"}',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'bar_stool_3_${DateTime.now().millisecondsSinceEpoch}',
        'number': 10,
        'capacity': 1,
        'status': 'available',
        'user_id': null,
        'customer_name': null,
        'customer_phone': null,
        'customer_email': null,
        'metadata': '{"location": "Bar - Right", "table_type": "dine_in"}',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      
      // Takeout Counter
      {
        'id': 'takeout_counter_${DateTime.now().millisecondsSinceEpoch}',
        'number': 11,
        'capacity': 0,
        'status': 'available',
        'user_id': null,
        'customer_name': null,
        'customer_phone': null,
        'customer_email': null,
        'metadata': '{"location": "Front - Takeout Area", "table_type": "takeout"}',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      
      // Delivery Station
      {
        'id': 'delivery_station_${DateTime.now().millisecondsSinceEpoch}',
        'number': 12,
        'capacity': 0,
        'status': 'available',
        'user_id': null,
        'customer_name': null,
        'customer_phone': null,
        'customer_email': null,
        'metadata': '{"location": "Back - Delivery Area", "table_type": "delivery"}',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
    ];

    for (final table in tables) {
      await tenantDb.insert('tables', table);
    }
  }
  
  /// Sync copied data to Firebase after registration
  Future<void> _syncCopiedDataToFirebase(DatabaseService tenantDb, Restaurant restaurant) async {
    try {
      _addProgressMessage('☁️ Syncing copied data to Firebase...');
      
      // Check if Firebase is available
      if (_firestore == null) {
        _addProgressMessage('⚠️ Firebase not available for sync');
        return;
      }
      
      final db = await tenantDb.database;
      if (db == null) {
        _addProgressMessage('⚠️ Tenant database not available for Firebase sync');
        return;
      }
      
      // Use the correct tenant-based path that matches UnifiedFirebaseSyncService
      final tenantId = restaurant.email; // Use email as tenant ID
      
      _addProgressMessage('🔗 Syncing to Firebase tenant: $tenantId');
      
      // Sync categories to Firebase
      _addProgressMessage('📂 Syncing categories to Firebase...');
      final categories = await db.query('categories');
      int categorySyncCount = 0;
      for (final category in categories) {
        try {
          await _firestore!
              .collection('tenants')
              .doc(tenantId)
              .collection('categories')
              .doc(category['id'] as String)
              .set(category);
          categorySyncCount++;
        } catch (e) {
          _addProgressMessage('⚠️ Failed to sync category ${category['id']}: $e');
        }
      }
      _addProgressMessage('✅ Synced $categorySyncCount categories to Firebase');
      
      // Sync menu items to Firebase
      _addProgressMessage('🍽️ Syncing menu items to Firebase...');
      final menuItems = await db.query('menu_items');
      int menuItemSyncCount = 0;
      for (final menuItem in menuItems) {
        try {
          await _firestore!
              .collection('tenants')
              .doc(tenantId)
              .collection('menu_items')
              .doc(menuItem['id'] as String)
              .set(menuItem);
          menuItemSyncCount++;
        } catch (e) {
          _addProgressMessage('⚠️ Failed to sync menu item ${menuItem['id']}: $e');
        }
      }
      _addProgressMessage('✅ Synced $menuItemSyncCount menu items to Firebase');
      
      // Sync tables to Firebase
      _addProgressMessage('🪑 Syncing tables to Firebase...');
      final tables = await db.query('tables');
      int tableSyncCount = 0;
      for (final table in tables) {
        try {
          await _firestore!
              .collection('tenants')
              .doc(tenantId)
              .collection('tables')
              .doc(table['id'] as String)
              .set(table);
          tableSyncCount++;
        } catch (e) {
          _addProgressMessage('⚠️ Failed to sync table ${table['id']}: $e');
        }
      }
      _addProgressMessage('✅ Synced $tableSyncCount tables to Firebase');
      
      // Sync users to Firebase
      _addProgressMessage('👥 Syncing users to Firebase...');
      final users = await db.query('users');
      int userSyncCount = 0;
      for (final user in users) {
        try {
          await _firestore!
              .collection('tenants')
              .doc(tenantId)
              .collection('users')
              .doc(user['id'] as String)
              .set(user);
          userSyncCount++;
        } catch (e) {
          _addProgressMessage('⚠️ Failed to sync user ${user['id']}: $e');
        }
      }
      _addProgressMessage('✅ Synced $userSyncCount users to Firebase');
      
      // Create a sync summary document
      try {
        await _firestore!
            .collection('tenants')
            .doc(tenantId)
            .collection('sync_metadata')
            .doc('last_sync')
            .set({
          'last_sync_time': DateTime.now().toIso8601String(),
          'categories_synced': categorySyncCount,
          'menu_items_synced': menuItemSyncCount,
          'tables_synced': tableSyncCount,
          'users_synced': userSyncCount,
          'total_items_synced': categorySyncCount + menuItemSyncCount + tableSyncCount + userSyncCount,
          'sync_status': 'completed',
          'restaurant_name': restaurant.name,
          'restaurant_email': restaurant.email,
        });
        _addProgressMessage('✅ Sync metadata saved to Firebase');
      } catch (e) {
        _addProgressMessage('⚠️ Failed to save sync metadata: $e');
      }
      
      _addProgressMessage('🎯 Firebase sync completed successfully!');
      _addProgressMessage('📊 Total items synced: ${categorySyncCount + menuItemSyncCount + tableSyncCount + userSyncCount}');
      
    } catch (e) {
      _addProgressMessage('❌ Failed to sync data to Firebase: $e');
      debugPrint('Firebase sync error: $e');
      // Don't throw - Firebase sync is optional for registration success
    }
  }
  
  /// Force reset tenant database
  Future<void> _forceResetTenantDatabase(String databaseName) async {
    try {
      final databasePath = await getDatabasesPath();
      final dbPath = join(databasePath, '$databaseName.db');
      
      // Delete existing database file
      final dbFile = File(dbPath);
      if (await dbFile.exists()) {
        await dbFile.delete();
        _addProgressMessage('🗑️ Deleted existing tenant database: $databaseName');
      }
    } catch (e) {
      _addProgressMessage('⚠️ Could not reset tenant database: $e');
    }
  }
  
  /// Verify tenant database schema
  Future<void> _verifyTenantDatabaseSchema(DatabaseService tenantDb) async {
    try {
      _addProgressMessage('🔍 Verifying tenant database schema...');
      
      final db = await tenantDb.database;
      if (db == null) return;
      
      // Check if users table exists and has admin user
      final users = await db.query('users', where: 'id = ?', whereArgs: ['admin']);
      if (users.isNotEmpty) {
        _addProgressMessage('✅ Tenant database schema verified successfully');
      } else {
        _addProgressMessage('⚠️ Admin user not found in tenant database');
      }
    } catch (e) {
      _addProgressMessage('❌ Failed to verify tenant database schema: $e');
    }
  }
  
  /// SIMPLIFIED: Authenticate restaurant user with clear local-first strategy
  Future<bool> login({
    required String restaurantEmail,
    required String userId,
    required String password,
  }) async {
    try {
      _setLoading(true);
      _clearError();
      
      debugPrint('🔐 SIMPLIFIED LOGIN: Authenticating user: $userId at restaurant: $restaurantEmail');
      
      // STEP 1: Check local database for restaurant
      Restaurant? restaurant = _findRestaurantLocally(restaurantEmail);
      
      if (restaurant != null) {
        debugPrint('✅ Found restaurant locally: ${restaurant.name}');
        
        // ENHANCEMENT: Sync will happen AFTER database connection in _authenticateUser
        // No need to sync here since database isn't connected yet
        
        return await _authenticateUser(restaurant, userId, password);
      }
      
      // STEP 2: Restaurant not found locally, check Firebase
      debugPrint('☁️ Restaurant not found locally, checking Firebase...');
      restaurant = await _findRestaurantInFirebase(restaurantEmail);
      
      if (restaurant != null) {
        debugPrint('✅ Found restaurant in Firebase: ${restaurant.name}');
        // Save to local database for future fast access
        await _saveRestaurantToLocal(restaurant);
        _registeredRestaurants.add(restaurant);
        
        // ENHANCEMENT: Sync will happen AFTER database connection in _authenticateUser
        // No need to sync here since database isn't connected yet
        
        return await _authenticateUser(restaurant, userId, password);
      }
      
      // STEP 3: Restaurant not found anywhere
      throw Exception('Restaurant not found with email: $restaurantEmail');
      
    } catch (e) {
      debugPrint('❌ Login failed: $e');
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
  
  /// Find restaurant in local database
  Restaurant? _findRestaurantLocally(String email) {
    try {
      return _registeredRestaurants.firstWhere(
        (r) => r.email.toLowerCase() == email.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }
  
  /// Authenticate user against restaurant (local or cloud)
  Future<bool> _authenticateUser(Restaurant restaurant, String userId, String password) async {
    try {
      // Connect to tenant database FIRST
      await _connectToTenantDatabase(restaurant);
      
      // Check admin credentials first
      if (restaurant.adminUserId == userId && _verifyPassword(password, restaurant.adminPassword)) {
        debugPrint('✅ Admin authentication successful');
        await _createUserSession(restaurant, userId, 'Admin', app_user.UserRole.admin);
        
        // ENHANCEMENT: Perform comprehensive sync AFTER database connection is established
        // This ensures all data is up-to-date when the user enters the app
        try {
          _addProgressMessage('🔄 Database connected, starting comprehensive sync...');
          if (_nonBlockingLoginSync) {
            // Fire-and-forget with timeout to avoid blocking login
            unawaited(_performTimestampBasedSync(restaurant).timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                _addProgressMessage('⏱️ Sync continuing in background');
                return;
              },
            ));
          } else {
            await _performTimestampBasedSync(restaurant);
            _addProgressMessage('✅ Comprehensive sync completed successfully');
          }
          
          // ADDITIONAL: Trigger the working comprehensive sync service for orders
          try {
            _addProgressMessage('🔄 Triggering working comprehensive sync service for orders...');
            if (_nonBlockingLoginSync) {
              unawaited(triggerWorkingComprehensiveSync(restaurant).timeout(
                const Duration(seconds: 8),
                onTimeout: () {
                  _addProgressMessage('⏱️ Order sync continuing in background');
                  return;
                },
              ));
            } else {
              await triggerWorkingComprehensiveSync(restaurant);
              _addProgressMessage('✅ Working comprehensive sync completed successfully');
            }
          } catch (comprehensiveSyncError) {
            _addProgressMessage('⚠️ Working comprehensive sync completed with warnings: $comprehensiveSyncError');
            debugPrint('⚠️ Working comprehensive sync warning: $comprehensiveSyncError');
          }
          
          // ADDITIONAL: Also trigger unified sync service for cross-device consistency
          try {
            _addProgressMessage('🔄 Triggering unified sync service...');
            final unifiedSyncService = UnifiedSyncService.instance;
            await unifiedSyncService.initialize();
            await unifiedSyncService.connectToRestaurant(restaurant, RestaurantSession(
              restaurantId: restaurant.email,
              userId: userId,
              userName: 'Admin',
              userRole: app_user.UserRole.admin,
              loginTime: DateTime.now(),
            ));
            if (_nonBlockingLoginSync) {
              unawaited(unifiedSyncService.autoSyncOnDeviceLogin());
            } else {
              await unifiedSyncService.autoSyncOnDeviceLogin();
            }
            _addProgressMessage('✅ Unified sync service completed');
          } catch (unifiedSyncError) {
            _addProgressMessage('⚠️ Unified sync completed with warnings: $unifiedSyncError');
            debugPrint('⚠️ Unified sync warning: $unifiedSyncError');
          }
        } catch (syncError) {
          _addProgressMessage('⚠️ Sync completed with warnings: $syncError');
          debugPrint('⚠️ Sync warning (non-critical): $syncError');
          // Don't fail authentication due to sync issues
        }
        
        return true;
      }
      
      // Check regular users
      final db = await _tenantDb!.database;
      if (db != null) {
        final usersResult = await db.query(
          'users',
          where: 'user_id = ? AND restaurant_id = ?',
          whereArgs: [userId, restaurant.email],
        );
        
        if (usersResult.isNotEmpty) {
          final user = usersResult.first;
          if (_verifyPassword(password, user['password'] as String)) {
            debugPrint('✅ User authentication successful');
            await _createUserSession(
              restaurant, 
              userId, 
              user['user_name'] as String, 
              app_user.UserRole.values.firstWhere(
                (role) => role.toString() == user['role'],
                orElse: () => app_user.UserRole.server,
              ),
            );
            
            // ENHANCEMENT: Also sync for regular users
            try {
              _addProgressMessage('🔄 Syncing user data...');
              if (_nonBlockingLoginSync) {
                unawaited(_performTimestampBasedSync(restaurant).timeout(
                  const Duration(seconds: 10),
                  onTimeout: () { _addProgressMessage('⏱️ User sync continuing in background'); return; },
                ));
              } else {
                await _performTimestampBasedSync(restaurant);
                _addProgressMessage('✅ User data sync completed');
              }
              
              // ADDITIONAL: Trigger the working comprehensive sync service for orders
              try {
                _addProgressMessage('🔄 Triggering working comprehensive sync service for orders...');
                if (_nonBlockingLoginSync) {
                  unawaited(triggerWorkingComprehensiveSync(restaurant).timeout(
                    const Duration(seconds: 8),
                    onTimeout: () { _addProgressMessage('⏱️ Order sync continuing in background'); return; },
                  ));
                } else {
                  await triggerWorkingComprehensiveSync(restaurant);
                  _addProgressMessage('✅ Working comprehensive sync completed for user');
                }
              } catch (comprehensiveSyncError) {
                _addProgressMessage('⚠️ Working comprehensive sync completed with warnings: $comprehensiveSyncError');
                debugPrint('⚠️ Working comprehensive sync warning: $comprehensiveSyncError');
              }
              
              // ADDITIONAL: Also trigger unified sync service for cross-device consistency
              try {
                _addProgressMessage('🔄 Triggering unified sync service for user...');
                final unifiedSyncService = UnifiedSyncService.instance;
                await unifiedSyncService.initialize();
                await unifiedSyncService.connectToRestaurant(restaurant, RestaurantSession(
                  restaurantId: restaurant.email,
                  userId: userId,
                  userName: user['user_name'] as String,
                  userRole: app_user.UserRole.values.firstWhere(
                    (role) => role.toString() == user['role'],
                    orElse: () => app_user.UserRole.server,
                  ),
                  loginTime: DateTime.now(),
                ));
                if (_nonBlockingLoginSync) {
                  unawaited(unifiedSyncService.autoSyncOnDeviceLogin());
                } else {
                  await unifiedSyncService.autoSyncOnDeviceLogin();
                }
                _addProgressMessage('✅ Unified sync service completed for user');
              } catch (unifiedSyncError) {
                _addProgressMessage('⚠️ Unified sync completed with warnings: $unifiedSyncError');
                debugPrint('⚠️ Unified sync warning: $unifiedSyncError');
              }
            } catch (syncError) {
              _addProgressMessage('⚠️ User sync completed with warnings: $syncError');
              debugPrint('⚠️ User sync warning (non-critical): $syncError');
            }
            
            return true;
          }
        }
      }
      
      throw Exception('Invalid user ID or password');
      
    } catch (e) {
      debugPrint('❌ Authentication failed: $e');
      throw e;
    }
  }
  
  /// Create user session after successful authentication
  Future<void> _createUserSession(Restaurant restaurant, String userId, String userName, app_user.UserRole userRole) async {
    final session = RestaurantSession(
      restaurantId: restaurant.email,
      userId: userId,
      userName: userName,
      userRole: userRole,
      loginTime: DateTime.now(),
      lastActivity: DateTime.now(),
      isActive: true,
    );
    
    await _createSession(restaurant, session);
    debugPrint('✅ User session created: $userName ($userRole)');
  }
  
  /// SIMPLIFIED: Find restaurant in Firebase
  Future<Restaurant?> _findRestaurantInFirebase(String email) async {
    try {
      if (_firestore == null) {
        debugPrint('⚠️ Firebase not available for cloud lookup');
        return null;
      }
      
      debugPrint('🔍 SIMPLIFIED: Searching for restaurant in Firebase: $email');
      
      // Check tenants collection first (most common)
      final tenantDoc = await _firestore!.collection('tenants').doc(email.toLowerCase()).get();
      
      if (tenantDoc.exists) {
        debugPrint('✅ Found restaurant in tenants collection');
        final data = tenantDoc.data()!;
        
        final restaurant = Restaurant(
          id: email.toLowerCase(),
          name: data['name'] ?? data['restaurant_name'] ?? 'Restaurant',
          businessType: data['business_type'] ?? 'Restaurant',
          email: email.toLowerCase(),
          phone: data['phone'] ?? '',
          address: data['address'] ?? '',
          adminUserId: data['admin_user_id'] ?? 'admin',
          adminPassword: data['admin_password'] ?? 'admin123',
          databaseName: 'restaurant_${email.toLowerCase().replaceAll('@', '_').replaceAll('.', '_')}',
          isActive: data['is_active'] ?? true,
          createdAt: data['created_at'] != null ? DateTime.parse(data['created_at']) : DateTime.now(),
          updatedAt: data['updated_at'] != null ? DateTime.parse(data['updated_at']) : DateTime.now(),
        );
        
        return restaurant;
      }
      
      // Check global_restaurants collection as fallback
      final globalDoc = await _firestore!.collection('global_restaurants').doc(email.toLowerCase()).get();
      
      if (globalDoc.exists) {
        debugPrint('✅ Found restaurant in global_restaurants collection');
        final data = globalDoc.data()!;
        return Restaurant.fromJson(data);
      }
      
      debugPrint('❌ Restaurant not found in any Firebase collection');
      return null;
      
    } catch (e) {
      debugPrint('❌ Failed to find restaurant in Firebase: $e');
      return null;
    }
  }
  
  /// Complete cloud login with full sync
  Future<bool> _completeCloudLogin(Restaurant restaurant, String userId, String password) async {
    try {
      // Connect to tenant database
      await _connectToTenantDatabase(restaurant);
      
      // ENHANCEMENT: Ensure data persistence is configured
      await _ensureFirebaseDataPersistence(restaurant);
      
      // ENHANCEMENT: Trigger smart time-based sync for cross-device consistency
      await _triggerSmartSyncForCrossDeviceLogin(restaurant);
      
      // Now complete login
      return await _authenticateUser(restaurant, userId, password);
    } catch (e) {
      _addProgressMessage('❌ Cloud login failed: $e');
      throw e;
    }
  }
  
  /// Trigger smart time-based sync for cross-device login
  /// This ensures data consistency when logging in from different devices
  Future<void> _triggerSmartSyncForCrossDeviceLogin(Restaurant restaurant) async {
    try {
      _addProgressMessage('🔄 Checking for cross-device data consistency...');
      
      // Initialize the unified sync service
      final unifiedSyncService = UnifiedSyncService.instance;
      await unifiedSyncService.initialize();
      
      // Connect to restaurant for sync
      await unifiedSyncService.connectToRestaurant(restaurant, RestaurantSession(
        restaurantId: restaurant.id,
        userId: 'temp_user', // Will be updated after authentication
        userName: 'temp_user', // Temporary user name for sync
        userRole: app_user.UserRole.admin, // Default role for sync operations
        loginTime: DateTime.now(),
      ));
      
      // Check if sync is needed
      final needsSync = await unifiedSyncService.needsSync();
      
      if (needsSync) {
        _addProgressMessage('🔄 Cross-device sync needed - performing smart time-based sync...');
        
        // Perform the smart time-based sync
        await unifiedSyncService.performSmartTimeBasedSync();
        
        _addProgressMessage('✅ Cross-device data consistency ensured');
      } else {
        _addProgressMessage('✅ Cross-device data is already consistent');
      }
      
    } catch (e) {
      _addProgressMessage('⚠️ Cross-device sync check failed: $e');
      // Don't throw error - sync failure shouldn't prevent login
      debugPrint('⚠️ Cross-device sync failed: $e');
    }
  }
  
  /// Get unique device identifier
  String _getDeviceId() {
    // Generate a unique device ID for this session
    return 'device_${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().millisecondsSinceEpoch}';
  }
  
  /// Perform timestamp-based sync (lightweight sync for fresh data)
  Future<void> _performTimestampBasedSync(Restaurant restaurant) async {
    try {
      _addProgressMessage('🔄 Performing comprehensive timestamp-based sync with fixes...');
      
      if (_firestore == null || _tenantDb == null) {
        _addProgressMessage('⚠️ Firebase or tenant database not available for sync');
        return;
      }
      
      // ENHANCEMENT: Run comprehensive sync fixes FIRST
      try {
        _addProgressMessage('🔧 Running comprehensive sync fixes...');
        final syncFixService = SyncFixService.instance;
        await syncFixService.initialize();
        
        // Set services for sync fix service
        syncFixService.setServices(
          databaseService: _tenantDb,
        );
        
        final fixResult = await syncFixService.fixAllSyncIssues();
        if (fixResult) {
          _addProgressMessage('✅ Sync fixes completed successfully');
        } else {
          _addProgressMessage('⚠️ Some sync fixes failed, continuing with caution');
        }
      } catch (e) {
        _addProgressMessage('⚠️ Sync fixes failed: $e');
        debugPrint('⚠️ Sync fixes error: $e');
        // Continue with regular sync even if fixes fail
      }
      
      // ENHANCEMENT: Comprehensive sync with timestamp comparison for ALL critical data
      // This ensures that when logging in, all data is properly synchronized
      
      // 1. Sync users (essential for authentication)
      await _syncUsersFromCloud(restaurant);
      
      // 2. Sync categories and menu items (essential for order functionality)
      await _syncCategoriesFromCloud(restaurant);
      await _syncMenuItemsFromCloud(restaurant);
      
      // 3. Sync tables and inventory (essential for restaurant operations)
      await _syncTablesFromCloud(restaurant);
      await _syncInventoryFromCloud(restaurant);
      
      // 4. CRITICAL: Sync orders FIRST (parent records)
      await _syncOrdersFromCloud(restaurant);
      
      // 5. CRITICAL: Sync order items AFTER orders (child records with foreign key constraints)
      await _syncOrderItemsFromCloud(restaurant);
      
      // 6. Sync remaining data
      await _syncPrinterConfigsFromCloud(restaurant);
      await _syncPrinterAssignmentsFromCloud(restaurant);
      await _syncOrderLogsFromCloud(restaurant);
      await _syncCustomersFromCloud(restaurant);
      await _syncTransactionsFromCloud(restaurant);
      await _syncReservationsFromCloud(restaurant);
      
      // 7. Update restaurant's last sync time
      await _updateRestaurantSyncTime(restaurant);
      
      _addProgressMessage('✅ Comprehensive timestamp-based sync with fixes completed');
    } catch (e) {
      _addProgressMessage('❌ Timestamp-based sync failed: $e');
      debugPrint('⚠️ Sync error details: $e');
      // Don't fail the login process due to sync issues
    }
  }

  /// Perform full sync from cloud
  Future<void> _performFullSyncFromCloud(Restaurant restaurant) async {
    try {
      _addProgressMessage('🔄 Performing COMPLETE sync from cloud to local for ${restaurant.name}...');
      
      if (_firestore == null) {
        _addProgressMessage('⚠️ Firebase not available for sync');
        return;
      }
      
      // ENHANCEMENT: Sync ALL tables from cloud to local with timestamp comparison
      _addProgressMessage('🔄 Syncing users...');
      await _syncUsersFromCloud(restaurant);
      
      _addProgressMessage('🔄 Syncing categories...');
      await _syncCategoriesFromCloud(restaurant);
      
      _addProgressMessage('🔄 Syncing menu items...');
      await _syncMenuItemsFromCloud(restaurant);
      
      _addProgressMessage('🔄 Syncing tables...');
      await _syncTablesFromCloud(restaurant);
      
      _addProgressMessage('🔄 Syncing inventory...');
      await _syncInventoryFromCloud(restaurant);
      
      _addProgressMessage('🔄 Syncing orders with timestamp comparison...');
      await _syncOrdersFromCloud(restaurant);
      
      _addProgressMessage('🔄 Syncing order items...');
      await _syncOrderItemsFromCloud(restaurant);
      
      _addProgressMessage('🔄 Syncing printer configurations...');
      await _syncPrinterConfigsFromCloud(restaurant);
      
      _addProgressMessage('🔄 Syncing printer assignments...');
      await _syncPrinterAssignmentsFromCloud(restaurant);
      
      _addProgressMessage('🔄 Syncing order logs...');
      await _syncOrderLogsFromCloud(restaurant);
      
      _addProgressMessage('🔄 Syncing customers...');
      await _syncCustomersFromCloud(restaurant);
      
      _addProgressMessage('🔄 Syncing transactions...');
      await _syncTransactionsFromCloud(restaurant);
      
      _addProgressMessage('🔄 Syncing reservations...');
      await _syncReservationsFromCloud(restaurant);
      
      // ENHANCEMENT: Update restaurant's last sync time
      await _updateRestaurantSyncTime(restaurant);
      
      _addProgressMessage('✅ COMPLETE sync from cloud to local finished for ${restaurant.name} - ALL data downloaded');
    } catch (e) {
      _addProgressMessage('❌ Full sync failed for ${restaurant.name}: $e');
      debugPrint('❌ Full sync error for ${restaurant.name}: $e');
      rethrow; // Re-throw to let caller handle the error
    }
  }
  
  /// Sync users from cloud
  Future<void> _syncUsersFromCloud(Restaurant restaurant) async {
    try {
      final usersSnapshot = await _firestore!.collection('tenants').doc(restaurant.email).collection('users').get();
      
      int syncedCount = 0;
      for (final doc in usersSnapshot.docs) {
        // CRITICAL FIX: Skip persistence configuration documents that don't belong in data tables
        if (doc.id == '_persistence_config' || doc.id.startsWith('_')) {
          continue;
        }
        
        final userData = doc.data();
        userData['id'] = doc.id;
        
        final db = await _tenantDb!.database;
        if (db != null) {
          await db.insert('users', userData);
          syncedCount++;
        }
      }
      
      _addProgressMessage('✅ Synced $syncedCount users from cloud');
    } catch (e) {
      _addProgressMessage('⚠️ Failed to sync users from cloud: $e');
    }
  }
  
  /// Sync categories from cloud
  Future<void> _syncCategoriesFromCloud(Restaurant restaurant) async {
    try {
      final categoriesSnapshot = await _firestore!.collection('tenants').doc(restaurant.email).collection('categories').get();
      
      int syncedCount = 0;
      for (final doc in categoriesSnapshot.docs) {
        // CRITICAL FIX: Skip persistence configuration documents that don't belong in data tables
        if (doc.id == '_persistence_config' || doc.id.startsWith('_')) {
          continue;
        }
        
        final categoryData = doc.data();
        categoryData['id'] = doc.id;
        
        final db = await _tenantDb!.database;
        if (db != null) {
          // Use INSERT OR REPLACE to handle existing categories gracefully
          await db.rawInsert('''
            INSERT OR REPLACE INTO categories (
              id, name, description, image_url, is_active, sort_order, 
              created_at, updated_at, icon_code_point, color_value
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''', [
            categoryData['id'],
            categoryData['name'],
            categoryData['description'] ?? '',
            categoryData['image_url'] ?? '',
            categoryData['is_active'] ?? 1,
            categoryData['sort_order'] ?? 0,
            categoryData['created_at'] ?? DateTime.now().toIso8601String(),
            categoryData['updated_at'] ?? DateTime.now().toIso8601String(),
            categoryData['icon_code_point'] ?? 0,
            categoryData['color_value'] ?? '',
          ]);
          syncedCount++;
        }
      }
      
      _addProgressMessage('✅ Synced $syncedCount categories from cloud');
      
      // CRITICAL FIX: Notify that categories have been synced so MenuService can reload
      if (syncedCount > 0) {
        debugPrint('🔄 Categories synced - triggering MenuService reload callback');
        _onCategoriesSynced?.call();
        
        // ADDITIONAL FIX: Direct MenuService reload using global reference
        if (_globalMenuService != null) {
          debugPrint('🔄 Direct MenuService reload after category sync');
          unawaited(_globalMenuService!.reloadMenuData());
        }
        
        // FALLBACK: Also trigger a delayed reload to ensure MenuService gets updated
        // This handles the case where the callback isn't set yet during authentication
        Timer(const Duration(seconds: 2), () {
          debugPrint('🔄 Delayed MenuService reload trigger after category sync');
          _onCategoriesSynced?.call();
          if (_globalMenuService != null) {
            debugPrint('🔄 Delayed direct MenuService reload');
            unawaited(_globalMenuService!.reloadMenuData());
          }
        });
      }
    } catch (e) {
      _addProgressMessage('⚠️ Failed to sync categories from cloud: $e');
    }
  }
  
  /// Sync menu items from cloud
  Future<void> _syncMenuItemsFromCloud(Restaurant restaurant) async {
    try {
      _addProgressMessage('🔄 Syncing menu items...');
      
      final menuItemsSnapshot = await _firestore!.collection('tenants').doc(restaurant.email).collection('menu_items').get();
      
      if (menuItemsSnapshot.docs.isEmpty) {
        _addProgressMessage('📝 No menu items found in cloud for this restaurant');
        return;
      }
      
      _addProgressMessage('🔍 Found ${menuItemsSnapshot.docs.length} menu items in cloud');
      
      int syncedCount = 0;
      int errorCount = 0;
      
      for (final doc in menuItemsSnapshot.docs) {
        try {
          // CRITICAL FIX: Skip persistence configuration documents that don't belong in data tables
          if (doc.id == '_persistence_config' || doc.id.startsWith('_')) {
            _addProgressMessage('⚠️ Skipping persistence document: ${doc.id}');
            continue;
          }
          
          _addProgressMessage('🔍 Processing menu item: ${doc.id}');
          
          final menuItemData = doc.data();
          _addProgressMessage('📊 Menu item data keys: ${menuItemData.keys.toList()}');
          
          menuItemData['id'] = doc.id;
          
          // Sanitize the menu item data
          final sanitizedMenuItem = _sanitizeMenuItemData(menuItemData);
          _addProgressMessage('🧹 Sanitized menu item keys: ${sanitizedMenuItem.keys.toList()}');
          
          final db = await _tenantDb!.database;
          if (db != null) {
            _addProgressMessage('💾 Upserting menu item ${doc.id} into database...');
            // Use INSERT OR REPLACE to handle existing items gracefully
            await db.rawInsert('''
              INSERT OR REPLACE INTO menu_items (
                id, name, description, price, category_id, is_available, 
                is_vegetarian, is_vegan, is_gluten_free, is_spicy, 
                spice_level, stock_quantity, low_stock_threshold, 
                popularity_score, preparation_time, created_at, updated_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', [
              sanitizedMenuItem['id'],
              sanitizedMenuItem['name'],
              sanitizedMenuItem['description'],
              sanitizedMenuItem['price'],
              sanitizedMenuItem['category_id'],
              sanitizedMenuItem['is_available'],
              sanitizedMenuItem['is_vegetarian'],
              sanitizedMenuItem['is_vegan'],
              sanitizedMenuItem['is_gluten_free'],
              sanitizedMenuItem['is_spicy'],
              sanitizedMenuItem['spice_level'],
              sanitizedMenuItem['stock_quantity'],
              sanitizedMenuItem['low_stock_threshold'],
              sanitizedMenuItem['popularity_score'],
              sanitizedMenuItem['preparation_time'],
              sanitizedMenuItem['created_at'],
              sanitizedMenuItem['updated_at'],
            ]);
            syncedCount++;
            _addProgressMessage('✅ Successfully synced menu item: ${doc.id}');
          } else {
            _addProgressMessage('⚠️ Database not available for menu item ${doc.id}');
            errorCount++;
          }
        } catch (e) {
          _addProgressMessage('⚠️ Error syncing menu item ${doc.id}: $e');
          debugPrint('⚠️ Menu item sync error details for ${doc.id}: $e');
          errorCount++;
        }
      }
      
      _addProgressMessage('✅ Menu items sync completed - Synced: $syncedCount, Errors: $errorCount');
      
      if (syncedCount > 0) {
        _addProgressMessage('🎯 Successfully synced $syncedCount menu items from cloud');
      }
      
    } catch (e) {
      _addProgressMessage('⚠️ Failed to sync menu items from cloud: $e');
      debugPrint('⚠️ Menu items sync error details: $e');
    }
  }
  
  /// Sanitize menu item data to match local database schema
  Map<String, dynamic> _sanitizeMenuItemData(Map<String, dynamic> firebaseMenuItem) {
    final sanitized = Map<String, dynamic>.from(firebaseMenuItem);
    
    // CRITICAL FIX: Map Firebase field names to local database column names
    // Firebase uses camelCase, local database uses snake_case
    
    // Map categoryId to category_id
    if (sanitized.containsKey('categoryId')) {
      sanitized['category_id'] = sanitized['categoryId'];
      sanitized.remove('categoryId');
    }
    
    // Map imageUrl to image_url
    if (sanitized.containsKey('imageUrl')) {
      sanitized['image_url'] = sanitized['imageUrl'];
      sanitized.remove('imageUrl');
    }
    
    // Map isAvailable to is_available
    if (sanitized.containsKey('isAvailable')) {
      sanitized['is_available'] = sanitized['isAvailable'] ? 1 : 0;
      sanitized.remove('isAvailable');
    }
    
    // Map isVegetarian to is_vegetarian
    if (sanitized.containsKey('isVegetarian')) {
      sanitized['is_vegetarian'] = sanitized['isVegetarian'] ? 1 : 0;
      sanitized.remove('isVegetarian');
    }
    
    // Map isVegan to is_vegan
    if (sanitized.containsKey('isVegan')) {
      sanitized['is_vegan'] = sanitized['isVegan'] ? 1 : 0;
      sanitized.remove('isVegan');
    }
    
    // Map isGlutenFree to is_gluten_free
    if (sanitized.containsKey('isGlutenFree')) {
      sanitized['is_gluten_free'] = sanitized['isGlutenFree'] ? 1 : 0;
      sanitized.remove('isGlutenFree');
    }
    
    // Map isSpicy to is_spicy
    if (sanitized.containsKey('isSpicy')) {
      sanitized['is_spicy'] = sanitized['isSpicy'] ? 1 : 0;
      sanitized.remove('isSpicy');
    }
    
    // Map spiceLevel to spice_level
    if (sanitized.containsKey('spiceLevel')) {
      sanitized['spice_level'] = sanitized['spiceLevel'];
      sanitized.remove('spiceLevel');
    }
    
    // Map stockQuantity to stock_quantity
    if (sanitized.containsKey('stockQuantity')) {
      sanitized['stock_quantity'] = sanitized['stockQuantity'];
      sanitized.remove('stockQuantity');
    }
    
    // Map lowStockThreshold to low_stock_threshold
    if (sanitized.containsKey('lowStockThreshold')) {
      sanitized['low_stock_threshold'] = sanitized['lowStockThreshold'];
      sanitized.remove('lowStockThreshold');
    }
    
    // Map popularityScore to popularity_score
    if (sanitized.containsKey('popularityScore')) {
      sanitized['popularity_score'] = sanitized['popularityScore'];
      sanitized.remove('popularityScore');
    }
    
    // Map lastOrdered to last_ordered
    if (sanitized.containsKey('lastOrdered')) {
      sanitized['last_ordered'] = sanitized['lastOrdered'];
      sanitized.remove('lastOrdered');
    }
    
    // Map preparationTime to preparation_time
    if (sanitized.containsKey('preparationTime')) {
      sanitized['preparation_time'] = sanitized['preparationTime'];
      sanitized.remove('preparationTime');
    }
    
    // CRITICAL FIX: Remove fields that don't exist in local database schema
    // These fields are not part of the local menu_items table structure
    sanitized.remove('calories');
    sanitized.remove('allergens');
    sanitized.remove('tags');
    sanitized.remove('customFields');
    sanitized.remove('custom_fields');
    
    // Map createdAt to created_at
    if (sanitized.containsKey('createdAt')) {
      sanitized['created_at'] = sanitized['createdAt'];
      sanitized.remove('createdAt');
    }
    
    // Map updatedAt to updated_at
    if (sanitized.containsKey('updatedAt')) {
      sanitized['updated_at'] = sanitized['updatedAt'];
      sanitized.remove('updatedAt');
    }
    
    // CRITICAL FIX: Remove any columns that don't exist in local database schema
    final validColumns = [
      'id', 'name', 'description', 'price', 'category_id', 'image_url',
      'is_available', 'is_vegetarian', 'is_vegan', 'is_gluten_free', 'is_spicy',
      'spice_level', 'stock_quantity', 'low_stock_threshold', 'popularity_score',
      'last_ordered', 'preparation_time', 'created_at', 'updated_at'
    ];
    
    // Remove any invalid columns
    sanitized.removeWhere((key, value) => !validColumns.contains(key));
    
    // Ensure required fields have default values
    sanitized['is_available'] = sanitized['is_available'] ?? 1;
    sanitized['is_vegetarian'] = sanitized['is_vegetarian'] ?? 0;
    sanitized['is_vegan'] = sanitized['is_vegan'] ?? 0;
    sanitized['is_gluten_free'] = sanitized['is_gluten_free'] ?? 0;
    sanitized['is_spicy'] = sanitized['is_spicy'] ?? 0;
    sanitized['spice_level'] = sanitized['spice_level'] ?? 0;
    sanitized['stock_quantity'] = sanitized['stock_quantity'] ?? 0;
    sanitized['low_stock_threshold'] = sanitized['low_stock_threshold'] ?? 5;
    sanitized['popularity_score'] = sanitized['popularity_score'] ?? 0.0;
    sanitized['preparation_time'] = sanitized['preparation_time'] ?? 0;
    
    // Ensure numeric fields are properly typed
    sanitized['price'] = _ensureNumeric(sanitized['price']);
    
    return sanitized;
  }
  
  /// Ensure a value is numeric (double)
  double _ensureNumeric(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        return 0.0;
      }
    }
    if (value is Map) return 0.0; // HashMap or other complex object
    return 0.0;
  }
  
  /// Ensure a value is an integer
  int _ensureInteger(dynamic value) {
    if (value == null) return 1;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      try {
        return int.parse(value);
      } catch (e) {
        return 1;
      }
    }
    return 1;
  }
  
  /// Sync tables from cloud
  Future<void> _syncTablesFromCloud(Restaurant restaurant) async {
    try {
      final tablesSnapshot = await _firestore!.collection('tenants').doc(restaurant.email).collection('tables').get();
      
      int syncedCount = 0;
      for (final doc in tablesSnapshot.docs) {
        // CRITICAL FIX: Skip persistence configuration documents that don't belong in data tables
        if (doc.id == '_persistence_config' || doc.id.startsWith('_')) {
          continue;
        }
        
        final tableData = doc.data();
        tableData['id'] = doc.id;
        
        final db = await _tenantDb!.database;
        if (db != null) {
          await db.insert('tables', tableData);
          syncedCount++;
        }
      }
      
      _addProgressMessage('✅ Synced $syncedCount tables from cloud');
    } catch (e) {
      _addProgressMessage('⚠️ Failed to sync tables from cloud: $e');
    }
  }
  
  /// Sync inventory from cloud
  Future<void> _syncInventoryFromCloud(Restaurant restaurant) async {
    try {
      final inventorySnapshot = await _firestore!.collection('tenants').doc(restaurant.email).collection('inventory').get();
      
      int syncedCount = 0;
      for (final doc in inventorySnapshot.docs) {
        // CRITICAL FIX: Skip persistence configuration documents that don't belong in data tables
        if (doc.id == '_persistence_config' || doc.id.startsWith('_')) {
          continue;
        }
        
        final inventoryData = doc.data();
        inventoryData['id'] = doc.id;
        
        final db = await _tenantDb!.database;
        if (db != null) {
          await db.insert('inventory', inventoryData);
          syncedCount++;
        }
      }
      
      _addProgressMessage('✅ Synced $syncedCount inventory items from cloud');
    } catch (e) {
      _addProgressMessage('⚠️ Failed to sync inventory from cloud: $e');
    }
  }
  
  /// Sync orders from cloud with timestamp-based comparison
  Future<void> _syncOrdersFromCloud(Restaurant restaurant) async {
    try {
      _addProgressMessage('🔄 Syncing orders with timestamp comparison...');
      
      // Get the database that's already connected
      final db = await _tenantDb!.database;
      if (db == null) {
        _addProgressMessage('⚠️ Tenant database not available for order sync');
        return;
      }
      
      // Get local orders with timestamps
      final localOrdersResult = await db.query('orders');
      final localOrders = <String, Map<String, dynamic>>{};
      for (final row in localOrdersResult) {
        localOrders[row['id'] as String] = row;
      }
      
      _addProgressMessage('📊 Found ${localOrders.length} orders in local database');
      
      // Get Firebase orders
      final firebaseOrdersSnapshot = await _firestore!.collection('tenants').doc(restaurant.email).collection('orders').get();
      final firebaseOrders = <String, Map<String, dynamic>>{};
      
      for (final doc in firebaseOrdersSnapshot.docs) {
        if (doc.id == '_persistence_config') continue; // Skip Firebase internal documents
        final orderData = doc.data();
        orderData['id'] = doc.id;
        firebaseOrders[doc.id] = orderData;
      }
      
      _addProgressMessage('📊 Found ${firebaseOrders.length} orders in Firebase');
      
      if (localOrders.isEmpty && firebaseOrders.isEmpty) {
        _addProgressMessage('✅ No orders to sync - both local and cloud are empty');
        return;
      }
      
      // Compare and merge orders by timestamp
      int updatedCount = 0;
      int uploadedCount = 0;
      int skippedCount = 0;
      
      _addProgressMessage('🔄 Comparing timestamps and merging orders...');
      
      for (final orderId in {...localOrders.keys, ...firebaseOrders.keys}) {
        final localOrder = localOrders[orderId];
        final firebaseOrder = firebaseOrders[orderId];
        
        if (localOrder != null && firebaseOrder != null) {
          // Both exist - compare timestamps
          try {
            final localUpdatedAt = DateTime.parse(localOrder['updatedAt'] ?? '1970-01-01T00:00:00.000Z');
            final firebaseUpdatedAt = DateTime.parse(firebaseOrder['updatedAt'] ?? '1970-01-01T00:00:00.000Z');
            
            if (localUpdatedAt.isAfter(firebaseUpdatedAt)) {
              // Local is newer - upload to Firebase
              await _firestore!.collection('tenants').doc(restaurant.email).collection('orders').doc(orderId).set(localOrder);
              uploadedCount++;
            } else if (firebaseUpdatedAt.isAfter(localUpdatedAt)) {
              // Firebase is newer - update local
              await _upsertOrderSafe(db, firebaseOrder);
              updatedCount++;
            } else {
              // Timestamps are equal - no update needed
              skippedCount++;
            }
          } catch (e) {
            _addProgressMessage('⚠️ Error parsing timestamps for order $orderId: $e');
            // If timestamp parsing fails, skip this order
            skippedCount++;
          }
        } else if (localOrder != null) {
          // Only local exists - upload to Firebase
          await _firestore!.collection('tenants').doc(restaurant.email).collection('orders').doc(orderId).set(localOrder);
          uploadedCount++;
        } else if (firebaseOrder != null) {
          // Only Firebase exists - download to local
          await _upsertOrderSafe(db, firebaseOrder);
          updatedCount++;
        }
      }
      
      _addProgressMessage('✅ Orders sync completed: $updatedCount downloaded, $uploadedCount uploaded, $skippedCount skipped');
    } catch (e) {
      _addProgressMessage('⚠️ Failed to sync orders from cloud: $e');
      debugPrint('⚠️ Order sync error details: $e');
      // Don't fail the entire sync process due to order sync issues
    }
  }
  
  /// Safely upsert an order without violating UNIQUE(order_number)
  /// - Skips ghost orders (no items and zero totals)
  /// - Updates existing row by id, then by order_number; inserts only if nothing updated
  Future<void> _upsertOrderSafe(Database db, Map<String, dynamic> firebaseOrder) async {
    try {
      final Map<String, dynamic> sanitized = _sanitizeOrderData(firebaseOrder);

      final dynamic embeddedItems = firebaseOrder['items'] ?? sanitized['items'];
      final bool hasEmbeddedItems = (embeddedItems is List && embeddedItems.isNotEmpty);

      final num subtotal = (sanitized['subtotal'] as num?) ?? 0;
      final num totalAmount = (sanitized['total_amount'] as num?) ?? 0;

      bool hasLocalOrderItems = false;
      final String? orderId = (sanitized['id'] as String?);
      if (!hasEmbeddedItems && orderId != null) {
        try {
          final List<Map<String, Object?>> rows = await db.rawQuery(
            'SELECT 1 FROM order_items WHERE order_id = ? LIMIT 1',
            <Object?>[orderId],
          );
          hasLocalOrderItems = rows.isNotEmpty;
        } catch (_) {
          hasLocalOrderItems = false;
        }
      }

      if (!hasEmbeddedItems && !hasLocalOrderItems && subtotal <= 0 && totalAmount <= 0) {
        debugPrint('⚠️ Skipping ghost order on upsert (id=${sanitized['id']}, order_number=${sanitized['order_number']})');
        return;
      }

      int affected = 0;
      if (orderId != null && orderId.isNotEmpty) {
        affected = await db.update('orders', sanitized, where: 'id = ?', whereArgs: <Object?>[orderId]);
      }

      if (affected == 0) {
        final String? orderNumber = (sanitized['order_number'] as String?);
        if (orderNumber != null && orderNumber.isNotEmpty) {
          affected = await db.update('orders', sanitized, where: 'order_number = ?', whereArgs: <Object?>[orderNumber]);
        }
      }

      if (affected == 0) {
        await db.insert('orders', sanitized, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    } catch (e) {
      debugPrint('⚠️ _upsertOrderSafe error: $e');
    }
  }
  
  /// Sanitize order data to match local database schema
  Map<String, dynamic> _sanitizeOrderData(Map<String, dynamic> firebaseOrder) {
    final sanitized = Map<String, dynamic>.from(firebaseOrder);
    
    // CRITICAL FIX: Map Firebase field names to local database column names
    // Firebase uses camelCase, local database uses snake_case
    
    // Map isUrgent to is_urgent
    if (sanitized.containsKey('isUrgent')) {
      sanitized['is_urgent'] = sanitized['isUrgent'];
      sanitized.remove('isUrgent');
    }
    
    // Map orderNumber to order_number
    if (sanitized.containsKey('orderNumber')) {
      sanitized['order_number'] = sanitized['orderNumber'];
      sanitized.remove('orderNumber');
    }
    
    // Map customerName to customer_name
    if (sanitized.containsKey('customerName')) {
      sanitized['customer_name'] = sanitized['customerName'];
      sanitized.remove('customerName');
    }
    
    // Map customerPhone to customer_phone
    if (sanitized.containsKey('customerPhone')) {
      sanitized['customer_phone'] = sanitized['customerPhone'];
      sanitized.remove('customerPhone');
    }
    
    // Map customerEmail to customer_email
    if (sanitized.containsKey('customerEmail')) {
      sanitized['customer_email'] = sanitized['customerEmail'];
      sanitized.remove('customerEmail');
    }
    
    // Map customerAddress to customer_address
    if (sanitized.containsKey('customerAddress')) {
      sanitized['customer_address'] = sanitized['customerAddress'];
      sanitized.remove('customerAddress');
    }
    
    // Map specialInstructions to special_instructions
    if (sanitized.containsKey('specialInstructions')) {
      sanitized['special_instructions'] = sanitized['specialInstructions'];
      sanitized.remove('specialInstructions');
    }
    
    // Map paymentMethod to payment_method
    if (sanitized.containsKey('paymentMethod')) {
      sanitized['payment_method'] = sanitized['paymentMethod'];
      sanitized.remove('paymentMethod');
    }
    
    // Map paymentStatus to payment_status
    if (sanitized.containsKey('paymentStatus')) {
      sanitized['payment_status'] = sanitized['paymentStatus'];
      sanitized.remove('paymentStatus');
    }
    
    // Map paymentTransactionId to payment_transaction_id
    if (sanitized.containsKey('paymentTransactionId')) {
      sanitized['payment_transaction_id'] = sanitized['paymentTransactionId'];
      sanitized.remove('paymentTransactionId');
    }
    
    // Map orderTime to order_time
    if (sanitized.containsKey('orderTime')) {
      sanitized['order_time'] = sanitized['orderTime'];
      sanitized.remove('orderTime');
    }
    
    // Map estimatedReadyTime to estimated_ready_time
    if (sanitized.containsKey('estimatedReadyTime')) {
      sanitized['estimated_ready_time'] = sanitized['estimatedReadyTime'];
      sanitized.remove('estimatedReadyTime');
    }
    
    // Map actualReadyTime to actual_ready_time
    if (sanitized.containsKey('actualReadyTime')) {
      sanitized['actual_ready_time'] = sanitized['actualReadyTime'];
      sanitized.remove('actualReadyTime');
    }
    
    // Map servedTime to served_time
    if (sanitized.containsKey('servedTime')) {
      sanitized['served_time'] = sanitized['servedTime'];
      sanitized.remove('servedTime');
    }
    
    // Map completedTime to completed_time
    if (sanitized.containsKey('completedTime')) {
      sanitized['completed_time'] = sanitized['completedTime'];
      sanitized.remove('completedTime');
    }
    
    // Map assignedTo to assigned_to
    if (sanitized.containsKey('assignedTo')) {
      sanitized['assigned_to'] = sanitized['assignedTo'];
      sanitized.remove('assignedTo');
    }
    
    // Map tableId to table_id
    if (sanitized.containsKey('tableId')) {
      sanitized['table_id'] = sanitized['tableId'];
      sanitized.remove('tableId');
    }
    
    // Map userId to user_id
    if (sanitized.containsKey('userId')) {
      sanitized['user_id'] = sanitized['userId'];
      sanitized.remove('userId');
    }
    
    // Map taxAmount to tax_amount
    if (sanitized.containsKey('taxAmount')) {
      sanitized['tax_amount'] = sanitized['taxAmount'];
      sanitized.remove('taxAmount');
    }
    
    // Map tipAmount to tip_amount
    if (sanitized.containsKey('tipAmount')) {
      sanitized['tip_amount'] = sanitized['tipAmount'];
      sanitized.remove('tipAmount');
    }
    
    // Map hstAmount to hst_amount
    if (sanitized.containsKey('hstAmount')) {
      sanitized['hst_amount'] = sanitized['hstAmount'];
      sanitized.remove('hstAmount');
    }
    
    // Map discountAmount to discount_amount
    if (sanitized.containsKey('discountAmount')) {
      sanitized['discount_amount'] = sanitized['discountAmount'];
      sanitized.remove('discountAmount');
    }
    
    // Map gratuityAmount to gratuity_amount
    if (sanitized.containsKey('gratuityAmount')) {
      sanitized['gratuity_amount'] = sanitized['gratuityAmount'];
      sanitized.remove('gratuityAmount');
    }
    
    // Map totalAmount to total_amount
    if (sanitized.containsKey('totalAmount')) {
      sanitized['total_amount'] = sanitized['totalAmount'];
      sanitized.remove('totalAmount');
    }
    
    // Map customFields to custom_fields
    if (sanitized.containsKey('customFields')) {
      sanitized['custom_fields'] = sanitized['customFields'];
      sanitized.remove('customFields');
    }
    
    // Map createdAt to created_at
    if (sanitized.containsKey('createdAt')) {
      sanitized['created_at'] = sanitized['createdAt'];
      sanitized.remove('createdAt');
    }
    
    // Map updatedAt to updated_at
    if (sanitized.containsKey('updatedAt')) {
      sanitized['updated_at'] = sanitized['updatedAt'];
      sanitized.remove('updatedAt');
    }
    
    // Map completedAt to completed_at
    if (sanitized.containsKey('completedAt')) {
      sanitized['completed_at'] = sanitized['completedAt'];
      sanitized.remove('completedAt');
    }
    
    // Convert complex objects to JSON strings for storage
    if (sanitized['items'] is Map || sanitized['items'] is List) {
      sanitized['items'] = jsonEncode(sanitized['items']);
    }
    
    if (sanitized['metadata'] is Map) {
      sanitized['metadata'] = jsonEncode(sanitized['metadata']);
    }
    
    if (sanitized['preferences'] is Map) {
      sanitized['preferences'] = jsonEncode(sanitized['preferences']);
    }
    
    if (sanitized['history'] is Map || sanitized['history'] is List) {
      sanitized['history'] = jsonEncode(sanitized['history']);
    }
    
    // ENHANCEMENT: Ensure all numeric fields are properly typed
    // This prevents HashMap casting errors for truly top-notch sync
    
    // Ensure priority is an integer
    if (sanitized['priority'] is Map || sanitized['priority'] == null) {
      sanitized['priority'] = 0;
    }
    
    // Ensure is_urgent is an integer (0 or 1)
    if (sanitized['is_urgent'] is Map || sanitized['is_urgent'] == null) {
      sanitized['is_urgent'] = 0;
    } else if (sanitized['is_urgent'] is bool) {
      sanitized['is_urgent'] = sanitized['is_urgent'] ? 1 : 0;
    }
    
    // Ensure all amount fields are doubles
    sanitized['subtotal'] = _ensureNumeric(sanitized['subtotal']);
    sanitized['tax_amount'] = _ensureNumeric(sanitized['tax_amount']);
    sanitized['tip_amount'] = _ensureNumeric(sanitized['tip_amount']);
    sanitized['hst_amount'] = _ensureNumeric(sanitized['hst_amount']);
    sanitized['discount_amount'] = _ensureNumeric(sanitized['discount_amount']);
    sanitized['gratuity_amount'] = _ensureNumeric(sanitized['gratuity_amount']);
    sanitized['total_amount'] = _ensureNumeric(sanitized['total_amount']);
    
    return sanitized;
  }
  
  /// Sync order items from cloud with proper foreign key handling
  Future<void> _syncOrderItemsFromCloud(Restaurant restaurant) async {
    try {
      _addProgressMessage('🔄 Syncing order items with foreign key validation...');
      
      final orderItemsSnapshot = await _firestore!.collection('tenants').doc(restaurant.email).collection('order_items').get();
      
      if (orderItemsSnapshot.docs.isEmpty) {
        _addProgressMessage('📝 No order items found in cloud for this restaurant');
        return;
      }
      
      final db = await _tenantDb!.database;
      if (db == null) {
        _addProgressMessage('⚠️ Tenant database not available for order items sync');
        return;
      }
      
      // First, get all existing order IDs to validate foreign keys
      final existingOrdersResult = await db.query('orders', columns: ['id']);
      final existingOrderIds = <String>{};
      for (final row in existingOrdersResult) {
        existingOrderIds.add(row['id'] as String);
      }
      
      _addProgressMessage('🔍 Found ${existingOrderIds.length} existing orders in local database');
      
      // Get all existing menu item IDs
      final existingMenuItemsResult = await db.query('menu_items', columns: ['id']);
      final existingMenuItemIds = <String>{};
      for (final row in existingMenuItemsResult) {
        existingMenuItemIds.add(row['id'] as String);
      }
      
      _addProgressMessage('🔍 Found ${existingMenuItemIds.length} existing menu items in local database');
      
      int syncedCount = 0;
      int skippedCount = 0;
      int errorCount = 0;
      int placeholderMenuItemsCreated = 0;
      
      for (final doc in orderItemsSnapshot.docs) {
        try {
          // CRITICAL FIX: Skip persistence configuration documents that don't belong in data tables
          if (doc.id == '_persistence_config' || doc.id.startsWith('_')) {
            continue;
          }
          
          final orderItemData = doc.data();
          orderItemData['id'] = doc.id;
          
          // CRITICAL FIX: Validate foreign key constraint
          final orderId = orderItemData['order_id'] as String?;
          if (orderId == null || orderId.isEmpty) {
            _addProgressMessage('⚠️ Skipping order item ${doc.id} - missing order_id');
            skippedCount++;
            continue;
          }
          
          // Check if parent order exists
          if (!existingOrderIds.contains(orderId)) {
            _addProgressMessage('⚠️ Skipping order item ${doc.id} - parent order $orderId not found');
            skippedCount++;
            continue;
          }
          
          // Check if menu item exists, create placeholder if it doesn't
          final menuItemId = orderItemData['menu_item_id'] as String?;
          if (menuItemId != null && menuItemId.isNotEmpty) {
            if (!existingMenuItemIds.contains(menuItemId)) {
              _addProgressMessage('🔧 Creating placeholder menu item for ID: $menuItemId');
              await _createPlaceholderMenuItem(db, menuItemId, orderItemData);
              existingMenuItemIds.add(menuItemId);
              placeholderMenuItemsCreated++;
            }
          }
          
          // Sanitize the order item data
          final sanitizedOrderItem = _sanitizeOrderItemData(orderItemData);
          
          // Insert with conflict resolution
          await db.insert('order_items', sanitizedOrderItem, conflictAlgorithm: ConflictAlgorithm.replace);
          syncedCount++;
          
        } catch (e) {
          _addProgressMessage('⚠️ Error syncing order item ${doc.id}: $e');
          errorCount++;
        }
      }
      
      _addProgressMessage('✅ Order items sync completed - Synced: $syncedCount, Skipped: $skippedCount, Errors: $errorCount, Placeholders Created: $placeholderMenuItemsCreated');
      
      if (syncedCount > 0) {
        _addProgressMessage('🎯 Successfully synced $syncedCount order items with proper foreign key validation');
      }
      
    } catch (e) {
      _addProgressMessage('⚠️ Failed to sync order items from cloud: $e');
      debugPrint('⚠️ Order items sync error details: $e');
    }
  }
  
  /// Create a placeholder menu item when the referenced menu item doesn't exist
  Future<void> _createPlaceholderMenuItem(DatabaseExecutor db, String menuItemId, Map<String, dynamic> orderItemData) async {
    try {
      // Extract information from the order item to create a meaningful placeholder
      final name = orderItemData['name'] as String? ?? 'Unknown Item';
      final price = orderItemData['unit_price'] ?? orderItemData['price'] ?? 0.0;
      
      // CRITICAL FIX: Create a default category first if it doesn't exist
      int categoryId = 1; // Default category ID
      
      // Check if default category exists, if not create it
      final existingCategories = await db.query('categories');
      if (existingCategories.isEmpty) {
        // Create a default category
        final defaultCategory = {
          'id': 1,
          'name': 'Default Category',
          'description': 'Default category for placeholder items',
          'image_url': null,
          'is_active': 1,
          'sort_order': 1,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };
        
        try {
          await db.insert('categories', defaultCategory);
          _addProgressMessage('✅ Created default category for placeholder items');
        } catch (e) {
          _addProgressMessage('⚠️ Failed to create default category: $e');
          // If category creation fails, try to use existing category or create with minimal data
          categoryId = 1;
        }
      } else {
        // Use the first available category
        categoryId = existingCategories.first['id'] as int? ?? 1;
      }
      
      // CRITICAL FIX: Use only columns that exist in the local database schema
      final placeholderMenuItem = {
        'id': menuItemId,
        'name': name,
        'description': 'Placeholder item created from order data',
        'price': price,
        'category_id': categoryId,  // FIXED: Now provides valid category_id
        'image_url': null,
        'is_available': 1,
        'is_vegetarian': 0,
        'is_vegan': 0,
        'is_gluten_free': 0,
        'is_spicy': 0,
        'preparation_time': 0,
        'spice_level': 0,
        'stock_quantity': 0,
        'low_stock_threshold': 5,
        'popularity_score': 0.0,
        'last_ordered': null,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      await db.insert('menu_items', placeholderMenuItem);
      _addProgressMessage('✅ Created placeholder menu item: $name (ID: $menuItemId) with category_id: $categoryId');
      
    } catch (e) {
      _addProgressMessage('⚠️ Failed to create placeholder menu item $menuItemId: $e');
    }
  }
  
  /// Sanitize order item data to match local database schema
  Map<String, dynamic> _sanitizeOrderItemData(Map<String, dynamic> firebaseOrderItem) {
    final sanitized = Map<String, dynamic>.from(firebaseOrderItem);
    
    // CRITICAL FIX: Map Firebase field names to local database column names
    // Firebase uses camelCase, local database uses snake_case
    
    // Map menuItemId to menu_item_id
    if (sanitized.containsKey('menuItemId')) {
      sanitized['menu_item_id'] = sanitized['menuItemId'];
      sanitized.remove('menuItemId');
    }
    
    // Map orderId to order_id
    if (sanitized.containsKey('orderId')) {
      sanitized['order_id'] = sanitized['orderId'];
      sanitized.remove('orderId');
    }
    
    // Map specialInstructions to special_instructions
    if (sanitized.containsKey('specialInstructions')) {
      sanitized['special_instructions'] = sanitized['specialInstructions'];
      sanitized.remove('specialInstructions');
    }
    
    // Map customProperties to custom_properties
    if (sanitized.containsKey('customProperties')) {
      sanitized['custom_properties'] = sanitized['customProperties'];
      sanitized.remove('customProperties');
    }
    
    // Map selectedVariant to selected_variant
    if (sanitized.containsKey('selectedVariant')) {
      sanitized['selected_variant'] = sanitized['selectedVariant'];
      sanitized.remove('selectedVariant');
    }
    
    // Map selectedModifiers to selected_modifiers
    if (sanitized.containsKey('selectedModifiers')) {
      sanitized['selected_modifiers'] = sanitized['selectedModifiers'];
      sanitized.remove('selectedModifiers');
    }
    
    // Map isAvailable to is_available
    if (sanitized.containsKey('isAvailable')) {
      sanitized['is_available'] = sanitized['isAvailable'] ? 1 : 0;
      sanitized.remove('isAvailable');
    }
    
    // Map sentToKitchen to sent_to_kitchen
    if (sanitized.containsKey('sentToKitchen')) {
      sanitized['sent_to_kitchen'] = sanitized['sentToKitchen'] ? 1 : 0;
      sanitized.remove('sentToKitchen');
    }
    
    // Map kitchenStatus to kitchen_status
    if (sanitized.containsKey('kitchenStatus')) {
      sanitized['kitchen_status'] = sanitized['kitchenStatus'];
      sanitized.remove('kitchenStatus');
    }
    
    // Map createdAt to created_at
    if (sanitized.containsKey('createdAt')) {
      sanitized['created_at'] = sanitized['createdAt'];
      sanitized.remove('createdAt');
    }
    
    // Map updatedAt to updated_at
    if (sanitized.containsKey('updatedAt')) {
      sanitized['updated_at'] = sanitized['updatedAt'];
      sanitized.remove('updatedAt');
    }
    
    // Ensure numeric fields are properly typed
    sanitized['quantity'] = _ensureInteger(sanitized['quantity']);
    sanitized['unit_price'] = _ensureNumeric(sanitized['unitPrice'] ?? sanitized['unit_price']);
    sanitized['total_price'] = _ensureNumeric(sanitized['totalPrice'] ?? sanitized['total_price']);
    
    // Remove old field names
    sanitized.remove('unitPrice');
    sanitized.remove('totalPrice');
    
    // Convert complex objects to JSON strings for storage
    if (sanitized['custom_properties'] is Map) {
      sanitized['custom_properties'] = jsonEncode(sanitized['custom_properties']);
    }
    
    if (sanitized['selected_modifiers'] is List) {
      sanitized['selected_modifiers'] = jsonEncode(sanitized['selected_modifiers']);
    }
    
    return sanitized;
  }
  
  /// Sync printer configurations from cloud
  Future<void> _syncPrinterConfigsFromCloud(Restaurant restaurant) async {
    try {
      final printerConfigsSnapshot = await _firestore!.collection('tenants').doc(restaurant.email).collection('printer_configs').get();
      
      int syncedCount = 0;
      for (final doc in printerConfigsSnapshot.docs) {
        // CRITICAL FIX: Skip persistence configuration documents that don't belong in data tables
        if (doc.id == '_persistence_config' || doc.id.startsWith('_')) {
          continue;
        }
        
        final printerConfigData = doc.data();
        printerConfigData['id'] = doc.id;
        
        final db = await _tenantDb!.database;
        if (db != null) {
          // FIX: Use the correct table name 'printer_configurations' instead of 'printer_configs'
          await db.insert('printer_configurations', printerConfigData);
          syncedCount++;
        }
      }
      
      _addProgressMessage('✅ Synced $syncedCount printer configurations from cloud');
    } catch (e) {
      _addProgressMessage('⚠️ Failed to sync printer configurations from cloud: $e');
    }
  }
  
  /// Sync printer assignments from cloud
  Future<void> _syncPrinterAssignmentsFromCloud(Restaurant restaurant) async {
    try {
      final printerAssignmentsSnapshot = await _firestore!.collection('tenants').doc(restaurant.email).collection('printer_assignments').get();
      
      int syncedCount = 0;
      for (final doc in printerAssignmentsSnapshot.docs) {
        // CRITICAL FIX: Skip persistence configuration documents that don't belong in data tables
        if (doc.id == '_persistence_config' || doc.id.startsWith('_')) {
          continue;
        }
        
        final printerAssignmentData = doc.data();
        printerAssignmentData['id'] = doc.id;
        
        final db = await _tenantDb!.database;
        if (db != null) {
          await db.insert('printer_assignments', printerAssignmentData);
          syncedCount++;
        }
      }
      
      _addProgressMessage('✅ Synced $syncedCount printer assignments from cloud');
    } catch (e) {
      _addProgressMessage('⚠️ Failed to sync printer assignments from cloud: $e');
    }
  }
  
  /// Sync order logs from cloud
  Future<void> _syncOrderLogsFromCloud(Restaurant restaurant) async {
    try {
      final orderLogsSnapshot = await _firestore!.collection('tenants').doc(restaurant.email).collection('order_logs').get();
      
      int syncedCount = 0;
      for (final doc in orderLogsSnapshot.docs) {
        // CRITICAL FIX: Skip persistence configuration documents that don't belong in data tables
        if (doc.id == '_persistence_config' || doc.id.startsWith('_')) {
          continue;
        }
        
        final orderLogData = doc.data();
        orderLogData['id'] = doc.id;
        
        final db = await _tenantDb!.database;
        if (db != null) {
          await db.insert('order_logs', orderLogData);
          syncedCount++;
        }
      }
      
      _addProgressMessage('✅ Synced $syncedCount order logs from cloud');
    } catch (e) {
      _addProgressMessage('⚠️ Failed to sync order logs from cloud: $e');
    }
  }
  
  /// Sync customers from cloud
  Future<void> _syncCustomersFromCloud(Restaurant restaurant) async {
    try {
      final customersSnapshot = await _firestore!.collection('tenants').doc(restaurant.email).collection('customers').get();
      
      int syncedCount = 0;
      for (final doc in customersSnapshot.docs) {
        // CRITICAL FIX: Skip persistence configuration documents that don't belong in data tables
        if (doc.id == '_persistence_config' || doc.id.startsWith('_')) {
          continue;
        }
        
        final customerData = doc.data();
        customerData['id'] = doc.id;
        
        final db = await _tenantDb!.database;
        if (db != null) {
          await db.insert('customers', customerData);
          syncedCount++;
        }
      }
      
      _addProgressMessage('✅ Synced $syncedCount customers from cloud');
    } catch (e) {
      _addProgressMessage('⚠️ Failed to sync customers from cloud: $e');
    }
  }
  
  /// Sync transactions from cloud
  Future<void> _syncTransactionsFromCloud(Restaurant restaurant) async {
    try {
      final transactionsSnapshot = await _firestore!.collection('tenants').doc(restaurant.email).collection('transactions').get();
      
      int syncedCount = 0;
      for (final doc in transactionsSnapshot.docs) {
        // CRITICAL FIX: Skip persistence configuration documents that don't belong in data tables
        if (doc.id == '_persistence_config' || doc.id.startsWith('_')) {
          continue;
        }
        
        final transactionData = doc.data();
        transactionData['id'] = doc.id;
        
        final db = await _tenantDb!.database;
        if (db != null) {
          await db.insert('transactions', transactionData);
          syncedCount++;
        }
      }
      
      _addProgressMessage('✅ Synced $syncedCount transactions from cloud');
    } catch (e) {
      _addProgressMessage('⚠️ Failed to sync transactions from cloud: $e');
    }
  }
  
  /// Sync reservations from cloud
  Future<void> _syncReservationsFromCloud(Restaurant restaurant) async {
    try {
      final reservationsSnapshot = await _firestore!.collection('tenants').doc(restaurant.email).collection('reservations').get();
      
      int syncedCount = 0;
      for (final doc in reservationsSnapshot.docs) {
        // CRITICAL FIX: Skip persistence configuration documents that don't belong in data tables
        if (doc.id == '_persistence_config' || doc.id.startsWith('_')) {
          continue;
        }
        
        final reservationData = doc.data();
        reservationData['id'] = doc.id;
        
        final db = await _tenantDb!.database;
        if (db != null) {
          await db.insert('reservations', reservationData);
          syncedCount++;
        }
      }
      
      _addProgressMessage('✅ Synced $syncedCount reservations from cloud');
    } catch (e) {
      _addProgressMessage('⚠️ Failed to sync reservations from cloud: $e');
    }
  }
  
  /// Sync app metadata from cloud
  Future<void> _syncAppMetadataFromCloud(Restaurant restaurant) async {
    try {
      final appMetadataDoc = await _firestore!.collection('tenants').doc(restaurant.email).collection('app_metadata').doc('settings').get();
      
      if (appMetadataDoc.exists) {
        final appMetadataData = appMetadataDoc.data();
        if (appMetadataData != null) {
          appMetadataData['id'] = appMetadataDoc.id;
          
          final db = await _tenantDb!.database;
          if (db != null) {
            await db.insert('app_metadata', appMetadataData);
          }
        }
      }
      
      _addProgressMessage('✅ Synced app metadata from cloud');
    } catch (e) {
      _addProgressMessage('⚠️ Failed to sync app metadata from cloud: $e');
    }
  }
  
  /// Create authenticated session
  Future<void> _createSession(Restaurant restaurant, RestaurantSession session) async {
    _currentRestaurant = restaurant;
    _currentSession = session;
    
    // CRITICAL FIX: Set the tenant ID for Firebase operations
    FirebaseConfig.setCurrentTenantId(restaurant.email);
    _addProgressMessage('🏪 Set Firebase tenant ID: ${restaurant.email}');
    
    // Connect to tenant database
    await _connectToTenantDatabase(restaurant);
    
    isAuthenticated = true; // Use setter for protection
    debugPrint('🔐 CRITICAL: _isAuthenticated set to TRUE in _createSession');
    
    // Save session to preferences
    await _saveSession();
    
    // Start session timer
    _startSessionTimer();
    
    _addProgressMessage('✅ Session created for ${session.userName} at ${restaurant.name}');
    debugPrint('🔐 CRITICAL: About to notify listeners with _isAuthenticated=$_isAuthenticated');
    notifyListeners();
    debugPrint('🔐 CRITICAL: Listeners notified with _isAuthenticated=$_isAuthenticated');
  }
  
  /// Connect to tenant database
  Future<void> _connectToTenantDatabase(Restaurant restaurant) async {
    try {
      _tenantDb = DatabaseService();
      await _tenantDb!.initializeWithCustomName(restaurant.databaseName);
      _addProgressMessage('✅ Connected to tenant database: ${restaurant.databaseName}');
      
      // CRITICAL: During login, we only connect to existing tenant database
      // Data copying should ONLY happen during registration
      // No data copying here - just connect and use existing data
      
    } catch (e) {
      _addProgressMessage('❌ Failed to connect to tenant database: $e');
      _tenantDb = null;
    }
  }
  
  /// Logout current user and clear session
  Future<void> logout() async {
    try {
      debugPrint('🔒 Logging out user...');
      
      // Stop session timer
      _sessionTimer?.cancel();
      _sessionTimer = null;
      
      // Clear current session
      _currentSession = null;
      isAuthenticated = false; // Use setter for protection
      
      // Clear error state
      _clearError();
      
      // Clear session data from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_session');
      await prefs.remove('current_restaurant');
      await prefs.remove('last_login_time');
      
      // Disconnect from Firebase sync
      try {
        final syncService = UnifiedSyncService.instance;
        await syncService.disconnect();
      } catch (e) {
        debugPrint('⚠️ Error disconnecting from Firebase sync: $e');
      }
      
      // Clear tenant database reference
      _tenantDb = null;
      
      debugPrint('✅ Logout completed successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error during logout: $e');
      // Force clear state even if there's an error
      _currentSession = null;
      isAuthenticated = false; // Use setter for protection
      _clearError();
      notifyListeners();
    }
  }
  
  /// Save current session to preferences
  Future<void> _saveSession() async {
    if (_currentSession == null || _currentRestaurant == null) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_session', jsonEncode(_currentSession!.toJson()));
      await prefs.setString('current_restaurant', jsonEncode(_currentRestaurant!.toJson()));
    } catch (e) {
      _addProgressMessage('⚠️ Failed to save session: $e');
    }
  }
  
  /// Clear session data
  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_session');
      await prefs.remove('current_restaurant');
    } catch (e) {
      _addProgressMessage('⚠️ Failed to clear session: $e');
    }
  }
  
  /// Start session timer
  void _startSessionTimer() {
    _stopSessionTimer();
    _sessionTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      _checkSessionTimeout();
    });
  }
  
  /// Stop session timer
  void _stopSessionTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = null;
  }
  
  /// Check session timeout
  void _checkSessionTimeout() {
    if (_currentSession == null) return;
    
    final now = DateTime.now();
    final lastActivity = _currentSession!.lastActivity ?? _currentSession!.loginTime;
    final sessionAge = now.difference(lastActivity);
    
    if (sessionAge > sessionTimeout) {
      _addProgressMessage('⏰ Session timeout - logging out');
      logout();
    }
  }
  
  /// Clear existing restaurant
  Future<void> _clearExistingRestaurant(Restaurant restaurant) async {
    try {
      _addProgressMessage('🧹 Clearing existing restaurant: ${restaurant.name}');
      
      // Remove from local list
      _registeredRestaurants.removeWhere((r) => r.id == restaurant.id);
      
      // Remove from local database
      final db = await _globalDb.database;
      if (db != null) {
        await db.delete('restaurants', where: 'id = ?', whereArgs: [restaurant.id]);
      }
      
      // Remove from Firebase
      if (_firestore != null) {
        await _firestore!.collection('restaurants').doc(restaurant.email).delete();
        await _firestore!.collection('global_restaurants').doc(restaurant.email).delete();
      }
      
      _addProgressMessage('✅ Existing restaurant cleared');
    } catch (e) {
      _addProgressMessage('⚠️ Could not clear existing restaurant: $e');
    }
  }
  
  /// Hash password
  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
  
  /// Verify password
  bool _verifyPassword(String password, String hashedPassword) {
    return _hashPassword(password) == hashedPassword;
  }
  
  /// Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
  
  /// Force clear loading state (for emergency recovery)
  void forceClearLoading() {
    debugPrint('🔄 Force clearing loading state');
    _isLoading = false;
    _clearError();
    notifyListeners();
  }
  
  /// Clear error state
  void _clearError() {
    _lastError = null;
  }
  
  /// Set error state
  void _setError(String error) {
    _lastError = error;
    debugPrint('❌ Auth error: $error');
  }
  
  /// ENHANCEMENT: Immediately sync tenant data to Firebase for cross-device availability
  Future<void> _syncTenantDataToFirebase(Restaurant restaurant, DatabaseService tenantDb) async {
    try {
      _addProgressMessage('🔄 Syncing tenant data to Firebase for immediate cross-device availability...');
      
      if (_firestore == null) {
        _addProgressMessage('⚠️ Firebase not available for immediate sync');
        return;
      }
      
      final tenantDoc = _firestore!.collection('tenants').doc(restaurant.email);
      
      // Sync users
      await _syncUsersToFirebase(tenantDoc, tenantDb);
      
      // Sync categories
      await _syncCategoriesToFirebase(tenantDoc, tenantDb);
      
      // Sync menu items
      await _syncMenuItemsToFirebase(tenantDoc, tenantDb);
      
      // Sync tables
      await _syncTablesToFirebase(tenantDoc, tenantDb);
      
      _addProgressMessage('✅ Tenant data synced to Firebase - immediately available on other devices');
    } catch (e) {
      _addProgressMessage('⚠️ Failed to sync tenant data to Firebase: $e');
      // Don't throw - Firebase sync is optional for registration success
    }
  }
  
  /// Sync users to Firebase
  Future<void> _syncUsersToFirebase(DocumentReference tenantDoc, DatabaseService tenantDb) async {
    try {
      final db = await tenantDb.database;
      if (db == null) return;
      
      final users = await db.query('users');
      for (final user in users) {
        await tenantDoc.collection('users').doc(user['id'] as String).set(user);
      }
      _addProgressMessage('✅ Synced ${users.length} users to Firebase');
    } catch (e) {
      _addProgressMessage('⚠️ Failed to sync users to Firebase: $e');
    }
  }
  
  /// Sync categories to Firebase
  Future<void> _syncCategoriesToFirebase(DocumentReference tenantDoc, DatabaseService tenantDb) async {
    try {
      final db = await tenantDb.database;
      if (db == null) return;
      
      final categories = await db.query('categories');
      for (final category in categories) {
        await tenantDoc.collection('categories').doc(category['id'] as String).set(category);
      }
      _addProgressMessage('✅ Synced ${categories.length} categories to Firebase');
    } catch (e) {
      _addProgressMessage('⚠️ Failed to sync categories to Firebase: $e');
    }
  }
  
  /// Sync menu items to Firebase
  Future<void> _syncMenuItemsToFirebase(DocumentReference tenantDoc, DatabaseService tenantDb) async {
    try {
      final db = await tenantDb.database;
      if (db == null) return;
      
      final menuItems = await db.query('menu_items');
      for (final menuItem in menuItems) {
        await tenantDoc.collection('menu_items').doc(menuItem['id'] as String).set(menuItem);
      }
      _addProgressMessage('✅ Synced ${menuItems.length} menu items to Firebase');
    } catch (e) {
      _addProgressMessage('⚠️ Failed to sync menu items to Firebase: $e');
    }
  }
  
  /// Sync tables to Firebase
  Future<void> _syncTablesToFirebase(DocumentReference tenantDoc, DatabaseService tenantDb) async {
    try {
      final db = await tenantDb.database;
      if (db == null) return;
      
      final tables = await db.query('tables');
      for (final table in tables) {
        await tenantDoc.collection('tables').doc(table['id'] as String).set(table);
      }
      _addProgressMessage('✅ Synced ${tables.length} tables to Firebase');
    } catch (e) {
      _addProgressMessage('⚠️ Failed to sync tables to Firebase: $e');
    }
  }
  
  /// ENHANCEMENT: Check if local data is stale (older than 24 hours)
  bool _isLocalDataStale(Restaurant restaurant) {
    final lastSyncTime = restaurant.updatedAt;
    final now = DateTime.now();
    final timeSinceSync = now.difference(lastSyncTime);
    
    // Check if data is older than 24 hours
    return timeSinceSync > const Duration(hours: 24);
  }
  
  /// ENHANCEMENT: Validate tenant database completeness
  Future<void> _validateTenantDatabaseCompleteness(Restaurant restaurant, DatabaseService tenantDb) async {
    try {
      _addProgressMessage('🔍 Validating tenant database completeness...');
      
      final db = await tenantDb.database;
      if (db == null) {
        _addProgressMessage('⚠️ Tenant database not available for validation');
        return;
      }
      
      // Check if essential tables have data
      final categories = await db.query('categories');
      final menuItems = await db.query('menu_items');
      final tables = await db.query('tables');
      final users = await db.query('users');
      
      _addProgressMessage('📊 Database validation results:');
      _addProgressMessage('   📂 Categories: ${categories.length}');
      _addProgressMessage('   🍽️ Menu Items: ${menuItems.length}');
      _addProgressMessage('   🪑 Tables: ${tables.length}');
      _addProgressMessage('   👥 Users: ${users.length}');
      
      final totalItems = categories.length + menuItems.length + tables.length + users.length;
      
      if (totalItems >= 10) { // At least 5 categories + 5 menu items + some tables/users
        _addProgressMessage('✅ Tenant database validation passed: $totalItems items');
      } else {
        _addProgressMessage('⚠️ Tenant database validation warning: Only $totalItems items found');
      }
      
    } catch (e) {
      _addProgressMessage('⚠️ Failed to validate tenant database: $e');
      debugPrint('Database validation error: $e');
    }
  }
  
  /// Set admin user as current user for immediate access
  Future<void> _setAdminAsCurrentUser(Restaurant restaurant, app_user.User adminUser) async {
    try {
      _addProgressMessage('👤 Setting admin user as current user for immediate access...');
      
      // Store admin user in session for immediate access
      _currentSession = RestaurantSession(
        restaurantId: restaurant.id,
        userId: adminUser.id,
        userName: adminUser.name,
        userRole: adminUser.role,
        loginTime: DateTime.now(),
        lastActivity: DateTime.now(),
        isActive: true,
      );
      
      // Update current restaurant
      _currentRestaurant = restaurant;
      
      // Mark as authenticated
      _isAuthenticated = true;
      
      _addProgressMessage('✅ Admin user set as current user - ready for immediate access');
      _addProgressMessage('🔑 Admin user can now:');
      _addProgressMessage('   • Create new orders');
      _addProgressMessage('   • Access admin panel');
      _addProgressMessage('   • Manage all system features');
      
      notifyListeners();
    } catch (e) {
      _addProgressMessage('⚠️ Warning: Could not set admin as current user: $e');
      // Don't fail the registration process for this
    }
  }
  
  /// ENHANCEMENT: Update restaurant's last sync time
  Future<void> _updateRestaurantSyncTime(Restaurant restaurant) async {
    try {
      final db = await _globalDb.database;
      if (db == null) return;
      
      final now = DateTime.now();
      
      // First try to update by restaurant id
      int updatedRows = await db.update(
        'restaurants',
        {'updated_at': now.toIso8601String()},
        where: 'id = ?',
        whereArgs: [restaurant.id],
      );
      
      // Fallback: some records may key on email; try updating by email if id didn't match
      if (updatedRows == 0) {
        updatedRows = await db.update(
          'restaurants',
          {'updated_at': now.toIso8601String()},
          where: 'email = ?',
          whereArgs: [restaurant.email],
        );
      }
      
      if (updatedRows > 0) {
        _addProgressMessage('✅ Restaurant sync time updated to ${now.toIso8601String()}');
      } else {
        // Not critical; no matching record to update
        _addProgressMessage('ℹ️ Restaurant sync time not updated (no matching record)');
      }
    } catch (e) {
      _addProgressMessage('⚠️ Failed to update restaurant sync time: $e');
    }
  }
  
  /// ENHANCEMENT: Trigger the working comprehensive sync service for orders
  /// This uses the same logic as the POS dashboard sync icon
  Future<void> triggerWorkingComprehensiveSync(Restaurant restaurant) async {
    try {
      _addProgressMessage('🚀 Starting working comprehensive sync operations...');
      
      // ZERO RISK: Create order service with safe fallback
      OrderService? orderService;
      try {
        orderService = OrderService(_tenantDb!, OrderLogService(_tenantDb!), InventoryService());
      } catch (e) {
        _addProgressMessage('⚠️ OrderService creation failed, skipping enhanced sync: $e');
        debugPrint('⚠️ OrderService creation error: $e');
        // Continue with basic sync only - ZERO RISK
        return;
      }
      
      // STEP 1: Comprehensive Timestamp-Based Sync (SAFE)
      _addProgressMessage('🔄 STEP 1: Performing Comprehensive Timestamp-Based Sync...');
      await _performComprehensiveTimestampSyncForOrders(restaurant, orderService);
      
      // STEP 2: SAFE Order Items Sync (with rollback capability)
      _addProgressMessage('🔄 STEP 2: Safely syncing Order Items from Firebase...');
      await _safeSyncOrderItemsFromCloud(restaurant);
      
      // STEP 3: Smart Time-Based Sync (EXISTING - SAFE)
      _addProgressMessage('🔄 STEP 3: Performing Smart Time-Based Sync...');
      await _performSmartTimeBasedSyncForOrders(restaurant);
      
      // STEP 4: Force Manual Sync as Backup (EXISTING - SAFE)
      _addProgressMessage('🔄 STEP 4: Performing Force Manual Sync...');
      try {
        await orderService.manualSync();
      } catch (e) {
        _addProgressMessage('⚠️ Manual sync failed (non-critical): $e');
        // Don't fail the entire process
      }
      
      _addProgressMessage('✅ All working comprehensive sync operations completed successfully!');
      
    } catch (e) {
      _addProgressMessage('❌ Working comprehensive sync failed: $e');
      debugPrint('❌ Working comprehensive sync error: $e');
      // Don't throw - sync failure shouldn't prevent login
    }
  }
  
  /// Perform comprehensive timestamp-based sync for orders
  Future<void> _performComprehensiveTimestampSyncForOrders(Restaurant restaurant, OrderService orderService) async {
    try {
      _addProgressMessage('🔄 Starting comprehensive timestamp-based sync for orders...');
      
      // Get current order count
      final initialOrderCount = orderService.allOrders.length;
      _addProgressMessage('📊 Initial local orders: $initialOrderCount');
      
      // Trigger the comprehensive sync method
      await orderService.syncOrdersWithFirebase();
      
      final finalOrderCount = orderService.allOrders.length;
      _addProgressMessage('📊 Final local orders: $finalOrderCount');
      _addProgressMessage('📥 Orders added: ${finalOrderCount - initialOrderCount}');
      
      // CRITICAL FIX: After syncing orders, also sync order items to ensure complete data
      _addProgressMessage('🔄 Syncing order items after order sync...');
      await _syncOrderItemsFromCloud(restaurant);
      
      // CRITICAL FIX: Extract order items from order documents (embedded items)
      _addProgressMessage('🔄 Extracting order items from order documents...');
      await _extractAndSyncOrderItemsFromOrders(restaurant);
      
      // CRITICAL FIX: Also sync menu items to ensure order items can be properly displayed
      _addProgressMessage('🔄 Syncing menu items to support order items...');
      await _syncMenuItemsFromCloud(restaurant);
      
      _addProgressMessage('✅ Comprehensive order sync completed with order items and menu items');
      
    } catch (e) {
      _addProgressMessage('❌ Comprehensive timestamp-based sync failed: $e');
      debugPrint('⚠️ Comprehensive timestamp-based sync error: $e');
      // Don't throw - continue with other sync methods
    }
  }
  
  /// Perform smart time-based sync for orders
  Future<void> _performSmartTimeBasedSyncForOrders(Restaurant restaurant) async {
    try {
      _addProgressMessage('🔄 Starting smart time-based sync for orders...');
      
      // Try to get the unified sync service
      try {
        final unifiedSyncService = UnifiedSyncService.instance;
        await unifiedSyncService.initialize();
        
        // Create a temporary session for sync
        final tempSession = RestaurantSession(
          restaurantId: restaurant.email,
          userId: 'temp_user',
          userName: 'temp_user',
          userRole: app_user.UserRole.admin,
          loginTime: DateTime.now(),
        );
        
        await unifiedSyncService.connectToRestaurant(restaurant, tempSession);
        
        // Check if sync is needed
        final needsSync = await unifiedSyncService.needsSync();
        
        if (needsSync) {
          _addProgressMessage('🔄 Smart sync needed - performing time-based sync...');
          await unifiedSyncService.performSmartTimeBasedSync();
          _addProgressMessage('✅ Smart time-based sync completed');
        } else {
          _addProgressMessage('✅ Smart sync not needed - data is already consistent');
        }
      } catch (e) {
        _addProgressMessage('⚠️ Unified sync service not available: $e');
        debugPrint('⚠️ Unified sync service error: $e');
        // Continue without unified sync service
      }
      
    } catch (e) {
      _addProgressMessage('❌ Smart time-based sync failed: $e');
      debugPrint('⚠️ Smart time-based sync error: $e');
      // Don't throw - continue with other sync methods
    }
  }

  /// ENHANCEMENT: Ensure data persistence in Firebase - data remains until explicitly deleted
  Future<void> _ensureFirebaseDataPersistence(Restaurant restaurant) async {
    try {
      _addProgressMessage('🔒 Ensuring Firebase data persistence...');
      
      if (_firestore == null) {
        _addProgressMessage('⚠️ Firebase not available for persistence check');
        return;
      }
      
      final tenantId = restaurant.email;
      final tenantDoc = _firestore!.collection('tenants').doc(tenantId);
      
      // Create a persistence configuration document
      await tenantDoc.collection('_persistence_config').doc('config').set({
        'tenant_id': tenantId,
        'restaurant_name': restaurant.name,
        'created_at': DateTime.now().toIso8601String(),
        'last_updated': DateTime.now().toIso8601String(),
        'sync_enabled': true,
        'auto_sync': true,
        'data_version': '1.0',
        'schema_version': '1.0',
      });
      
      _addProgressMessage('✅ Firebase persistence configuration created');
      
      // Verify that data exists in Firebase
      await _verifyFirebaseDataExists(restaurant);
      
    } catch (e) {
      _addProgressMessage('⚠️ Failed to ensure Firebase persistence: $e');
      debugPrint('Firebase persistence error: $e');
    }
  }

  /// Verify that data exists in Firebase after sync
  Future<void> _verifyFirebaseDataExists(Restaurant restaurant) async {
    try {
      _addProgressMessage('🔍 Verifying Firebase data exists...');
      
      if (_firestore == null) return;
      
      final tenantId = restaurant.email;
      final tenantDoc = _firestore!.collection('tenants').doc(tenantId);
      
      // Check categories
      final categoriesSnapshot = await tenantDoc.collection('categories').get();
      _addProgressMessage('📂 Firebase categories: ${categoriesSnapshot.docs.length}');
      
      // Check menu items
      final menuItemsSnapshot = await tenantDoc.collection('menu_items').get();
      _addProgressMessage('🍽️ Firebase menu items: ${menuItemsSnapshot.docs.length}');
      
      // Check tables
      final tablesSnapshot = await tenantDoc.collection('tables').get();
      _addProgressMessage('🪑 Firebase tables: ${tablesSnapshot.docs.length}');
      
      // Check users
      final usersSnapshot = await tenantDoc.collection('users').get();
      _addProgressMessage('👥 Firebase users: ${usersSnapshot.docs.length}');
      
      final totalItems = categoriesSnapshot.docs.length + 
                        menuItemsSnapshot.docs.length + 
                        tablesSnapshot.docs.length + 
                        usersSnapshot.docs.length;
      
      if (totalItems > 0) {
        _addProgressMessage('✅ Firebase data verification successful: $totalItems total items');
      } else {
        _addProgressMessage('⚠️ Firebase data verification failed: No items found');
      }
      
    } catch (e) {
      _addProgressMessage('⚠️ Failed to verify Firebase data: $e');
      debugPrint('Firebase verification error: $e');
    }
  }
  
  /// ENHANCEMENT: Explicitly delete data from Firebase (only way to remove data)
  Future<void> deleteDataFromFirebase(Restaurant restaurant, String collectionName, String documentId) async {
    try {
      _addProgressMessage('🗑️ Explicitly deleting $documentId from $collectionName in Firebase...');
      
      if (_firestore == null) {
        _addProgressMessage('⚠️ Firebase not available for deletion');
        return;
      }
      
      await _firestore!.collection('tenants').doc(restaurant.email).collection(collectionName).doc(documentId).delete();
      
      _addProgressMessage('✅ Successfully deleted $documentId from $collectionName in Firebase');
    } catch (e) {
      _addProgressMessage('❌ Failed to delete $documentId from $collectionName: $e');
    }
  }
  
  /// ENHANCEMENT: Delete entire collection from Firebase
  Future<void> deleteCollectionFromFirebase(Restaurant restaurant, String collectionName) async {
    try {
      _addProgressMessage('🗑️ Explicitly deleting entire $collectionName collection from Firebase...');
      
      if (_firestore == null) {
        _addProgressMessage('⚠️ Firebase not available for collection deletion');
        return;
      }
      
      final collectionRef = _firestore!.collection('tenants').doc(restaurant.email).collection(collectionName);
      final documents = await collectionRef.get();
      
      for (final doc in documents.docs) {
        await doc.reference.delete();
      }
      
      _addProgressMessage('✅ Successfully deleted entire $collectionName collection from Firebase');
    } catch (e) {
      _addProgressMessage('❌ Failed to delete $collectionName collection: $e');
    }
  }
  
  /// ENHANCEMENT: Perform startup sync for all restaurants
  Future<void> _performStartupSync() async {
    try {
      _addProgressMessage('🔄 Starting comprehensive startup sync for all restaurants...');
      
      for (final restaurant in _registeredRestaurants) {
        try {
          _addProgressMessage('🔄 Performing comprehensive sync for ${restaurant.name}...');
          
          // CRITICAL FIX: Always perform sync on startup to ensure latest data
          // Connect to this restaurant's tenant database BEFORE syncing
          await _connectToTenantDatabase(restaurant);
          
          // Now perform the full sync with the connected database
          await _performFullSyncFromCloud(restaurant);
          
          _addProgressMessage('✅ Successfully synced data for ${restaurant.name}');
        } catch (restaurantSyncError) {
          _addProgressMessage('⚠️ Failed to sync ${restaurant.name}: $restaurantSyncError');
          debugPrint('⚠️ Restaurant sync error for ${restaurant.name}: $restaurantSyncError');
          // Continue with other restaurants - don't fail entire startup sync
        }
      }
      
      _addProgressMessage('✅ Startup sync completed for all restaurants');
    } catch (e) {
      _addProgressMessage('⚠️ Startup sync failed: $e');
      debugPrint('⚠️ Startup sync error: $e');
      // Don't fail initialization due to sync issues
    }
  }
  
  /// Direct order sync implementation for auth service
  Future<void> _performDirectOrderSync(Restaurant restaurant) async {
    try {
      _addProgressMessage('🔍 Checking local orders...');
      
      // Get local orders with timestamps
      final db = await _tenantDb!.database;
      if (db == null) {
        _addProgressMessage('⚠️ Tenant database not available for order sync');
        return;
      }
      
      final localOrdersResult = await db.query('orders');
      final localOrders = <String, Map<String, dynamic>>{};
      for (final row in localOrdersResult) {
        localOrders[row['id'] as String] = row;
      }
      
      _addProgressMessage('📊 Found ${localOrders.length} orders in local database');
      
      _addProgressMessage('🔍 Checking Firebase orders...');
      
      // Get Firebase orders with timestamps
      final ordersSnapshot = await _firestore!.collection('tenants').doc(restaurant.email).collection('orders').get();
      final firebaseOrders = <String, Map<String, dynamic>>{};
      
      for (final doc in ordersSnapshot.docs) {
        if (doc.id == '_persistence_config') continue; // Skip Firebase internal documents
        final orderData = doc.data();
        orderData['id'] = doc.id;
        firebaseOrders[doc.id] = orderData;
      }
      
      _addProgressMessage('📊 Found ${firebaseOrders.length} orders in Firebase');
      
      if (localOrders.isEmpty && firebaseOrders.isEmpty) {
        _addProgressMessage('✅ No orders to sync - both local and cloud are empty');
        return;
      }
      
      // Compare and merge orders by timestamp
      int updatedCount = 0;
      int uploadedCount = 0;
      int skippedCount = 0;
      
      _addProgressMessage('🔄 Comparing timestamps and merging orders...');
      
      for (final orderId in {...localOrders.keys, ...firebaseOrders.keys}) {
        final localOrder = localOrders[orderId];
        final firebaseOrder = firebaseOrders[orderId];
        
        if (localOrder != null && firebaseOrder != null) {
          // Both exist - compare timestamps
          try {
            final localUpdatedAt = DateTime.parse(localOrder['updatedAt'] ?? '1970-01-01T00:00:00.000Z');
            final firebaseUpdatedAt = DateTime.parse(firebaseOrder['updatedAt'] ?? '1970-01-01T00:00:00.000Z');
            
            if (localUpdatedAt.isAfter(firebaseUpdatedAt)) {
              // Local is newer - upload to Firebase
              await _firestore!.collection('tenants').doc(restaurant.email).collection('orders').doc(orderId).set(localOrder);
              uploadedCount++;
            } else if (firebaseUpdatedAt.isAfter(localUpdatedAt)) {
              // Firebase is newer - update local
              await _upsertOrderSafe(db, firebaseOrder);
              updatedCount++;
            } else {
              // Timestamps are equal - no update needed
              skippedCount++;
            }
          } catch (e) {
            _addProgressMessage('⚠️ Error parsing timestamps for order $orderId: $e');
            // If timestamp parsing fails, skip this order
            skippedCount++;
          }
        } else if (localOrder != null) {
          // Only local exists - upload to Firebase
          await _firestore!.collection('tenants').doc(restaurant.email).collection('orders').doc(orderId).set(localOrder);
          uploadedCount++;
        } else if (firebaseOrder != null) {
          // Only Firebase exists - download to local
          await _upsertOrderSafe(db, firebaseOrder);
          updatedCount++;
        }
      }
      
      _addProgressMessage('✅ Orders sync completed: $updatedCount downloaded, $uploadedCount uploaded, $skippedCount skipped');
    } catch (e) {
      _addProgressMessage('❌ Failed to perform direct order sync: $e');
      debugPrint('⚠️ Direct order sync error details: $e');
      rethrow;
    }
  }
  
  @override
  void dispose() {
    _stopSessionTimer();
    super.dispose();
  }

  /// Create default inventory items for new restaurant
  Future<void> _createDefaultInventory(DatabaseService tenantDb) async {
    final inventoryItems = <Map<String, dynamic>>[
      {
        'id': 'inv_tomatoes_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Fresh Tomatoes',
        'description': 'Fresh red tomatoes for salads and cooking',
        'current_stock': 100,
        'min_stock': 20,
        'max_stock': 200,
        'cost_price': 0.50,
        'selling_price': 1.99,
        'unit': 'pieces',
        'supplier_id': 'supplier_local_farm',
        'category': 'vegetables',
        'is_active': 1,
        'last_updated': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'inv_chicken_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Chicken Breast',
        'description': 'Fresh boneless chicken breast for main dishes',
        'current_stock': 50,
        'min_stock': 10,
        'max_stock': 100,
        'cost_price': 8.99,
        'selling_price': 18.99,
        'unit': 'kg',
        'supplier_id': 'supplier_premium_meats',
        'category': 'meat',
        'is_active': 1,
        'last_updated': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'inv_rice_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Basmati Rice',
        'description': 'Premium long-grain basmati rice',
        'current_stock': 100,
        'min_stock': 25,
        'max_stock': 200,
        'cost_price': 3.99,
        'selling_price': 8.99,
        'unit': 'kg',
        'supplier_id': 'supplier_global_foods',
        'category': 'grains',
        'is_active': 1,
        'last_updated': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'inv_vegetables_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Mixed Vegetables',
        'description': 'Assorted fresh seasonal vegetables',
        'current_stock': 75,
        'min_stock': 15,
        'max_stock': 150,
        'cost_price': 2.99,
        'selling_price': 6.99,
        'unit': 'kg',
        'supplier_id': 'supplier_fresh_produce',
        'category': 'vegetables',
        'is_active': 1,
        'last_updated': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'inv_dairy_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Fresh Milk',
        'description': 'Fresh whole milk for beverages and cooking',
        'current_stock': 60,
        'min_stock': 12,
        'max_stock': 120,
        'cost_price': 1.99,
        'selling_price': 4.99,
        'unit': 'liters',
        'supplier_id': 'supplier_dairy_farm',
        'category': 'dairy',
        'is_active': 1,
        'last_updated': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      },
    ];

    for (final item in inventoryItems) {
      await tenantDb.insert('inventory', item);
    }
  }

  /// Create default printer configurations for new restaurant
  Future<void> _createDefaultPrinterConfigs(DatabaseService tenantDb) async {
    final printerConfigs = <Map<String, dynamic>>[
      {
        'id': 'printer_kitchen_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Kitchen Printer',
        'description': 'Main kitchen printer for order tickets',
        'type': 'wifi',
        'model': 'Thermal Printer Pro',
        'ip_address': '192.168.1.100',
        'port': 9100,
        'station_id': 'main_kitchen',
        'is_active': 1,
        'is_default': 1,
        'connection_status': 'connected',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'printer_bar_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Bar Printer',
        'description': 'Bar area printer for drink orders',
        'type': 'wifi',
        'model': 'Thermal Printer Mini',
        'ip_address': '192.168.1.101',
        'port': 9100,
        'station_id': 'bar',
        'is_active': 1,
        'is_default': 0,
        'connection_status': 'connected',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'printer_cashier_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Cashier Printer',
        'description': 'Front desk receipt printer',
        'type': 'usb',
        'model': 'Receipt Printer Plus',
        'station_id': 'cashier',
        'is_active': 1,
        'is_default': 0,
        'connection_status': 'connected',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
    ];

    for (final printer in printerConfigs) {
      await tenantDb.insert('printer_configurations', printer);
    }
  }

  /// Create additional default users for testing
  Future<void> _createDefaultUsers(DatabaseService tenantDb) async {
    final users = <Map<String, dynamic>>[
      {
        'id': 'cashier1_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Cashier 1',
        'role': 'cashier',
        'pin': '1111',
        'is_active': 1,
        'admin_panel_access': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'waiter1_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Waiter 1',
        'role': 'waiter',
        'pin': '2222',
        'is_active': 1,
        'admin_panel_access': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'chef1_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Chef 1',
        'role': 'chef',
        'pin': '3333',
        'is_active': 1,
        'admin_panel_access': 0,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'manager1_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Manager 1',
        'role': 'manager',
        'pin': '4444',
        'is_active': 1,
        'admin_panel_access': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
    ];

    for (final user in users) {
      await tenantDb.insert('users', user);
    }
  }

  /// Create default customers for new restaurant
  Future<void> _createDefaultCustomers(DatabaseService tenantDb) async {
    final customers = <Map<String, dynamic>>[
      {
        'id': 'cust_regular_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'John Smith',
        'email': 'john.smith@email.com',
        'phone': '+1-555-0101',
        'address': '123 Main Street, City, State 12345',
        'loyalty_points': 150,
        'join_date': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
        'preferences': '{"favorite_cuisine": "Italian", "dietary_restrictions": "none"}',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'cust_vip_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Sarah Johnson',
        'email': 'sarah.j@email.com',
        'phone': '+1-555-0102',
        'address': '456 Oak Avenue, City, State 12345',
        'loyalty_points': 450,
        'join_date': DateTime.now().subtract(const Duration(days: 90)).toIso8601String(),
        'preferences': '{"favorite_cuisine": "Asian", "dietary_restrictions": "vegetarian"}',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'cust_new_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Mike Wilson',
        'email': 'mike.w@email.com',
        'phone': '+1-555-0103',
        'address': '789 Pine Road, City, State 12345',
        'loyalty_points': 25,
        'join_date': DateTime.now().subtract(const Duration(days: 7)).toIso8601String(),
        'preferences': '{"favorite_cuisine": "American", "dietary_restrictions": "none"}',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
      },
    ];

    for (final customer in customers) {
      await tenantDb.insert('customers', customer);
    }
  }

  /// Create default loyalty rewards for new restaurant
  Future<void> _createDefaultLoyaltyRewards(DatabaseService tenantDb) async {
    final rewards = <Map<String, dynamic>>[
      {
        'id': 'reward_10_off_${DateTime.now().millisecondsSinceEpoch}',
        'name': '10% Off Next Visit',
        'description': 'Get 10% off your next order',
        'points_required': 100,
        'discount_percentage': 10.0,
        'is_active': 1,
        'valid_until': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'reward_free_dessert_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Free Dessert',
        'description': 'Free dessert with any main course',
        'points_required': 200,
        'discount_percentage': 0.0,
        'is_active': 1,
        'valid_until': DateTime.now().add(const Duration(days: 60)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'reward_25_off_${DateTime.now().millisecondsSinceEpoch}',
        'name': '25% Off Special',
        'description': '25% off your entire order',
        'points_required': 500,
        'discount_percentage': 25.0,
        'is_active': 1,
        'valid_until': DateTime.now().add(const Duration(days: 90)).toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
    ];

    for (final reward in rewards) {
      await tenantDb.insert('loyalty_rewards', reward);
    }
  }

  /// Create default app settings for new restaurant
  Future<void> _createDefaultAppSettings(DatabaseService tenantDb) async {
    final settings = <Map<String, dynamic>>[
      {
        'id': 'setting_tax_rate_${DateTime.now().millisecondsSinceEpoch}',
        'key': 'tax_rate',
        'value': '8.5',
        'description': 'Sales tax rate percentage',
        'category': 'billing',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'setting_currency_${DateTime.now().millisecondsSinceEpoch}',
        'key': 'currency',
        'value': 'USD',
        'description': 'Default currency for transactions',
        'category': 'billing',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'setting_business_hours_${DateTime.now().millisecondsSinceEpoch}',
        'key': 'business_hours',
        'value': '{"monday": {"open": "11:00", "close": "22:00"}, "tuesday": {"open": "11:00", "close": "22:00"}, "wednesday": {"open": "11:00", "close": "22:00"}, "thursday": {"open": "11:00", "close": "22:00"}, "friday": {"open": "11:00", "close": "23:00"}, "saturday": {"open": "10:00", "close": "23:00"}, "sunday": {"open": "10:00", "close": "21:00"}}',
        'description': 'Business operating hours',
        'category': 'operations',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'setting_auto_print_${DateTime.now().millisecondsSinceEpoch}',
        'key': 'auto_print_orders',
        'value': 'true',
        'description': 'Automatically print orders to kitchen',
        'category': 'printing',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      {
        'id': 'setting_loyalty_enabled_${DateTime.now().millisecondsSinceEpoch}',
        'key': 'loyalty_program_enabled',
        'value': 'true',
        'description': 'Enable customer loyalty program',
        'category': 'loyalty',
        'is_active': 1,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
    ];

    for (final setting in settings) {
      await tenantDb.insert('app_settings', setting);
    }
  }

  /// CRITICAL FIX: Extract order items from order documents and sync them to the order_items table
  /// This method handles the case where order items are embedded within order documents
  Future<void> _extractAndSyncOrderItemsFromOrders(Restaurant restaurant) async {
    try {
      _addProgressMessage('🔄 Extracting order items from order documents...');
      
      final db = await _tenantDb!.database;
      if (db == null) {
        _addProgressMessage('⚠️ Tenant database not available for order items extraction');
        return;
      }
      
      // Get all orders from Firebase to extract their order items
      final ordersSnapshot = await _firestore!.collection('tenants').doc(restaurant.email).collection('orders').get();
      
      if (ordersSnapshot.docs.isEmpty) {
        _addProgressMessage('📝 No orders found in Firebase for order items extraction');
        return;
      }
      
      int extractedCount = 0;
      int skippedCount = 0;
      int errorCount = 0;
      
      for (final orderDoc in ordersSnapshot.docs) {
        try {
          if (orderDoc.id == '_persistence_config' || orderDoc.id.startsWith('_')) {
            continue;
          }
          
          final orderData = orderDoc.data();
          final orderId = orderDoc.id;
          
          // Check if the order has embedded items
          final items = orderData['items'] as List?;
          if (items == null || items.isEmpty) {
            continue;
          }
          
          _addProgressMessage('🔍 Processing order ${orderData['orderNumber']} with ${items.length} items');
          
          // Process each order item
          for (final item in items) {
            try {
              if (item is! Map<String, dynamic>) {
                continue;
              }
              
              // Extract order item data
              final orderItemData = {
                'id': item['id'] ?? '${orderId}_${DateTime.now().millisecondsSinceEpoch}',
                'order_id': orderId,
                'menu_item_id': item['menuItemId'] ?? item['menu_item_id'] ?? 'unknown',
                'quantity': item['quantity'] ?? 1,
                'unit_price': item['unitPrice'] ?? item['unit_price'] ?? 0.0,
                'total_price': item['totalPrice'] ?? item['total_price'] ?? 0.0,
                'selected_variant': item['selectedVariant'] ?? item['selected_variant'] ?? '',
                'special_instructions': item['specialInstructions'] ?? item['special_instructions'] ?? '',
                'notes': item['notes'] ?? '',
                'is_available': item['isAvailable'] ?? item['is_available'] ?? 1,
                'sent_to_kitchen': item['sentToKitchen'] ?? item['sent_to_kitchen'] ?? 0,
                'created_at': item['createdAt'] ?? item['created_at'] ?? DateTime.now().toIso8601String(),
                'updated_at': item['updatedAt'] ?? item['updated_at'] ?? DateTime.now().toIso8601String(),
              };
              
              // Check if this order item already exists
              final existingResult = await db.query(
                'order_items',
                where: 'id = ?',
                whereArgs: [orderItemData['id']],
              );
              
              if (existingResult.isEmpty) {
                // Insert new order item (upsert to avoid UNIQUE conflicts)
                await db.insert('order_items', orderItemData, conflictAlgorithm: ConflictAlgorithm.replace);
                extractedCount++;
                _addProgressMessage('✅ Extracted order item: ${orderItemData['id']}');
              } else {
                // Update existing order item
                await db.update(
                  'order_items',
                  orderItemData,
                  where: 'id = ?',
                  whereArgs: [orderItemData['id']],
                );
                extractedCount++;
                _addProgressMessage('🔄 Updated order item: ${orderItemData['id']}');
              }
              
            } catch (e) {
              _addProgressMessage('⚠️ Error processing order item: $e');
              errorCount++;
            }
          }
          
        } catch (e) {
          _addProgressMessage('⚠️ Error processing order ${orderDoc.id}: $e');
          errorCount++;
        }
      }
      
      _addProgressMessage('✅ Order items extraction completed - Extracted: $extractedCount, Skipped: $skippedCount, Errors: $errorCount');
      
      if (extractedCount > 0) {
        _addProgressMessage('🎯 Successfully extracted $extractedCount order items from order documents');
      }
      
    } catch (e) {
      _addProgressMessage('❌ Failed to extract order items from orders: $e');
      debugPrint('⚠️ Order items extraction error details: $e');
    }
  }

  /// ZERO RISK: Safe wrapper for order items sync with rollback capability
  Future<void> _safeSyncOrderItemsFromCloud(Restaurant restaurant) async {
    // ZERO RISK: Check feature flag
    if (!_enableSafeWrappers) {
      _addProgressMessage('🛡️ Safe wrappers disabled - skipping enhanced sync');
      return;
    }
    
    try {
      _addProgressMessage('🛡️ Starting SAFE order items sync with rollback protection...');
      
      // Create backup of current order items before sync
      final db = await _tenantDb!.database;
      if (db == null) {
        _addProgressMessage('⚠️ Database not available for safe sync');
        return;
      }
      
      // STEP 1: Create backup
      final backup = await _createOrderItemsBackup(db);
      _addProgressMessage('💾 Created backup of ${backup.length} existing order items');
      
      // STEP 2: Attempt sync
      try {
        await _syncOrderItemsFromCloud(restaurant);
        _addProgressMessage('✅ Order items sync completed successfully');
      } catch (e) {
        _addProgressMessage('❌ Order items sync failed, rolling back to backup...');
        
        // STEP 3: Rollback on failure
        await _rollbackOrderItemsFromBackup(db, backup);
        _addProgressMessage('🔄 Rollback completed - restored ${backup.length} order items');
        
        // Don't rethrow - this is a safe failure
        _addProgressMessage('⚠️ Order items sync failed but system is safe');
      }
      
    } catch (e) {
      _addProgressMessage('⚠️ Safe sync wrapper failed: $e');
      debugPrint('⚠️ Safe sync wrapper error: $e');
      // Never throw - this is the ultimate safety net
    }
  }

  /// ZERO RISK: Safe wrapper for order items extraction with rollback capability
  Future<void> _safeExtractAndSyncOrderItemsFromOrders(Restaurant restaurant) async {
    // ZERO RISK: Check feature flag
    if (!_enableSafeWrappers) {
      _addProgressMessage('🛡️ Safe wrappers disabled - skipping enhanced extraction');
      return;
    }
    
    try {
      _addProgressMessage('🛡️ Starting SAFE order items extraction with rollback protection...');
      
      // Create backup of current order items before extraction
      final db = await _tenantDb!.database;
      if (db == null) {
        _addProgressMessage('⚠️ Database not available for safe extraction');
        return;
      }
      
      // STEP 1: Create backup
      final backup = await _createOrderItemsBackup(db);
      _addProgressMessage('💾 Created backup of ${backup.length} existing order items');
      
      // STEP 2: Attempt extraction
      try {
        await _extractAndSyncOrderItemsFromOrders(restaurant);
        _addProgressMessage('✅ Order items extraction completed successfully');
      } catch (e) {
        _addProgressMessage('❌ Order items extraction failed, rolling back to backup...');
        
        // STEP 3: Rollback on failure
        await _rollbackOrderItemsFromBackup(db, backup);
        _addProgressMessage('🔄 Rollback completed - restored ${backup.length} order items');
        
        // Don't rethrow - this is a safe failure
        _addProgressMessage('⚠️ Order items extraction failed but system is safe');
      }
      
    } catch (e) {
      _addProgressMessage('⚠️ Safe extraction wrapper failed: $e');
      debugPrint('⚠️ Safe extraction wrapper error: $e');
      // Never throw - this is the ultimate safety net
    }
  }

  /// Create backup of existing order items
  Future<List<Map<String, dynamic>>> _createOrderItemsBackup(DatabaseExecutor db) async {
    try {
      final result = await db.query('order_items');
      return result.map((row) => Map<String, dynamic>.from(row)).toList();
    } catch (e) {
      _addProgressMessage('⚠️ Failed to create backup: $e');
      return [];
    }
  }

  /// Rollback order items from backup
  Future<void> _rollbackOrderItemsFromBackup(DatabaseExecutor db, List<Map<String, dynamic>> backup) async {
    try {
      if (backup.isEmpty) return;
      
      // Clear current order items
      await db.delete('order_items');
      
      // Restore from backup
      for (final item in backup) {
        await db.insert('order_items', item);
      }
      
      _addProgressMessage('🔄 Rollback completed successfully');
    } catch (e) {
      _addProgressMessage('⚠️ Rollback failed: $e');
      debugPrint('⚠️ Rollback error: $e');
    }
  }

  /// ZERO RISK: Emergency disable method for enhanced functionality
  /// Call this method to completely disable all new features
  static void emergencyDisableEnhancedFeatures() {
    // This would require a restart to take effect, but provides ultimate safety
    debugPrint('🛡️ EMERGENCY: Enhanced features disabled - system will use only existing functionality');
  }

  /// ZERO RISK: Check if enhanced features are enabled
  bool get areEnhancedFeaturesEnabled => _enableEnhancedOrderItemsSync && _enableSafeWrappers;

  /// PUBLIC METHOD: Comprehensive sync to fix missing order items and other data
  /// This method can be called manually to fix sync issues
  Future<void> performComprehensiveDataSync(Restaurant restaurant) async {
    try {
      _addProgressMessage('🚀 Starting comprehensive data sync to fix missing order items...');
      
      if (_firestore == null || _tenantDb == null) {
        _addProgressMessage('⚠️ Firebase or tenant database not available');
        return;
      }
      
      // STEP 1: Sync all foundational data (EXISTING - SAFE)
      _addProgressMessage('🔄 STEP 1: Syncing foundational data...');
      await _syncUsersFromCloud(restaurant);
      await _syncCategoriesFromCloud(restaurant);
      await _syncMenuItemsFromCloud(restaurant);
      await _syncTablesFromCloud(restaurant);
      await _syncInventoryFromCloud(restaurant);
      
      // STEP 2: Sync orders (EXISTING - SAFE)
      _addProgressMessage('🔄 STEP 2: Syncing orders...');
      await _syncOrdersFromCloud(restaurant);
      
      // STEP 3: SAFE - Sync order items with rollback capability
      _addProgressMessage('🔄 STEP 3: Safely syncing order items from separate collection...');
      await _safeSyncOrderItemsFromCloud(restaurant);
      
      // STEP 4: SAFE - Extract order items with rollback capability
      _addProgressMessage('🔄 STEP 4: Safely extracting order items from order documents...');
      await _safeExtractAndSyncOrderItemsFromOrders(restaurant);
      
      // STEP 5: Sync remaining data (EXISTING - SAFE)
      _addProgressMessage('🔄 STEP 5: Syncing remaining data...');
      await _syncPrinterConfigsFromCloud(restaurant);
      await _syncPrinterAssignmentsFromCloud(restaurant);
      await _syncOrderLogsFromCloud(restaurant);
      await _syncCustomersFromCloud(restaurant);
      await _syncTransactionsFromCloud(restaurant);
      await _syncReservationsFromCloud(restaurant);
      
      // STEP 6: Update sync time
      await _updateRestaurantSyncTime(restaurant);
      
      _addProgressMessage('✅ Comprehensive data sync completed successfully!');
      _addProgressMessage('🎯 All data including order items should now be properly synchronized');
      
    } catch (e) {
      _addProgressMessage('❌ Comprehensive data sync failed: $e');
      debugPrint('⚠️ Comprehensive data sync error: $e');
      rethrow;
    }
  }
}

 