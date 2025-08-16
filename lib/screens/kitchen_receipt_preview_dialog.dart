import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/order.dart';
import '../services/menu_service.dart';

class KitchenReceiptPreviewDialog extends StatelessWidget {
  final Order order;
  final String serverName;

  const KitchenReceiptPreviewDialog({
    super.key,
    required this.order,
    required this.serverName,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
    
    if (isPhone) {
      // Mobile: Full-screen dialog with optimized layout
      return Dialog.fullscreen(
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.orange.shade600,
            foregroundColor: Colors.white,
            title: const Text(
              'Kitchen Receipt Preview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  '80mm Thermal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              // Receipt Preview with Mobile Optimized Scrolling
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _buildMobileReceiptContent(context),
                    ),
                  ),
                ),
              ),
              
              // Mobile Action Buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text(
                          'Cancel',
                          style: TextStyle(fontSize: 14),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(true),
                        icon: const Icon(Icons.print, size: 18),
                        label: const Text(
                          'Send to Kitchen',
                          style: TextStyle(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
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
    } else {
      // Tablet/Desktop: Original dialog layout (unchanged)
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade600,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.restaurant,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Kitchen Receipt Preview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '80mm Thermal',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Receipt Preview
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: SingleChildScrollView(
                    child: Container(
                      // Increased from 384 to 1150 (about 3x for larger text)
                      width: 1150, 
                      padding: const EdgeInsets.all(48), // Increased padding from 16 to 48 (16*3)
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _buildReceiptContent(context),
                    ),
                  ),
                ),
              ),
              
              // Action Buttons
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
                        onPressed: () => Navigator.of(context).pop(false),
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey.shade700,
                          side: BorderSide(color: Colors.grey.shade400),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(true),
                        icon: const Icon(Icons.print),
                        label: const Text('Send to Kitchen & Print'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
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

  Widget _buildReceiptContent(BuildContext context) {
    final menuService = Provider.of<MenuService>(context, listen: false);
    final now = DateTime.now();
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('MMM dd, yyyy');
    
    // Calculate estimated ready time (add 20 minutes)
    final estimatedReadyTime = now.add(const Duration(minutes: 20));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Restaurant Header
        _buildReceiptLine('================================', bold: true, fontSize: 36), // 12*3
        const SizedBox(height: 24), // 8*3
        _buildReceiptLine('${_getOrderTypeDisplay(order.type)} ORDER', bold: true, fontSize: 48), // 16*3 - Dynamic order type
        const SizedBox(height: 24), // 8*3
        _buildReceiptLine('================================', bold: true, fontSize: 36), // 12*3
        const SizedBox(height: 48), // 16*3
        
        // Order Details Header
        _buildReceiptLine('ORDER #${order.orderNumber}', bold: true, fontSize: 60), // 20*3
        const SizedBox(height: 36), // 12*3
        
        // Server & Time Info
        _buildReceiptRow('Server:', serverName, bold: true, fontSize: 36), // 12*3
        _buildReceiptRow('Date:', dateFormat.format(now), fontSize: 36), // 12*3
        _buildReceiptRow('Time:', timeFormat.format(now), fontSize: 36), // 12*3
        _buildReceiptRow('Ready by:', timeFormat.format(estimatedReadyTime), 
            valueStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 36, fontFamily: 'monospace')), // 12*3
        
        const SizedBox(height: 48), // 16*3
        _buildReceiptLine('================================', bold: true, fontSize: 36), // 12*3
        const SizedBox(height: 48), // 16*3
        
        // Items grouped by category
        FutureBuilder<Widget>(
          future: _buildGroupedItems(context, menuService),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return snapshot.data!;
            }
            return const CircularProgressIndicator();
          },
        ),
        
        const SizedBox(height: 48), // 16*3
        _buildReceiptLine('================================', bold: true, fontSize: 36), // 12*3
        
        // Special Instructions
        if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty) ...[
          const SizedBox(height: 48), // 16*3
          _buildReceiptLine('SPECIAL INSTRUCTIONS:', bold: true, fontSize: 42), // 14*3
          const SizedBox(height: 24), // 8*3
          _buildReceiptLine(order.specialInstructions!, bold: true, fontSize: 36), // 12*3, made bold
          const SizedBox(height: 48), // 16*3
          _buildReceiptLine('================================', fontSize: 36), // 12*3
        ],
      ],
    );
  }

  /// Mobile-optimized receipt content with smaller fonts for display only
  Widget _buildMobileReceiptContent(BuildContext context) {
    final menuService = Provider.of<MenuService>(context, listen: false);
    final now = DateTime.now();
    final timeFormat = DateFormat('HH:mm');
    final dateFormat = DateFormat('MMM dd, yyyy');
    
    // Calculate estimated ready time (add 20 minutes)
    final estimatedReadyTime = now.add(const Duration(minutes: 20));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Restaurant Header
        _buildMobileReceiptLine('================================', bold: true, fontSize: 14),
        const SizedBox(height: 8),
        _buildMobileReceiptLine('${_getOrderTypeDisplay(order.type)} ORDER', bold: true, fontSize: 16),
        const SizedBox(height: 8),
        _buildMobileReceiptLine('================================', bold: true, fontSize: 14),
        const SizedBox(height: 16),
        
        // Order Details Header
        _buildMobileReceiptLine('ORDER #${order.orderNumber}', bold: true, fontSize: 20),
        const SizedBox(height: 12),
        
        // Server & Time Info
        _buildMobileReceiptRow('Server:', serverName, bold: true, fontSize: 14),
        _buildMobileReceiptRow('Date:', dateFormat.format(now), fontSize: 14),
        _buildMobileReceiptRow('Time:', timeFormat.format(now), fontSize: 14),
        _buildMobileReceiptRow('Ready by:', timeFormat.format(estimatedReadyTime), 
            valueStyle: TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 14, fontFamily: 'monospace')),
        
        const SizedBox(height: 16),
        _buildMobileReceiptLine('================================', bold: true, fontSize: 14),
        const SizedBox(height: 16),
        
        // Items grouped by category
        FutureBuilder<Widget>(
          future: _buildMobileGroupedItems(context, menuService),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return snapshot.data!;
            }
            return const CircularProgressIndicator();
          },
        ),
        
        const SizedBox(height: 16),
        _buildMobileReceiptLine('================================', bold: true, fontSize: 14),
        
        // Special Instructions
        if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildMobileReceiptLine('SPECIAL INSTRUCTIONS:', bold: true, fontSize: 15),
          const SizedBox(height: 8),
          _buildMobileReceiptLine(order.specialInstructions!, bold: true, fontSize: 14),
          const SizedBox(height: 16),
          _buildMobileReceiptLine('================================', fontSize: 14),
        ],
      ],
    );
  }

  Future<Widget> _buildGroupedItems(BuildContext context, MenuService menuService) async {
    // Filter items that haven't been sent to kitchen yet
    final newItems = order.items.where((item) => !item.sentToKitchen).toList();
    
    // If no new items, show appropriate message
    if (newItems.isEmpty) {
      return Column(
        children: [
          _buildReceiptLine('NO NEW ITEMS TO PREPARE', bold: true, fontSize: 48, color: Colors.orange.shade700),
          const SizedBox(height: 24),
          _buildReceiptLine('All items have already been sent to kitchen', bold: true, fontSize: 33, color: Colors.grey.shade600),
          const SizedBox(height: 48),
        ],
      );
    }
    
    // Group new items by category
    final Map<String, List<OrderItem>> groupedItems = {};
    
    for (final item in newItems) {
      final categoryId = item.menuItem.categoryId;
      final category = await menuService.getCategoryById(categoryId);
      final categoryName = category?.name ?? 'Other Items';
      
      if (!groupedItems.containsKey(categoryName)) {
        groupedItems[categoryName] = [];
      }
      groupedItems[categoryName]!.add(item);
    }

    // Build UI for each category in specific order
    final List<Widget> categoryWidgets = [];
    
    // Get sorted category names based on predefined order
    final sortedCategoryNames = _getSortedCategoryNames(groupedItems.keys.toList());
    
    for (final categoryName in sortedCategoryNames) {
      final items = groupedItems[categoryName]!;
      
      // Skip empty categories (safety check)
      if (items.isEmpty) continue;
      
      // Category header
      categoryWidgets.add(_buildReceiptLine(categoryName.toUpperCase(), bold: true, fontSize: 42)); // 14*3
      categoryWidgets.add(const SizedBox(height: 24)); // 8*3
      categoryWidgets.add(_buildReceiptLine('--------------------------------', bold: true, fontSize: 30)); // 10*3, made bold
      categoryWidgets.add(const SizedBox(height: 24)); // 8*3
      
      // Items in this category
      for (final item in items) {
        categoryWidgets.add(_buildItemDetails(item));
        categoryWidgets.add(const SizedBox(height: 36)); // 12*3
      }
      
      categoryWidgets.add(const SizedBox(height: 24)); // 8*3
    }
    
    return Column(children: categoryWidgets);
  }

  /// Mobile grouped items builder with smaller fonts
  Future<Widget> _buildMobileGroupedItems(BuildContext context, MenuService menuService) async {
    // Filter items that haven't been sent to kitchen yet
    final newItems = order.items.where((item) => !item.sentToKitchen).toList();
    
    // If no new items, show appropriate message
    if (newItems.isEmpty) {
      return Column(
        children: [
          _buildMobileReceiptLine('NO NEW ITEMS TO PREPARE', bold: true, fontSize: 16, color: Colors.orange.shade700),
          const SizedBox(height: 8),
          _buildMobileReceiptLine('All items have already been sent to kitchen', bold: true, fontSize: 12, color: Colors.grey.shade600),
          const SizedBox(height: 16),
        ],
      );
    }
    
    // Group new items by category
    final Map<String, List<OrderItem>> groupedItems = {};
    
    for (final item in newItems) {
      final categoryId = item.menuItem.categoryId;
      final category = await menuService.getCategoryById(categoryId);
      final categoryName = category?.name ?? 'Other Items';
      
      if (!groupedItems.containsKey(categoryName)) {
        groupedItems[categoryName] = [];
      }
      groupedItems[categoryName]!.add(item);
    }

    // Build UI for each category in specific order
    final List<Widget> categoryWidgets = [];
    
    // Get sorted category names based on predefined order
    final sortedCategoryNames = _getSortedCategoryNames(groupedItems.keys.toList());
    
    for (final categoryName in sortedCategoryNames) {
      final items = groupedItems[categoryName]!;
      
      // Category header
      categoryWidgets.add(_buildMobileReceiptLine('--- $categoryName ---', bold: true, fontSize: 15));
      categoryWidgets.add(const SizedBox(height: 8));
      
      // Category items
      for (final item in items) {
        categoryWidgets.add(_buildMobileItemLine(item));
        
        // Add special instructions if present
        if (item.specialInstructions != null && item.specialInstructions!.isNotEmpty) {
          categoryWidgets.add(const SizedBox(height: 2));
          categoryWidgets.add(
            Padding(
              padding: const EdgeInsets.only(left: 20),
              child: _buildMobileReceiptLine('* ${item.specialInstructions}', fontSize: 12, color: Colors.grey.shade700),
            ),
          );
        }
        
        categoryWidgets.add(const SizedBox(height: 4));
      }
      
      categoryWidgets.add(const SizedBox(height: 12));
    }
    
    return Column(children: categoryWidgets);
  }

  Widget _buildItemDetails(OrderItem item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Item name and quantity
        _buildReceiptRow('${item.quantity}x', item.menuItem.name, bold: true, fontSize: 36), // 12*3
        
        // Special instructions
        if (item.specialInstructions != null && item.specialInstructions!.isNotEmpty) ...[
          const SizedBox(height: 12), // 4*3
          _buildReceiptLine('  → ${item.specialInstructions!}', fontSize: 33, bold: true, // 11*3, made bold
              color: Colors.blue.shade700),
        ],
        
        // Spice level
        if (item.notes != null && item.notes!.contains('Spice:')) ...[
          const SizedBox(height: 12), // 4*3
          _buildReceiptLine('  → ${item.notes!}', fontSize: 33, bold: true, // 11*3, made bold
              color: Colors.red.shade700),
        ],
      ],
    );
  }

  /// Mobile item line builder with smaller fonts
  Widget _buildMobileItemLine(OrderItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          // Quantity
          SizedBox(
            width: 30,
            child: Text(
              '${item.quantity}x',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Item name
          Expanded(
            child: Text(
              item.menuItem.name,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptLine(String text, {
    bool bold = true, // Changed default to true
    double fontSize = 36, // Changed default from 12 to 36 (12*3)
    Color? color,
    TextAlign textAlign = TextAlign.center,
  }) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        text,
        textAlign: textAlign,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color ?? Colors.black,
          fontFamily: 'monospace', // Monospace for thermal printer effect
        ),
      ),
    );
  }

  /// Mobile receipt line builder with smaller fonts
  Widget _buildMobileReceiptLine(String text, {bool bold = false, double fontSize = 12, Color? color}) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'monospace',
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        color: color ?? Colors.black,
        height: 1.2,
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, {
    bool bold = true, // Changed default to true
    TextStyle? valueStyle,
    double fontSize = 36, // Changed default from 12 to 36 (12*3)
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontFamily: 'monospace',
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: valueStyle ?? TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }

  /// Mobile receipt row builder with smaller fonts
  Widget _buildMobileReceiptRow(String label, String value, {bool bold = false, double fontSize = 12, TextStyle? valueStyle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: valueStyle ?? TextStyle(
              fontFamily: 'monospace',
              fontSize: fontSize,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  String _getTableNumber(String tableId) {
    // Extract table number from tableId
    final match = RegExp(r'table_(\d+)').firstMatch(tableId);
    if (match != null) {
      return match.group(1)!;
    }
    final numbers = RegExp(r'\d+').allMatches(tableId);
    if (numbers.isNotEmpty) {
      return numbers.first.group(0)!;
    }
    return tableId.replaceAll('table_', '').replaceAll('_', ' ').toUpperCase();
  }

  String _getOrderTypeDisplay(OrderType type) {
    switch (type) {
      case OrderType.dineIn:
        return 'DINE IN';
      case OrderType.takeaway:
        return 'TAKEAWAY';
      case OrderType.delivery:
        return 'DELIVERY';
      case OrderType.catering:
        return 'CATERING';
    }
  }

  List<String> _getSortedCategoryNames(List<String> categoryNames) {
    // Define the preferred order for categories
    final categoryOrder = [
      'starters', 'starter', 'appetizers', 'appetizer', 'starter-veg', 'starter-non-veg',
      'main course', 'main', 'curry', 'curries', 'main-veg', 'main-non-veg',
      'breads', 'bread', 'naan', 'roti', 'paratha',
      'rice', 'rice items', 'biryani', 'fried rice',
      'desserts', 'dessert', 'sweets', 'sweet',
      'beverages', 'beverage', 'drinks', 'drink', 'juice', 'lassi',
      'sides', 'side dishes', 'extras',
      'other items', 'other', 'miscellaneous'
    ];
    
    // Function to get priority index for a category (lower number = higher priority)
    int getPriority(String categoryName) {
      final lowerCaseName = categoryName.toLowerCase();
      for (int i = 0; i < categoryOrder.length; i++) {
        if (lowerCaseName.contains(categoryOrder[i]) || categoryOrder[i].contains(lowerCaseName)) {
          return i;
        }
      }
      return categoryOrder.length; // Unknown categories go to the end
    }
    
    // Sort categories based on predefined order
    final sortedNames = List<String>.from(categoryNames);
    sortedNames.sort((a, b) {
      final priorityA = getPriority(a);
      final priorityB = getPriority(b);
      
      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }
      
      // If same priority, sort alphabetically
      return a.compareTo(b);
    });
    
    return sortedNames;
  }
} 