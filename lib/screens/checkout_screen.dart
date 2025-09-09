import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../models/table.dart' as restaurant_table;
import '../services/payment_service.dart';
import '../services/printing_service.dart';
import '../services/order_service.dart';
import '../services/table_service.dart';
import '../services/order_log_service.dart';
import '../services/inventory_service.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/back_button.dart';
import '../widgets/error_dialog.dart';
import 'print_preview_screen.dart';
import 'order_type_selection_screen.dart';

class CheckoutScreen extends StatefulWidget {
  final Order order;
  final User user;
  final restaurant_table.Table? table;
  final OrderType orderType;
  final bool enableBillSplitting;

  const CheckoutScreen({
    super.key,
    required this.order,
    required this.user,
    this.table,
    required this.orderType,
    this.enableBillSplitting = false,
  });

  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isLoading = false;
  String? _error;
  String _selectedPaymentMethod = 'Cash';
  double _tipAmount = 0.0;
  double _tipPercentage = 0.0;
  double _amountTendered = 0.0;
  final TextEditingController _customTipController = TextEditingController();
  final TextEditingController _amountTenderedController = TextEditingController();

  // Bill splitting
  bool _isBillSplit = false;
  int _numberOfSplits = 2;
  List<Map<String, dynamic>> _splitPayments = [];

  // Tip percentage options
  static const List<double> tipPercentages = [0, 10, 15, 18, 20, 25];

  @override
  void initState() {
    super.initState();
    _amountTenderedController.text = widget.order.totalAmount.toStringAsFixed(2);
    _amountTendered = widget.order.totalAmount;
  }

  @override
  void dispose() {
    _customTipController.dispose();
    _amountTenderedController.dispose();
    super.dispose();
  }

  /// Calculate tip amount based on percentage
  void _calculateTipFromPercentage(double percentage) {
    setState(() {
      _tipPercentage = percentage;
      // CRITICAL FIX: Calculate tip based on subtotal + HST (excluding existing gratuity)
      final baseForTip = widget.order.subtotalAfterDiscount + widget.order.calculatedHstAmount;
      _tipAmount = baseForTip * (percentage / 100);
      _customTipController.text = _tipAmount.toStringAsFixed(2);
      
      // Update amount tendered to include tip
      _amountTendered = widget.order.totalAmount + _tipAmount;
      _amountTenderedController.text = _amountTendered.toStringAsFixed(2);
    });
  }

  /// Calculate tip percentage from custom amount
  void _calculatePercentageFromCustomTip(String value) {
    final tipAmount = double.tryParse(value) ?? 0.0;
    setState(() {
      _tipAmount = tipAmount;
      // CRITICAL FIX: Calculate percentage based on subtotal + HST (excluding existing gratuity)
      final baseForTip = widget.order.subtotalAfterDiscount + widget.order.calculatedHstAmount;
      _tipPercentage = baseForTip > 0 ? (tipAmount / baseForTip) * 100 : 0;
      
      // Update amount tendered to include tip
      _amountTendered = widget.order.totalAmount + _tipAmount;
      _amountTenderedController.text = _amountTendered.toStringAsFixed(2);
    });
  }

  /// Calculate change amount
  double get _changeAmount => _amountTendered - _finalTotal;

  /// Get final total including tip (order already includes gratuity in totalAmount)
  double get _finalTotal => widget.order.totalAmount + _tipAmount;

  /// Initialize bill splitting
  void _initializeBillSplit() {
    _splitPayments.clear();
    final splitAmount = _finalTotal / _numberOfSplits;
    
    for (int i = 0; i < _numberOfSplits; i++) {
      _splitPayments.add({
        'amount': splitAmount,
        'paymentMethod': 'Cash',
        'amountTendered': splitAmount,
        'paid': false,
      });
    }
  }

  /// Toggle bill splitting
  void _toggleBillSplit() {
    setState(() {
      _isBillSplit = !_isBillSplit;
      if (_isBillSplit) {
        _initializeBillSplit();
      } else {
        _splitPayments.clear();
      }
    });
  }

  /// Update number of splits
  void _updateNumberOfSplits(int splits) {
    setState(() {
      _numberOfSplits = splits;
      if (_isBillSplit) {
        _initializeBillSplit();
      }
    });
  }

  /// Process split payment for a specific split
  Future<void> _processSplitPayment(int index) async {
    final split = _splitPayments[index];
    
    if (split['amountTendered'] < split['amount']) {
      await ErrorDialogHelper.showValidationError(
        context,
        message: 'Amount tendered must be at least \$${split['amount'].toStringAsFixed(2)}',
      );
      return;
    }

    setState(() {
      _splitPayments[index]['paid'] = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Split ${index + 1} payment processed'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Check if all splits are paid
  bool get _allSplitsPaid => _splitPayments.every((split) => split['paid'] == true);

  /// Process payment
  Future<void> _processPayment() async {
    // Handle bill splitting
    if (_isBillSplit) {
      if (!_allSplitsPaid) {
        await ErrorDialogHelper.showValidationError(
          context,
          message: 'All split payments must be processed before completing the order',
        );
        return;
      }
    } else {
      if (_amountTendered < _finalTotal) {
        await ErrorDialogHelper.showValidationError(
          context,
          message: 'Amount tendered must be at least \$${_finalTotal.toStringAsFixed(2)}',
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final paymentService = Provider.of<PaymentService>(context, listen: false);
      final orderService = Provider.of<OrderService>(context, listen: false);
      final printingService = Provider.of<PrintingService>(context, listen: false);
      final inventoryService = Provider.of<InventoryService>(context, listen: false);

      // Update order with tip and payment info
      final updatedOrder = widget.order.copyWith(
        tipAmount: _tipAmount,
        paymentMethod: _selectedPaymentMethod,
        paymentStatus: PaymentStatus.paid,
        status: OrderStatus.completed,
        completedTime: DateTime.now(),
        totalAmount: _finalTotal, // Include tip in total
        updatedAt: DateTime.now(),
      );

      debugPrint('💳 Processing payment for order: ${updatedOrder.orderNumber}');
      debugPrint('💳 Payment method: $_selectedPaymentMethod');
      debugPrint('💳 Amount: \$${_finalTotal.toStringAsFixed(2)}');
      debugPrint('💳 Tip: \$${_tipAmount.toStringAsFixed(2)}');
      debugPrint('💳 Amount tendered: \$${_amountTendered.toStringAsFixed(2)}');

      // Process payment
      await paymentService.processPayment(
        order: updatedOrder,
        method: _selectedPaymentMethod,
        amount: _finalTotal,
      );

      // Log payment processing
      _logPaymentProcessed(updatedOrder, _finalTotal, _selectedPaymentMethod);

      // Save updated order with payment completion log
      final orderSaved = await orderService.saveOrder(updatedOrder);
      if (!orderSaved) {
        throw Exception('Failed to save order to database');
      }



      // Log order completion
      _logOrderCompleted(updatedOrder);

      debugPrint('✅ Order ${updatedOrder.orderNumber} successfully saved as completed');

      // Free up table if dine-in
      if (widget.order.type == OrderType.dineIn && widget.table != null) {
        try {
          final tableService = Provider.of<TableService>(context, listen: false);
          await tableService.freeTable(widget.table!.id);
          debugPrint('✅ Table ${widget.table!.id} freed successfully');
        } catch (e) {
          debugPrint('⚠️ Failed to free table: $e');
          // Continue with checkout even if table freeing fails
        }
      }

      // Print receipt
      try {
        await printingService.printReceipt(updatedOrder);
        debugPrint('✅ Receipt printed successfully');
      } catch (e) {
        debugPrint('⚠️ Failed to print receipt: $e');
        // Continue with checkout even if printing fails
      }

      // CRITICAL FIX: Maintain printer connections during order completion
      try {
        await printingService.maintainConnectionsDuringOrderCompletion();
        debugPrint('🔌 Printer connections maintained during checkout');
      } catch (e) {
        debugPrint('⚠️ Failed to maintain printer connections: $e');
        // Continue with checkout even if connection maintenance fails
      }
      
      // CRITICAL FIX: Don't clear current order state to maintain kitchen printing functionality
      // orderService.clearCurrentOrder(); // REMOVED: This was breaking kitchen printing
      debugPrint('⚠️ Maintaining current order state for kitchen printing functionality');

      // CRITICAL FIX: Check if widget is still mounted before setState
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Show success dialog with change amount
        await _showPaymentSuccessDialog();
        
        // CRITICAL FIX: Check if widget is still mounted before navigation
        if (mounted) {
          // Navigate back to POS Dashboard (OrderTypeSelectionScreen)
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const OrderTypeSelectionScreen(),
            ),
            (route) => false, // Remove all previous routes
          );
        }
      }
    } catch (e) {
      // CRITICAL FIX: Check if widget is still mounted before setState
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Payment failed: $e';
        });
        
        await ErrorDialogHelper.showError(
          context,
          title: 'Payment Error',
          message: 'Failed to process payment: $e',
        );
      }
    }
  }

  /// Show payment success dialog
  Future<void> _showPaymentSuccessDialog() async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Payment Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Order #${widget.order.orderNumber}'),
            const SizedBox(height: 8),
            Text('Total: \$${_finalTotal.toStringAsFixed(2)}'),
            Text('Method: $_selectedPaymentMethod'),
            if (_amountTendered > _finalTotal) ...[
              const SizedBox(height: 8),
              Text(
                'Change: \$${_changeAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Text('Receipt has been printed.'),
          ],
        ),
        actions: <Widget>[
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show receipt preview
  Future<void> _showReceiptPreview() async {
    final updatedOrder = widget.order.copyWith(tipAmount: _tipAmount);
    
    // Navigate to print preview screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrintPreviewScreen(
          order: updatedOrder,
          user: widget.user,
          table: widget.table,
          orderType: widget.orderType.toString().split('.').last,
          isKitchenTicket: false,
        ),
      ),
    );
    
    // If user clicked print, proceed with printing
    if (result == true) {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      
      try {
        await printingService.printReceipt(updatedOrder);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Receipt printed successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to print receipt: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: Text('Checkout - Order #${widget.order.orderNumber}'),
          backgroundColor: Colors.white,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          actions: [
            const CustomBackButton(),
            const SizedBox(width: 16),
          ],
        ),
        body: _error != null
            ? _buildErrorState(_error!)
            : _buildMainContent(),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _error = null;
              });
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOrderSummary(),
          const SizedBox(height: 24),
          _buildPaymentMethodSection(),
          const SizedBox(height: 24),
          if (widget.enableBillSplitting) ...[
            _buildBillSplittingSection(),
            const SizedBox(height: 24),
          ],
          _buildTipSection(),
          const SizedBox(height: 24),
          if (!_isBillSplit) ...[
            _buildAmountTenderedSection(),
            const SizedBox(height: 24),
          ],
          if (_isBillSplit) ...[
            _buildSplitPaymentSection(),
            const SizedBox(height: 24),
          ],
          _buildFinalSummary(),
          const SizedBox(height: 32),
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  'Order Summary',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Subtotal', widget.order.subtotal),
            if (widget.order.taxAmount > 0)
              _buildSummaryRow('Tax', widget.order.taxAmount),
            if (widget.order.hstAmount > 0)
              _buildSummaryRow('HST', widget.order.hstAmount),
            if (widget.order.discountAmount > 0)
              _buildSummaryRow('Discount', -widget.order.discountAmount, isDiscount: true),
            // CRITICAL FIX: Display existing gratuity from order creation as separate line item
            if (widget.order.gratuityAmount > 0) ...[
              _buildSummaryRow('Gratuity (Order Creation)', widget.order.gratuityAmount, isGratuity: true),
            ],
            const Divider(height: 16),
            _buildSummaryRow('Total', widget.order.totalAmount, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payment, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Payment Method',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PaymentService.paymentMethods.map((method) {
                final isSelected = _selectedPaymentMethod == method;
                return ChoiceChip(
                  label: Text(method),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedPaymentMethod = method;
                      });
                    }
                  },
                  selectedColor: Theme.of(context).primaryColor,
                  checkmarkColor: Colors.white,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.tips_and_updates, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  widget.order.gratuityAmount > 0 ? 'Additional Tip (Checkout)' : 'Tip',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.order.gratuityAmount > 0 ? Colors.green.shade50 : Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: widget.order.gratuityAmount > 0 ? Colors.green.shade200 : Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: widget.order.gratuityAmount > 0 ? Colors.green.shade700 : Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.order.gratuityAmount > 0 
                          ? 'Additional tip calculated on subtotal + HST (\$${(widget.order.subtotalAfterDiscount + widget.order.calculatedHstAmount).toStringAsFixed(2)}), separate from existing \$${widget.order.gratuityAmount.toStringAsFixed(2)} gratuity'
                          : 'Tip percentage is calculated based on subtotal + HST (\$${(widget.order.subtotalAfterDiscount + widget.order.calculatedHstAmount).toStringAsFixed(2)})',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.order.gratuityAmount > 0 ? Colors.green.shade700 : Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Tip percentage buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tipPercentages.map((percentage) {
                final isSelected = _tipPercentage == percentage;
                return ChoiceChip(
                  label: Text('${percentage.toInt()}%'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      _calculateTipFromPercentage(percentage);
                    }
                  },
                  selectedColor: Theme.of(context).primaryColor,
                  checkmarkColor: Colors.white,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            // Custom tip input
            TextField(
              controller: _customTipController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Custom Tip Amount',
                prefixText: '\$',
                border: const OutlineInputBorder(),
                suffixText: _tipPercentage > 0 ? '(${_tipPercentage.toStringAsFixed(1)}%)' : null,
              ),
              onChanged: _calculatePercentageFromCustomTip,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountTenderedSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.money, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Amount Tendered',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountTenderedController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Amount Received',
                prefixText: '\$',
                border: const OutlineInputBorder(),
                helperText: _tipAmount > 0 
                    ? 'Order total: \$${widget.order.totalAmount.toStringAsFixed(2)}${widget.order.gratuityAmount > 0 ? ' (incl. \$${widget.order.gratuityAmount.toStringAsFixed(2)} gratuity)' : ''} + Tip: \$${_tipAmount.toStringAsFixed(2)}'
                    : widget.order.gratuityAmount > 0 
                        ? 'Order total: \$${widget.order.totalAmount.toStringAsFixed(2)} (includes \$${widget.order.gratuityAmount.toStringAsFixed(2)} gratuity from order creation)'
                        : 'Enter the amount received from customer',
              ),
              onChanged: (value) {
                setState(() {
                  _amountTendered = double.tryParse(value) ?? 0.0;
                  // Note: Tip calculation should not change when amount tendered changes
                  // Tips are calculated based on order total, not amount received
                });
              },
            ),
            if (_amountTendered > 0 && _changeAmount > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.arrow_upward, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Change: \$${_changeAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFinalSummary() {
    return Card(
      elevation: 2,
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calculate, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Final Total',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Subtotal', widget.order.subtotal),
            if (widget.order.taxAmount > 0)
              _buildSummaryRow('Tax', widget.order.taxAmount),
            if (widget.order.calculatedHstAmount > 0)
              _buildSummaryRow('HST', widget.order.calculatedHstAmount),
            if (widget.order.discountAmount > 0)
              _buildSummaryRow('Discount', -widget.order.discountAmount, isDiscount: true),
            // CRITICAL FIX: Show existing gratuity from order creation and additional tip separately
            if (widget.order.gratuityAmount > 0)
              _buildSummaryRow('Gratuity (Order Creation)', widget.order.gratuityAmount, isGratuity: true),
            if (_tipAmount > 0)
              _buildSummaryRow('Tip (Checkout)', _tipAmount, isGratuity: true),
            const Divider(height: 16),
            _buildSummaryRow('TOTAL', _finalTotal, isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _showReceiptPreview,
                icon: const Icon(Icons.preview),
                label: const Text('Preview Receipt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _processPayment,
                icon: const Icon(Icons.check_circle),
                label: Text('Close Order (\$${_finalTotal.toStringAsFixed(2)})'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBillSplittingSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.group, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Bill Splitting',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Switch(
                  value: _isBillSplit,
                  onChanged: (value) => _toggleBillSplit(),
                  activeColor: Theme.of(context).primaryColor,
                ),
              ],
            ),
            if (_isBillSplit) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Split between:'),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButton<int>(
                      value: _numberOfSplits,
                      items: List.generate(8, (index) => index + 2)
                          .map((splits) => DropdownMenuItem(
                                value: splits,
                                child: Text('$splits people'),
                              ))
                          .toList(),
                      onChanged: (splits) {
                        if (splits != null) {
                          _updateNumberOfSplits(splits);
                        }
                      },
                      isExpanded: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Each person pays: \$${(_finalTotal / _numberOfSplits).toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSplitPaymentSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.payment, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Split Payments',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...List.generate(_splitPayments.length, (index) {
              final split = _splitPayments[index];
              final isPaid = split['paid'] as bool;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isPaid ? Colors.green.shade50 : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isPaid ? Colors.green.shade200 : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Person ${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const Spacer(),
                        if (isPaid) ...[
                          Icon(Icons.check_circle, color: Colors.green.shade600),
                          const SizedBox(width: 4),
                          Text(
                            'PAID',
                            style: TextStyle(
                              color: Colors.green.shade600,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ] else ...[
                          Text(
                            '\$${split['amount'].toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (!isPaid) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButton<String>(
                              value: split['paymentMethod'],
                              items: PaymentService.paymentMethods
                                  .map((method) => DropdownMenuItem(
                                        value: method,
                                        child: Text(method),
                                      ))
                                  .toList(),
                              onChanged: (method) {
                                if (method != null) {
                                  setState(() {
                                    _splitPayments[index]['paymentMethod'] = method;
                                  });
                                }
                              },
                              isExpanded: true,
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Amount',
                                prefixText: '\$',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              controller: TextEditingController(
                                text: split['amountTendered'].toStringAsFixed(2),
                              ),
                              onChanged: (value) {
                                final amount = double.tryParse(value) ?? 0.0;
                                setState(() {
                                  _splitPayments[index]['amountTendered'] = amount;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () => _processSplitPayment(index),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Pay'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _allSplitsPaid ? Colors.green.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _allSplitsPaid ? Colors.green.shade200 : Colors.orange.shade200,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _allSplitsPaid ? Icons.check_circle : Icons.pending,
                    color: _allSplitsPaid ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _allSplitsPaid 
                          ? 'All payments received! Ready to complete order.'
                          : 'Waiting for ${_splitPayments.where((s) => !s['paid']).length} more payment(s)',
                      style: TextStyle(
                        color: _allSplitsPaid ? Colors.green.shade700 : Colors.orange.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isTotal = false, bool isDiscount = false, bool isGratuity = false}) {
    final textStyle = isTotal 
        ? Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : Theme.of(context).textTheme.bodyMedium;
    
    final amountStyle = isTotal
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          )
        : isDiscount
            ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.red.shade600,
                fontWeight: FontWeight.w500,
              )
            : isGratuity
                ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  )
                : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: textStyle),
          Text('\$${amount.toStringAsFixed(2)}', style: amountStyle),
        ],
      ),
    );
  }

  // Logging helper methods for comprehensive audit trail
  void _logPaymentProcessed(Order order, double amount, String paymentMethod) {
    try {
      final orderLogService = Provider.of<OrderLogService>(context, listen: false);
      orderLogService.logPaymentProcessed(
        order,
        amount,
        paymentMethod,
        widget.user.id,
      );
    } catch (e) {
      debugPrint('Failed to log payment processing: $e');
    }
  }

  void _logOrderCompleted(Order order) {
    try {
      final orderLogService = Provider.of<OrderLogService>(context, listen: false);
      orderLogService.logOrderCompleted(
        order,
        widget.user.id,
      );
    } catch (e) {
      debugPrint('Failed to log order completion: $e');
    }
  }
} 