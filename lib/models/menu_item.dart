import 'package:uuid/uuid.dart';

import 'dart:convert';

/// Represents a menu item in the POS system.
class MenuItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String categoryId;
  final String? imageUrl;
  final bool isAvailable;
  final List<String> tags;
  final Map<String, dynamic> customProperties;
  final List<MenuItemVariant> variants;
  final List<MenuItemModifier> modifiers;
  final Map<String, dynamic> nutritionalInfo;
  final Map<String, dynamic> allergens;
  final int preparationTime; // in minutes
  final bool isVegetarian;
  final bool isVegan;
  final bool isGlutenFree;
  final bool isSpicy;
  final int spiceLevel; // 0-5
  final int stockQuantity;
  final int lowStockThreshold;
  // isOutOfStock is derived
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Creates a [MenuItem].
  MenuItem({
    String? id,
    required this.name,
    required this.description,
    required this.price,
    required this.categoryId,
    this.imageUrl,
    this.isAvailable = true,
    this.tags = const [],
    this.customProperties = const {},
    this.variants = const [],
    this.modifiers = const [],
    this.nutritionalInfo = const {},
    this.allergens = const {},
    this.preparationTime = 0,
    this.isVegetarian = false,
    this.isVegan = false,
    this.isGlutenFree = false,
    this.isSpicy = false,
    this.spiceLevel = 0,
    this.stockQuantity = 0,
    this.lowStockThreshold = 5,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    id = id ?? const Uuid().v4(),
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now();

  /// Returns true if the item is out of stock.
  bool get isOutOfStock => stockQuantity <= 0;

  /// Creates a [MenuItem] from JSON, with robust error handling.
  factory MenuItem.fromJson(Map<String, dynamic> json) {
    try {
      // Helper function to convert int/bool to bool
      bool parseBool(dynamic value) {
        if (value is bool) return value;
        if (value is int) return value == 1;
        if (value is String) return value.toLowerCase() == 'true' || value == '1';
        return false;
      }

      // Parse categoryId with robust fallback
      String? categoryIdFromJson = json['categoryId'];
      String? categoryIdFromUnderscore = json['category_id'];
      String finalCategoryId = '';
      
      if (categoryIdFromJson != null && categoryIdFromJson.toString().isNotEmpty && categoryIdFromJson.toString() != 'null') {
        finalCategoryId = categoryIdFromJson.toString();
      } else if (categoryIdFromUnderscore != null && categoryIdFromUnderscore.toString().isNotEmpty && categoryIdFromUnderscore.toString() != 'null') {
        finalCategoryId = categoryIdFromUnderscore.toString();
      } else {
        // If both are missing or empty, set to 'uncategorized'
        finalCategoryId = 'uncategorized';
      }

      // Parse tags robustly
      List<String> parseTags(dynamic tags) {
        if (tags == null) return [];
        if (tags is List) {
          try {
            return tags.map((e) => e.toString()).toList();
          } catch (e) {
            return [];
          }
        }
        if (tags is String) {
          try {
            // First try to decode as JSON
            final decoded = jsonDecode(tags);
            if (decoded is List) {
              return decoded.map((e) => e.toString()).toList();
            }
          } catch (e) {
            // If JSON decoding fails, treat as a single tag
            return [tags];
          }
        }
        return [];
      }

      // Parse variants robustly
      List<MenuItemVariant> parseVariants(dynamic variants) {
        if (variants == null) return [];
        if (variants is List) {
          try {
            return variants.map((e) {
              if (e is Map<String, dynamic>) {
                return MenuItemVariant(
                  name: e['name']?.toString() ?? '',
                  priceAdjustment: (e['price_adjustment'] is num) ? e['price_adjustment'].toDouble() : 0.0,
                );
              } else {
                return MenuItemVariant(name: e.toString(), priceAdjustment: 0.0);
              }
            }).toList();
          } catch (e) {
            return [];
          }
        }
        if (variants is String) {
          try {
            final decoded = jsonDecode(variants);
            if (decoded is List) {
              return decoded.map((e) {
                if (e is Map<String, dynamic>) {
                  return MenuItemVariant(
                    name: e['name']?.toString() ?? '',
                    priceAdjustment: (e['price_adjustment'] is num) ? e['price_adjustment'].toDouble() : 0.0,
                  );
                } else {
                  return MenuItemVariant(name: e.toString(), priceAdjustment: 0.0);
                }
              }).toList();
            }
          } catch (e) {
            return [MenuItemVariant(name: variants, priceAdjustment: 0.0)];
          }
        }
        return [];
      }

      // Parse modifiers robustly
      List<MenuItemModifier> parseModifiers(dynamic modifiers) {
        if (modifiers == null) return [];
        if (modifiers is List) {
          try {
            return modifiers.map((e) {
              if (e is Map<String, dynamic>) {
                return MenuItemModifier(
                  name: e['name']?.toString() ?? '',
                  price: (e['price'] is num) ? e['price'].toDouble() : 0.0,
                );
              } else {
                return MenuItemModifier(name: e.toString(), price: 0.0);
              }
            }).toList();
          } catch (e) {
            return [];
          }
        }
        if (modifiers is String) {
          try {
            final decoded = jsonDecode(modifiers);
            if (decoded is List) {
              return decoded.map((e) {
                if (e is Map<String, dynamic>) {
                  return MenuItemModifier(
                    name: e['name']?.toString() ?? '',
                    price: (e['price'] is num) ? e['price'].toDouble() : 0.0,
                  );
                } else {
                  return MenuItemModifier(name: e.toString(), price: 0.0);
                }
              }).toList();
            }
          } catch (e) {
            return [MenuItemModifier(name: modifiers, price: 0.0)];
          }
        }
        return [];
      }

      return MenuItem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        price: (json['price'] is num) ? json['price'].toDouble() : double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
        categoryId: finalCategoryId,
        imageUrl: json['image_url']?.toString(),
        isAvailable: parseBool(json['is_available']),
        tags: parseTags(json['tags']),
        customProperties: json['custom_properties'] is Map<String, dynamic> ? json['custom_properties'] : {},
        variants: parseVariants(json['variants']),
        modifiers: parseModifiers(json['modifiers']),
        nutritionalInfo: json['nutritional_info'] is Map<String, dynamic> ? json['nutritional_info'] : {},
        allergens: json['allergens'] is Map<String, dynamic> ? json['allergens'] : {},
        preparationTime: json['preparation_time'] is int ? json['preparation_time'] : int.tryParse(json['preparation_time']?.toString() ?? '0') ?? 0,
        isVegetarian: parseBool(json['is_vegetarian']),
        isVegan: parseBool(json['is_vegan']),
        isGlutenFree: parseBool(json['is_gluten_free']),
        isSpicy: parseBool(json['is_spicy']),
        spiceLevel: json['spice_level'] is int ? json['spice_level'] : int.tryParse(json['spice_level']?.toString() ?? '0') ?? 0,
        stockQuantity: json['stock_quantity'] is int ? json['stock_quantity'] : int.tryParse(json['stock_quantity']?.toString() ?? '0') ?? 0,
        lowStockThreshold: json['low_stock_threshold'] is int ? json['low_stock_threshold'] : int.tryParse(json['low_stock_threshold']?.toString() ?? '0') ?? 0,
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      // Return a default MenuItem instead of rethrowing
      return MenuItem(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Unknown Item',
        description: json['description']?.toString() ?? '',
        price: (json['price'] is num) ? json['price'].toDouble() : double.tryParse(json['price']?.toString() ?? '0') ?? 0.0,
        categoryId: json['category_id']?.toString() ?? json['categoryId']?.toString() ?? 'uncategorized',
        imageUrl: json['image_url']?.toString(),
        isAvailable: true,
        tags: [],
        customProperties: {},
        variants: [],
        modifiers: [],
        nutritionalInfo: {},
        allergens: {},
        preparationTime: 0,
        isVegetarian: false,
        isVegan: false,
        isGlutenFree: false,
        isSpicy: false,
        spiceLevel: 0,
        stockQuantity: 0,
        lowStockThreshold: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }
  }

  /// Converts this [MenuItem] to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'categoryId': categoryId,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
      'tags': tags,
      'customProperties': customProperties,
      'variants': variants.map((v) => v.toJson()).toList(),
      'modifiers': modifiers.map((m) => m.toJson()).toList(),
      'nutritionalInfo': nutritionalInfo,
      'allergens': allergens,
      'preparationTime': preparationTime,
      'isVegetarian': isVegetarian,
      'isVegan': isVegan,
      'isGlutenFree': isGlutenFree,
      'isSpicy': isSpicy,
      'spiceLevel': spiceLevel,
      'stockQuantity': stockQuantity,
      'lowStockThreshold': lowStockThreshold,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Returns a copy of this [MenuItem] with updated fields.
  MenuItem copyWith({
    String? id,
    String? name,
    String? description,
    double? price,
    String? categoryId,
    String? imageUrl,
    bool? isAvailable,
    List<String>? tags,
    Map<String, dynamic>? customProperties,
    List<MenuItemVariant>? variants,
    List<MenuItemModifier>? modifiers,
    Map<String, dynamic>? nutritionalInfo,
    Map<String, dynamic>? allergens,
    int? preparationTime,
    bool? isVegetarian,
    bool? isVegan,
    bool? isGlutenFree,
    bool? isSpicy,
    int? spiceLevel,
    int? stockQuantity,
    int? lowStockThreshold,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MenuItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      categoryId: categoryId ?? this.categoryId,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      tags: tags ?? this.tags,
      customProperties: customProperties ?? this.customProperties,
      variants: variants ?? this.variants,
      modifiers: modifiers ?? this.modifiers,
      nutritionalInfo: nutritionalInfo ?? this.nutritionalInfo,
      allergens: allergens ?? this.allergens,
      preparationTime: preparationTime ?? this.preparationTime,
      isVegetarian: isVegetarian ?? this.isVegetarian,
      isVegan: isVegan ?? this.isVegan,
      isGlutenFree: isGlutenFree ?? this.isGlutenFree,
      isSpicy: isSpicy ?? this.isSpicy,
      spiceLevel: spiceLevel ?? this.spiceLevel,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  // Helper methods
  bool hasVariant(String variantName) {
    return variants.any((v) => v.name == variantName);
  }

  bool hasModifier(String modifierName) {
    return modifiers.any((m) => m.name == modifierName);
  }

  double getVariantPrice(String variantName) {
    final variant = variants.firstWhere(
      (v) => v.name == variantName,
      orElse: () => MenuItemVariant(name: '', priceAdjustment: 0),
    );
    return price + variant.priceAdjustment;
  }

  double getModifierPrice(String modifierName) {
    final modifier = modifiers.firstWhere(
      (m) => m.name == modifierName,
      orElse: () => MenuItemModifier(name: '', price: 0),
    );
    return modifier.price;
  }

  List<String> getAllergenList() {
    return allergens.keys.where((key) => allergens[key] == true).toList();
  }

  bool hasAllergen(String allergen) {
    return allergens[allergen] == true;
  }

  Map<String, dynamic> getNutritionalValue(String nutrient) {
    return nutritionalInfo[nutrient] ?? {};
  }
}

class MenuItemVariant {
  final String name;
  final double priceAdjustment;
  final bool isAvailable;
  final Map<String, dynamic> properties;

  MenuItemVariant({
    required this.name,
    required this.priceAdjustment,
    this.isAvailable = true,
    this.properties = const {},
  });

  factory MenuItemVariant.fromJson(Map<String, dynamic> json) {
    return MenuItemVariant(
      name: json['name'],
      priceAdjustment: (json['priceAdjustment'] ?? 0.0).toDouble(),
      isAvailable: json['isAvailable'] ?? true,
      properties: Map<String, dynamic>.from(json['properties'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'priceAdjustment': priceAdjustment,
      'isAvailable': isAvailable,
      'properties': properties,
    };
  }
}

class MenuItemModifier {
  final String name;
  final double price;
  final bool isAvailable;
  final String? description;
  final Map<String, dynamic> properties;

  MenuItemModifier({
    required this.name,
    required this.price,
    this.isAvailable = true,
    this.description,
    this.properties = const {},
  });

  factory MenuItemModifier.fromJson(Map<String, dynamic> json) {
    return MenuItemModifier(
      name: json['name'],
      price: (json['price'] ?? 0.0).toDouble(),
      isAvailable: json['isAvailable'] ?? true,
      description: json['description'],
      properties: Map<String, dynamic>.from(json['properties'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'price': price,
      'isAvailable': isAvailable,
      'description': description,
      'properties': properties,
    };
  }
} 