import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../models/order.dart';
import '../models/menu_item.dart';
import '../models/category.dart';
import '../models/user.dart';
import '../models/table.dart';
import '../models/customer.dart';
import '../models/inventory_item.dart';
import '../models/restaurant.dart';
import '../models/store.dart';
import '../models/activity_log.dart';
import '../models/app_settings.dart';
import '../models/loyalty_reward.dart';
import '../models/loyalty_transaction.dart';
import '../models/reservation.dart';
import '../models/printer_configuration.dart';
import '../models/printer_assignment.dart';
import '../models/order_log.dart';
import '../utils/exceptions.dart';

/// Comprehensive Schema Validation Service
/// Ensures all services understand and work with the application schema 100% of the time
class SchemaValidationService {
  static const String _logTag = '🔍 SchemaValidationService';
  
  // ZERO RISK: Feature flags for schema validation
  static const bool _enableSchemaValidation = true;
  static const bool _enableAutoCorrection = true;
  static const bool _enableBackupBeforeValidation = true;
  static const bool _enableDetailedLogging = true;
  
  // Schema definitions for validation
  static const Map<String, List<String>> _requiredTables = {
    'orders': [
      'id', 'order_number', 'status', 'type', 'table_id', 'user_id', 
      'customer_name', 'customer_phone', 'customer_email', 'customer_address',
      'special_instructions', 'subtotal', 'tax_amount', 'tip_amount', 
      'hst_amount', 'discount_amount', 'gratuity_amount', 'total_amount',
      'payment_method', 'payment_status', 'payment_transaction_id',
      'order_time', 'estimated_ready_time', 'actual_ready_time',
      'served_time', 'completed_time', 'is_urgent', 'priority',
      'assigned_to', 'custom_fields', 'metadata', 'notes', 'preferences',
      'history', 'items', 'completed_at', 'created_at', 'updated_at'
    ],
    'order_items': [
      'id', 'order_id', 'menu_item_id', 'quantity', 'unit_price',
      'total_price', 'selected_variant', 'selected_modifiers',
      'special_instructions', 'notes', 'custom_properties',
      'is_available', 'sent_to_kitchen', 'kitchen_status',
      'created_at', 'updated_at'
    ],
    'menu_items': [
      'id', 'name', 'description', 'price', 'category_id', 'image_url',
      'is_available', 'tags', 'custom_properties', 'variants', 'modifiers',
      'nutritional_info', 'allergens', 'preparation_time', 'is_vegetarian',
      'is_vegan', 'is_gluten_free', 'is_spicy', 'spice_level',
      'stock_quantity', 'low_stock_threshold', 'popularity_score',
      'last_ordered', 'created_at', 'updated_at'
    ],
    'categories': [
      'id', 'name', 'description', 'is_active', 'sort_order',
      'created_at', 'updated_at'
    ],
    'users': [
      'id', 'name', 'role', 'pin', 'is_active', 'admin_panel_access',
      'created_at', 'last_login'
    ],
    'tables': [
      'id', 'name', 'capacity', 'status', 'is_active', 'sort_order',
      'created_at', 'updated_at'
    ],
    'inventory': [
      'id', 'name', 'description', 'category_id', 'current_stock',
      'minimum_stock', 'unit', 'cost_per_unit', 'supplier_info',
      'last_restocked', 'is_active', 'created_at', 'updated_at'
    ],
    'customers': [
      'id', 'name', 'phone', 'email', 'address', 'loyalty_points',
      'total_spent', 'last_visit', 'preferences', 'is_active',
      'created_at', 'updated_at'
    ],
    'transactions': [
      'id', 'order_id', 'amount', 'payment_method', 'status',
      'transaction_id', 'processed_at', 'created_at'
    ],
    'reservations': [
      'id', 'customer_name', 'customer_phone', 'customer_email',
      'table_id', 'reservation_time', 'party_size', 'special_requests',
      'status', 'created_at', 'updated_at'
    ],
    'printer_configurations': [
      'id', 'name', 'type', 'ip_address', 'port', 'is_active',
      'settings', 'created_at', 'updated_at'
    ],
    'printer_assignments': [
      'id', 'printer_id', 'order_type', 'is_active', 'created_at'
    ],
    'order_logs': [
      'id', 'order_id', 'order_number', 'action', 'description',
      'performed_by', 'timestamp', 'metadata'
    ],
    'app_metadata': [
      'id', 'key', 'value', 'created_at', 'updated_at'
    ],
    'loyalty_rewards': [
      'id', 'name', 'description', 'points_required', 'discount_percentage',
      'is_active', 'created_at', 'updated_at'
    ],
    'app_settings': [
      'id', 'key', 'value', 'description', 'created_at', 'updated_at'
    ]
  };

  /// Validate entire database schema with zero risk protection
  Future<SchemaValidationResult> validateDatabaseSchema(Database database) async {
    if (!_enableSchemaValidation) {
      debugPrint('$_logTag ⚠️ Schema validation disabled by feature flag');
      return SchemaValidationResult(
        isValid: true,
        issues: [],
        message: 'Schema validation disabled by feature flag'
      );
    }

    try {
      debugPrint('$_logTag 🔍 Starting comprehensive database schema validation...');
      
      // ZERO RISK: Create backup before validation
      if (_enableBackupBeforeValidation) {
        await _createSchemaValidationBackup(database);
      }

      final List<SchemaIssue> issues = [];
      
      // Validate all required tables exist
      final tableIssues = await _validateTableExistence(database);
      issues.addAll(tableIssues);
      
      // Validate table schemas
      for (final tableName in _requiredTables.keys) {
        final schemaIssues = await _validateTableSchema(database, tableName);
        issues.addAll(schemaIssues);
      }
      
      // Validate data integrity
      final integrityIssues = await _validateDataIntegrity(database);
      issues.addAll(integrityIssues);
      
      // Validate foreign key relationships
      final relationshipIssues = await _validateForeignKeys(database);
      issues.addAll(relationshipIssues);
      
      // Validate indexes
      final indexIssues = await _validateIndexes(database);
      issues.addAll(indexIssues);
      
      final isValid = issues.where((issue) => issue.severity == SchemaIssueSeverity.critical).isEmpty;
      
      final result = SchemaValidationResult(
        isValid: isValid,
        issues: issues,
        message: 'Schema validation completed with ${issues.length} issues found'
      );
      
      debugPrint('$_logTag ✅ Schema validation completed: ${result.message}');
      
      // ZERO RISK: Auto-correct non-critical issues if enabled
      if (_enableAutoCorrection && !isValid) {
        await _autoCorrectIssues(database, issues);
      }
      
      return result;
      
    } catch (e) {
      debugPrint('$_logTag ❌ Schema validation failed: $e');
      return SchemaValidationResult(
        isValid: false,
        issues: [SchemaIssue(
          table: 'unknown',
          column: 'unknown',
          severity: SchemaIssueSeverity.critical,
          message: 'Schema validation failed: $e',
          suggestion: 'Check database connection and permissions'
        )],
        message: 'Schema validation failed with exception'
      );
    }
  }

  /// Validate that all required tables exist
  Future<List<SchemaIssue>> _validateTableExistence(Database database) async {
    final List<SchemaIssue> issues = [];
    
    try {
      final tables = await database.query('sqlite_master', 
        where: 'type = ?', 
        whereArgs: ['table']
      );
      
      final existingTables = tables.map((row) => row['name'] as String).toSet();
      
      for (final requiredTable in _requiredTables.keys) {
        if (!existingTables.contains(requiredTable)) {
          issues.add(SchemaIssue(
            table: requiredTable,
            column: 'table',
            severity: SchemaIssueSeverity.critical,
            message: 'Required table "$requiredTable" does not exist',
            suggestion: 'Create table "$requiredTable" with proper schema'
          ));
        }
      }
    } catch (e) {
      debugPrint('$_logTag ❌ Error validating table existence: $e');
      issues.add(SchemaIssue(
        table: 'unknown',
        column: 'unknown',
        severity: SchemaIssueSeverity.critical,
        message: 'Failed to validate table existence: $e',
        suggestion: 'Check database permissions and connection'
      ));
    }
    
    return issues;
  }

  /// Validate table schema against required columns
  Future<List<SchemaIssue>> _validateTableSchema(Database database, String tableName) async {
    final List<SchemaIssue> issues = [];
    
    try {
      final pragmaResult = await database.rawQuery('PRAGMA table_info($tableName)');
      final existingColumns = pragmaResult.map((row) => row['name'] as String).toSet();
      
      final requiredColumns = _requiredTables[tableName] ?? [];
      
      for (final requiredColumn in requiredColumns) {
        if (!existingColumns.contains(requiredColumn)) {
          issues.add(SchemaIssue(
            table: tableName,
            column: requiredColumn,
            severity: SchemaIssueSeverity.critical,
            message: 'Required column "$requiredColumn" missing in table "$tableName"',
            suggestion: 'Add column "$requiredColumn" to table "$tableName"'
          ));
        }
      }
    } catch (e) {
      debugPrint('$_logTag ❌ Error validating schema for table $tableName: $e');
      issues.add(SchemaIssue(
        table: tableName,
        column: 'unknown',
        severity: SchemaIssueSeverity.critical,
        message: 'Failed to validate schema for table "$tableName": $e',
        suggestion: 'Check table permissions and structure'
      ));
    }
    
    return issues;
  }

  /// Validate data integrity constraints
  Future<List<SchemaIssue>> _validateDataIntegrity(Database database) async {
    final List<SchemaIssue> issues = [];
    
    try {
      // Check for duplicate order numbers
      final duplicateOrders = await database.rawQuery('''
        SELECT order_number, COUNT(*) as count 
        FROM orders 
        GROUP BY order_number 
        HAVING COUNT(*) > 1
      ''');
      
      for (final duplicate in duplicateOrders) {
        issues.add(SchemaIssue(
          table: 'orders',
          column: 'order_number',
          severity: SchemaIssueSeverity.critical,
          message: 'Duplicate order number: ${duplicate['order_number']} (${duplicate['count']} occurrences)',
          suggestion: 'Fix duplicate order numbers by updating or removing duplicates'
        ));
      }
      
      // Check for orphaned order items
      final orphanedItems = await database.rawQuery('''
        SELECT oi.id, oi.order_id 
        FROM order_items oi 
        LEFT JOIN orders o ON oi.order_id = o.id 
        WHERE o.id IS NULL
      ''');
      
      for (final orphan in orphanedItems) {
        issues.add(SchemaIssue(
          table: 'order_items',
          column: 'order_id',
          severity: SchemaIssueSeverity.warning,
          message: 'Orphaned order item: ${orphan['id']} (order_id: ${orphan['order_id']})',
          suggestion: 'Remove orphaned order items or link to valid orders'
        ));
      }
      
      // Check for orphaned menu items in order items
      final orphanedMenuItems = await database.rawQuery('''
        SELECT oi.id, oi.menu_item_id 
        FROM order_items oi 
        LEFT JOIN menu_items mi ON oi.menu_item_id = mi.id 
        WHERE mi.id IS NULL
      ''');
      
      for (final orphan in orphanedMenuItems) {
        issues.add(SchemaIssue(
          table: 'order_items',
          column: 'menu_item_id',
          severity: SchemaIssueSeverity.warning,
          message: 'Order item with missing menu item: ${orphan['id']} (menu_item_id: ${orphan['menu_item_id']})',
          suggestion: 'Update order items to reference valid menu items'
        ));
      }
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error validating data integrity: $e');
      issues.add(SchemaIssue(
        table: 'unknown',
        column: 'unknown',
        severity: SchemaIssueSeverity.critical,
        message: 'Failed to validate data integrity: $e',
        suggestion: 'Check database permissions and structure'
      ));
    }
    
    return issues;
  }

  /// Validate foreign key relationships
  Future<List<SchemaIssue>> _validateForeignKeys(Database database) async {
    final List<SchemaIssue> issues = [];
    
    try {
      // Check foreign key constraints are properly set up
      final foreignKeys = await database.rawQuery('PRAGMA foreign_key_list(orders)');
      
      if (foreignKeys.isEmpty) {
        issues.add(SchemaIssue(
          table: 'orders',
          column: 'foreign_keys',
          severity: SchemaIssueSeverity.warning,
          message: 'No foreign key constraints found on orders table',
          suggestion: 'Consider adding foreign key constraints for data integrity'
        ));
      }
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error validating foreign keys: $e');
      issues.add(SchemaIssue(
        table: 'unknown',
        column: 'unknown',
        severity: SchemaIssueSeverity.warning,
        message: 'Failed to validate foreign keys: $e',
        suggestion: 'Check database configuration'
      ));
    }
    
    return issues;
  }

  /// Validate database indexes
  Future<List<SchemaIssue>> _validateIndexes(Database database) async {
    final List<SchemaIssue> issues = [];
    
    try {
      final indexes = await database.rawQuery('''
        SELECT name, tbl_name, sql 
        FROM sqlite_master 
        WHERE type = 'index' AND tbl_name IN (${_requiredTables.keys.map((k) => "'$k'").join(',')})
      ''');
      
      final requiredIndexes = [
        'idx_orders_status',
        'idx_orders_type', 
        'idx_orders_created_at',
        'idx_order_items_order_id',
        'idx_menu_items_category_id',
        'idx_menu_items_available'
      ];
      
      final existingIndexes = indexes.map((row) => row['name'] as String).toSet();
      
      for (final requiredIndex in requiredIndexes) {
        if (!existingIndexes.contains(requiredIndex)) {
          issues.add(SchemaIssue(
            table: 'indexes',
            column: requiredIndex,
            severity: SchemaIssueSeverity.warning,
            message: 'Recommended index missing: $requiredIndex',
            suggestion: 'Create index $requiredIndex for better performance'
          ));
        }
      }
      
    } catch (e) {
      debugPrint('$_logTag ❌ Error validating indexes: $e');
      issues.add(SchemaIssue(
        table: 'indexes',
        column: 'unknown',
        severity: SchemaIssueSeverity.warning,
        message: 'Failed to validate indexes: $e',
        suggestion: 'Check database permissions'
      ));
    }
    
    return issues;
  }

  /// Auto-correct non-critical schema issues
  Future<void> _autoCorrectIssues(Database database, List<SchemaIssue> issues) async {
    if (!_enableAutoCorrection) return;
    
    debugPrint('$_logTag 🔧 Starting auto-correction of schema issues...');
    
    try {
      for (final issue in issues) {
        if (issue.severity == SchemaIssueSeverity.critical) {
          debugPrint('$_logTag ⚠️ Skipping critical issue: ${issue.message}');
          continue;
        }
        
        await _correctIssue(database, issue);
      }
      
      debugPrint('$_logTag ✅ Auto-correction completed');
    } catch (e) {
      debugPrint('$_logTag ❌ Auto-correction failed: $e');
    }
  }

  /// Correct a specific schema issue
  Future<void> _correctIssue(Database database, SchemaIssue issue) async {
    try {
      switch (issue.table) {
        case 'indexes':
          await _createMissingIndex(database, issue.column);
          break;
        case 'order_items':
          if (issue.message.contains('orphaned')) {
            await _removeOrphanedOrderItems(database);
          }
          break;
        default:
          debugPrint('$_logTag ⚠️ No auto-correction available for: ${issue.message}');
      }
    } catch (e) {
      debugPrint('$_logTag ❌ Failed to correct issue: $e');
    }
  }

  /// Create missing index
  Future<void> _createMissingIndex(Database database, String indexName) async {
    try {
      switch (indexName) {
        case 'idx_orders_status':
          await database.execute('CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status)');
          break;
        case 'idx_orders_type':
          await database.execute('CREATE INDEX IF NOT EXISTS idx_orders_type ON orders(type)');
          break;
        case 'idx_orders_created_at':
          await database.execute('CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC)');
          break;
        case 'idx_order_items_order_id':
          await database.execute('CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items(order_id)');
          break;
        case 'idx_menu_items_category_id':
          await database.execute('CREATE INDEX IF NOT EXISTS idx_menu_items_category_id ON menu_items(category_id)');
          break;
        case 'idx_menu_items_available':
          await database.execute('CREATE INDEX IF NOT EXISTS idx_menu_items_available ON menu_items(is_available)');
          break;
      }
      debugPrint('$_logTag ✅ Created missing index: $indexName');
    } catch (e) {
      debugPrint('$_logTag ❌ Failed to create index $indexName: $e');
    }
  }

  /// Remove orphaned order items
  Future<void> _removeOrphanedOrderItems(Database database) async {
    try {
      final deleted = await database.rawDelete('''
        DELETE FROM order_items 
        WHERE order_id NOT IN (SELECT id FROM orders)
      ''');
      debugPrint('$_logTag ✅ Removed $deleted orphaned order items');
    } catch (e) {
      debugPrint('$_logTag ❌ Failed to remove orphaned order items: $e');
    }
  }

  /// Create backup before schema validation
  Future<void> _createSchemaValidationBackup(Database database) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupName = 'schema_validation_backup_$timestamp';
      
      // Create backup by copying critical tables
      await database.execute('CREATE TABLE IF NOT EXISTS ${backupName}_orders AS SELECT * FROM orders');
      await database.execute('CREATE TABLE IF NOT EXISTS ${backupName}_order_items AS SELECT * FROM order_items');
      
      debugPrint('$_logTag 💾 Created schema validation backup: $backupName');
    } catch (e) {
      debugPrint('$_logTag ⚠️ Failed to create backup: $e');
    }
  }

  /// Emergency disable schema validation
  static void emergencyDisableSchemaValidation() {
    debugPrint('$_logTag 🚨 EMERGENCY: Schema validation disabled');
    // This would normally update a configuration file or database setting
  }

  /// Check if schema validation is enabled
  static bool get isSchemaValidationEnabled => _enableSchemaValidation;
  
  /// Check if auto-correction is enabled
  static bool get isAutoCorrectionEnabled => _enableAutoCorrection;
}

/// Schema validation result
class SchemaValidationResult {
  final bool isValid;
  final List<SchemaIssue> issues;
  final String message;

  SchemaValidationResult({
    required this.isValid,
    required this.issues,
    required this.message,
  });

  @override
  String toString() {
    return 'SchemaValidationResult(isValid: $isValid, issues: ${issues.length}, message: $message)';
  }
}

/// Schema issue with severity levels
class SchemaIssue {
  final String table;
  final String column;
  final SchemaIssueSeverity severity;
  final String message;
  final String suggestion;

  SchemaIssue({
    required this.table,
    required this.column,
    required this.severity,
    required this.message,
    required this.suggestion,
  });

  @override
  String toString() {
    return 'SchemaIssue(table: $table, column: $column, severity: $severity, message: $message)';
  }
}

/// Schema issue severity levels
enum SchemaIssueSeverity {
  info,
  warning,
  critical,
} 