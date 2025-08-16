import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

enum InventoryUnit {
  pieces,
  grams,
  kilograms,
  liters,
  milliliters,
  ounces,
  pounds,
  units,
}

enum InventoryCategory {
  produce,
  meat,
  dairy,
  pantry,
  beverages,
  spices,
  frozen,
  other;

  String get categoryDisplay {
    switch (this) {
      case InventoryCategory.produce:
        return 'Produce';
      case InventoryCategory.meat:
        return 'Meat';
      case InventoryCategory.dairy:
        return 'Dairy';
      case InventoryCategory.pantry:
        return 'Pantry';
      case InventoryCategory.beverages:
        return 'Beverages';
      case InventoryCategory.spices:
        return 'Spices';
      case InventoryCategory.frozen:
        return 'Frozen';
      case InventoryCategory.other:
        return 'Other';
    }
  }
}

/// Represents an inventory item in the POS system.
class InventoryItem {
  final String id;
  final String name;
  final String? description;
  final InventoryCategory category;
  final InventoryUnit unit;
  final double currentStock;
  final double minimumStock;
  final double maximumStock;
  final double costPerUnit;
  final String? supplier;
  final String? supplierContact;
  final DateTime? lastRestocked;
  final DateTime? expiryDate;
  final bool isActive;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Creates an [InventoryItem].
  InventoryItem({
    String? id,
    required this.name,
    this.description,
    required this.category,
    required this.unit,
    required this.currentStock,
    required this.minimumStock,
    required this.maximumStock,
    required this.costPerUnit,
    this.supplier,
    this.supplierContact,
    this.lastRestocked,
    this.expiryDate,
    this.isActive = true,
    this.metadata = const {},
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    id = id ?? const Uuid().v4(),
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now();

  /// Returns a copy of this [InventoryItem] with updated fields.
  InventoryItem copyWith({
    String? id,
    String? name,
    String? description,
    InventoryCategory? category,
    InventoryUnit? unit,
    double? currentStock,
    double? minimumStock,
    double? maximumStock,
    double? costPerUnit,
    String? supplier,
    String? supplierContact,
    DateTime? lastRestocked,
    DateTime? expiryDate,
    bool? isActive,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      currentStock: currentStock ?? this.currentStock,
      minimumStock: minimumStock ?? this.minimumStock,
      maximumStock: maximumStock ?? this.maximumStock,
      costPerUnit: costPerUnit ?? this.costPerUnit,
      supplier: supplier ?? this.supplier,
      supplierContact: supplierContact ?? this.supplierContact,
      lastRestocked: lastRestocked ?? this.lastRestocked,
      expiryDate: expiryDate ?? this.expiryDate,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Creates an [InventoryItem] from JSON.
  factory InventoryItem.fromJson(Map<String, dynamic> json) {
    try {
      // Validate required fields
      if (json['name'] == null || json['name'].toString().isEmpty) {
        throw Exception('Inventory item name is required but was null or empty');
      }
      
      return InventoryItem(
        id: json['id'] as String? ?? const Uuid().v4(),
        name: json['name'] as String,
        description: json['description'] as String?,
        category: InventoryCategory.values.firstWhere(
          (e) => e.toString().split('.').last == (json['category'] ?? '').toString(),
          orElse: () => InventoryCategory.other,
        ),
        unit: InventoryUnit.values.firstWhere(
          (e) => e.toString().split('.').last == (json['unit'] ?? '').toString(),
          orElse: () => InventoryUnit.pieces,
        ),
        currentStock: (json['currentStock'] as num?)?.toDouble() ?? 0.0,
        minimumStock: (json['minimumStock'] as num?)?.toDouble() ?? 0.0,
        maximumStock: (json['maximumStock'] as num?)?.toDouble() ?? 0.0,
        costPerUnit: (json['costPerUnit'] as num?)?.toDouble() ?? 0.0,
        supplier: json['supplier'] as String?,
        supplierContact: json['supplierContact'] as String?,
        lastRestocked: json['lastRestocked'] != null ? DateTime.tryParse(json['lastRestocked']) : null,
        expiryDate: json['expiryDate'] != null ? DateTime.tryParse(json['expiryDate']) : null,
        isActive: json['isActive'] as bool? ?? true,
        metadata: json['metadata'] is Map<String, dynamic> ? Map<String, dynamic>.from(json['metadata']) : {},
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) ?? DateTime.now() : DateTime.now(),
        updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) ?? DateTime.now() : DateTime.now(),
      );
    } catch (e) {
      debugPrint('Error parsing InventoryItem from JSON: $e');
      debugPrint('JSON data: $json');
      debugPrint('Stack trace: ${StackTrace.current}');
      
      // Return a default error item instead of throwing
      return InventoryItem(
        name: 'Error Item - ${json['name'] ?? 'Unknown'}',
        category: InventoryCategory.other,
        unit: InventoryUnit.pieces,
        currentStock: 0,
        minimumStock: 0,
        maximumStock: 0,
        costPerUnit: 0,
      );
    }
  }

  /// Converts this [InventoryItem] to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category.toString().split('.').last,
      'unit': unit.toString().split('.').last,
      'currentStock': currentStock,
      'minimumStock': minimumStock,
      'maximumStock': maximumStock,
      'costPerUnit': costPerUnit,
      'supplier': supplier,
      'supplierContact': supplierContact,
      'lastRestocked': lastRestocked?.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
      'isActive': isActive,
      'metadata': metadata,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Helper methods
  bool get isLowStock => currentStock <= minimumStock;
  bool get isOutOfStock => currentStock <= 0;
  bool get isOverstocked => currentStock > maximumStock;
  bool get isExpired => expiryDate != null && DateTime.now().isAfter(expiryDate!);
  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final daysUntilExpiry = expiryDate!.difference(DateTime.now()).inDays;
    return daysUntilExpiry <= 7 && daysUntilExpiry >= 0;
  }

  double get totalValue => currentStock * costPerUnit;
  double get stockPercentage => maximumStock > 0 ? (currentStock / maximumStock) * 100 : 0;

  String get unitDisplay {
    switch (unit) {
      case InventoryUnit.pieces:
        return 'pcs';
      case InventoryUnit.grams:
        return 'g';
      case InventoryUnit.kilograms:
        return 'kg';
      case InventoryUnit.liters:
        return 'L';
      case InventoryUnit.milliliters:
        return 'mL';
      case InventoryUnit.ounces:
        return 'oz';
      case InventoryUnit.pounds:
        return 'lbs';
      case InventoryUnit.units:
        return 'units';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'InventoryItem{id: $id, name: $name, currentStock: $currentStock, unit: $unit}';
  }
}

/// Represents an inventory transaction (stock adjustment).
class InventoryTransaction {
  final String id;
  final String inventoryItemId;
  final String type; // 'restock', 'usage', 'waste', 'transfer', 'adjustment'
  final double quantity;
  final String? reason;
  final String? notes;
  final String? userId;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  /// Creates an [InventoryTransaction].
  InventoryTransaction({
    String? id,
    required this.inventoryItemId,
    required this.type,
    required this.quantity,
    this.reason,
    this.notes,
    this.userId,
    DateTime? timestamp,
    this.metadata = const {},
  }) : 
    id = id ?? const Uuid().v4(),
    timestamp = timestamp ?? DateTime.now();

  /// Returns a copy of this [InventoryTransaction] with updated fields.
  InventoryTransaction copyWith({
    String? id,
    String? inventoryItemId,
    String? type,
    double? quantity,
    String? reason,
    String? notes,
    String? userId,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return InventoryTransaction(
      id: id ?? this.id,
      inventoryItemId: inventoryItemId ?? this.inventoryItemId,
      type: type ?? this.type,
      quantity: quantity ?? this.quantity,
      reason: reason ?? this.reason,
      notes: notes ?? this.notes,
      userId: userId ?? this.userId,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Creates an [InventoryTransaction] from JSON.
  factory InventoryTransaction.fromJson(Map<String, dynamic> json) {
    try {
      return InventoryTransaction(
        id: json['id'] as String? ?? const Uuid().v4(),
        inventoryItemId: json['inventoryItemId'] as String,
        type: json['type'] as String,
        quantity: (json['quantity'] as num).toDouble(),
        reason: json['reason'] as String?,
        notes: json['notes'] as String?,
        userId: json['userId'] as String?,
        timestamp: json['timestamp'] != null ? DateTime.tryParse(json['timestamp']) ?? DateTime.now() : DateTime.now(),
        metadata: json['metadata'] is Map<String, dynamic> ? Map<String, dynamic>.from(json['metadata']) : {},
      );
    } catch (e) {
      debugPrint('Error parsing InventoryTransaction from JSON: $e, data: $json');
      return InventoryTransaction(
        inventoryItemId: 'error',
        type: 'error',
        quantity: 0,
      );
    }
  }

  /// Converts this [InventoryTransaction] to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'inventoryItemId': inventoryItemId,
      'type': type,
      'quantity': quantity,
      'reason': reason,
      'notes': notes,
      'userId': userId,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InventoryTransaction &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'InventoryTransaction{id: $id, type: $type, quantity: $quantity, timestamp: $timestamp}';
  }
} 