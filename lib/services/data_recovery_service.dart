import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../config/firebase_config.dart';
import '../services/database_service.dart';
import '../models/order.dart';

class DataRecoveryService {
  static final DataRecoveryService _instance = DataRecoveryService._internal();
  factory DataRecoveryService() => _instance;
  DataRecoveryService._internal();

  final DatabaseService _databaseService = DatabaseService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _isRecovering = false;
  String _recoveryStatus = '';
  int _recoveredCount = 0;
  int _totalCount = 0;
  
  // Getters for UI
  bool get isRecovering => _isRecovering;
  String get recoveryStatus => _recoveryStatus;
  double get recoveryProgress => _totalCount > 0 ? _recoveredCount / _totalCount : 0.0;
  
  /// Perform comprehensive data recovery from Firebase
  Future<RecoveryResult> performComprehensiveRecovery() async {
    if (_isRecovering) {
      throw Exception('Recovery already in progress');
    }
    
    _isRecovering = true;
    _recoveredCount = 0;
    _totalCount = 0;
    
    try {
      _updateStatus('🚨 Starting comprehensive data recovery...');
      
      // Get current tenant ID
      final tenantId = FirebaseConfig.getCurrentTenantId();
      if (tenantId == null) {
        throw Exception('No tenant ID available for recovery');
      }
      
      _updateStatus('🏢 Recovering data for tenant: $tenantId');
      
      // Get current local order count
      final db = await _databaseService.database;
      if (db == null) {
        throw Exception('Database not available');
      }
      
      final localOrdersResult = await db.query('orders');
      final initialLocalCount = localOrdersResult.length;
      _updateStatus('📊 Current local orders: $initialLocalCount');
      
      // Get all orders from Firebase
      _updateStatus('☁️ Fetching orders from Firebase...');
      final ordersRef = _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('orders');
      
      final ordersSnapshot = await ordersRef.get();
      _totalCount = ordersSnapshot.docs.length;
      _updateStatus('📊 Found $_totalCount orders in Firebase');
      
      if (ordersSnapshot.docs.isEmpty) {
        _updateStatus('⚠️ No orders found in Firebase to recover');
        return RecoveryResult(
          success: true,
          recoveredOrders: 0,
          recoveredOrderItems: 0,
          skippedOrders: 0,
          initialLocalCount: initialLocalCount,
          finalLocalCount: initialLocalCount,
          message: 'No orders found in Firebase to recover',
        );
      }
      
      // Process each Firebase order
      int recoveredOrders = 0;
      int recoveredOrderItems = 0;
      int skippedOrders = 0;
      
      _updateStatus('💾 Recovering orders to local database...');
      
      for (int i = 0; i < ordersSnapshot.docs.length; i++) {
        final orderDoc = ordersSnapshot.docs[i];
        _recoveredCount = i + 1;
        
        try {
          final orderData = orderDoc.data();
          final orderId = orderDoc.id;
          final orderNumber = orderData['orderNumber'] ?? orderData['order_number'] ?? 'Unknown';
          
          _updateStatus('🔄 Processing order $i/${_totalCount}: $orderNumber');
          
          // Check if order already exists locally
          final existingOrder = await db.query(
            'orders',
            where: 'id = ?',
            whereArgs: [orderId],
            limit: 1,
          );
          
          if (existingOrder.isNotEmpty) {
            skippedOrders++;
            continue;
          }
          
          // Validate order has items or non-zero total
          final items = orderData['items'] as List? ?? [];
          final totalAmount = (orderData['totalAmount'] as num?)?.toDouble() ?? 0.0;
          
          if (items.isEmpty && totalAmount == 0) {
            skippedOrders++;
            continue;
          }
          
          
          // Convert Firebase data to local database format
          final localOrderData = _convertFirebaseOrderToLocal(orderData, orderId);
          
          // Insert order into local database
          await db.transaction((txn) async {
            // Insert order
            await txn.insert(
              'orders',
              localOrderData,
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
            
            // Insert order items
            for (final item in items) {
              final localItemData = _convertFirebaseOrderItemToLocal(item, orderId);
              await txn.insert(
                'order_items',
                localItemData,
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
              recoveredOrderItems++;
            }
          });
          
          recoveredOrders++;
          
        } catch (e) {
          continue;
        }
      }
      
      // Verify recovery
      final finalOrdersResult = await db.query('orders');
      final finalLocalCount = finalOrdersResult.length;
      
      _updateStatus('✅ Recovery complete! Recovered $recoveredOrders orders');
      
      return RecoveryResult(
        success: true,
        recoveredOrders: recoveredOrders,
        recoveredOrderItems: recoveredOrderItems,
        skippedOrders: skippedOrders,
        initialLocalCount: initialLocalCount,
        finalLocalCount: finalLocalCount,
        message: 'Successfully recovered $recoveredOrders orders with $recoveredOrderItems items',
      );
      
    } catch (e) {
      _updateStatus('❌ Recovery failed: $e');
      return RecoveryResult(
        success: false,
        recoveredOrders: 0,
        recoveredOrderItems: 0,
        skippedOrders: 0,
        initialLocalCount: 0,
        finalLocalCount: 0,
        message: 'Recovery failed: $e',
      );
    } finally {
      _isRecovering = false;
    }
  }
  
  void _updateStatus(String status) {
    _recoveryStatus = status;
  }
  
  Map<String, dynamic> _convertFirebaseOrderToLocal(Map<String, dynamic> firebaseData, String orderId) {
    final now = DateTime.now().toIso8601String();
    
    return {
      'id': orderId,
      'order_number': firebaseData['orderNumber'] ?? firebaseData['order_number'] ?? 'RECOVERED-$orderId',
      'customer_name': firebaseData['customerName'],
      'customer_phone': firebaseData['customerPhone'],
      'table_id': firebaseData['tableId'],
      'type': _convertOrderType(firebaseData['type']),
      'status': _convertOrderStatus(firebaseData['status']),
      'subtotal': (firebaseData['subtotal'] as num?)?.toDouble() ?? 0.0,
      'tax_amount': (firebaseData['taxAmount'] as num?)?.toDouble() ?? 0.0,
      'hst_amount': (firebaseData['hstAmount'] as num?)?.toDouble() ?? 0.0,
      'total_amount': (firebaseData['totalAmount'] as num?)?.toDouble() ?? 0.0,
      'payment_method': firebaseData['paymentMethod'] ?? 'cash',
      'special_instructions': firebaseData['specialInstructions'],
      'order_time': firebaseData['orderTime'] ?? now,
      'created_at': firebaseData['createdAt'] ?? now,
      'updated_at': firebaseData['updatedAt'] ?? now,
      'user_id': firebaseData['userId'] ?? 'recovered_user',
      'is_urgent': (firebaseData['isUrgent'] == true) ? 1 : 0,
      'sent_to_kitchen': (firebaseData['sentToKitchen'] == true) ? 1 : 0,
      'voided': (firebaseData['voided'] == true) ? 1 : 0,
      'comped': (firebaseData['comped'] == true) ? 1 : 0,
    };
  }
  
  Map<String, dynamic> _convertFirebaseOrderItemToLocal(Map<String, dynamic> firebaseItem, String orderId) {
    final now = DateTime.now().toIso8601String();
    
    return {
      'id': firebaseItem['id'] ?? 'recovered_${DateTime.now().millisecondsSinceEpoch}',
      'order_id': orderId,
      'menu_item_id': firebaseItem['menuItemId'] ?? firebaseItem['menuItem']?['id'] ?? 'unknown_item',
      'quantity': (firebaseItem['quantity'] as num?)?.toDouble() ?? 1.0,
      'unit_price': (firebaseItem['unitPrice'] as num?)?.toDouble() ?? 0.0,
      'total_price': (firebaseItem['totalPrice'] as num?)?.toDouble() ?? 0.0,
      'selected_variant': firebaseItem['selectedVariant'],
      'special_instructions': firebaseItem['specialInstructions'],
      'notes': firebaseItem['notes'],
      'is_available': (firebaseItem['isAvailable'] == true) ? 1 : 0,
      'sent_to_kitchen': (firebaseItem['sentToKitchen'] == true) ? 1 : 0,
      'created_at': firebaseItem['createdAt'] ?? now,
      'updated_at': firebaseItem['updatedAt'] ?? now,
    };
  }
  
  String _convertOrderType(dynamic type) {
    if (type == null) return 'dine_in';
    
    final typeStr = type.toString().toLowerCase();
    switch (typeStr) {
      case 'dinein':
      case 'dine_in':
        return 'dine_in';
      case 'takeout':
      case 'take_out':
        return 'takeout';
      case 'delivery':
        return 'delivery';
      default:
        return 'dine_in';
    }
  }
  
  String _convertOrderStatus(dynamic status) {
    if (status == null) return 'pending';
    
    final statusStr = status.toString().toLowerCase();
    switch (statusStr) {
      case 'pending':
        return 'pending';
      case 'confirmed':
        return 'confirmed';
      case 'preparing':
        return 'preparing';
      case 'ready':
        return 'ready';
      case 'completed':
        return 'completed';
      case 'cancelled':
        return 'cancelled';
      default:
        return 'pending';
    }
  }
}

class RecoveryResult {
  final bool success;
  final int recoveredOrders;
  final int recoveredOrderItems;
  final int skippedOrders;
  final int initialLocalCount;
  final int finalLocalCount;
  final String message;
  
  RecoveryResult({
    required this.success,
    required this.recoveredOrders,
    required this.recoveredOrderItems,
    required this.skippedOrders,
    required this.initialLocalCount,
    required this.finalLocalCount,
    required this.message,
  });
  
  @override
  String toString() {
    return 'RecoveryResult(success: $success, recovered: $recoveredOrders orders, '
           'items: $recoveredOrderItems, skipped: $skippedOrders, '
           'before: $initialLocalCount, after: $finalLocalCount)';
  }
} 