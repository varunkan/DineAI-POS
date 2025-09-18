import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/table.dart' as restaurant_table;
import 'package:uuid/uuid.dart';
import 'package:ai_pos_system/models/menu_item.dart';
import 'package:ai_pos_system/services/unified_sync_service.dart';

class TableService with ChangeNotifier {
  final SharedPreferences _prefs;
  List<restaurant_table.Table> _tables = [];
  static const String _tablesKey = 'restaurant_tables';

  TableService(this._prefs) {
    _loadTables();
  }

  Future<void> _loadTables() async {
    final String? tablesJson = _prefs.getString(_tablesKey);
    if (tablesJson == null) return;

    final List<dynamic> tablesList = jsonDecode(tablesJson);
    _tables = tablesList.map((table) => restaurant_table.Table.fromJson(table)).toList();
    
    // Safely notify listeners
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint('Error notifying listeners during load tables: $e');
        }
      });
    } catch (e) {
      debugPrint('Error scheduling notification during load tables: $e');
    }
  }

  Future<void> _saveTables() async {
    final String tablesJson =
        jsonEncode(List<dynamic>.from(_tables.map((table) => table.toJson())));
    await _prefs.setString(_tablesKey, tablesJson);
  }

  List<restaurant_table.Table> get tables => _tables;

  Future<List<restaurant_table.Table>> getTables() async {
    return _tables;
  }

  Future<void> addTable(restaurant_table.Table table) async {
    _tables.add(table);
    await _saveTables();
    
    // ENHANCEMENT: Automatic Firebase sync trigger
    try {
      final unifiedSyncService = UnifiedSyncService.instance;
      await unifiedSyncService.syncTableToFirebase(table, 'created');
    } catch (e) {
      debugPrint('⚠️ Failed to sync table creation to Firebase: $e');
    }
    
    // Safely notify listeners
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint('Error notifying listeners during add table: $e');
        }
      });
    } catch (e) {
      debugPrint('Error scheduling notification during add table: $e');
    }
  }

  Future<void> createTable(int number, int capacity, {String? userId}) async {
    final newTable = restaurant_table.Table(
      id: 'table_$number', // Use consistent ID format
      number: number,
      capacity: capacity,
      status: restaurant_table.TableStatus.available,
    );
    await addTable(newTable);
  }

  Future<List<restaurant_table.Table>> getTablesForUser(String userId) async {
    return _tables.where((table) => table.userId == userId).toList();
  }

  Future<void> updateTableStatus(String tableId, restaurant_table.TableStatus status) async {
    final table = getTableById(tableId);
    if (table != null) {
      final updatedTable = table.copyWith(
        status: status,
        occupiedAt: status == restaurant_table.TableStatus.occupied ? DateTime.now() : table.occupiedAt,
      );
      await updateTable(updatedTable);
    }
  }

  Future<void> occupyTable(String tableId, {String? customerName}) async {
    final table = getTableById(tableId);
    if (table != null) {
      final updatedTable = table.copyWith(
        status: restaurant_table.TableStatus.occupied,
        customerName: customerName,
        occupiedAt: DateTime.now(),
      );
      await updateTable(updatedTable);
    }
  }

  Future<void> markTableForCleaning(String tableId) async {
    final table = getTableById(tableId);
    if (table != null) {
      final updatedTable = table.copyWith(
        status: restaurant_table.TableStatus.cleaning,
      );
      await updateTable(updatedTable);
    }
  }

  Future<void> releaseTable(String tableId) async {
    final tableIndex = _tables.indexWhere((t) => t.id == tableId);

    if (tableIndex != -1) {
      final table = _tables[tableIndex];
      _tables[tableIndex] = table.copyWith(
        userId: null,
        customerName: null,
        status: restaurant_table.TableStatus.cleaning,
        occupiedAt: null,
      );
      await _saveTables();
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during release table: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during release table: $e');
      }
    }
  }

  Future<void> freeTable(String tableId) async {
    final tableIndex = _tables.indexWhere((t) => t.id == tableId);

    if (tableIndex != -1) {
      final table = _tables[tableIndex];
      _tables[tableIndex] = table.copyWith(
        userId: null,
        customerName: null,
        status: restaurant_table.TableStatus.available,
        occupiedAt: null,
        reservedAt: null,
      );
      await _saveTables();
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during free table: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during free table: $e');
      }
    }
  }

  Future<void> deleteTable(String tableId) async {
    final table = getTableById(tableId);
    if (table != null) {
      _tables.removeWhere((table) => table.id == tableId);
      await _saveTables();
      
      // ENHANCEMENT: Automatic Firebase sync trigger
      try {
        final unifiedSyncService = UnifiedSyncService.instance;
        await unifiedSyncService.syncTableToFirebase(table, 'deleted');
      } catch (e) {
        debugPrint('⚠️ Failed to sync table deletion to Firebase: $e');
      }
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during delete table: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during delete table: $e');
      }
    }
  }

  Future<void> updateTable(restaurant_table.Table table) async {
    final index = _tables.indexWhere((t) => t.id == table.id);

    if (index != -1) {
      _tables[index] = table;
      await _saveTables();
      
      // ENHANCEMENT: Automatic Firebase sync trigger
      try {
        final unifiedSyncService = UnifiedSyncService.instance;
        await unifiedSyncService.syncTableToFirebase(table, 'updated');
      } catch (e) {
        debugPrint('⚠️ Failed to sync table update to Firebase: $e');
      }
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during update table: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during update table: $e');
      }
    }
  }

  /// Update table from Firebase (for cross-device sync)
  Future<void> updateTableFromFirebase(restaurant_table.Table firebaseTable) async {
    try {
      debugPrint('🔄 Updating table from Firebase: ${firebaseTable.number}');
      
      // Check if table already exists locally
      final existingIndex = _tables.indexWhere((table) => table.id == firebaseTable.id);
      
      if (existingIndex != -1) {
        // Update existing table
        _tables[existingIndex] = firebaseTable;
        debugPrint('🔄 Updated existing table from Firebase: ${firebaseTable.number}');
      } else {
        // Add new table from Firebase
        _tables.add(firebaseTable);
        debugPrint('➕ Added new table from Firebase: ${firebaseTable.number}');
      }
      
      // Save to local storage
      await _saveTables();
      
      debugPrint('✅ Table updated from Firebase: ${firebaseTable.number}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to update table from Firebase: $e');
    }
  }

  Future<void> clearUserTables(String userId) async {
    _tables.removeWhere((table) => table.userId == userId);
    await _saveTables();
    
    // Safely notify listeners
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint('Error notifying listeners during clear user tables: $e');
        }
      });
    } catch (e) {
      debugPrint('Error scheduling notification during clear user tables: $e');
    }
  }

  /// Clear all tables from memory and database
  Future<void> clearAllTables() async {
    try {
      debugPrint('🗑️ Clearing all tables...');
      
      // Clear from memory
      _tables.clear();
      
      // Clear from SharedPreferences
      await _prefs.remove(_tablesKey);
      
      debugPrint('✅ All tables cleared');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error clearing tables: $e');
      rethrow;
    }
  }

  // Helper methods
  List<restaurant_table.Table> getAvailableTables() {
    return _tables.where((table) => table.isAvailable).toList();
  }

  List<restaurant_table.Table> getOccupiedTables() {
    return _tables.where((table) => table.isOccupied).toList();
  }

  restaurant_table.Table? getTableById(String tableId) {
    try {
      return _tables.firstWhere((table) => table.id == tableId);
    } catch (e) {
      return null;
    }
  }

  restaurant_table.Table? getTableByNumber(int number) {
    try {
      return _tables.firstWhere((table) => table.number == number);
    } catch (e) {
      return null;
    }
  }

  Future<void> addItemToOrder(String tableId, MenuItem item, {int quantity = 1}) async {
    final tableIndex = _tables.indexWhere((t) => t.id == tableId);
    if (tableIndex == -1) return;

    final table = _tables[tableIndex];
    final existingOrder = table.metadata['currentOrder'] as Map<String, dynamic>? ?? {};
    final items = List<Map<String, dynamic>>.from(existingOrder['items'] ?? []);

    // Check if item already exists
    final existingItemIndex = items.indexWhere((oi) => oi['menuItem']['id'] == item.id);
    if (existingItemIndex != -1) {
      // Update quantity
      items[existingItemIndex]['quantity'] = (items[existingItemIndex]['quantity'] ?? 1) + quantity;
    } else {
      // Add new item
      items.add({
        'id': const Uuid().v4(),
        'menuItem': item.toJson(),
        'quantity': quantity,
        'unitPrice': item.price,
        'totalPrice': item.price * quantity,
      });
    }

    final updatedOrder = {
      ...existingOrder,
      'items': items,
      'total': items.fold<double>(0.0, (sum, item) => sum + (item['totalPrice'] ?? 0.0)),
    };

    _tables[tableIndex] = table.copyWith(
      metadata: {
        ...table.metadata,
        'currentOrder': updatedOrder,
      },
    );

    await _saveTables();
    
    // Safely notify listeners
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint('Error notifying listeners during add item to order: $e');
        }
      });
    } catch (e) {
      debugPrint('Error scheduling notification during add item to order: $e');
    }
  }

  Future<void> removeItemFromOrder(String tableId, String itemId) async {
    final tableIndex = _tables.indexWhere((t) => t.id == tableId);
    if (tableIndex == -1) return;

    final table = _tables[tableIndex];
    final existingOrder = table.metadata['currentOrder'] as Map<String, dynamic>? ?? {};
    final items = List<Map<String, dynamic>>.from(existingOrder['items'] ?? []);

    items.removeWhere((item) => item['id'] == itemId);

    final updatedOrder = {
      ...existingOrder,
      'items': items,
      'total': items.fold<double>(0.0, (sum, item) => sum + (item['totalPrice'] ?? 0.0)),
    };

    _tables[tableIndex] = table.copyWith(
      metadata: {
        ...table.metadata,
        'currentOrder': updatedOrder,
      },
    );

    await _saveTables();
    
    // Safely notify listeners
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint('Error notifying listeners during remove item from order: $e');
        }
      });
    } catch (e) {
      debugPrint('Error scheduling notification during remove item from order: $e');
    }
  }

  Future<void> updateItemQuantity(String tableId, String itemId, int quantity) async {
    final tableIndex = _tables.indexWhere((t) => t.id == tableId);
    if (tableIndex == -1) return;

    final table = _tables[tableIndex];
    final existingOrder = table.metadata['currentOrder'] as Map<String, dynamic>? ?? {};
    final items = List<Map<String, dynamic>>.from(existingOrder['items'] ?? []);

    final itemIndex = items.indexWhere((item) => item['id'] == itemId);
    if (itemIndex != -1) {
      final item = items[itemIndex];
      final unitPrice = item['unitPrice'] ?? 0.0;
      items[itemIndex] = {
        ...item,
        'quantity': quantity,
        'totalPrice': unitPrice * quantity,
      };

      final updatedOrder = {
        ...existingOrder,
        'items': items,
        'total': items.fold<double>(0.0, (sum, item) => sum + (item['totalPrice'] ?? 0.0)),
      };

      _tables[tableIndex] = table.copyWith(
        metadata: {
          ...table.metadata,
          'currentOrder': updatedOrder,
        },
      );

      await _saveTables();
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during update item quantity: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during update item quantity: $e');
      }
    }
  }

  Future<void> clearOrder(String tableId) async {
    final tableIndex = _tables.indexWhere((t) => t.id == tableId);
    if (tableIndex == -1) return;

    final table = _tables[tableIndex];
    final updatedMetadata = Map<String, dynamic>.from(table.metadata);
    updatedMetadata.remove('currentOrder');

    _tables[tableIndex] = table.copyWith(metadata: updatedMetadata);
    await _saveTables();
    
    // Safely notify listeners
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint('Error notifying listeners during clear order: $e');
        }
      });
    } catch (e) {
      debugPrint('Error scheduling notification during clear order: $e');
    }
  }

  /// Resets all tables to the specified configuration for the restaurant.
  /// Only tables 1-16 will exist, with the correct capacities.
  /// Uses consistent IDs based on table numbers to prevent display issues.
  Future<void> resetTablesToDefault() async {
    _tables = [
      restaurant_table.Table(id: 'table_1', number: 1, capacity: 4),
      restaurant_table.Table(id: 'table_2', number: 2, capacity: 4),
      restaurant_table.Table(id: 'table_3', number: 3, capacity: 4),
      restaurant_table.Table(id: 'table_4', number: 4, capacity: 4),
      restaurant_table.Table(id: 'table_5', number: 5, capacity: 2),
      restaurant_table.Table(id: 'table_6', number: 6, capacity: 4),
      restaurant_table.Table(id: 'table_7', number: 7, capacity: 4),
      restaurant_table.Table(id: 'table_8', number: 8, capacity: 6),
      restaurant_table.Table(id: 'table_9', number: 9, capacity: 6),
      restaurant_table.Table(id: 'table_10', number: 10, capacity: 4),
      restaurant_table.Table(id: 'table_11', number: 11, capacity: 6),
      restaurant_table.Table(id: 'table_12', number: 12, capacity: 6),
      restaurant_table.Table(id: 'table_13', number: 13, capacity: 6),
      restaurant_table.Table(id: 'table_14', number: 14, capacity: 4),
      restaurant_table.Table(id: 'table_15', number: 15, capacity: 4),
      restaurant_table.Table(id: 'table_16', number: 16, capacity: 4),
    ];
    await _saveTables();
    
    // Safely notify listeners
    try {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint('Error notifying listeners during reset tables to default: $e');
        }
      });
    } catch (e) {
      debugPrint('Error scheduling notification during reset tables to default: $e');
    }
  }
} 