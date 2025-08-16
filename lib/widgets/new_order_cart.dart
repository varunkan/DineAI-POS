import 'package:flutter/material.dart';
import '../models/order.dart';

/// A reusable widget that displays the order cart with items and totals.
/// 
/// This widget shows the current order items, allows quantity updates,
/// and displays order totals with a save button.
class NewOrderCart extends StatelessWidget {
  final Order order;
  final Function(OrderItem, int) onUpdateQuantity;
  final VoidCallback onSave;
  final bool isLoading;
  final String? saveButtonText;

  const NewOrderCart({
    super.key,
    required this.order,
    required this.onUpdateQuantity,
    required this.onSave,
    this.isLoading = false,
    this.saveButtonText,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildCartBody(context),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  /// Builds the main cart body with items or empty state.
  Widget _buildCartBody(BuildContext context) {
    if (order.items.isEmpty) {
      return _buildEmptyCart(context);
    }
    
    return ListView.builder(
      itemCount: order.items.length,
      padding: const EdgeInsets.all(16.0),
      itemBuilder: (context, index) {
        final item = order.items[index];
        return _buildCartItem(context, item);
      },
    );
  }

  /// Builds the empty cart state.
  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Cart is empty',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add items from the right-hand menu',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds an individual cart item with quantity controls.
  Widget _buildCartItem(BuildContext context, OrderItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.menuItem.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.menuItem.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.menuItem.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '\$${item.totalPrice.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            _buildQuantityControls(context, item),
          ],
        ),
      ),
    );
  }

  /// Builds the quantity control buttons for a cart item.
  Widget _buildQuantityControls(BuildContext context, OrderItem item) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => _updateQuantity(item, item.quantity - 1),
          color: Colors.red.shade600,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            '${item.quantity}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => _updateQuantity(item, item.quantity + 1),
          color: Colors.green.shade600,
        ),
      ],
    );
  }

  /// Updates the quantity of an item, removing it if quantity becomes 0.
  void _updateQuantity(OrderItem item, int newQuantity) {
    if (newQuantity <= 0) {
      onUpdateQuantity(item, 0);
    } else {
      onUpdateQuantity(item, newQuantity);
    }
  }

  /// Builds the bottom bar with order totals and save button.
  Widget _buildBottomBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildOrderTotals(context),
              const SizedBox(height: 16),
              _buildSaveButton(context),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the order totals section.
  Widget _buildOrderTotals(BuildContext context) {
    return Column(
      children: [
        _buildTotalRow(context, 'Subtotal', order.subtotal),
        if (order.taxAmount > 0) ...[
          const SizedBox(height: 8),
          _buildTotalRow(context, 'Tax', order.taxAmount),
        ],
        if (order.tipAmount > 0) ...[
          const SizedBox(height: 8),
          _buildTotalRow(context, 'Tip', order.tipAmount),
        ],
        const Divider(height: 24),
        _buildTotalRow(
          context, 
          'Total', 
          order.totalAmount,
          isTotal: true,
        ),
      ],
    );
  }

  /// Builds a single total row.
  Widget _buildTotalRow(
    BuildContext context, 
    String label, 
    double amount, {
    bool isTotal = false,
  }) {
    final textStyle = isTotal 
        ? Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          )
        : Theme.of(context).textTheme.bodyMedium;
    
    final amountStyle = isTotal
        ? Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).primaryColor,
          )
        : Theme.of(context).textTheme.bodyMedium;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: textStyle),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: amountStyle,
        ),
      ],
    );
  }

  /// Builds the save button.
  Widget _buildSaveButton(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onSave,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              saveButtonText ?? 'Save Order',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
    );
  }
} 