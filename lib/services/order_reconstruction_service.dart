import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../services/database_service.dart';
import '../models/order.dart';
import '../models/menu_item.dart';
import '../config/firebase_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as fs;

class OrderReconstructionService {
  static final OrderReconstructionService _instance = OrderReconstructionService._internal();
  factory OrderReconstructionService() => _instance;
  OrderReconstructionService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final fs.FirebaseFirestore _firestore = fs.FirebaseFirestore.instance;

  /// 🔄 RECONSTRUCTION: Create orders from orphaned order_items
  Future<List<Order>> reconstructOrdersFromItems() async {
    try {
      
      final db = await _databaseService.database;
      if (db == null) {
        throw Exception('Database not available');
      }

      // Find all order_items that don't have corresponding orders
      final orphanedItemsQuery = await db.rawQuery('''
        SELECT oi.*, mi.name as menu_item_name, mi.price as menu_item_price
        FROM order_items oi
        LEFT JOIN orders o ON oi.order_id = o.id
        LEFT JOIN menu_items mi ON oi.menu_item_id = mi.id
        WHERE o.id IS NULL
        ORDER BY oi.order_id, oi.created_at
      ''');

      if (orphanedItemsQuery.isEmpty) {
        return [];
      }


      // Group items by order_id
      final Map<String, List<Map<String, dynamic>>> itemsByOrderId = {};
      for (final item in orphanedItemsQuery) {
        final orderId = item['order_id'] as String;
        itemsByOrderId.putIfAbsent(orderId, () => []).add(item);
      }

      final List<Order> reconstructedOrders = [];

      for (final entry in itemsByOrderId.entries) {
        final orderId = entry.key;
        final itemMaps = entry.value;

        try {
          final order = await _reconstructOrderFromItems(orderId, itemMaps);
          if (order != null) {
            reconstructedOrders.add(order);
          }
        } catch (e) {
        }
      }

      return reconstructedOrders;

    } catch (e) {
      return [];
    }
  }

  /// 🔧 RECONSTRUCTION: Create a single order from its items
  Future<Order?> _reconstructOrderFromItems(String orderId, List<Map<String, dynamic>> itemMaps) async {
    try {
      // Convert item maps to OrderItem objects
      final List<OrderItem> orderItems = [];
      DateTime? earliestCreatedAt;
      DateTime? latestUpdatedAt;

      for (final itemMap in itemMaps) {
        try {
          // Create a basic MenuItem for the OrderItem
          final menuItem = MenuItem(
            id: itemMap['menu_item_id'] as String? ?? 'unknown',
            name: itemMap['menu_item_name'] as String? ?? 'Unknown Item',
            price: (itemMap['menu_item_price'] as num?)?.toDouble() ?? (itemMap['unit_price'] as num?)?.toDouble() ?? 0.0,
            categoryId: 'reconstructed',
            description: 'Reconstructed from order items',
            isAvailable: true,
          );

          final orderItem = OrderItem(
            id: itemMap['id'] as String,
            menuItem: menuItem,
            quantity: (itemMap['quantity'] as num?)?.toInt() ?? 1,
            unitPrice: (itemMap['unit_price'] as num?)?.toDouble() ?? 0.0,
            selectedVariant: itemMap['selected_variant'] as String?,
            specialInstructions: itemMap['special_instructions'] as String?,
            notes: itemMap['notes'] as String?,
            isAvailable: (itemMap['is_available'] as int?) == 1,
            sentToKitchen: (itemMap['sent_to_kitchen'] as int?) == 1,
            createdAt: DateTime.tryParse(itemMap['created_at'] as String? ?? '') ?? DateTime.now(),
          );

          orderItems.add(orderItem);

          // Track timestamps
          final itemCreatedAt = orderItem.createdAt;
          if (earliestCreatedAt == null || itemCreatedAt.isBefore(earliestCreatedAt)) {
            earliestCreatedAt = itemCreatedAt;
          }
          if (latestUpdatedAt == null || itemCreatedAt.isAfter(latestUpdatedAt)) {
            latestUpdatedAt = itemCreatedAt;
          }

        } catch (e) {
        }
      }

      if (orderItems.isEmpty) {
        return null;
      }

      // Calculate totals
      final subtotal = orderItems.fold(0.0, (sum, item) => sum + item.totalPrice);
      final hstAmount = subtotal * 0.13; // 13% HST
      final totalAmount = subtotal + hstAmount;

      // Generate order number
      final orderNumber = 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';

      // Create the reconstructed order
      final reconstructedOrder = Order(
        id: orderId,
        orderNumber: orderNumber,
        items: orderItems,
        status: OrderStatus.pending,
        type: OrderType.dineIn,
        userId: 'system_reconstruction',
        customerName: 'Reconstructed Order',
        subtotal: subtotal,
        hstAmount: hstAmount,
        totalAmount: totalAmount,
        paymentMethod: 'cash',
        orderTime: earliestCreatedAt ?? DateTime.now(),
        createdAt: earliestCreatedAt ?? DateTime.now(),
        updatedAt: latestUpdatedAt ?? DateTime.now(),
        specialInstructions: 'Order reconstructed from orphaned items',
      );

      return reconstructedOrder;

    } catch (e) {
      return null;
    }
  }

  /// 💾 SAVE: Save reconstructed orders to database
  Future<int> saveReconstructedOrders(List<Order> orders) async {
    try {
      
      final db = await _databaseService.database;
      if (db == null) {
        throw Exception('Database not available');
      }

      int savedCount = 0;
      for (final order in orders) {
        try {
          await db.transaction((txn) async {
            // Insert the order
            final orderMap = {
              'id': order.id,
              'order_number': order.orderNumber,
              'status': order.status.toString().split('.').last,
              'type': order.type.toString().split('.').last,
              'table_id': order.tableId,
              'user_id': order.userId,
              'customer_name': order.customerName,
              'customer_phone': order.customerPhone,
              'customer_email': order.customerEmail,
              'customer_address': order.customerAddress,
              'special_instructions': order.specialInstructions,
              'subtotal': order.subtotal,
              'tax_amount': order.taxAmount,
              'tip_amount': order.tipAmount,
              'hst_amount': order.hstAmount,
              'discount_amount': order.discountAmount,
              'gratuity_amount': order.gratuityAmount,
              'total_amount': order.totalAmount,
              'payment_method': order.paymentMethod?.toString().split('.').last,
              'payment_status': order.paymentStatus.toString().split('.').last,
              'payment_transaction_id': order.paymentTransactionId,
              'order_time': order.orderTime.toIso8601String(),
              'estimated_ready_time': order.estimatedReadyTime?.toIso8601String(),
              'actual_ready_time': order.actualReadyTime?.toIso8601String(),
              'served_time': order.servedTime?.toIso8601String(),
              'completed_time': order.completedTime?.toIso8601String(),
              'is_urgent': order.isUrgent ? 1 : 0,
              'priority': order.priority ?? 0,
              'assigned_to': order.assignedTo,
              'created_at': order.createdAt.toIso8601String(),
              'updated_at': order.updatedAt.toIso8601String(),
            };

            await txn.insert(
              'orders',
              orderMap,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            savedCount++;
          });

        } catch (e) {
        }
      }

      return savedCount;

    } catch (e) {
      return 0;
    }
  }

  /// 🔍 ANALYSIS: Analyze order_items table for reconstruction opportunities
  Future<Map<String, dynamic>> analyzeOrderItems() async {
    try {
      
      final db = await _databaseService.database;
      if (db == null) {
        throw Exception('Database not available');
      }

      // Count total order items
      final totalItemsResult = await db.rawQuery('SELECT COUNT(*) as count FROM order_items');
      final totalItems = Sqflite.firstIntValue(totalItemsResult) ?? 0;

      // Count orphaned items (items without orders)
      final orphanedItemsResult = await db.rawQuery('''
        SELECT COUNT(*) as count 
        FROM order_items oi 
        LEFT JOIN orders o ON oi.order_id = o.id 
        WHERE o.id IS NULL
      ''');
      final orphanedItems = Sqflite.firstIntValue(orphanedItemsResult) ?? 0;

      // Count unique order IDs in order_items
      final uniqueOrderIdsResult = await db.rawQuery('SELECT COUNT(DISTINCT order_id) as count FROM order_items');
      final uniqueOrderIds = Sqflite.firstIntValue(uniqueOrderIdsResult) ?? 0;

      // Count existing orders
      final existingOrdersResult = await db.rawQuery('SELECT COUNT(*) as count FROM orders');
      final existingOrders = Sqflite.firstIntValue(existingOrdersResult) ?? 0;

      // Calculate potential reconstructable orders
      final potentialReconstructableOrders = orphanedItems > 0 ? await _countPotentialReconstructableOrders() : 0;

      final analysis = {
        'totalOrderItems': totalItems,
        'orphanedItems': orphanedItems,
        'uniqueOrderIds': uniqueOrderIds,
        'existingOrders': existingOrders,
        'potentialReconstructableOrders': potentialReconstructableOrders,
        'itemsWithOrders': totalItems - orphanedItems,
        'reconstructionNeeded': orphanedItems > 0,
      };


      return analysis;

    } catch (e) {
      return {};
    }
  }

  /// 📊 COUNT: Count potential reconstructable orders
  Future<int> _countPotentialReconstructableOrders() async {
    try {
      final db = await _databaseService.database;
      if (db == null) return 0;

      final result = await db.rawQuery('''
        SELECT COUNT(DISTINCT oi.order_id) as count
        FROM order_items oi
        LEFT JOIN orders o ON oi.order_id = o.id
        WHERE o.id IS NULL
      ''');

      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// 🚀 FULL PROCESS: Analyze, reconstruct, and save orders
  Future<Map<String, dynamic>> performFullReconstruction() async {
    try {

      // Step 1: Analyze
      final analysis = await analyzeOrderItems();
      
      if (!(analysis['reconstructionNeeded'] as bool? ?? false)) {
        return {
          'success': true,
          'message': 'No orphaned items found - no reconstruction needed',
          'analysis': analysis,
          'reconstructedOrders': 0,
        };
      }

      // Step 2: Reconstruct
      final reconstructedOrders = await reconstructOrdersFromItems();
      
      if (reconstructedOrders.isEmpty) {
        return {
          'success': false,
          'message': 'No orders could be reconstructed from orphaned items',
          'analysis': analysis,
          'reconstructedOrders': 0,
        };
      }

      // Step 3: Save
      final savedCount = await saveReconstructedOrders(reconstructedOrders);


      return {
        'success': true,
        'message': 'Successfully reconstructed $savedCount orders from orphaned items',
        'analysis': analysis,
        'reconstructedOrders': savedCount,
        'orders': reconstructedOrders,
      };

    } catch (e) {
      return {
        'success': false,
        'message': 'Reconstruction failed: $e',
        'reconstructedOrders': 0,
      };
    }
  }
} 