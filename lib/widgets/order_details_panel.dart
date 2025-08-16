import 'package:flutter/material.dart';
import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/models/table.dart' as restaurant_table;
import 'package:ai_pos_system/models/order.dart';

/// A reusable widget that displays order details and allows item management.
/// 
/// This widget shows order information, customer details, and provides
/// controls for updating quantities and removing items.
class OrderDetailsPanel extends StatelessWidget {
  final Order? order;
  final User user;
  final restaurant_table.Table? table;
  final int? numberOfPeople;
  final String orderType;
  final Function(OrderItem, int) onUpdateQuantity;
  final Function(OrderItem) onRemoveItem;
  final bool isLoading;
  final bool showActions;

  const OrderDetailsPanel({
    super.key,
    required this.order,
    required this.user,
    this.table,
    this.numberOfPeople,
    required this.orderType,
    required this.onUpdateQuantity,
    required this.onRemoveItem,
    this.isLoading = false,
    this.showActions = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          _buildContent(context),
        ],
      ),
    );
  }

  /// Builds the panel header with order information.
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOrderTypeInfo(context),
          const SizedBox(height: 12),
          _buildOrderDetails(context),
        ],
      ),
    );
  }

  /// Builds the order type and basic information.
  Widget _buildOrderTypeInfo(BuildContext context) {
    return Row(
      children: [
        Icon(
          _getOrderTypeIcon(),
          color: Colors.white,
          size: 24,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _getOrderTypeDisplayName(),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (order?.id != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '#${order!.id}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  /// Builds the order details section.
  Widget _buildOrderDetails(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildUserInfo(context),
        if (table != null) ...[
          const SizedBox(height: 8),
          _buildTableInfo(context),
        ],
        if (numberOfPeople != null) ...[
          const SizedBox(height: 8),
          _buildPeopleInfo(context),
        ],
      ],
    );
  }

  /// Builds the user information section.
  Widget _buildUserInfo(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.person,
          color: Colors.white.withValues(alpha: 0.8),
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          'Server: ${user.name}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  /// Builds the table information section.
  Widget _buildTableInfo(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.table_restaurant,
          color: Colors.white.withValues(alpha: 0.8),
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          'Table: ${table!.number}',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  /// Builds the number of people information section.
  Widget _buildPeopleInfo(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.people,
          color: Colors.white.withValues(alpha: 0.8),
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          'Guests: $numberOfPeople',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  /// Builds the main content area.
  Widget _buildContent(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (order == null || order!.items.isEmpty) {
      return _buildEmptyOrder(context);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildOrderItems(context),
        _buildOrderSummary(context),
      ],
    );
  }

  /// Builds the empty order state.
  Widget _buildEmptyOrder(BuildContext context) {
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
            'No items in order',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add items from the menu to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Builds the order items list.
  Widget _buildOrderItems(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: order!.items.length,
      itemBuilder: (context, index) {
        final item = order!.items[index];
        return _buildOrderItem(context, item);
      },
    );
  }

  /// Builds an individual order item.
  Widget _buildOrderItem(BuildContext context, OrderItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildItemHeader(context, item),
            const SizedBox(height: 8),
            _buildItemDetails(context, item),
            if (showActions) ...[
              const SizedBox(height: 8),
              _buildItemActions(context, item),
            ],
          ],
        ),
      ),
    );
  }

  /// Builds the item header with name and price.
  Widget _buildItemHeader(BuildContext context, OrderItem item) {
    return Row(
      children: [
        Expanded(
          child: Text(
            item.menuItem.name,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '\$${item.totalPrice.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Builds the item details section.
  Widget _buildItemDetails(BuildContext context, OrderItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.menuItem.description.isNotEmpty) ...[
          Text(
            item.menuItem.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
        ],
        Row(
          children: [
            Expanded(
              child: Text(
                'Quantity: ${item.quantity}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '\$${item.menuItem.price.toStringAsFixed(2)} each',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Builds the item action buttons.
  Widget _buildItemActions(BuildContext context, OrderItem item) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => _updateQuantity(item, item.quantity - 1),
          color: Colors.red.shade600,
          tooltip: 'Decrease quantity',
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
          tooltip: 'Increase quantity',
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _removeItem(item),
          color: Colors.red.shade600,
          tooltip: 'Remove item',
        ),
      ],
    );
  }

  /// Builds the order summary section.
  Widget _buildOrderSummary(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(
          top: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildSummaryRow(context, 'Subtotal', order!.subtotal),
          if (order!.taxAmount > 0) ...[
            const SizedBox(height: 4),
            _buildSummaryRow(context, 'Tax', order!.taxAmount),
          ],
          if (order!.hstAmount > 0) ...[
            const SizedBox(height: 4),
            _buildSummaryRow(context, 'HST', order!.hstAmount),
          ],
          if (order!.discountAmount > 0) ...[
            const SizedBox(height: 4),
            _buildSummaryRow(context, 'Discount', -order!.discountAmount, isDiscount: true),
          ],
          if (order!.tipAmount > 0) ...[
            const SizedBox(height: 4),
            _buildSummaryRow(context, 'Tip', order!.tipAmount),
          ],
          if (order!.gratuityAmount > 0) ...[
            const SizedBox(height: 4),
            _buildSummaryRow(context, 'Gratuity', order!.gratuityAmount),
          ],
          const Divider(height: 16),
          _buildSummaryRow(
            context, 
            'Total', 
            order!.totalAmount,
            isTotal: true,
          ),
        ],
      ),
    );
  }

  /// Builds a single summary row.
  Widget _buildSummaryRow(
    BuildContext context, 
    String label, 
    double amount, {
    bool isTotal = false,
    bool isDiscount = false,
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
        : isDiscount
            ? Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.red.shade600,
                fontWeight: FontWeight.w500,
              )
            : Theme.of(context).textTheme.bodyMedium;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label, 
            style: textStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: amountStyle,
        ),
      ],
    );
  }

  /// Updates the quantity of an item.
  void _updateQuantity(OrderItem item, int newQuantity) {
    if (newQuantity <= 0) {
      onRemoveItem(item);
    } else {
      onUpdateQuantity(item, newQuantity);
    }
  }

  /// Removes an item from the order.
  void _removeItem(OrderItem item) {
    onRemoveItem(item);
  }

  /// Gets the appropriate icon for the order type.
  IconData _getOrderTypeIcon() {
    switch (orderType.toLowerCase()) {
      case 'dine-in':
        return Icons.table_restaurant;
      case 'takeout':
        return Icons.takeout_dining;
      default:
        return Icons.receipt;
    }
  }

  /// Gets the display name for the order type.
  String _getOrderTypeDisplayName() {
    switch (orderType.toLowerCase()) {
      case 'dine-in':
        return 'Dine-In Order';
      case 'takeout':
        return 'Takeout Order';
      default:
        return 'Order';
    }
  }
} 