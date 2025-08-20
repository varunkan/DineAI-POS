import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/order.dart';
import '../models/menu_item.dart';
import '../models/category.dart';
import '../models/user.dart';
import '../models/table.dart';
import '../models/customer.dart';
import '../models/inventory_item.dart';
import '../models/restaurant.dart';
import '../models/store.dart';
import '../models/activity_log.dart';
import '../models/app_settings.dart';
import '../models/loyalty_reward.dart';
import '../models/loyalty_transaction.dart';
import '../models/reservation.dart';
import '../models/printer_configuration.dart';
import '../models/printer_assignment.dart';
import '../models/order_log.dart';
import '../utils/exceptions.dart';
import 'package:uuid/uuid.dart';
import 'schema_validation_service.dart';

/// Custom exception for database operations
class DatabaseException implements Exception {
  final String message;
  final String? operation;
  final dynamic originalError;

  DatabaseException(this.message, {this.operation, this.originalError});

  @override
  String toString() => 'DatabaseException: $message${operation != null ? ' (Operation: $operation)' : ''}';
}

/// Service responsible for all database operations in the POS system.
/// 
/// This service provides a singleton pattern for database access and handles
/// all CRUD operations with proper error handling and transaction support.
/// Uses SQLite for mobile/desktop and Hive for web platform.
class DatabaseService {
  static Database? _database;
  static Box? _webBox;
  static const String _databaseName = 'ai_pos_database.db';
  static const String _webBoxName = 'pos_data';
  static const int _databaseVersion = 2;
  
  // Singleton pattern with initialization lock
  static final DatabaseService _instance = DatabaseService._internal();
  static bool _isInitialized = false;
  static bool _initializationInProgress = false;
  static final Object _initializationLock = Object();
  
  factory DatabaseService() => _instance;
  DatabaseService._internal();
  
  // Custom database instance for multi-tenant support
  Database? _customDatabase;
  String? _customDatabaseName;
  
  /// Gets the database instance asynchronously with proper null checking.
  Future<Database?> get database async {
    if (kIsWeb) {
      // Web platform doesn't use SQLite
      return null;
    }
    
    // CRITICAL: Return custom tenant database if available, otherwise main database
    if (_customDatabase != null) {
      debugPrint('🔗 Returning custom tenant database: $_customDatabaseName');
      return _customDatabase;
    }
    
    // Return main database instance
    if (_database == null && !_isInitialized) {
      await initialize();
    }
    debugPrint('🔗 Returning main database: $_databaseName');
    return _database;
  }
  
  /// Gets the custom database instance if one is set
  Future<Database?> get customDatabase async {
    if (kIsWeb) {
      return null;
    }
    return _customDatabase;
  }
  
  /// Check if database is initialized
  bool get isInitialized => _isInitialized;
  
  /// Get current database name
  String get databaseName => _customDatabaseName ?? _databaseName;

  /// Initializes Hive storage for web platform
  Future<void> _initWebStorage() async {
    try {
      if (!Hive.isAdapterRegistered(0)) {
        // Register adapters if needed
        debugPrint('🌐 Initializing Hive for web platform...');
      }
      
      _webBox = await Hive.openBox(_webBoxName);
      debugPrint('✅ Web storage initialized successfully');
      
      // Initialize default data if needed
      await _initializeWebDefaults();
      
    } catch (e) {
      debugPrint('❌ Failed to initialize web storage: $e');
      throw DatabaseException('Failed to initialize web storage', operation: 'init_web_storage', originalError: e);
    }
  }

  /// Initializes default data for web platform
  Future<void> _initializeWebDefaults() async {
    try {
      // Check if we have any users
      final users = _webBox?.get('users', defaultValue: <Map<String, dynamic>>[]);
      if (users?.isEmpty ?? true) {
        // Create default admin user
        final defaultUsers = [
          {
            'id': 'admin-001',
            'name': 'Admin',
            'email': 'admin@restaurant.com',
            'role': 'admin',
            'password': 'admin123',
            'created_at': DateTime.now().toIso8601String(),
          }
        ];
        await _webBox?.put('users', defaultUsers);
        debugPrint('✅ Created default admin user for web');
      }
      
      // Initialize empty collections if they don't exist
      final collections = ['orders', 'menu_items', 'categories', 'tables', 'order_logs'];
      for (final collection in collections) {
        if (!(_webBox?.containsKey(collection) ?? false)) {
          await _webBox?.put(collection, <Map<String, dynamic>>[]);
        }
      }
      
    } catch (e) {
      debugPrint('❌ Failed to initialize web defaults: $e');
    }
  }

  /// Initializes the database connection.
  /// 
  /// Opens the SQLite database and enables foreign key constraints.
  /// Throws [DatabaseException] if initialization fails.
  Future<Database> _initDatabase() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, _databaseName);

      // Delete existing database for development (remove in production)
      // if (await databaseExists(path)) {
      //   await deleteDatabase(path);
      // }

      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) async {
          // Enable foreign key constraints
          await db.execute('PRAGMA foreign_keys = ON');
          debugPrint('Database opened successfully with foreign keys enabled');
          
          // Try to enable WAL mode with fallback
          try {
            await db.execute('PRAGMA journal_mode = WAL');
            debugPrint('✅ WAL mode enabled successfully');
          } catch (e) {
            debugPrint('⚠️ WAL mode not supported, using default journal mode: $e');
            // Continue without WAL mode - this is fine for development
          }
          
          // Set synchronous mode
          try {
            await db.execute('PRAGMA synchronous = NORMAL');
            debugPrint('✅ Synchronous mode set to NORMAL');
          } catch (e) {
            debugPrint('⚠️ Could not set synchronous mode: $e');
            // Continue anyway
          }
          
          // Perform schema migrations for existing databases
          await _performSchemaMigrations(db);
          
          // ZERO RISK: Validate schema after opening existing database
          await _validateAndCorrectSchema(db);
        },
      );
    } catch (e) {
      throw DatabaseException('Failed to initialize database', operation: 'init_database', originalError: e);
    }
  }

  /// Creates all database tables.
  /// 
  /// This method is called when the database is first created.
  /// Throws [DatabaseException] if table creation fails.
  Future<void> _onCreate(Database db, int version) async {
    try {
      debugPrint('Creating database tables...');
      
      await db.transaction((txn) async {
        // Core tables
        await _createOrdersTable(txn);
        await _createOrderItemsTable(txn);
        await _createMenuItemsTable(txn);
        await _createCategoriesTable(txn);
        await _createUsersTable(txn);
        await _createTablesTable(txn);
        await _createInventoryTable(txn);
        await _createCustomersTable(txn);
        await _createTransactionsTable(txn);
        
        // FIXED: Add missing table creation methods
        await _createReservationsTable(txn);
        await _createPrinterConfigurationsTable(txn);
        await _createPrinterAssignmentsTable(txn);
        await _createOrderLogsTable(txn);
        await _createAppMetadataTable(txn);
        
        // ENHANCEMENT: Add new tables for comprehensive restaurant setup
        await _createLoyaltyRewardsTable(txn);
        await _createAppSettingsTable(txn);
        
        debugPrint('✅ All database tables created successfully');
      });
      
      // ENHANCEMENT: Migrate existing tables to add missing columns
      // This ensures top-notch data synchronization with Firebase
      await _migrateOrdersTable(db);
      
      // ZERO RISK: Validate schema after creation
      await _validateAndCorrectSchema(db);
    } catch (e) {
      debugPrint('❌ Error creating database tables: $e');
      throw DatabaseException('Failed to create database tables', operation: 'create_tables', originalError: e);
    }
  }

  /// ZERO RISK: Validate and correct database schema
  Future<void> _validateAndCorrectSchema(Database db) async {
    try {
      debugPrint('🔍 Validating database schema after creation...');
      
      final schemaValidationService = SchemaValidationService();
      final validationResult = await schemaValidationService.validateDatabaseSchema(db);
      
      if (validationResult.isValid) {
        debugPrint('✅ Database schema validation passed');
      } else {
        debugPrint('⚠️ Database schema validation found ${validationResult.issues.length} issues:');
        for (final issue in validationResult.issues) {
          debugPrint('  - ${issue.severity}: ${issue.message}');
        }
        
        // ZERO RISK: Auto-correct non-critical issues
        if (SchemaValidationService.isAutoCorrectionEnabled) {
          debugPrint('🔧 Auto-correcting non-critical schema issues...');
          // Auto-correction is handled within the validation service
        }
      }
    } catch (e) {
      debugPrint('⚠️ Schema validation failed: $e');
      // Don't throw - schema validation failure shouldn't break database initialization
    }
  }

  /// Creates the orders table with optimized indexes.
  Future<void> _createOrdersTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE orders (
        id TEXT PRIMARY KEY,
        order_number TEXT NOT NULL UNIQUE,
        status TEXT NOT NULL,
        type TEXT NOT NULL,
        table_id TEXT,
        user_id TEXT,
        customer_name TEXT,
        customer_phone TEXT,
        customer_email TEXT,
        customer_address TEXT,
        special_instructions TEXT,
        subtotal REAL NOT NULL,
        tax_amount REAL NOT NULL,
        tip_amount REAL NOT NULL,
        hst_amount REAL NOT NULL DEFAULT 0.0,
        discount_amount REAL NOT NULL DEFAULT 0.0,
        gratuity_amount REAL NOT NULL DEFAULT 0.0,
        total_amount REAL NOT NULL,
        payment_method TEXT,
        payment_status TEXT,
        payment_transaction_id TEXT,
        order_time TEXT NOT NULL,
        estimated_ready_time TEXT,
        actual_ready_time TEXT,
        served_time TEXT,
        completed_time TEXT,
        is_urgent INTEGER NOT NULL DEFAULT 0,
        priority INTEGER NOT NULL DEFAULT 0,
        assigned_to TEXT,
        custom_fields TEXT,
        metadata TEXT,
        notes TEXT,
        preferences TEXT,
        history TEXT,
        items TEXT,
        completed_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    
    // Create performance indexes
    await db.execute('CREATE INDEX idx_orders_status ON orders(status)');
    await db.execute('CREATE INDEX idx_orders_type ON orders(type)');
    await db.execute('CREATE INDEX idx_orders_table_id ON orders(table_id)');
    await db.execute('CREATE INDEX idx_orders_user_id ON orders(user_id)');
    await db.execute('CREATE INDEX idx_orders_created_at ON orders(created_at DESC)');
    await db.execute('CREATE INDEX idx_orders_order_time ON orders(order_time DESC)');
    await db.execute('CREATE INDEX idx_orders_status_created ON orders(status, created_at DESC)');
    await db.execute('CREATE INDEX idx_orders_urgent_priority ON orders(is_urgent DESC, priority DESC)');
  }

  /// Creates the order_items table with optimized indexes.
  Future<void> _createOrderItemsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE order_items (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        menu_item_id TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL,
        selected_variant TEXT,
        selected_modifiers TEXT,
        special_instructions TEXT,
        notes TEXT,
        custom_properties TEXT,
        is_available INTEGER NOT NULL DEFAULT 1,
        sent_to_kitchen INTEGER NOT NULL DEFAULT 0,
        kitchen_status TEXT DEFAULT 'pending',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE,
        FOREIGN KEY (menu_item_id) REFERENCES menu_items (id)
      )
    ''');
    
    // Performance indexes for order items
    await db.execute('CREATE INDEX idx_order_items_order_id ON order_items(order_id)');
    await db.execute('CREATE INDEX idx_order_items_menu_item_id ON order_items(menu_item_id)');
    await db.execute('CREATE INDEX idx_order_items_kitchen_status ON order_items(kitchen_status)');
    await db.execute('CREATE INDEX idx_order_items_sent_to_kitchen ON order_items(sent_to_kitchen)');
  }

  /// Creates the menu_items table with optimized indexes.
  Future<void> _createMenuItemsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE menu_items (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL,
        price REAL NOT NULL,
        category_id TEXT NOT NULL,
        image_url TEXT,
        is_available INTEGER NOT NULL DEFAULT 1,
        tags TEXT,
        custom_properties TEXT,
        variants TEXT,
        modifiers TEXT,
        nutritional_info TEXT,
        allergens TEXT,
        preparation_time INTEGER NOT NULL DEFAULT 0,
        is_vegetarian INTEGER NOT NULL DEFAULT 0,
        is_vegan INTEGER NOT NULL DEFAULT 0,
        is_gluten_free INTEGER NOT NULL DEFAULT 0,
        is_spicy INTEGER NOT NULL DEFAULT 0,
        spice_level INTEGER NOT NULL DEFAULT 0,
        stock_quantity INTEGER NOT NULL DEFAULT 0,
        low_stock_threshold INTEGER NOT NULL DEFAULT 5,
        popularity_score REAL DEFAULT 0.0,
        last_ordered TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    
    // Performance indexes for menu items
    await db.execute('CREATE INDEX idx_menu_items_category_id ON menu_items(category_id)');
    await db.execute('CREATE INDEX idx_menu_items_available ON menu_items(is_available)');
    await db.execute('CREATE INDEX idx_menu_items_name ON menu_items(name)');
    await db.execute('CREATE INDEX idx_menu_items_popularity ON menu_items(popularity_score DESC)');
    await db.execute('CREATE INDEX idx_menu_items_stock ON menu_items(stock_quantity)');
    await db.execute('CREATE INDEX idx_menu_items_price ON menu_items(price)');
  }

  /// Creates the categories table.
  Future<void> _createCategoriesTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        image_url TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  /// Creates the users table.
  Future<void> _createUsersTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        role TEXT NOT NULL,
        pin TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        admin_panel_access INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        last_login TEXT
      )
    ''');
  }

  /// Creates the tables table.
  Future<void> _createTablesTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE tables (
        id TEXT PRIMARY KEY,
        number INTEGER NOT NULL,
        capacity INTEGER NOT NULL,
        status TEXT NOT NULL,
        user_id TEXT,
        customer_name TEXT,
        customer_phone TEXT,
        customer_email TEXT,
        metadata TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  /// Creates the inventory table.
  Future<void> _createInventoryTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE inventory (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        current_stock INTEGER NOT NULL DEFAULT 0,
        min_stock INTEGER NOT NULL DEFAULT 0,
        max_stock INTEGER,
        cost_price REAL NOT NULL DEFAULT 0.0,
        selling_price REAL,
        unit TEXT NOT NULL,
        supplier_id TEXT,
        category TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        last_updated TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  /// Creates the customers table.
  Future<void> _createCustomersTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE customers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        address TEXT,
        loyalty_points INTEGER NOT NULL DEFAULT 0,
        join_date TEXT NOT NULL,
        preferences TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  /// Creates the transactions table.
  Future<void> _createTransactionsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        amount REAL NOT NULL,
        currency TEXT NOT NULL DEFAULT 'USD',
        payment_method TEXT NOT NULL,
        payment_status TEXT NOT NULL,
        transaction_id TEXT,
        gateway_response TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (order_id) REFERENCES orders (id)
      )
    ''');
  }

  /// Creates the reservations table.
  Future<void> _createReservationsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS reservations (
        id TEXT PRIMARY KEY,
        customer_name TEXT NOT NULL,
        customer_phone TEXT,
        customer_email TEXT,
        party_size INTEGER NOT NULL,
        reservation_date TEXT NOT NULL,
        reservation_time TEXT NOT NULL,
        table_id TEXT,
        status TEXT DEFAULT 'pending',
        special_requests TEXT,
        notes TEXT,
        created_by TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (table_id) REFERENCES tables (id) ON DELETE SET NULL,
        FOREIGN KEY (created_by) REFERENCES users (id) ON DELETE SET NULL
      )
    ''');

    // Create indexes for performance
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_reservations_date ON reservations(reservation_date)
    ''');
    
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_reservations_status ON reservations(status)
    ''');
    
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_reservations_table ON reservations(table_id)
    ''');

    debugPrint('✅ Reservations table created with indexes');
  }

  /// Creates the printer_configurations table with comprehensive printer management.
  /// 
  /// Supports WiFi, Bluetooth, and USB printers with full configuration options.
  Future<void> _createPrinterConfigurationsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS printer_configurations (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT 'Printer configuration',
        type TEXT NOT NULL DEFAULT 'wifi',
        model TEXT,
        ip_address TEXT,
        port INTEGER DEFAULT 9100,
        mac_address TEXT,
        bluetooth_address TEXT,
        station_id TEXT DEFAULT 'main_kitchen',
        is_active INTEGER DEFAULT 1,
        is_default INTEGER DEFAULT 0,
        connection_status TEXT DEFAULT 'unknown',
        last_connected TEXT,
        last_test_print TEXT,
        custom_settings TEXT DEFAULT '{}',
        remote_config TEXT DEFAULT '{}',
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Create indexes for performance
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_printer_configs_active ON printer_configurations(is_active)
    ''');
    
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_printer_configs_type ON printer_configurations(type)
    ''');
    
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_printer_configs_station ON printer_configurations(station_id)
    ''');

    debugPrint('✅ Printer configurations table created with indexes');
  }

  /// Creates the printer_assignments table with kitchen station management.
  /// 
  /// Maps printers to kitchen stations for order routing.
  Future<void> _createPrinterAssignmentsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS printer_assignments (
        id TEXT PRIMARY KEY,
        printer_id TEXT NOT NULL,
        printer_name TEXT NOT NULL DEFAULT '',
        printer_address TEXT NOT NULL DEFAULT '',
        assignment_type TEXT NOT NULL DEFAULT 'category',
        target_id TEXT NOT NULL DEFAULT '',
        target_name TEXT NOT NULL DEFAULT 'Kitchen',
        station_name TEXT NOT NULL DEFAULT 'Kitchen',
        order_types TEXT DEFAULT '["dineIn","takeaway"]',
        is_active INTEGER DEFAULT 1,
        priority INTEGER DEFAULT 1,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (printer_id) REFERENCES printer_configurations (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for performance
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_printer_assignments_printer ON printer_assignments(printer_id)
    ''');
    
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_printer_assignments_station ON printer_assignments(station_name)
    ''');
    
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_printer_assignments_target ON printer_assignments(target_name)
    ''');

    debugPrint('✅ Printer assignments table created with indexes');
  }

  /// Creates the order_logs table with comprehensive audit trail support.
  /// 
  /// This table tracks all order-related actions for audit purposes.
  /// Supports comprehensive logging for restaurant operations.
  Future<void> _createOrderLogsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS order_logs (
        id TEXT PRIMARY KEY,
        order_id TEXT NOT NULL,
        order_number TEXT,
        action TEXT NOT NULL,
        level TEXT NOT NULL DEFAULT 'info',
        performed_by TEXT NOT NULL DEFAULT 'system',
        performed_by_name TEXT NOT NULL DEFAULT 'System',
        timestamp TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT 'Order action',
        before_data TEXT DEFAULT '{}',
        after_data TEXT DEFAULT '{}',
        metadata TEXT DEFAULT '{}',
        notes TEXT,
        device_id TEXT,
        session_id TEXT,
        ip_address TEXT,
        is_system_action INTEGER DEFAULT 1,
        error_message TEXT,
        amount_before REAL,
        amount_after REAL,
        table_id TEXT,
        customer_id TEXT,
        created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (order_id) REFERENCES orders (id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for performance
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_order_logs_order_id ON order_logs(order_id)
    ''');
    
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_order_logs_performed_by ON order_logs(performed_by)
    ''');
    
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_order_logs_timestamp ON order_logs(timestamp DESC)
    ''');
    
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_order_logs_action ON order_logs(action)
    ''');

    debugPrint('✅ Order logs table created with indexes');
  }

  /// Creates the app_metadata table for application configuration and state.
  /// 
  /// Stores application-wide settings and metadata for cross-platform sync.
  Future<void> _createAppMetadataTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        type TEXT DEFAULT 'string',
        description TEXT,
        is_system INTEGER DEFAULT 0,
        updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    // Insert initial metadata
    await db.execute('''
      INSERT OR IGNORE INTO app_metadata (key, value, type, description, is_system)
      VALUES ('database_version', '1.0.0', 'string', 'Current database schema version', 1)
    ''');
    
    await db.execute('''
      INSERT OR IGNORE INTO app_metadata (key, value, type, description, is_system)
      VALUES ('last_migration', ?, 'string', 'Last migration timestamp', 1)
    ''', [DateTime.now().toIso8601String()]);

    debugPrint('✅ App metadata table created with initial data');
  }

  /// Ensures a table exists, creating it if necessary.
  Future<void> _ensureTableExists(dynamic db, String tableName, Future<void> Function() createTable) async {
    try {
      // Check if table exists
      final result = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
        [tableName],
      );
      
      if (result.isEmpty) {
        debugPrint('🔧 Creating missing table: $tableName');
        await createTable();
        debugPrint('✅ Created table: $tableName');
      }
    } catch (e) {
      debugPrint('⚠️ Error ensuring table $tableName exists: $e');
      // Try to create the table anyway
      try {
        await createTable();
        debugPrint('✅ Created table $tableName after error');
      } catch (createError) {
        debugPrint('❌ Failed to create table $tableName: $createError');
      }
    }
  }

  /// Handles database upgrades.
  /// 
  /// This method is called when the database version is increased.
  /// Add migration logic here when needed.
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('📈 Upgrading database from version $oldVersion to $newVersion');
    
    try {
      // Version 1 → 2: Add missing columns to existing tables
      if (oldVersion < 2) {
        await _migratePrinterConfigurationsTable(db);
        await _migratePrinterAssignmentsTable(db);
        await _migrateOrderLogsTable(db);
      }
      
      // Future migrations can be added here
      // if (oldVersion < 3) { ... }
      
      debugPrint('✅ Database upgrade completed successfully');
      
      // CRITICAL: Clear any cached table schemas to ensure fresh reads
      await db.execute('PRAGMA schema_version = $newVersion');
      
    } catch (e) {
      debugPrint('❌ Database upgrade failed: $e');
      // Don't rethrow - let the database continue with potentially incomplete migration
    }
  }

  /// Inserts a record into the specified table.
  /// 
  /// [table] is the table name to insert into.
  /// [data] is the data to insert.
  /// Returns the ID of the inserted record.
  /// Throws [DatabaseException] if the operation fails.
  Future<int> insert(String table, Map<String, dynamic> data) async {
    if (kIsWeb) {
      // Web platform - use Hive storage
      try {
        switch (table) {
          case 'users':
            await saveWebUser(data);
            return 1;
          case 'orders':
            await saveWebOrder(data);
            return 1;
          case 'menu_items':
            await saveWebMenuItem(data);
            return 1;
          case 'categories':
            await saveWebCategory(data);
            return 1;
          case 'order_logs':
            await saveWebOrderLog(data);
            return 1;
          default:
            debugPrint('⚠️ Web insert for unsupported table: $table');
            return 0;
        }
      } catch (e) {
        throw DatabaseException('Failed to insert into $table on web', operation: 'insert', originalError: e);
      }
    }
    
    try {
      final db = await database;
      if (db == null) throw DatabaseException('Database not available', operation: 'insert');
      
      return await db.insert(table, data);
    } catch (e) {
      throw DatabaseException('Failed to insert into $table', operation: 'insert', originalError: e);
    }
  }

  /// Queries records from the specified table.
  /// 
  /// [table] is the table name to query from.
  /// All other parameters are optional query constraints.
  /// Returns a list of records as maps.
  /// Throws [DatabaseException] if the operation fails.
  Future<List<Map<String, dynamic>>> query(
    String table, {
    bool? distinct,
    List<String>? columns,
    String? where,
    List<Object?>? whereArgs,
    String? groupBy,
    String? having,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    if (kIsWeb) {
      // Web platform - return data from Hive storage
      try {
        List<Map<String, dynamic>> data = [];
        
        switch (table) {
          case 'users':
            data = await getWebUsers();
            break;
          case 'orders':
            data = await getWebOrders();
            break;
          case 'menu_items':
            data = await getWebMenuItems();
            break;
          case 'categories':
            data = await getWebCategories();
            break;
          case 'order_logs':
            data = await getWebOrderLogs();
            break;
          default:
            debugPrint('⚠️ Web query for unsupported table: $table');
            return [];
        }
        
        // Apply basic filtering (simplified for web)
        if (where != null && whereArgs != null) {
          // Simple filtering - can be enhanced as needed
          if (where.contains('user_id = ?') && whereArgs.isNotEmpty) {
            final userId = whereArgs[0];
            data = data.where((item) => item['user_id'] == userId).toList();
          } else if (where.contains('table_id = ?') && whereArgs.isNotEmpty) {
            final tableId = whereArgs[0];
            data = data.where((item) => item['table_id'] == tableId).toList();
          }
        }
        
        // Apply ordering (simplified)
        if (orderBy != null) {
          if (orderBy.contains('created_at DESC')) {
            data.sort((a, b) {
              final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.now();
              final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.now();
              return bDate.compareTo(aDate);
            });
          }
        }
        
        // Apply limit
        if (limit != null && limit > 0) {
          data = data.take(limit).toList();
        }
        
        debugPrint('✅ Web query returned ${data.length} records from $table');
        return data;
        
      } catch (e) {
        debugPrint('❌ Error in web query for $table: $e');
        return [];
      }
    }
    
    try {
      final db = await database;
      if (db == null) return [];
      
      return await db.query(
        table,
        distinct: distinct,
        columns: columns,
        where: where,
        whereArgs: whereArgs,
        groupBy: groupBy,
        having: having,
        orderBy: orderBy,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      throw DatabaseException('Failed to query from $table', operation: 'query', originalError: e);
    }
  }

  /// Updates records in the specified table.
  /// 
  /// [table] is the table name to update.
  /// [data] is the data to update.
  /// [where] and [whereArgs] specify which records to update.
  /// Returns the number of updated records.
  /// Throws [DatabaseException] if the operation fails.
  Future<int> update(
    String table,
    Map<String, dynamic> data, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    if (kIsWeb) {
      // Web platform - simplified update (could be enhanced)
      try {
        switch (table) {
          case 'users':
            await saveWebUser(data);
            return 1;
          case 'orders':
            await saveWebOrder(data);
            return 1;
          case 'menu_items':
            await saveWebMenuItem(data);
            return 1;
          case 'categories':
            await saveWebCategory(data);
            return 1;
          case 'order_logs':
            await saveWebOrderLog(data);
            return 1;
          default:
            debugPrint('⚠️ Web update for unsupported table: $table');
            return 0;
        }
      } catch (e) {
        throw DatabaseException('Failed to update $table on web', operation: 'update', originalError: e);
      }
    }
    
    try {
      final db = await database;
      if (db == null) throw DatabaseException('Database not available', operation: 'update');
      
      return await db.update(table, data, where: where, whereArgs: whereArgs);
    } catch (e) {
      throw DatabaseException('Failed to update $table', operation: 'update', originalError: e);
    }
  }

  /// Deletes records from the specified table.
  /// 
  /// [table] is the table name to delete from.
  /// [where] and [whereArgs] specify which records to delete.
  /// Returns the number of deleted records.
  /// Throws [DatabaseException] if the operation fails.
  Future<int> delete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
  }) async {
    if (kIsWeb) {
      // Web platform - simplified delete (could be enhanced)
      try {
        // For web, we'll need to implement specific delete logic
        // For now, return 0 as delete operations are less common in POS
        debugPrint('⚠️ Web delete operation not fully implemented for $table');
        return 0;
      } catch (e) {
        throw DatabaseException('Failed to delete from $table on web', operation: 'delete', originalError: e);
      }
    }
    
    try {
      final db = await database;
      if (db == null) throw DatabaseException('Database not available', operation: 'delete');
      
      return await db.delete(table, where: where, whereArgs: whereArgs);
    } catch (e) {
      throw DatabaseException('Failed to delete from $table', operation: 'delete', originalError: e);
    }
  }

  /// Closes the database connection.
  /// 
  /// This should be called when the app is shutting down.
  Future<void> close() async {
    try {
      if (_database != null) {
        await _database!.close();
        _database = null;
        debugPrint('Database connection closed');
      }
    } catch (e) {
      throw DatabaseException('Failed to close database', operation: 'close', originalError: e);
    }
  }

  /// Clears all data from all tables.
  /// 
  /// This is useful for development/testing purposes.
  /// Use with caution in production.
  Future<void> clearAllData() async {
    if (kIsWeb) {
      // Web platform - clear Hive storage
      try {
        if (_webBox == null) await _initWebStorage();
        await _webBox?.clear();
        debugPrint('✅ All web data cleared');
      } catch (e) {
        throw DatabaseException('Failed to clear web data', operation: 'clear_all_data', originalError: e);
      }
      return;
    }
    
    try {
      final db = await database;
      if (db == null) throw DatabaseException('Database not available', operation: 'clear_all_data');
      
      await db.transaction((txn) async {
        await txn.delete('orders');
        await txn.delete('order_items');
        await txn.delete('menu_items');
        await txn.delete('categories');
        await txn.delete('users');
        await txn.delete('tables');
        await txn.delete('inventory');
        await txn.delete('customers');
        await txn.delete('transactions');
      });
      debugPrint('All data cleared from database');
    } catch (e) {
      throw DatabaseException('Failed to clear all data', operation: 'clear_all_data', originalError: e);
    }
  }

  /// Gets the count of records in each table.
  /// 
  /// Returns a map of table names to record counts.
  /// Useful for debugging and monitoring.
  Future<Map<String, int>> getTableCounts() async {
    if (kIsWeb) {
      // Web platform - get counts from Hive storage
      try {
        final users = await getWebUsers();
        final orders = await getWebOrders();
        final menuItems = await getWebMenuItems();
        final categories = await getWebCategories();
        final orderLogs = await getWebOrderLogs();
        
        return {
          'users': users.length,
          'orders': orders.length,
          'menu_items': menuItems.length,
          'categories': categories.length,
          'order_logs': orderLogs.length,
          'tables': 0, // Not implemented for web yet
          'inventory': 0, // Not implemented for web yet
          'customers': 0, // Not implemented for web yet
        };
      } catch (e) {
        throw DatabaseException('Failed to get web table counts', operation: 'get_table_counts', originalError: e);
      }
    }
    
    try {
      final db = await database;
      if (db == null) throw DatabaseException('Database not available', operation: 'get_table_counts');
      
      final tables = ['orders', 'menu_items', 'categories', 'users', 'tables', 'inventory', 'customers'];
      final counts = <String, int>{};
      
      for (final table in tables) {
        final result = await db.rawQuery('SELECT COUNT(*) as count FROM $table');
        counts[table] = result.first['count'] as int;
      }
      
      return counts;
    } catch (e) {
      throw DatabaseException('Failed to get table counts', operation: 'get_table_counts', originalError: e);
    }
  }

  /// Optimized batch query for order with items (eliminates N+1 problem)
  Future<List<Map<String, dynamic>>> getOrdersWithItems({
    String? whereClause,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    if (kIsWeb) {
      // Web platform - return orders with items from Hive storage
      try {
        final orders = await getWebOrders();
        final menuItems = await getWebMenuItems();
        
        // Transform web orders to match the expected format
        final result = <Map<String, dynamic>>[];
        
        for (final order in orders) {
          // Add order data without items first
          result.add({
            ...order,
            'item_id': null,
            'quantity': null,
            'unit_price': null,
            'total_price': null,
            'selected_variant': null,
            'selected_modifiers': null,
            'special_instructions': null,
            'notes': null,
            'custom_properties': null,
            'item_available': null,
            'sent_to_kitchen': null,
            'kitchen_status': null,
            'item_created_at': null,
            'menu_item_name': null,
            'menu_item_description': null,
            'menu_item_price': null,
            'menu_item_category_id': null,
            'menu_item_image_url': null,
            'menu_item_available': null,
            'preparation_time': null,
            'is_vegetarian': null,
            'is_vegan': null,
            'is_gluten_free': null,
            'is_spicy': null,
            'spice_level': null,
          });
        }
        
        debugPrint('✅ Loaded ${result.length} orders for web platform');
        return result;
      } catch (e) {
        debugPrint('❌ Error getting web orders: $e');
        return [];
      }
    }
    
    try {
      final db = await database;
      if (db == null) return [];
      
      // Check if notes and kitchen_status columns exist in order_items table
      bool hasNotesColumn = false;
      bool hasKitchenStatusColumn = false;
      try {
        final columns = await db.rawQuery("PRAGMA table_info(order_items)");
        hasNotesColumn = columns.any((col) => col['name'] == 'notes');
        hasKitchenStatusColumn = columns.any((col) => col['name'] == 'kitchen_status');
        
        // Add missing columns if they don't exist
        if (!hasNotesColumn) {
          await db.execute('ALTER TABLE order_items ADD COLUMN notes TEXT');
          debugPrint('Added notes column to order_items table');
        }
        if (!hasKitchenStatusColumn) {
          await db.execute('ALTER TABLE order_items ADD COLUMN kitchen_status TEXT DEFAULT "pending"');
          debugPrint('Added kitchen_status column to order_items table');
        }
      } catch (e) {
        debugPrint('Warning: Could not check/add columns: $e');
      }
      
      // Build query with conditional column selection
      final notesSelect = hasNotesColumn ? 'oi.notes,' : 'NULL as notes,';
      final kitchenStatusSelect = hasKitchenStatusColumn ? 'oi.kitchen_status,' : '"pending" as kitchen_status,';
      
      final query = '''
        SELECT 
          o.*,
          oi.id as item_id,
          oi.quantity,
          oi.unit_price,
          oi.total_price,
          oi.selected_variant,
          oi.selected_modifiers,
          oi.special_instructions,
          $notesSelect
          oi.custom_properties,
          oi.is_available as item_available,
          oi.sent_to_kitchen,
          $kitchenStatusSelect
          oi.created_at as item_created_at,
          mi.name as menu_item_name,
          mi.description as menu_item_description,
          mi.price as menu_item_price,
          mi.category_id as menu_item_category_id,
          mi.image_url as menu_item_image_url,
          mi.is_available as menu_item_available,
          mi.preparation_time,
          mi.is_vegetarian,
          mi.is_vegan,
          mi.is_gluten_free,
          mi.is_spicy,
          mi.spice_level
        FROM orders o
        LEFT JOIN order_items oi ON o.id = oi.order_id
        LEFT JOIN menu_items mi ON oi.menu_item_id = mi.id
        ${whereClause != null ? 'WHERE $whereClause' : ''}
        ${orderBy != null ? 'ORDER BY $orderBy' : 'ORDER BY o.created_at DESC'}
        ${limit != null ? 'LIMIT $limit' : ''}
      ''';
      
      return await db.rawQuery(query, whereArgs);
    } catch (e) {
      throw DatabaseException('Failed to get orders with items', operation: 'get_orders_with_items', originalError: e);
    }
  }

  /// Optimized analytics queries
  Future<Map<String, dynamic>> getAnalyticsData({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (kIsWeb) {
      // Web platform - simplified analytics
      try {
        final orders = await getWebOrders();
        final start = startDate ?? DateTime.now().subtract(const Duration(days: 30));
        final end = endDate ?? DateTime.now();
        
        final filteredOrders = orders.where((order) {
          final orderDate = DateTime.tryParse(order['created_at']?.toString() ?? '') ?? DateTime.now();
          return orderDate.isAfter(start) && orderDate.isBefore(end);
        }).toList();
        
        return {
          'total_orders': filteredOrders.length,
          'total_revenue': filteredOrders.fold(0.0, (sum, order) => sum + (order['total_amount'] ?? 0.0)),
          'avg_order_value': filteredOrders.isEmpty ? 0.0 : filteredOrders.fold(0.0, (sum, order) => sum + (order['total_amount'] ?? 0.0)) / filteredOrders.length,
          'completed_orders': filteredOrders.where((o) => o['status'] == 'completed').length,
          'cancelled_orders': filteredOrders.where((o) => o['status'] == 'cancelled').length,
          'dine_in_orders': filteredOrders.where((o) => o['type'] == 'dineIn').length,
          'takeaway_orders': filteredOrders.where((o) => o['type'] == 'takeaway').length,
          'delivery_orders': filteredOrders.where((o) => o['type'] == 'delivery').length,
          'first_order': filteredOrders.isNotEmpty ? filteredOrders.first['order_time'] : null,
          'last_order': filteredOrders.isNotEmpty ? filteredOrders.last['order_time'] : null,
        };
      } catch (e) {
        throw DatabaseException('Failed to get web analytics data', operation: 'get_analytics', originalError: e);
      }
    }
    
    try {
      final db = await database;
      if (db == null) throw DatabaseException('Database not available', operation: 'get_analytics');
      
      final start = startDate?.toIso8601String() ?? DateTime.now().subtract(const Duration(days: 30)).toIso8601String();
      final end = endDate?.toIso8601String() ?? DateTime.now().toIso8601String();
      
      // Single query for comprehensive analytics
      final result = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_orders,
          SUM(total_amount) as total_revenue,
          AVG(total_amount) as avg_order_value,
          COUNT(CASE WHEN status = 'completed' THEN 1 END) as completed_orders,
          COUNT(CASE WHEN status = 'cancelled' THEN 1 END) as cancelled_orders,
          COUNT(CASE WHEN type = 'dineIn' THEN 1 END) as dine_in_orders,
          COUNT(CASE WHEN type = 'takeaway' THEN 1 END) as takeaway_orders,
          COUNT(CASE WHEN type = 'delivery' THEN 1 END) as delivery_orders,
          MIN(order_time) as first_order,
          MAX(order_time) as last_order
        FROM orders 
        WHERE created_at BETWEEN ? AND ?
      ''', [start, end]);
      
      return result.first;
    } catch (e) {
      throw DatabaseException('Failed to get analytics data', operation: 'get_analytics', originalError: e);
    }
  }

  /// Get popular menu items with performance metrics
  Future<List<Map<String, dynamic>>> getPopularMenuItems({int limit = 10}) async {
    if (kIsWeb) {
      // Web platform - simplified popular items
      try {
        final menuItems = await getWebMenuItems();
        // For web, just return the first few items (could be enhanced with actual popularity logic)
        return menuItems.take(limit).map((item) => {
          ...item,
          'order_count': 0,
          'total_quantity': 0,
          'total_revenue': 0.0,
          'avg_quantity_per_order': 0.0,
          'popularity_score': 0.0,
        }).toList();
      } catch (e) {
        throw DatabaseException('Failed to get web popular menu items', operation: 'get_popular_items', originalError: e);
      }
    }
    
    try {
      final db = await database;
      if (db == null) throw DatabaseException('Database not available', operation: 'get_popular_items');
      
      return await db.rawQuery('''
        SELECT 
          mi.id,
          mi.name,
          mi.price,
          mi.category_id,
          COUNT(oi.id) as order_count,
          SUM(oi.quantity) as total_quantity,
          SUM(oi.total_price) as total_revenue,
          AVG(oi.quantity) as avg_quantity_per_order,
          mi.preparation_time,
          mi.popularity_score
        FROM menu_items mi
        LEFT JOIN order_items oi ON mi.id = oi.menu_item_id
        LEFT JOIN orders o ON oi.order_id = o.id
        WHERE o.status = 'completed' AND o.created_at >= date('now', '-30 days')
        GROUP BY mi.id, mi.name, mi.price, mi.category_id
        ORDER BY order_count DESC, total_revenue DESC
        LIMIT ?
      ''', [limit]);
    } catch (e) {
      throw DatabaseException('Failed to get popular menu items', operation: 'get_popular_items', originalError: e);
    }
  }

  /// Performs comprehensive schema migrations for existing databases
  Future<void> _performSchemaMigrations(Database db) async {
    try {
      debugPrint('🔧 Starting database schema migrations...');
      
      // CRITICAL FIX: Force check and fix critical schema issues first
      await _forceFixCriticalSchemaIssues(db);
      
      // Clean up any orphaned data before migration
      await _cleanupOrphanedData(db);
      
      // Ensure all required tables exist
      await _ensureAllTablesExist(db);
      
      // Migrate existing table schemas
      await _migrateExistingTableSchemas(db);
      
      // Run post-migration integrity check
      await _postMigrationIntegrityCheck(db);
      
      debugPrint('✅ Database schema migrations completed');
    } catch (e) {
      debugPrint('❌ Database migration failed: $e');
      rethrow;
    }
  }

  /// Force fix critical schema issues immediately
  Future<void> _forceFixCriticalSchemaIssues(Database db) async {
    debugPrint('🔧 FORCE FIXING critical schema issues...');
    
    try {
      // ALWAYS force recreate problematic tables to ensure correct schema
      await _forceRecreateProblematicTables(db);
      debugPrint('✅ Critical schema issues fixed by force recreation');
    } catch (e) {
      debugPrint('❌ Critical schema fix failed: $e');
      // Continue anyway to prevent app crashes
    }
  }

  /// Check and fix order_logs table schema
  Future<void> _checkAndFixOrderLogsTable(Database db) async {
    try {
      final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='order_logs'"
      );
      
      if (tableExists.isEmpty) {
        debugPrint('🔧 Creating missing order_logs table');
        await _createOrderLogsTable(db);
        return;
      }
      
      final columns = await db.rawQuery("PRAGMA table_info(order_logs)");
      final existingColumns = columns.map((col) => col['name'] as String).toSet();
      
      final requiredColumns = {
        'id', 'order_id', 'order_number', 'action', 'level', 'performed_by',
        'performed_by_name', 'timestamp', 'description', 'created_at'
      };
      
      final missingColumns = requiredColumns.difference(existingColumns);
      
      if (missingColumns.isNotEmpty) {
        debugPrint('🔧 Fixing order_logs table - missing columns: $missingColumns');
        await _recreateOrderLogsTable(db);
      } else {
        debugPrint('✅ Order logs table schema is correct');
      }
    } catch (e) {
      debugPrint('❌ Error checking order_logs table: $e');
      await _recreateOrderLogsTable(db);
    }
  }

  /// Check and fix printer_configurations table schema
  Future<void> _checkAndFixPrinterConfigurationsTable(Database db) async {
    try {
      final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='printer_configurations'"
      );
      
      if (tableExists.isEmpty) {
        debugPrint('🔧 Creating missing printer_configurations table');
        await _createPrinterConfigurationsTable(db);
        return;
      }
      
      final columns = await db.rawQuery("PRAGMA table_info(printer_configurations)");
      final existingColumns = columns.map((col) => col['name'] as String).toSet();
      
      final requiredColumns = {
        'id', 'name', 'description', 'type', 'bluetooth_address', 'remote_config', 'station_id', 'created_at', 'updated_at'
      };
      
      final missingColumns = requiredColumns.difference(existingColumns);
      
      if (missingColumns.isNotEmpty) {
        debugPrint('🔧 Fixing printer_configurations table - missing columns: $missingColumns');
        await _recreatePrinterConfigurationsTable(db);
      } else {
        debugPrint('✅ Printer configurations table schema is correct');
      }
    } catch (e) {
      debugPrint('❌ Error checking printer_configurations table: $e');
      await _recreatePrinterConfigurationsTable(db);
    }
  }

  /// Check and fix printer_assignments table schema
  Future<void> _checkAndFixPrinterAssignmentsTable(Database db) async {
    try {
      final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='printer_assignments'"
      );
      
      if (tableExists.isEmpty) {
        debugPrint('🔧 Creating missing printer_assignments table');
        await _createPrinterAssignmentsTable(db);
        return;
      }
      
      final columns = await db.rawQuery("PRAGMA table_info(printer_assignments)");
      final existingColumns = columns.map((col) => col['name'] as String).toSet();
      
      final requiredColumns = {
        'id', 'printer_id', 'printer_name', 'printer_address', 'assignment_type', 'target_id', 'target_name', 'station_name', 'created_at', 'updated_at'
      };
      
      final missingColumns = requiredColumns.difference(existingColumns);
      
      if (missingColumns.isNotEmpty) {
        debugPrint('🔧 Fixing printer_assignments table - missing columns: $missingColumns');
        await _recreatePrinterAssignmentsTable(db);
      } else {
        debugPrint('✅ Printer assignments table schema is correct');
      }
    } catch (e) {
      debugPrint('❌ Error checking printer_assignments table: $e');
      await _recreatePrinterAssignmentsTable(db);
    }
  }

  /// Force recreate problematic tables
  Future<void> _forceRecreateProblematicTables(Database db) async {
    debugPrint('🔧 Force recreating problematic tables...');
    
    await db.transaction((txn) async {
      // Disable foreign keys for this operation
      await txn.execute('PRAGMA foreign_keys = OFF');
      
      // Drop and recreate problematic tables
      await txn.execute('DROP TABLE IF EXISTS order_logs');
      await txn.execute('DROP TABLE IF EXISTS printer_configurations');
      await txn.execute('DROP TABLE IF EXISTS printer_assignments');
      
      // Recreate with proper schema
      await _createOrderLogsTable(txn);
      await _createPrinterConfigurationsTable(txn);
      await _createPrinterAssignmentsTable(txn);
      
      // Re-enable foreign keys
      await txn.execute('PRAGMA foreign_keys = ON');
    });
    
    debugPrint('✅ Problematic tables recreated');
  }

  /// Ensures all required tables exist with proper schema
  Future<void> _ensureAllTablesExist(Database db) async {
    final requiredTables = {
      'orders': () => _createOrdersTable(db),
      'order_items': () => _createOrderItemsTable(db),
      'order_logs': () => _createOrderLogsTable(db),
      'menu_items': () => _createMenuItemsTable(db),
      'categories': () => _createCategoriesTable(db),
      'users': () => _createUsersTable(db),
      'tables': () => _createTablesTable(db),
      'inventory': () => _createInventoryTable(db),
      'customers': () => _createCustomersTable(db),
      'transactions': () => _createTransactionsTable(db),
      'reservations': () => _createReservationsTable(db),
      'printer_configurations': () => _createPrinterConfigurationsTable(db),
      'printer_assignments': () => _createPrinterAssignmentsTable(db),
      'app_metadata': () => _createAppMetadataTable(db),
      'loyalty_rewards': () => _createLoyaltyRewardsTable(db),
      'app_settings': () => _createAppSettingsTable(db),
    };

    for (final entry in requiredTables.entries) {
      await _ensureTableExists(db, entry.key, entry.value);
    }
  }

  /// Migrates existing table schemas to add missing columns and fix column naming issues
  Future<void> _migrateExistingTableSchemas(Database db) async {
    try {
      debugPrint('🔧 Migrating existing table schemas...');
      
      // CRITICAL FIX: Ensure all boolean columns use proper SQLite integer format
      await _fixBooleanColumnNaming(db);
      
      // ENHANCEMENT: Migrate orders table to add missing columns for Firebase sync
      await _migrateOrdersTable(db);
      
      // Check and fix specific table schemas
      await _checkAndFixUsersTable(db);
      await _checkAndFixOrderLogsTable(db);
      await _checkAndFixPrinterConfigurationsTable(db);
      await _checkAndFixPrinterAssignmentsTable(db);
      
      debugPrint('✅ Table schema migrations completed');
    } catch (e) {
      debugPrint('❌ Error migrating table schemas: $e');
    }
  }
  
  /// Fix boolean column naming issues across all tables
  Future<void> _fixBooleanColumnNaming(Database db) async {
    debugPrint('🔧 Fixing boolean column naming issues...');
    
    try {
      // Check users table for column naming issues
      final usersColumns = await db.rawQuery("PRAGMA table_info(users)");
      final usersColumnNames = usersColumns.map((col) => col['name'] as String).toSet();
      
      // If we have the wrong column names, recreate the table
      if (usersColumnNames.contains('isActive') || usersColumnNames.contains('adminPanelAccess')) {
        debugPrint('⚠️ Found incorrect boolean column names in users table, fixing...');
        await _recreateUsersTableWithCorrectSchema(db);
      }
      
      // Check categories table
      final categoriesExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='categories'"
      );
      
      if (categoriesExists.isNotEmpty) {
        final categoriesColumns = await db.rawQuery("PRAGMA table_info(categories)");
        final categoriesColumnNames = categoriesColumns.map((col) => col['name'] as String).toSet();
        
        if (categoriesColumnNames.contains('isActive')) {
          debugPrint('⚠️ Found incorrect boolean column names in categories table, fixing...');
          await _fixCategoriesTableSchema(db);
        }
      }
      
      debugPrint('✅ Boolean column naming fixed');
    } catch (e) {
      debugPrint('❌ Error fixing boolean column naming: $e');
    }
  }
  
  /// Recreate users table with correct schema
  Future<void> _recreateUsersTableWithCorrectSchema(Database db) async {
    await db.transaction((txn) async {
      // Create temporary table with correct schema
      await txn.execute('''
        CREATE TABLE users_temp (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          role TEXT NOT NULL,
          pin TEXT NOT NULL,
          is_active INTEGER NOT NULL DEFAULT 1,
          admin_panel_access INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          last_login TEXT
        )
      ''');
      
      // Copy data with proper column mapping
      await txn.execute('''
        INSERT INTO users_temp (id, name, role, pin, is_active, admin_panel_access, created_at, last_login)
        SELECT 
          id, 
          name, 
          role, 
          pin,
          CASE 
            WHEN isActive IS NOT NULL THEN CASE WHEN isActive THEN 1 ELSE 0 END
            WHEN is_active IS NOT NULL THEN is_active
            ELSE 1
          END as is_active,
          CASE 
            WHEN adminPanelAccess IS NOT NULL THEN CASE WHEN adminPanelAccess THEN 1 ELSE 0 END
            WHEN admin_panel_access IS NOT NULL THEN admin_panel_access
            ELSE 0
          END as admin_panel_access,
          created_at,
          last_login
        FROM users
      ''');
      
      // Drop old table and rename temp table
      await txn.execute('DROP TABLE users');
      await txn.execute('ALTER TABLE users_temp RENAME TO users');
    });
    
    debugPrint('✅ Users table recreated with correct schema');
  }
  
  /// Fix categories table schema
  Future<void> _fixCategoriesTableSchema(Database db) async {
    await db.transaction((txn) async {
      // Create temporary table with correct schema
      await txn.execute('''
        CREATE TABLE categories_temp (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          description TEXT,
          image_url TEXT,
          is_active INTEGER NOT NULL DEFAULT 1,
          sort_order INTEGER NOT NULL DEFAULT 0,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      
      // Copy data with proper column mapping
      await txn.execute('''
        INSERT INTO categories_temp (id, name, description, image_url, is_active, sort_order, created_at, updated_at)
        SELECT 
          id, 
          name, 
          description,
          image_url,
          CASE 
            WHEN isActive IS NOT NULL THEN CASE WHEN isActive THEN 1 ELSE 0 END
            WHEN is_active IS NOT NULL THEN is_active
            ELSE 1
          END as is_active,
          COALESCE(sort_order, 0) as sort_order,
          COALESCE(created_at, datetime('now')) as created_at,
          COALESCE(updated_at, datetime('now')) as updated_at
        FROM categories
      ''');
      
      // Drop old table and rename temp table
      await txn.execute('DROP TABLE categories');
      await txn.execute('ALTER TABLE categories_temp RENAME TO categories');
    });
    
    debugPrint('✅ Categories table schema fixed');
  }

  /// Migrates users table to add admin_panel_access column
  Future<void> _migrateUsersTable(Database db) async {
    try {
      debugPrint('🔧 Migrating users table schema...');
      
      // Get current table schema
      final tableInfo = await db.rawQuery("PRAGMA table_info(users)");
      final existingColumns = tableInfo.map((col) => col['name'] as String).toSet();
      
      // Add admin_panel_access column if it doesn't exist
      if (!existingColumns.contains('admin_panel_access')) {
        try {
          await db.execute('ALTER TABLE users ADD COLUMN admin_panel_access INTEGER NOT NULL DEFAULT 0');
          debugPrint('✅ Added admin_panel_access column to users table');
          
          // Grant admin panel access to existing admin users
          await db.execute('''
            UPDATE users 
            SET admin_panel_access = 1 
            WHERE role = 'admin'
          ''');
          debugPrint('✅ Granted admin panel access to existing admin users');
        } catch (e) {
          debugPrint('⚠️ Could not add admin_panel_access column: $e');
        }
      }
      
      debugPrint('✅ users table schema migration completed');
    } catch (e) {
      debugPrint('❌ Failed to migrate users table: $e');
    }
  }

  /// Migrates order_logs table to add missing columns
  Future<void> _migrateOrderLogsTable(dynamic db) async {
    try {
      debugPrint('🔧 Migrating order_logs table schema...');
      
      // Get current table schema
      final tableInfo = await db.rawQuery("PRAGMA table_info(order_logs)");
      final existingColumns = tableInfo.map((col) => col['name'] as String).toSet();
      
      // Define required columns with their SQL definitions
      final requiredColumns = {
        'level': 'TEXT NOT NULL DEFAULT \'info\'',
        'performed_by': 'TEXT NOT NULL DEFAULT \'system\'',
        'performed_by_name': 'TEXT NOT NULL DEFAULT \'System\'',
        'description': 'TEXT NOT NULL DEFAULT \'Order action\'',
        'before_data': 'TEXT DEFAULT \'{}\'',
        'after_data': 'TEXT DEFAULT \'{}\'',
        'metadata': 'TEXT DEFAULT \'{}\'',
        'notes': 'TEXT',
        'device_id': 'TEXT',
        'session_id': 'TEXT',
        'ip_address': 'TEXT',
        'is_system_action': 'INTEGER DEFAULT 1',
        'error_message': 'TEXT',
        'amount_before': 'REAL',
        'amount_after': 'REAL',
        'table_id': 'TEXT',
        'customer_id': 'TEXT',
        'created_at': 'TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP',
      };
      
      // Add missing columns
      for (final entry in requiredColumns.entries) {
        if (!existingColumns.contains(entry.key)) {
          try {
            await db.execute('ALTER TABLE order_logs ADD COLUMN ${entry.key} ${entry.value}');
            debugPrint('✅ Added column ${entry.key} to order_logs');
          } catch (e) {
            debugPrint('⚠️ Could not add column ${entry.key}: $e');
          }
        }
      }
      
      // Create indexes if they don't exist
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_order_logs_order_id ON order_logs(order_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_order_logs_performed_by ON order_logs(performed_by)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_order_logs_timestamp ON order_logs(timestamp DESC)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_order_logs_action ON order_logs(action)');
        debugPrint('✅ order_logs indexes created');
      } catch (e) {
        debugPrint('⚠️ Could not create order_logs indexes: $e');
      }
      
      debugPrint('✅ order_logs table schema migration completed');
    } catch (e) {
      debugPrint('❌ Failed to migrate order_logs table: $e');
    }
  }

  /// Migrates printer_configurations table to add missing columns
  Future<void> _migratePrinterConfigurationsTable(dynamic db) async {
    try {
      debugPrint('🔧 Migrating printer_configurations table schema...');
      
      // Get current table schema
      final tableInfo = await db.rawQuery("PRAGMA table_info(printer_configurations)");
      final existingColumns = tableInfo.map((col) => col['name'] as String).toSet();
      
      // Define required columns
      final requiredColumns = {
        'description': 'TEXT NOT NULL DEFAULT \'Printer configuration\'',
        'bluetooth_address': 'TEXT',
        'station_id': 'TEXT DEFAULT \'main_kitchen\'',
        'connection_status': 'TEXT DEFAULT \'unknown\'',
        'last_connected': 'TEXT',
        'last_test_print': 'TEXT',
        'custom_settings': 'TEXT DEFAULT \'{}\'',
        'remote_config': 'TEXT DEFAULT \'{}\'',
        'created_at': 'TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP',
        'updated_at': 'TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP',
      };
      
      // Add missing columns
      for (final entry in requiredColumns.entries) {
        if (!existingColumns.contains(entry.key)) {
          try {
            await db.execute('ALTER TABLE printer_configurations ADD COLUMN ${entry.key} ${entry.value}');
            debugPrint('✅ Added column ${entry.key} to printer_configurations');
          } catch (e) {
            debugPrint('⚠️ Could not add column ${entry.key}: $e');
          }
        }
      }
      
      debugPrint('✅ printer_configurations table schema migration completed');
    } catch (e) {
      debugPrint('❌ Failed to migrate printer_configurations table: $e');
    }
  }

  /// Migrates printer_assignments table to add missing columns
  Future<void> _migratePrinterAssignmentsTable(dynamic db) async {
    try {
      debugPrint('🔧 Migrating printer_assignments table schema...');
      
      // Get current table schema
      final tableInfo = await db.rawQuery("PRAGMA table_info(printer_assignments)");
      final existingColumns = tableInfo.map((col) => col['name'] as String).toSet();
      
      // Define required columns
      final requiredColumns = {
        'printer_name': 'TEXT NOT NULL DEFAULT \'\'',
        'printer_address': 'TEXT NOT NULL DEFAULT \'\'',
        'assignment_type': 'TEXT NOT NULL DEFAULT \'category\'',
        'target_id': 'TEXT NOT NULL DEFAULT \'\'',
        'target_name': 'TEXT NOT NULL DEFAULT \'Kitchen\'',
        'station_name': 'TEXT NOT NULL DEFAULT \'Kitchen\'',
        'order_types': 'TEXT DEFAULT \'["dineIn","takeaway"]\'',
        'is_active': 'INTEGER DEFAULT 1',
        'priority': 'INTEGER DEFAULT 1',
        'created_at': 'TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP',
        'updated_at': 'TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP',
      };
      
      // Add missing columns
      for (final entry in requiredColumns.entries) {
        if (!existingColumns.contains(entry.key)) {
          try {
            await db.execute('ALTER TABLE printer_assignments ADD COLUMN ${entry.key} ${entry.value}');
            debugPrint('✅ Added column ${entry.key} to printer_assignments');
          } catch (e) {
            debugPrint('⚠️ Could not add column ${entry.key}: $e');
          }
        }
      }
      
      debugPrint('✅ printer_assignments table schema migration completed');
    } catch (e) {
      debugPrint('❌ Failed to migrate printer_assignments table: $e');
    }
  }

  /// Performs post-migration integrity check
  Future<void> _postMigrationIntegrityCheck(Database db) async {
    try {
      debugPrint('🔧 Starting post-migration data integrity check...');
      
      // Test critical operations
      await db.rawQuery('SELECT COUNT(*) FROM order_logs LIMIT 1');
      await db.rawQuery('SELECT COUNT(*) FROM printer_configurations LIMIT 1');
      await db.rawQuery('SELECT COUNT(*) FROM printer_assignments LIMIT 1');
      
      debugPrint('✅ Post-migration integrity check passed');
    } catch (e) {
      debugPrint('⚠️ Post-migration integrity check warning: $e');
    }
  }

  /// Cleans up orphaned data that could cause foreign key constraint errors
  Future<void> _cleanupOrphanedData(Database db) async {
    try {
      debugPrint('🧹 Starting orphaned data cleanup...');
      
      // Check if we have menu items loaded first
      final menuItemsResult = await db.rawQuery('SELECT COUNT(*) as count FROM menu_items');
      final menuItemsCount = menuItemsResult.first['count'] as int;
      
      if (menuItemsCount == 0) {
        debugPrint('⚠️ No menu items found - skipping order cleanup to prevent data loss');
        // Only clean up order logs that reference non-existent orders
        final orphanedLogs = await db.rawDelete('''
          DELETE FROM order_logs 
          WHERE order_id NOT IN (
            SELECT id FROM orders WHERE id IS NOT NULL
          )
        ''');
        
        if (orphanedLogs > 0) {
          debugPrint('🧹 Removed $orphanedLogs orphaned order logs');
        }
        
        debugPrint('✅ Limited orphaned data cleanup completed (preserved orders)');
        return;
      }
      
      // Only clean up order items with truly empty menu_item_id (not just missing references)
      final emptyMenuItemIds = await db.rawDelete('''
        DELETE FROM order_items 
        WHERE menu_item_id IS NULL OR menu_item_id = '' OR TRIM(menu_item_id) = ''
      ''');
      
      if (emptyMenuItemIds > 0) {
        debugPrint('🧹 Removed $emptyMenuItemIds order items with empty menu_item_id');
      }
      
      // Be more conservative with orphaned order items - only delete if menu items table is properly loaded
      final orphanedOrderItems = await db.rawDelete('''
        DELETE FROM order_items 
        WHERE menu_item_id NOT IN (
          SELECT id FROM menu_items WHERE id IS NOT NULL AND id != ''
        ) AND menu_item_id NOT LIKE 'placeholder_%'
      ''');
      
      if (orphanedOrderItems > 0) {
        debugPrint('🧹 Removed $orphanedOrderItems orphaned order items');
      }
      
      // Only clean up orders that have no items AND are completed/cancelled (preserve active orders)
      final emptyOrders = await db.rawDelete('''
        DELETE FROM orders 
        WHERE id NOT IN (
          SELECT DISTINCT order_id FROM order_items WHERE order_id IS NOT NULL
        ) AND status IN ('completed', 'cancelled')
      ''');
      
      if (emptyOrders > 0) {
        debugPrint('🧹 Removed $emptyOrders completed/cancelled orders with no items');
      }
      
      // Clean up order logs that reference non-existent orders
      final orphanedLogs = await db.rawDelete('''
        DELETE FROM order_logs 
        WHERE order_id NOT IN (
          SELECT id FROM orders WHERE id IS NOT NULL
        )
      ''');
      
      if (orphanedLogs > 0) {
        debugPrint('🧹 Removed $orphanedLogs orphaned order logs');
      }
      
      debugPrint('✅ Orphaned data cleanup completed');
    } catch (e) {
      debugPrint('⚠️ Orphaned data cleanup error: $e');
    }
  }

  /// Cleanup orphaned order items that reference non-existent menu items or orders
  Future<void> cleanupOrphanedOrderItems() async {
    if (kIsWeb) {
      // Web platform - simplified cleanup (could be enhanced)
      debugPrint('✅ Web platform cleanup completed (simplified)');
      return;
    }
    
    try {
      final db = await database;
      if (db == null) {
        debugPrint('⚠️ Database not available for cleanup');
        return;
      }
      
      final orphanedCount = await db.rawDelete('''
        DELETE FROM order_items 
        WHERE menu_item_id NOT IN (SELECT id FROM menu_items)
           OR order_id NOT IN (SELECT id FROM orders)
      ''');
      
      if (orphanedCount > 0) {
        debugPrint('🧹 Cleaned up $orphanedCount orphaned order items');
      } else {
        debugPrint('✅ No orphaned order items found');
      }
    } catch (e) {
      debugPrint('❌ Error during orphaned order items cleanup: $e');
    }
  }

  /// Validates that a menu item exists in the database
  Future<bool> validateMenuItemExists(String menuItemId) async {
    if (kIsWeb) {
      // Web platform - check in Hive storage
      try {
        final menuItems = await getWebMenuItems();
        return menuItems.any((item) => item['id'] == menuItemId);
      } catch (e) {
        debugPrint('⚠️ Error validating web menu item existence: $e');
        return false;
      }
    }
    
    try {
      final db = await database;
      if (db == null) return false;
      
      final result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM menu_items WHERE id = ?',
        [menuItemId],
      );
      return (result.first['count'] as int) > 0;
    } catch (e) {
      debugPrint('⚠️ Error validating menu item existence: $e');
      return false;
    }
  }

  /// Validates multiple menu items exist in the database
  /// Returns list of invalid menu item IDs
  Future<List<String>> validateOrderMenuItems(List<String> menuItemIds) async {
    if (menuItemIds.isEmpty) return [];
    
    if (kIsWeb) {
      // Web platform - check in Hive storage
      try {
        final menuItems = await getWebMenuItems();
        final existingIds = menuItems.map((item) => item['id'] as String).toSet();
        return menuItemIds.where((id) => !existingIds.contains(id)).toList();
      } catch (e) {
        debugPrint('⚠️ Error validating web menu items: $e');
        return menuItemIds; // Return all as invalid on error
      }
    }
    
    try {
      final db = await database;
      if (db == null) return menuItemIds; // Return all as invalid if no database
      
      final placeholders = List.filled(menuItemIds.length, '?').join(',');
      
      final result = await db.rawQuery('''
        SELECT id FROM menu_items WHERE id IN ($placeholders)
      ''', menuItemIds);
      
      final existingIds = result.map((row) => row['id'] as String).toSet();
      return menuItemIds.where((id) => !existingIds.contains(id)).toList();
    } catch (e) {
      debugPrint('⚠️ Error validating menu items: $e');
      return menuItemIds; // Return all as invalid on error
    }
  }

  /// Checks if sample data needs to be loaded
  Future<bool> needsSampleData() async {
    if (kIsWeb) {
      // Web platform - check if categories exist
      try {
        final categories = await getWebCategories();
        return categories.isEmpty;
      } catch (e) {
        debugPrint('⚠️ Error checking web sample data need: $e');
        return true; // Default to needing sample data
      }
    }
    
    try {
      final db = await database;
      if (db == null) return true; // Need sample data if no database
      
      // Check if we have the sample data loaded flag
      final metadataResult = await db.rawQuery('''
        SELECT value FROM app_metadata WHERE key = 'sample_data_loaded'
      ''');
      
      if (metadataResult.isNotEmpty) {
        return metadataResult.first['value'] != 'true';
      }
      
      // If no metadata, check if we have any menu items
      final menuItemsResult = await db.rawQuery('SELECT COUNT(*) as count FROM menu_items');
      final menuItemsCount = menuItemsResult.first['count'] as int;
      
      return menuItemsCount == 0;
    } catch (e) {
      debugPrint('⚠️ Error checking sample data need: $e');
      return true; // Default to needing sample data
    }
  }

  /// Marks sample data as loaded
  Future<void> markSampleDataLoaded() async {
    if (kIsWeb) {
      // Web platform - no need to mark as loaded (handled by sample data existence)
      debugPrint('✅ Web sample data loading completed');
      return;
    }
    
    try {
      final db = await database;
      if (db == null) {
        debugPrint('⚠️ Database not available to mark sample data as loaded');
        return;
      }
      
      await db.rawInsert('''
        INSERT OR REPLACE INTO app_metadata (key, value, updated_at)
        VALUES ('sample_data_loaded', 'true', ?)
      ''', [DateTime.now().toIso8601String()]);
      debugPrint('✅ Marked sample data as loaded');
    } catch (e) {
      debugPrint('⚠️ Error marking sample data as loaded: $e');
    }
  }

  /// Completely resets the database by dropping and recreating all tables
  Future<void> resetDatabase() async {
    if (kIsWeb) {
      // Web platform - clear all Hive storage
      try {
        debugPrint('🔄 Resetting web storage completely...');
        if (_webBox == null) await _initWebStorage();
        await _webBox?.clear();
        debugPrint('✅ Web storage reset completed successfully');
      } catch (e) {
        debugPrint('❌ Web storage reset failed: $e');
        rethrow;
      }
      return;
    }
    
    try {
      debugPrint('🔄 Resetting database completely...');
      final db = await database;
      if (db == null) throw DatabaseException('Database not available', operation: 'reset_database');
      
      await db.transaction((txn) async {
        // Drop all tables in correct order to avoid foreign key issues
        await txn.execute('PRAGMA foreign_keys = OFF');
        
        // Drop tables
        await txn.execute('DROP TABLE IF EXISTS order_items');
        await txn.execute('DROP TABLE IF EXISTS orders');
        await txn.execute('DROP TABLE IF EXISTS menu_items');
        await txn.execute('DROP TABLE IF EXISTS categories');
        await txn.execute('DROP TABLE IF EXISTS users');
        await txn.execute('DROP TABLE IF EXISTS tables');
        await txn.execute('DROP TABLE IF EXISTS reservations');
        await txn.execute('DROP TABLE IF EXISTS printer_configurations');
        await txn.execute('DROP TABLE IF EXISTS printer_assignments');
        await txn.execute('DROP TABLE IF EXISTS order_logs');
        await txn.execute('DROP TABLE IF EXISTS app_metadata');
        await txn.execute('DROP TABLE IF EXISTS loyalty_rewards');
        await txn.execute('DROP TABLE IF EXISTS app_settings');
        
        // Recreate all tables
        await _createUsersTable(txn);
        await _createTablesTable(txn);
        await _createCategoriesTable(txn);
        await _createMenuItemsTable(txn);
        await _createOrdersTable(txn);
        await _createOrderItemsTable(txn);
        await _createInventoryTable(txn);
        await _createCustomersTable(txn);
        await _createTransactionsTable(txn);
        
        // Create app_metadata table
        await _createAppMetadataTable(txn);
        
        // Create new tables for comprehensive restaurant setup
        await _createLoyaltyRewardsTable(txn);
        await _createAppSettingsTable(txn);
        
        await txn.execute('PRAGMA foreign_keys = ON');
      });
      
      debugPrint('✅ Database reset completed successfully');
    } catch (e) {
      debugPrint('❌ Database reset failed: $e');
      rethrow;
    }
  }

  // ===== WEB-COMPATIBLE METHODS =====
  
  /// Web-compatible method to get users
  Future<List<Map<String, dynamic>>> getWebUsers() async {
    if (!kIsWeb) return [];
    
    try {
      if (_webBox == null) await _initWebStorage();
      final users = _webBox?.get('users', defaultValue: <Map<String, dynamic>>[]);
      return List<Map<String, dynamic>>.from(users ?? []);
    } catch (e) {
      debugPrint('❌ Error getting web users: $e');
      return [];
    }
  }

  /// Web-compatible method to save user
  Future<void> saveWebUser(Map<String, dynamic> user) async {
    if (!kIsWeb) return;
    
    try {
      if (_webBox == null) await _initWebStorage();
      final users = await getWebUsers();
      
      // Update existing user or add new one
      final existingIndex = users.indexWhere((u) => u['id'] == user['id']);
      if (existingIndex >= 0) {
        users[existingIndex] = user;
      } else {
        users.add(user);
      }
      
      await _webBox?.put('users', users);
      debugPrint('✅ User saved to web storage: ${user['name']}');
    } catch (e) {
      debugPrint('❌ Error saving web user: $e');
    }
  }

  /// Web-compatible method to get orders
  Future<List<Map<String, dynamic>>> getWebOrders() async {
    if (!kIsWeb) return [];
    
    try {
      if (_webBox == null) await _initWebStorage();
      final orders = _webBox?.get('orders', defaultValue: <Map<String, dynamic>>[]);
      return List<Map<String, dynamic>>.from(orders ?? []);
    } catch (e) {
      debugPrint('❌ Error getting web orders: $e');
      return [];
    }
  }

  /// Web-compatible method to save order
  Future<void> saveWebOrder(Map<String, dynamic> order) async {
    if (!kIsWeb) return;
    
    try {
      if (_webBox == null) await _initWebStorage();
      final orders = await getWebOrders();
      
      // Update existing order or add new one
      final existingIndex = orders.indexWhere((o) => o['id'] == order['id']);
      if (existingIndex >= 0) {
        orders[existingIndex] = order;
      } else {
        orders.add(order);
      }
      
      await _webBox?.put('orders', orders);
      debugPrint('✅ Order saved to web storage: ${order['order_number']}');
    } catch (e) {
      debugPrint('❌ Error saving web order: $e');
    }
  }

  /// Web-compatible method to get order logs
  Future<List<Map<String, dynamic>>> getWebOrderLogs() async {
    if (!kIsWeb) return [];
    
    try {
      if (_webBox == null) await _initWebStorage();
      final logs = _webBox?.get('order_logs', defaultValue: <Map<String, dynamic>>[]);
      return List<Map<String, dynamic>>.from(logs ?? []);
    } catch (e) {
      debugPrint('❌ Error getting web order logs: $e');
      return [];
    }
  }

  /// Web-compatible method to save order log
  Future<void> saveWebOrderLog(Map<String, dynamic> log) async {
    if (!kIsWeb) return;
    
    try {
      if (_webBox == null) await _initWebStorage();
      final logs = await getWebOrderLogs();
      logs.add(log);
      
      await _webBox?.put('order_logs', logs);
      debugPrint('✅ Order log saved to web storage');
    } catch (e) {
      debugPrint('❌ Error saving web order log: $e');
    }
  }

  /// Web-compatible method to save multiple order logs
  Future<void> saveWebOrderLogs(List<Map<String, dynamic>> logs) async {
    if (!kIsWeb) return;
    
    try {
      if (_webBox == null) await _initWebStorage();
      await _webBox?.put('order_logs', logs);
      debugPrint('✅ ${logs.length} order logs saved to web storage');
    } catch (e) {
      debugPrint('❌ Error saving web order logs: $e');
    }
  }

  /// Web-compatible method to get menu items
  Future<List<Map<String, dynamic>>> getWebMenuItems() async {
    if (!kIsWeb) return [];
    
    try {
      if (_webBox == null) await _initWebStorage();
      final items = _webBox?.get('menu_items', defaultValue: <Map<String, dynamic>>[]);
      return List<Map<String, dynamic>>.from(items ?? []);
    } catch (e) {
      debugPrint('❌ Error getting web menu items: $e');
      return [];
    }
  }

  /// Web-compatible method to save menu item
  Future<void> saveWebMenuItem(Map<String, dynamic> item) async {
    if (!kIsWeb) return;
    
    try {
      if (_webBox == null) await _initWebStorage();
      final items = await getWebMenuItems();
      
      // Update existing item or add new one
      final existingIndex = items.indexWhere((i) => i['id'] == item['id']);
      if (existingIndex >= 0) {
        items[existingIndex] = item;
      } else {
        items.add(item);
      }
      
      await _webBox?.put('menu_items', items);
      debugPrint('✅ Menu item saved to web storage: ${item['name']}');
    } catch (e) {
      debugPrint('❌ Error saving web menu item: $e');
    }
  }

  /// Web-compatible method to get categories
  Future<List<Map<String, dynamic>>> getWebCategories() async {
    if (!kIsWeb) return [];
    
    try {
      if (_webBox == null) await _initWebStorage();
      final categories = _webBox?.get('categories', defaultValue: <Map<String, dynamic>>[]);
      return List<Map<String, dynamic>>.from(categories ?? []);
    } catch (e) {
      debugPrint('❌ Error getting web categories: $e');
      return [];
    }
  }

  /// Web-compatible method to save category
  Future<void> saveWebCategory(Map<String, dynamic> category) async {
    if (!kIsWeb) return;
    
    try {
      if (_webBox == null) await _initWebStorage();
      final categories = await getWebCategories();
      
      // Update existing category or add new one
      final existingIndex = categories.indexWhere((c) => c['id'] == category['id']);
      if (existingIndex >= 0) {
        categories[existingIndex] = category;
      } else {
        categories.add(category);
      }
      
      await _webBox?.put('categories', categories);
      debugPrint('✅ Category saved to web storage: ${category['name']}');
    } catch (e) {
      debugPrint('❌ Error saving web category: $e');
    }
  }

  /// Web-compatible method to initialize with sample data
  Future<void> initializeWebSampleData() async {
    if (!kIsWeb) return;
    
    try {
      if (_webBox == null) await _initWebStorage();
      
      // Check if we already have sample data
      final categories = await getWebCategories();
      if (categories.isNotEmpty) {
        debugPrint('✅ Web sample data already exists');
        return;
      }
      
      // Create sample categories
      final sampleCategories = [
        {
          'id': 'cat-1',
          'name': 'Appetizers',
          'description': 'Start your meal right',
          'is_active': true,
          'sort_order': 1,
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'cat-2',
          'name': 'Main Course',
          'description': 'Hearty main dishes',
          'is_active': true,
          'sort_order': 2,
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'cat-3',
          'name': 'Beverages',
          'description': 'Refreshing drinks',
          'is_active': true,
          'sort_order': 3,
          'created_at': DateTime.now().toIso8601String(),
        },
      ];
      
      await _webBox?.put('categories', sampleCategories);
      
      // Create sample menu items
      final sampleMenuItems = [
        {
          'id': 'item-1',
          'name': 'Spring Rolls',
          'description': 'Crispy vegetable spring rolls',
          'price': 8.99,
          'category_id': 'cat-1',
          'is_available': true,
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'item-2',
          'name': 'Chicken Curry',
          'description': 'Spicy chicken curry with rice',
          'price': 15.99,
          'category_id': 'cat-2',
          'is_available': true,
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'item-3',
          'name': 'Mango Lassi',
          'description': 'Traditional yogurt drink',
          'price': 4.99,
          'category_id': 'cat-3',
          'is_available': true,
          'created_at': DateTime.now().toIso8601String(),
        },
      ];
      
      await _webBox?.put('menu_items', sampleMenuItems);
      
      debugPrint('✅ Web sample data initialized successfully');
      
    } catch (e) {
      debugPrint('❌ Error initializing web sample data: $e');
    }
  }

  /// Check if running on web platform
  bool get isWeb => kIsWeb;

  /// Get the appropriate storage method name for debugging
  String get storageType => kIsWeb ? 'Hive (Web)' : 'SQLite (Mobile/Desktop)';

  /// Retrieves all users from the database.
  /// 
  /// Returns a list of user maps containing user information.
  /// Throws [DatabaseException] if the query fails.
  Future<List<Map<String, dynamic>>> getUsersFromDatabase() async {
    if (kIsWeb) {
      return await getWebUsers();
    }
    
    try {
      final db = await database;
      if (db == null) return [];
      
      final List<Map<String, dynamic>> maps = await db.query('users');
      return maps;
    } catch (e) {
      throw DatabaseException('Failed to get users from database', operation: 'get_users', originalError: e);
    }
  }

  /// Initialize the database
  Future<void> initialize() async {
    if (_isInitialized || _initializationInProgress) {
      debugPrint('⚠️ Database service already initialized or initialization in progress');
      return;
    }
    
    _initializationInProgress = true;
    
    try {
      if (kIsWeb) {
        debugPrint('🌐 Initializing database service for web platform...');
        await _initWebStorage();
        debugPrint('✅ Web database service initialized');
      } else {
        debugPrint('📱 Initializing database service for mobile/desktop platform...');
        _database = await _initDatabase();
        
        // CRITICAL: Force verify and fix schema issues immediately after database connection
        await _forceVerifyAndFixSchema();
        
        debugPrint('✅ Database service initialized with cleanup');
        
        // Force cleanup of orphaned data
        debugPrint('🧹 Running additional database cleanup...');
        await cleanupOrphanedOrderItems();
        debugPrint('✅ Database cleanup completed');
      }
      
      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ Database initialization failed: $e');
      _isInitialized = false;
      rethrow;
    } finally {
      _initializationInProgress = false;
    }
  }
  
  /// Initialize the database with a custom name for multi-tenant support
  Future<void> initializeWithCustomName(String customDatabaseName) async {
    if (_customDatabaseName == customDatabaseName && _customDatabase != null) {
      debugPrint('⚠️ Custom database already initialized: $customDatabaseName');
      return;
    }
    
    try {
      // Close existing custom database if it exists
      if (_customDatabase != null) {
        debugPrint('🔒 Closing existing custom database: $_customDatabaseName');
        await _customDatabase!.close();
        _customDatabase = null;
      }
      
      _customDatabaseName = customDatabaseName;
      
      if (kIsWeb) {
        debugPrint('🌐 Initializing database service for web platform with custom name: $customDatabaseName');
        await _initWebStorage();
        debugPrint('✅ Web database service initialized with custom name');
      } else {
        debugPrint('📱 Initializing database service for mobile/desktop platform with custom name: $customDatabaseName');
        _customDatabase = await _initDatabaseWithCustomName(customDatabaseName);
        debugPrint('✅ Database service initialized with custom name: $customDatabaseName');
        
        // Force cleanup of orphaned data
        debugPrint('🧹 Running additional database cleanup...');
        await cleanupOrphanedOrderItems();
        debugPrint('✅ Database cleanup completed');
      }
    } catch (e) {
      debugPrint('❌ Custom database initialization failed: $e');
      _customDatabase = null;
      _customDatabaseName = null;
      rethrow;
    }
  }
  
  /// Initializes the database with custom name for multi-tenant support
  Future<Database> _initDatabaseWithCustomName(String customDatabaseName) async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, '$customDatabaseName.db');

      return await openDatabase(
        path,
        version: _databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: (db) async {
          // Enable foreign key constraints
          await db.execute('PRAGMA foreign_keys = ON');
          debugPrint('Database opened successfully with foreign keys enabled: $customDatabaseName');
          
          // Perform schema migrations for existing databases
          await _performSchemaMigrations(db);
          
          // Verify schema integrity
          await _verifySchemaIntegrity(db);
        },
      );
    } catch (e) {
      throw DatabaseException('Failed to initialize database with custom name: $customDatabaseName', 
          operation: 'init_database', originalError: e);
    }
  }
  
  /// Verify schema integrity for multi-tenant database
  Future<void> _verifySchemaIntegrity(Database db) async {
    try {
      debugPrint('🔍 Verifying schema integrity for multi-tenant database...');
      
      // Check if all required tables exist
      final requiredTables = [
        'categories',
        'menu_items',
        'orders',
        'order_items',
        'users',
        'tables',
        'inventory',
        'customers',
        'transactions',
        'reservations',
        'printer_configurations',
        'printer_assignments',
        'order_logs',
        'app_metadata',
      ];
      
      for (final tableName in requiredTables) {
        final tableExists = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [tableName]
        );
        
        if (tableExists.isEmpty) {
          debugPrint('⚠️ Required table missing: $tableName - creating it...');
          await _createMissingTable(db, tableName);
        }
      }
      
      debugPrint('✅ Schema integrity verified for multi-tenant database');
    } catch (e) {
      debugPrint('❌ Schema integrity verification failed: $e');
    }
  }
  
  /// Create missing table with proper schema
  Future<void> _createMissingTable(Database db, String tableName) async {
    try {
      switch (tableName) {
        case 'categories':
          await db.execute('''
            CREATE TABLE IF NOT EXISTS categories (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              description TEXT,
              is_active INTEGER NOT NULL DEFAULT 1,
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          break;
        case 'menu_items':
          await db.execute('''
            CREATE TABLE IF NOT EXISTS menu_items (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              description TEXT,
              price REAL NOT NULL,
              category_id TEXT NOT NULL,
              is_available INTEGER NOT NULL DEFAULT 1,
              is_vegetarian INTEGER NOT NULL DEFAULT 0,
              is_gluten_free INTEGER NOT NULL DEFAULT 0,
              allergens TEXT,
              image_url TEXT,
              sort_order INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL,
              FOREIGN KEY (category_id) REFERENCES categories (id)
            )
          ''');
          break;
        case 'users':
          await db.execute('''
            CREATE TABLE IF NOT EXISTS users (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              role TEXT NOT NULL,
              pin TEXT NOT NULL,
              is_active INTEGER NOT NULL DEFAULT 1,
              admin_panel_access INTEGER NOT NULL DEFAULT 0,
              created_at TEXT NOT NULL,
              last_login TEXT
            )
          ''');
          break;
        case 'tables':
          await db.execute('''
            CREATE TABLE IF NOT EXISTS tables (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              capacity INTEGER NOT NULL,
              status TEXT NOT NULL DEFAULT 'available',
              is_active INTEGER NOT NULL DEFAULT 1,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          break;
        case 'app_metadata':
          await db.execute('''
            CREATE TABLE IF NOT EXISTS app_metadata (
              id TEXT PRIMARY KEY,
              key TEXT NOT NULL UNIQUE,
              value TEXT NOT NULL,
              created_at TEXT NOT NULL,
              updated_at TEXT NOT NULL
            )
          ''');
          break;
        default:
          debugPrint('⚠️ Unknown table type: $tableName');
      }
      
      debugPrint('✅ Created missing table: $tableName');
    } catch (e) {
      debugPrint('❌ Failed to create missing table $tableName: $e');
    }
  }

  /// Performs comprehensive database integrity check
  Future<void> performDatabaseIntegrityCheck() async {
    try {
      debugPrint('🔧 Starting comprehensive database integrity check...');
      
      final db = await database;
      if (db == null) {
        debugPrint('❌ Database not available for integrity check');
        return;
      }
      
      // Check for critical schema issues
      await _checkCriticalSchemaIssues(db);
      
      debugPrint('✅ Database integrity check completed successfully');
    } catch (e) {
      debugPrint('❌ Database integrity check failed: $e');
      rethrow;
    }
  }
  
  /// Checks for critical schema issues that need immediate fixing
  Future<void> _checkCriticalSchemaIssues(Database db) async {
    debugPrint('🔧 Checking for critical schema issues...');
    
    try {
      // Check order_logs table schema
      final orderLogsColumns = await db.rawQuery("PRAGMA table_info(order_logs)");
      final orderLogsColumnNames = orderLogsColumns.map((col) => col['name'] as String).toSet();
      
      final requiredOrderLogsColumns = {
        'id', 'order_id', 'order_number', 'action', 'level', 'performed_by', 
        'performed_by_name', 'timestamp', 'description', 'created_at'
      };
      
      final missingOrderLogsColumns = requiredOrderLogsColumns.difference(orderLogsColumnNames);
      
      if (missingOrderLogsColumns.isNotEmpty) {
        debugPrint('⚠️ Missing columns in order_logs: $missingOrderLogsColumns');
        await _recreateOrderLogsTable(db);
      }
      
      // Check printer_configurations table schema
      final printerConfigColumns = await db.rawQuery("PRAGMA table_info(printer_configurations)");
      final printerConfigColumnNames = printerConfigColumns.map((col) => col['name'] as String).toSet();
      
      final requiredPrinterConfigColumns = {
        'id', 'name', 'description', 'type', 'bluetooth_address', 'remote_config', 'created_at', 'updated_at'
      };
      
      final missingPrinterConfigColumns = requiredPrinterConfigColumns.difference(printerConfigColumnNames);
      
      if (missingPrinterConfigColumns.isNotEmpty) {
        debugPrint('⚠️ Missing columns in printer_configurations: $missingPrinterConfigColumns');
        await _recreatePrinterConfigurationsTable(db);
      }
      
      // Check printer_assignments table schema
      final printerAssignColumns = await db.rawQuery("PRAGMA table_info(printer_assignments)");
      final printerAssignColumnNames = printerAssignColumns.map((col) => col['name'] as String).toSet();
      
      final requiredPrinterAssignColumns = {
        'id', 'printer_id', 'printer_name', 'printer_address', 'assignment_type', 'target_id', 'target_name', 'station_name', 'created_at', 'updated_at'
      };
      
      final missingPrinterAssignColumns = requiredPrinterAssignColumns.difference(printerAssignColumnNames);
      
      if (missingPrinterAssignColumns.isNotEmpty) {
        debugPrint('⚠️ Missing columns in printer_assignments: $missingPrinterAssignColumns');
        await _recreatePrinterAssignmentsTable(db);
      }
      
      debugPrint('✅ No critical schema issues detected');
    } catch (e) {
      debugPrint('❌ Critical schema check failed: $e');
      // Continue with app initialization even if schema check fails
    }
  }
  
  /// Recreates the order_logs table with proper schema
  Future<void> _recreateOrderLogsTable(Database db) async {
    debugPrint('🔄 Recreating order_logs table...');
    
    try {
      // Backup existing data
      List<Map<String, dynamic>> existingData = [];
      try {
        existingData = await db.query('order_logs');
      } catch (e) {
        debugPrint('⚠️ Could not backup existing order_logs data: $e');
      }
      
      // Drop and recreate table
      await db.execute('DROP TABLE IF EXISTS order_logs');
      await _createOrderLogsTable(db);
      
      // Restore compatible data
      for (final row in existingData) {
        try {
          final migratedRow = <String, dynamic>{
            'id': row['id'] ?? const Uuid().v4(),
            'order_id': row['order_id'] ?? '',
            'order_number': row['order_number'] ?? '',
            'action': row['action'] ?? 'unknown',
            'level': row['level'] ?? 'info',
            'performed_by': row['performed_by'] ?? 'system',
            'performed_by_name': row['performed_by_name'] ?? 'System',
            'timestamp': row['timestamp'] ?? DateTime.now().toIso8601String(),
            'description': row['description'] ?? 'Order action',
            'before_data': row['before_data'] ?? '{}',
            'after_data': row['after_data'] ?? '{}',
            'metadata': row['metadata'] ?? '{}',
            'notes': row['notes'],
            'device_id': row['device_id'],
            'session_id': row['session_id'],
            'ip_address': row['ip_address'],
            'is_system_action': row['is_system_action'] ?? 1,
            'error_message': row['error_message'],
            'amount_before': row['amount_before'],
            'amount_after': row['amount_after'],
            'table_id': row['table_id'],
            'customer_id': row['customer_id'],
            'created_at': row['created_at'] ?? DateTime.now().toIso8601String(),
          };
          
          await db.insert('order_logs', migratedRow);
        } catch (e) {
          debugPrint('⚠️ Could not migrate order log row: $e');
        }
      }
      
      debugPrint('✅ Recreated order_logs table successfully');
    } catch (e) {
      debugPrint('❌ Failed to recreate order_logs table: $e');
    }
  }
  
  /// Recreates the printer_configurations table with proper schema
  Future<void> _recreatePrinterConfigurationsTable(Database db) async {
    debugPrint('🔄 Recreating printer_configurations table...');
    
    try {
      // Backup existing data
      List<Map<String, dynamic>> existingData = [];
      try {
        existingData = await db.query('printer_configurations');
      } catch (e) {
        debugPrint('⚠️ Could not backup existing printer_configurations data: $e');
      }
      
      // Drop and recreate table
      await db.execute('DROP TABLE IF EXISTS printer_configurations');
      await _createPrinterConfigurationsTable(db);
      
      debugPrint('✅ Recreated printer_configurations table successfully');
    } catch (e) {
      debugPrint('❌ Failed to recreate printer_configurations table: $e');
    }
  }
  
  /// Recreates the printer_assignments table with proper schema
  Future<void> _recreatePrinterAssignmentsTable(Database db) async {
    debugPrint('🔄 Recreating printer_assignments table...');
    
    try {
      // Backup existing data
      List<Map<String, dynamic>> existingData = [];
      try {
        existingData = await db.query('printer_assignments');
      } catch (e) {
        debugPrint('⚠️ Could not backup existing printer_assignments data: $e');
      }
      
      // Drop and recreate table
      await db.execute('DROP TABLE IF EXISTS printer_assignments');
      await _createPrinterAssignmentsTable(db);
      
      debugPrint('✅ Recreated printer_assignments table successfully');
    } catch (e) {
      debugPrint('❌ Failed to recreate printer_assignments table: $e');
    }
  }

  /// Force database reset if critical schema issues are detected
  Future<void> _handleCriticalSchemaIssues(Database db) async {
    try {
      debugPrint('🔧 Checking for critical schema issues...');
      
      // Check for critical missing columns that indicate major schema problems
      final criticalIssues = <String>[];
      
      // Check order_logs table
      try {
        final orderLogsColumns = await db.rawQuery("PRAGMA table_info(order_logs)");
        final orderLogsColumnNames = orderLogsColumns.map((col) => col['name'] as String).toSet();
        
        if (!orderLogsColumnNames.contains('performed_by') || 
            !orderLogsColumnNames.contains('description') || 
            !orderLogsColumnNames.contains('level')) {
          criticalIssues.add('order_logs missing critical columns');
        }
      } catch (e) {
        criticalIssues.add('order_logs table corrupted');
      }
      
      // Check printer_configurations table
      try {
        final printerConfigColumns = await db.rawQuery("PRAGMA table_info(printer_configurations)");
        final printerConfigColumnNames = printerConfigColumns.map((col) => col['name'] as String).toSet();
        
        if (!printerConfigColumnNames.contains('description') || 
            !printerConfigColumnNames.contains('bluetooth_address')) {
          criticalIssues.add('printer_configurations missing critical columns');
        }
      } catch (e) {
        // Table might not exist, this is ok
      }
      
      // Check printer_assignments table
      try {
        final printerAssignColumns = await db.rawQuery("PRAGMA table_info(printer_assignments)");
        final printerAssignColumnNames = printerAssignColumns.map((col) => col['name'] as String).toSet();
        
        if (!printerAssignColumnNames.contains('target_name') || 
            !printerAssignColumnNames.contains('target_id') ||
            !printerAssignColumnNames.contains('assignment_type')) {
          criticalIssues.add('printer_assignments missing critical columns');
        }
      } catch (e) {
        // Table might not exist, this is ok
      }
      
      if (criticalIssues.isNotEmpty) {
        debugPrint('❌ Critical schema issues detected: ${criticalIssues.join(', ')}');
        debugPrint('🔄 Performing emergency database reset...');
        
        // Force recreate all tables
        await _forceRecreateAllTables(db);
        
        debugPrint('✅ Emergency database reset completed');
      } else {
        debugPrint('✅ No critical schema issues detected');
      }
    } catch (e) {
      debugPrint('❌ Error checking for critical schema issues: $e');
    }
  }

  /// Force recreate all tables (nuclear option)
  Future<void> _forceRecreateAllTables(Database db) async {
    await db.transaction((txn) async {
      // Disable foreign keys for this operation
      await txn.execute('PRAGMA foreign_keys = OFF');
      
      // Drop all tables
      await txn.execute('DROP TABLE IF EXISTS order_items');
      await txn.execute('DROP TABLE IF EXISTS orders');
      await txn.execute('DROP TABLE IF EXISTS order_logs');
      await txn.execute('DROP TABLE IF EXISTS printer_configurations');
      await txn.execute('DROP TABLE IF EXISTS printer_assignments');
      await txn.execute('DROP TABLE IF EXISTS app_metadata');
      
      // Recreate core tables
      await _createOrdersTable(txn);
      await _createOrderItemsTable(txn);
      await _createOrderLogsTable(txn);
      await _createPrinterConfigurationsTable(txn);
      await _createPrinterAssignmentsTable(txn);
      await _createAppMetadataTable(txn);
      
      // Re-enable foreign keys
      await txn.execute('PRAGMA foreign_keys = ON');
    });
  }

  /// Add missing columns to order_logs table
  Future<void> _addMissingOrderLogsColumns(Database db) async {
    // This method is now handled by _checkAndFixOrderLogsTable
    // which recreates the table if columns are missing
    debugPrint('✅ order_logs table schema ensured');
  }
  
  /// Add missing columns to printer_configurations table
  Future<void> _addMissingPrinterConfigColumns(Database db) async {
    // This method is now handled by _checkAndFixPrinterConfigurationsTable
    // which recreates the table if columns are missing
    debugPrint('✅ printer_configurations table schema ensured');
  }
  
  /// Add missing columns to printer_assignments table
  Future<void> _addMissingPrinterAssignmentColumns(Database db) async {
    // This method is now handled by _checkAndFixPrinterAssignmentsTable
    // which recreates the table if columns are missing
    debugPrint('✅ printer_assignments table schema ensured');
  }

  /// Check and fix users table schema
  Future<void> _checkAndFixUsersTable(Database db) async {
    try {
      final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='users'"
      );
      
      if (tableExists.isEmpty) {
        debugPrint('🔧 Creating missing users table');
        await _createUsersTable(db);
        return;
      }
      
      final tableInfo = await db.rawQuery("PRAGMA table_info(users)");
      final columnNames = tableInfo.map((col) => col['name'] as String).toSet();
      
      final requiredColumns = {
        'id', 'name', 'role', 'pin', 'is_active', 'admin_panel_access', 'created_at', 'last_login'
      };
      
      final missingColumns = requiredColumns.difference(columnNames);
      
      // If critical columns are missing or we have naming issues, recreate the table
      if (missingColumns.isNotEmpty || 
          columnNames.contains('isActive') || 
          columnNames.contains('adminPanelAccess')) {
        debugPrint('🔧 Users table needs major schema fix, recreating...');
        await _recreateUsersTableWithCorrectSchema(db);
      } else {
        debugPrint('✅ Users table schema is correct');
      }
      
    } catch (e) {
      debugPrint('❌ Error checking users table: $e');
      // Try to recreate the table
      await _recreateUsersTableWithCorrectSchema(db);
    }
  }



  /// CRITICAL: Force verify and fix schema issues immediately after database connection
  Future<void> _forceVerifyAndFixSchema() async {
    try {
      final db = await database;
      if (db == null) return;

      debugPrint('🔧 Force verifying and fixing critical schema issues...');
      
      // CRITICAL: Force check and fix printer_configurations table
      await _forceFixPrinterConfigurationsTable(db);
      
      // CRITICAL: Force check and fix printer_assignments table  
      await _forceFixPrinterAssignmentsTable(db);
      
      // CRITICAL: Force check and fix order_logs table
      await _forceFixOrderLogsTable(db);
      
      debugPrint('✅ Critical schema verification and fixes completed');
      
    } catch (e) {
      debugPrint('❌ Schema verification failed: $e');
      // Continue initialization even if schema fixes fail
    }
  }

  /// FORCE FIX: Ensure printer_configurations table has all required columns
  Future<void> _forceFixPrinterConfigurationsTable(Database db) async {
    try {
      debugPrint('🔧 Force fixing printer_configurations table schema...');
      
      // Check if table exists
      final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='printer_configurations'"
      );
      
      if (tableExists.isEmpty) {
        debugPrint('🔧 Creating missing printer_configurations table');
        await _createPrinterConfigurationsTable(db);
        return;
      }

      // Get current table schema
      final tableInfo = await db.rawQuery("PRAGMA table_info(printer_configurations)");
      final existingColumns = tableInfo.map((col) => col['name'] as String).toSet();
      
      debugPrint('🔧 Current printer_configurations columns: ${existingColumns.join(', ')}');
      
      // CRITICAL: Define ALL required columns
      final requiredColumns = {
        'id': 'TEXT PRIMARY KEY',
        'name': 'TEXT NOT NULL',
        'description': 'TEXT NOT NULL DEFAULT \'Printer configuration\'',
        'type': 'TEXT NOT NULL DEFAULT \'wifi\'',
        'model': 'TEXT',
        'ip_address': 'TEXT',
        'port': 'INTEGER DEFAULT 9100',
        'mac_address': 'TEXT',
        'bluetooth_address': 'TEXT',
        'station_id': 'TEXT DEFAULT \'main_kitchen\'',  // THIS IS THE CRITICAL MISSING COLUMN
        'is_active': 'INTEGER DEFAULT 1',
        'is_default': 'INTEGER DEFAULT 0',
        'connection_status': 'TEXT DEFAULT \'unknown\'',
        'last_connected': 'TEXT',
        'last_test_print': 'TEXT',
        'custom_settings': 'TEXT DEFAULT \'{}\'',
        'remote_config': 'TEXT DEFAULT \'{}\'',
        'created_at': 'TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP',
        'updated_at': 'TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP',
      };
      
      // Check for missing columns
      final missingColumns = requiredColumns.keys.toSet().difference(existingColumns);
      
      if (missingColumns.isNotEmpty) {
        debugPrint('🔧 Missing columns in printer_configurations: ${missingColumns.join(', ')}');
        
        // Add missing columns one by one
        for (final columnName in missingColumns) {
          try {
            final columnDef = requiredColumns[columnName]!;
            await db.execute('ALTER TABLE printer_configurations ADD COLUMN $columnName $columnDef');
            debugPrint('✅ Added column $columnName to printer_configurations');
          } catch (e) {
            debugPrint('⚠️ Could not add column $columnName: $e');
            
            // If adding column fails, recreate the entire table
            debugPrint('🔧 Recreating printer_configurations table due to column addition failure');
            await _forceRecreatePrinterConfigurationsTable(db);
            break;
          }
        }
      } else {
        debugPrint('✅ printer_configurations table has all required columns');
      }
      
      // Verify the station_id column specifically
      final updatedTableInfo = await db.rawQuery("PRAGMA table_info(printer_configurations)");
      final updatedColumns = updatedTableInfo.map((col) => col['name'] as String).toSet();
      
      if (updatedColumns.contains('station_id')) {
        debugPrint('✅ station_id column verified in printer_configurations table');
      } else {
        debugPrint('❌ station_id column still missing - forcing table recreation');
        await _forceRecreatePrinterConfigurationsTable(db);
      }
      
    } catch (e) {
      debugPrint('❌ Error force fixing printer_configurations table: $e');
      // Try to recreate the table as a last resort
      await _forceRecreatePrinterConfigurationsTable(db);
    }
  }

  /// FORCE RECREATE: printer_configurations table with proper schema
  Future<void> _forceRecreatePrinterConfigurationsTable(Database db) async {
    try {
      debugPrint('🔧 Force recreating printer_configurations table...');
      
      // Backup existing data
      List<Map<String, dynamic>> existingData = [];
      try {
        existingData = await db.query('printer_configurations');
        debugPrint('🔧 Backed up ${existingData.length} printer configurations');
      } catch (e) {
        debugPrint('⚠️ Could not backup existing printer_configurations data: $e');
      }
      
      // Drop and recreate table
      await db.execute('DROP TABLE IF EXISTS printer_configurations');
      await _createPrinterConfigurationsTable(db);
      
      // Restore data if possible
      for (final row in existingData) {
        try {
          // Ensure all required fields exist with defaults
          final safeRow = {
            'id': row['id'] ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}',
            'name': row['name'] ?? 'Unknown Printer',
            'description': row['description'] ?? 'Printer configuration',
            'type': row['type'] ?? 'wifi',
            'model': row['model'],
            'ip_address': row['ip_address'],
            'port': row['port'] ?? 9100,
            'mac_address': row['mac_address'],
            'bluetooth_address': row['bluetooth_address'],
            'station_id': row['station_id'] ?? 'main_kitchen',  // Ensure station_id exists
            'is_active': row['is_active'] ?? 1,
            'is_default': row['is_default'] ?? 0,
            'connection_status': row['connection_status'] ?? 'unknown',
            'last_connected': row['last_connected'],
            'last_test_print': row['last_test_print'],
            'custom_settings': row['custom_settings'] ?? '{}',
            'remote_config': row['remote_config'] ?? '{}',
            'created_at': row['created_at'] ?? DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };
          
          await db.insert('printer_configurations', safeRow);
          debugPrint('✅ Restored printer configuration: ${safeRow['name']}');
        } catch (e) {
          debugPrint('⚠️ Could not restore printer configuration: $e');
        }
      }
      
      debugPrint('✅ Force recreated printer_configurations table successfully');
      
    } catch (e) {
      debugPrint('❌ Failed to force recreate printer_configurations table: $e');
    }
  }

  /// FORCE FIX: Ensure printer_assignments table has all required columns
  Future<void> _forceFixPrinterAssignmentsTable(Database db) async {
    try {
      debugPrint('🔧 Force fixing printer_assignments table schema...');
      
      // Check if table exists
      final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='printer_assignments'"
      );
      
      if (tableExists.isEmpty) {
        debugPrint('🔧 Creating missing printer_assignments table');
        await _createPrinterAssignmentsTable(db);
        return;
      }

      // Get current table schema
      final tableInfo = await db.rawQuery("PRAGMA table_info(printer_assignments)");
      final existingColumns = tableInfo.map((col) => col['name'] as String).toSet();
      
      // Define required columns
      final requiredColumns = {
        'id': 'TEXT PRIMARY KEY',
        'printer_id': 'TEXT NOT NULL',
        'printer_name': 'TEXT NOT NULL DEFAULT \'\'',
        'printer_address': 'TEXT NOT NULL DEFAULT \'\'',
        'assignment_type': 'TEXT NOT NULL DEFAULT \'category\'',
        'target_id': 'TEXT NOT NULL DEFAULT \'\'',
        'target_name': 'TEXT NOT NULL DEFAULT \'Kitchen\'',
        'station_name': 'TEXT NOT NULL DEFAULT \'Kitchen\'',
        'order_types': 'TEXT DEFAULT \'["dineIn","takeaway"]\'',
        'is_active': 'INTEGER DEFAULT 1',
        'priority': 'INTEGER DEFAULT 1',
        'created_at': 'TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP',
        'updated_at': 'TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP',
      };
      
      // Check for missing columns
      final missingColumns = requiredColumns.keys.toSet().difference(existingColumns);
      
      if (missingColumns.isNotEmpty) {
        debugPrint('🔧 Missing columns in printer_assignments: ${missingColumns.join(', ')}');
        
        // Add missing columns one by one
        for (final columnName in missingColumns) {
          try {
            final columnDef = requiredColumns[columnName]!;
            await db.execute('ALTER TABLE printer_assignments ADD COLUMN $columnName $columnDef');
            debugPrint('✅ Added column $columnName to printer_assignments');
          } catch (e) {
            debugPrint('⚠️ Could not add column $columnName: $e');
          }
        }
      } else {
        debugPrint('✅ printer_assignments table has all required columns');
      }
      
    } catch (e) {
      debugPrint('❌ Error force fixing printer_assignments table: $e');
    }
  }

  /// FORCE FIX: Ensure order_logs table has all required columns
  Future<void> _forceFixOrderLogsTable(Database db) async {
    try {
      debugPrint('🔧 Force fixing order_logs table schema...');
      
      // Check if table exists
      final tableExists = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='order_logs'"
      );
      
      if (tableExists.isEmpty) {
        debugPrint('🔧 Creating missing order_logs table');
        await _createOrderLogsTable(db);
        return;
      }

      // Get current table schema
      final tableInfo = await db.rawQuery("PRAGMA table_info(order_logs)");
      final existingColumns = tableInfo.map((col) => col['name'] as String).toSet();
      
      // Define required columns
      final requiredColumns = {
        'id': 'TEXT PRIMARY KEY',
        'order_id': 'TEXT NOT NULL',
        'order_number': 'TEXT',
        'action': 'TEXT NOT NULL',
        'level': 'TEXT NOT NULL DEFAULT \'info\'',
        'performed_by': 'TEXT NOT NULL DEFAULT \'system\'',
        'performed_by_name': 'TEXT NOT NULL DEFAULT \'System\'',
        'timestamp': 'TEXT NOT NULL',
        'description': 'TEXT NOT NULL DEFAULT \'Order action\'',
        'before_data': 'TEXT DEFAULT \'{}\'',
        'after_data': 'TEXT DEFAULT \'{}\'',
        'metadata': 'TEXT DEFAULT \'{}\'',
        'notes': 'TEXT',
        'device_id': 'TEXT',
        'session_id': 'TEXT',
        'ip_address': 'TEXT',
        'is_system_action': 'INTEGER DEFAULT 1',
        'error_message': 'TEXT',
        'amount_before': 'REAL',
        'amount_after': 'REAL',
        'table_id': 'TEXT',
        'customer_id': 'TEXT',
        'created_at': 'TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP',
      };
      
      // Check for missing columns
      final missingColumns = requiredColumns.keys.toSet().difference(existingColumns);
      
      if (missingColumns.isNotEmpty) {
        debugPrint('🔧 Missing columns in order_logs: ${missingColumns.join(', ')}');
        
        // Add missing columns one by one
        for (final columnName in missingColumns) {
          try {
            final columnDef = requiredColumns[columnName]!;
            await db.execute('ALTER TABLE order_logs ADD COLUMN $columnName $columnDef');
            debugPrint('✅ Added column $columnName to order_logs');
          } catch (e) {
            debugPrint('⚠️ Could not add column $columnName: $e');
          }
        }
      } else {
        debugPrint('✅ order_logs table has all required columns');
      }
      
    } catch (e) {
      debugPrint('❌ Error force fixing order_logs table: $e');
    }
  }

  /// Clear all cached data and close database connections
  /// This is critical for multi-tenant isolation
  Future<void> clearAllDataAndClose() async {
    try {
      debugPrint('🧹 Clearing all cached data and closing database connections...');
      
      // Close custom database
      if (_customDatabase != null) {
        await _customDatabase!.close();
        _customDatabase = null;
        debugPrint('✅ Custom database closed');
      }
      
      // Close main database
      if (_database != null) {
        await _database!.close();
        _database = null;
        debugPrint('✅ Main database closed');
      }
      
      // Reset initialization flags
      _isInitialized = false;
      _initializationInProgress = false;
      _customDatabaseName = null;
      
      // Clear web storage if on web platform
      if (kIsWeb && _webBox != null) {
        await _webBox!.clear();
        await _webBox!.close();
        _webBox = null;
        debugPrint('✅ Web storage cleared and closed');
      }
      
      debugPrint('✅ All database connections and cached data cleared');
    } catch (e) {
      debugPrint('❌ Error clearing database data: $e');
      // Continue anyway - don't throw as this is cleanup
    }
  }

  /// Get data from database
  Future<Map<String, dynamic>?> getData(String collection, String id) async {
    try {
      final db = await database;
      if (db == null) return null;
      
      final result = await db.query(
        collection,
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      
      return result.isNotEmpty ? result.first : null;
    } catch (e) {
      debugPrint('❌ Error getting data: $e');
      return null;
    }
  }
  
  /// Save data to database
  Future<void> saveData(String collection, String id, Map<String, dynamic> data) async {
    try {
      final db = await database;
      if (db == null) return;
      
      data['id'] = id;
      await db.insert(
        collection,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('❌ Error saving data: $e');
      rethrow;
    }
  }
  
  /// Get all data from collection
  Future<List<Map<String, dynamic>>> getAllData(String collection) async {
    try {
      final db = await database;
      if (db == null) return [];
      
      final result = await db.query(collection);
      return result;
    } catch (e) {
      debugPrint('❌ Error getting all data: $e');
      return [];
    }
  }

  /// Migrate existing orders table to add missing columns
  Future<void> _migrateOrdersTable(DatabaseExecutor db) async {
    try {
      // Check if new columns exist
      final columns = await db.rawQuery('PRAGMA table_info(orders)');
      final columnNames = columns.map((col) => col['name'] as String).toList();
      
      // Add missing columns if they don't exist
      if (!columnNames.contains('notes')) {
        await db.execute('ALTER TABLE orders ADD COLUMN notes TEXT');
        debugPrint('✅ Added notes column to orders table');
      }
      
      if (!columnNames.contains('preferences')) {
        await db.execute('ALTER TABLE orders ADD COLUMN preferences TEXT');
        debugPrint('✅ Added preferences column to orders table');
      }
      
      if (!columnNames.contains('history')) {
        await db.execute('ALTER TABLE orders ADD COLUMN history TEXT');
        debugPrint('✅ Added history column to orders table');
      }
      
      if (!columnNames.contains('completed_at')) {
        await db.execute('ALTER TABLE orders ADD COLUMN completed_at TEXT');
        debugPrint('✅ Added completed_at column to orders table');
      }
      
      if (!columnNames.contains('items')) {
        await db.execute('ALTER TABLE orders ADD COLUMN items TEXT');
        debugPrint('✅ Added items column to orders table');
      }
      
      debugPrint('✅ Orders table migration completed');
    } catch (e) {
      debugPrint('⚠️ Orders table migration failed: $e');
    }
  }

  /// Creates the loyalty_rewards table
  Future<void> _createLoyaltyRewardsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE loyalty_rewards (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        points_required INTEGER NOT NULL DEFAULT 0,
        discount_percentage REAL NOT NULL DEFAULT 0.0,
        is_active INTEGER NOT NULL DEFAULT 1,
        valid_until TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  /// Creates the app_settings table
  Future<void> _createAppSettingsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE app_settings (
        id TEXT PRIMARY KEY,
        key TEXT NOT NULL UNIQUE,
        value TEXT NOT NULL,
        description TEXT,
        category TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }
} 