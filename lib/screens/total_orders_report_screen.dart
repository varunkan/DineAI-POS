import 'package:flutter/material.dart';
import '../models/order.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/user_service.dart';
import '../models/user.dart';

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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Date: ${_formatDateTime(order.completedTime ?? order.orderTime)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (order.type == OrderType.dineIn)
                          FutureBuilder<String>(
                            future: _resolveServerName(context, order),
                            builder: (context, snapshot) {
                              final server = snapshot.data;
                              if (server == null || server.isEmpty) return const SizedBox.shrink();
                              return Text(
                                'Server: $server',
                                style: Theme.of(context).textTheme.bodySmall,
                              );
                            },
                          ),
                        if (((order.customerName ?? '').isNotEmpty) || ((order.customerPhone ?? '').isNotEmpty))
                          Text(
                            'Customer: ${[order.customerName, order.customerPhone].where((e) => (e ?? '').isNotEmpty).join('  •  ')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        Text(
                          'HST: \$${order.hstAmount.toStringAsFixed(2)}   Discount: \$${order.discountAmount.toStringAsFixed(2)}   Tips/Gratuity: \$${(order.tipAmount + order.gratuityAmount).toStringAsFixed(2)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
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

  String _formatDateTime(DateTime dt) {
    return DateFormat('yyyy-MM-dd h:mm a').format(dt);
  }

  Future<String> _resolveServerName(BuildContext context, Order order) async {
    try {
      final userService = Provider.of<UserService?>(context, listen: false);
      if (userService == null) return '';
      final users = await userService.getUsers();
      final primaryId = order.userId ?? order.assignedTo;
      if (primaryId != null && primaryId.isNotEmpty) {
        final found = users.firstWhere(
          (u) => u.id == primaryId,
          orElse: () => users.firstWhere((u) => u.id == (order.assignedTo ?? ''), orElse: () => User(id: '', name: '', role: UserRole.server, pin: '0000')),
        );
        if (found.id.isNotEmpty) return found.name;
      }
      return '';
    } catch (_) {
      return '';
    }
  }
} 