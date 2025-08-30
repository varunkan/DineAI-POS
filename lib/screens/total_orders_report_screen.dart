import 'package:flutter/material.dart';
import '../models/order.dart';

class TotalOrdersReportScreen extends StatelessWidget {
  final List<Order> orders;

  const TotalOrdersReportScreen({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    final completed = orders.where((o) => o.isCompleted).toList()
      ..sort((a, b) => (b.completedTime ?? b.orderTime).compareTo(a.completedTime ?? a.orderTime));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Total Orders Detail'),
      ),
      body: completed.isEmpty
          ? const Center(child: Text('No completed orders in selected period'))
          : ListView.builder(
              itemCount: completed.length,
              itemBuilder: (context, index) {
                final order = completed[index];
                final items = order.items;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 2,
                  child: ExpansionTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          order.orderNumber,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '\$${order.totalAmount.toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      'HST: \$${order.hstAmount.toStringAsFixed(2)}   Discount: \$${order.discountAmount.toStringAsFixed(2)}   Tips/Gratuity: \$${(order.tipAmount + order.gratuityAmount).toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (order.completedTime != null)
                              Text('Completed: ${order.completedTime}'),
                            const SizedBox(height: 8),
                            Text('Final Items:', style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 4),
                            ...items.map((it) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('${it.quantity} x ${it.menuItem.name}'),
                                  trailing: Text('\$${it.totalPrice.toStringAsFixed(2)}'),
                                  subtitle: _buildItemSubtitle(it),
                                )),
                            const Divider(),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _row('Subtotal after discount', '\$${order.subtotalAfterDiscount.toStringAsFixed(2)}'),
                                  _row('HST (calc)', '\$${order.calculatedHstAmount.toStringAsFixed(2)}'),
                                  _row('Tips + Gratuity', '\$${(order.tipAmount + order.gratuityAmount).toStringAsFixed(2)}'),
                                  const SizedBox(height: 4),
                                  Text('Total: \$${order.totalAmount.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget? _buildItemSubtitle(OrderItem it) {
    final parts = <String>[];
    if ((it.selectedVariant ?? '').isNotEmpty) parts.add('Variant: ${it.selectedVariant}');
    if (it.selectedModifiers.isNotEmpty) parts.add('Mods: ${it.selectedModifiers.join(', ')}');
    if ((it.notes ?? '').isNotEmpty) parts.add('Notes: ${it.notes}');
    if (parts.isEmpty) return null;
    return Text(parts.join('  •  '));
  }
} 