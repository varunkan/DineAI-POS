import 'package:flutter/material.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../models/table.dart' as restaurant_table;
import '../widgets/back_button.dart';

class PrintPreviewScreen extends StatelessWidget {
  final Order order;
  final User user;
  final restaurant_table.Table? table;
  final String orderType;
  final bool isKitchenTicket;

  const PrintPreviewScreen({
    super.key,
    required this.order,
    required this.user,
    this.table,
    required this.orderType,
    this.isKitchenTicket = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isKitchenTicket ? 'Kitchen Ticket Preview' : 'Receipt Preview'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: <Widget>[
          const CustomBackButton(),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Print Preview Card
            Card(
              elevation: 4,
              child: Container(
                width: 300, // Standard receipt width
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeader(),
                    const SizedBox(height: 16),
                    
                    // Order Details
                    _buildOrderDetails(),
                    const SizedBox(height: 16),
                    
                    // Items List
                    _buildItemsList(),
                    const SizedBox(height: 16),
                    
                    // Totals
                    _buildTotals(),
                    const SizedBox(height: 16),
                    
                    // Footer
                    _buildFooter(),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context, true),
                  icon: const Icon(Icons.print),
                  label: const Text('Print'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'OH BOMBAY RESTAURANT',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 4),
        Text(
          'Authentic Indian Cuisine',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          '123 Main Street, City, State 12345',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 4),
        Text(
          'Phone: (555) 123-4567',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Divider(),
      ],
    );
  }

  Widget _buildOrderDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isKitchenTicket) ...[
          Text(
            'KITCHEN TICKET',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4),
        ],
        Text(
          'Order #: ${order.orderNumber}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 2),
        Text(
          'Time: ${_formatTime(order.orderTime)}',
          style: const TextStyle(fontSize: 11),
        ),
        SizedBox(height: 2),
        Text(
          'Type: ${orderType.toUpperCase()}',
          style: const TextStyle(fontSize: 11),
        ),
        if (table != null) ...[
          SizedBox(height: 2),
          Text(
            'Table: ${table!.number}',
            style: const TextStyle(fontSize: 11),
          ),
        ],
        if (order.customerName != null && order.customerName!.isNotEmpty) ...[
          SizedBox(height: 2),
          Text(
            'Customer: ${order.customerName}',
            style: const TextStyle(fontSize: 11),
          ),
        ],
        SizedBox(height: 8),
        Divider(),
      ],
    );
  }

  Widget _buildItemsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ITEMS:',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        ...order.items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.quantity}x ',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.menuItem.name,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (item.specialInstructions != null && 
                        item.specialInstructions!.isNotEmpty)
                      Text(
                        '  Note: ${item.specialInstructions}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade600,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                '\$${item.totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        )),
        SizedBox(height: 8),
        Divider(),
      ],
    );
  }

  Widget _buildTotals() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Subtotal:', style: TextStyle(fontSize: 11)),
            Text('\$${order.subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
          ],
        ),
        if (order.discountAmount > 0) ...[
          SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Discount:', style: TextStyle(fontSize: 11, color: Colors.red)),
              Text('-\$${order.discountAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: Colors.red)),
            ],
          ),
          SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal after Discount:', style: TextStyle(fontSize: 11)),
              Text('\$${order.subtotalAfterDiscount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
            ],
          ),
        ],
        SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('HST (13%):', style: TextStyle(fontSize: 11)),
            Text('\$${order.calculatedHstAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
          ],
        ),
        if (order.gratuityAmount > 0) ...[
          SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Gratuity:', style: TextStyle(fontSize: 11)),
              Text('\$${order.gratuityAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
            ],
          ),
        ],
        if (order.tipAmount > 0) ...[
          SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tip:', style: TextStyle(fontSize: 11)),
              Text('\$${order.tipAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11)),
            ],
          ),
        ],
        SizedBox(height: 4),
        Divider(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'TOTAL:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '\$${order.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Divider(),
      ],
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'Thank you for dining with us!',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 4),
        Text(
          'Please visit again',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 8),
        Text(
          'Server: ${user.name}',
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 4),
        Text(
          _formatDate(order.orderTime),
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
} 