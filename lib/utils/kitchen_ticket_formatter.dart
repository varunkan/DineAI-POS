import 'package:intl/intl.dart';
import '../models/order.dart';

class KitchenTicketFormatter {
  static const String _separator = '-----------------------------------------';

  static List<String> buildLines({
    required Order order,
    required List<OrderItem> items,
    bool showAllItems = false,
    String? tableDisplay,
  }) {
    final List<String> lines = [];

    // Header
    lines.add(_separator);
    lines.add('KITCHEN RECEIPT');
    lines.add(_separator);
    lines.add('');

    // Order information
    lines.add('ORDER #${order.orderNumber}');
    lines.add('Date: ${DateFormat('MMM dd, yyyy').format(order.createdAt)}');
    lines.add('Time: ${DateFormat('HH:mm').format(order.createdAt)}');
    lines.add('Type: ${order.type.toString().split('.').last.toUpperCase()}');

    if (order.type == OrderType.dineIn && (order.tableId != null)) {
      final tableStr = tableDisplay ?? order.tableId!;
      lines.add('Table: $tableStr');
    }

    lines.add('Server: ${order.userId ?? 'N/A'}');
    if (order.type == OrderType.takeaway) {
      final String name = (order.customerName ?? '').trim();
      final String phone = (order.customerPhone ?? '').trim();
      if (name.isNotEmpty) {
        lines.add('Customer: $name');
      }
      if (phone.isNotEmpty) {
        lines.add('Phone: $phone');
      }
    }
    lines.add('');

    // Items header
    lines.add(_separator);
    lines.add('ITEMS TO PREPARE:');
    lines.add(_separator);

    // Items
    final List<OrderItem> targetItems = showAllItems ? order.items : items;
    for (final item in targetItems) {
      lines.add('');
      lines.add('${item.quantity}x ${item.menuItem.name}');

      if (item.menuItem.description.isNotEmpty) {
        lines.add('   ${item.menuItem.description}');
      }

      if (item.specialInstructions != null && item.specialInstructions!.isNotEmpty) {
        lines.add('   SPECIAL INSTRUCTIONS:');
        lines.add('      ${item.specialInstructions}');
      }

      if (item.selectedModifiers.isNotEmpty) {
        lines.add('   Modifiers:');
        for (final modifier in item.selectedModifiers) {
          lines.add('      - $modifier');
        }
      }

      if (item.selectedVariant != null) {
        lines.add('   Variant: ${item.selectedVariant!}');
      }

      if (item.menuItem.allergens.isNotEmpty) {
        lines.add('   ALLERGENS: ${item.menuItem.allergens.keys.join(', ')}');
      }

      if (item.menuItem.preparationTime > 0) {
        lines.add('   Prep Time: ${item.menuItem.preparationTime} min');
      }

      final List<String> dietaryInfo = [];
      if (item.menuItem.isVegetarian) dietaryInfo.add('VEG');
      if (item.menuItem.isVegan) dietaryInfo.add('VEGAN');
      if (item.menuItem.isGlutenFree) dietaryInfo.add('GLUTEN-FREE');

      final int? customSpiceLevel = item.customProperties['customSpiceLevel'];
      if (customSpiceLevel != null) {
        final spiceName = _getSpiceLevelName(customSpiceLevel);
        dietaryInfo.add('CUSTOM SPICE: $spiceName (${customSpiceLevel}/5)');
      } else if (item.menuItem.isSpicy) {
        dietaryInfo.add('SPICY (${item.menuItem.spiceLevel}/5)');
      }

      if (dietaryInfo.isNotEmpty) {
        lines.add('   ${dietaryInfo.join(' | ')}');
      }

      if (item.notes != null && item.notes!.isNotEmpty) {
        lines.add('   Notes: ${item.notes}');
      }
    }

    lines.add('');
    lines.add(_separator);
    lines.add('TOTAL ITEMS: ${targetItems.length}');

    if (order.notes.isNotEmpty) {
      lines.add('');
      lines.add('SPECIAL NOTES:');
      for (final note in order.notes) {
        lines.add(' - ${note.note}');
      }
    }

    lines.add('');
    lines.add('Sent to Kitchen: ${DateFormat('HH:mm:ss').format(DateTime.now())}');
    lines.add('Status: ${order.status.toString().split('.').last.toUpperCase()}');
    lines.add('');

    lines.add(_separator);
    lines.add('PREPARE WITH PRIORITY');
    lines.add(_separator);

    return lines;
  }

  static String _getSpiceLevelName(int level) {
    switch (level) {
      case 0:
        return 'No Spice';
      case 1:
        return 'Mild';
      case 2:
        return 'Medium';
      case 3:
        return 'Hot';
      case 4:
        return 'Extra Hot';
      case 5:
        return 'Extremely Hot';
      default:
        return 'Medium';
    }
  }
} 