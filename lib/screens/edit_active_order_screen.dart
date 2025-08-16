import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_pos_system/models/order.dart';
import 'package:ai_pos_system/models/menu_item.dart';
import 'package:ai_pos_system/models/table.dart' as restaurant_table;
import 'package:ai_pos_system/services/order_service.dart';
import 'package:ai_pos_system/services/menu_service.dart';
import 'package:ai_pos_system/services/table_service.dart';
import 'package:ai_pos_system/services/printing_service.dart';
import 'package:ai_pos_system/services/enhanced_printer_assignment_service.dart';
import 'package:ai_pos_system/services/database_service.dart';
import 'package:ai_pos_system/services/order_log_service.dart';
import 'package:ai_pos_system/services/activity_log_service.dart';
import 'package:ai_pos_system/models/activity_log.dart';
import 'package:ai_pos_system/widgets/confirmation_dialog.dart';
import 'package:ai_pos_system/widgets/error_dialog.dart';
import 'package:ai_pos_system/widgets/loading_overlay.dart';
import 'package:ai_pos_system/models/category.dart' as pos_category;
import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/widgets/back_button.dart';
import 'package:ai_pos_system/screens/checkout_screen.dart';
import 'package:ai_pos_system/screens/order_type_selection_screen.dart';

class EditActiveOrderScreen extends StatefulWidget {
  final Order order;
  final User user;

  const EditActiveOrderScreen({super.key, required this.order, required this.user});

  @override
  _EditActiveOrderScreenState createState() => _EditActiveOrderScreenState();
}

class _EditActiveOrderScreenState extends State<EditActiveOrderScreen> {
  final List<MenuItem> _menuItems = [];
  List<pos_category.Category> _categories = [];
  pos_category.Category? _selectedCategory;
  bool _isLoading = true;
  String? _error;
  // Local order state that can be modified
  late Order _currentOrder;

  // Undo/Redo functionality
  final List<Order> _changeHistory = [];
  int _currentHistoryIndex = -1;
  bool _isUndoRedoAction = false;

  // New: View state management for drill-down navigation
  bool _isViewingCategory = false;  // false = showing categories, true = showing items

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order.copyWith();
    _loadCategories();
    _initializeChangeHistory();
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Initialize change history with the original order
  void _initializeChangeHistory() {
    _changeHistory.add(_currentOrder.copyWith());
    _currentHistoryIndex = 0;
  }

  /// Save current state to history before making changes
  void _saveToHistory() {
    if (_isUndoRedoAction) return; // Don't save during undo/redo operations
    
    // Remove any future history if we're not at the end
    if (_currentHistoryIndex < _changeHistory.length - 1) {
      _changeHistory.removeRange(_currentHistoryIndex + 1, _changeHistory.length);
    }
    
    // Add current state to history
    _changeHistory.add(_currentOrder.copyWith());
    _currentHistoryIndex++;
    
    // Limit history size to prevent memory issues
    if (_changeHistory.length > 20) {
      _changeHistory.removeAt(0);
      _currentHistoryIndex--;
    }
  }

  /// Undo the last change
  void _undo() {
    if (_currentHistoryIndex > 0) {
      setState(() {
        _isUndoRedoAction = true;
        _currentHistoryIndex--;
        widget.order.items.clear();
        widget.order.items.addAll(_changeHistory[_currentHistoryIndex].items);
        _isUndoRedoAction = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Undo completed'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Redo the last undone change
  void _redo() {
    if (_currentHistoryIndex < _changeHistory.length - 1) {
      setState(() {
        _isUndoRedoAction = true;
        _currentHistoryIndex++;
        widget.order.items.clear();
        widget.order.items.addAll(_changeHistory[_currentHistoryIndex].items);
        _isUndoRedoAction = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Redo completed'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Check if undo is available
  bool get _canUndo => _currentHistoryIndex > 0;

  /// Check if redo is available
  bool get _canRedo => _currentHistoryIndex < _changeHistory.length - 1;

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final menuService = Provider.of<MenuService>(context, listen: false);
      
      final categories = await menuService.getCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error loading categories: $e';
      });
    }
  }

  Future<void> _onCategorySelected(pos_category.Category category) async {
    setState(() {
      _selectedCategory = category;
      _isLoading = true;
      _error = null;
    });

    try {
      final menuService = Provider.of<MenuService>(context, listen: false);
      final items = await menuService.getMenuItemsByCategoryId(category.id);
      setState(() {
        _menuItems.clear();
        _menuItems.addAll(items);
        _isLoading = false;
        _isViewingCategory = true;  // Switch to items view
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error loading menu items: $e';
      });
    }
  }

  // New: Navigate back to categories view
  void _navigateBackToCategories() {
    setState(() {
      _isViewingCategory = false;
      _selectedCategory = null;
      _menuItems.clear();
    });
  }

  Future<void> _addItemToOrder(MenuItem item) async {
    if (item.isOutOfStock) {
      await ErrorDialogHelper.showValidationError(
        context,
        message: '${item.name} is out of stock.',
      );
      return;
    }

    final currentQuantity = _currentOrder.items
        .where((orderItem) => orderItem.menuItem.id == item.id)
        .fold(0, (sum, orderItem) => sum + orderItem.quantity);

    if (currentQuantity >= item.stockQuantity) {
      await ErrorDialogHelper.showValidationError(
        context,
        message: 'Insufficient stock for ${item.name}. Available: ${item.stockQuantity}',
      );
      return;
    }

    // Save current state to history before making changes
    _saveToHistory();

    setState(() {
      // Always create a new OrderItem for each addition
      // This allows new additions to be sent to kitchen separately
      final orderItem = OrderItem(
        menuItem: item,
        quantity: 1,
        unitPrice: item.price,
        sentToKitchen: false, // New items are not sent to kitchen yet
      );
      
      _currentOrder.items.add(orderItem);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} added to order'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _updateItemQuantity(OrderItem item, int newQuantity) async {
    // Check if item has been sent to kitchen
    if (item.sentToKitchen && !widget.user.isAdmin) {
      // Only admin can modify quantities of items sent to kitchen
      await ErrorDialogHelper.showValidationError(
        context,
        message: 'This item has been sent to kitchen. Only admin users can modify its quantity.',
      );
      return;
    }

    // Show confirmation dialog for admin users modifying sent items
    if (item.sentToKitchen && widget.user.isAdmin) {
      final confirmed = await ConfirmationDialogHelper.showConfirmation(
        context,
        title: 'Modify Sent Item',
        message: 'This item has been sent to kitchen. Are you sure you want to change its quantity?',
        confirmText: 'Modify',
        cancelText: 'Cancel',
      );
      
      if (confirmed != true) return;
    }

    // Save current state to history before making changes
    _saveToHistory();

    setState(() {
      final itemIndex = widget.order.items.indexWhere(
        (orderItem) => orderItem.id == item.id,
      );

      if (itemIndex != -1) {
        if (newQuantity <= 0) {
          _currentOrder.items.removeAt(itemIndex);
        } else {
          _currentOrder.items[itemIndex] = item.copyWith(
            quantity: newQuantity,
          );
        }
      }
    });
  }

  void _removeItemFromOrder(OrderItem item) async {
    // Check if item has been sent to kitchen
    if (item.sentToKitchen && !widget.user.isAdmin) {
      // Only admin can remove items that have been sent to kitchen
      await ErrorDialogHelper.showValidationError(
        context,
        message: 'This item has been sent to kitchen. Only admin users can remove it.',
      );
      return;
    }

    // Show confirmation dialog for admin users removing sent items
    if (item.sentToKitchen && widget.user.isAdmin) {
      final confirmed = await ConfirmationDialogHelper.showConfirmation(
        context,
        title: 'Remove Sent Item',
        message: 'This item has been sent to kitchen. Are you sure you want to remove it?',
        confirmText: 'Remove',
        cancelText: 'Cancel',
      );
      
      if (confirmed != true) return;
    }

    // Save current state to history before making changes
    _saveToHistory();

    setState(() {
      _currentOrder.items.removeWhere((orderItem) => orderItem.id == item.id);
    });

    // Show feedback
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.menuItem.name} removed from order'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendToKitchen() async {
    
    // Guard to prevent multiple simultaneous operations
    if (_isLoading) return;
    
    debugPrint('🚀 Starting send to kitchen process...');
    
    // GUARANTEE: Set loading state
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    // Get all providers synchronously BEFORE any async operations
    final databaseService = Provider.of<DatabaseService>(context, listen: false);
    final printingService = Provider.of<PrintingService?>(context, listen: false);
    final activityLogService = Provider.of<ActivityLogService>(context, listen: false);

    try {
      // Step 1: Get items that haven't been sent to kitchen yet
      final newItems = _currentOrder.items.where((item) => !item.sentToKitchen).toList();
      
      debugPrint('🔍 Found ${newItems.length} new items to send to kitchen');
      
      if (newItems.isEmpty) {
        debugPrint('⚠️ No new items to send to kitchen');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No new items to send to kitchen. All items have already been sent.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      
      // Step 2: Update items to mark as sent to kitchen
      debugPrint('📝 Updating items to mark as sent to kitchen...');
      final updatedItems = _currentOrder.items.map((item) =>
        item.sentToKitchen ? item : item.copyWith(sentToKitchen: true)
      ).toList();
      
      // Step 3: Update order
      debugPrint('📋 Creating updated order...');
      final updatedOrder = _currentOrder.copyWith(
        items: updatedItems,
        userId: widget.user.id,
        updatedAt: DateTime.now(),
      );
      
      // Step 4: Save to database with timeout protection
      debugPrint('💾 Saving order to database...');
      
      // Use Future.timeout to prevent hanging
      await _saveOrderDirectly(updatedOrder, databaseService).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException('Database save timeout', const Duration(seconds: 10)),
      );
      
      debugPrint('✅ Order saved successfully to database');
      
      // Step 5: Update UI state
      if (mounted) {
        setState(() {
          _currentOrder = updatedOrder;
        });
      }
      
      debugPrint('✅ UI state updated successfully');
      
      // Step 6: Show success message IMMEDIATELY
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${newItems.length} items sent to kitchen successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      
      debugPrint('✅ Success message displayed');
      
      // Step 7: Log activity (synchronously)
      try {
        await activityLogService.logActivity(
          action: ActivityAction.orderSentToKitchen,
          description: 'Order ${updatedOrder.orderNumber} sent to kitchen',
          targetId: updatedOrder.id,
          targetType: 'order',
          metadata: {
            'order_number': updatedOrder.orderNumber,
            'items_count': newItems.length,
            'sent_by': widget.user.name,
            'sent_at': DateTime.now().toIso8601String(),
          },
        );
        debugPrint('✅ Activity logged successfully');
      } catch (e) {
        debugPrint('⚠️ Failed to log activity: $e');
        // Don't fail the send to kitchen if logging fails
      }
      
      // Step 8: Try printing in background (don't await it)
      debugPrint('🖨️ Starting background printing...');
      _tryPrintingInBackground(updatedOrder, printingService);
      
      debugPrint('🎉 Send to kitchen process completed successfully!');

    } catch (e) {
      debugPrint('❌ Error sending to kitchen: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Error stack trace: ${StackTrace.current}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString().length > 80 ? e.toString().substring(0, 80) + "..." : e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      // GUARANTEE: Always clear loading state no matter what happens
      debugPrint('🧹 Clearing loading state...');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      debugPrint('✅ Loading state cleared');
    }
  }
  
  /// Try printing in background without blocking main flow
  void _tryPrintingInBackground(Order order, PrintingService? printingService) {
    // Fire and forget - don't block the main UI flow
    () async {
      try {
        if (printingService != null) {
          // Try printing with short timeout
          await printingService.printKitchenTicket(order).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              return false;
            },
          );
        }
      } catch (e) {
        debugPrint('⚠️ Background printing failed: $e');
        // Silently fail - the order was already saved successfully
      }
    }();
  }

  /// Saves order directly to database without triggering OrderService listeners
  Future<void> _saveOrderDirectly(Order order, DatabaseService databaseService) async {
    try {
      debugPrint('💾 Starting direct database save for order: ${order.orderNumber}');
      
      final orderData = _orderToMap(order);
      debugPrint('📋 Order data prepared, items count: ${order.items.length}');
      
      // Save order in a transaction
      final db = await databaseService.database;
      if (db != null) {
        debugPrint('🗄️ Database connection established');
        
        await db.transaction((txn) async {
          debugPrint('🔄 Starting database transaction');
          
          // Use INSERT OR REPLACE to handle potential ID conflicts
          await txn.rawInsert('''
            INSERT OR REPLACE INTO orders (
              id, order_number, status, type, table_id, user_id, customer_name,
              customer_phone, customer_email, customer_address, special_instructions,
              subtotal, tax_amount, tip_amount, hst_amount, discount_amount, gratuity_amount, total_amount, payment_method,
              payment_status, payment_transaction_id, order_time, estimated_ready_time,
              actual_ready_time, served_time, completed_time, is_urgent, priority,
              assigned_to, custom_fields, metadata, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''', [
            orderData['id'],
            orderData['order_number'],
            orderData['status'],
            orderData['type'],
            orderData['table_id'],
            orderData['user_id'],
            orderData['customer_name'],
            orderData['customer_phone'],
            orderData['customer_email'],
            orderData['customer_address'],
            orderData['special_instructions'],
            orderData['subtotal'],
            orderData['tax_amount'],
            orderData['tip_amount'],
            orderData['hst_amount'],
            orderData['discount_amount'],
            orderData['gratuity_amount'],
            orderData['total_amount'],
            orderData['payment_method'],
            orderData['payment_status'],
            orderData['payment_transaction_id'],
            orderData['order_time'],
            orderData['estimated_ready_time'],
            orderData['actual_ready_time'],
            orderData['served_time'],
            orderData['completed_time'],
            orderData['is_urgent'],
            orderData['priority'],
            orderData['assigned_to'],
            orderData['custom_fields'],
            orderData['metadata'],
            orderData['created_at'],
            orderData['updated_at'],
          ]);
          
          debugPrint('✅ Order saved to database');
          
          // Delete existing order items first to avoid duplicates
          await txn.delete('order_items', where: 'order_id = ?', whereArgs: [order.id]);
          debugPrint('🗑️ Existing order items deleted');
          
          // Save order items
          for (int i = 0; i < order.items.length; i++) {
            final item = order.items[i];
            final itemData = _orderItemToMap(item, order.id);
            
            debugPrint('📝 Saving order item ${i + 1}/${order.items.length}: ${item.menuItem.name}');
            
            await txn.rawInsert('''
              INSERT OR REPLACE INTO order_items (
                id, order_id, menu_item_id, quantity, unit_price, total_price,
                selected_variant, selected_modifiers, special_instructions,
                custom_properties, is_available, sent_to_kitchen, created_at
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', [
              itemData['id'],
              itemData['order_id'],
              itemData['menu_item_id'],
              itemData['quantity'],
              itemData['unit_price'],
              itemData['total_price'],
              itemData['selected_variant'],
              itemData['selected_modifiers'],
              itemData['special_instructions'],
              itemData['custom_properties'],
              itemData['is_available'],
              itemData['sent_to_kitchen'],
              itemData['created_at'],
            ]);
          }
          
          debugPrint('✅ All order items saved successfully');
        });
        
        debugPrint('✅ Database transaction completed successfully');
      } else {
        throw Exception('Database is not available');
      }
    } catch (e) {
      debugPrint('❌ Database save error: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      debugPrint('❌ Error stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  /// Converts an Order object to a database map.
  Map<String, dynamic> _orderToMap(Order order) {
    return {
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
      'payment_method': order.paymentMethod,
      'payment_status': order.paymentStatus.toString().split('.').last,
      'payment_transaction_id': order.paymentTransactionId,
      'order_time': order.orderTime.toIso8601String(),
      'estimated_ready_time': order.estimatedReadyTime?.toIso8601String(),
      'actual_ready_time': order.actualReadyTime?.toIso8601String(),
      'served_time': order.servedTime?.toIso8601String(),
      'completed_time': order.completedTime?.toIso8601String(),
      'is_urgent': order.isUrgent ? 1 : 0,
      'priority': order.priority,
      'assigned_to': order.assignedTo,
      'custom_fields': jsonEncode(order.customFields),
      'metadata': jsonEncode(order.metadata),
      'created_at': order.createdAt.toIso8601String(),
      'updated_at': order.updatedAt.toIso8601String(),
    };
  }

  /// Converts an OrderItem object to a database map.
  Map<String, dynamic> _orderItemToMap(OrderItem item, String orderId) {
    return {
      'id': item.id,
      'order_id': orderId,
      'menu_item_id': item.menuItem.id,
      'quantity': item.quantity,
      'unit_price': item.unitPrice,
      'total_price': item.totalPrice,
      'selected_variant': item.selectedVariant,
      'selected_modifiers': jsonEncode(item.selectedModifiers),
      'special_instructions': item.specialInstructions,
      'custom_properties': jsonEncode(item.customProperties),
      'is_available': item.isAvailable ? 1 : 0,
      'sent_to_kitchen': item.sentToKitchen ? 1 : 0,
      'created_at': item.createdAt.toIso8601String(),
    };
  }

  /// Shows a detailed change summary dialog before sending to kitchen
  Future<bool?> _showChangeSummaryDialog(List<OrderItem> newItems) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.restaurant, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Send to Kitchen'),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 400,
            maxHeight: 400,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The following ${newItems.length} item${newItems.length > 1 ? 's' : ''} will be sent to kitchen:',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                ...newItems.map((item) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.menuItem.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Qty: ${item.quantity}',
                              style: TextStyle(
                                color: Colors.orange.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (item.notes?.isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Notes: ${item.notes}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                )).toList(),
                const SizedBox(height: 16),
                Text(
                  'Are you sure you want to send these items to kitchen?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.send),
            label: const Text('Send to Kitchen'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  /// Print kitchen ticket
  Future<void> _printKitchenTicket() async {
    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      final printerAssignmentService = Provider.of<EnhancedPrinterAssignmentService?>(context, listen: false);
      if (printerAssignmentService == null) {
        throw Exception('EnhancedPrinterAssignmentService not available - services not initialized');
      }
      
      // Segregate items by printer assignments and print directly
      final Map<String, List<OrderItem>> itemsByPrinter = await printingService.segregateOrderItems(
        _currentOrder,
        printerAssignmentService,
      );
      
      // Print to segregated printers
      await printingService.printOrderSegregated(_currentOrder, itemsByPrinter);
      
      // Show success message with printer details
      final printerCount = itemsByPrinter.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Kitchen tickets printed to $printerCount printer${printerCount == 1 ? '' : 's'} successfully'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing ticket: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _closeTable() async {
    // Show confirmation dialog
    final confirmed = await ConfirmationDialogHelper.showConfirmation(
      context,
      title: 'Close Table',
      message: 'Are you sure you want to close this table? This will mark the table as available and complete the order.',
      confirmText: 'Close Table',
      cancelText: 'Cancel',
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // CRITICAL FIX: Maintain printer connections before closing order
      final printingService = Provider.of<PrintingService>(context, listen: false);
      try {
        await printingService.maintainConnectionsDuringOrderCompletion();
        debugPrint('🔌 Printer connections maintained before table close');
      } catch (e) {
        debugPrint('⚠️ Failed to maintain printer connections: $e');
        // Continue with table close even if connection maintenance fails
      }
      
      // Mark order as completed
      final completedOrder = widget.order.copyWith(
        status: OrderStatus.completed,
        completedTime: DateTime.now(),
      );
      
      // Save the completed order
      final orderService = Provider.of<OrderService>(context, listen: false);
      await orderService.saveOrder(completedOrder);
      
      // Free up the table
      if (widget.order.tableId != null) {
        final tableService = Provider.of<TableService>(context, listen: false);
        await tableService.freeTable(widget.order.tableId!);
      }

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Table closed successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Navigate back to POS Dashboard (OrderTypeSelectionScreen)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const OrderTypeSelectionScreen(),
          ),
          (route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error closing table: $e';
      });
      if (mounted) {
        await ErrorDialogHelper.showError(
          context,
          title: 'Error Closing Table',
          message: 'Failed to close table: $e',
        );
      }
    }
  }

  /// Void an item (admin only)
  Future<void> _voidItem(OrderItem item) async {
    if (!widget.user.isAdmin) {
      await ErrorDialogHelper.showValidationError(
        context,
        message: 'Only admin users can void items.',
      );
      return;
    }

    final confirmed = await ConfirmationDialogHelper.showConfirmation(
      context,
      title: 'Void Item',
      message: 'Are you sure you want to void "${item.menuItem.name}"? This action cannot be undone.',
      confirmText: 'Void',
      cancelText: 'Cancel',
    );

    if (confirmed != true) return;

    // Save current state to history before making changes
    _saveToHistory();

    setState(() {
      final itemIndex = widget.order.items.indexWhere(
        (orderItem) => orderItem.id == item.id,
      );

      if (itemIndex != -1) {
        widget.order.items[itemIndex] = item.copyWith(
          voided: true,
          voidedBy: widget.user.id,
          voidedAt: DateTime.now(),
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.menuItem.name} voided'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Comp an item (admin only)
  Future<void> _compItem(OrderItem item) async {
    if (!widget.user.isAdmin) {
      await ErrorDialogHelper.showValidationError(
        context,
        message: 'Only admin users can comp items.',
      );
      return;
    }

    final confirmed = await ConfirmationDialogHelper.showConfirmation(
      context,
      title: 'Comp Item',
      message: 'Are you sure you want to comp "${item.menuItem.name}"? This will make the item free.',
      confirmText: 'Comp',
      cancelText: 'Cancel',
    );

    if (confirmed != true) return;

    // Save current state to history before making changes
    _saveToHistory();

    setState(() {
      final itemIndex = widget.order.items.indexWhere(
        (orderItem) => orderItem.id == item.id,
      );

      if (itemIndex != -1) {
        widget.order.items[itemIndex] = item.copyWith(
          comped: true,
          compedBy: widget.user.id,
          compedAt: DateTime.now(),
          unitPrice: 0.0, // Make it free
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.menuItem.name} comped'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Apply discount to an item (admin only)
  Future<void> _applyDiscount(OrderItem item) async {
    if (!widget.user.isAdmin) {
      await ErrorDialogHelper.showValidationError(
        context,
        message: 'Only admin users can apply discounts.',
      );
      return;
    }

    final discountController = TextEditingController();
    final discountType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apply Discount'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Apply discount to "${item.menuItem.name}"'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, 'percentage'),
                    child: const Text('Percentage'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, 'amount'),
                    child: const Text('Amount'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (discountType == null) return;

    final discountValue = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter ${discountType == 'percentage' ? 'Percentage' : 'Amount'}'),
        content: TextField(
          controller: discountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: discountType == 'percentage' ? 'Percentage (%)' : 'Amount (\$)',
            hintText: discountType == 'percentage' ? '10' : '5.00',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(discountController.text);
              if (value != null && value > 0) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (discountValue == null) return;

    // Save current state to history before making changes
    _saveToHistory();

    setState(() {
      final itemIndex = widget.order.items.indexWhere(
        (orderItem) => orderItem.id == item.id,
      );

      if (itemIndex != -1) {
        double newPrice = item.unitPrice;
        if (discountType == 'percentage') {
          newPrice = item.unitPrice * (1 - discountValue / 100);
        } else {
          newPrice = (item.unitPrice - discountValue).clamp(0.0, item.unitPrice);
        }

        widget.order.items[itemIndex] = item.copyWith(
          unitPrice: newPrice,
          discountPercentage: discountType == 'percentage' ? discountValue : null,
          discountAmount: discountType == 'amount' ? discountValue : null,
          discountedBy: widget.user.id,
          discountedAt: DateTime.now(),
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Discount applied to ${item.menuItem.name}'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Reprint kitchen ticket
  Future<void> _reprintKitchenTicket() async {
    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      await printingService.printKitchenTicket(widget.order);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kitchen ticket reprinted'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      await ErrorDialogHelper.showError(
        context,
        title: 'Print Error',
        message: 'Failed to reprint kitchen ticket: $e',
      );
    }
  }

  /// Cancel order
  void _cancelOrder() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Text('Are you sure you want to cancel order ${_currentOrder.orderNumber}?\n\nThis action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _performOrderCancellation();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
  }

  /// Perform the actual order cancellation
  Future<void> _performOrderCancellation() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cancelling order...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Update order status to cancelled using the proper method
      final orderService = Provider.of<OrderService>(context, listen: false);
      
      // Use updateOrderStatus instead of saveOrder to bypass validation
      final success = await orderService.updateOrderStatus(_currentOrder.id, 'cancelled');
      
      // Also update the completed_time for cancelled orders
      if (success) {
        try {
          final databaseService = Provider.of<DatabaseService>(context, listen: false);
          final database = await databaseService.database;
          if (database != null) {
            await database.update(
              'orders',
              {'completed_time': DateTime.now().toIso8601String()},
              where: 'id = ?',
              whereArgs: [_currentOrder.id],
            );
          }
        } catch (e) {
          debugPrint('⚠️ Failed to update completed_time: $e');
          // Don't fail the cancellation if this fails
        }
      }
      
      if (success) {
        // Log the cancellation
        try {
          final activityLogService = Provider.of<ActivityLogService>(context, listen: false);
          await activityLogService.logActivity(
            action: ActivityAction.orderCancelled,
            description: 'Order ${_currentOrder.orderNumber} cancelled',
            targetId: _currentOrder.id,
            targetType: 'order',
            metadata: {
              'order_number': _currentOrder.orderNumber,
              'cancelled_by': widget.user.name,
              'cancelled_at': DateTime.now().toIso8601String(),
            },
          );
        } catch (e) {
          debugPrint('⚠️ Failed to log cancellation activity: $e');
        }

        // Show success message and navigate back
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order ${_currentOrder.orderNumber} has been cancelled'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
          Navigator.pop(context); // Return to previous screen
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to cancel order. Please try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error cancelling order: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling order: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Navigate to checkout screen
  Future<void> _navigateToCheckout() async {
    try {
      final result = await Navigator.push<Order>(
        context,
        MaterialPageRoute<Order>(
          builder: (context) => CheckoutScreen(
            order: _currentOrder,
            user: widget.user,
            orderType: _currentOrder.type,
            enableBillSplitting: true,
            table: _currentOrder.tableId != null 
                ? restaurant_table.Table(
                    id: _currentOrder.tableId!,
                    number: int.tryParse(_currentOrder.tableId!) ?? 1,
                    capacity: 4,
                    status: restaurant_table.TableStatus.occupied,
                  )
                : null,
          ),
        ),
      );
      
      if (result != null && mounted) {
        Navigator.pop(context, result);
      }
    } catch (e) {
      if (mounted) {
        await ErrorDialogHelper.showError(
          context,
          title: 'Checkout Error',
          message: 'Failed to open checkout: $e',
        );
      }
    }
  }

  /// Show discount dialog for the entire order
  Future<void> _showDiscountDialog() async {
    final discountController = TextEditingController(
      text: _currentOrder.discountAmount?.toString() ?? '',
    );
    
    final discountType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.discount, color: Colors.blue),
            SizedBox(width: 8),
            Text('Order Discount'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Apply discount to entire order'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, 'percentage'),
                    child: const Text('Percentage'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, 'amount'),
                    child: const Text('Amount'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (discountType == null) return;

    final discountValue = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter ${discountType == 'percentage' ? 'Percentage' : 'Amount'}'),
        content: TextField(
          controller: discountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: discountType == 'percentage' ? 'Percentage (%)' : 'Amount (\$)',
            hintText: discountType == 'percentage' ? '10' : '5.00',
          ),
          autofocus: true,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(discountController.text);
              if (value != null && value > 0) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (discountValue == null) return;

    // Save current state to history before making changes
    _saveToHistory();

    setState(() {
      double discountAmount;
      if (discountType == 'percentage') {
        discountAmount = _currentOrder.subtotal * (discountValue / 100);
      } else {
        discountAmount = discountValue.clamp(0.0, _currentOrder.subtotal);
      }

      _currentOrder = _currentOrder.copyWith(
        discountAmount: discountAmount,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied ${discountType == 'percentage' ? '${discountValue}%' : '\$${discountValue}'} discount to order'),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show gratuity dialog for dine-in orders
  Future<void> _showGratuityDialog() async {
    final gratuityController = TextEditingController(
      text: _currentOrder.gratuityAmount?.toString() ?? '',
    );
    
    final gratuityType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.attach_money, color: Colors.green),
            SizedBox(width: 8),
            Text('Add Gratuity'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add gratuity for table service'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, 'percentage'),
                    child: const Text('Percentage'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, 'amount'),
                    child: const Text('Amount'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Quick options:',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 4,
              children: [
                _buildQuickGratuityButton('15%', 15.0),
                _buildQuickGratuityButton('18%', 18.0),
                _buildQuickGratuityButton('20%', 20.0),
                _buildQuickGratuityButton('25%', 25.0),
              ],
            ),
          ],
        ),
      ),
    );

    if (gratuityType == null) return;

    final gratuityValue = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter ${gratuityType == 'percentage' ? 'Percentage' : 'Amount'}'),
        content: TextField(
          controller: gratuityController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: gratuityType == 'percentage' ? 'Percentage (%)' : 'Amount (\$)',
            hintText: gratuityType == 'percentage' ? '18' : '10.00',
          ),
          autofocus: true,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = double.tryParse(gratuityController.text);
              if (value != null && value > 0) {
                Navigator.pop(context, value);
              }
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (gratuityValue == null) return;

    // Save current state to history before making changes
    _saveToHistory();

    setState(() {
      double gratuityAmount;
      if (gratuityType == 'percentage') {
        final subtotalAfterDiscount = _currentOrder.subtotal - (_currentOrder.discountAmount ?? 0.0);
        gratuityAmount = subtotalAfterDiscount * (gratuityValue / 100);
      } else {
        gratuityAmount = gratuityValue;
      }

      _currentOrder = _currentOrder.copyWith(
        gratuityAmount: gratuityAmount,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied ${gratuityType == 'percentage' ? '${gratuityValue}%' : '\$${gratuityValue}'} gratuity'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildQuickGratuityButton(String label, double value) {
    return InkWell(
      onTap: () {
        Navigator.pop(context, 'percentage');
        // Apply the quick percentage immediately
        Future.delayed(Duration(milliseconds: 100), () {
          _applyQuickGratuity(value);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.green.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _applyQuickGratuity(double percentage) {
    // Save current state to history before making changes
    _saveToHistory();

    setState(() {
      final subtotalAfterDiscount = _currentOrder.subtotal - (_currentOrder.discountAmount ?? 0.0);
      final gratuityAmount = subtotalAfterDiscount * (percentage / 100);

      _currentOrder = _currentOrder.copyWith(
        gratuityAmount: gratuityAmount,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Applied ${percentage}% gratuity'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: _buildAppBar(),
        body: _error != null
            ? _buildErrorState(_error!)
            : _buildMainContent(),
        bottomNavigationBar: _buildActionButtons(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Order #${widget.order.orderNumber}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            widget.order.type == OrderType.dineIn ? 'Dine-In' : 'Takeout',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            'Server: ${widget.user.name}',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.1),
      actions: [
        // Admin actions
        if (widget.user.isAdmin) ...[
          PopupMenuButton<String>(
            icon: const Icon(Icons.admin_panel_settings, color: Colors.purple),
            tooltip: 'Admin Actions',
            onSelected: (value) async {
              switch (value) {
                case 'reprint':
                  await _reprintKitchenTicket();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'reprint',
                child: Row(
                  children: [
                    Icon(Icons.print, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Reprint Kitchen Ticket'),
                  ],
                ),
              ),
            ],
          ),
        ],
        const CustomBackButton(),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {

    
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: _isLoading && label == 'Send' 
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(icon, size: 18),
      label: Text(
        _isLoading && label == 'Send' ? 'Sending...' : label, 
        style: const TextStyle(fontSize: 12)
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _isLoading ? Colors.grey : color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildDisabledActionButton({
    required IconData icon,
    required String label,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: ElevatedButton.icon(
        onPressed: null,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey.shade300,
          foregroundColor: Colors.grey.shade600,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final hasNewItems = _currentOrder.items.any((item) => !item.sentToKitchen);
    final hasAnyItems = _currentOrder.items.isNotEmpty;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 5,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top row - Quick actions
          Row(
            children: [
              // Undo/Redo buttons
              if (_canUndo || _canRedo) ...[
                IconButton(
                  onPressed: _canUndo ? _undo : null,
                  icon: const Icon(Icons.undo),
                  tooltip: 'Undo',
                  color: _canUndo ? Theme.of(context).primaryColor : Colors.grey,
                ),
                IconButton(
                  onPressed: _canRedo ? _redo : null,
                  icon: const Icon(Icons.redo),
                  tooltip: 'Redo',
                  color: _canRedo ? Theme.of(context).primaryColor : Colors.grey,
                ),
                const SizedBox(width: 8),
                Container(
                  height: 30,
                  width: 1,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(width: 8),
              ],
              
              // Print receipt button
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: hasAnyItems ? _printKitchenTicket : null,
                  icon: const Icon(Icons.print, size: 16),
                  label: const Text('Print'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              
              // Discount button (Admin only)
              if (widget.user.isAdmin) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasAnyItems ? _showDiscountDialog : null,
                    icon: const Icon(Icons.discount, size: 16),
                    label: const Text('Discount'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      side: const BorderSide(color: Colors.purple),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              
              // Gratuity button (Dine-in only)
              if (_currentOrder.type == OrderType.dineIn) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: hasAnyItems ? _showGratuityDialog : null,
                    icon: const Icon(Icons.attach_money, size: 16),
                    label: const Text('Tip'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Bottom row - Main actions
          Row(
            children: [
              // Send to kitchen button
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: hasNewItems ? _sendToKitchen : null,
                  icon: _isLoading 
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.kitchen),
                  label: Text(_isLoading ? 'Sending...' : 'Send to Kitchen'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasNewItems ? Colors.orange : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Checkout button
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: hasAnyItems ? _navigateToCheckout : null,
                  icon: const Icon(Icons.payment),
                  label: const Text('Checkout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasAnyItems ? Colors.green : Colors.grey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Cancel Order button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _cancelOrder,
                  icon: const Icon(Icons.cancel),
                  label: const Text('Cancel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              
              // Close table button (Dine-in only, Admin only)
              if (_currentOrder.type == OrderType.dineIn && widget.user.isAdmin) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: hasAnyItems ? _closeTable : null,
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Close'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasAnyItems ? Colors.red.shade800 : Colors.grey,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Row(
      children: [
        // Left Panel - Order Details
        Expanded(
          flex: 1,
          child: _buildOrderPanel(),
        ),
        // Right Panel - Menu
        Expanded(
          flex: 2,
          child: _buildMenuPanel(),
        ),
      ],
    );
  }

  Widget _buildOrderPanel() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildOrderHeader(),
          Expanded(
            child: _buildOrderItems(),
          ),
          _buildOrderSummary(),
        ],
      ),
    );
  }

  Widget _buildOrderHeader() {
    final newItemsCount = widget.order.items.where((item) => !item.sentToKitchen).length;
    final sentItemsCount = widget.order.items.where((item) => item.sentToKitchen).length;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.order.type == OrderType.dineIn ? 'Dine-In Order' : 'Takeout Order',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Server: ${widget.user.name}',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 12,
            ),
          ),
          if (_currentOrder.items.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (newItemsCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$newItemsCount New',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (sentItemsCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$sentItemsCount Sent',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderItems() {
    if (_currentOrder.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 48,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 8),
            Text(
              'No items in order',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    // Check if all items have been sent to kitchen
    final allItemsSent = _currentOrder.items.every((item) => item.sentToKitchen);
    
    return Column(
      children: [
        if (allItemsSent) ...[
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.blue.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'All items have been sent to kitchen. Add new items to send more.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: _currentOrder.items.length,
            itemBuilder: (context, index) {
              final item = _currentOrder.items[index];
              return _buildOrderItemCard(item);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrderItemCard(OrderItem item) {
    final isNewItem = !item.sentToKitchen;
    final isVoided = item.voided == true;
    final isComped = item.comped == true;
    final hasDiscount = item.discountPercentage != null || item.discountAmount != null;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isVoided ? Colors.red.shade50 : 
             isComped ? Colors.green.shade50 :
             hasDiscount ? Colors.blue.shade50 :
             item.sentToKitchen ? Colors.grey.shade50 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            // Kitchen status indicator
            Container(
              width: 4,
              height: 40,
              decoration: BoxDecoration(
                color: isVoided ? Colors.red :
                       isComped ? Colors.green :
                       hasDiscount ? Colors.blue :
                       item.sentToKitchen ? Colors.green : Colors.orange,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.menuItem.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isVoided ? Colors.red.shade700 :
                                   isComped ? Colors.green.shade700 :
                                   hasDiscount ? Colors.blue.shade700 :
                                   item.sentToKitchen ? Colors.grey.shade600 : Colors.black,
                            decoration: isVoided ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Status badges
                      if (isVoided)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'VOID',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (isComped)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'COMP',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (hasDiscount)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'DISCOUNT',
                            style: TextStyle(
                              color: Colors.blue.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (item.sentToKitchen)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Sent',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (isNewItem)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'New',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    isComped ? 'FREE' : '\$${item.unitPrice.toStringAsFixed(2)} each',
                    style: TextStyle(
                      color: isComped ? Colors.green.shade700 : Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: isComped ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (hasDiscount) ...[
                    Text(
                      item.discountPercentage != null 
                          ? '${item.discountPercentage}% off'
                          : '\$${item.discountAmount} off',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _buildQuantityControls(item),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isVoided ? 'VOID' : '\$${item.totalPrice.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isVoided ? Colors.red.shade700 :
                           isComped ? Colors.green.shade700 :
                           hasDiscount ? Colors.blue.shade700 :
                           item.sentToKitchen ? Colors.grey.shade600 : Colors.green,
                  ),
                ),
                // Admin action buttons
                if (widget.user.isAdmin && !isVoided) ...[
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () => _voidItem(item),
                        icon: const Icon(Icons.block, size: 14),
                        color: Colors.red.shade400,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Void Item',
                      ),
                      if (!isComped)
                        IconButton(
                          onPressed: () => _compItem(item),
                          icon: const Icon(Icons.free_breakfast, size: 14),
                          color: Colors.green.shade400,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Comp Item',
                        ),
                      if (!hasDiscount)
                        IconButton(
                          onPressed: () => _applyDiscount(item),
                          icon: const Icon(Icons.discount, size: 14),
                          color: Colors.blue.shade400,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          tooltip: 'Apply Discount',
                        ),
                    ],
                  ),
                ],
                // Only show delete button if user is admin OR item is not sent to kitchen
                if (widget.user.isAdmin || !item.sentToKitchen) ...[
                  IconButton(
                    onPressed: () => _removeItemFromOrder(item),
                    icon: Icon(
                      item.sentToKitchen && !widget.user.isAdmin 
                          ? Icons.lock_outline 
                          : Icons.delete_outline, 
                      size: 16
                    ),
                    color: item.sentToKitchen && !widget.user.isAdmin 
                        ? Colors.grey.shade400 
                        : Colors.red.shade400,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: item.sentToKitchen && !widget.user.isAdmin 
                        ? 'Only admin can remove sent items' 
                        : 'Remove item',
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityControls(OrderItem item) {
    final isDisabled = item.sentToKitchen && !widget.user.isAdmin;
    
    return Container(
      decoration: BoxDecoration(
        color: isDisabled ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDisabled ? Colors.grey.shade300 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: isDisabled ? null : () => _updateItemQuantity(item, item.quantity - 1),
            icon: Icon(
              Icons.remove, 
              size: 14,
              color: isDisabled ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              '${item.quantity}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDisabled ? Colors.grey.shade500 : Colors.black,
              ),
            ),
          ),
          IconButton(
            onPressed: isDisabled ? null : () => _updateItemQuantity(item, item.quantity + 1),
            icon: Icon(
              Icons.add, 
              size: 14,
              color: isDisabled ? Colors.grey.shade400 : Theme.of(context).primaryColor,
            ),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    final subtotal = _currentOrder.subtotal;
    final discountAmount = _currentOrder.discountAmount ?? 0.0;
    final gratuityAmount = _currentOrder.gratuityAmount ?? 0.0;
    final subtotalAfterDiscount = subtotal - discountAmount;
    final tax = subtotalAfterDiscount * 0.08;
    final total = subtotalAfterDiscount + tax + gratuityAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Subtotal', subtotal),
          if (discountAmount > 0) ...[
            const SizedBox(height: 4),
            _buildSummaryRow('Discount', -discountAmount, isDiscount: true),
          ],
          const SizedBox(height: 4),
          _buildSummaryRow('Tax (8%)', tax),
          if (_currentOrder.type == OrderType.dineIn && gratuityAmount > 0) ...[
            const SizedBox(height: 4),
            _buildSummaryRow('Gratuity', gratuityAmount, isGratuity: true),
          ],
          const SizedBox(height: 8),
          // Action buttons for admin
          if (widget.user.isAdmin) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showDiscountDialog(),
                    icon: const Icon(Icons.discount, size: 16),
                    label: Text(discountAmount > 0 ? 'Edit Discount' : 'Add Discount'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: BorderSide(color: Colors.blue.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                if (_currentOrder.type == OrderType.dineIn) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showGratuityDialog(),
                      icon: const Icon(Icons.attach_money, size: 16),
                      label: Text(gratuityAmount > 0 ? 'Edit Gratuity' : 'Add Gratuity'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: BorderSide(color: Colors.green.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
          ],
          const Divider(height: 16),
          _buildSummaryRow('Total', total, isTotal: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false, bool isDiscount = false, bool isGratuity = false}) {
    Color textColor = Colors.grey.shade700;
    if (isTotal) textColor = Colors.black;
    if (isDiscount) textColor = Colors.red.shade600;
    if (isGratuity) textColor = Colors.green.shade600;
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 12,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: textColor,
          ),
        ),
        Text(
          '\$${amount.abs().toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal ? 16 : 12,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? Colors.green : textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuPanel() {
    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuHeader(),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isViewingCategory
                    ? _buildItemsView()
                    : _buildCategoriesView(),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Reduced padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back button (only show when viewing items)
          if (_isViewingCategory) ...[
            InkWell(
              onTap: _navigateBackToCategories,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.arrow_back,
                  size: 20,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          
          // Icon
          Icon(
            Icons.restaurant_menu,
            color: Theme.of(context).primaryColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isViewingCategory 
                      ? _selectedCategory?.name ?? 'Menu Items'
                      : 'Menu Categories',
                  style: const TextStyle(
                    fontSize: 15, // Slightly reduced
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_isViewingCategory && _selectedCategory != null)
                  Text(
                    'Select items to add to your order',
                    style: TextStyle(
                      fontSize: 11, // Reduced from 12
                      color: Colors.grey.shade600,
                    ),
                  ),
                if (!_isViewingCategory)
                  Text(
                    'Choose a category to view menu items',
                    style: TextStyle(
                      fontSize: 11, // Reduced from 12
                      color: Colors.grey.shade600,
                    ),
                  ),
              ],
            ),
          ),
          
          // Item count indicator
          if (_isViewingCategory && _menuItems.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_menuItems.length} items',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoriesView() {
    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No Categories Available',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please check back later or contact support',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12), // Reduced padding
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, // Changed to 4 columns as requested
          childAspectRatio: 0.8, // Adjusted for 4 columns
          crossAxisSpacing: 8, // Reduced spacing for 4 columns
          mainAxisSpacing: 8, // Reduced spacing for 4 columns
        ),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return _buildElegantCategoryCard(category);
        },
      ),
    );
  }

  Widget _buildElegantCategoryCard(pos_category.Category category) {
    return InkWell(
      onTap: () => _onCategorySelected(category),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12), // Reduced padding
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Category Icon with elegant background
              Container(
                width: 40, // Reduced size
                height: 40, // Reduced size
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      Theme.of(context).primaryColor.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                                child: Icon(
                  _getCategoryIcon(category.name),
                  size: 24, // Reduced from 32
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8), // Reduced spacing
              
              // Category Name
              Text(
                category.name,
                style: const TextStyle(
                  fontSize: 21, // Increased by 50% (14 * 1.5)
                  fontWeight: FontWeight.bold, // Made bold
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4), // Reduced spacing
              
              // Category Description or item count
              Text(
                (category.description?.isNotEmpty == true) 
                    ? category.description!
                    : 'Tap to explore items',
                style: TextStyle(
                  fontSize: 15, // Increased by 50% (10 * 1.5)
                  fontWeight: FontWeight.bold, // Made bold
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1, // Reduced from 2 to save space
                overflow: TextOverflow.ellipsis,
              ),
              
              const Spacer(),
              
              // Explore indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Reduced padding
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8), // Reduced radius
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Explore',
                      style: TextStyle(
                        fontSize: 15, // Increased by 50% (10 * 1.5)
                        fontWeight: FontWeight.bold, // Made bold
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(width: 2), // Reduced spacing
                    Icon(
                      Icons.arrow_forward,
                      size: 12, // Reduced from 14
                      color: Theme.of(context).primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper method to get appropriate icons for different categories
  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();
    if (name.contains('appetizer') || name.contains('starter')) return Icons.restaurant;
    if (name.contains('main') || name.contains('entree')) return Icons.dinner_dining;
    if (name.contains('dessert') || name.contains('sweet')) return Icons.cake;
    if (name.contains('drink') || name.contains('beverage')) return Icons.local_drink;
    if (name.contains('salad')) return Icons.grass;
    if (name.contains('soup')) return Icons.soup_kitchen;
    if (name.contains('seafood') || name.contains('fish')) return Icons.set_meal;
    if (name.contains('meat') || name.contains('grill')) return Icons.outdoor_grill;
    if (name.contains('vegetarian') || name.contains('vegan')) return Icons.eco;
    if (name.contains('pasta') || name.contains('noodle')) return Icons.ramen_dining;
    return Icons.restaurant_menu;
  }

  Widget _buildItemsView() {
    if (_menuItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No Items Available',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This category appears to be empty',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _navigateBackToCategories,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Categories'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(8), // Further reduced padding
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4, // Changed to 4 columns as requested
          childAspectRatio: 0.9, // Adjusted for 4 columns
          crossAxisSpacing: 6, // Further reduced spacing for 4 columns
          mainAxisSpacing: 6, // Further reduced spacing for 4 columns
        ),
        itemCount: _menuItems.length,
        itemBuilder: (context, index) {
          final item = _menuItems[index];
          return _buildElegantMenuItemCard(item);
        },
      ),
    );
  }

  Widget _buildElegantMenuItemCard(MenuItem item) {
    return InkWell(
      onTap: () => _addItemToOrder(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.grey.shade50,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(8), // Further reduced padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Item image placeholder with elegant styling
              Container(
                height: 45, // Further reduced height
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor.withValues(alpha: 0.1),
                      Theme.of(context).primaryColor.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.restaurant,
                  size: 22, // Further reduced
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6), // Further reduced spacing
              
              // Item name
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 18, // Increased by 50% (12 * 1.5)
                  fontWeight: FontWeight.bold, // Made bold
                  color: Colors.black87,
                ),
                maxLines: 1, // Reduced to 1 line to save space
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2), // Further reduced spacing
              
              // Item description
              if (item.description.isNotEmpty)
                Text(
                  item.description,
                  style: TextStyle(
                    fontSize: 15, // Increased by 50% (10 * 1.5)
                    fontWeight: FontWeight.bold, // Made bold
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              
              const Spacer(),
              
              // Price and add button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$${item.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 21, // Increased by 50% (14 * 1.5)
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(4), // Further reduced padding
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).primaryColor,
                          Theme.of(context).primaryColor.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(6), // Further reduced radius
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                          blurRadius: 2, // Further reduced blur
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 16, // Further reduced
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.error_outline, color: Colors.red),
          SizedBox(height: 16),
          Text(
            'Error Loading Order',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Failed to load order details. Please try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: null,
            child: Text('Retry'),
          ),
        ],
      ),
    );
  }
} 