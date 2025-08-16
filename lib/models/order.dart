import 'package:uuid/uuid.dart';
import 'package:ai_pos_system/models/menu_item.dart';
import 'package:flutter/material.dart';

enum OrderStatus {
  pending,
  confirmed,
  preparing,
  ready,
  served,
  completed,
  cancelled,
  refunded,
}

enum OrderType {
  dineIn,
  takeaway,
  delivery,
  catering,
}

enum PaymentStatus {
  pending,
  paid,
  failed,
  refunded,
}

/// Represents an order in the POS system.
class Order {
  final String id;
  final String orderNumber;
  final List<OrderItem> items;
  final OrderStatus status;
  final OrderType type;
  final String? tableId;
  final String? userId;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerAddress;
  final String? specialInstructions;
  final double taxAmount;
  final double tipAmount;
  final double hstAmount;
  final double discountAmount;
  final double gratuityAmount;
  final double? _storedSubtotal;
  final double? _storedTotalAmount;
  final String? paymentMethod;
  final PaymentStatus paymentStatus;
  final String? paymentTransactionId;
  final DateTime orderTime;
  final DateTime? estimatedReadyTime;
  final DateTime? actualReadyTime;
  final DateTime? servedTime;
  final DateTime? completedTime;
  final Map<String, dynamic> customFields;
  final Map<String, dynamic> metadata;
  final List<OrderNote> notes;
  final List<OrderHistory> history;
  final bool isUrgent;
  final int priority;
  final String? assignedTo;
  final Map<String, dynamic> preferences;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  /// Creates an [Order].
  Order({
    String? id,
    String? orderNumber,
    required this.items,
    this.status = OrderStatus.pending,
    this.type = OrderType.dineIn,
    this.tableId,
    this.userId,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.customerAddress,
    this.specialInstructions,
    double? subtotal,
    double? taxAmount,
    double? tipAmount,
    double? hstAmount,
    double? discountAmount,
    double? gratuityAmount,
    double? totalAmount,
    this.paymentMethod,
    this.paymentStatus = PaymentStatus.pending,
    this.paymentTransactionId,
    DateTime? orderTime,
    this.estimatedReadyTime,
    this.actualReadyTime,
    this.servedTime,
    this.completedTime,
    this.customFields = const {},
    this.metadata = const {},
    this.notes = const [],
    this.history = const [],
    this.isUrgent = false,
    this.priority = 0,
    this.assignedTo,
    this.preferences = const {},
    DateTime? createdAt,
    DateTime? updatedAt,
    this.completedAt,
  }) : 
    id = id ?? const Uuid().v4(),
    orderNumber = orderNumber ?? _generateOrderNumber(),
    taxAmount = taxAmount ?? 0.0,
    tipAmount = tipAmount ?? 0.0,
    hstAmount = hstAmount ?? 0.0,
    discountAmount = discountAmount ?? 0.0,
    gratuityAmount = gratuityAmount ?? 0.0,
    _storedSubtotal = subtotal,
    _storedTotalAmount = totalAmount,
    orderTime = orderTime ?? DateTime.now(),
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now();

  /// Returns the subtotal for the order (always calculated from items)
  double get subtotal => _calculateSubtotal(items);
  
  /// Returns the subtotal after applying discount
  double get subtotalAfterDiscount => subtotal - discountAmount;
  
  /// Returns the HST amount calculated on the discounted subtotal
  double get calculatedHstAmount => subtotalAfterDiscount * 0.13;
  
  /// Returns the total amount for the order with proper calculation
  double get totalAmount {
    // Always calculate dynamically for accurate totals
    // 1. Start with subtotal after discount
    // 2. Add HST on discounted amount
    // 3. Add gratuity/tip (prioritize gratuityAmount over tipAmount)
    final baseAfterDiscount = subtotalAfterDiscount;
    final hstAmount = calculatedHstAmount;
    final gratuityTip = gratuityAmount + tipAmount;
    
    final calculatedTotal = baseAfterDiscount + hstAmount + gratuityTip;
    
    // If we have a stored total and it's different from calculated, use calculated
    // This ensures consistency when values change
    return calculatedTotal;
  }

  /// Alias for totalAmount
  double get total => totalAmount;

  /// Generates a unique order number.
  static String _generateOrderNumber() {
    final now = DateTime.now();
    return 'ORD${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
  }

  /// Calculates the subtotal for a list of items.
  static double _calculateSubtotal(List<OrderItem> items) {
    return items.fold(0.0, (sum, item) => sum + item.totalPrice);
  }

  /// Creates an [Order] from JSON, with null safety and defaults.
  factory Order.fromJson(Map<String, dynamic> json) {
    try {
      return Order(
        id: json['id'] as String? ?? '',
        orderNumber: json['orderNumber'] as String? ?? '',
        items: (json['items'] as List?)?.map((item) => OrderItem.fromJson(item)).toList() ?? [],
        status: OrderStatus.values.firstWhere(
          (e) => e.toString().split('.').last == (json['status'] ?? '').toString(),
          orElse: () => OrderStatus.pending,
        ),
        type: OrderType.values.firstWhere(
          (e) => e.toString().split('.').last == (json['type'] ?? '').toString(),
          orElse: () => OrderType.dineIn,
        ),
        tableId: json['tableId'] as String?,
        userId: json['userId'] as String?,
        customerName: json['customerName'] as String?,
        customerPhone: json['customerPhone'] as String?,
        customerEmail: json['customerEmail'] as String?,
        customerAddress: json['customerAddress'] as String?,
        specialInstructions: json['specialInstructions'] as String?,
        subtotal: json['subtotal'] != null ? (json['subtotal'] as num).toDouble() : null,
        taxAmount: (json['taxAmount'] ?? 0.0).toDouble(),
        tipAmount: (json['tipAmount'] ?? 0.0).toDouble(),
        hstAmount: (json['hstAmount'] ?? 0.0).toDouble(),
        discountAmount: (json['discountAmount'] ?? 0.0).toDouble(),
        gratuityAmount: (json['gratuityAmount'] ?? 0.0).toDouble(),
        totalAmount: json['totalAmount'] != null ? (json['totalAmount'] as num).toDouble() : null,
        paymentMethod: json['paymentMethod'] as String?,
        paymentStatus: PaymentStatus.values.firstWhere(
          (e) => e.toString().split('.').last == (json['paymentStatus'] ?? '').toString(),
          orElse: () => PaymentStatus.pending,
        ),
        paymentTransactionId: json['paymentTransactionId'] as String?,
        orderTime: json['orderTime'] != null ? DateTime.tryParse(json['orderTime']) ?? DateTime.now() : DateTime.now(),
        estimatedReadyTime: json['estimatedReadyTime'] != null ? DateTime.tryParse(json['estimatedReadyTime']) : null,
        actualReadyTime: json['actualReadyTime'] != null ? DateTime.tryParse(json['actualReadyTime']) : null,
        servedTime: json['servedTime'] != null ? DateTime.tryParse(json['servedTime']) : null,
        completedTime: json['completedTime'] != null ? DateTime.tryParse(json['completedTime']) : null,
        customFields: json['customFields'] is Map<String, dynamic> ? Map<String, dynamic>.from(json['customFields']) : {},
        metadata: json['metadata'] is Map<String, dynamic> ? Map<String, dynamic>.from(json['metadata']) : {},
        notes: (json['notes'] as List?)?.map((note) => OrderNote.fromJson(note)).toList() ?? [],
        history: (json['history'] as List?)?.map((h) => OrderHistory.fromJson(h)).toList() ?? [],
        isUrgent: json['isUrgent'] ?? false,
        priority: json['priority'] ?? 0,
        assignedTo: json['assignedTo'] as String?,
        preferences: json['preferences'] is Map<String, dynamic> ? Map<String, dynamic>.from(json['preferences']) : {},
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) ?? DateTime.now() : DateTime.now(),
        updatedAt: json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt']) ?? DateTime.now() : DateTime.now(),
        completedAt: json['completedAt'] != null ? DateTime.tryParse(json['completedAt']) : null,
      );
    } catch (e) {
      return Order(items: []);
    }
  }

  /// Converts this [Order] to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'orderNumber': orderNumber,
      'items': items.map((item) => item.toJson()).toList(),
      'status': status.toString().split('.').last,
      'type': type.toString().split('.').last,
      'tableId': tableId,
      'userId': userId,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      'customerAddress': customerAddress,
      'specialInstructions': specialInstructions,
      'subtotal': subtotal,
      'taxAmount': taxAmount,
      'tipAmount': tipAmount,
      'hstAmount': hstAmount,
      'discountAmount': discountAmount,
      'gratuityAmount': gratuityAmount,
      'totalAmount': totalAmount,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus.toString().split('.').last,
      'paymentTransactionId': paymentTransactionId,
      'orderTime': orderTime.toIso8601String(),
      'estimatedReadyTime': estimatedReadyTime?.toIso8601String(),
      'actualReadyTime': actualReadyTime?.toIso8601String(),
      'servedTime': servedTime?.toIso8601String(),
      'completedTime': completedTime?.toIso8601String(),
      'customFields': customFields,
      'metadata': metadata,
      'notes': notes.map((note) => note.toJson()).toList(),
      'history': history.map((h) => h.toJson()).toList(),
      'isUrgent': isUrgent,
      'priority': priority,
      'assignedTo': assignedTo,
      'preferences': preferences,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  /// Returns a copy of this [Order] with updated fields.
  Order copyWith({
    String? id,
    String? orderNumber,
    List<OrderItem>? items,
    OrderStatus? status,
    OrderType? type,
    String? tableId,
    String? userId,
    String? customerName,
    String? customerPhone,
    String? customerEmail,
    String? customerAddress,
    String? specialInstructions,
    double? subtotal,
    double? taxAmount,
    double? tipAmount,
    double? hstAmount,
    double? discountAmount,
    double? gratuityAmount,
    double? totalAmount,
    String? paymentMethod,
    PaymentStatus? paymentStatus,
    String? paymentTransactionId,
    DateTime? orderTime,
    DateTime? estimatedReadyTime,
    DateTime? actualReadyTime,
    DateTime? servedTime,
    DateTime? completedTime,
    Map<String, dynamic>? customFields,
    Map<String, dynamic>? metadata,
    List<OrderNote>? notes,
    List<OrderHistory>? history,
    bool? isUrgent,
    int? priority,
    String? assignedTo,
    Map<String, dynamic>? preferences,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      items: items ?? this.items,
      status: status ?? this.status,
      type: type ?? this.type,
      tableId: tableId ?? this.tableId,
      userId: userId ?? this.userId,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      customerEmail: customerEmail ?? this.customerEmail,
      customerAddress: customerAddress ?? this.customerAddress,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      subtotal: subtotal ?? _storedSubtotal,
      taxAmount: taxAmount ?? this.taxAmount,
      tipAmount: tipAmount ?? this.tipAmount,
      hstAmount: hstAmount ?? this.hstAmount,
      discountAmount: discountAmount ?? this.discountAmount,
      gratuityAmount: gratuityAmount ?? this.gratuityAmount,
      totalAmount: totalAmount ?? _storedTotalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentTransactionId: paymentTransactionId ?? this.paymentTransactionId,
      orderTime: orderTime ?? this.orderTime,
      estimatedReadyTime: estimatedReadyTime ?? this.estimatedReadyTime,
      actualReadyTime: actualReadyTime ?? this.actualReadyTime,
      servedTime: servedTime ?? this.servedTime,
      completedTime: completedTime ?? this.completedTime,
      customFields: customFields ?? this.customFields,
      metadata: metadata ?? this.metadata,
      notes: notes ?? this.notes,
      history: history ?? this.history,
      isUrgent: isUrgent ?? this.isUrgent,
      priority: priority ?? this.priority,
      assignedTo: assignedTo ?? this.assignedTo,
      preferences: preferences ?? this.preferences,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  // Helper methods
  bool get isCompleted => status == OrderStatus.completed;
  
  bool get isCancelled => status == OrderStatus.cancelled;
  
  bool get isActive => status != OrderStatus.completed && 
                      status != OrderStatus.cancelled && 
                      status != OrderStatus.refunded;

  /// NEW: Comprehensive order state protection
  bool get isModifiable => status != OrderStatus.completed && 
                          status != OrderStatus.cancelled && 
                          status != OrderStatus.refunded;

  bool get isProtected => !isModifiable;

  /// Returns protection reason for user feedback
  String get protectionReason {
    switch (status) {
      case OrderStatus.cancelled:
        return 'Order has been cancelled';
      case OrderStatus.completed:
        return 'Order has been completed';
      case OrderStatus.refunded:
        return 'Order has been refunded';
      default:
        return 'Order cannot be modified';
    }
  }

  /// Returns appropriate protection message for UI
  String get protectionMessage {
    switch (status) {
      case OrderStatus.cancelled:
        return 'This order was cancelled and cannot be modified';
      case OrderStatus.completed:
        return 'This order is completed and cannot be modified';
      case OrderStatus.refunded:
        return 'This order has been refunded and cannot be modified';
      default:
        return 'This order cannot be modified';
    }
  }

  /// Returns color for order status display
  Color get statusColor {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.purple;
      case OrderStatus.ready:
        return Colors.green;
      case OrderStatus.served:
        return Colors.teal;
      case OrderStatus.completed:
        return Colors.grey;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.refunded:
        return Colors.red.shade300;
    }
  }

  /// Returns icon for order status display
  IconData get statusIcon {
    switch (status) {
      case OrderStatus.pending:
        return Icons.pending;
      case OrderStatus.confirmed:
        return Icons.check_circle_outline;
      case OrderStatus.preparing:
        return Icons.restaurant;
      case OrderStatus.ready:
        return Icons.room_service;
      case OrderStatus.served:
        return Icons.done_all;
      case OrderStatus.completed:
        return Icons.task_alt;
      case OrderStatus.cancelled:
        return Icons.cancel;
      case OrderStatus.refunded:
        return Icons.money_off;
    }
  }

  Duration get preparationTime {
    if (actualReadyTime != null) {
      return actualReadyTime!.difference(orderTime);
    }
    return Duration.zero;
  }

  Duration get estimatedPreparationTime {
    if (estimatedReadyTime != null) {
      return estimatedReadyTime!.difference(orderTime);
    }
    return Duration.zero;
  }

  bool get isOverdue {
    if (estimatedReadyTime != null) {
      return DateTime.now().isAfter(estimatedReadyTime!);
    }
    return false;
  }

  List<OrderItem> get availableItems => items.where((item) => item.menuItem.isAvailable).toList();

  List<OrderItem> get unavailableItems => items.where((item) => !item.menuItem.isAvailable).toList();

  double get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  void addNote(String note, String? author) {
    notes.add(OrderNote(
      id: const Uuid().v4(),
      note: note,
      author: author,
      timestamp: DateTime.now(),
    ));
  }

  void updateStatus(OrderStatus newStatus, String? updatedBy) {
    history.add(OrderHistory(
      id: const Uuid().v4(),
      status: newStatus,
      updatedBy: updatedBy,
      timestamp: DateTime.now(),
      notes: 'Status changed from ${status.toString().split('.').last} to ${newStatus.toString().split('.').last}',
    ));
  }
}

/// Represents an item in an order.
class OrderItem {
  final String id;
  final MenuItem menuItem;
  final int quantity;
  final double unitPrice;
  final String? selectedVariant;
  final List<String> selectedModifiers;
  final String? specialInstructions;
  final Map<String, dynamic> customProperties;
  final bool isAvailable;
  final bool sentToKitchen;
  final DateTime createdAt;
  // Admin action fields
  final bool? voided;
  final String? voidedBy;
  final DateTime? voidedAt;
  final bool? comped;
  final String? compedBy;
  final DateTime? compedAt;
  final double? discountPercentage;
  final double? discountAmount;
  final String? discountedBy;
  final DateTime? discountedAt;
  final String? notes;

  // Dynamic getter for totalPrice
  double get totalPrice {
    if (voided == true) return 0.0;
    if (comped == true) return 0.0;
    return unitPrice * quantity;
  }

  /// Creates an [OrderItem].
  OrderItem({
    String? id,
    required this.menuItem,
    required this.quantity,
    double? unitPrice,
    this.selectedVariant,
    this.selectedModifiers = const [],
    this.specialInstructions,
    this.customProperties = const {},
    this.isAvailable = true,
    this.sentToKitchen = false,
    DateTime? createdAt,
    this.voided,
    this.voidedBy,
    this.voidedAt,
    this.comped,
    this.compedBy,
    this.compedAt,
    this.discountPercentage,
    this.discountAmount,
    this.discountedBy,
    this.discountedAt,
    this.notes,
  }) : 
    id = id ?? const Uuid().v4(),
    unitPrice = unitPrice ?? _calculateUnitPrice(menuItem, selectedVariant, selectedModifiers),
    createdAt = createdAt ?? DateTime.now();

  /// Calculates the unit price for an item.
  static double _calculateUnitPrice(MenuItem menuItem, String? variant, List<String> modifiers) {
    double price = menuItem.price;
    
    if (variant != null && menuItem.hasVariant(variant)) {
      price = menuItem.getVariantPrice(variant);
    }
    
    for (final modifier in modifiers) {
      if (menuItem.hasModifier(modifier)) {
        price += menuItem.getModifierPrice(modifier);
      }
    }
    
    return price;
  }

  /// Creates an [OrderItem] from JSON, with null safety and defaults.
  factory OrderItem.fromJson(Map<String, dynamic> json) {
    try {
      return OrderItem(
        id: json['id'] as String? ?? '',
        menuItem: json['menuItem'] != null ? MenuItem.fromJson(json['menuItem']) : MenuItem(name: '', description: '', price: 0.0, categoryId: ''),
        quantity: json['quantity'] is int ? json['quantity'] : int.tryParse(json['quantity']?.toString() ?? '') ?? 1,
        unitPrice: (json['unitPrice'] ?? 0.0).toDouble(),
        selectedVariant: json['selectedVariant'] as String?,
        selectedModifiers: json['selectedModifiers'] is List ? List<String>.from(json['selectedModifiers']) : [],
        specialInstructions: json['specialInstructions'] as String?,
        customProperties: json['customProperties'] is Map<String, dynamic> ? Map<String, dynamic>.from(json['customProperties']) : {},
        isAvailable: json['isAvailable'] ?? true,
        sentToKitchen: json['sentToKitchen'] ?? json['sent_to_kitchen'] == 1,
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) ?? DateTime.now() : DateTime.now(),
        voided: json['voided'] as bool?,
        voidedBy: json['voidedBy'] as String?,
        voidedAt: json['voidedAt'] != null ? DateTime.tryParse(json['voidedAt']) : null,
        comped: json['comped'] as bool?,
        compedBy: json['compedBy'] as String?,
        compedAt: json['compedAt'] != null ? DateTime.tryParse(json['compedAt']) : null,
        discountPercentage: json['discountPercentage'] != null ? (json['discountPercentage'] as num).toDouble() : null,
        discountAmount: json['discountAmount'] != null ? (json['discountAmount'] as num).toDouble() : null,
        discountedBy: json['discountedBy'] as String?,
        discountedAt: json['discountedAt'] != null ? DateTime.tryParse(json['discountedAt']) : null,
        notes: json['notes'] as String?,
      );
    } catch (e) {
      return OrderItem(menuItem: MenuItem(name: '', description: '', price: 0.0, categoryId: ''), quantity: 1);
    }
  }

  /// Converts this [OrderItem] to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'menuItem': menuItem.toJson(),
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'selectedVariant': selectedVariant,
      'selectedModifiers': selectedModifiers,
      'specialInstructions': specialInstructions,
      'customProperties': customProperties,
      'isAvailable': isAvailable,
      'sentToKitchen': sentToKitchen,
      'createdAt': createdAt.toIso8601String(),
      'voided': voided,
      'voidedBy': voidedBy,
      'voidedAt': voidedAt?.toIso8601String(),
      'comped': comped,
      'compedBy': compedBy,
      'compedAt': compedAt?.toIso8601String(),
      'discountPercentage': discountPercentage,
      'discountAmount': discountAmount,
      'discountedBy': discountedBy,
      'discountedAt': discountedAt?.toIso8601String(),
      'notes': notes,
    };
  }

  /// Returns a copy of this [OrderItem] with updated fields.
  OrderItem copyWith({
    String? id,
    MenuItem? menuItem,
    int? quantity,
    double? unitPrice,
    String? selectedVariant,
    List<String>? selectedModifiers,
    String? specialInstructions,
    Map<String, dynamic>? customProperties,
    bool? isAvailable,
    bool? sentToKitchen,
    DateTime? createdAt,
    bool? voided,
    String? voidedBy,
    DateTime? voidedAt,
    bool? comped,
    String? compedBy,
    DateTime? compedAt,
    double? discountPercentage,
    double? discountAmount,
    String? discountedBy,
    DateTime? discountedAt,
    String? notes,
  }) {
    return OrderItem(
      id: id ?? this.id,
      menuItem: menuItem ?? this.menuItem,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      selectedVariant: selectedVariant ?? this.selectedVariant,
      selectedModifiers: selectedModifiers ?? this.selectedModifiers,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      customProperties: customProperties ?? this.customProperties,
      isAvailable: isAvailable ?? this.isAvailable,
      sentToKitchen: sentToKitchen ?? this.sentToKitchen,
      createdAt: createdAt ?? this.createdAt,
      voided: voided ?? this.voided,
      voidedBy: voidedBy ?? this.voidedBy,
      voidedAt: voidedAt ?? this.voidedAt,
      comped: comped ?? this.comped,
      compedBy: compedBy ?? this.compedBy,
      compedAt: compedAt ?? this.compedAt,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      discountAmount: discountAmount ?? this.discountAmount,
      discountedBy: discountedBy ?? this.discountedBy,
      discountedAt: discountedAt ?? this.discountedAt,
      notes: notes ?? this.notes,
    );
  }
}

/// Represents a note on an order.
class OrderNote {
  final String id;
  final String note;
  final String? author;
  final DateTime timestamp;
  final bool isInternal;

  /// Creates an [OrderNote].
  OrderNote({
    required this.id,
    required this.note,
    this.author,
    required this.timestamp,
    this.isInternal = false,
  });

  /// Creates an [OrderNote] from JSON, with null safety and defaults.
  factory OrderNote.fromJson(Map<String, dynamic> json) {
    return OrderNote(
      id: json['id'] as String? ?? '',
      note: json['note'] as String? ?? '',
      author: json['author'] as String?,
      timestamp: json['timestamp'] != null ? DateTime.tryParse(json['timestamp']) ?? DateTime.now() : DateTime.now(),
      isInternal: json['isInternal'] ?? false,
    );
  }

  /// Converts this [OrderNote] to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'note': note,
      'author': author,
      'timestamp': timestamp.toIso8601String(),
      'isInternal': isInternal,
    };
  }
}

/// Represents a status change in an order's history.
class OrderHistory {
  final String id;
  final OrderStatus status;
  final String? updatedBy;
  final DateTime timestamp;
  final String? notes;
  final Map<String, dynamic> metadata;

  /// Creates an [OrderHistory].
  OrderHistory({
    required this.id,
    required this.status,
    this.updatedBy,
    required this.timestamp,
    this.notes,
    this.metadata = const {},
  });

  /// Creates an [OrderHistory] from JSON, with null safety and defaults.
  factory OrderHistory.fromJson(Map<String, dynamic> json) {
    return OrderHistory(
      id: json['id'] as String? ?? '',
      status: OrderStatus.values.firstWhere(
        (e) => e.toString().split('.').last == (json['status'] ?? '').toString(),
        orElse: () => OrderStatus.pending,
      ),
      updatedBy: json['updatedBy'] as String?,
      timestamp: json['timestamp'] != null ? DateTime.tryParse(json['timestamp']) ?? DateTime.now() : DateTime.now(),
      notes: json['notes'] as String?,
      metadata: json['metadata'] is Map<String, dynamic> ? Map<String, dynamic>.from(json['metadata']) : {},
    );
  }

  /// Converts this [OrderHistory] to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status.toString().split('.').last,
      'updatedBy': updatedBy,
      'timestamp': timestamp.toIso8601String(),
      'notes': notes,
      'metadata': metadata,
    };
  }
} 