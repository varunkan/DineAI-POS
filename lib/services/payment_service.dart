import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../models/order.dart';
import 'order_service.dart';
import 'inventory_service.dart';

class PaymentService with ChangeNotifier {
  final OrderService orderService;
  final InventoryService inventoryService;

  PaymentService(this.orderService, this.inventoryService);

  // Supported payment methods
  static const List<String> paymentMethods = [
    'Cash',
    'Credit Card',
    'Debit Card',
    'Digital Wallet',
    'Other',
  ];

  // Process a payment for an order
  Future<void> processPayment({
    required Order order,
    required String method,
    String? transactionId,
    double? amount,
  }) async {
    try {
      // Here you would integrate with a real payment gateway if needed
      // For now, we simulate a successful payment
      final updatedOrder = order.copyWith(
        paymentMethod: method,
        paymentStatus: PaymentStatus.paid,
        paymentTransactionId: transactionId ?? 'TXN${DateTime.now().millisecondsSinceEpoch}',
        status: OrderStatus.completed,
        completedTime: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      await orderService.updateOrderStatus(order.id, 'completed');
      
      // 📦 CRITICAL: Update inventory after successful payment
      debugPrint('💳 Payment successful - updating inventory for order: ${updatedOrder.orderNumber}');
      try {
        final inventoryUpdated = await inventoryService.updateInventoryOnOrderCompletion(updatedOrder);
        if (inventoryUpdated) {
          debugPrint('✅ Inventory updated successfully for order: ${updatedOrder.orderNumber}');
        } else {
          debugPrint('⚠️ No inventory items were updated for order: ${updatedOrder.orderNumber}');
        }
      } catch (e) {
        debugPrint('❌ Error updating inventory for order ${updatedOrder.orderNumber}: $e');
        // Don't fail the payment if inventory update fails - log it for manual review
      }
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during process payment: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during process payment: $e');
      }
      
      debugPrint('Payment processed for order: ${order.orderNumber}');
    } catch (e) {
      debugPrint('Payment failed: $e');
      // Optionally update order/payment status to failed
      // ...
      rethrow;
    }
  }

  // Refund a payment
  Future<void> refundPayment(Order order) async {
    try {
      // Simulate refund logic
      order.copyWith(
        paymentStatus: PaymentStatus.refunded,
      );
      await orderService.updateOrderStatus(order.id, 'refunded');
      // Optionally update payment info in DB
      // ...
      
      // Safely notify listeners
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          try {
            notifyListeners();
          } catch (e) {
            debugPrint('Error notifying listeners during refund payment: $e');
          }
        });
      } catch (e) {
        debugPrint('Error scheduling notification during refund payment: $e');
      }
      
      debugPrint('Payment refunded for order: ${order.orderNumber}');
    } catch (e) {
      debugPrint('Refund failed: $e');
      rethrow;
    }
  }
} 