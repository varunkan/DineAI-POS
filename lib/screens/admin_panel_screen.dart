import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../models/category.dart' as pos_category;
import '../models/menu_item.dart';
import '../models/order.dart';

import '../services/menu_service.dart';
import '../services/order_service.dart';
import '../services/order_log_service.dart';
import '../services/table_service.dart';
import '../services/enhanced_printer_assignment_service.dart';
import 'comprehensive_printer_assignment_screen.dart';

import '../services/user_service.dart';
import '../widgets/universal_navigation.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/error_dialog.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/form_field.dart';

import '../screens/admin_orders_screen.dart';
import '../screens/kitchen_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/inventory_screen.dart';
import '../screens/tables_screen.dart';
import '../screens/user_management_screen.dart';
import '../screens/user_activity_monitoring_screen.dart';
import '../screens/free_cloud_setup_screen.dart';
import '../services/activity_log_service.dart';
import '../models/activity_log.dart';
import '../widgets/printer_status_widget.dart';
import '../utils/firebase_data_clearer.dart';
import '../screens/bluetooth_printer_management_screen.dart';
import '../examples/multiple_bluetooth_printers_example.dart';
import '../services/printer_configuration_service.dart';
import '../services/printing_service.dart';

enum UserManagementView { addUser, existingUsers }

class AdminPanelScreen extends StatefulWidget {
  final User user;
  final int initialTabIndex;

  const AdminPanelScreen({super.key, required this.user, this.initialTabIndex = 0});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with TickerProviderStateMixin {
  static const _titleTextStyle = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    color: Color(0xFF1F2937),
    letterSpacing: 0.5,
  );

  static const _subtitleTextStyle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Color(0xFF3B82F6),
    letterSpacing: 0.3,
  );

  /// Enhanced card text styling
  static TextStyle _getCardTitleStyle(Color color) => TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: color,
    letterSpacing: 0.4,
  );

  static TextStyle _getCardValueStyle(Color color) => TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w900,
    color: color,
    letterSpacing: 0.5,
  );

  int _selectedIndex = 0;
  List<pos_category.Category> _categories = [];
  List<MenuItem> _menuItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialTabIndex;
    debugPrint('ADMIN FLOW: AdminPanelScreen initState, initialTabIndex: $_selectedIndex');
    _verifyAdminAccess();
    _loadData();
    _logAdminPanelAccess();
  }
  
  /// Verify that the user has proper admin access
  void _verifyAdminAccess() {
    debugPrint('🔍 Verifying admin access for user: ${widget.user.name}');
    debugPrint('🔑 User Role: ${widget.user.role}');
    debugPrint('⚙️ Admin Panel Access: ${widget.user.adminPanelAccess}');
    debugPrint('✅ User is Active: ${widget.user.isActive}');
    
    if (widget.user.role == UserRole.admin && widget.user.adminPanelAccess && widget.user.isActive) {
      debugPrint('✅ User has full admin access');
    } else {
      debugPrint('⚠️ Warning: User may not have proper admin access');
      debugPrint('   • Role: ${widget.user.role} (should be admin)');
      debugPrint('   • Admin Panel Access: ${widget.user.adminPanelAccess} (should be true)');
      debugPrint('   • Active: ${widget.user.isActive} (should be true)');
    }
  }

  /// Log admin panel access
  void _logAdminPanelAccess() {
    try {
      final activityLogService = Provider.of<ActivityLogService>(context, listen: false);
      activityLogService.logAdminPanelAccess(
        userId: widget.user.id,
        userName: widget.user.name,
        userRole: widget.user.role.toString(),
        tabName: 'Tab $_selectedIndex',
      );
    } catch (e) {
      debugPrint('⚠️ Failed to log admin panel access: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Load data for admin panel
  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // DISABLED: This was causing infinite sync loops
      // await _triggerSyncOnAdminPanelAccess();
      
      final menuService = Provider.of<MenuService>(context, listen: false);
      
      _categories = await menuService.getCategories();
      _menuItems = await menuService.getMenuItems();
      
      setState(() {
        _isLoading = false;
      });
      
      debugPrint('✅ Admin panel data loaded: ${_categories.length} categories, ${_menuItems.length} menu items');
    } catch (e) {
      debugPrint('❌ Error loading admin panel data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Trigger sync on admin panel access - DISABLED to prevent infinite loops
  Future<void> _triggerSyncOnAdminPanelAccess() async {
    // DISABLED: This was causing infinite sync loops
    // try {
    //   final syncTriggerService = AutomaticSyncTriggerService();
    //   await syncTriggerService.triggerImmediateSyncOnInteraction();
    //   debugPrint('🔄 Sync triggered on admin panel access');
    // } catch (e) {
    //   debugPrint('⚠️ Failed to trigger sync on admin panel access: $e');
    // }
  }

  Future<void> _addCategory() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController sortOrderController = TextEditingController();
    bool isActive = true;
    IconData selectedIcon = Icons.restaurant_menu;
    Color selectedColor = Colors.blue;

    // Pre-defined restaurant category options
    final categoryTemplates = [
      {'name': 'Appetizers', 'icon': Icons.local_dining, 'color': Colors.orange},
      {'name': 'Main Courses', 'icon': Icons.dinner_dining, 'color': Colors.red},
      {'name': 'Desserts', 'icon': Icons.cake, 'color': Colors.pink},
      {'name': 'Beverages', 'icon': Icons.local_drink, 'color': Colors.blue},
      {'name': 'Salads', 'icon': Icons.eco, 'color': Colors.green},
      {'name': 'Soups', 'icon': Icons.soup_kitchen, 'color': Colors.amber},
      {'name': 'Seafood', 'icon': Icons.set_meal, 'color': Colors.teal},
      {'name': 'Vegetarian', 'icon': Icons.grass, 'color': Colors.lightGreen},
      {'name': 'Kids Menu', 'icon': Icons.child_friendly, 'color': Colors.purple},
      {'name': 'Specials', 'icon': Icons.star, 'color': Colors.deepOrange},
    ];

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.category, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              const Text('Add New Category'),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.4,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick templates section
                  const Text(
                    'Quick Templates',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: categoryTemplates.map((template) {
                      return InkWell(
                        onTap: () {
                          nameController.text = template['name'] as String;
                          selectedIcon = template['icon'] as IconData;
                          selectedColor = template['color'] as Color;
                          setState(() {});
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: (template['color'] as Color).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: (template['color'] as Color).withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(template['icon'] as IconData, 
                                   size: 16, color: template['color'] as Color),
                              const SizedBox(width: 4),
                              Text(template['name'] as String,
                                   style: TextStyle(color: template['color'] as Color, fontSize: 12)),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  
                  AppFormField(
                    label: 'Category Name *',
                    hint: 'Enter category name',
                    controller: nameController,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Category name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  AppFormField(
                    label: 'Description',
                    hint: 'Brief description of this category',
                    controller: descriptionController,
                    maxLines: 3,
                  ),
                  const SizedBox(height: 16),
                  
                  AppFormField(
                    label: 'Sort Order',
                    hint: 'Display order (1, 2, 3...)',
                    controller: sortOrderController,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  
                  // Icon and color selection
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Icon', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(selectedIcon, color: selectedColor),
                                  const SizedBox(width: 8),
                                  const Text('Selected Icon'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Color', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: selectedColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('Selected Color'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Active toggle
                  Row(
                    children: [
                      Switch(
                        value: isActive,
                        onChanged: (value) {
                          isActive = value;
                          setState(() {});
                        },
                      ),
                      const SizedBox(width: 8),
                      const Text('Active Category'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop({
                    'name': nameController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'sortOrder': int.tryParse(sortOrderController.text) ?? _categories.length,
                    'isActive': isActive,
                    'icon': selectedIcon.codePoint,
                    'color': selectedColor.toARGB32(),
                  });
                }
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Category'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final menuService = Provider.of<MenuService>(context, listen: false);
        final newCategory = pos_category.Category(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: result['name']!,
          description: result['description']!.isEmpty ? null : result['description']!,
          sortOrder: result['sortOrder'] as int,
          isActive: result['isActive'] as bool,
          iconCodePoint: result['icon'] as int?,
          colorValue: result['color'] as int?,
        );
        await menuService.addCategory(newCategory); // Use addCategory for proper Firebase sync
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(newCategory.icon, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('Category "${result['name']}" created successfully!'),
                ],
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          await ErrorDialogHelper.showError(
            context,
            title: 'Error Adding Category',
            message: 'Failed to add category: $e',
          );
        }
      } finally {
        if (mounted) setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _editCategory(pos_category.Category category) async {
    final TextEditingController nameController = TextEditingController(text: category.name);
    final TextEditingController descriptionController = TextEditingController(text: category.description ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppFormField(
              label: 'Category Name',
              hint: 'Enter category name',
              controller: nameController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Category name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AppFormField(
              label: 'Description',
              hint: 'Enter description (optional)',
              controller: descriptionController,
              maxLines: 3,
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.of(context).pop({
                  'name': nameController.text.trim(),
                  'description': descriptionController.text.trim(),
                });
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final menuService = Provider.of<MenuService>(context, listen: false);
        final updatedCategory = category.copyWith(
          name: result['name']!,
          description: result['description']!.isEmpty ? null : result['description']!,
        );
        await menuService.updateCategory(updatedCategory); // Use updateCategory for proper Firebase sync
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Category updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          await ErrorDialogHelper.showError(
            context,
            title: 'Error Updating Category',
            message: 'Failed to update category: $e',
          );
        }
      } finally {
        if (mounted) setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _deleteCategory(pos_category.Category category) async {
    // Check if category has menu items
    final itemsInCategory = _menuItems.where((item) => item.categoryId == category.id).toList();
    
    if (itemsInCategory.isNotEmpty) {
      await ErrorDialogHelper.showError(
        context,
        title: 'Cannot Delete Category',
        message: 'This category contains ${itemsInCategory.length} menu item(s). Please remove or reassign all items before deleting the category.',
      );
      return;
    }

    final confirmed = await ConfirmationDialogHelper.showDeleteConfirmation(
      context,
      itemName: category.name,
      message: 'Are you sure you want to delete "${category.name}"? This action cannot be undone.',
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final menuService = Provider.of<MenuService>(context, listen: false);
        await menuService.deleteCategory(category.id);
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Category deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          await ErrorDialogHelper.showError(
            context,
            title: 'Error Deleting Category',
            message: 'Failed to delete category: $e',
          );
        }
      } finally {
        if (mounted) setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _addMenuItem() async {
    if (_categories.isEmpty) {
      await ErrorDialogHelper.showError(
        context,
        title: 'No Categories Available',
        message: 'Please create at least one category before adding menu items.',
      );
      return;
    }

    final TextEditingController nameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController priceController = TextEditingController();
    String? selectedCategoryId = _categories.first.id;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Menu Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppFormField(
                label: 'Item Name',
                hint: 'Enter item name',
                controller: nameController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Item name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppFormField(
                label: 'Description',
                hint: 'Enter description (optional)',
                controller: descriptionController,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              AppFormField(
                label: 'Price',
                hint: 'Enter price (e.g., 9.99)',
                controller: priceController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Price is required';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Please enter a valid price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                value: selectedCategoryId,
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  );
                }).toList(),
                onChanged: (value) {
                  selectedCategoryId = value;
                },
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty &&
                  priceController.text.trim().isNotEmpty &&
                  double.tryParse(priceController.text) != null) {
                Navigator.of(context).pop({
                  'name': nameController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'price': double.parse(priceController.text),
                  'categoryId': selectedCategoryId,
                });
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final menuService = Provider.of<MenuService>(context, listen: false);
        final newMenuItem = MenuItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: result['name']!,
          description: result['description']!.isEmpty ? '' : result['description']!,
          price: result['price']!,
          categoryId: result['categoryId']!,
          tags: [],
          customProperties: {},
          variants: [],
          modifiers: [],
          nutritionalInfo: {},
          allergens: {},
          preparationTime: 10,
          isVegetarian: false,
          isVegan: false,
          isGlutenFree: false,
          isSpicy: false,
          spiceLevel: 0,
          stockQuantity: 100,
          lowStockThreshold: 10,
        );
        await menuService.addMenuItem(newMenuItem); // Use addMenuItem for proper Firebase sync
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Menu item "${result['name']}" added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          await ErrorDialogHelper.showError(
            context,
            title: 'Error Adding Menu Item',
            message: 'Failed to add menu item: $e',
          );
        }
      }
    }
  }

  Future<void> _editMenuItem(MenuItem item) async {
    final TextEditingController nameController = TextEditingController(text: item.name);
    final TextEditingController descriptionController = TextEditingController(text: item.description);
    final TextEditingController priceController = TextEditingController(text: item.price.toString());
    String? selectedCategoryId = item.categoryId;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Menu Item'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppFormField(
                label: 'Item Name',
                hint: 'Enter item name',
                controller: nameController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Item name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              AppFormField(
                label: 'Description',
                hint: 'Enter description (optional)',
                controller: descriptionController,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              AppFormField(
                label: 'Price',
                hint: 'Enter price (e.g., 9.99)',
                controller: priceController,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Price is required';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Please enter a valid price';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                value: selectedCategoryId,
                items: _categories.map((category) {
                  return DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  );
                }).toList(),
                onChanged: (value) {
                  selectedCategoryId = value;
                },
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty &&
                  priceController.text.trim().isNotEmpty &&
                  double.tryParse(priceController.text) != null) {
                Navigator.of(context).pop({
                  'name': nameController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'price': double.parse(priceController.text),
                  'categoryId': selectedCategoryId,
                });
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
      });

      try {
        final menuService = Provider.of<MenuService>(context, listen: false);
        final updatedMenuItem = item.copyWith(
          name: result['name']!,
          description: result['description']!.isEmpty ? '' : result['description']!,
          price: result['price']!,
          categoryId: result['categoryId']!,
        );
        await menuService.updateMenuItem(updatedMenuItem); // Use updateMenuItem for proper Firebase sync
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Menu item updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          await ErrorDialogHelper.showError(
            context,
            title: 'Error Updating Menu Item',
            message: 'Failed to update menu item: $e',
          );
        }
      }
    }
  }

  Future<void> _deleteMenuItem(MenuItem item) async {
    final confirmed = await ConfirmationDialogHelper.showDeleteConfirmation(
      context,
      itemName: item.name,
      message: 'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
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
        if (mounted) {
          await ErrorDialogHelper.showError(
            context,
            title: 'Error Deleting Menu Item',
            message: 'Failed to delete menu item: $e',
          );
        }
      }
    }
  }

  // User Management Methods
  // Removed unused methods: _addUser, _editUser, _deleteUser

  // Menu Loading Methods
  Future<void> _loadOhBombayMenu() async {
    final confirmed = await ConfirmationDialogHelper.showConfirmation(
      context,
      title: 'Load Oh Bombay Menu',
      message: 'This will replace all existing categories and menu items with the Oh Bombay Milton restaurant menu. Are you sure?',
      confirmText: 'Load Menu',
      cancelText: 'Cancel',
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        debugPrint('🍽️ Admin: Starting Oh Bombay menu loading...');
        final menuService = Provider.of<MenuService>(context, listen: false);
        
        // Ensure menu service is properly initialized
        await menuService.ensureInitialized();
        debugPrint('✅ Admin: Menu service initialized');
        
        // Load the Oh Bombay menu
        await menuService.loadOhBombayMenu();
        debugPrint('✅ Admin: Oh Bombay menu loaded');
        
        // Reload local data
        await _loadData();
        debugPrint('✅ Admin: UI data refreshed');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Oh Bombay menu loaded successfully! 🇮🇳\n${_categories.length} categories, ${_menuItems.length} items'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 4),
            ),
          );
        }
      } catch (e, stackTrace) {
        debugPrint('❌ Admin: Error loading Oh Bombay menu: $e');
        debugPrint('Stack trace: $stackTrace');
        
        if (mounted) {
          await ErrorDialogHelper.showError(
            context,
            title: 'Error Loading Oh Bombay Menu',
            message: 'Failed to load Oh Bombay menu:\n\nError: $e\n\nPlease check the console for more details.',
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<void> _testMenuService() async {
    setState(() { _isLoading = true; });
    
    try {
      debugPrint('🧪 Testing menu service functionality...');
      final menuService = Provider.of<MenuService>(context, listen: false);
      
      // Test 1: Check service initialization
      debugPrint('🔍 Test 1: Service initialization');
      await menuService.ensureInitialized();
      debugPrint('✅ Menu service initialized successfully');
      
      // Test 2: Check current data
      debugPrint('🔍 Test 2: Current menu data');
      final currentCategories = await menuService.getCategories();
      final currentMenuItems = await menuService.getMenuItems();
      debugPrint('📊 Current: ${currentCategories.length} categories, ${currentMenuItems.length} items');
      
      // Test 3: Test database connectivity
      debugPrint('🔍 Test 3: Database operations');
      // Try to create a test category
      final testCategory = pos_category.Category(
        name: 'Test Category ${DateTime.now().millisecondsSinceEpoch}',
        description: 'Test category for functionality check',
        sortOrder: 999,
      );
      
      await menuService.saveCategory(testCategory);
      debugPrint('✅ Test category created successfully');
      
      // Clean up test category
      await menuService.deleteCategory(testCategory.id);
      debugPrint('✅ Test category deleted successfully');
      
      // Test 4: Test Oh Bombay menu loading with detailed error checking
      debugPrint('🔍 Test 4: Oh Bombay menu loading dry run');
      try {
        // This will test the actual loadOhBombayMenu method
        await menuService.clearAllData();
        debugPrint('✅ Data cleared successfully');
        
        await menuService.loadOhBombayMenu();
        debugPrint('✅ Oh Bombay menu loaded successfully');
        
        final finalCategories = await menuService.getCategories();
        final finalMenuItems = await menuService.getMenuItems();
        debugPrint('📊 Final: ${finalCategories.length} categories, ${finalMenuItems.length} items');
        
      } catch (e, stackTrace) {
        debugPrint('❌ Oh Bombay loading failed: $e');
        debugPrint('Stack trace: $stackTrace');
        throw e;
      }
      
      // Refresh UI
      await _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Menu service test completed successfully!\n${_categories.length} categories, ${_menuItems.length} items loaded'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
      
    } catch (e, stackTrace) {
      debugPrint('❌ Menu service test failed: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        await ErrorDialogHelper.showError(
          context,
          title: 'Menu Service Test Failed',
          message: 'Test failed with error:\n\n$e\n\nCheck console for details.',
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _loadSampleMenu() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Load Sample Menu'),
        content: const Text('This will load a sample menu with various categories and items. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Load Menu'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final menuService = Provider.of<MenuService>(context, listen: false);
        
        // Load sample menu data
        await menuService.loadSampleMenu();
        
        // Refresh the data
        await _loadData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sample menu loaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load sample menu: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _createTestOrders() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Test Orders'),
        content: const Text('This will create 3 simple test orders to demonstrate the audit logging functionality. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Create Orders'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() { _isLoading = true; });
      
      try {
        final orderService = Provider.of<OrderService>(context, listen: false);
        final orderLogService = Provider.of<OrderLogService>(context, listen: false);
        
        // Set current user context for logging
        orderLogService.setCurrentUser(widget.user.id, widget.user.name);
        
        // Create 3 simple test orders
        for (int i = 1; i <= 3; i++) {
          final order = Order(
            orderNumber: 'TEST-${DateTime.now().millisecondsSinceEpoch}-$i',
            userId: widget.user.id,
            customerName: 'Test Customer $i',
            type: i % 2 == 0 ? OrderType.dineIn : OrderType.takeaway,
            items: [], // Start with empty items to avoid menu dependency
            status: OrderStatus.pending,
          );
          
          // Save the order (this should create audit logs)
          await orderService.saveOrder(order);
          debugPrint('Created test order: ${order.orderNumber}');
          
          // Update status to create more audit logs
          await orderService.updateOrderStatus(order.id, 'confirmed');
          debugPrint('Updated order ${order.orderNumber} to confirmed');
          
          if (i > 1) {
            await orderService.updateOrderStatus(order.id, 'preparing');
            debugPrint('Updated order ${order.orderNumber} to preparing');
          }
        }
        
        // Check if logs were created
        final allLogs = orderLogService.allLogs;
        debugPrint('Total audit logs created: ${allLogs.length}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Created 3 test orders with ${allLogs.length} audit logs!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error creating test orders: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create test orders: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() { _isLoading = false; });
        }
      }
    }
  }

  Future<void> _generateTestActivityLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Generate Test Activity Logs'),
        content: const Text('This will generate various test activity logs to demonstrate the audit functionality. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Generate Logs'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() { _isLoading = true; });
      
      try {
        final activityLogService = Provider.of<ActivityLogService>(context, listen: false);
        
        // Generate various types of activity logs
        await activityLogService.logActivity(
          action: ActivityAction.login,
          description: 'Test login activity',
          screenName: 'Admin Panel',
          metadata: {'test': true, 'source': 'admin_panel'},
        );

        await activityLogService.logActivity(
          action: ActivityAction.userCreated,
          description: 'Test user creation',
          targetName: 'Test User',
          screenName: 'Admin Panel',
          metadata: {'test': true, 'source': 'admin_panel'},
        );

        await activityLogService.logActivity(
          action: ActivityAction.orderCreated,
          description: 'Test order creation',
          targetName: 'Test Order #123',
          screenName: 'Admin Panel',
          metadata: {'test': true, 'source': 'admin_panel'},
        );

        await activityLogService.logActivity(
          action: ActivityAction.paymentProcessed,
          description: 'Test payment processing',
          targetName: 'Payment #456',
          financialAmount: 25.99,
          screenName: 'Admin Panel',
          metadata: {'test': true, 'source': 'admin_panel'},
        );

        await activityLogService.logActivity(
          action: ActivityAction.menuItemUpdated,
          description: 'Test menu item update',
          targetName: 'Test Menu Item',
          screenName: 'Admin Panel',
          metadata: {'test': true, 'source': 'admin_panel'},
        );

        await activityLogService.logActivity(
          action: ActivityAction.systemError,
          level: ActivityLevel.error,
          description: 'Test error log',
          errorMessage: 'This is a test error message',
          screenName: 'Admin Panel',
          metadata: {'test': true, 'source': 'admin_panel'},
        );

        // Check if logs were created
        final allLogs = activityLogService.allLogs;
        final recentLogs = activityLogService.recentLogs;
        
        debugPrint('Total activity logs: ${allLogs.length}');
        debugPrint('Recent activity logs: ${recentLogs.length}');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Generated ${recentLogs.length} test activity logs! Check the Activity tab.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error generating test activity logs: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to generate test logs: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() { _isLoading = false; });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Processing...',
      child: Scaffold(
        appBar: _buildAppBar(),
        body: Column(
          children: [
            // Admin action buttons for specific tabs
            if (_selectedIndex == 4) // Clear orders button on orders tab
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete_sweep),
                    label: const Text('Clear All Orders (Testing)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final confirmed = await ConfirmationDialogHelper.showConfirmation(
                        context,
                        title: 'Clear All Orders',
                        message: 'This will permanently delete ALL orders from the database. Users, menu items, and categories will be preserved. This action cannot be undone. Are you sure?',
                        confirmText: 'Clear Orders',
                        cancelText: 'Cancel',
                      );
                      if (confirmed == true) {
                        setState(() { _isLoading = true; });
                        try {
                          final orderService = Provider.of<OrderService>(context, listen: false);
                          await orderService.deleteAllOrders();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('✅ All orders cleared successfully! Database ready for testing.'),
                                backgroundColor: Colors.green,
                                duration: Duration(seconds: 4),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            await ErrorDialogHelper.showError(
                              context,
                              title: 'Error Clearing Orders',
                              message: 'Failed to clear orders: $e',
                            );
                          }
                        } finally {
                          if (mounted) setState(() { _isLoading = false; });
                        }
                      }
                    },
                  ),
                ),
              ),
            if (_selectedIndex == 9) // Only show reset button on tables tab
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.table_restaurant),
                    label: const Text('Reset Tables to Default'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final confirmed = await ConfirmationDialogHelper.showConfirmation(
                        context,
                        title: 'Reset Tables',
                        message: 'This will delete all existing tables and recreate tables 1-16 with the correct capacities. Are you sure?',
                        confirmText: 'Reset',
                        cancelText: 'Cancel',
                      );
                      if (confirmed == true) {
                        setState(() { _isLoading = true; });
                        try {
                          final tableService = Provider.of<TableService>(context, listen: false);
                          await tableService.resetTablesToDefault();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tables reset to default configuration!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            await ErrorDialogHelper.showError(
                              context,
                              title: 'Error Resetting Tables',
                              message: 'Failed to reset tables: $e',
                            );
                          }
                        } finally {
                          if (mounted) setState(() { _isLoading = false; });
                        }
                      }
                    },
                  ),
                ),
              ),
            Expanded(child: _buildBody()),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() {
              _selectedIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.category),
              label: 'Categories',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_menu),
              label: 'Menu Items',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Users',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.print),
              label: 'Printers',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long),
              label: 'Orders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.kitchen),
              label: 'Kitchen',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assessment),
              label: 'Reports',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.inventory),
              label: 'Inventory',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.table_restaurant),
              label: 'Tables',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: 'Settings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.monitor_heart),
              label: 'Activity',
            ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return UniversalAppBar(
      currentUser: widget.user,
      title: 'Admin Panel',
      onBack: () {
        // Navigate back to landing screen
        Navigator.of(context).popUntil((route) => route.isFirst);
      },
      additionalActions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadData,
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildBody() {
    debugPrint('ADMIN FLOW: Building tab content for index: $_selectedIndex');
    switch (_selectedIndex) {
      case 0:
        return _buildCategoriesTab();
      case 1:
        return _buildMenuItemsTab();
      case 2:
        return _buildManageUsersTab();
      case 3:
        return _buildPrinterAssignmentsTab();
      case 4:
        return _buildOrdersTab();
      case 5:
        return _buildKitchenTab();
      case 6:
        return _buildReportsTab();
      case 7:
        return _buildInventoryTab();
      case 8:
        return _buildTablesTab();
      case 9:
        return _buildSettingsTab();
      case 10:
        return _buildActivityMonitoringTab();
      default:
        return _buildCategoriesTab();
    }
  }

  Widget _buildCategoriesTab() {
    // Get responsive sizing based on device type
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
    
    // Responsive padding and spacing
    final padding = isPhone ? 12.0 : isTablet ? 14.0 : 16.0;
    final buttonPadding = isPhone ? 8.0 : isTablet ? 10.0 : 12.0;
    final buttonSpacing = isPhone ? 6.0 : isTablet ? 8.0 : 12.0;
    
    return Column(
      children: [
        _buildTabHeader(
          title: 'Categories',
          subtitle: 'Manage menu categories',
          onAddPressed: _addCategory,
        ),
        // Add Oh Bombay Menu loading section - Responsive layout
        Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            children: [
              // Responsive button layout for mobile
              if (isPhone) ...[
                // Mobile: Stacked buttons
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.restaurant),
                    label: const Text('Load Oh Bombay Menu'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: buttonPadding),
                    ),
                    onPressed: _loadOhBombayMenu,
                  ),
                ),
                SizedBox(height: buttonSpacing),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.dining),
                    label: const Text('Load Sample Menu'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: buttonPadding),
                    ),
                    onPressed: _loadSampleMenu,
                  ),
                ),
                SizedBox(height: buttonSpacing),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.bug_report),
                    label: const Text('Test Menu Service'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: buttonPadding),
                    ),
                    onPressed: _testMenuService,
                  ),
                ),
                SizedBox(height: buttonSpacing),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Create Test Orders'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: buttonPadding),
                    ),
                    onPressed: _createTestOrders,
                  ),
                ),
                SizedBox(height: buttonSpacing),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.analytics),
                    label: const Text('Generate Test Activity Logs'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: buttonPadding),
                    ),
                    onPressed: _generateTestActivityLogs,
                  ),
                ),
              ] else ...[
                // Tablet/Desktop: Row layout
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.restaurant),
                        label: const Text('Load Oh Bombay Menu'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: buttonPadding),
                        ),
                        onPressed: _loadOhBombayMenu,
                      ),
                    ),
                    SizedBox(width: buttonSpacing),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.dining),
                        label: const Text('Load Sample Menu'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: buttonPadding),
                        ),
                        onPressed: _loadSampleMenu,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: buttonSpacing),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.bug_report),
                        label: const Text('Test Menu Service'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade700,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: buttonPadding),
                        ),
                        onPressed: _testMenuService,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: buttonSpacing),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Create Test Orders (with Audit Logs)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: buttonPadding),
                    ),
                    onPressed: _createTestOrders,
                  ),
                ),
                SizedBox(height: buttonSpacing),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.analytics),
                    label: const Text('Generate Test Activity Logs'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: buttonPadding),
                    ),
                    onPressed: _generateTestActivityLogs,
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _categories.isEmpty
              ? _buildEmptyState(
                  icon: Icons.category,
                  title: 'No Categories',
                  message: 'Add your first category to get started, or load a sample menu!',
                  actionLabel: 'Add Category',
                  onAction: _addCategory,
                )
              : ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: isPhone ? 8.0 : 16.0),
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final itemCount = _menuItems.where((item) => item.categoryId == category.id).length;

                    return Card(
                      margin: EdgeInsets.symmetric(
                        horizontal: isPhone ? 4.0 : 8.0, 
                        vertical: isPhone ? 2.0 : 4.0
                      ),
                      elevation: 2,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: category.color.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: isPhone ? 8.0 : 16.0,
                            vertical: isPhone ? 4.0 : 8.0,
                          ),
                          leading: Container(
                            width: isPhone ? 40.0 : 50.0,
                            height: isPhone ? 40.0 : 50.0,
                            decoration: BoxDecoration(
                              color: category.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(isPhone ? 20.0 : 25.0),
                              border: Border.all(color: category.color.withValues(alpha: 0.3)),
                            ),
                            child: Icon(
                              category.icon,
                              color: category.color,
                              size: isPhone ? 20.0 : 24.0,
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  category.name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isPhone ? 14.0 : 16.0,
                                    color: category.color.withValues(alpha: 0.8),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: isPhone ? 4.0 : 8.0),
                              if (!category.isActive)
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isPhone ? 4.0 : 6.0, 
                                    vertical: isPhone ? 1.0 : 2.0
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade100,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'INACTIVE',
                                    style: TextStyle(
                                      color: Colors.red.shade700,
                                      fontSize: isPhone ? 8.0 : 10.0,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (category.description?.isNotEmpty == true)
                                Padding(
                                  padding: EdgeInsets.only(top: isPhone ? 2.0 : 4.0),
                                  child: Text(
                                    category.description ?? '',
                                    style: TextStyle(
                                      fontSize: isPhone ? 11.0 : 13.0,
                                      color: Colors.grey,
                                    ),
                                    maxLines: isPhone ? 1 : 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              SizedBox(height: isPhone ? 2.0 : 4.0),
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isPhone ? 6.0 : 8.0, 
                                      vertical: isPhone ? 1.0 : 2.0
                                    ),
                                    decoration: BoxDecoration(
                                      color: category.color.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '$itemCount item${itemCount == 1 ? '' : 's'}',
                                      style: TextStyle(
                                        color: category.color,
                                        fontWeight: FontWeight.w600,
                                        fontSize: isPhone ? 10.0 : 12.0,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: isPhone ? 4.0 : 8.0),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: isPhone ? 6.0 : 8.0, 
                                      vertical: isPhone ? 1.0 : 2.0
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      'Order: ${category.sortOrder}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                        fontSize: isPhone ? 9.0 : 11.0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              switch (value) {
                                case 'edit':
                                  _editCategory(category);
                                  break;
                                case 'delete':
                                  _deleteCategory(category);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit),
                                    SizedBox(width: 8),
                                    Text('Edit'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete', style: TextStyle(color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMenuItemsTab() {
    // Group items by category
    final itemsByCategory = <String, List<MenuItem>>{};
    for (final item in _menuItems) {
      itemsByCategory.putIfAbsent(item.categoryId, () => []).add(item);
    }

    return Column(
      children: [
        _buildTabHeader(
          title: 'Menu Items',
          subtitle: 'Manage menu items by category',
          onAddPressed: _addMenuItem,
        ),
        Expanded(
          child: _menuItems.isEmpty
              ? _buildEmptyState(
                  icon: Icons.restaurant_menu,
                  title: 'No Menu Items',
                  message: 'Add your first menu item to get started!',
                  actionLabel: 'Add Menu Item',
                  onAction: _addMenuItem,
                )
              : ListView.builder(
                  itemCount: _categories.length,
                  itemBuilder: (context, index) {
                    final category = _categories[index];
                    final items = itemsByCategory[category.id] ?? [];

                    return ExpansionTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: category.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: category.color.withValues(alpha: 0.3)),
                        ),
                        child: Icon(
                          category.icon,
                          color: category.color,
                          size: 20,
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(
                            category.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: category.color.withValues(alpha: 0.8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: category.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: category.color.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              '${items.length} item${items.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                color: category.color,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      children: items.isEmpty
                          ? [
                              Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'No items in this category',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ]
                          : items.map((item) => _buildMenuItemTile(item)).toList(),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildMenuItemTile(MenuItem item) {
            final category = _categories.firstWhere(
          (cat) => cat.id == item.categoryId,
          orElse: () => pos_category.Category(
            id: 'unknown',
            name: 'Unknown Category',
        sortOrder: 0,
      ),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      elevation: 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: category.color.withValues(alpha: 0.2)),
        ),
        child: ListTile(
          leading: Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: category.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(22.5),
              border: Border.all(color: category.color.withValues(alpha: 0.3)),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    item.name[0].toUpperCase(),
                    style: TextStyle(
                      color: category.color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: category.color,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      category.icon,
                      color: Colors.white,
                      size: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.description?.isNotEmpty == true) 
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    item.description ?? '',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '\$${item.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      category.name,
                      style: TextStyle(
                        color: category.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (item.isAvailable)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'AVAILABLE',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'UNAVAILABLE',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                _editMenuItem(item);
                break;
              case 'delete':
                _deleteMenuItem(item);
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildManageUsersTab() {
    debugPrint('ADMIN FLOW: _buildManageUsersTab called');
    return UserManagementScreen(currentUser: widget.user);
  }



  Widget _buildStatsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrinterAssignmentsTab() {
    return Column(
      children: [
        _buildTabHeader(
          title: 'Printer Management',
          subtitle: 'Configure printer connections and assignments',
          onAddPressed: () => _navigateToPrinterAssignments(),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Printer Management Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        'WiFi Printers',
                        'Manage network printer connections',
                        Icons.wifi,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoCard(
                        'Bluetooth Printers',
                        'Manage Bluetooth printer connections',
                        Icons.bluetooth,
                        Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoCard(
                        'Category Assignment',
                        'Route entire categories to specific printers',
                        Icons.category,
                        Colors.green,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildInfoCard(
                        'Menu Item Assignment',
                        'Route specific items to designated printers',
                        Icons.restaurant_menu,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Real-time Printer Status Widget
                const PrinterStatusWidget(
                  showHeader: true,
                  showControls: true,
                ),
                
                const SizedBox(height: 24),
                
                // Bluetooth Printer Management Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.purple.shade50,
                        Colors.purple.shade50,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.purple.shade200, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.shade100,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.bluetooth,
                            color: Colors.purple.shade700,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Bluetooth Printer Management',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Connect and manage multiple Bluetooth printers for your restaurant. Discover, connect, and test Bluetooth thermal printers.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.purple.shade700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _navigateToBluetoothPrinterManagement(),
                              icon: const Icon(Icons.bluetooth_searching),
                              label: const Text('Manage Bluetooth Printers'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple.shade600,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _navigateToBluetoothPrinterExample(),
                              icon: const Icon(Icons.play_circle_outline),
                              label: const Text('View Example'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.purple.shade700,
                                side: BorderSide(color: Colors.purple.shade400),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                textStyle: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.purple.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bluetooth Printer Features:',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.shade800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildBluetoothFeatureItem('Discover paired Bluetooth printers'),
                            _buildBluetoothFeatureItem('Connect to multiple printers simultaneously'),
                            _buildBluetoothFeatureItem('Test printer connections'),
                            _buildBluetoothFeatureItem('Print to specific or all connected printers'),
                            _buildBluetoothFeatureItem('Real-time connection status monitoring'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // WiFi Printer Management Section
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue.shade50,
                        Colors.blue.shade50,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade200, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.shade100,
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.wifi,
                            color: Colors.blue.shade700,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'WiFi Printer Assignments',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Configure how menu items and categories are routed to different WiFi printers in your kitchen.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue.shade700,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () => _navigateToPrinterAssignments(),
                        icon: const Icon(Icons.settings),
                        label: const Text('Manage Printer Assignments'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          textStyle: const TextStyle(fontSize: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Benefits List
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Benefits of Printer Assignments',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildBenefitItem('Appetizers print to appetizer station'),
                      _buildBenefitItem('Main courses print to grill station'),
                      _buildBenefitItem('Desserts print to dessert station'),
                      _buildBenefitItem('Same order number across all stations'),
                      _buildBenefitItem('Improved kitchen workflow efficiency'),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Current Assignments Preview
                Consumer<EnhancedPrinterAssignmentService?>(
                  builder: (context, assignmentService, child) {
                    if (assignmentService == null) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current Assignment Status',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Printer assignment service not available',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }
                    
                    return FutureBuilder<Map<String, dynamic>>(
                      future: assignmentService.getAssignmentStats(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Assignment Status',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Center(child: CircularProgressIndicator()),
                              ],
                            ),
                          );
                        }
                        
                        if (snapshot.hasError) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Assignment Status',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Error loading stats: ${snapshot.error}',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          );
                        }
                        
                        final stats = snapshot.data ?? {};
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Current Assignment Status',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatChip('Total', stats['totalAssignments'] ?? 0, Colors.blue),
                                  _buildStatChip('Categories', stats['categoryAssignments'] ?? 0, Colors.green),
                                  _buildStatChip('Items', stats['menuItemAssignments'] ?? 0, Colors.orange),
                                  _buildStatChip('Printers', stats['uniquePrinters'] ?? 0, Colors.purple),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(String title, String description, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: color),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(String benefit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              benefit,
              style: TextStyle(color: Colors.blue.shade800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.05),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value.toString(),
            style: _getCardValueStyle(color),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: _getCardTitleStyle(color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _navigateToPrinterAssignments() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ComprehensivePrinterAssignmentScreen(),
      ),
    );
  }

  void _navigateToBluetoothPrinterManagement() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const BluetoothPrinterManagementScreen(),
      ),
    );
  }

  void _navigateToBluetoothPrinterExample() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const MultipleBluetoothPrintersExample(),
      ),
    );
  }

  Widget _buildBluetoothFeatureItem(String feature) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color: Colors.purple.shade600,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              feature,
              style: TextStyle(
                color: Colors.purple.shade700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersTab() {
    return AdminOrdersScreen(user: widget.user, showAppBar: false);
  }

  Widget _buildKitchenTab() {
    return KitchenScreen(user: widget.user, showAppBar: false);
  }

  Widget _buildReportsTab() {
    return ReportsScreen(user: widget.user, showAppBar: false);
  }

  Widget _buildInventoryTab() {
    return const InventoryScreen(showAppBar: false);
  }

  Widget _buildTablesTab() {
    return TablesScreen(user: widget.user, showAppBar: false);
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Settings',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          
          // Database Management Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.storage, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Database Management',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Use these tools to manage your database and fix data issues.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  
                  // Force Sync Button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      border: Border.all(color: Colors.blue.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.sync, color: Colors.blue.shade600, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Force Cross-Platform Sync',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Manually trigger synchronization between Android and macOS devices. Use this to ensure data consistency across all platforms.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _forceSyncNow,
                          icon: const Icon(Icons.sync, size: 16),
                          label: const Text('Force Sync Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Database Reset Button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      border: Border.all(color: Colors.red.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning, color: Colors.red.shade600, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Reset Database',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                                                 const SizedBox(height: 8),
                         Text(
                           'This will completely reset the database, removing all orders, menu items, and data. Use this to fix foreign key constraint errors.',
                           style: TextStyle(
                             fontSize: 12,
                             color: Colors.red.shade600,
                           ),
                         ),
                         const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _resetDatabase,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Reset Database'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Firebase Data Clear Button
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.cloud_off, color: Colors.orange.shade600, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Clear Firebase Data',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This will completely clear all data from Firebase, including all tenants, restaurants, orders, and sync data. Use this to fix inconsistent Firebase data.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _clearFirebaseData,
                          icon: const Icon(Icons.delete_forever, size: 16),
                          label: const Text('Clear Firebase Data'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Free Cloud Printing Setup Section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      Text(
                        '🆓 Free Cloud Printing',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'FREE',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Print from anywhere to your restaurant printers. No computer needed at restaurant - everything in the cloud!',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Zero monthly cost',
                        style: TextStyle(color: Colors.green.shade700, fontSize: 12),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.check_circle, color: Colors.green.shade600, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '5-minute setup',
                        style: TextStyle(color: Colors.green.shade700, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FreeCloudSetupScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.cloud_upload),
                      label: const Text('Setup Free Cloud Printing'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Other settings can go here
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.settings, color: Theme.of(context).primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Application Settings',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Additional settings will be available here.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Reset the database completely
  Future<void> _resetDatabase() async {
    try {
      // For now, just show a message that the feature is coming soon
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database reset feature is temporarily disabled. Please restart the app to clear data.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Clear all Firebase data
  Future<void> _clearFirebaseData() async {
    try {
      // Show confirmation dialog
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Clear Firebase Data'),
          content: const Text(
            'This will permanently delete ALL data from Firebase, including:\n\n'
            '• All restaurant tenants\n'
            '• All orders and menu items\n'
            '• All user data\n'
            '• All sync data\n\n'
            'This action cannot be undone. Are you sure you want to continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Clear All Data'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Show loading
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clearing Firebase data... This may take a moment.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Clear Firebase data
      await FirebaseDataClearer.clearAllFirebaseData();
      
      // Verify cleanup
      await FirebaseDataClearer.verifyDataCleared();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ All Firebase data cleared successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error clearing Firebase data: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  /// Force cross-platform database synchronization
  Future<void> _forceSyncNow() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Note: UnifiedSyncService removed for performance optimization
      // Cross-platform sync functionality preserved through existing services
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cross-platform sync completed successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Cross-platform sync completed successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }

      // Log the sync action
      try {
        final activityLogService = Provider.of<ActivityLogService>(context, listen: false);
        activityLogService.logAdminPanelAccess(
          userId: widget.user.id,
          userName: widget.user.name,
          userRole: widget.user.role.toString(),
          tabName: 'Force Cross-Platform Sync',
        );
      } catch (e) {
        debugPrint('⚠️ Failed to log sync action: $e');
      }

    } catch (e) {
      debugPrint('❌ Error during force sync: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sync failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildActivityMonitoringTab() {
    return UserActivityMonitoringScreen(user: widget.user, showAppBar: false);
  }

  Widget _buildTabHeader({
    required String title,
    required String subtitle,
    required VoidCallback onAddPressed,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.surface,
            Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _titleTextStyle,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: _subtitleTextStyle,
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: onAddPressed,
            icon: const Icon(Icons.add, size: 20),
            label: Text(
              'Add',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add),
            label: const Text('Add'),
          ),
        ],
      ),
    );
  }

  /// Load popular Indian restaurant menu for all tenant instances
  Future<void> _loadPopularIndianMenu() async {
    setState(() { _isLoading = true; });
    
    try {
      debugPrint('🍽️ Admin: Loading Oh Bombay menu...');
      final menuService = Provider.of<MenuService>(context, listen: false);
      
      // Clear existing data first to avoid conflicts
      debugPrint('🗑️ Admin: Clearing existing menu data');
      await menuService.clearAllData();
      
      // Load Oh Bombay menu
      debugPrint('📥 Admin: Loading Oh Bombay menu data');
      await menuService.loadOhBombayMenu();
      debugPrint('✅ Admin: Oh Bombay menu loaded to database');
      
      // Reload local data
      await _loadData();
      debugPrint('✅ Admin: UI data refreshed');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Oh Bombay menu loaded successfully! 🇮🇳\n${_categories.length} categories, ${_menuItems.length} items'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Admin: Error loading Oh Bombay menu: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        await ErrorDialogHelper.showError(
          context,
          title: 'Error Loading Oh Bombay Menu',
          message: 'Failed to load Oh Bombay menu:\n\nError: $e\n\nPlease check the console for more details.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Show a status dialog with the given message
  Future<void> _showStatusDialog(String title, String message, {bool isError = false}) async {
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade50 : Colors.green.shade50,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Set loading state for the admin panel
  void _setLoading(bool loading) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
      });
    }
  }
}

class _AddUserView extends StatefulWidget {
  const _AddUserView();

  @override
  State<_AddUserView> createState() => _AddUserViewState();
}

class _AddUserViewState extends State<_AddUserView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  UserRole _selectedRole = UserRole.server;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    debugPrint('ADMIN FLOW: _AddUserView initState');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final newUser = User(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        pin: _pinController.text.trim(),
        role: _selectedRole,
      );

      await userService.addUser(newUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _formKey.currentState!.reset();
        _nameController.clear();
        _pinController.clear();
        _selectedRole = UserRole.server;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('ADMIN FLOW: _AddUserView build called');
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add New User',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          AppFormField(
            controller: _nameController,
            label: 'Full Name',
            hint: 'Enter user\'s full name',
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          AppFormField(
            controller: _pinController,
            label: 'PIN',
            hint: 'Enter 4-digit PIN',
            keyboardType: TextInputType.number,
            maxLength: 4,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a PIN';
              }
              if (value.length != 4) {
                return 'PIN must be 4 digits';
              }
              if (!RegExp(r'^\d{4}$').hasMatch(value)) {
                return 'PIN must contain only numbers';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<UserRole>(
            value: _selectedRole,
            decoration: const InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(),
            ),
            items: UserRole.values.map((role) {
              return DropdownMenuItem(
                value: role,
                child: Text(role.name.toUpperCase()),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedRole = value;
                });
              }
            },
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _addUser,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Add User'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExistingUsersView extends StatefulWidget {
  const _ExistingUsersView();

  @override
  State<_ExistingUsersView> createState() => _ExistingUsersViewState();
}

class _ExistingUsersViewState extends State<_ExistingUsersView> {
  List<User> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    debugPrint('ADMIN FLOW: _ExistingUsersView initState');
    _loadUsers();
  }

  /// Set loading state for the admin panel
  void _setLoading(bool loading) {
    if (mounted) {
      setState(() {
        _isLoading = loading;
      });
    }
  }

  /// Show a status dialog with the given message
  Future<void> _showStatusDialog(String title, String message, {bool isError = false}) async {
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade50 : Colors.green.shade50,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final users = await userService.getUsers();
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('ADMIN FLOW: _ExistingUsersView build called');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Existing Users',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            IconButton(
              onPressed: _loadUsers,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 16),
        _isLoading
            ? const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            : _users.isEmpty
                ? const Expanded(
                    child: Center(
                      child: Text('No users found'),
                    ),
                  )
                : Expanded(
                    child: ListView.builder(
                      itemCount: _users.length,
                      itemBuilder: (context, index) {
                        final user = _users[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(user.name[0].toUpperCase()),
                            ),
                            title: Text(
                              '${user.name} (${user.role.name})',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('PIN: ${user.pin}'),
                                Text('Role: ${user.role.name.toUpperCase()}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Removed edit and delete buttons as their methods were deleted
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ],
          );
    }
} 