import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/menu_item.dart';
import '../models/category.dart';

import '../services/menu_service.dart';
import '../widgets/universal_navigation.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/error_dialog.dart';
import '../widgets/confirmation_dialog.dart';


class ManageMenuItemsScreen extends StatefulWidget {
  const ManageMenuItemsScreen({super.key});

  @override
  _ManageMenuItemsScreenState createState() => _ManageMenuItemsScreenState();
}

class _ManageMenuItemsScreenState extends State<ManageMenuItemsScreen> {
  List<MenuItem> _menuItems = [];
  List<Category> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final menuService = Provider.of<MenuService>(context, listen: false);
      final categories = await menuService.getCategories();
      final menuItems = await menuService.getAllMenuItems();

      setState(() {
        _categories = categories;
        _menuItems = menuItems;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error loading data: $e';
      });
    }
  }

  Future<void> _deleteMenuItem(MenuItem item) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final menuService = Provider.of<MenuService>(context, listen: false);
      await menuService.deleteMenuItem(item.id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.name} deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error deleting item: $e';
      });
      if (mounted) {
        await ErrorDialogHelper.showError(
          context,
          title: 'Error Deleting Item',
          message: 'Failed to delete ${item.name}: $e',
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation(MenuItem item) async {
    final confirmed = await ConfirmationDialogHelper.showDeleteConfirmation(
      context,
      itemName: item.name,
      message: 'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
    );

    if (confirmed == true) {
      await _deleteMenuItem(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: UniversalAppBar(
          currentUser: null, // This screen doesn't have user context
          title: 'Manage Menu Items',
          additionalActions: [
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final result = await Navigator.pushNamed(context, '/add-menu-item');
                if (result == true) {
                  _loadData();
                }
              },
              tooltip: 'Add Menu Item',
            ),
          ],
          showQuickActions: false, // Disable quick actions for this admin screen
        ),
        body: _error != null
            ? _buildErrorState(_error!)
            : _buildMenuItemsList(),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            'Error loading menu items',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.red.shade700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItemsList() {
    if (_menuItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_menu, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No menu items found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first menu item to get started!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade500,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Group items by category
    final itemsByCategory = <String, List<MenuItem>>{};
    for (final item in _menuItems) {
      itemsByCategory.putIfAbsent(item.categoryId, () => []).add(item);
    }

    return ListView.builder(
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        final items = itemsByCategory[category.id] ?? [];

        return ExpansionTile(
          title: Text(
            category.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text('${items.length} items'),
          children: items.map((item) => _buildMenuItemTile(item)).toList(),
        );
      },
    );
  }

  Widget _buildMenuItemTile(MenuItem item) {
    final category = _categories.firstWhere(
      (cat) => cat.id == item.categoryId,
                              orElse: () => Category(name: 'Unknown'),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.description.isNotEmpty) ...[
              Text(
                item.description,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Icon(Icons.category, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  category.name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
                const SizedBox(width: 16),
                Icon(Icons.attach_money, size: 16, color: Colors.green),
                const SizedBox(width: 4),
                Text(
                  '\$${item.price.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            if (!item.isAvailable) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'Out of Stock',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                // TODO: Implement edit functionality
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Edit functionality coming soon'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              tooltip: 'Edit Item',
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _showDeleteConfirmation(item),
              tooltip: 'Delete Item',
            ),
          ],
        ),
      ),
    );
  }
} 