import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../services/order_service.dart';
import '../services/user_service.dart';
import '../services/table_service.dart';
import '../services/database_service.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/error_dialog.dart';
import '../widgets/back_button.dart';
import 'order_creation_screen.dart';
import 'order_audit_screen.dart';
import '../services/order_log_service.dart'; // Added import for OrderLogService
import '../services/multi_tenant_auth_service.dart'; // Added import for MultiTenantAuthService
import '../services/unified_sync_service.dart'; // Added import for UnifiedSyncService

class AdminOrdersScreen extends StatefulWidget {
  final User user;
  final bool showAppBar;

  const AdminOrdersScreen({super.key, required this.user, this.showAppBar = true});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  bool _isLoading = false;
  String? _error;
  List<Order> _allOrders = [];
  String _searchQuery = '';
  OrderStatus? _statusFilter;
  OrderType? _typeFilter;
  bool _showActiveOnly = true;  // Default to active only to match "All Servers" view





  @override
  void initState() {
    super.initState();
    // Defer loading until after the build is complete
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrders();
    });
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orderService = Provider.of<OrderService>(context, listen: false);
      
      // Add explicit logging to show tenant database usage
      final authService = Provider.of<MultiTenantAuthService>(context, listen: false);
      final currentRestaurant = authService.currentRestaurant;
      if (currentRestaurant != null) {
        debugPrint('🏪 Admin Orders Screen: Loading orders for restaurant: ${currentRestaurant.name} (${currentRestaurant.email})');
        debugPrint('🏪 Admin Orders Screen: Using tenant database: ${currentRestaurant.databaseName}');
      } else {
        debugPrint('⚠️ Admin Orders Screen: No current restaurant - using default database');
      }
      
      // 🚫 CRITICAL FIX: Use existing orders if available to avoid ghost order cleanup interference
      List<Order> orders;
      if (orderService.allOrders.isNotEmpty) {
        debugPrint('📋 Admin Orders Screen: Using existing loaded orders (${orderService.allOrders.length}) to avoid reload interference');
        orders = orderService.allOrders;
      } else {
        debugPrint('📋 Admin Orders Screen: Loading orders from database (first time)');
        await orderService.loadOrders();
        orders = orderService.allOrders;
      }
      
      debugPrint('📋 Admin Orders Screen: Using ${orders.length} orders for admin panel');
      
      if (mounted) {
        setState(() {
          _allOrders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load orders.\n\nError: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _syncOrders() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final unifiedSyncService = Provider.of<UnifiedSyncService>(context, listen: false);
      
      debugPrint('🔄 Admin Orders Screen: Triggering manual sync...');
      await unifiedSyncService.manualSync();
      
      // Reload orders after sync
      await _loadOrders();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Orders synchronized with Firebase'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to sync orders.\n\nError: ${e.toString()}';
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Sync failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Order> get _filteredOrders {
    var filtered = _allOrders.where((order) {
      // Active Only filter (like "All Servers" view)
      if (_showActiveOnly && !order.isActive) {
        return false;
      }

      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesSearch = order.orderNumber.toLowerCase().contains(query) ||
            order.customerName?.toLowerCase().contains(query) == true ||
            order.items.any((item) => 
                item.menuItem.name.toLowerCase().contains(query));
        if (!matchesSearch) return false;
      }

      // Status filter
      if (_statusFilter != null && order.status != _statusFilter) {
        return false;
      }

      // Type filter
      if (_typeFilter != null && order.type != _typeFilter) {
        return false;
      }

      return true;
    }).toList();

    // Sort by date/time with latest orders on top
    filtered.sort((a, b) {
      // Primary sort: by orderTime (latest first)
      final orderTimeComparison = b.orderTime.compareTo(a.orderTime);
      if (orderTimeComparison != 0) return orderTimeComparison;
      
      // Secondary sort: by createdAt if orderTime is the same (latest first)
      return b.createdAt.compareTo(a.createdAt);
    });

    return filtered;
  }

  // Get server name who cancelled the order
  String? _getCancelledByServerName(Order order) {
    if (order.status != OrderStatus.cancelled) return null;
    
    // Find the last history entry with cancelled status
    final cancelHistory = order.history
        .where((h) => h.status == OrderStatus.cancelled)
        .lastOrNull;
    
    return cancelHistory?.updatedBy;
  }

  // Get server name from user ID
  String? _getServerNameFromId(String? userId) {
    if (userId == null) return null;
    
    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final user = userService.getUserById(userId);
      return user?.name;
    } catch (e) {
      return userId; // Return ID if name lookup fails
    }
  }

  Future<void> _viewOrderDetails(Order order) async {
    await showDialog(
      context: context,
      builder: (context) => _OrderDetailsDialog(order: order),
    );
  }

  Future<void> _editOrder(Order order) async {
    // Check if order is closed/completed
    if (order.status == OrderStatus.completed || order.status == OrderStatus.cancelled) {
      await ErrorDialogHelper.showValidationError(
        context,
        message: 'Cannot edit ${order.status.name} orders.',
      );
      return;
    }

    try {
      final userService = Provider.of<UserService?>(context, listen: false);
      
      if (userService == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Services are still loading. Please wait a moment.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      // Find the user who created the order or use admin as fallback
      User? orderUser;
      try {
        orderUser = userService.users.firstWhere((user) => user.id == order.userId);
      } catch (e) {
        // If original user not found, use admin or first available user
        try {
          orderUser = userService.users.firstWhere(
            (user) => user.role == UserRole.admin,
          );
        } catch (e) {
          // If no admin found, use first available user
          if (userService.users.isNotEmpty) {
            orderUser = userService.users.first;
          }
        }
      }
      
      if (orderUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Unable to edit order: No valid user found'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      debugPrint('🔍 ADMIN: Editing order ${order.orderNumber} with user ${orderUser.name} (${orderUser.id})');
      
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderCreationScreen(
            user: orderUser!,
            orderType: order.type == OrderType.dineIn ? 'dine-in' : 'takeout',
            existingOrder: order, // Pass the existing order for editing
            table: order.tableId != null ? 
              Provider.of<TableService?>(context, listen: false)?.getTableById(order.tableId!) : null,
            numberOfPeople: order.type == OrderType.dineIn ? order.items.length : null,
            orderNumber: order.orderNumber,
          ),
        ),
      );

      if (result != null) {
        // Refresh orders if order was modified
        debugPrint('🔄 ADMIN: Returned from edit order, reloading orders...');
        await _loadOrders();
        
        // If coming from send to kitchen, show a success message
        if (result is Map && result['showActiveOrders'] == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Items sent to kitchen successfully!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error editing order: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Unable to edit order. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _cancelOrder(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to cancel this order?'),
            const SizedBox(height: 16),
            Text('Order #: ${order.orderNumber}'),
            Text('Customer: ${order.customerName ?? 'No customer name'}'),
            Text('Order Total: \$${order.totalAmount.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            const Text(
              'This will mark the order as cancelled and cannot be undone.',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep Order'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() {
        _isLoading = true;
      });

      // Update order status to cancelled using the proper method
      final orderService = Provider.of<OrderService>(context, listen: false);
      final success = await orderService.updateOrderStatus(order.id, 'cancelled');
      
      if (!success) {
        throw Exception('Failed to update order status to cancelled');
      }
      
      // Also update the completed_time for cancelled orders
      try {
        final databaseService = Provider.of<DatabaseService>(context, listen: false);
        final database = await databaseService.database;
        if (database != null) {
          await database.update(
            'orders',
            {'completed_time': DateTime.now().toIso8601String()},
            where: 'id = ?',
            whereArgs: [order.id],
          );
        }
      } catch (e) {
        debugPrint('⚠️ Failed to update completed_time: $e');
        // Don't fail the cancellation if this fails
      }
      // Reload local orders list only
      await _loadOrders();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #${order.orderNumber} cancelled successfully!'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
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
          title: 'Error Cancelling Order',
          message: 'Failed to cancel order: $e',
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

  Future<void> _deleteOrder(Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Order'),
        content: Text('Are you sure you want to delete order #${order.orderNumber}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final orderService = Provider.of<OrderService>(context, listen: false);
        await orderService.deleteOrder(order.id);
        await _loadOrders();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Order #${order.orderNumber} deleted'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
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
            title: 'Error Deleting Order',
            message: 'Failed to delete order: $e',
          );
        }
      }
    }
  }

  Future<void> _viewOrderAudit(Order order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderAuditScreen(orderId: order.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _error != null
        ? _buildErrorState(_error!)
        : Column(
            children: [
              _buildRestaurantInfoHeader(),
              _buildFilters(),
              Expanded(
                child: _buildOrdersList(),
              ),
            ],
          );

    if (!widget.showAppBar) {
      // When used as a tab in AdminPanelScreen, just return the body content
      return LoadingOverlay(
        isLoading: _isLoading,
        child: Container(
          color: Colors.grey.shade50,
          child: body,
        ),
      );
    }

    // When used as a standalone screen, show the full Scaffold with AppBar
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          title: const Text('Admin Orders'),
          backgroundColor: Colors.white,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.1),
          actions: [
            IconButton(
              onPressed: _loadOrders,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
            IconButton(
              onPressed: _syncOrders,
              icon: const Icon(Icons.sync),
              tooltip: 'Sync with Firebase',
            ),
            const SizedBox(width: 16),
          ],
          leading: const CustomBackButton(),
        ),
        body: body,
      ),
    );
  }

  /// Build restaurant info header
  Widget _buildRestaurantInfoHeader() {
    return Consumer<MultiTenantAuthService>(
      builder: (context, authService, child) {
        final currentRestaurant = authService.currentRestaurant;
        if (currentRestaurant == null) {
          return const SizedBox.shrink();
        }
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            border: Border(
              bottom: BorderSide(color: Colors.blue.shade200, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.restaurant, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentRestaurant.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Email: ${currentRestaurant.email}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade600,
                ),
              ),
              Text(
                'Database: ${currentRestaurant.databaseName}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_allOrders.length} Total Orders',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
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
                      '${_allOrders.where((o) => o.isActive).length} Active',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_allOrders.where((o) => !o.isActive).length} Completed',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Error',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _loadOrders,
            icon: _isLoading 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(_isLoading ? 'Loading...' : 'Retry'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search orders by number, customer, or items...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Filter chips
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'ACTIVE ONLY',
                        isSelected: _showActiveOnly && _statusFilter == null,
                        onTap: () => setState(() {
                          _showActiveOnly = true;
                          _statusFilter = null;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'All',
                        isSelected: !_showActiveOnly && _statusFilter == null,
                        onTap: () => setState(() {
                          _statusFilter = null;
                          _showActiveOnly = false;
                        }),
                      ),
                      const SizedBox(width: 8),
                      ...OrderStatus.values.map((status) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildFilterChip(
                          label: status.name.toUpperCase(),
                          isSelected: _statusFilter == status && !_showActiveOnly,
                          onTap: () => setState(() {
                            _statusFilter = status;
                            _showActiveOnly = false;
                          }),
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildFilterChip(
                label: 'All Types',
                isSelected: _typeFilter == null,
                onTap: () => setState(() => _typeFilter = null),
              ),
              const SizedBox(width: 8),
              ...OrderType.values.map((type) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildFilterChip(
                  label: type.name.toUpperCase(),
                  isSelected: _typeFilter == type,
                  onTap: () => setState(() => _typeFilter = type),
                ),
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.grey.shade100,
      selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
      checkmarkColor: Theme.of(context).primaryColor,
    );
  }

  Widget _buildOrdersList() {
    if (_filteredOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _searchQuery.isNotEmpty ? Icons.search_off : Icons.receipt_long,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'No orders found for "$_searchQuery"'
                  : 'No orders found',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _filteredOrders.length,
      itemBuilder: (context, index) {
        final order = _filteredOrders[index];
        return _buildOrderCard(order, order.status != OrderStatus.completed && order.status != OrderStatus.cancelled);
      },
    );
  }

  Widget _buildOrderCard(Order order, bool canEdit) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(order.status).withValues(alpha: 0.1),
          child: Text(
            order.orderNumber.split('-').last,
            style: TextStyle(
              color: _getStatusColor(order.status),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Order #${order.orderNumber}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            // Enhanced audit indicator badge
            Consumer<OrderLogService>(
              builder: (context, orderLogService, child) {
                final logs = orderLogService.getLogsForOrder(order.id);
                return GestureDetector(
                  onTap: () => _viewOrderAudit(order),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: logs.isEmpty ? Colors.grey.shade300 : Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: logs.isEmpty ? Colors.grey.shade400 : Colors.blue.shade300,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history,
                          size: 12,
                          color: logs.isEmpty ? Colors.grey.shade600 : Colors.blue.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${logs.length}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: logs.isEmpty ? Colors.grey.shade600 : Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getOrderTypeText(order.type)} • ${order.items.length} items • \$${order.totalAmount.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            Row(
              children: [
                _buildStatusChip(order.status),
                const SizedBox(width: 8),
                Text(
                  'Table: ${_getTableDisplay(order)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick audit access button
            IconButton(
              icon: const Icon(Icons.history, size: 18),
              onPressed: () => _viewOrderAudit(order),
              tooltip: 'View Order Activity Log',
              style: IconButton.styleFrom(
                backgroundColor: Colors.blue.shade50,
                foregroundColor: Colors.blue.shade700,
                padding: const EdgeInsets.all(8),
                minimumSize: const Size(32, 32),
              ),
            ),
            const SizedBox(width: 4),
            // Main menu button
            PopupMenuButton<String>(
              onSelected: (value) {
                switch (value) {
                  case 'view':
                    _viewOrderDetails(order);
                    break;
                  case 'edit':
                    _editOrder(order);
                    break;
                  case 'cancel':
                    _cancelOrder(order);
                    break;
                  case 'delete':
                    _deleteOrder(order);
                    break;
                  case 'audit':
                    _viewOrderAudit(order);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility, size: 16),
                      SizedBox(width: 8),
                      Text('View Details'),
                    ],
                  ),
                ),
                if (canEdit)
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 16),
                        SizedBox(width: 8),
                        Text('Edit Order'),
                      ],
                    ),
                  ),
                if (canEdit && order.status != OrderStatus.cancelled)
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Row(
                      children: [
                        Icon(Icons.cancel, size: 16, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Cancel Order', style: TextStyle(color: Colors.orange)),
                      ],
                    ),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Order', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
                // Enhanced audit menu item
                PopupMenuItem(
                  value: 'audit',
                  child: Consumer<OrderLogService>(
                    builder: (context, orderLogService, child) {
                      final logs = orderLogService.getLogsForOrder(order.id);
                      return Row(
                        children: [
                          Icon(Icons.receipt, size: 16, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text('Activity Log (${logs.length})', style: TextStyle(color: Colors.blue.shade700)),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus status) {
    Color color;
    String label;

    switch (status) {
      case OrderStatus.pending:
        color = Colors.orange;
        label = 'PENDING';
        break;
      case OrderStatus.confirmed:
        color = Colors.blue;
        label = 'CONFIRMED';
        break;
      case OrderStatus.preparing:
        color = Colors.indigo;
        label = 'PREPARING';
        break;
      case OrderStatus.ready:
        color = Colors.green;
        label = 'READY';
        break;
      case OrderStatus.served:
        color = Colors.teal;
        label = 'SERVED';
        break;
      case OrderStatus.completed:
        color = Colors.green;
        label = 'COMPLETED';
        break;
      case OrderStatus.cancelled:
        color = Colors.red;
        label = 'CANCELLED';
        break;
      case OrderStatus.refunded:
        color = Colors.purple;
        label = 'REFUNDED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.preparing:
        return Colors.indigo;
      case OrderStatus.ready:
        return Colors.green;
      case OrderStatus.served:
        return Colors.teal;
      case OrderStatus.completed:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.refunded:
        return Colors.purple;
    }
  }

     String _getOrderTypeText(OrderType type) {
     switch (type) {
       case OrderType.dineIn:
         return 'DINE-IN';
       case OrderType.takeaway:
         return 'TAKEOUT';
       case OrderType.delivery:
         return 'DELIVERY';
       case OrderType.catering:
         return 'CATERING';
     }
   }

  String _getTableDisplay(Order order) {
    if (order.tableId == null) return 'N/A';
    final table = Provider.of<TableService>(context, listen: false).getTableById(order.tableId!);
    return table?.number.toString() ?? order.tableId!;
  }
}

class _OrderDetailsDialog extends StatelessWidget {
  final Order order;

  const _OrderDetailsDialog({required this.order});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order #${order.orderNumber}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildStatusChip(order.status),
                          const SizedBox(width: 12),
                          Text(
                            order.type.name.toUpperCase(),
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: 32),
            
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Information
                    _buildSection(
                      'Customer Information',
                      [
                        _buildInfoRow('Name', order.customerName ?? 'N/A'),
                        _buildInfoRow('Phone', order.customerPhone ?? 'N/A'),
                        _buildInfoRow('Email', order.customerEmail ?? 'N/A'),
                        if (order.customerAddress != null)
                          _buildInfoRow('Address', order.customerAddress!),
                      ],
                    ),
                    
                    // Order Information
                    _buildSection(
                      'Order Information',
                      [
                        _buildInfoRow('Order Time', _formatDateTime(order.createdAt)),
                        _buildInfoRow('Order Type', order.type.name.toUpperCase()),
                        if (order.tableId != null)
                          Consumer<TableService>(
                            builder: (context, tableService, child) {
                              final table = tableService.getTableById(order.tableId!);
                              final tableDisplay = table?.number.toString() ?? order.tableId!;
                              return _buildInfoRow('Table', tableDisplay);
                            },
                          ),
                        if (order.specialInstructions != null)
                          _buildInfoRow('Special Instructions', order.specialInstructions!),
                        if (order.assignedTo != null)
                          _buildInfoRow('Assigned To', order.assignedTo!),
                      ],
                    ),
                    
                    // Items
                    _buildSection(
                      'Order Items (${order.items.length})',
                      order.items.map((item) => _buildItemRow(item)).toList(),
                    ),
                    
                    // Order Totals
                    _buildSection(
                      'Order Totals',
                      [
                        _buildInfoRow('Subtotal', '\$${order.subtotal.toStringAsFixed(2)}'),
                        if (order.discountAmount > 0)
                          _buildInfoRow('Discount', '-\$${order.discountAmount.toStringAsFixed(2)}', isDiscount: true),
                        _buildInfoRow('HST (13%)', '\$${order.calculatedHstAmount.toStringAsFixed(2)}'),
                        if (order.gratuityAmount > 0)
                          _buildInfoRow('Gratuity', '\$${order.gratuityAmount.toStringAsFixed(2)}'),
                        if (order.tipAmount > 0)
                          _buildInfoRow('Tip', '\$${order.tipAmount.toStringAsFixed(2)}'),
                        const Divider(),
                        _buildInfoRow('Total', '\$${order.totalAmount.toStringAsFixed(2)}', isTotal: true),
                      ],
                    ),
                    
                    // Payment Information
                    if (order.paymentMethod != null)
                      _buildSection(
                        'Payment Information',
                        [
                          _buildInfoRow('Payment Method', order.paymentMethod!),
                          _buildInfoRow('Payment Status', order.paymentStatus.name.toUpperCase()),
                          if (order.paymentTransactionId != null)
                            _buildInfoRow('Transaction ID', order.paymentTransactionId!),
                        ],
                      ),
                    
                    // Order History
                    if (order.history.isNotEmpty)
                      _buildSection(
                        'Order History',
                        order.history.map((history) => _buildHistoryRow(history)).toList(),
                      ),
                    
                    // Order Notes
                    if (order.notes.isNotEmpty)
                      _buildSection(
                        'Order Notes',
                        order.notes.map((note) => _buildNoteRow(note)).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isDiscount = false, bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
                fontSize: isTotal ? 16 : 14,
                color: isDiscount ? Colors.red.shade600 : 
                       isTotal ? Colors.black87 : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(OrderItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.menuItem.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              Text(
                'x${item.quantity}',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '\$${item.totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          if (item.selectedVariant != null) ...[
            const SizedBox(height: 4),
            Text(
              'Variant: ${item.selectedVariant}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
          if (item.selectedModifiers.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Modifiers: ${item.selectedModifiers.join(', ')}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
          ],
          if (item.specialInstructions != null) ...[
            const SizedBox(height: 4),
            Text(
              'Instructions: ${item.specialInstructions}',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          if (item.notes != null) ...[
            const SizedBox(height: 4),
            Text(
              'Chef Notes: ${item.notes}',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: item.sentToKitchen ? Colors.green.shade100 : Colors.orange.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  item.sentToKitchen ? 'SENT TO KITCHEN' : 'NEW',
                  style: TextStyle(
                    color: item.sentToKitchen ? Colors.green.shade700 : Colors.orange.shade700,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (item.voided == true)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'VOIDED',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryRow(OrderHistory history) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Status changed to: ${history.status.name.toUpperCase()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _formatDateTime(history.timestamp),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (history.updatedBy != null) ...[
            const SizedBox(height: 4),
            Text(
              'Updated by: ${history.updatedBy}',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          if (history.notes != null) ...[
            const SizedBox(height: 4),
            Text(
              'Notes: ${history.notes}',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNoteRow(OrderNote note) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: note.isInternal ? Colors.yellow.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: note.isInternal ? Colors.yellow.shade200 : Colors.green.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                note.isInternal ? Icons.note : Icons.comment,
                size: 16,
                color: note.isInternal ? Colors.yellow.shade700 : Colors.green.shade700,
              ),
              const SizedBox(width: 8),
              Text(
                note.isInternal ? 'Internal Note' : 'Customer Note',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: note.isInternal ? Colors.yellow.shade700 : Colors.green.shade700,
                ),
              ),
              const Spacer(),
              Text(
                _formatDateTime(note.timestamp),
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            note.note,
            style: const TextStyle(fontSize: 14),
          ),
          if (note.author != null) ...[
            const SizedBox(height: 4),
            Text(
              'By: ${note.author}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusChip(OrderStatus status) {
    Color color;
    String label;

    switch (status) {
      case OrderStatus.pending:
        color = Colors.orange;
        label = 'PENDING';
        break;
      case OrderStatus.confirmed:
        color = Colors.blue;
        label = 'CONFIRMED';
        break;
      case OrderStatus.preparing:
        color = Colors.indigo;
        label = 'PREPARING';
        break;
      case OrderStatus.ready:
        color = Colors.green;
        label = 'READY';
        break;
      case OrderStatus.served:
        color = Colors.teal;
        label = 'SERVED';
        break;
      case OrderStatus.completed:
        color = Colors.green;
        label = 'COMPLETED';
        break;
      case OrderStatus.cancelled:
        color = Colors.red;
        label = 'CANCELLED';
        break;
      case OrderStatus.refunded:
        color = Colors.purple;
        label = 'REFUNDED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.15),
            color.withValues(alpha: 0.08),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ).copyWith(
          color: color,
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
} 