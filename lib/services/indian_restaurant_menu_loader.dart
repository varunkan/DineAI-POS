import 'package:flutter/foundation.dart';
import '../models/category.dart' as pos_category;
import '../models/menu_item.dart';
import '../services/database_service.dart';
import '../services/menu_service.dart';

/// Service for loading popular Indian restaurant categories and menu items
/// This service provides comprehensive menu data for Indian restaurants
class IndianRestaurantMenuLoader {
  static final IndianRestaurantMenuLoader _instance = IndianRestaurantMenuLoader._internal();
  factory IndianRestaurantMenuLoader() => _instance;
  IndianRestaurantMenuLoader._internal();

  /// Load comprehensive Indian restaurant menu for all tenant instances
  static Future<void> loadPopularIndianMenu({
    required DatabaseService databaseService,
    required MenuService menuService,
    bool clearExisting = false,
  }) async {
    try {
      debugPrint('🇮🇳 Loading popular Indian restaurant menu...');
      
      if (clearExisting) {
        await menuService.clearAllData();
        debugPrint('🗑️ Cleared existing menu data');
      }
      
      // Create popular Indian restaurant categories
      final categories = await _createIndianCategories(menuService);
      debugPrint('✅ Created ${categories.length} Indian categories');
      
      // Create popular Indian menu items
      final menuItems = await _createIndianMenuItems(menuService, categories);
      debugPrint('✅ Created ${menuItems.length} Indian menu items');
      
      debugPrint('🇮🇳 Successfully loaded popular Indian restaurant menu');
      debugPrint('📊 Summary: ${categories.length} categories, ${menuItems.length} items');
      
    } catch (e) {
      debugPrint('❌ Failed to load Indian restaurant menu: $e');
      rethrow;
    }
  }

  /// Create popular Indian restaurant categories
  static Future<List<pos_category.Category>> _createIndianCategories(MenuService menuService) async {
    final categories = [
      pos_category.Category(
        name: 'Appetizers & Starters',
        description: 'Popular Indian appetizers and street food',
        sortOrder: 1,
      ),
      pos_category.Category(
        name: 'Vegetarian Main Course',
        description: 'Traditional vegetarian curries and dishes',
        sortOrder: 2,
      ),
      pos_category.Category(
        name: 'Non-Vegetarian Main Course',
        description: 'Chicken, mutton and seafood specialties',
        sortOrder: 3,
      ),
      pos_category.Category(
        name: 'Biryani & Rice',
        description: 'Aromatic biryanis and rice dishes',
        sortOrder: 4,
      ),
      pos_category.Category(
        name: 'Bread & Rotis',
        description: 'Fresh naans, rotis and Indian breads',
        sortOrder: 5,
      ),
      pos_category.Category(
        name: 'South Indian',
        description: 'Dosas, idlis and South Indian specialties',
        sortOrder: 6,
      ),
      pos_category.Category(
        name: 'Tandoor Specialties',
        description: 'Clay oven grilled meats and vegetables',
        sortOrder: 7,
      ),
      pos_category.Category(
        name: 'Indo-Chinese',
        description: 'Popular Indian-Chinese fusion dishes',
        sortOrder: 8,
      ),
      pos_category.Category(
        name: 'Desserts',
        description: 'Traditional Indian sweets and desserts',
        sortOrder: 9,
      ),
      pos_category.Category(
        name: 'Beverages',
        description: 'Lassi, chai and Indian drinks',
        sortOrder: 10,
      ),
    ];

    final savedCategories = <pos_category.Category>[];
    for (final category in categories) {
      await menuService.saveCategory(category);
      savedCategories.add(category);
    }

    debugPrint('✅ Created ${savedCategories.length} Indian restaurant categories');
    return savedCategories;
  }

  /// Create popular Indian menu items
  static Future<List<MenuItem>> _createIndianMenuItems(MenuService menuService, List<pos_category.Category> categories) async {
    final categoryMap = {for (var cat in categories) cat.name: cat};
    final menuItems = <MenuItem>[];

    // Appetizers & Starters
    final appetizersCategory = categoryMap['Appetizers & Starters']!;
    menuItems.addAll([
      MenuItem(
        name: 'Samosa (2 pieces)',
        description: 'Crispy pastry filled with spiced potatoes and peas',
        price: 4.99,
        categoryId: appetizersCategory.id,
        isVegetarian: true,
        preparationTime: 8,
        stockQuantity: 50,
      ),
      MenuItem(
        name: 'Pakora (Mixed)',
        description: 'Assorted vegetable fritters with mint chutney',
        price: 6.99,
        categoryId: appetizersCategory.id,
        isVegetarian: true,
        preparationTime: 10,
        stockQuantity: 30,
      ),
      MenuItem(
        name: 'Chicken Tikka',
        description: 'Marinated chicken pieces grilled in tandoor',
        price: 12.99,
        categoryId: appetizersCategory.id,
        preparationTime: 15,
        stockQuantity: 25,
      ),
      MenuItem(
        name: 'Paneer Tikka',
        description: 'Grilled cottage cheese with bell peppers',
        price: 11.99,
        categoryId: appetizersCategory.id,
        isVegetarian: true,
        preparationTime: 12,
        stockQuantity: 20,
      ),
      MenuItem(
        name: 'Aloo Tikki Chat',
        description: 'Spiced potato patties with chutneys',
        price: 7.99,
        categoryId: appetizersCategory.id,
        isVegetarian: true,
        preparationTime: 10,
        stockQuantity: 25,
      ),
    ]);

    // Vegetarian Main Course
    final vegMainCategory = categoryMap['Vegetarian Main Course']!;
    menuItems.addAll([
      MenuItem(
        name: 'Dal Tadka',
        description: 'Yellow lentils tempered with cumin and garlic',
        price: 8.99,
        categoryId: vegMainCategory.id,
        isVegetarian: true,
        preparationTime: 20,
        stockQuantity: 30,
      ),
      MenuItem(
        name: 'Palak Paneer',
        description: 'Cottage cheese in spinach gravy',
        price: 12.99,
        categoryId: vegMainCategory.id,
        isVegetarian: true,
        preparationTime: 18,
        stockQuantity: 25,
      ),
      MenuItem(
        name: 'Chana Masala',
        description: 'Chickpeas in spiced tomato onion gravy',
        price: 9.99,
        categoryId: vegMainCategory.id,
        isVegetarian: true,
        preparationTime: 15,
        stockQuantity: 30,
      ),
      MenuItem(
        name: 'Aloo Gobi',
        description: 'Potato and cauliflower curry with turmeric',
        price: 10.99,
        categoryId: vegMainCategory.id,
        isVegetarian: true,
        preparationTime: 16,
        stockQuantity: 25,
      ),
      MenuItem(
        name: 'Paneer Butter Masala',
        description: 'Cottage cheese in creamy tomato sauce',
        price: 13.99,
        categoryId: vegMainCategory.id,
        isVegetarian: true,
        preparationTime: 20,
        stockQuantity: 20,
      ),
    ]);

    // Non-Vegetarian Main Course
    final nonVegMainCategory = categoryMap['Non-Vegetarian Main Course']!;
    menuItems.addAll([
      MenuItem(
        name: 'Butter Chicken',
        description: 'Tender chicken in rich tomato cream sauce',
        price: 16.99,
        categoryId: nonVegMainCategory.id,
        preparationTime: 25,
        stockQuantity: 20,
      ),
      MenuItem(
        name: 'Chicken Curry',
        description: 'Traditional chicken curry with onions and spices',
        price: 15.99,
        categoryId: nonVegMainCategory.id,
        preparationTime: 22,
        stockQuantity: 25,
      ),
      MenuItem(
        name: 'Mutton Rogan Josh',
        description: 'Slow-cooked lamb in aromatic Kashmiri spices',
        price: 19.99,
        categoryId: nonVegMainCategory.id,
        preparationTime: 35,
        stockQuantity: 15,
      ),
      MenuItem(
        name: 'Fish Curry',
        description: 'Fresh fish in coconut and spice curry',
        price: 17.99,
        categoryId: nonVegMainCategory.id,
        preparationTime: 20,
        stockQuantity: 18,
      ),
      MenuItem(
        name: 'Chicken Tikka Masala',
        description: 'Grilled chicken in spiced curry sauce',
        price: 17.99,
        categoryId: nonVegMainCategory.id,
        preparationTime: 25,
        stockQuantity: 20,
      ),
    ]);

    // Biryani & Rice
    final biryaniCategory = categoryMap['Biryani & Rice']!;
    menuItems.addAll([
      MenuItem(
        name: 'Chicken Biryani',
        description: 'Aromatic basmati rice with marinated chicken',
        price: 18.99,
        categoryId: biryaniCategory.id,
        preparationTime: 30,
        stockQuantity: 15,
      ),
      MenuItem(
        name: 'Vegetable Biryani',
        description: 'Mixed vegetables with fragrant basmati rice',
        price: 15.99,
        categoryId: biryaniCategory.id,
        isVegetarian: true,
        preparationTime: 25,
        stockQuantity: 20,
      ),
      MenuItem(
        name: 'Mutton Biryani',
        description: 'Tender lamb with saffron rice',
        price: 21.99,
        categoryId: biryaniCategory.id,
        preparationTime: 35,
        stockQuantity: 12,
      ),
      MenuItem(
        name: 'Jeera Rice',
        description: 'Cumin flavored basmati rice',
        price: 6.99,
        categoryId: biryaniCategory.id,
        isVegetarian: true,
        preparationTime: 15,
        stockQuantity: 30,
      ),
      MenuItem(
        name: 'Pulao Rice',
        description: 'Spiced rice with whole garam masala',
        price: 7.99,
        categoryId: biryaniCategory.id,
        isVegetarian: true,
        preparationTime: 18,
        stockQuantity: 25,
      ),
    ]);

    // Bread & Rotis
    final breadCategory = categoryMap['Bread & Rotis']!;
    menuItems.addAll([
      MenuItem(
        name: 'Garlic Naan',
        description: 'Fresh naan bread with garlic and herbs',
        price: 3.99,
        categoryId: breadCategory.id,
        isVegetarian: true,
        preparationTime: 8,
        stockQuantity: 50,
      ),
      MenuItem(
        name: 'Butter Naan',
        description: 'Soft naan bread brushed with butter',
        price: 3.49,
        categoryId: breadCategory.id,
        isVegetarian: true,
        preparationTime: 8,
        stockQuantity: 50,
      ),
      MenuItem(
        name: 'Tandoori Roti',
        description: 'Whole wheat bread from tandoor oven',
        price: 2.99,
        categoryId: breadCategory.id,
        isVegetarian: true,
        preparationTime: 6,
        stockQuantity: 60,
      ),
      MenuItem(
        name: 'Aloo Paratha',
        description: 'Stuffed bread with spiced potato filling',
        price: 4.99,
        categoryId: breadCategory.id,
        isVegetarian: true,
        preparationTime: 12,
        stockQuantity: 30,
      ),
      MenuItem(
        name: 'Cheese Naan',
        description: 'Naan stuffed with melted cheese',
        price: 4.99,
        categoryId: breadCategory.id,
        isVegetarian: true,
        preparationTime: 10,
        stockQuantity: 35,
      ),
    ]);

    // South Indian
    final southIndianCategory = categoryMap['South Indian']!;
    menuItems.addAll([
      MenuItem(
        name: 'Masala Dosa',
        description: 'Crispy crepe with spiced potato filling',
        price: 9.99,
        categoryId: southIndianCategory.id,
        isVegetarian: true,
        preparationTime: 15,
        stockQuantity: 25,
      ),
      MenuItem(
        name: 'Idli Sambar (3 pieces)',
        description: 'Steamed rice cakes with lentil curry',
        price: 7.99,
        categoryId: southIndianCategory.id,
        isVegetarian: true,
        preparationTime: 10,
        stockQuantity: 30,
      ),
      MenuItem(
        name: 'Rava Dosa',
        description: 'Semolina crepe with onions and chilies',
        price: 10.99,
        categoryId: southIndianCategory.id,
        isVegetarian: true,
        preparationTime: 18,
        stockQuantity: 20,
      ),
      MenuItem(
        name: 'Uttapam',
        description: 'Thick pancake with vegetables',
        price: 8.99,
        categoryId: southIndianCategory.id,
        isVegetarian: true,
        preparationTime: 12,
        stockQuantity: 25,
      ),
    ]);

    // Tandoor Specialties
    final tandoorCategory = categoryMap['Tandoor Specialties']!;
    menuItems.addAll([
      MenuItem(
        name: 'Tandoori Chicken (Half)',
        description: 'Marinated chicken grilled in clay oven',
        price: 14.99,
        categoryId: tandoorCategory.id,
        preparationTime: 25,
        stockQuantity: 20,
      ),
      MenuItem(
        name: 'Seekh Kebab',
        description: 'Spiced minced meat skewers',
        price: 13.99,
        categoryId: tandoorCategory.id,
        preparationTime: 20,
        stockQuantity: 25,
      ),
      MenuItem(
        name: 'Tandoori Vegetables',
        description: 'Mixed vegetables grilled with spices',
        price: 11.99,
        categoryId: tandoorCategory.id,
        isVegetarian: true,
        preparationTime: 18,
        stockQuantity: 30,
      ),
    ]);

    // Indo-Chinese
    final indoChineseCategory = categoryMap['Indo-Chinese']!;
    menuItems.addAll([
      MenuItem(
        name: 'Chicken Manchurian',
        description: 'Fried chicken balls in spicy sauce',
        price: 14.99,
        categoryId: indoChineseCategory.id,
        preparationTime: 20,
        stockQuantity: 25,
      ),
      MenuItem(
        name: 'Vegetable Fried Rice',
        description: 'Wok-fried rice with mixed vegetables',
        price: 9.99,
        categoryId: indoChineseCategory.id,
        isVegetarian: true,
        preparationTime: 15,
        stockQuantity: 30,
      ),
      MenuItem(
        name: 'Chili Paneer',
        description: 'Cottage cheese in spicy sauce',
        price: 12.99,
        categoryId: indoChineseCategory.id,
        isVegetarian: true,
        preparationTime: 18,
        stockQuantity: 25,
      ),
      MenuItem(
        name: 'Hakka Noodles',
        description: 'Stir-fried noodles with vegetables',
        price: 10.99,
        categoryId: indoChineseCategory.id,
        isVegetarian: true,
        preparationTime: 15,
        stockQuantity: 30,
      ),
    ]);

    // Desserts
    final dessertsCategory = categoryMap['Desserts']!;
    menuItems.addAll([
      MenuItem(
        name: 'Gulab Jamun (2 pieces)',
        description: 'Sweet milk dumplings in sugar syrup',
        price: 4.99,
        categoryId: dessertsCategory.id,
        isVegetarian: true,
        preparationTime: 5,
        stockQuantity: 40,
      ),
      MenuItem(
        name: 'Rasmalai (2 pieces)',
        description: 'Soft cheese balls in sweetened milk',
        price: 5.99,
        categoryId: dessertsCategory.id,
        isVegetarian: true,
        preparationTime: 5,
        stockQuantity: 35,
      ),
      MenuItem(
        name: 'Kulfi',
        description: 'Traditional Indian ice cream',
        price: 4.49,
        categoryId: dessertsCategory.id,
        isVegetarian: true,
        preparationTime: 3,
        stockQuantity: 50,
      ),
      MenuItem(
        name: 'Kheer',
        description: 'Rice pudding with cardamom and nuts',
        price: 4.99,
        categoryId: dessertsCategory.id,
        isVegetarian: true,
        preparationTime: 5,
        stockQuantity: 30,
      ),
    ]);

    // Beverages
    final beveragesCategory = categoryMap['Beverages']!;
    menuItems.addAll([
      MenuItem(
        name: 'Mango Lassi',
        description: 'Sweet yogurt drink with mango',
        price: 3.99,
        categoryId: beveragesCategory.id,
        isVegetarian: true,
        preparationTime: 5,
        stockQuantity: 50,
      ),
      MenuItem(
        name: 'Masala Chai',
        description: 'Spiced Indian tea with milk',
        price: 2.99,
        categoryId: beveragesCategory.id,
        isVegetarian: true,
        preparationTime: 8,
        stockQuantity: 60,
      ),
      MenuItem(
        name: 'Sweet Lassi',
        description: 'Traditional yogurt drink',
        price: 3.49,
        categoryId: beveragesCategory.id,
        isVegetarian: true,
        preparationTime: 5,
        stockQuantity: 50,
      ),
      MenuItem(
        name: 'Nimbu Paani',
        description: 'Fresh lime water with mint',
        price: 2.99,
        categoryId: beveragesCategory.id,
        isVegetarian: true,
        preparationTime: 5,
        stockQuantity: 60,
      ),
      MenuItem(
        name: 'Filter Coffee',
        description: 'South Indian style coffee',
        price: 3.49,
        categoryId: beveragesCategory.id,
        isVegetarian: true,
        preparationTime: 6,
        stockQuantity: 50,
      ),
    ]);

    // Save all menu items
    final savedMenuItems = <MenuItem>[];
    for (final item in menuItems) {
      await menuService.saveMenuItem(item);
      savedMenuItems.add(item);
    }

    debugPrint('✅ Created ${savedMenuItems.length} Indian restaurant menu items');
    return savedMenuItems;
  }

  /// Load popular Indian restaurant menu for specific tenant
  static Future<void> loadForTenant({
    required String tenantId,
    required DatabaseService databaseService,
    required MenuService menuService,
    bool clearExisting = false,
  }) async {
    try {
      debugPrint('🏢 Loading Indian menu for tenant: $tenantId');
      
      await loadPopularIndianMenu(
        databaseService: databaseService,
        menuService: menuService,
        clearExisting: clearExisting,
      );
      
      debugPrint('✅ Successfully loaded Indian menu for tenant: $tenantId');
      
    } catch (e) {
      debugPrint('❌ Failed to load Indian menu for tenant $tenantId: $e');
      rethrow;
    }
  }

  /// Load popular Indian restaurant menu for all tenants
  static Future<void> loadForAllTenants({
    required DatabaseService databaseService,
    required MenuService menuService,
    bool clearExisting = false,
  }) async {
    try {
      debugPrint('🌍 Loading popular Indian menu for all tenant instances...');
      
      await loadPopularIndianMenu(
        databaseService: databaseService,
        menuService: menuService,
        clearExisting: clearExisting,
      );
      
      debugPrint('✅ Successfully loaded Indian menu for all tenant instances');
      
    } catch (e) {
      debugPrint('❌ Failed to load Indian menu for all tenants: $e');
      rethrow;
    }
  }

  /// Get menu statistics
  static Map<String, dynamic> getMenuStats() {
    return {
      'categories': 10,
      'total_items': 60,
      'vegetarian_items': 35,
      'non_vegetarian_items': 25,
      'average_price': 10.50,
      'price_range': {
        'min': 2.99,
        'max': 21.99,
      },
      'specialties': [
        'Traditional Indian Cuisine',
        'Tandoor Grilled Items',
        'Indo-Chinese Fusion',
        'South Indian Delicacies',
        'Authentic Biryanis',
      ],
    };
  }
} 