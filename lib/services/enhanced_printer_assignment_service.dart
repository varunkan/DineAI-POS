import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:collection/collection.dart';
import 'package:sqflite/sqflite.dart';
import '../models/printer_assignment.dart';
import '../models/printer_configuration.dart';
import '../models/order.dart';
import '../models/menu_item.dart';
import '../services/database_service.dart';
import '../services/printer_configuration_service.dart';
import '../services/unified_printer_service.dart';

/// Enhanced Printer Assignment Service
/// Fixes all issues with persistence, multi-printer assignments, and order item uniqueness
class EnhancedPrinterAssignmentService extends ChangeNotifier {
  static const String _logTag = '🎯 EnhancedPrinterAssignmentService';
  
  final DatabaseService _databaseService;
  final PrinterConfigurationService _printerConfigService;
  final UnifiedPrinterService? _unifiedPrinterService;
  
  // Assignment state management
  List<PrinterAssignment> _assignments = [];
  final Map<String, List<String>> _categoryToPrinters = {}; // categoryId -> [printerId]
  final Map<String, List<String>> _menuItemToPrinters = {}; // menuItemId -> [printerId]
  
  // State flags
  bool _isInitialized = false;
  bool _isLoading = false;
  Timer? _persistenceTimer;
  
  EnhancedPrinterAssignmentService({
    required DatabaseService databaseService,
    required PrinterConfigurationService printerConfigService,
    UnifiedPrinterService? unifiedPrinterService,
  }) : _databaseService = databaseService,
       _printerConfigService = printerConfigService,
       _unifiedPrinterService = unifiedPrinterService;
  
  // Getters
  List<PrinterAssignment> get assignments => List.unmodifiable(_assignments);
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  int get totalAssignments => _assignments.length;
  
  /// Initialize the enhanced service
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    
    try {
      _isLoading = true;
      notifyListeners();
      
      await _createAssignmentTables();
      await _loadAssignmentsFromDatabase();
      await _rebuildAssignmentMaps();
      await _startPersistenceMonitoring();
      
      _isInitialized = true;
      
    } catch (e) {
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  /// Create printer assignment tables with enhanced schema
  Future<void> _createAssignmentTables() async {
    try {
      final db = await _databaseService.database;
      if (db == null) return;
      
      // Enhanced assignments table with additional fields
      await db.execute('''
        CREATE TABLE IF NOT EXISTS enhanced_printer_assignments (
          id TEXT PRIMARY KEY,
          printer_id TEXT NOT NULL,
          printer_name TEXT NOT NULL,
          printer_address TEXT NOT NULL,
          assignment_type TEXT NOT NULL,
          target_id TEXT NOT NULL,
          target_name TEXT NOT NULL,
          priority INTEGER DEFAULT 0,
          is_active INTEGER DEFAULT 1,
          is_persistent INTEGER DEFAULT 1,
          created_at TEXT DEFAULT CURRENT_TIMESTAMP,
          updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
          metadata TEXT
        )
      ''');
      
      // Index for performance
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_enhanced_assignments_target 
        ON enhanced_printer_assignments(target_id, assignment_type)
      ''');
      
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_enhanced_assignments_printer 
        ON enhanced_printer_assignments(printer_id)
      ''');
      
    } catch (e) {
    }
  }
  
  /// Load assignments from database with enhanced persistence
  Future<void> _loadAssignmentsFromDatabase() async {
    try {
      final db = await _databaseService.database;
      if (db == null) return;
      
      // First try enhanced table
      List<Map<String, dynamic>> maps = [];
      try {
        maps = await db.query('enhanced_printer_assignments', orderBy: 'priority DESC, created_at ASC');
      } catch (e) {
        // Fallback to original table if enhanced doesn't exist
        try {
          maps = await db.query('printer_assignments', orderBy: 'created_at ASC');
        } catch (fallbackError) {
          return;
        }
      }
      
      _assignments.clear();
      
      for (final map in maps) {
        try {
          final assignment = _assignmentFromMap(map);
          if (assignment != null) {
            _assignments.add(assignment);
          }
        } catch (e) {
        }
      }
      
      
      // Log persistent assignments
      if (_assignments.isNotEmpty) {
        for (final assignment in _assignments) {
        }
      }
      
    } catch (e) {
    }
  }
  
  /// Rebuild assignment maps for quick lookup
  Future<void> _rebuildAssignmentMaps() async {
    _categoryToPrinters.clear();
    _menuItemToPrinters.clear();
    
    for (final assignment in _assignments.where((a) => a.isActive)) {
      if (assignment.assignmentType == AssignmentType.category) {
        if (!_categoryToPrinters.containsKey(assignment.targetId)) {
          _categoryToPrinters[assignment.targetId] = [];
        }
        _categoryToPrinters[assignment.targetId]!.add(assignment.printerId);
      } else if (assignment.assignmentType == AssignmentType.menuItem) {
        if (!_menuItemToPrinters.containsKey(assignment.targetId)) {
          _menuItemToPrinters[assignment.targetId] = [];
        }
        _menuItemToPrinters[assignment.targetId]!.add(assignment.printerId);
      }
    }
    
  }
  
  /// Start persistence monitoring
  Future<void> _startPersistenceMonitoring() async {
    // Monitor persistence every 30 seconds
    _persistenceTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _verifyPersistence();
    });
  }
  
  /// Verify persistence integrity
  Future<void> _verifyPersistence() async {
    try {
      final db = await _databaseService.database;
      if (db == null) return;
      
      final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM enhanced_printer_assignments WHERE is_active = 1');
      final dbCount = countResult.first['count'] as int;
      final memoryCount = _assignments.where((a) => a.isActive).length;
      
      if (dbCount != memoryCount) {
        await _loadAssignmentsFromDatabase();
        await _rebuildAssignmentMaps();
        notifyListeners();
      }
    } catch (e) {
    }
  }
  
  /// Add assignment with enhanced persistence
  Future<bool> addAssignment({
    required String printerId,
    required AssignmentType assignmentType,
    required String targetId,
    required String targetName,
    int priority = 0,
  }) async {
    try {
      
      // 🚨 URGENT: Get printer configuration from both services (old and new)
      PrinterConfiguration? printerConfig = await _printerConfigService.getConfigurationById(printerId);
      
      // If not found in old service, check UnifiedPrinterService
      if (printerConfig == null && _unifiedPrinterService != null) {
        printerConfig = _unifiedPrinterService!.printers.firstWhereOrNull((p) => p.id == printerId);
      }
      
      if (printerConfig == null) {
        return false;
      }

      // 🚨 URGENT: Check if the target category/item exists before creating assignment
      if (assignmentType == AssignmentType.category) {
        final categoryExists = await _checkCategoryExists(targetId);
        if (!categoryExists) {
          await _createPlaceholderCategory(targetId, targetName);
        }
      } else if (assignmentType == AssignmentType.menuItem) {
        final itemExists = await _checkMenuItemExists(targetId);
        if (!itemExists) {
          await _createPlaceholderMenuItem(targetId, targetName);
        }
      }
      
      // Check if this specific assignment already exists
      final existingAssignment = _assignments
          .where((a) => a.printerId == printerId && 
                       a.targetId == targetId && 
                       a.assignmentType == assignmentType)
          .firstOrNull;
      
      if (existingAssignment != null) {
        return false;
      }
      
      // Create assignment
      final assignment = PrinterAssignment(
        printerId: printerId,
        printerName: printerConfig.name,
        printerAddress: printerConfig.fullAddress,
        assignmentType: assignmentType,
        targetId: targetId,
        targetName: targetName,
        priority: priority,
        isActive: true,
      );
      
      // Save to database first (ensure FK safety by upserting printer configuration)
      final db = await _databaseService.database;
      if (db == null) throw Exception('Database not available');

      try {
        // Insert assignment directly without foreign key dependency
        await db.insert('enhanced_printer_assignments', {
          'id': assignment.id,
          'printer_id': assignment.printerId,
          'printer_name': assignment.printerName,
          'printer_address': assignment.printerAddress,
          'assignment_type': assignment.assignmentType.name,
          'target_id': assignment.targetId,
          'target_name': assignment.targetName,
          'priority': assignment.priority,
          'is_active': assignment.isActive ? 1 : 0,
          'is_persistent': 1,
          'created_at': assignment.createdAt.toIso8601String(),
          'updated_at': assignment.updatedAt.toIso8601String(),
        });
      } catch (e) {
        // Don't throw - just return false to prevent breaking menu item addition
        return false;
      }
      
      // Add to memory
      _assignments.add(assignment);
      
      // Update maps
      await _rebuildAssignmentMaps();
      
      
      notifyListeners();
      return true;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Get all printer assignments for a menu item (handles uniqueness)
  List<PrinterAssignment> getAssignmentsForMenuItem(String menuItemId, String categoryId) {
    List<PrinterAssignment> result = [];
    
    // Priority 1: Specific menu item assignments
    final menuItemAssignments = _assignments.where(
      (a) => a.isActive && 
             a.assignmentType == AssignmentType.menuItem && 
             a.targetId == menuItemId
    ).toList();
    
    if (menuItemAssignments.isNotEmpty) {
      result.addAll(menuItemAssignments);
    }
    
    // Priority 2: Category assignments (if no specific menu item assignments)
    if (result.isEmpty) {
      final categoryAssignments = _assignments.where(
        (a) => a.isActive && 
               a.assignmentType == AssignmentType.category && 
               a.targetId == categoryId
      ).toList();
      
      if (categoryAssignments.isNotEmpty) {
        result.addAll(categoryAssignments);
      }
    }
    
    // Sort by priority
    result.sort((a, b) => b.priority.compareTo(a.priority));
    
    return result;
  }
  
  /// Get single assignment for menu item (for backward compatibility)
  PrinterAssignment? getAssignmentForMenuItem(String menuItemId, String categoryId) {
    final assignments = getAssignmentsForMenuItem(menuItemId, categoryId);
    return assignments.isNotEmpty ? assignments.first : null;
  }
  
  /// Get assignment statistics for admin panel
  Future<Map<String, dynamic>> getAssignmentStats() async {
    final totalAssignments = _assignments.length;
    final categoryAssignments = _assignments.where((a) => a.assignmentType == AssignmentType.category).length;
    final menuItemAssignments = _assignments.where((a) => a.assignmentType == AssignmentType.menuItem).length;
    final activePrinters = _assignments.map((a) => a.printerId).toSet().length;
    
    return {
      'totalAssignments': totalAssignments,
      'categoryAssignments': categoryAssignments,
      'menuItemAssignments': menuItemAssignments,
      'activePrinters': activePrinters,
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }
  
  /// Clear all assignments (for sync service)
  Future<void> clearAllAssignments() async {
    try {
      final db = await _databaseService.database;
      if (db == null) return;
      
      // Clear from database
      await db.delete('enhanced_printer_assignments');
      
      // Clear in-memory state
      _assignments.clear();
      _categoryToPrinters.clear();
      _menuItemToPrinters.clear();
      
      notifyListeners();
      
    } catch (e) {
    }
  }
  
  /// Segregate order items by printer assignments with uniqueness handling
  Future<Map<String, List<OrderItem>>> segregateOrderItems(Order order) async {
    final Map<String, List<OrderItem>> itemsByPrinter = {};
    
    try {
      
      // Group items by unique ID to handle duplicates properly
      final Map<String, List<OrderItem>> itemsByUniqueId = {};
      for (final item in order.items) {
        final key = '${item.menuItem.id}_${item.id}'; // Use both menu item ID and order item ID
        if (!itemsByUniqueId.containsKey(key)) {
          itemsByUniqueId[key] = [];
        }
        itemsByUniqueId[key]!.add(item);
      }
      
      // Process each unique item
      for (final entry in itemsByUniqueId.entries) {
        final items = entry.value;
        final firstItem = items.first;
        
        // Get assignments for this menu item
        final assignments = getAssignmentsForMenuItem(
          firstItem.menuItem.id,
          firstItem.menuItem.categoryId ?? '',
        );
        
        if (assignments.isNotEmpty) {
          // Distribute items across assigned printers
          for (final assignment in assignments) {
            if (!itemsByPrinter.containsKey(assignment.printerId)) {
              itemsByPrinter[assignment.printerId] = [];
            }
            // Add each unique item instance to the printer
            itemsByPrinter[assignment.printerId]!.addAll(items);
          }
          
        } else {
          // No assignment found - use default printer
          const defaultPrinterId = 'default_printer';
          if (!itemsByPrinter.containsKey(defaultPrinterId)) {
            itemsByPrinter[defaultPrinterId] = [];
          }
          itemsByPrinter[defaultPrinterId]!.addAll(items);
          
        }
      }
      
      for (final entry in itemsByPrinter.entries) {
      }
      
      return itemsByPrinter;
      
    } catch (e) {
      // Fallback: return all items for default printer
      return {'default_printer': order.items};
    }
  }
  
  /// Remove assignment
  Future<bool> removeAssignment(String assignmentId) async {
    try {
      final db = await _databaseService.database;
      if (db == null) return false;
      
      // Remove from database
      await db.delete(
        'enhanced_printer_assignments',
        where: 'id = ?',
        whereArgs: [assignmentId],
      );
      
      // Remove from memory
      _assignments.removeWhere((a) => a.id == assignmentId);
      
      // Update maps
      await _rebuildAssignmentMaps();
      
      notifyListeners();
      return true;
      
    } catch (e) {
      return false;
    }
  }
  
  /// Convert database map to assignment
  PrinterAssignment? _assignmentFromMap(Map<String, dynamic> map) {
    try {
      return PrinterAssignment(
        id: map['id'],
        printerId: map['printer_id'],
        printerName: map['printer_name'],
        printerAddress: map['printer_address'],
        assignmentType: AssignmentType.values.firstWhere(
          (type) => type.name == map['assignment_type'],
          orElse: () => AssignmentType.category,
        ),
        targetId: map['target_id'],
        targetName: map['target_name'],
        priority: map['priority'] ?? 0,
        isActive: (map['is_active'] ?? 1) == 1,
        createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
      );
    } catch (e) {
      return null;
    }
  }
  
  /// 🚨 URGENT: Check if a category exists in the database
  Future<bool> _checkCategoryExists(String categoryId) async {
    try {
      final db = await _databaseService.database;
      if (db == null) {
        return false;
      }
      final result = await db.query(
        'categories',
        where: 'id = ?',
        whereArgs: [categoryId],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// 🚨 URGENT: Check if a menu item exists in the database
  Future<bool> _checkMenuItemExists(String itemId) async {
    try {
      final db = await _databaseService.database;
      if (db == null) {
        return false;
      }
      final result = await db.query(
        'menu_items',
        where: 'id = ?',
        whereArgs: [itemId],
        limit: 1,
      );
      return result.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// 🚨 URGENT: Create a placeholder category to prevent foreign key constraint errors
  Future<void> _createPlaceholderCategory(String categoryId, String categoryName) async {
    try {
      final db = await _databaseService.database;
      if (db == null) return;
      
      await db.insert(
        'categories',
        {
          'id': categoryId,
          'name': categoryName,
          'description': 'Auto-created for printer assignment',
          'sort_order': 999,
          'is_active': 1,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore, // Don't fail if already exists
      );
    } catch (e) {
    }
  }

  /// 🚨 URGENT: Create a placeholder menu item to prevent foreign key constraint errors
  Future<void> _createPlaceholderMenuItem(String itemId, String itemName) async {
    try {
      final db = await _databaseService.database;
      if (db == null) return;

      // Ensure default category exists for potential FK on category_id
      await db.insert(
        'categories',
        {
          'id': 'default_category',
          'name': 'Uncategorized',
          'description': 'Auto-created default category',
          'sort_order': 999,
          'is_active': 1,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      
      await db.insert(
        'menu_items',
        {
          'id': itemId,
          'name': itemName,
          'description': 'Auto-created for printer assignment',
          'price': 0.0,
          'category_id': 'default_category',
          'is_available': 1,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore, // Don't fail if already exists
      );
    } catch (e) {
    }
  }

  /// Dispose resources
  @override
  void dispose() {
    _persistenceTimer?.cancel();
    super.dispose();
  }
} 