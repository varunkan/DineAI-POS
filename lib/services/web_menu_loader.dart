import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/menu_item.dart';
import '../models/category.dart' as pos_category;

class WebMenuLoader {
  static const String _categoriesBoxName = 'web_categories';
  static const String _menuItemsBoxName = 'web_menu_items';
  
  Box<Map>? _categoriesBox;
  Box<Map>? _menuItemsBox;
  
  static final WebMenuLoader _instance = WebMenuLoader._internal();
  factory WebMenuLoader() => _instance;
  WebMenuLoader._internal();

  /// Initialize Hive boxes for web storage
  Future<void> initialize() async {
    try {
      debugPrint('🌐 Initializing WebMenuLoader...');
      
      if (!Hive.isBoxOpen(_categoriesBoxName)) {
        _categoriesBox = await Hive.openBox<Map>(_categoriesBoxName);
      } else {
        _categoriesBox = Hive.box<Map>(_categoriesBoxName);
      }
      
      if (!Hive.isBoxOpen(_menuItemsBoxName)) {
        _menuItemsBox = await Hive.openBox<Map>(_menuItemsBoxName);
      } else {
        _menuItemsBox = Hive.box<Map>(_menuItemsBoxName);
      }
      
      debugPrint('✅ WebMenuLoader initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize WebMenuLoader: $e');
      rethrow;
    }
  }

  /// Check if the web storage is empty
  Future<bool> isEmpty() async {
    try {
      final categoriesCount = _categoriesBox?.length ?? 0;
      final menuItemsCount = _menuItemsBox?.length ?? 0;
      return categoriesCount == 0 && menuItemsCount == 0;
    } catch (e) {
      debugPrint('❌ Error checking if web storage is empty: $e');
      return true;
    }
  }

  /// Load sample categories for web storage
  Future<void> _loadSampleCategories() async {
    final sampleCategories = [
      pos_category.Category(
        id: 'cat_1',
        name: 'Appetizers',
        description: 'Start your meal with our delicious appetizers',
        sortOrder: 1,
      ),
      pos_category.Category(
        id: 'cat_2', 
        name: 'Main Course',
        description: 'Our signature main dishes',
        sortOrder: 2,
      ),
      pos_category.Category(
        id: 'cat_3',
        name: 'Desserts', 
        description: 'Sweet endings to your meal',
        sortOrder: 3,
      ),
      pos_category.Category(
        id: 'cat_4',
        name: 'Beverages',
        description: 'Refreshing drinks and beverages',
        sortOrder: 4,
      ),
    ];

    for (final category in sampleCategories) {
      await saveCategory({
        'id': category.id,
        'name': category.name,
        'description': category.description,
        'image_url': category.imageUrl,
        'is_active': category.isActive ? 1 : 0,
        'sort_order': category.sortOrder,
        'created_at': category.createdAt.toIso8601String(),
        'updated_at': category.updatedAt.toIso8601String(),
      });
    }
  }

  /// Load the Oh Bombay Milton menu specifically
  Future<void> loadOhBombayMiltonMenu() async {
    try {
      debugPrint('🍽️ Loading Oh Bombay Milton menu...');
      
      // Oh Bombay Milton categories
      final categories = [
        pos_category.Category(
          id: 'appetizers',
          name: 'Appetizers',
          description: 'Start your meal with our delicious appetizers',
          sortOrder: 1,
        ),
        pos_category.Category(
          id: 'tandoor',
          name: 'Tandoor Specialties',
          description: 'Fresh from our traditional tandoor oven',
          sortOrder: 2,
        ),
        pos_category.Category(
          id: 'curry',
          name: 'Curry Dishes',
          description: 'Authentic Indian curry dishes',
          sortOrder: 3,
        ),
        pos_category.Category(
          id: 'biryani',
          name: 'Biryani & Rice',
          description: 'Fragrant basmati rice dishes',
          sortOrder: 4,
        ),
        pos_category.Category(
          id: 'breads',
          name: 'Indian Breads',
          description: 'Freshly baked naan and other breads',
          sortOrder: 5,
        ),
        pos_category.Category(
          id: 'beverages',
          name: 'Beverages',
          description: 'Traditional and modern drinks',
          sortOrder: 6,
        ),
      ];

      // Oh Bombay Milton menu items
      final menuItems = [
        // Appetizers
        MenuItem(
          id: 'app_samosa',
          name: 'Vegetable Samosa',
          description: 'Crispy pastry filled with spiced vegetables',
          price: 6.99,
          categoryId: 'appetizers',
          isAvailable: true,
          preparationTime: 15,
          isVegetarian: true,
        ),
        MenuItem(
          id: 'app_pakora',
          name: 'Mixed Pakora',
          description: 'Assorted vegetable fritters with mint chutney',
          price: 8.99,
          categoryId: 'appetizers',
          isAvailable: true,
          preparationTime: 12,
          isVegetarian: true,
        ),
        
        // Tandoor
        MenuItem(
          id: 'tan_chicken',
          name: 'Tandoori Chicken',
          description: 'Half chicken marinated in yogurt and spices',
          price: 18.99,
          categoryId: 'tandoor',
          isAvailable: true,
          preparationTime: 25,
        ),
        MenuItem(
          id: 'tan_naan',
          name: 'Garlic Naan',
          description: 'Fresh naan bread with garlic and herbs',
          price: 4.99,
          categoryId: 'breads',
          isAvailable: true,
          preparationTime: 8,
          isVegetarian: true,
        ),
        
        // Curry
        MenuItem(
          id: 'cur_butter',
          name: 'Butter Chicken',
          description: 'Tender chicken in creamy tomato sauce',
          price: 16.99,
          categoryId: 'curry',
          isAvailable: true,
          preparationTime: 20,
        ),
        MenuItem(
          id: 'cur_dal',
          name: 'Dal Makhani',
          description: 'Rich black lentils in creamy sauce',
          price: 13.99,
          categoryId: 'curry',
          isAvailable: true,
          preparationTime: 18,
          isVegetarian: true,
        ),
        
        // Biryani
        MenuItem(
          id: 'bir_chicken',
          name: 'Chicken Biryani',
          description: 'Fragrant basmati rice with spiced chicken',
          price: 17.99,
          categoryId: 'biryani',
          isAvailable: true,
          preparationTime: 30,
        ),
        MenuItem(
          id: 'bir_veg',
          name: 'Vegetable Biryani',
          description: 'Aromatic rice with mixed vegetables and spices',
          price: 15.99,
          categoryId: 'biryani',
          isAvailable: true,
          preparationTime: 25,
          isVegetarian: true,
        ),
        
        // Beverages
        MenuItem(
          id: 'bev_lassi',
          name: 'Mango Lassi',
          description: 'Traditional yogurt drink with mango',
          price: 4.99,
          categoryId: 'beverages',
          isAvailable: true,
          preparationTime: 5,
          isVegetarian: true,
        ),
        MenuItem(
          id: 'bev_chai',
          name: 'Masala Chai',
          description: 'Spiced Indian tea with milk',
          price: 3.99,
          categoryId: 'beverages',
          isAvailable: true,
          preparationTime: 5,
          isVegetarian: true,
        ),
      ];
      
      // Clear existing data
      await _categoriesBox!.clear();
      await _menuItemsBox!.clear();
      
      // Save categories to Hive
      for (var category in categories) {
        await _categoriesBox!.put(category.id, {
          'id': category.id,
          'name': category.name,
          'description': category.description,
          'image_url': category.imageUrl,
          'is_active': category.isActive ? 1 : 0,
          'sort_order': category.sortOrder,
          'created_at': category.createdAt.toIso8601String(),
          'updated_at': category.updatedAt.toIso8601String(),
        });
      }
      
      // Save menu items to Hive
      for (var item in menuItems) {
        await _menuItemsBox!.put(item.id, item.toJson());
      }
      
      debugPrint('✅ Oh Bombay Milton menu loaded: ${categories.length} categories, ${menuItems.length} items');
      
    } catch (e) {
      debugPrint('❌ Failed to load Oh Bombay Milton menu: $e');
      rethrow;
    }
  }

  /// Load sample menu data for web platform
  Future<void> loadSampleMenu() async {
    try {
      await initialize();
      
      // Check if menu already exists
      if (_categoriesBox!.isNotEmpty && _menuItemsBox!.isNotEmpty) {
        debugPrint('📋 Menu already loaded, skipping sample data');
        return;
      }
      
      debugPrint('🍽️ Loading sample menu for web...');
      
      // Sample categories
      final categories = [
        pos_category.Category(
          id: 'cat_1',
          name: 'Appetizers',
          description: 'Start your meal with our delicious appetizers',
          isActive: true,
          sortOrder: 1,
        ),
        pos_category.Category(
          id: 'cat_2', 
          name: 'Main Course',
          description: 'Hearty main dishes to satisfy your hunger',
          isActive: true,
          sortOrder: 2,
        ),
        pos_category.Category(
          id: 'cat_3',
          name: 'Desserts',
          description: 'Sweet treats to end your meal',
          isActive: true,
          sortOrder: 3,
        ),
        pos_category.Category(
          id: 'cat_4',
          name: 'Beverages',
          description: 'Refreshing drinks and hot beverages',
          isActive: true,
          sortOrder: 4,
        ),
      ];
      
      // Sample menu items
      final menuItems = [
        // Appetizers
        MenuItem(
          id: 'item_1',
          name: 'Chicken Wings',
          description: 'Crispy buffalo wings with ranch dipping sauce',
          price: 12.99,
          categoryId: 'cat_1',
          isAvailable: true,
          preparationTime: 15,
        ),
        MenuItem(
          id: 'item_2',
          name: 'Mozzarella Sticks',
          description: 'Golden fried mozzarella with marinara sauce',
          price: 8.99,
          categoryId: 'cat_1',
          isAvailable: true,
          preparationTime: 10,
        ),
        MenuItem(
          id: 'item_3',
          name: 'Caesar Salad',
          description: 'Fresh romaine lettuce with Caesar dressing and croutons',
          price: 9.99,
          categoryId: 'cat_1',
          isAvailable: true,
          preparationTime: 8,
        ),
        
        // Main Course
        MenuItem(
          id: 'item_4',
          name: 'Grilled Chicken Breast',
          description: 'Juicy grilled chicken with herbs and spices',
          price: 18.99,
          categoryId: 'cat_2',
          isAvailable: true,
          preparationTime: 25,
        ),
        MenuItem(
          id: 'item_5',
          name: 'Beef Burger',
          description: 'Premium beef patty with lettuce, tomato, and fries',
          price: 15.99,
          categoryId: 'cat_2',
          isAvailable: true,
          preparationTime: 20,
        ),
        MenuItem(
          id: 'item_6',
          name: 'Margherita Pizza',
          description: 'Classic pizza with fresh mozzarella and basil',
          price: 16.99,
          categoryId: 'cat_2',
          isAvailable: true,
          preparationTime: 18,
        ),
        MenuItem(
          id: 'item_7',
          name: 'Pasta Carbonara',
          description: 'Creamy pasta with bacon and parmesan cheese',
          price: 14.99,
          categoryId: 'cat_2',
          isAvailable: true,
          preparationTime: 15,
        ),
        
        // Desserts
        MenuItem(
          id: 'item_8',
          name: 'Chocolate Cake',
          description: 'Rich chocolate cake with chocolate frosting',
          price: 6.99,
          categoryId: 'cat_3',
          isAvailable: true,
          preparationTime: 5,
        ),
        MenuItem(
          id: 'item_9',
          name: 'Cheesecake',
          description: 'New York style cheesecake with berry compote',
          price: 7.99,
          categoryId: 'cat_3',
          isAvailable: true,
          preparationTime: 5,
        ),
        MenuItem(
          id: 'item_10',
          name: 'Ice Cream Sundae',
          description: 'Vanilla ice cream with chocolate sauce and whipped cream',
          price: 5.99,
          categoryId: 'cat_3',
          isAvailable: true,
          preparationTime: 3,
        ),
        
        // Beverages
        MenuItem(
          id: 'item_11',
          name: 'Coffee',
          description: 'Freshly brewed coffee',
          price: 2.99,
          categoryId: 'cat_4',
          isAvailable: true,
          preparationTime: 3,
        ),
        MenuItem(
          id: 'item_12',
          name: 'Soft Drinks',
          description: 'Coca-Cola, Pepsi, Sprite, Orange',
          price: 2.49,
          categoryId: 'cat_4',
          isAvailable: true,
          preparationTime: 1,
        ),
        MenuItem(
          id: 'item_13',
          name: 'Fresh Juice',
          description: 'Orange, Apple, or Cranberry juice',
          price: 3.99,
          categoryId: 'cat_4',
          isAvailable: true,
          preparationTime: 2,
        ),
      ];
      
      // Save categories to Hive
      await _categoriesBox!.clear();
      for (var category in categories) {
        await _categoriesBox!.put(category.id, {
          'id': category.id,
          'name': category.name,
          'description': category.description,
          'image_url': category.imageUrl,
          'is_active': category.isActive ? 1 : 0,
          'sort_order': category.sortOrder,
          'created_at': category.createdAt.toIso8601String(),
          'updated_at': category.updatedAt.toIso8601String(),
        });
      }
      
      // Save menu items to Hive
      await _menuItemsBox!.clear();
      for (var item in menuItems) {
        await _menuItemsBox!.put(item.id, item.toJson());
      }
      
      debugPrint('✅ Sample menu loaded: ${categories.length} categories, ${menuItems.length} items');
      
    } catch (e) {
      debugPrint('❌ Failed to load sample menu: $e');
      rethrow;
    }
  }

  /// Get all categories from web storage as raw data
  Future<List<Map<String, dynamic>>> getCategories() async {
    try {
      await initialize();
      
      final categories = <Map<String, dynamic>>[];
      for (var key in _categoriesBox!.keys) {
        final categoryData = _categoriesBox!.get(key);
        if (categoryData != null) {
          categories.add(Map<String, dynamic>.from(categoryData));
        }
      }
      
      // Sort by sortOrder
      categories.sort((a, b) => (a['sort_order'] as int).compareTo(b['sort_order'] as int));
      
      debugPrint('📋 Loaded ${categories.length} categories from web storage');
      return categories;
      
    } catch (e) {
      debugPrint('❌ Failed to get categories: $e');
      return [];
    }
  }

  /// Get all menu items from web storage as raw data
  Future<List<Map<String, dynamic>>> getMenuItems() async {
    try {
      await initialize();
      
      final menuItems = <Map<String, dynamic>>[];
      for (var key in _menuItemsBox!.keys) {
        final itemData = _menuItemsBox!.get(key);
        if (itemData != null) {
          menuItems.add(Map<String, dynamic>.from(itemData));
        }
      }
      
      debugPrint('🍽️ Loaded ${menuItems.length} menu items from web storage');
      return menuItems;
      
    } catch (e) {
      debugPrint('❌ Failed to get menu items: $e');
      return [];
    }
  }

  /// Get menu items by category
  Future<List<Map<String, dynamic>>> getMenuItemsByCategory(String categoryId) async {
    try {
      final allItems = await getMenuItems();
      final categoryItems = allItems.where((item) => item['category_id'] == categoryId).toList();
      
      debugPrint('📋 Found ${categoryItems.length} items for category $categoryId');
      return categoryItems;
      
    } catch (e) {
      debugPrint('❌ Failed to get menu items by category: $e');
      return [];
    }
  }

  /// Save a category to web storage
  Future<bool> saveCategory(Map<String, dynamic> category) async {
    try {
      await initialize();
      await _categoriesBox!.put(category['id'], category);
      debugPrint('✅ Category saved: ${category['name']}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to save category: $e');
      return false;
    }
  }

  /// Save a menu item to web storage
  Future<bool> saveMenuItem(Map<String, dynamic> item) async {
    try {
      await initialize();
      await _menuItemsBox!.put(item['id'], item);
      debugPrint('✅ Menu item saved: ${item['name']}');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to save menu item: $e');
      return false;
    }
  }

  /// Delete a category from web storage
  Future<bool> deleteCategory(String categoryId) async {
    try {
      await initialize();
      await _categoriesBox!.delete(categoryId);
      debugPrint('✅ Category deleted: $categoryId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to delete category: $e');
      return false;
    }
  }

  /// Delete a menu item from web storage
  Future<bool> deleteMenuItem(String itemId) async {
    try {
      await initialize();
      await _menuItemsBox!.delete(itemId);
      debugPrint('✅ Menu item deleted: $itemId');
      return true;
    } catch (e) {
      debugPrint('❌ Failed to delete menu item: $e');
      return false;
    }
  }

  /// Clear all menu data
  Future<void> clearAllData() async {
    try {
      await initialize();
      await _categoriesBox!.clear();
      await _menuItemsBox!.clear();
      debugPrint('✅ All menu data cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear menu data: $e');
    }
  }

  /// Get menu statistics
  Future<Map<String, int>> getMenuStats() async {
    try {
      final categories = await getCategories();
      final menuItems = await getMenuItems();
      
      return {
        'categories': categories.length,
        'menuItems': menuItems.length,
        'activeCategories': categories.where((c) => (c['is_active'] as int) == 1).length,
        'availableItems': menuItems.where((i) => (i['is_available'] as bool? ?? true)).length,
      };
    } catch (e) {
      debugPrint('❌ Failed to get menu stats: $e');
      return {
        'categories': 0,
        'menuItems': 0,
        'activeCategories': 0,
        'availableItems': 0,
      };
    }
  }
} 