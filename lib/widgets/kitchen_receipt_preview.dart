import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../services/table_service.dart';

class KitchenReceiptPreview extends StatelessWidget {
  final Order order;
  final List<OrderItem> newItems;
  final bool showAllItems;

  const KitchenReceiptPreview({
    super.key,
    required this.order,
    required this.newItems,
    this.showAllItems = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340, // Approximate width for 80mm thermal printer (80mm ≈ 340px)
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Column(
              children: [
                Text(
                  '🍽️ KITCHEN RECEIPT',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '80mm Thermal Printer Preview',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          
          // Receipt content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Restaurant header
                _buildCenteredText('═══════════════════════════════════════'),
                const SizedBox(height: 8),
                _buildCenteredText('🏪 RESTAURANT KITCHEN', fontSize: 14, bold: true),
                _buildCenteredText('Kitchen Order Receipt', fontSize: 12),
                const SizedBox(height: 8),
                _buildCenteredText('═══════════════════════════════════════'),
                
                const SizedBox(height: 16),
                
                // Order information
                _buildBoldText('ORDER #${order.orderNumber}'),
                const SizedBox(height: 4),
                _buildText('Date: ${DateFormat('MMM dd, yyyy').format(order.createdAt)}'),
                _buildText('Time: ${DateFormat('HH:mm').format(order.createdAt)}'),
                _buildText('Type: ${order.type.toString().split('.').last.toUpperCase()}'),
                
                if (order.type == OrderType.dineIn && order.tableId != null)
                  Consumer<TableService>(
                    builder: (context, tableService, child) {
                      final table = tableService.getTableById(order.tableId!);
                      final tableDisplay = table?.number.toString() ?? order.tableId!;
                      return _buildText('Table: $tableDisplay');
                    },
                  ),
                
                _buildText('Server: ${order.userId ?? 'N/A'}'),
                
                const SizedBox(height: 16),
                
                // Items separator
                _buildText('─────────────────────────────────────────'),
                _buildBoldText('ITEMS TO PREPARE:'),
                _buildText('─────────────────────────────────────────'),
                
                const SizedBox(height: 8),
                
                // Items list
                ...(!showAllItems ? newItems : order.items).map((item) => _buildItemSection(item)).toList(),
                
                const SizedBox(height: 16),
                
                // Footer
                _buildText('─────────────────────────────────────────'),
                _buildBoldText('TOTAL ITEMS: ${(!showAllItems ? newItems : order.items).length}'),
                
                if (order.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildBoldText('📝 SPECIAL NOTES:'),
                  ...order.notes.map((note) => _buildText('• ${note.note}', indent: 2)).toList(),
                ],
                
                const SizedBox(height: 16),
                
                // Time stamps
                _buildText('Sent to Kitchen: ${DateFormat('HH:mm:ss').format(DateTime.now())}'),
                _buildText('Status: ${order.status.toString().split('.').last.toUpperCase()}'),
                
                const SizedBox(height: 16),
                
                // Bottom separator
                _buildCenteredText('═══════════════════════════════════════'),
                _buildCenteredText('⏰ PREPARE WITH PRIORITY ⏰', fontSize: 12, bold: true),
                _buildCenteredText('═══════════════════════════════════════'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemSection(OrderItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item name and quantity
          Row(
            children: [
              Expanded(
                child: _buildBoldText(
                  '${item.quantity}x ${item.menuItem.name}',
                  fontSize: 13,
                ),
              ),
              if (item.sentToKitchen)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'SENT',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
            ],
          ),
          
          // Item details
          if (item.menuItem.description.isNotEmpty)
            _buildText('   ${item.menuItem.description}', fontSize: 11),
          
          // Special instructions
          if (item.specialInstructions != null && item.specialInstructions!.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.yellow.shade50,
                border: Border.all(color: Colors.orange.shade300),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBoldText('⚠️ SPECIAL INSTRUCTIONS:', fontSize: 11),
                  const SizedBox(height: 2),
                  _buildText('   ${item.specialInstructions}', fontSize: 11),
                ],
              ),
            ),
          
          // Modifiers
          if (item.selectedModifiers.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildBoldText('   Modifiers:', fontSize: 11),
            ...item.selectedModifiers.map((modifier) => 
              _buildText('     • $modifier', fontSize: 10)
            ).toList(),
          ],
          
          // Variants
          if (item.selectedVariant != null) ...[
            const SizedBox(height: 4),
            _buildText('   Variant: ${item.selectedVariant!}', fontSize: 11),
          ],
          
          // Allergen info
          if (item.menuItem.allergens.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildText('   ⚠️ ALLERGENS: ${item.menuItem.allergens.keys.join(', ')}', fontSize: 10),
          ],
          
          // Preparation time
          if (item.menuItem.preparationTime > 0) ...[
            const SizedBox(height: 4),
            _buildText('   ⏱️ Prep Time: ${item.menuItem.preparationTime} min', fontSize: 10),
          ],
          
          // Dietary info
          ...() {
            List<String> dietaryInfo = [];
            if (item.menuItem.isVegetarian) dietaryInfo.add('🥬 VEG');
            if (item.menuItem.isVegan) dietaryInfo.add('🌱 VEGAN');
            if (item.menuItem.isGlutenFree) dietaryInfo.add('🌾 GLUTEN-FREE');
            
            // Handle custom spice level
            final int? customSpiceLevel = item.customProperties['customSpiceLevel'];
            if (customSpiceLevel != null) {
              dietaryInfo.add('🌶️ CUSTOM SPICE: ${_getSpiceLevelName(customSpiceLevel)} (${customSpiceLevel}/5)');
            } else if (item.menuItem.isSpicy) {
              dietaryInfo.add('🌶️ SPICY (${item.menuItem.spiceLevel}/5)');
            }
            
            if (dietaryInfo.isNotEmpty) {
              return [
                const SizedBox(height: 4),
                _buildText('   ${dietaryInfo.join(' • ')}', fontSize: 10),
              ];
            } else {
              return <Widget>[];
            }
          }(),
          
          // Item notes
          if (item.notes != null && item.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            _buildText('   📝 Notes: ${item.notes}', fontSize: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildCenteredText(String text, {double fontSize = 12, bool bold = false}) {
    return Center(
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.w900 : FontWeight.normal,
          fontFamily: 'Courier New', // Monospace font for thermal printer feel
        ),
      ),
    );
  }

  Widget _buildBoldText(String text, {double fontSize = 12}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        fontFamily: 'Courier New',
        height: 1.2,
      ),
    );
  }

  Widget _buildText(String text, {double fontSize = 12, int indent = 0}) {
    return Text(
      '${'  ' * indent}$text',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.normal,
        fontFamily: 'Courier New',
        height: 1.2,
      ),
    );
  }

  String _getSpiceLevelName(int level) {
    switch (level) {
      case 0: return 'No Spice';
      case 1: return 'Mild';
      case 2: return 'Medium';
      case 3: return 'Hot';
      case 4: return 'Extra Hot';
      case 5: return 'Extremely Hot';
      default: return 'Medium';
    }
  }
}

class KitchenReceiptDialog extends StatelessWidget {
  final Order order;
  final List<OrderItem> newItems;
  final VoidCallback? onPrintAgain;
  final VoidCallback? onClose;

  const KitchenReceiptDialog({
    super.key,
    required this.order,
    required this.newItems,
    this.onPrintAgain,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Kitchen Receipt Generated!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Order #${order.orderNumber} sent to kitchen',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            
            // Receipt preview
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Kitchen Receipt Preview',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    KitchenReceiptPreview(
                      order: order,
                      newItems: newItems,
                    ),
                  ],
                ),
              ),
            ),
            
            // Action buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onPrintAgain,
                      icon: const Icon(Icons.print),
                      label: const Text('Print Again'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
                        side: BorderSide(color: Colors.blue.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onClose ?? () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.done),
                      label: const Text('Done'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
} 