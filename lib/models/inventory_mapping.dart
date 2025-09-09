import 'package:uuid/uuid.dart';

class InventoryRecipeLink {
  final String id;
  final String inventoryItemId;
  final String menuItemId;
  final double consumptionPerOrder; // how much inventory to deduct per 1 order of the menu item
  final DateTime createdAt;
  final DateTime updatedAt;

  InventoryRecipeLink({
    String? id,
    required this.inventoryItemId,
    required this.menuItemId,
    required this.consumptionPerOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) :
    id = id ?? const Uuid().v4(),
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now();

  InventoryRecipeLink copyWith({
    String? id,
    String? inventoryItemId,
    String? menuItemId,
    double? consumptionPerOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InventoryRecipeLink(
      id: id ?? this.id,
      inventoryItemId: inventoryItemId ?? this.inventoryItemId,
      menuItemId: menuItemId ?? this.menuItemId,
      consumptionPerOrder: consumptionPerOrder ?? this.consumptionPerOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory InventoryRecipeLink.fromJson(Map<String, dynamic> json) {
    return InventoryRecipeLink(
      id: json['id'] as String?,
      inventoryItemId: json['inventoryItemId'] as String,
      menuItemId: json['menuItemId'] as String,
      consumptionPerOrder: (json['consumptionPerOrder'] as num).toDouble(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'inventoryItemId': inventoryItemId,
      'menuItemId': menuItemId,
      'consumptionPerOrder': consumptionPerOrder,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
} 