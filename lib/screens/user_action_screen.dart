import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../services/settings_service.dart';
import '../services/table_service.dart';
import '../widgets/user_profile_card.dart';
import '../widgets/action_card.dart';
import '../widgets/error_dialog.dart';
import '../widgets/universal_navigation.dart';
import 'categories_screen.dart';
import 'tables_screen.dart';

import 'manage_menu_items_screen.dart';
import 'settings_screen.dart';
import 'users_screen.dart';
import 'manage_categories_screen.dart';
import 'admin_panel_screen.dart';
import 'admin_orders_screen.dart';
import 'kitchen_screen.dart';
import 'reports_screen.dart';
import 'inventory_screen.dart';


/// Main screen that displays user actions and navigation options.
/// 
/// This screen serves as the hub for all user interactions in the POS system.
class UserActionScreen extends StatelessWidget {
  final User user;

  const UserActionScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final settingsService = Provider.of<SettingsService>(context);
    final isAdmin = user.role == UserRole.admin;

    return Scaffold(
      appBar: _buildAppBar(context, isAdmin),
      body: _buildBody(context, settingsService, isAdmin),
      floatingActionButton: _buildFloatingActionButton(context),
    );
  }

  /// Builds the app bar with user info and settings button.
  PreferredSizeWidget _buildAppBar(BuildContext context, bool isAdmin) {
    return UniversalAppBar(
      currentUser: user,
      title: 'Welcome, ${user.name}',
      additionalActions: [
        if (isAdmin)
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _navigateToSettings(context),
            tooltip: 'Settings',
          ),
      ],
      showQuickActions: true, // Show all quick actions since this is the main hub
    );
  }

  /// Builds the main body content.
  Widget _buildBody(BuildContext context, SettingsService settingsService, bool isAdmin) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UserProfileCard(
            user: user,
            onTap: () {}, // No action needed for display only
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _buildActionGrid(context, settingsService, isAdmin),
          ),
        ],
      ),
    );
  }

  /// Builds the grid of action cards.
  Widget _buildActionGrid(BuildContext context, SettingsService settingsService, bool isAdmin) {
    final actions = <Widget>[
      // Core actions for all users
      NavigationActionCard(
        title: 'Tables',
        icon: Icons.table_restaurant,
        color: Colors.blue,
        onTap: () => _navigateToTables(context),
        subtitle: 'Manage restaurant tables',
      ),
      NavigationActionCard(
        title: 'Menu',
        icon: Icons.restaurant_menu,
        color: Colors.green,
        onTap: () => _navigateToCategories(context),
        subtitle: 'Browse menu categories',
      ),
    ];

    // Admin-only actions
    if (isAdmin) {
      // Core admin functions
      actions.addAll([
        NavigationActionCard(
          title: 'Admin Panel',
          icon: Icons.admin_panel_settings,
          color: Colors.purple,
          onTap: () => _navigateToAdminPanel(context),
          subtitle: 'Complete admin management',
        ),
        NavigationActionCard(
          title: 'Admin Orders',
          icon: Icons.receipt_long,
          color: Colors.deepPurple,
          onTap: () => _navigateToAdminOrders(context),
          subtitle: 'View and manage all orders',
        ),
        NavigationActionCard(
          title: 'Kitchen',
          icon: Icons.kitchen,
          color: Colors.red,
          onTap: () => _navigateToKitchen(context),
          subtitle: 'Kitchen management screen',
        ),
        NavigationActionCard(
          title: 'Reports',
          icon: Icons.analytics,
          color: Colors.indigo,
          onTap: () => _navigateToReports(context),
          subtitle: 'Sales reports and analytics',
        ),
      ]);

      // Optional admin functions based on settings
      if (settingsService.isUserManagementEnabled) {
        actions.add(
          NavigationActionCard(
            title: 'Users',
            icon: Icons.people,
            color: Colors.orange,
            onTap: () => _navigateToUsers(context),
            subtitle: 'Manage system users',
          ),
        );
      }

      if (settingsService.isCategoryManagementEnabled) {
        actions.add(
          NavigationActionCard(
            title: 'Categories',
            icon: Icons.category,
            color: Colors.teal,
            onTap: () => _navigateToManageCategories(context),
            subtitle: 'Manage menu categories',
          ),
        );
      }

      if (settingsService.isMenuItemManagementEnabled) {
        actions.add(
          NavigationActionCard(
            title: 'Menu Items',
            icon: Icons.edit,
            color: Colors.amber,
            onTap: () => _navigateToManageMenuItems(context),
            subtitle: 'Manage menu items',
          ),
        );
      }

      // Additional admin tools
      actions.add(
        NavigationActionCard(
          title: 'Inventory',
          icon: Icons.inventory,
          color: Colors.brown,
          onTap: () => _navigateToInventory(context),
          subtitle: 'Manage stock and ingredients',
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine grid layout based on screen size and number of actions
        int crossAxisCount;
        double childAspectRatio;
        
        if (constraints.maxWidth > 800) {
          crossAxisCount = 4;
          childAspectRatio = 1.0;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 3;
          childAspectRatio = 1.0;
        } else {
          crossAxisCount = 2;
          childAspectRatio = 1.1;
        }

        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: childAspectRatio,
          children: actions,
        );
      },
    );
  }

  /// Builds the floating action button for creating tables.
  Widget _buildFloatingActionButton(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showCreateTableDialog(context),
      tooltip: 'Create Table',
      child: const Icon(Icons.add),
    );
  }

  /// Shows a dialog for creating a new table.
  void _showCreateTableDialog(BuildContext context) {
    final TextEditingController numberController = TextEditingController();
    final TextEditingController capacityController = TextEditingController();
    capacityController.text = '4'; // Default capacity

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Table'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberController,
              decoration: const InputDecoration(
                labelText: 'Table Number',
                hintText: 'Enter table number',
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: capacityController,
              decoration: const InputDecoration(
                labelText: 'Table Capacity',
                hintText: 'Enter table capacity',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text('Create'),
            onPressed: () => _createTable(context, numberController, capacityController),
          ),
        ],
      ),
    );
  }

  /// Creates a new table with validation and error handling.
  Future<void> _createTable(
    BuildContext context,
    TextEditingController numberController,
    TextEditingController capacityController,
  ) async {
    final number = int.tryParse(numberController.text);
    final capacity = int.tryParse(capacityController.text);

    if (number == null || capacity == null) {
      await ErrorDialogHelper.showValidationError(
        context,
        message: 'Please enter valid numbers for table number and capacity.',
      );
      return;
    }

    if (number <= 0 || capacity <= 0) {
      await ErrorDialogHelper.showValidationError(
        context,
        message: 'Table number and capacity must be positive numbers.',
      );
      return;
    }

    try {
      final tableService = Provider.of<TableService>(context, listen: false);
      await tableService.createTable(number, capacity, userId: user.id);
      
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Table created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        await ErrorDialogHelper.showError(
          context,
          title: 'Error Creating Table',
          message: 'Failed to create table: $e',
        );
      }
    }
  }

  // Navigation methods
  void _navigateToSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SettingsScreen(),
      ),
    );
  }

  void _navigateToTables(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TablesScreen(user: user),
      ),
    );
  }

  void _navigateToCategories(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoriesScreen(user: user),
      ),
    );
  }

  void _navigateToUsers(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UsersScreen(),
      ),
    );
  }



  void _navigateToManageMenuItems(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManageMenuItemsScreen(),
      ),
    );
  }

  void _navigateToManageCategories(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ManageCategoriesScreen(user: user),
      ),
    );
  }



  void _navigateToAdminOrders(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminOrdersScreen(user: user),
      ),
    );
  }

  void _navigateToKitchen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KitchenScreen(user: user),
      ),
    );
  }

  void _navigateToReports(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportsScreen(user: user),
      ),
    );
  }

  void _navigateToInventory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const InventoryScreen(),
      ),
    );
  }

  void _navigateToAdminPanel(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminPanelScreen(user: user),
      ),
    );
  }


} 