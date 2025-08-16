import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Comprehensive enum for all possible user actions in the POS system
enum ActivityAction {
  // Authentication & Session
  login,
  logout,
  sessionTimeout,
  pinEntered,
  roleChanged,
  
  // User Management
  userCreated,
  userUpdated,
  userDeleted,
  userActivated,
  userDeactivated,
  passwordChanged,
  
  // Menu Management
  menuItemCreated,
  menuItemUpdated,
  menuItemDeleted,
  menuItemActivated,
  menuItemDeactivated,
  categoryCreated,
  categoryUpdated,
  categoryDeleted,
  priceChanged,
  
  // Order Operations
  orderCreated,
  orderUpdated,
  orderCancelled,
  orderCompleted,
  orderStatusChanged,
  orderItemAdded,
  orderItemRemoved,
  orderItemModified,
  orderSentToKitchen,
  orderPrinted,
  orderRefunded,
  
  // Financial Operations
  discountApplied,
  discountRemoved,
  tipAdded,
  tipModified,
  paymentProcessed,
  paymentVoided,
  refundProcessed,
  
  // Table Management
  tableCreated,
  tableUpdated,
  tableDeleted,
  tableAssigned,
  tableReleased,
  tableStatusChanged,
  
  // Inventory Management
  inventoryAdded,
  inventoryUpdated,
  inventoryDeleted,
  stockAdjusted,
  lowStockAlert,
  
  // Kitchen Operations
  kitchenOrderReceived,
  kitchenOrderStarted,
  kitchenOrderCompleted,
  kitchenStatusChanged,
  
  // Printer Operations
  printerConfigured,
  printerAssigned,
  printerUnassigned,
  printJobSent,
  printJobFailed,
  
  // System Operations
  settingsChanged,
  databaseBackup,
  databaseRestore,
  systemError,
  systemWarning,
  
  // Navigation & Screen Access
  screenAccessed,
  adminPanelAccessed,
  reportsAccessed,
  
  // Data Import/Export
  dataImported,
  dataExported,
  reportGenerated,
  
  // Custom Actions
  customAction,
}

/// Log severity levels
enum ActivityLevel {
  info,
  warning,
  error,
  critical,
  security,
}

/// Activity categories for better organization
enum ActivityCategory {
  authentication,
  userManagement,
  menuManagement,
  orderManagement,
  financial,
  kitchen,
  inventory,
  system,
  navigation,
  printing,
  reporting,
}

/// Comprehensive activity log entry for complete system audit trail
class ActivityLog {
  final String id;
  final ActivityAction action;
  final ActivityLevel level;
  final ActivityCategory category;
  final String performedBy; // User ID
  final String performedByName; // User display name
  final String performedByRole; // User role
  final DateTime timestamp;
  final String description; // Human-readable description
  final String? targetId; // ID of the object being acted upon
  final String? targetType; // Type of object (order, user, menu_item, etc.)
  final String? targetName; // Name of the object
  final Map<String, dynamic> beforeData; // Data before the change
  final Map<String, dynamic> afterData; // Data after the change
  final Map<String, dynamic> metadata; // Additional context
  final String? notes; // Optional user notes
  final String? deviceId; // Device identifier
  final String? sessionId; // Session identifier
  final String? ipAddress; // IP address
  final String? screenName; // Screen where action occurred
  final bool isSystemAction; // Whether this was system-generated
  final String? errorMessage; // Error message if action failed
  final double? financialAmount; // Financial amount if applicable
  final String? restaurantId; // Restaurant/tenant ID
  final Duration? executionTime; // Time taken to execute action

  ActivityLog({
    String? id,
    required this.action,
    this.level = ActivityLevel.info,
    ActivityCategory? category,
    required this.performedBy,
    required this.performedByName,
    required this.performedByRole,
    DateTime? timestamp,
    required this.description,
    this.targetId,
    this.targetType,
    this.targetName,
    this.beforeData = const {},
    this.afterData = const {},
    this.metadata = const {},
    this.notes,
    this.deviceId,
    this.sessionId,
    this.ipAddress,
    this.screenName,
    this.isSystemAction = false,
    this.errorMessage,
    this.financialAmount,
    this.restaurantId,
    this.executionTime,
  }) : 
    id = id ?? const Uuid().v4(),
    timestamp = timestamp ?? DateTime.now(),
    category = category ?? _getCategoryFromAction(action);

  /// Automatically determine category from action
  static ActivityCategory _getCategoryFromAction(ActivityAction action) {
    switch (action) {
      case ActivityAction.login:
      case ActivityAction.logout:
      case ActivityAction.sessionTimeout:
      case ActivityAction.pinEntered:
      case ActivityAction.roleChanged:
        return ActivityCategory.authentication;
      
      case ActivityAction.userCreated:
      case ActivityAction.userUpdated:
      case ActivityAction.userDeleted:
      case ActivityAction.userActivated:
      case ActivityAction.userDeactivated:
      case ActivityAction.passwordChanged:
        return ActivityCategory.userManagement;
      
      case ActivityAction.menuItemCreated:
      case ActivityAction.menuItemUpdated:
      case ActivityAction.menuItemDeleted:
      case ActivityAction.menuItemActivated:
      case ActivityAction.menuItemDeactivated:
      case ActivityAction.categoryCreated:
      case ActivityAction.categoryUpdated:
      case ActivityAction.categoryDeleted:
      case ActivityAction.priceChanged:
        return ActivityCategory.menuManagement;
      
      case ActivityAction.orderCreated:
      case ActivityAction.orderUpdated:
      case ActivityAction.orderCancelled:
      case ActivityAction.orderCompleted:
      case ActivityAction.orderStatusChanged:
      case ActivityAction.orderItemAdded:
      case ActivityAction.orderItemRemoved:
      case ActivityAction.orderItemModified:
      case ActivityAction.orderSentToKitchen:
      case ActivityAction.orderPrinted:
      case ActivityAction.orderRefunded:
        return ActivityCategory.orderManagement;
      
      case ActivityAction.discountApplied:
      case ActivityAction.discountRemoved:
      case ActivityAction.tipAdded:
      case ActivityAction.tipModified:
      case ActivityAction.paymentProcessed:
      case ActivityAction.paymentVoided:
      case ActivityAction.refundProcessed:
        return ActivityCategory.financial;
      
      case ActivityAction.kitchenOrderReceived:
      case ActivityAction.kitchenOrderStarted:
      case ActivityAction.kitchenOrderCompleted:
      case ActivityAction.kitchenStatusChanged:
        return ActivityCategory.kitchen;
      
      case ActivityAction.inventoryAdded:
      case ActivityAction.inventoryUpdated:
      case ActivityAction.inventoryDeleted:
      case ActivityAction.stockAdjusted:
      case ActivityAction.lowStockAlert:
        return ActivityCategory.inventory;
      
      case ActivityAction.printerConfigured:
      case ActivityAction.printerAssigned:
      case ActivityAction.printerUnassigned:
      case ActivityAction.printJobSent:
      case ActivityAction.printJobFailed:
        return ActivityCategory.printing;
      
      case ActivityAction.screenAccessed:
      case ActivityAction.adminPanelAccessed:
      case ActivityAction.reportsAccessed:
        return ActivityCategory.navigation;
      
      case ActivityAction.dataImported:
      case ActivityAction.dataExported:
      case ActivityAction.reportGenerated:
        return ActivityCategory.reporting;
      
      default:
        return ActivityCategory.system;
    }
  }

  /// Creates ActivityLog from JSON
  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] as String? ?? '',
      action: ActivityAction.values.firstWhere(
        (e) => e.toString().split('.').last == (json['action'] ?? ''),
        orElse: () => ActivityAction.customAction,
      ),
      level: ActivityLevel.values.firstWhere(
        (e) => e.toString().split('.').last == (json['level'] ?? ''),
        orElse: () => ActivityLevel.info,
      ),
      category: ActivityCategory.values.firstWhere(
        (e) => e.toString().split('.').last == (json['category'] ?? ''),
        orElse: () => ActivityCategory.system,
      ),
      performedBy: json['performed_by'] as String? ?? '',
      performedByName: json['performed_by_name'] as String? ?? '',
      performedByRole: json['performed_by_role'] as String? ?? '',
      timestamp: json['timestamp'] != null 
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
      description: json['description'] as String? ?? '',
      targetId: json['target_id'] as String?,
      targetType: json['target_type'] as String?,
      targetName: json['target_name'] as String?,
      beforeData: json['before_data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['before_data'])
          : {},
      afterData: json['after_data'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['after_data'])
          : {},
      metadata: json['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['metadata'])
          : {},
      notes: json['notes'] as String?,
      deviceId: json['device_id'] as String?,
      sessionId: json['session_id'] as String?,
      ipAddress: json['ip_address'] as String?,
      screenName: json['screen_name'] as String?,
      isSystemAction: json['is_system_action'] == 1 || json['is_system_action'] == true,
      errorMessage: json['error_message'] as String?,
      financialAmount: json['financial_amount'] as double?,
      restaurantId: json['restaurant_id'] as String?,
      executionTime: json['execution_time'] != null
          ? Duration(milliseconds: json['execution_time'])
          : null,
    );
  }

  /// Converts ActivityLog to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action.toString().split('.').last,
      'level': level.toString().split('.').last,
      'category': category.toString().split('.').last,
      'performed_by': performedBy,
      'performed_by_name': performedByName,
      'performed_by_role': performedByRole,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
      'target_id': targetId,
      'target_type': targetType,
      'target_name': targetName,
      'before_data': beforeData,
      'after_data': afterData,
      'metadata': metadata,
      'notes': notes,
      'device_id': deviceId,
      'session_id': sessionId,
      'ip_address': ipAddress,
      'screen_name': screenName,
      'is_system_action': isSystemAction,
      'error_message': errorMessage,
      'financial_amount': financialAmount,
      'restaurant_id': restaurantId,
      'execution_time': executionTime?.inMilliseconds,
      'created_at': timestamp.toIso8601String(),
    };
  }

  /// Converts to SQLite-compatible map
  Map<String, dynamic> toSQLiteMap() {
    return {
      'id': id,
      'action': action.toString().split('.').last,
      'level': level.toString().split('.').last,
      'category': category.toString().split('.').last,
      'performed_by': performedBy,
      'performed_by_name': performedByName,
      'performed_by_role': performedByRole,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
      'target_id': targetId,
      'target_type': targetType,
      'target_name': targetName,
      'before_data': beforeData.isNotEmpty ? jsonEncode(beforeData) : null,
      'after_data': afterData.isNotEmpty ? jsonEncode(afterData) : null,
      'metadata': metadata.isNotEmpty ? jsonEncode(metadata) : null,
      'notes': notes,
      'device_id': deviceId,
      'session_id': sessionId,
      'ip_address': ipAddress,
      'screen_name': screenName,
      'is_system_action': isSystemAction ? 1 : 0,
      'error_message': errorMessage,
      'financial_amount': financialAmount,
      'restaurant_id': restaurantId,
      'execution_time': executionTime?.inMilliseconds,
      'created_at': timestamp.toIso8601String(),
    };
  }

  /// Gets user-friendly action description
  String get actionDescription {
    switch (action) {
      case ActivityAction.login:
        return 'Logged in';
      case ActivityAction.logout:
        return 'Logged out';
      case ActivityAction.userCreated:
        return 'Created user';
      case ActivityAction.userUpdated:
        return 'Updated user';
      case ActivityAction.userDeleted:
        return 'Deleted user';
      case ActivityAction.menuItemCreated:
        return 'Created menu item';
      case ActivityAction.menuItemUpdated:
        return 'Updated menu item';
      case ActivityAction.menuItemDeleted:
        return 'Deleted menu item';
      case ActivityAction.orderCreated:
        return 'Created order';
      case ActivityAction.orderUpdated:
        return 'Updated order';
      case ActivityAction.orderCancelled:
        return 'Cancelled order';
      case ActivityAction.orderCompleted:
        return 'Completed order';
      case ActivityAction.discountApplied:
        return 'Applied discount';
      case ActivityAction.paymentProcessed:
        return 'Processed payment';
      case ActivityAction.screenAccessed:
        return 'Accessed screen';
      case ActivityAction.adminPanelAccessed:
        return 'Accessed admin panel';
      case ActivityAction.settingsChanged:
        return 'Changed settings';
      case ActivityAction.printerConfigured:
        return 'Configured printer';
      case ActivityAction.stockAdjusted:
        return 'Adjusted stock';
      case ActivityAction.reportGenerated:
        return 'Generated report';
      default:
        return action.toString().split('.').last;
    }
  }

  /// Gets color for the activity level
  String get levelColor {
    switch (level) {
      case ActivityLevel.info:
        return '#2196F3';
      case ActivityLevel.warning:
        return '#FF9800';
      case ActivityLevel.error:
        return '#F44336';
      case ActivityLevel.critical:
        return '#9C27B0';
      case ActivityLevel.security:
        return '#E91E63';
    }
  }

  /// Gets color for the activity category
  String get categoryColor {
    switch (category) {
      case ActivityCategory.authentication:
        return '#4CAF50';
      case ActivityCategory.userManagement:
        return '#2196F3';
      case ActivityCategory.menuManagement:
        return '#FF9800';
      case ActivityCategory.orderManagement:
        return '#9C27B0';
      case ActivityCategory.financial:
        return '#4CAF50';
      case ActivityCategory.kitchen:
        return '#F44336';
      case ActivityCategory.inventory:
        return '#795548';
      case ActivityCategory.system:
        return '#607D8B';
      case ActivityCategory.navigation:
        return '#3F51B5';
      case ActivityCategory.printing:
        return '#FF5722';
      case ActivityCategory.reporting:
        return '#009688';
    }
  }

  /// Checks if this is a sensitive operation
  bool get isSensitiveOperation {
    return [
      ActivityAction.login,
      ActivityAction.logout,
      ActivityAction.pinEntered,
      ActivityAction.userCreated,
      ActivityAction.userDeleted,
      ActivityAction.passwordChanged,
      ActivityAction.paymentProcessed,
      ActivityAction.refundProcessed,
      ActivityAction.adminPanelAccessed,
      ActivityAction.settingsChanged,
      ActivityAction.databaseBackup,
      ActivityAction.databaseRestore,
    ].contains(action);
  }

  /// Checks if this is a financial operation
  bool get isFinancialOperation {
    return [
      ActivityAction.discountApplied,
      ActivityAction.discountRemoved,
      ActivityAction.tipAdded,
      ActivityAction.tipModified,
      ActivityAction.paymentProcessed,
      ActivityAction.paymentVoided,
      ActivityAction.refundProcessed,
    ].contains(action);
  }

  /// Gets the financial impact of this operation
  double? get financialImpact {
    return financialAmount;
  }

  @override
  String toString() {
    return 'ActivityLog(id: $id, action: $actionDescription, user: $performedByName, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ActivityLog && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Helper class for creating activity log entries
class ActivityLogBuilder {
  /// Creates a generic activity log
  static ActivityLog createLog({
    required ActivityAction action,
    required String performedBy,
    required String performedByName,
    required String performedByRole,
    ActivityLevel level = ActivityLevel.info,
    String? description,
    String? targetId,
    String? targetType,
    String? targetName,
    Map<String, dynamic>? beforeData,
    Map<String, dynamic>? afterData,
    Map<String, dynamic>? metadata,
    String? notes,
    String? deviceId,
    String? sessionId,
    String? ipAddress,
    String? screenName,
    bool isSystemAction = false,
    String? errorMessage,
    double? financialAmount,
    String? restaurantId,
    Duration? executionTime,
  }) {
    return ActivityLog(
      action: action,
      level: level,
      performedBy: performedBy,
      performedByName: performedByName,
      performedByRole: performedByRole,
      description: description ?? action.toString().split('.').last,
      targetId: targetId,
      targetType: targetType,
      targetName: targetName,
      beforeData: beforeData ?? {},
      afterData: afterData ?? {},
      metadata: metadata ?? {},
      notes: notes,
      deviceId: deviceId,
      sessionId: sessionId,
      ipAddress: ipAddress,
      screenName: screenName,
      isSystemAction: isSystemAction,
      errorMessage: errorMessage,
      financialAmount: financialAmount,
      restaurantId: restaurantId,
      executionTime: executionTime,
    );
  }

  /// Creates a login activity log
  static ActivityLog loginLog({
    required String userId,
    required String userName,
    required String userRole,
    String? deviceId,
    String? sessionId,
    String? ipAddress,
  }) {
    return createLog(
      action: ActivityAction.login,
      performedBy: userId,
      performedByName: userName,
      performedByRole: userRole,
      description: '$userName logged in',
      deviceId: deviceId,
      sessionId: sessionId,
      ipAddress: ipAddress,
      screenName: 'Login',
    );
  }

  /// Creates a logout activity log
  static ActivityLog logoutLog({
    required String userId,
    required String userName,
    required String userRole,
    String? reason,
    String? deviceId,
    String? sessionId,
  }) {
    return createLog(
      action: ActivityAction.logout,
      performedBy: userId,
      performedByName: userName,
      performedByRole: userRole,
      description: '$userName logged out',
      notes: reason,
      deviceId: deviceId,
      sessionId: sessionId,
      screenName: 'Logout',
    );
  }

  /// Creates a screen access activity log
  static ActivityLog screenAccessLog({
    required String userId,
    required String userName,
    required String userRole,
    required String screenName,
    String? deviceId,
    String? sessionId,
  }) {
    return createLog(
      action: ActivityAction.screenAccessed,
      performedBy: userId,
      performedByName: userName,
      performedByRole: userRole,
      description: '$userName accessed $screenName',
      screenName: screenName,
      deviceId: deviceId,
      sessionId: sessionId,
    );
  }

  /// Creates a user management activity log
  static ActivityLog userManagementLog({
    required ActivityAction action,
    required String performedBy,
    required String performedByName,
    required String performedByRole,
    required String targetUserId,
    required String targetUserName,
    Map<String, dynamic>? beforeData,
    Map<String, dynamic>? afterData,
    String? notes,
    String? deviceId,
    String? sessionId,
    String? screenName,
  }) {
    return createLog(
      action: action,
      performedBy: performedBy,
      performedByName: performedByName,
      performedByRole: performedByRole,
      description: '$performedByName ${action.toString().split('.').last} user: $targetUserName',
      targetId: targetUserId,
      targetType: 'user',
      targetName: targetUserName,
      beforeData: beforeData,
      afterData: afterData,
      notes: notes,
      deviceId: deviceId,
      sessionId: sessionId,
      screenName: screenName,
    );
  }

  /// Creates a financial activity log
  static ActivityLog financialLog({
    required ActivityAction action,
    required String performedBy,
    required String performedByName,
    required String performedByRole,
    required double amount,
    String? orderId,
    String? orderNumber,
    String? notes,
    String? deviceId,
    String? sessionId,
    String? screenName,
  }) {
    return createLog(
      action: action,
      performedBy: performedBy,
      performedByName: performedByName,
      performedByRole: performedByRole,
      description: '$performedByName ${action.toString().split('.').last} \$${amount.toStringAsFixed(2)}',
      targetId: orderId,
      targetType: 'order',
      targetName: orderNumber,
      financialAmount: amount,
      notes: notes,
      deviceId: deviceId,
      sessionId: sessionId,
      screenName: screenName,
    );
  }
} 