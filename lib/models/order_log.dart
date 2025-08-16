import 'package:uuid/uuid.dart';
import 'dart:convert';

/// Enum for different types of order operations that can be logged
enum OrderLogAction {
  created,
  updated,
  statusChanged,
  itemAdded,
  itemRemoved,
  itemModified,
  itemVoided,
  discountApplied,
  discountRemoved,
  gratuityAdded,
  gratuityModified,
  sentToKitchen,
  kitchenStatusChanged,
  paymentProcessed,
  paymentRefunded,
  noteAdded,
  cancelled,
  refunded,
  completed,
  reopened,
  transferred,
  split,
  merged,
  printed,
  emailSent,
  customAction,
}

/// Enum for log severity levels
enum LogLevel {
  info,
  warning,
  error,
  critical,
}

/// Comprehensive order log entry for audit trail
class OrderLog {
  final String id;
  final String orderId;
  final String orderNumber;
  final OrderLogAction action;
  final LogLevel level;
  final String performedBy; // User ID or name who performed the action
  final String? performedByName; // Display name of the user
  final DateTime timestamp;
  final String description; // Human-readable description of the action
  final Map<String, dynamic> beforeData; // Data before the change
  final Map<String, dynamic> afterData; // Data after the change
  final Map<String, dynamic> metadata; // Additional context data
  final String? notes; // Optional notes from the user
  final String? deviceId; // Device where action was performed
  final String? sessionId; // Session identifier
  final String? ipAddress; // IP address if available
  final bool isSystemAction; // Whether this was a system-generated action
  final String? errorMessage; // Error message if action failed
  final double? amountBefore; // Financial amount before change
  final double? amountAfter; // Financial amount after change
  final String? tableId; // Table associated with the order
  final String? customerId; // Customer ID if available

  OrderLog({
    String? id,
    required this.orderId,
    required this.orderNumber,
    required this.action,
    this.level = LogLevel.info,
    required this.performedBy,
    this.performedByName,
    DateTime? timestamp,
    required this.description,
    this.beforeData = const {},
    this.afterData = const {},
    this.metadata = const {},
    this.notes,
    this.deviceId,
    this.sessionId,
    this.ipAddress,
    this.isSystemAction = false,
    this.errorMessage,
    this.amountBefore,
    this.amountAfter,
    this.tableId,
    this.customerId,
  }) : 
    id = id ?? const Uuid().v4(),
    timestamp = timestamp ?? DateTime.now();

  /// Creates an OrderLog from JSON
  factory OrderLog.fromJson(Map<String, dynamic> json) {
    return OrderLog(
      id: json['id'] as String? ?? '',
      orderId: json['order_id'] as String? ?? '',
      orderNumber: json['order_number'] as String? ?? '',
      action: OrderLogAction.values.firstWhere(
        (e) => e.toString().split('.').last == (json['action'] ?? ''),
        orElse: () => OrderLogAction.customAction,
      ),
      level: LogLevel.values.firstWhere(
        (e) => e.toString().split('.').last == (json['level'] ?? ''),
        orElse: () => LogLevel.info,
      ),
      performedBy: json['performed_by'] as String? ?? '',
      performedByName: json['performed_by_name'] as String?,
      timestamp: json['timestamp'] != null 
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      description: json['description'] as String? ?? '',
      beforeData: _parseJsonData(json['before_data']),
      afterData: _parseJsonData(json['after_data']),
      metadata: _parseJsonData(json['metadata']),
      notes: json['notes'] as String?,
      deviceId: json['device_id'] as String?,
      sessionId: json['session_id'] as String?,
      ipAddress: json['ip_address'] as String?,
      isSystemAction: json['is_system_action'] == 1 || json['is_system_action'] == true,
      errorMessage: json['error_message'] as String?,
      amountBefore: json['amount_before']?.toDouble(),
      amountAfter: json['amount_after']?.toDouble(),
      tableId: json['table_id'] as String?,
      customerId: json['customer_id'] as String?,
    );
  }

  /// Helper method to parse JSON data from database
  static Map<String, dynamic> _parseJsonData(dynamic data) {
    if (data == null) return {};
    if (data is Map<String, dynamic>) return Map<String, dynamic>.from(data);
    if (data is String) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map<String, dynamic>) {
          return Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        // If JSON parsing fails, return empty map
      }
    }
    return {};
  }

  /// Converts this OrderLog to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'order_number': orderNumber,
      'action': action.toString().split('.').last,
      'level': level.toString().split('.').last,
      'performed_by': performedBy,
      'performed_by_name': performedByName,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
      'before_data': beforeData,
      'after_data': afterData,
      'metadata': metadata,
      'notes': notes,
      'device_id': deviceId,
      'session_id': sessionId,
      'ip_address': ipAddress,
      'is_system_action': isSystemAction ? 1 : 0,
      'error_message': errorMessage,
      'amount_before': amountBefore,
      'amount_after': amountAfter,
      'table_id': tableId,
      'customer_id': customerId,
    };
  }

  /// Creates a copy of this OrderLog with updated fields
  OrderLog copyWith({
    String? id,
    String? orderId,
    String? orderNumber,
    OrderLogAction? action,
    LogLevel? level,
    String? performedBy,
    String? performedByName,
    DateTime? timestamp,
    String? description,
    Map<String, dynamic>? beforeData,
    Map<String, dynamic>? afterData,
    Map<String, dynamic>? metadata,
    String? notes,
    String? deviceId,
    String? sessionId,
    String? ipAddress,
    bool? isSystemAction,
    String? errorMessage,
    double? amountBefore,
    double? amountAfter,
    String? tableId,
    String? customerId,
  }) {
    return OrderLog(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      orderNumber: orderNumber ?? this.orderNumber,
      action: action ?? this.action,
      level: level ?? this.level,
      performedBy: performedBy ?? this.performedBy,
      performedByName: performedByName ?? this.performedByName,
      timestamp: timestamp ?? this.timestamp,
      description: description ?? this.description,
      beforeData: beforeData ?? this.beforeData,
      afterData: afterData ?? this.afterData,
      metadata: metadata ?? this.metadata,
      notes: notes ?? this.notes,
      deviceId: deviceId ?? this.deviceId,
      sessionId: sessionId ?? this.sessionId,
      ipAddress: ipAddress ?? this.ipAddress,
      isSystemAction: isSystemAction ?? this.isSystemAction,
      errorMessage: errorMessage ?? this.errorMessage,
      amountBefore: amountBefore ?? this.amountBefore,
      amountAfter: amountAfter ?? this.amountAfter,
      tableId: tableId ?? this.tableId,
      customerId: customerId ?? this.customerId,
    );
  }

  /// Gets a user-friendly action description
  String get actionDescription {
    switch (action) {
      case OrderLogAction.created:
        return 'Order Created';
      case OrderLogAction.updated:
        return 'Order Updated';
      case OrderLogAction.statusChanged:
        return 'Status Changed';
      case OrderLogAction.itemAdded:
        return 'Item Added';
      case OrderLogAction.itemRemoved:
        return 'Item Removed';
      case OrderLogAction.itemModified:
        return 'Item Modified';
      case OrderLogAction.itemVoided:
        return 'Item Voided';
      case OrderLogAction.discountApplied:
        return 'Discount Applied';
      case OrderLogAction.discountRemoved:
        return 'Discount Removed';
      case OrderLogAction.gratuityAdded:
        return 'Gratuity Added';
      case OrderLogAction.gratuityModified:
        return 'Gratuity Modified';
      case OrderLogAction.sentToKitchen:
        return 'Sent to Kitchen';
      case OrderLogAction.kitchenStatusChanged:
        return 'Kitchen Status Changed';
      case OrderLogAction.paymentProcessed:
        return 'Payment Processed';
      case OrderLogAction.paymentRefunded:
        return 'Payment Refunded';
      case OrderLogAction.noteAdded:
        return 'Note Added';
      case OrderLogAction.cancelled:
        return 'Order Cancelled';
      case OrderLogAction.refunded:
        return 'Order Refunded';
      case OrderLogAction.completed:
        return 'Order Completed';
      case OrderLogAction.reopened:
        return 'Order Reopened';
      case OrderLogAction.transferred:
        return 'Order Transferred';
      case OrderLogAction.split:
        return 'Order Split';
      case OrderLogAction.merged:
        return 'Order Merged';
      case OrderLogAction.printed:
        return 'Order Printed';
      case OrderLogAction.emailSent:
        return 'Email Sent';
      case OrderLogAction.customAction:
        return 'Custom Action';
    }
  }

  /// Gets the icon for this action
  String get actionIcon {
    switch (action) {
      case OrderLogAction.created:
        return '➕';
      case OrderLogAction.updated:
        return '✏️';
      case OrderLogAction.statusChanged:
        return '🔄';
      case OrderLogAction.itemAdded:
        return '🍽️';
      case OrderLogAction.itemRemoved:
        return '❌';
      case OrderLogAction.itemModified:
        return '🔧';
      case OrderLogAction.itemVoided:
        return '🚫';
      case OrderLogAction.discountApplied:
        return '💰';
      case OrderLogAction.discountRemoved:
        return '💸';
      case OrderLogAction.gratuityAdded:
        return '💝';
      case OrderLogAction.gratuityModified:
        return '💰';
      case OrderLogAction.sentToKitchen:
        return '👨‍🍳';
      case OrderLogAction.kitchenStatusChanged:
        return '🔥';
      case OrderLogAction.paymentProcessed:
        return '💳';
      case OrderLogAction.paymentRefunded:
        return '↩️';
      case OrderLogAction.noteAdded:
        return '📝';
      case OrderLogAction.cancelled:
        return '❌';
      case OrderLogAction.refunded:
        return '💰';
      case OrderLogAction.completed:
        return '✅';
      case OrderLogAction.reopened:
        return '🔓';
      case OrderLogAction.transferred:
        return '🔄';
      case OrderLogAction.split:
        return '✂️';
      case OrderLogAction.merged:
        return '🔗';
      case OrderLogAction.printed:
        return '🖨️';
      case OrderLogAction.emailSent:
        return '📧';
      case OrderLogAction.customAction:
        return '⚙️';
    }
  }

  /// Gets the color for this log level
  String get levelColor {
    switch (level) {
      case LogLevel.info:
        return '#2196F3';
      case LogLevel.warning:
        return '#FF9800';
      case LogLevel.error:
        return '#F44336';
      case LogLevel.critical:
        return '#9C27B0';
    }
  }

  /// Checks if this is a financial operation
  bool get isFinancialOperation {
    return [
      OrderLogAction.discountApplied,
      OrderLogAction.discountRemoved,
      OrderLogAction.gratuityAdded,
      OrderLogAction.gratuityModified,
      OrderLogAction.paymentProcessed,
      OrderLogAction.paymentRefunded,
      OrderLogAction.refunded,
    ].contains(action);
  }

  /// Checks if this is a kitchen operation
  bool get isKitchenOperation {
    return [
      OrderLogAction.sentToKitchen,
      OrderLogAction.kitchenStatusChanged,
      OrderLogAction.itemAdded,
      OrderLogAction.itemRemoved,
      OrderLogAction.itemModified,
      OrderLogAction.itemVoided,
    ].contains(action);
  }

  /// Gets the financial impact of this operation
  double? get financialImpact {
    if (amountBefore != null && amountAfter != null) {
      return amountAfter! - amountBefore!;
    }
    return null;
  }

  @override
  String toString() {
    return 'OrderLog(id: $id, action: $actionDescription, performedBy: $performedByName, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrderLog && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Helper class for creating order log entries
class OrderLogBuilder {
  static OrderLog createOrderLog({
    required String orderId,
    required String orderNumber,
    required OrderLogAction action,
    required String performedBy,
    String? performedByName,
    LogLevel level = LogLevel.info,
    String? description,
    Map<String, dynamic>? beforeData,
    Map<String, dynamic>? afterData,
    Map<String, dynamic>? metadata,
    String? notes,
    String? deviceId,
    String? sessionId,
    String? ipAddress,
    bool isSystemAction = false,
    String? errorMessage,
    double? amountBefore,
    double? amountAfter,
    String? tableId,
    String? customerId,
  }) {
    return OrderLog(
      orderId: orderId,
      orderNumber: orderNumber,
      action: action,
      level: level,
      performedBy: performedBy,
      performedByName: performedByName,
      description: description ?? action.toString().split('.').last,
      beforeData: beforeData ?? {},
      afterData: afterData ?? {},
      metadata: metadata ?? {},
      notes: notes,
      deviceId: deviceId,
      sessionId: sessionId,
      ipAddress: ipAddress,
      isSystemAction: isSystemAction,
      errorMessage: errorMessage,
      amountBefore: amountBefore,
      amountAfter: amountAfter,
      tableId: tableId,
      customerId: customerId,
    );
  }

  /// Creates a log entry for order creation
  static OrderLog orderCreated({
    required String orderId,
    required String orderNumber,
    required String performedBy,
    String? performedByName,
    required Map<String, dynamic> orderData,
    String? tableId,
    String? customerId,
    String? deviceId,
    String? sessionId,
  }) {
    return createOrderLog(
      orderId: orderId,
      orderNumber: orderNumber,
      action: OrderLogAction.created,
      performedBy: performedBy,
      performedByName: performedByName,
      description: 'Order $orderNumber created',
      afterData: orderData,
      tableId: tableId,
      customerId: customerId,
      deviceId: deviceId,
      sessionId: sessionId,
    );
  }

  /// Creates a log entry for status change
  static OrderLog statusChanged({
    required String orderId,
    required String orderNumber,
    required String performedBy,
    String? performedByName,
    required String fromStatus,
    required String toStatus,
    String? reason,
    String? deviceId,
    String? sessionId,
  }) {
    return createOrderLog(
      orderId: orderId,
      orderNumber: orderNumber,
      action: OrderLogAction.statusChanged,
      performedBy: performedBy,
      performedByName: performedByName,
      description: 'Status changed from $fromStatus to $toStatus',
      beforeData: {'status': fromStatus},
      afterData: {'status': toStatus},
      notes: reason,
      deviceId: deviceId,
      sessionId: sessionId,
    );
  }

  /// Creates a log entry for item operations
  static OrderLog itemOperation({
    required String orderId,
    required String orderNumber,
    required OrderLogAction action,
    required String performedBy,
    String? performedByName,
    required Map<String, dynamic> itemData,
    Map<String, dynamic>? beforeItemData,
    String? reason,
    String? deviceId,
    String? sessionId,
  }) {
    return createOrderLog(
      orderId: orderId,
      orderNumber: orderNumber,
      action: action,
      performedBy: performedBy,
      performedByName: performedByName,
      description: '${action.toString().split('.').last} - ${itemData['name'] ?? 'Unknown Item'}',
      beforeData: beforeItemData ?? {},
      afterData: itemData,
      notes: reason,
      deviceId: deviceId,
      sessionId: sessionId,
    );
  }

  /// Creates a log entry for financial operations
  static OrderLog financialOperation({
    required String orderId,
    required String orderNumber,
    required OrderLogAction action,
    required String performedBy,
    String? performedByName,
    required double amountBefore,
    required double amountAfter,
    String? reason,
    Map<String, dynamic>? additionalData,
    String? deviceId,
    String? sessionId,
  }) {
    final impact = amountAfter - amountBefore;
    final sign = impact >= 0 ? '+' : '';
    
    return createOrderLog(
      orderId: orderId,
      orderNumber: orderNumber,
      action: action,
      performedBy: performedBy,
      performedByName: performedByName,
      description: '${action.toString().split('.').last} - $sign\$${impact.abs().toStringAsFixed(2)}',
      beforeData: {'amount': amountBefore},
      afterData: {'amount': amountAfter},
      metadata: additionalData ?? {},
      notes: reason,
      amountBefore: amountBefore,
      amountAfter: amountAfter,
      deviceId: deviceId,
      sessionId: sessionId,
    );
  }
} 