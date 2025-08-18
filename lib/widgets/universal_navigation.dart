import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../models/printer_assignment.dart';
import '../services/order_service.dart';
import '../services/reservation_service.dart';
import '../services/printing_service.dart';
import '../services/enhanced_printer_assignment_service.dart';
import '../screens/order_type_selection_screen.dart';
import '../screens/admin_panel_screen.dart';
import '../screens/kitchen_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/admin_orders_screen.dart';
import '../screens/daily_bookings_screen.dart';
import '../screens/reservations_screen.dart';

// Printer selection now handled by UnifiedPrinterDashboard
import '../screens/unified_printer_dashboard.dart';

import '../screens/restaurant_auth_screen.dart';
import '../screens/bluetooth_printer_management_screen.dart';

/// Universal navigation widget that provides consistent navigation across all screens
class UniversalNavigation extends StatelessWidget implements PreferredSizeWidget {
  final User? currentUser;
  final String currentScreenTitle;
  final VoidCallback? onBack;
  final List<Widget>? additionalActions;
  final bool showQuickActions;
  final bool isFullscreen;

  const UniversalNavigation({
    super.key,
    this.currentUser,
    required this.currentScreenTitle,
    this.onBack,
    this.additionalActions,
    this.showQuickActions = true,
    this.isFullscreen = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isFullscreen) {
      return _buildFullscreenNavigation(context);
    }

    return AppBar(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Screen title on the left
          Expanded(
            child: Text(
              currentScreenTitle,
              textAlign: TextAlign.left,
            ),
          ),
          // Central POS Dashboard button
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () => _navigateToPOSDashboard(context),
              icon: const Icon(Icons.dashboard, size: 18),
              label: const Text('POS Dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          // Spacer to balance the layout
          const Expanded(child: SizedBox()),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      elevation: 2,
      leading: _buildLeadingWidget(context),
      actions: [
        if (showQuickActions) ..._buildQuickActions(context),
        if (additionalActions != null) ...additionalActions!,
        const SizedBox(width: 8),
        _buildNavigationMenu(context),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget? _buildLeadingWidget(BuildContext context) {
    if (onBack != null) {
      return IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: onBack,
        tooltip: 'Back',
      );
    }

    // Check if we can go back
    if (Navigator.of(context).canPop()) {
      return IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.of(context).pop(),
        tooltip: 'Back',
      );
    }

    return null;
  }

  Widget _buildFullscreenNavigation(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.inversePrimary,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          if (onBack != null || Navigator.of(context).canPop()) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onBack ?? () => Navigator.of(context).pop(),
              tooltip: 'Back',
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              currentScreenTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          // Central POS Dashboard button for fullscreen mode
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () => _navigateToPOSDashboard(context),
              icon: const Icon(Icons.dashboard, size: 16),
              label: const Text('POS Dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          if (showQuickActions) ..._buildQuickActions(context),
          if (additionalActions != null) ...additionalActions!,
          const SizedBox(width: 8),
          _buildNavigationMenu(context),
          const SizedBox(width: 16),
        ],
      ),
    );
  }

  List<Widget> _buildQuickActions(BuildContext context) {
    List<Widget> actions = [];

    // Active Orders Action
    actions.add(
      Consumer<OrderService>(
        builder: (context, orderService, child) {
          final activeOrdersCount = orderService.activeOrders.length;
          return Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.receipt_long),
                onPressed: () => _navigateToActiveOrders(context),
                tooltip: 'Active Orders',
              ),
              if (activeOrdersCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 14,
                      minHeight: 14,
                    ),
                    child: Text(
                      '$activeOrdersCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );

    // Reservations Action (for servers and admins)
    if (currentUser?.role == UserRole.admin || 
        currentUser?.role == UserRole.server) {
      actions.add(
        Consumer<ReservationService>(
          builder: (context, reservationService, child) {
            final todaysReservations = reservationService.reservations
                .where((r) => r.reservationDate.day == DateTime.now().day &&
                             r.reservationDate.month == DateTime.now().month &&
                             r.reservationDate.year == DateTime.now().year)
                .toList();
            final pendingCount = todaysReservations
                .where((r) => r.status == 'pending' || r.status == 'confirmed')
                .length;
            
            return Stack(
              children: [
                IconButton(
                  icon: const Icon(Icons.event_seat),
                  onPressed: () => _navigateToReservations(context),
                  tooltip: 'Reservations',
                ),
                if (pendingCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    // Printer features removed - only accessible via Admin Panel

    return actions;
  }

  Widget _buildNavigationMenu(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu),
      tooltip: 'Navigation Menu',
      onSelected: (value) => _handleMenuSelection(context, value),
      itemBuilder: (context) => [
        // Core Navigation
        const PopupMenuItem(
          value: 'home',
          child: ListTile(
            leading: Icon(Icons.home),
            title: Text('Home'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'new_order',
          child: ListTile(
            leading: Icon(Icons.add_circle_outline),
            title: Text('New Order'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'active_orders',
          child: ListTile(
            leading: Icon(Icons.receipt_long),
            title: Text('Active Orders'),
            dense: true,
          ),
        ),
        
        // Separator
        const PopupMenuDivider(),
        
        // Server Functions
        if (currentUser?.role == UserRole.admin || currentUser?.role == UserRole.server) ...[
          const PopupMenuItem(
            value: 'reservations',
            child: ListTile(
              leading: Icon(Icons.event_seat),
              title: Text('Reservations'),
              dense: true,
            ),
          ),
          const PopupMenuItem(
            value: 'daily_bookings',
            child: ListTile(
              leading: Icon(Icons.today),
              title: Text('Today\'s Bookings'),
              dense: true,
            ),
          ),
        ],
        
        // Kitchen Functions
        if (currentUser?.role == UserRole.admin || currentUser?.role == UserRole.manager) ...[
          const PopupMenuItem(
            value: 'kitchen',
            child: ListTile(
              leading: Icon(Icons.kitchen),
              title: Text('Kitchen'),
              dense: true,
            ),
          ),
        ],
        
        // Admin Functions
        if (currentUser?.role == UserRole.admin) ...[
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: 'admin_panel',
            child: ListTile(
              leading: Icon(Icons.admin_panel_settings),
              title: Text('Admin Panel'),
              dense: true,
            ),
          ),
          const PopupMenuItem(
            value: 'reports',
            child: ListTile(
              leading: Icon(Icons.analytics),
              title: Text('Reports & Analytics'),
              dense: true,
            ),
          ),
        ],
        
        // Separator
        const PopupMenuDivider(),
        
        // Enhanced Printer Settings
        const PopupMenuItem(
          value: 'printer_connection',
          child: ListTile(
            leading: Icon(Icons.wifi),
            title: Text('Printer Connection'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'printer_assignments',
          child: ListTile(
            leading: Icon(Icons.assignment),
            title: Text('Printer Assignments'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'bluetooth_printers',
          child: ListTile(
            leading: Icon(Icons.bluetooth),
            title: Text('Bluetooth Printers'),
            dense: true,
          ),
        ),
        
        // System Functions
        const PopupMenuItem(
          value: 'switch_server',
          child: ListTile(
            leading: Icon(Icons.switch_account),
            title: Text('Switch Server'),
            dense: true,
          ),
        ),
        const PopupMenuItem(
          value: 'logout',
          child: ListTile(
            leading: Icon(Icons.logout, color: Colors.red),
            title: Text('Logout', style: TextStyle(color: Colors.red)),
            dense: true,
          ),
        ),
      ],
    );
  }



  void _handleMenuSelection(BuildContext context, String value) {
    switch (value) {
      case 'home':
        _navigateToHome(context);
        break;
      case 'new_order':
        _navigateToNewOrder(context);
        break;
      case 'active_orders':
        _navigateToActiveOrders(context);
        break;
      case 'reservations':
        _navigateToReservations(context);
        break;
      case 'daily_bookings':
        _navigateToDailyBookings(context);
        break;
      case 'kitchen':
        _navigateToKitchen(context);
        break;
      case 'admin_panel':
        _navigateToAdminPanel(context);
        break;
      case 'reports':
        _navigateToReports(context);
        break;
      case 'printer_connection':
        _navigateToPrinterConnection(context);
        break;
      case 'printer_assignments':
        _navigateToPrinterAssignments(context);
        break;
      case 'bluetooth_printers':
        _navigateToBluetoothPrinters(context);
        break;
      case 'switch_server':
        // Navigate to landing screen instead of server selection
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const RestaurantAuthScreen(),
          ),
          (route) => false,
        );
        break;
      case 'logout':
        _performLogout(context);
        break;
    }
  }

  // Navigation methods
  void _navigateToHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const OrderTypeSelectionScreen(),
      ),
      (route) => false,
    );
  }

  void _navigateToNewOrder(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const OrderTypeSelectionScreen(),
      ),
      (route) => false,
    );
  }

  void _navigateToPOSDashboard(BuildContext context) {
    // Navigate to the main POS dashboard (OrderTypeSelectionScreen)
    if (currentUser != null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const OrderTypeSelectionScreen(),
        ),
        (route) => false,
      );
    } else {
      // If no user is available, go to landing screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const RestaurantAuthScreen(),
        ),
        (route) => false,
      );
    }
  }

  void _navigateToActiveOrders(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminOrdersScreen(user: currentUser!),
      ),
    );
  }

  void _navigateToReservations(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReservationsScreen(),
      ),
    );
  }

  void _navigateToDailyBookings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const DailyBookingsScreen(),
      ),
    );
  }

  void _navigateToKitchen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => KitchenScreen(user: currentUser!),
      ),
    );
  }

  void _navigateToAdminPanel(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminPanelScreen(user: currentUser!),
      ),
    );
  }

  void _navigateToReports(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportsScreen(user: currentUser!),
      ),
    );
  }



  // Enhanced printer navigation methods
  void _navigateToPrinterConnection(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UnifiedPrinterDashboard(),
      ),
    );
  }

  void _navigateToPrinterAssignments(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const UnifiedPrinterDashboard(),
    ),
  );
}

  void _navigateToBluetoothPrinters(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BluetoothPrinterManagementScreen(),
      ),
    );
  }

  void _navigateToPrinterIPConfig(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const UnifiedPrinterDashboard(),
      ),
    );
  }

  void _showPrinterAssignmentsSummary(BuildContext context) {
    final assignmentService = Provider.of<EnhancedPrinterAssignmentService?>(context, listen: false);
    final assignments = assignmentService?.assignments ?? [];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.assignment, color: Colors.blue),
            SizedBox(width: 8),
            Text('Printer Assignments Summary'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: assignments.isEmpty
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.assignment_outlined, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No printer assignments configured'),
                    SizedBox(height: 8),
                    Text(
                      'Use the drag-and-drop interface to assign categories and menu items to printers',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: assignments.length,
                  itemBuilder: (context, index) {
                    final assignment = assignments[index];
                    return ListTile(
                      leading: Icon(
                        assignment.assignmentType == AssignmentType.category
                            ? Icons.category
                            : Icons.restaurant_menu,
                        color: assignment.assignmentType == AssignmentType.category
                            ? Colors.green
                            : Colors.orange,
                      ),
                      title: Text(assignment.targetName),
                      subtitle: Text(
                        'Printer: ${assignment.printerName}\n'
                        'Priority: ${assignment.priority}',
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: assignment.isActive ? Colors.green.shade100 : Colors.red.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          assignment.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 10,
                            color: assignment.isActive ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                      ),
                      isThreeLine: true,
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (assignments.isNotEmpty) ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _navigateToPrinterAssignments(context);
              },
              icon: const Icon(Icons.edit),
              label: const Text('Manage'),
            ),
          ] else ...[
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _navigateToPrinterAssignments(context);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Assignments'),
            ),
          ],
        ],
      ),
    );
  }

  void _performTestPrint(BuildContext context) async {
    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      
      if (!printingService.isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 8),
                Text('No printer connected'),
              ],
            ),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Connect',
              textColor: Colors.white,
              onPressed: () => _navigateToPrinterConnection(context),
            ),
          ),
        );
        return;
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Printing test receipt...'),
            ],
          ),
        ),
      );

      await printingService.printTestReceipt();
      
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('Test receipt printed to ${printingService.connectedPrinter?.name}'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Print test failed: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _performTestPrint(context),
            ),
          ),
        );
      }
    }
  }

  void _performLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (context) => const RestaurantAuthScreen(),
                ),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Universal AppBar that delegates to UniversalNavigation
class UniversalAppBar extends StatelessWidget implements PreferredSizeWidget {
  final User? currentUser;
  final String title;
  final VoidCallback? onBack;
  final List<Widget>? additionalActions;
  final bool showQuickActions;
  final PreferredSizeWidget? bottom;

  const UniversalAppBar({
    super.key,
    this.currentUser,
    required this.title,
    this.onBack,
    this.additionalActions,
    this.showQuickActions = true,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    // Return the AppBar from UniversalNavigation build method
    return AppBar(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Screen title on the left
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.left,
            ),
          ),
          // Central POS Dashboard button
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () => _navigateToPOSDashboard(context),
              icon: const Icon(Icons.dashboard, size: 18),
              label: const Text('POS Dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                elevation: 2,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          // Spacer to balance the layout
          const Expanded(child: SizedBox()),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      elevation: 2,
      leading: onBack != null 
        ? IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onBack,
            tooltip: 'Go Back',
          )
        : Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
                tooltip: 'Go Back',
              )
            : null,
      actions: [
        // Use the same printer actions from the main navigation
        if (showQuickActions) ..._buildSimplifiedQuickActions(context),
        if (additionalActions != null) ...additionalActions!,
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          icon: const Icon(Icons.menu),
          tooltip: 'Navigation Menu',
          onSelected: (value) => _handleSimpleNavigation(context, value),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'printer_connection',
              child: ListTile(
                leading: Icon(Icons.wifi),
                title: Text('Printer Connection'),
                dense: true,
              ),
            ),
            const PopupMenuItem(
              value: 'printer_assignments',
              child: ListTile(
                leading: Icon(Icons.assignment),
                title: Text('Printer Assignments'),
                dense: true,
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
      ],
    );
  }

  List<Widget> _buildSimplifiedQuickActions(BuildContext context) {
    final actions = <Widget>[];

    // Add basic actions that don't require complex state
    actions.add(
      IconButton(
        icon: const Icon(Icons.settings),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UnifiedPrinterDashboard(),
            ),
          );
        },
        tooltip: 'Printer Settings',
      ),
    );

    return actions;
  }

  void _handleSimpleNavigation(BuildContext context, String value) {
    switch (value) {
      case 'printer_connection':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const UnifiedPrinterDashboard(),
          ),
        );
        break;
      case 'printer_assignments':
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const UnifiedPrinterDashboard(),
          ),
        );
        break;
    }
  }

  void _navigateToPOSDashboard(BuildContext context) {
    // Navigate to the main POS dashboard (OrderTypeSelectionScreen)
    if (currentUser != null) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const OrderTypeSelectionScreen(),
        ),
        (route) => false,
      );
    } else {
      // If no user is available, go to landing screen
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => const RestaurantAuthScreen(),
        ),
        (route) => false,
      );
    }
  }

  @override
  Size get preferredSize => Size.fromHeight(
    kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
  );
}