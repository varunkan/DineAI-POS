import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/printer_type_mapping.dart';
import '../models/printer_configuration.dart';
import '../models/category.dart';
import '../models/menu_item.dart';
import '../services/printer_type_management_service.dart';
import '../services/printing_service.dart';
import '../services/database_service.dart';
import '../services/firebase_auth_service.dart';
import '../widgets/action_card.dart';
import '../widgets/confirmation_dialog.dart';

/// Screen for managing printer type configurations and assignments
class PrinterTypeManagementScreen extends StatefulWidget {
  const PrinterTypeManagementScreen({super.key});

  @override
  State<PrinterTypeManagementScreen> createState() => _PrinterTypeManagementScreenState();
}

class _PrinterTypeManagementScreenState extends State<PrinterTypeManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final PrinterTypeManagementService _printerTypeService = PrinterTypeManagementService.instance;
  final DatabaseService _databaseService = DatabaseService();
  final FirebaseAuthService _firebaseService = FirebaseAuthService.instance;

  List<PrinterConfiguration> _availablePrinters = [];
  List<Category> _availableCategories = [];
  List<MenuItem> _availableItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Initialize data for the screen
  Future<void> _initializeData() async {
    try {
      setState(() => _isLoading = true);
      
      // Initialize printer type service
      await _printerTypeService.initialize();
      
      // Load available data
      await _loadAvailableData();
      
      // Create default configurations if none exist
      if (_printerTypeService.printerTypeConfigs.isEmpty) {
        await _createDefaultConfigurations();
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorSnackBar('Error initializing: $e');
    }
  }

  /// Load available printers, categories, and items
  Future<void> _loadAvailableData() async {
    try {
      // Load printers
      final printerData = await _databaseService.getAllPrinterConfigurations();
      _availablePrinters = printerData.map((data) => PrinterConfiguration.fromJson(data)).toList();
      
      // Load categories
      final categoryData = await _databaseService.getAllCategories();
      _availableCategories = categoryData.map((data) => Category.fromJson(data)).toList();
      
      // Load menu items
      final itemData = await _databaseService.getAllMenuItems();
      _availableItems = itemData.map((data) => MenuItem.fromJson(data)).toList();
      
      debugPrint('📊 Loaded ${_availablePrinters.length} printers, ${_availableCategories.length} categories, ${_availableItems.length} items');
    } catch (e) {
      debugPrint('❌ Error loading available data: $e');
    }
  }

  /// Create default printer type configurations
  Future<void> _createDefaultConfigurations() async {
    try {
      final restaurantId = await _firebaseService.getCurrentRestaurantId();
      final userId = await _firebaseService.getCurrentUserId();
      
      if (restaurantId != null && userId != null) {
        await _printerTypeService.createDefaultConfigurations(restaurantId, userId);
        _showSuccessSnackBar('Default printer type configurations created');
      }
    } catch (e) {
      _showErrorSnackBar('Error creating default configurations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🖨️ Printer Type Management'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '🧾 Receipt', icon: const Icon(Icons.receipt)),
            Tab(text: '🔥 Tandoor', icon: const Icon(Icons.local_fire_department)),
            Tab(text: '🍛 Curry', icon: const Icon(Icons.restaurant)),
            Tab(text: '📋 Expo', icon: const Icon(Icons.assignment)),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPrinterTypeTab(PrinterTypeCategory.receipt),
                _buildPrinterTypeTab(PrinterTypeCategory.tandoor),
                _buildPrinterTypeTab(PrinterTypeCategory.curry),
                _buildPrinterTypeTab(PrinterTypeCategory.expo),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showQuickAssignmentDialog,
        icon: const Icon(Icons.add),
        label: const Text('Quick Assign'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  /// Build tab for a specific printer type
  Widget _buildPrinterTypeTab(PrinterTypeCategory printerType) {
    final config = _printerTypeService.getAllPrinterTypes()[printerType];
    
    if (config == null) {
      return const Center(child: Text('No configuration found'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildPrinterTypeHeader(printerType, config),
          const SizedBox(height: 24),
          
          // Printers Section
          _buildPrintersSection(printerType, config),
          const SizedBox(height: 24),
          
          // Categories Section
          _buildCategoriesSection(printerType, config),
          const SizedBox(height: 24),
          
          // Items Section
          _buildItemsSection(printerType, config),
        ],
      ),
    );
  }

  /// Build printer type header
  Widget _buildPrinterTypeHeader(PrinterTypeCategory printerType, PrinterTypeConfiguration config) {
    final displayInfo = config.getDisplayInfo();
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  displayInfo['icon'],
                  style: const TextStyle(fontSize: 48),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayInfo['type'],
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        config.description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildStatCard('Printers', displayInfo['printerCount'], Icons.print),
                const SizedBox(width: 16),
                _buildStatCard('Categories', displayInfo['categoryCount'], Icons.category),
                const SizedBox(width: 16),
                _buildStatCard('Items', displayInfo['itemCount'], Icons.restaurant_menu),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build stat card
  Widget _buildStatCard(String label, int count, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 24, color: Colors.grey[600]),
            const SizedBox(height: 4),
            Text(
              count.toString(),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build printers section
  Widget _buildPrintersSection(PrinterTypeCategory printerType, PrinterTypeConfiguration config) {
    final assignedPrinters = _availablePrinters
        .where((p) => config.assignedPrinterIds.contains(p.id))
        .toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🖨️ Assigned Printers',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showPrinterAssignmentDialog(printerType),
                  icon: const Icon(Icons.add),
                  label: const Text('Assign'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (assignedPrinters.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    'No printers assigned yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              ...assignedPrinters.map((printer) => _buildPrinterTile(printer, printerType)),
          ],
        ),
      ),
    );
  }

  /// Build printer tile
  Widget _buildPrinterTile(PrinterConfiguration printer, PrinterTypeCategory printerType) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getPrinterTypeColor(printerType),
        child: const Icon(Icons.print, color: Colors.white),
      ),
      title: Text(printer.name),
      subtitle: Text('${printer.type.displayName} • ${printer.address}'),
      trailing: IconButton(
        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
        onPressed: () => _removePrinterAssignment(printer.id, printerType),
      ),
    );
  }

  /// Build categories section
  Widget _buildCategoriesSection(PrinterTypeCategory printerType, PrinterTypeConfiguration config) {
    final assignedCategories = _availableCategories
        .where((c) => config.assignedCategoryIds.contains(c.id))
        .toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🏷️ Assigned Categories',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCategoryAssignmentDialog(printerType),
                  icon: const Icon(Icons.add),
                  label: const Text('Assign'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (assignedCategories.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    'No categories assigned yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              ...assignedCategories.map((category) => _buildCategoryTile(category, printerType)),
          ],
        ),
      ),
    );
  }

  /// Build category tile
  Widget _buildCategoryTile(Category category, PrinterTypeCategory printerType) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getPrinterTypeColor(printerType),
        child: const Icon(Icons.category, color: Colors.white),
      ),
      title: Text(category.name),
      subtitle: Text('${category.itemCount} items'),
      trailing: IconButton(
        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
        onPressed: () => _removeCategoryAssignment(category.id, printerType),
      ),
    );
  }

  /// Build items section
  Widget _buildItemsSection(PrinterTypeCategory printerType, PrinterTypeConfiguration config) {
    final assignedItems = _availableItems
        .where((item) => config.assignedItemIds.contains(item.id))
        .toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🍽️ Assigned Items',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showItemAssignmentDialog(printerType),
                  icon: const Icon(Icons.add),
                  label: const Text('Assign'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (assignedItems.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Text(
                    'No items assigned yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              )
            else
              ...assignedItems.map((item) => _buildItemTile(item, printerType)),
          ],
        ),
      ),
    );
  }

  /// Build item tile
  Widget _buildItemTile(MenuItem item, PrinterTypeCategory printerType) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: _getPrinterTypeColor(printerType),
        child: const Icon(Icons.restaurant_menu, color: Colors.white),
      ),
      title: Text(item.name),
      subtitle: Text('₹${item.price.toStringAsFixed(2)} • ${item.categoryName}'),
      trailing: IconButton(
        icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
        onPressed: () => _removeItemAssignment(item.id, printerType),
      ),
    );
  }

  /// Show printer assignment dialog
  Future<void> _showPrinterAssignmentDialog(PrinterTypeCategory printerType) async {
    final availablePrinters = _availablePrinters
        .where((p) => !_printerTypeService.getPrintersForType(printerType).contains(p.id))
        .toList();

    if (availablePrinters.isEmpty) {
      _showInfoSnackBar('No available printers to assign');
      return;
    }

    final selectedPrinter = await showDialog<PrinterConfiguration>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign Printer to ${printerType.displayName}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availablePrinters.length,
            itemBuilder: (context, index) {
              final printer = availablePrinters[index];
              return ListTile(
                title: Text(printer.name),
                subtitle: Text('${printer.type.displayName} • ${printer.address}'),
                onTap: () => Navigator.of(context).pop(printer),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedPrinter != null) {
      try {
        final userId = await _firebaseService.getCurrentUserId();
        if (userId != null) {
          await _printerTypeService.assignPrinterToType(
            printerId: selectedPrinter.id,
            printerType: printerType,
            isPrimary: _printerTypeService.getPrintersForType(printerType).isEmpty,
            userId: userId,
          );
          _showSuccessSnackBar('Printer assigned successfully');
        }
      } catch (e) {
        _showErrorSnackBar('Error assigning printer: $e');
      }
    }
  }

  /// Show category assignment dialog
  Future<void> _showCategoryAssignmentDialog(PrinterTypeCategory printerType) async {
    final availableCategories = _availableCategories
        .where((c) => !_printerTypeService.getAllPrinterTypes()[printerType]!.assignedCategoryIds.contains(c.id))
        .toList();

    if (availableCategories.isEmpty) {
      _showInfoSnackBar('No available categories to assign');
      return;
    }

    final selectedCategory = await showDialog<Category>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign Category to ${printerType.displayName}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableCategories.length,
            itemBuilder: (context, index) {
              final category = availableCategories[index];
              return ListTile(
                title: Text(category.name),
                subtitle: Text('${category.itemCount} items'),
                onTap: () => Navigator.of(context).pop(category),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedCategory != null) {
      try {
        final userId = await _firebaseService.getCurrentUserId();
        if (userId != null) {
          await _printerTypeService.assignCategoryToType(
            categoryId: selectedCategory.id,
            printerType: printerType,
            userId: userId,
          );
          _showSuccessSnackBar('Category assigned successfully');
        }
      } catch (e) {
        _showErrorSnackBar('Error assigning category: $e');
      }
    }
  }

  /// Show item assignment dialog
  Future<void> _showItemAssignmentDialog(PrinterTypeCategory printerType) async {
    final availableItems = _availableItems
        .where((item) => !_printerTypeService.getAllPrinterTypes()[printerType]!.assignedItemIds.contains(item.id))
        .toList();

    if (availableItems.isEmpty) {
      _showInfoSnackBar('No available items to assign');
      return;
    }

    final selectedItem = await showDialog<MenuItem>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign Item to ${printerType.displayName}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableItems.length,
            itemBuilder: (context, index) {
              final item = availableItems[index];
              return ListTile(
                title: Text(item.name),
                subtitle: Text('₹${item.price.toStringAsFixed(2)} • ${item.categoryName}'),
                onTap: () => Navigator.of(context).pop(item),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedItem != null) {
      try {
        final userId = await _firebaseService.getCurrentUserId();
        final restaurantId = await _firebaseService.getCurrentRestaurantId();
        
        if (userId != null && restaurantId != null) {
          await _printerTypeService.assignItemToType(
            itemId: selectedItem.id,
            itemName: selectedItem.name,
            categoryId: selectedItem.categoryId,
            categoryName: selectedItem.categoryName,
            printerType: printerType,
            userId: userId,
            restaurantId: restaurantId,
          );
          _showSuccessSnackBar('Item assigned successfully');
        }
      } catch (e) {
        _showErrorSnackBar('Error assigning item: $e');
      }
    }
  }

  /// Show quick assignment dialog
  Future<void> _showQuickAssignmentDialog() async {
    // This would be a comprehensive dialog for quick assignments
    _showInfoSnackBar('Quick assignment feature coming soon!');
  }

  /// Remove printer assignment
  Future<void> _removePrinterAssignment(String printerId, PrinterTypeCategory printerType) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const ConfirmationDialog(
        title: 'Remove Printer Assignment',
        message: 'Are you sure you want to remove this printer assignment?',
        confirmText: 'Remove',
        cancelText: 'Cancel',
      ),
    );

    if (confirmed == true) {
      try {
        await _printerTypeService.removePrinterAssignment(printerId, printerType);
        _showSuccessSnackBar('Printer assignment removed');
      } catch (e) {
        _showErrorSnackBar('Error removing printer assignment: $e');
      }
    }
  }

  /// Remove category assignment
  Future<void> _removeCategoryAssignment(String categoryId, PrinterTypeCategory printerType) async {
    // Implementation for removing category assignment
    _showInfoSnackBar('Category removal feature coming soon!');
  }

  /// Remove item assignment
  Future<void> _removeItemAssignment(String itemId, PrinterTypeCategory printerType) async {
    // Implementation for removing item assignment
    _showInfoSnackBar('Item removal feature coming soon!');
  }

  /// Get printer type color
  Color _getPrinterTypeColor(PrinterTypeCategory printerType) {
    switch (printerType) {
      case PrinterTypeCategory.receipt:
        return Colors.green;
      case PrinterTypeCategory.tandoor:
        return Colors.orange;
      case PrinterTypeCategory.curry:
        return Colors.purple;
      case PrinterTypeCategory.expo:
        return Colors.blue;
    }
  }

  /// Show success snackbar
  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show error snackbar
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Show info snackbar
  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
} 