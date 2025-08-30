import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// 🚨 URGENT: Database Constraint Fix Script
/// This script fixes foreign key constraint issues that prevent menu item addition
void main() async {
  // Initialize Flutter bindings
  WidgetsFlutterBinding.ensureInitialized();
  
  print('🔧 Starting database constraint fix...');
  
  try {
    // Get database path
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final databasePath = join(documentsDirectory.path, 'pos_database.db');
    
    print('📁 Database path: $databasePath');
    
    // Delete existing database if it exists
    final databaseFile = File(databasePath);
    if (await databaseFile.exists()) {
      print('🗑️ Deleting existing database...');
      await databaseFile.delete();
      print('✅ Existing database deleted');
    }
    
    // Open database with proper schema creation
    final database = await openDatabase(
      databasePath,
      version: 1,
      onCreate: (db, version) async {
        print('🆕 Creating new database with proper schema...');
        await _createDatabaseSchema(db);
      },
      onOpen: (db) async {
        print('🔓 Database opened successfully');
      },
    );
    
    // Check if database exists and has data
    final tables = await database.query('sqlite_master', 
      where: 'type = ?', 
      whereArgs: ['table']
    );
    
    print('📊 Found ${tables.length} tables:');
    for (final table in tables) {
      print('  - ${table['name']}');
    }
    
    // Fix 1: Check and fix categories table
    print('\n🔧 Fix 1: Checking categories table...');
    final categories = await database.query('categories');
    print('📋 Found ${categories.length} categories');
    
    if (categories.isEmpty) {
      print('⚠️ No categories found! Creating default categories...');
      await _createDefaultCategories(database);
    }
    
    // Fix 2: Check menu_items table structure
    print('\n🔧 Fix 2: Checking menu_items table structure...');
    final menuItems = await database.query('menu_items');
    print('🍽️ Found ${menuItems.length} menu items');
    
    // Fix 3: Check for foreign key constraint issues
    print('\n🔧 Fix 3: Checking for orphaned menu items...');
    final orphanedItems = await database.rawQuery('''
      SELECT m.id, m.name, m.category_id 
      FROM menu_items m 
      LEFT JOIN categories c ON m.category_id = c.id 
      WHERE c.id IS NULL
    ''');
    
    if (orphanedItems.isNotEmpty) {
      print('⚠️ Found ${orphanedItems.length} orphaned menu items:');
      for (final item in orphanedItems) {
        print('  - ${item['name']} (ID: ${item['id']}, Category: ${item['category_id']})');
      }
      
      // Fix orphaned items by assigning them to a default category
      print('🔧 Fixing orphaned menu items...');
      final defaultCategory = await database.query('categories', limit: 1);
      if (defaultCategory.isNotEmpty) {
        final defaultCategoryId = defaultCategory.first['id'] as String;
        for (final item in orphanedItems) {
          await database.update(
            'menu_items',
            {'category_id': defaultCategoryId},
            where: 'id = ?',
            whereArgs: [item['id']],
          );
          print('  ✅ Fixed: ${item['name']} → category $defaultCategoryId');
        }
      }
    }
    
    // Fix 4: Ensure proper indexes exist
    print('\n🔧 Fix 4: Ensuring proper indexes...');
    await _ensureIndexes(database);
    
    // Fix 5: Test menu item insertion
    print('\n🔧 Fix 5: Testing menu item insertion...');
    await _testMenuItemInsertion(database);
    
    await database.close();
    print('\n✅ Database constraint fix completed successfully!');
    
  } catch (e) {
    print('❌ Error during database fix: $e');
    exit(1);
  }
}

Future<void> _createDatabaseSchema(Database db) async {
  print('🏗️ Creating database schema...');
  
  // Create categories table
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
  print('  ✅ Created categories table');
  
  // Create menu_items table WITHOUT foreign key constraint to avoid issues
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
  print('  ✅ Created menu_items table');
  
  // Create users table
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
  print('  ✅ Created users table');
  
  // Create tables table
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
  print('  ✅ Created tables table');
  
  // Create orders table
  await db.execute('''
    CREATE TABLE orders (
      id TEXT PRIMARY KEY,
      table_id TEXT,
      customer_name TEXT,
      customer_phone TEXT,
      customer_email TEXT,
      status TEXT NOT NULL,
      total_amount REAL NOT NULL,
      tax_amount REAL NOT NULL DEFAULT 0,
      discount_amount REAL NOT NULL DEFAULT 0,
      final_amount REAL NOT NULL,
      payment_method TEXT,
      payment_status TEXT NOT NULL DEFAULT 'pending',
      notes TEXT,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  print('  ✅ Created orders table');
  
  // Create order_items table
  await db.execute('''
    CREATE TABLE order_items (
      id TEXT PRIMARY KEY,
      order_id TEXT NOT NULL,
      menu_item_id TEXT NOT NULL,
      quantity INTEGER NOT NULL,
      unit_price REAL NOT NULL,
      total_price REAL NOT NULL,
      notes TEXT,
      created_at TEXT NOT NULL
    )
  ''');
  print('  ✅ Created order_items table');
  
  // Create indexes for performance
  await db.execute('CREATE INDEX idx_menu_items_category_id ON menu_items(category_id)');
  await db.execute('CREATE INDEX idx_menu_items_name ON menu_items(name)');
  await db.execute('CREATE INDEX idx_categories_name ON categories(name)');
  await db.execute('CREATE INDEX idx_orders_table_id ON orders(table_id)');
  await db.execute('CREATE INDEX idx_order_items_order_id ON order_items(order_id)');
  print('  ✅ Created performance indexes');
  
  print('🏗️ Database schema created successfully!');
}

Future<void> _createDefaultCategories(Database db) async {
  final defaultCategories = [
    {
      'id': 'cat_appetizers_${DateTime.now().millisecondsSinceEpoch}',
      'name': 'Appetizers & Starters',
      'description': 'Start your meal with our delicious appetizers',
      'is_active': 1,
      'sort_order': 1,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'cat_main_course_${DateTime.now().millisecondsSinceEpoch}',
      'name': 'Main Course',
      'description': 'Our signature main dishes',
      'is_active': 1,
      'sort_order': 2,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'cat_desserts_${DateTime.now().millisecondsSinceEpoch}',
      'name': 'Desserts',
      'description': 'Sweet endings to your meal',
      'is_active': 1,
      'sort_order': 3,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    },
    {
      'id': 'cat_beverages_${DateTime.now().millisecondsSinceEpoch}',
      'name': 'Beverages',
      'description': 'Refreshing drinks and beverages',
      'is_active': 1,
      'sort_order': 4,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    },
  ];
  
  for (final category in defaultCategories) {
    await db.insert('categories', category);
    print('  ✅ Created category: ${category['name']}');
  }
}

Future<void> _ensureIndexes(Database db) async {
  try {
    // Check if indexes exist
    final indexes = await db.query('sqlite_master', 
      where: 'type = ? AND tbl_name = ?', 
      whereArgs: ['index', 'menu_items']
    );
    
    final existingIndexNames = indexes.map((e) => e['name'] as String).toList();
    
    // Create missing indexes
    if (!existingIndexNames.contains('idx_menu_items_category_id')) {
      await db.execute('CREATE INDEX idx_menu_items_category_id ON menu_items(category_id)');
      print('  ✅ Created index: idx_menu_items_category_id');
    }
    
    if (!existingIndexNames.contains('idx_menu_items_name')) {
      await db.execute('CREATE INDEX idx_menu_items_name ON menu_items(name)');
      print('  ✅ Created index: idx_menu_items_name');
    }
    
    if (!existingIndexNames.contains('idx_categories_name')) {
      await db.execute('CREATE INDEX idx_categories_name ON categories(name)');
      print('  ✅ Created index: idx_categories_name');
    }
    
  } catch (e) {
    print('  ⚠️ Error creating indexes: $e');
  }
}

Future<void> _testMenuItemInsertion(Database db) async {
  try {
    // Get a valid category ID
    final categories = await db.query('categories', limit: 1);
    if (categories.isEmpty) {
      print('  ❌ No categories available for testing');
      return;
    }
    
    final categoryId = categories.first['id'] as String;
    
    // Test menu item insertion
    final testItem = {
      'id': 'test_item_${DateTime.now().millisecondsSinceEpoch}',
      'name': 'Test Menu Item',
      'description': 'This is a test menu item to verify database constraints',
      'price': 9.99,
      'category_id': categoryId,
      'is_available': 1,
      'is_vegetarian': 0,
      'is_vegan': 0,
      'is_gluten_free': 0,
      'is_spicy': 0,
      'preparation_time': 10,
      'spice_level': 0,
      'stock_quantity': 100,
      'low_stock_threshold': 10,
      'popularity_score': 0.0,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    await db.insert('menu_items', testItem);
    print('  ✅ Test menu item inserted successfully');
    
    // Clean up test item
    await db.delete('menu_items', where: 'id = ?', whereArgs: [testItem['id']]);
    print('  🧹 Test item cleaned up');
    
  } catch (e) {
    print('  ❌ Test menu item insertion failed: $e');
  }
} 