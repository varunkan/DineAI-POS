import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum for different printer types
enum PrinterTypeCategory {
  receipt,
  tandoor,
  curry,
  expo,
}

/// Extension to get display names and colors for printer types
extension PrinterTypeCategoryExtension on PrinterTypeCategory {
  String get displayName {
    switch (this) {
      case PrinterTypeCategory.receipt:
        return 'Receipt Printer';
      case PrinterTypeCategory.tandoor:
        return 'Tandoor Printer';
      case PrinterTypeCategory.curry:
        return 'Curry Printer';
      case PrinterTypeCategory.expo:
        return 'Expo Printer';
    }
  }

  String get shortName {
    switch (this) {
      case PrinterTypeCategory.receipt:
        return 'Receipt';
      case PrinterTypeCategory.tandoor:
        return 'Tandoor';
      case PrinterTypeCategory.curry:
        return 'Curry';
      case PrinterTypeCategory.expo:
        return 'Expo';
    }
  }

  String get icon {
    switch (this) {
      case PrinterTypeCategory.receipt:
        return '🧾';
      case PrinterTypeCategory.tandoor:
        return '🔥';
      case PrinterTypeCategory.curry:
        return '🍛';
      case PrinterTypeCategory.expo:
        return '📋';
    }
  }

  String get color {
    switch (this) {
      case PrinterTypeCategory.receipt:
        return '#4CAF50'; // Green
      case PrinterTypeCategory.tandoor:
        return '#FF9800'; // Orange
      case PrinterTypeCategory.curry:
        return '#9C27B0'; // Purple
      case PrinterTypeCategory.expo:
        return '#2196F3'; // Blue
    }
  }
}

/// Model for printer type configuration
class PrinterTypeConfiguration {
  final String id;
  final PrinterTypeCategory type;
  final String name;
  final String description;
  final List<String> assignedPrinterIds;
  final List<String> assignedCategoryIds;
  final List<String> assignedItemIds;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String restaurantId;

  PrinterTypeConfiguration({
    required this.id,
    required this.type,
    required this.name,
    required this.description,
    required this.assignedPrinterIds,
    required this.assignedCategoryIds,
    required this.assignedItemIds,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.restaurantId,
  });

  /// Create from Firestore document
  factory PrinterTypeConfiguration.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return PrinterTypeConfiguration(
      id: doc.id,
      type: PrinterTypeCategory.values.firstWhere(
        (e) => e.toString() == data['type'],
        orElse: () => PrinterTypeCategory.receipt,
      ),
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      assignedPrinterIds: List<String>.from(data['assignedPrinterIds'] ?? []),
      assignedCategoryIds: List<String>.from(data['assignedCategoryIds'] ?? []),
      assignedItemIds: List<String>.from(data['assignedItemIds'] ?? []),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
      restaurantId: data['restaurantId'] ?? '',
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'type': type.toString(),
      'name': name,
      'description': description,
      'assignedPrinterIds': assignedPrinterIds,
      'assignedCategoryIds': assignedCategoryIds,
      'assignedItemIds': assignedItemIds,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'restaurantId': restaurantId,
    };
  }

  /// Create a copy with updated fields
  PrinterTypeConfiguration copyWith({
    String? id,
    PrinterTypeCategory? type,
    String? name,
    String? description,
    List<String>? assignedPrinterIds,
    List<String>? assignedCategoryIds,
    List<String>? assignedItemIds,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? restaurantId,
  }) {
    return PrinterTypeConfiguration(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      description: description ?? this.description,
      assignedPrinterIds: assignedPrinterIds ?? this.assignedPrinterIds,
      assignedCategoryIds: assignedCategoryIds ?? this.assignedCategoryIds,
      assignedItemIds: assignedItemIds ?? this.assignedItemIds,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      restaurantId: restaurantId ?? this.restaurantId,
    );
  }

  /// Check if a category is assigned to this printer type
  bool isCategoryAssigned(String categoryId) {
    return assignedCategoryIds.contains(categoryId);
  }

  /// Check if an item is assigned to this printer type
  bool isItemAssigned(String itemId) {
    return assignedItemIds.contains(itemId);
  }

  /// Check if a printer is assigned to this printer type
  bool isPrinterAssigned(String printerId) {
    return assignedPrinterIds.contains(printerId);
  }

  /// Get display information
  Map<String, dynamic> getDisplayInfo() {
    return {
      'type': type.displayName,
      'shortName': type.shortName,
      'icon': type.icon,
      'color': type.color,
      'printerCount': assignedPrinterIds.length,
      'categoryCount': assignedCategoryIds.length,
      'itemCount': assignedItemIds.length,
    };
  }
}

/// Model for printer type assignment
class PrinterTypeAssignment {
  final String id;
  final String printerTypeConfigId;
  final String printerId;
  final PrinterTypeCategory printerType;
  final bool isPrimary;
  final DateTime assignedAt;
  final String assignedBy;

  PrinterTypeAssignment({
    required this.id,
    required this.printerTypeConfigId,
    required this.printerId,
    required this.printerType,
    required this.isPrimary,
    required this.assignedAt,
    required this.assignedBy,
  });

  /// Create from Firestore document
  factory PrinterTypeAssignment.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return PrinterTypeAssignment(
      id: doc.id,
      printerTypeConfigId: data['printerTypeConfigId'] ?? '',
      printerId: data['printerId'] ?? '',
      printerType: PrinterTypeCategory.values.firstWhere(
        (e) => e.toString() == data['printerType'],
        orElse: () => PrinterTypeCategory.receipt,
      ),
      isPrimary: data['isPrimary'] ?? false,
      assignedAt: (data['assignedAt'] as Timestamp).toDate(),
      assignedBy: data['assignedBy'] ?? '',
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'printerTypeConfigId': printerTypeConfigId,
      'printerId': printerId,
      'printerType': printerType.toString(),
      'isPrimary': isPrimary,
      'assignedAt': Timestamp.fromDate(assignedAt),
      'assignedBy': assignedBy,
    };
  }
}

/// Model for item/category to printer type mapping
class ItemPrinterTypeMapping {
  final String id;
  final String itemId;
  final String itemName;
  final String categoryId;
  final String categoryName;
  final PrinterTypeCategory printerType;
  final String printerTypeConfigId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String restaurantId;

  ItemPrinterTypeMapping({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.categoryId,
    required this.categoryName,
    required this.printerType,
    required this.printerTypeConfigId,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.restaurantId,
  });

  /// Create from Firestore document
  factory ItemPrinterTypeMapping.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return ItemPrinterTypeMapping(
      id: doc.id,
      itemId: data['itemId'] ?? '',
      itemName: data['itemName'] ?? '',
      categoryId: data['categoryId'] ?? '',
      categoryName: data['categoryName'] ?? '',
      printerType: PrinterTypeCategory.values.firstWhere(
        (e) => e.toString() == data['printerType'],
        orElse: () => PrinterTypeCategory.receipt,
      ),
      printerTypeConfigId: data['printerTypeConfigId'] ?? '',
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
      restaurantId: data['restaurantId'] ?? '',
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'itemId': itemId,
      'itemName': itemName,
      'categoryId': categoryId,
      'categoryName': categoryName,
      'printerType': printerType.toString(),
      'printerTypeConfigId': printerTypeConfigId,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'createdBy': createdBy,
      'restaurantId': restaurantId,
    };
  }
} 