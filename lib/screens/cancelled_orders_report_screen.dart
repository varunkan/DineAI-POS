import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import '../models/order_log.dart';
import '../services/order_log_service.dart';
import '../services/user_service.dart';
import '../models/user.dart';

class CancelledOrdersReportScreen extends StatefulWidget {
  final List<Order> orders;

  const CancelledOrdersReportScreen({super.key, required this.orders});

  @override
  State<CancelledOrdersReportScreen> createState() => _CancelledOrdersReportScreenState();
}

class _CancelledOrdersReportScreenState extends State<CancelledOrdersReportScreen> {
  late final List<Order> _cancelled;

  @override
  void initState() {
    super.initState();
    _cancelled = widget.orders.where((o) => o.isCancelled).toList()
      ..sort((a, b) => (b.updatedAt).compareTo(a.updatedAt));
  }

  Future<String> _resolveServerName(BuildContext context, Order order) async {
    try {
      final userService = Provider.of<UserService?>(context, listen: false);
      if (userService == null) return 'Unknown';
      final users = await userService.getUsers();
      final primaryId = order.userId ?? order.assignedTo;
      if (primaryId != null && primaryId.isNotEmpty) {
        final found = users.firstWhere(
          (u) => u.id == primaryId,
          orElse: () => users.firstWhere((u) => u.id == (order.assignedTo ?? ''), orElse: () => User(id: '', name: '', role: UserRole.server, pin: '0000')),
        );
        if (found.id.isNotEmpty) return found.name;
      }
      return 'Unknown';
    } catch (_) {
      return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cancelled Orders'),
      ),
      body: _cancelled.isEmpty
          ? const Center(child: Text('No cancelled orders in selected period'))
          : ListView.builder(
              itemCount: _cancelled.length,
              itemBuilder: (context, index) {
                final order = _cancelled[index];
                final sentItems = order.items.where((it) => it.sentToKitchen).toList();
                final notSentItems = order.items.where((it) => !it.sentToKitchen).toList();

                // Compute amounts for sent items, with HST proportional to the order's tax at the time
                final sentSubtotal = sentItems.fold<double>(0.0, (sum, it) => sum + it.totalPrice);
                final orderSubtotalAfterDiscount = order.subtotalAfterDiscount;
                final orderCalculatedHst = order.calculatedHstAmount;
                double sentHst;
                if (orderSubtotalAfterDiscount > 0) {
                  sentHst = orderCalculatedHst * (sentSubtotal / orderSubtotalAfterDiscount);
                } else {
                  // Fallback 13% if order subtotal isn't available
                  sentHst = sentSubtotal * 0.13;
                }
                final sentTotal = sentSubtotal + sentHst;

                final orderLogService = Provider.of<OrderLogService?>(context, listen: false);
                final logs = orderLogService?.getLogsForOrder(order.id) ?? const <OrderLog>[];
                final removedItems = logs
                    .where((l) => l.action == OrderLogAction.itemRemoved)
                    .map((l) => l.metadata['item_name']?.toString() ?? 'Item')
                    .toList();

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  elevation: 2,
                  child: ExpansionTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                order.orderNumber,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              FutureBuilder<String>(
                                future: _resolveServerName(context, order),
                                builder: (context, snapshot) {
                                  final serverName = snapshot.data ?? '...';
                                  return Text(
                                    'Server: $serverName',
                                    style: Theme.of(context).textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDateTime(order.updatedAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    subtitle: Text('Total items: ${order.itemCount.toInt()}'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Sent to kitchen (${sentItems.fold<int>(0, (s, it) => s + it.quantity)}):', style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 4),
                            // Totals for sent items (incl. HST)
                            if (sentItems.isEmpty)
                              const Text('— None —')
                            else ...[
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Subtotal: \$${sentSubtotal.toStringAsFixed(2)}'),
                                    Text('HST: \$${sentHst.toStringAsFixed(2)}'),
                                    Text('Total: \$${sentTotal.toStringAsFixed(2)}'),
                                  ],
                                ),
                              ),
                              ...sentItems.map((it) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text('${it.quantity} x ${it.menuItem.name}'),
                                    trailing: Text('\$${it.totalPrice.toStringAsFixed(2)}'),
                                  )),
                            ],
                            const SizedBox(height: 12),
                            Text('Not sent (${notSentItems.fold<int>(0, (s, it) => s + it.quantity)}):', style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 4),
                            if (notSentItems.isEmpty)
                              const Text('— None —')
                            else
                              ...notSentItems.map((it) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text('${it.quantity} x ${it.menuItem.name}'),
                                    trailing: Text('\$${it.totalPrice.toStringAsFixed(2)}'),
                                  )),
                            const SizedBox(height: 12),
                            Text('Removed before sending:', style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 4),
                            if (removedItems.isEmpty)
                              const Text('— None —')
                            else
                              ...removedItems.map((name) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(name),
                                  )),
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

  String _formatDateTime(DateTime dt) {
    return DateFormat('yyyy-MM-dd h:mm a').format(dt);
  }
} 