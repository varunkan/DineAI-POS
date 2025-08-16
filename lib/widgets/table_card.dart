import 'package:flutter/material.dart';
import '../models/table.dart' as restaurant_table;

/// A reusable widget that displays table information in a card format.
/// 
/// This widget shows table details including status, capacity, and customer info.
class TableCard extends StatelessWidget {
  final restaurant_table.Table table;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isSelected;

  const TableCard({
    super.key,
    required this.table,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTableHeader(context),
                  if (table.customerName != null) _buildCustomerInfo(context),
                  const SizedBox(height: 8),
                  if (table.status == restaurant_table.TableStatus.available)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Start Order'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onPressed: onTap,
                      ),
                    ),
                  if (_hasPendingActions())
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 18),
                          const SizedBox(width: 4),
                          Text(
                            'Pending Action',
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (table.status == restaurant_table.TableStatus.occupied)
              _buildCloseButton(context),
          ],
        ),
      ),
    );
  }

  /// Builds the table header with icon, name, capacity, and status.
  Widget _buildTableHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.table_restaurant_outlined,
          size: 40,
          color: _getStatusIconColor(table.status),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                table.displayName,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Capacity: ${table.capacity}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              _buildStatusChip(context),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds the status chip with appropriate color.
  Widget _buildStatusChip(BuildContext context) {
    String label;
    switch (table.status) {
      case restaurant_table.TableStatus.available:
        label = 'Available';
        break;
      case restaurant_table.TableStatus.occupied:
        label = 'Occupied';
        break;
      case restaurant_table.TableStatus.reserved:
        label = 'Reserved';
        break;
      case restaurant_table.TableStatus.cleaning:
        label = 'Needs Cleaning';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(table.status),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getStatusBorderColor(table.status),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: _getStatusTextColor(table.status),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Builds the customer information section.
  Widget _buildCustomerInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              Icons.person,
              size: 16,
              color: Colors.grey.shade600,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                table.customerName!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (table.occupiedAt != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.access_time,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 4),
              Text(
                _formatDuration(table.occupancyDuration),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Builds the close button for occupied tables.
  Widget _buildCloseButton(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IconButton(
          icon: const Icon(
            Icons.close,
            color: Colors.white,
            size: 16,
          ),
          onPressed: onDelete,
          tooltip: 'Close Table',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(
            minWidth: 24,
            minHeight: 24,
          ),
        ),
      ),
    );
  }

  /// Gets the appropriate color for the table status.
  Color _getStatusColor(restaurant_table.TableStatus status) {
    switch (status) {
      case restaurant_table.TableStatus.available:
        return Colors.green.shade50;
      case restaurant_table.TableStatus.occupied:
        return Colors.orange.shade50;
      case restaurant_table.TableStatus.reserved:
        return Colors.blue.shade50;
      case restaurant_table.TableStatus.cleaning:
        return Colors.red.shade50;
    }
  }

  /// Gets the border color for the status chip.
  Color _getStatusBorderColor(restaurant_table.TableStatus status) {
    switch (status) {
      case restaurant_table.TableStatus.available:
        return Colors.green.shade300;
      case restaurant_table.TableStatus.occupied:
        return Colors.orange.shade300;
      case restaurant_table.TableStatus.reserved:
        return Colors.blue.shade300;
      case restaurant_table.TableStatus.cleaning:
        return Colors.red.shade300;
    }
  }

  /// Gets the text color for the status chip.
  Color _getStatusTextColor(restaurant_table.TableStatus status) {
    switch (status) {
      case restaurant_table.TableStatus.available:
        return Colors.green.shade700;
      case restaurant_table.TableStatus.occupied:
        return Colors.orange.shade700;
      case restaurant_table.TableStatus.reserved:
        return Colors.blue.shade700;
      case restaurant_table.TableStatus.cleaning:
        return Colors.red.shade700;
    }
  }

  /// Gets the icon color based on table status.
  Color _getStatusIconColor(restaurant_table.TableStatus status) {
    switch (status) {
      case restaurant_table.TableStatus.available:
        return Colors.green;
      case restaurant_table.TableStatus.occupied:
        return Colors.orange;
      case restaurant_table.TableStatus.reserved:
        return Colors.blue;
      case restaurant_table.TableStatus.cleaning:
        return Colors.red;
    }
  }

  /// Formats the duration since the table was occupied.
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  /// Placeholder for pending actions (to be implemented with real logic)
  bool _hasPendingActions() {
    // TODO: Replace with real logic (e.g., needs payment, order ready, etc.)
    return false;
  }
}

/// A specialized table card for displaying tables in a grid.
class GridTableCard extends StatelessWidget {
  final restaurant_table.Table table;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const GridTableCard({
    super.key,
    required this.table,
    this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return TableCard(
      table: table,
      onTap: onTap,
      onDelete: onDelete,
    );
  }
} 