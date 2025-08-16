import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

/// Represents a menu category in the POS system.
class Category {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final bool isActive;
  final int sortOrder;
  final int? iconCodePoint;
  final int? colorValue;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Creates a [Category].
  Category({
    String? id,
    required this.name,
    this.description,
    this.imageUrl,
    this.isActive = true,
    this.sortOrder = 0,
    this.iconCodePoint,
    this.colorValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    id = id ?? const Uuid().v4(),
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now();

  /// Gets the icon for this category.
  IconData get icon {
    if (iconCodePoint != null) {
      // Use a predefined set of icons to avoid tree-shaking issues
      switch (iconCodePoint!) {
        case 0xe532: // restaurant
          return Icons.restaurant;
        case 0xe533: // restaurant_menu
          return Icons.restaurant_menu;
        case 0xe534: // local_pizza
          return Icons.local_pizza;
        case 0xe535: // local_cafe
          return Icons.local_cafe;
        case 0xe536: // local_bar
          return Icons.local_bar;
        case 0xe537: // local_dining
          return Icons.local_dining;
        case 0xe538: // fastfood
          return Icons.fastfood;
        case 0xe539: // cake
          return Icons.cake;
        case 0xe53a: // coffee
          return Icons.coffee;
        case 0xe53b: // wine_bar
          return Icons.wine_bar;
        default:
          return Icons.restaurant_menu;
      }
    }
    return Icons.restaurant_menu;
  }
  
  /// Gets the color for this category.
  Color get color => Color(colorValue ?? Colors.blue.toARGB32());

  /// Creates a [Category] from JSON, with null safety and defaults.
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String? ?? const Uuid().v4(),
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      isActive: (json['is_active'] as int?) == 1,
      sortOrder: json['sort_order'] as int? ?? 0,
      iconCodePoint: json['icon_code_point'] as int?,
      colorValue: json['color_value'] as int?,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  /// Converts this [Category] to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'image_url': imageUrl,
      'is_active': isActive ? 1 : 0,
      'sort_order': sortOrder,
      'icon_code_point': iconCodePoint,
      'color_value': colorValue,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Returns a copy of this [Category] with updated fields.
  Category copyWith({
    String? id,
    String? name,
    String? description,
    String? imageUrl,
    bool? isActive,
    int? sortOrder,
    int? iconCodePoint,
    int? colorValue,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      isActive: isActive ?? this.isActive,
      sortOrder: sortOrder ?? this.sortOrder,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Category && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 