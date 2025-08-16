import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../services/order_service.dart';
import '../services/printing_service.dart';
import '../services/table_service.dart';
import '../services/robust_kitchen_service.dart';
import '../services/unified_sync_service.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/error_dialog.dart';
import '../widgets/universal_navigation.dart';
import 'package:audioplayers/audioplayers.dart';
import '../widgets/kitchen_receipt_preview.dart';
import '../widgets/confirmation_dialog.dart';
import '../utils/instant_sync_mixin.dart'; // Instant sync functionality

class KitchenScreen extends StatefulWidget {
  final User user;
  final bool showAppBar;

  const KitchenScreen({super.key, required this.user, this.showAppBar = true});

  @override
  _KitchenScreenState createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> with TickerProviderStateMixin, InstantSyncMixin {
  bool _isLoading = false;
  String? _error;
  String _selectedFilter = 'all';
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<String> _lastOrderIds = [];
  String? _bannerMessage;
  Color? _bannerColor;
  Timer? _bannerTimer;
  bool _isFullscreen = false;

  // Filter options
  static const List<String> filterOptions = [
    'all',
    'pending',
    'preparing',
    'ready',
    'urgent',
  ];

  /// Enhanced text styles for better prominence and visual appeal

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOrders();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _autoRefreshTimer?.cancel();
    _audioPlayer.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  Timer? _autoRefreshTimer;
  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      await _loadOrders();
    });
  }

  void _showBanner(String message, Color color) {
    setState(() {
      _bannerMessage = message;
      _bannerColor = color;
    });
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _bannerMessage = null;
        });
      }
    });
  }

  /// Load orders for kitchen display
  Future<void> _loadOrders() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // DISABLED: These were causing infinite sync loops
      // await triggerInstantSync();
      // await _triggerSyncOnKitchenAccess();
      
      // The orders are loaded through the OrderService and accessed via getters
      // No need to manually assign to lists since they're computed from _filteredOrders
      
      setState(() {
        _isLoading = false;
      });
      
      debugPrint('✅ Kitchen orders loaded: ${_pendingOrders.length} pending, ${_preparingOrders.length} preparing, ${_readyOrders.length} ready');
    } catch (e) {
      debugPrint('❌ Error loading kitchen orders: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Trigger sync on kitchen screen access - DISABLED to prevent infinite loops
  Future<void> _triggerSyncOnKitchenAccess() async {
    // DISABLED: This was causing infinite sync loops
    // try {
    //   final syncTriggerService = AutomaticSyncTriggerService();
    //   await syncTriggerService.triggerImmediateSyncOnInteraction();
    //   debugPrint('🔄 Sync triggered on kitchen screen access');
    // } catch (e) {
    //   debugPrint('⚠️ Failed to trigger sync on kitchen access: $e');
    // }
  }

  List<Order> get _filteredOrders {
    final orderService = Provider.of<OrderService>(context, listen: false);
    List<Order> orders = List.from(orderService.activeOrders); // Create a new list from the unmodifiable list

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      orders = orders.where((order) {
        final query = _searchQuery.toLowerCase();
        return order.orderNumber.toLowerCase().contains(query) ||
               order.customerName?.toLowerCase().contains(query) == true ||
               order.tableId?.toLowerCase().contains(query) == true ||
               order.items.any((item) => 
                 item.menuItem.name.toLowerCase().contains(query));
      }).toList();
    }

    // Apply status filter
    switch (_selectedFilter) {
      case 'pending':
        orders = orders.where((order) => order.status == OrderStatus.pending).toList();
        break;
      case 'preparing':
        orders = orders.where((order) => order.status == OrderStatus.preparing).toList();
        break;
      case 'ready':
        orders = orders.where((order) => order.status == OrderStatus.ready).toList();
        break;
      case 'urgent':
        orders = orders.where((order) => order.isUrgent).toList();
        break;
    }

    // Sort orders by priority and time
    orders.sort((a, b) {
      // Urgent orders first
      if (a.isUrgent && !b.isUrgent) return -1;
      if (!a.isUrgent && b.isUrgent) return 1;
      
      // Then by priority
      if (a.priority != b.priority) return b.priority.compareTo(a.priority);
      
      // Then by order time (oldest first)
      return a.orderTime.compareTo(b.orderTime);
    });

    return orders;
  }

  List<Order> get _pendingOrders => _filteredOrders.where((order) => 
    order.status == OrderStatus.pending || order.status == OrderStatus.confirmed).toList();

  List<Order> get _preparingOrders => _filteredOrders.where((order) => 
    order.status == OrderStatus.preparing).toList();

  List<Order> get _readyOrders => _filteredOrders.where((order) => 
    order.status == OrderStatus.ready).toList();

  Future<void> _updateOrderStatus(Order order, OrderStatus newStatus) async {
    try {
      final orderService = Provider.of<OrderService>(context, listen: false);
      
      final updatedOrder = order.copyWith(
        status: newStatus,
        actualReadyTime: newStatus == OrderStatus.ready ? DateTime.now() : order.actualReadyTime,
      );

      await orderService.saveOrder(updatedOrder);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #${order.orderNumber} status updated to ${newStatus.toString().split('.').last.toUpperCase()}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await ErrorDialogHelper.showError(
          context,
          title: 'Update Error',
          message: 'Failed to update order status: $e',
        );
      }
    }
  }

  Future<void> _markAsUrgent(Order order) async {
    try {
      final orderService = Provider.of<OrderService>(context, listen: false);
      
      final updatedOrder = order.copyWith(
        isUrgent: !order.isUrgent,
        priority: order.isUrgent ? 0 : 10,
      );

      await orderService.saveOrder(updatedOrder);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #${order.orderNumber} ${order.isUrgent ? 'removed from' : 'marked as'} urgent'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await ErrorDialogHelper.showError(
          context,
          title: 'Update Error',
          message: 'Failed to update order priority: $e',
        );
      }
    }
  }

  Future<void> _reprintKitchenTicket(Order order) async {
    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      await printingService.printKitchenTicket(order);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kitchen ticket reprinted'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        await ErrorDialogHelper.showError(
          context,
          title: 'Print Error',
          message: 'Failed to reprint kitchen ticket: $e',
        );
      }
    }
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Calculate analytics
    final allOrders = Provider.of<OrderService>(context).activeOrders;
    final pendingCount = allOrders.where((o) => o.status == OrderStatus.pending || o.status == OrderStatus.confirmed).length;
    final preparingCount = allOrders.where((o) => o.status == OrderStatus.preparing).length;
    final readyCount = allOrders.where((o) => o.status == OrderStatus.ready).length;
    final urgentCount = allOrders.where((o) => o.isUrgent).length;
    final overdueCount = allOrders.where((o) => o.isOverdue).length;
    final prepTimes = allOrders.where((o) => o.status == OrderStatus.ready && o.actualReadyTime != null).map((o) => o.preparationTime.inMinutes).toList();
    final avgPrepTime = prepTimes.isNotEmpty ? prepTimes.reduce((a, b) => a + b) ~/ prepTimes.length : 0;

    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: (_isFullscreen || !widget.showAppBar)
            ? null
            : UniversalAppBar(
                currentUser: widget.user,
                title: 'Kitchen Management',
                additionalActions: [
                  IconButton(
                    onPressed: _loadOrders,
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Refresh Orders',
                  ),
                  IconButton(
                    onPressed: _toggleFullscreen,
                    icon: const Icon(Icons.fullscreen),
                    tooltip: 'Fullscreen Mode',
                  ),
                ],
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(160),
                  child: Column(
                    children: [
                      if (_bannerMessage != null)
                        GestureDetector(
                          onTap: () => setState(() => _bannerMessage = null),
                          child: Container(
                            width: double.infinity,
                            color: _bannerColor ?? Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            child: Row(
                              children: [
                                const Icon(Icons.notifications, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _bannerMessage!,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.close, color: Colors.white, size: 18),
                              ],
                            ),
                          ),
                        ),
                      // --- Analytics Bar ---
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatTile('Pending', pendingCount, Colors.orange),
                            _buildStatTile('Preparing', preparingCount, Colors.indigo),
                            _buildStatTile('Ready', readyCount, Colors.green),
                            _buildStatTile('Urgent', urgentCount, Colors.red),
                            _buildStatTile('Overdue', overdueCount, Colors.yellow.shade900),
                            Column(
                              children: [
                                const Text('Avg Prep', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text('$avgPrepTime min', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // --- End Analytics Bar ---
                      // Search bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search orders, customers, or items...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                      ),
                      // Filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: filterOptions.map((filter) {
                            final isSelected = _selectedFilter == filter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(filter.toUpperCase()),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedFilter = filter;
                                  });
                                },
                                selectedColor: Theme.of(context).primaryColor,
                                checkmarkColor: Colors.white,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      // Tab bar
                      TabBar(
                        controller: _tabController,
                        labelColor: Theme.of(context).primaryColor,
                        unselectedLabelColor: Colors.grey.shade600,
                        indicatorColor: Theme.of(context).primaryColor,
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.schedule, size: 16),
                                const SizedBox(width: 4),
                                Text('Pending ( [38;5;2m${_pendingOrders.length} [0m)'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.restaurant, size: 16),
                                const SizedBox(width: 4),
                                Text('Preparing ( [38;5;2m${_preparingOrders.length} [0m)'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle, size: 16),
                                const SizedBox(width: 4),
                                Text('Ready ( [38;5;2m${_readyOrders.length} [0m)'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        body: _error != null
            ? _buildErrorState(_error!)
            : !widget.showAppBar
                ? Column(
                    children: [
                      // Include kitchen controls when not showing AppBar
                      if (_bannerMessage != null)
                        GestureDetector(
                          onTap: () => setState(() => _bannerMessage = null),
                          child: Container(
                            width: double.infinity,
                            color: _bannerColor ?? Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            child: Row(
                              children: [
                                const Icon(Icons.notifications, color: Colors.white),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _bannerMessage!,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.close, color: Colors.white, size: 18),
                              ],
                            ),
                          ),
                        ),
                      // Analytics Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatTile('Pending', pendingCount, Colors.orange),
                            _buildStatTile('Preparing', preparingCount, Colors.indigo),
                            _buildStatTile('Ready', readyCount, Colors.green),
                            _buildStatTile('Urgent', urgentCount, Colors.red),
                            _buildStatTile('Overdue', overdueCount, Colors.yellow.shade900),
                            Column(
                              children: [
                                const Text('Avg Prep', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                Text('$avgPrepTime min', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Search bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search orders, customers, or items...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                      ),
                      // Filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: filterOptions.map((filter) {
                            final isSelected = _selectedFilter == filter;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(filter.toUpperCase()),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedFilter = filter;
                                  });
                                },
                                selectedColor: Theme.of(context).primaryColor,
                                checkmarkColor: Colors.white,
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      // Tab bar
                      TabBar(
                        controller: _tabController,
                        labelColor: Theme.of(context).primaryColor,
                        unselectedLabelColor: Colors.grey.shade600,
                        indicatorColor: Theme.of(context).primaryColor,
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.schedule, size: 16),
                                const SizedBox(width: 4),
                                Text('Pending ([38;5;2m${_pendingOrders.length}[0m)'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.restaurant, size: 16),
                                const SizedBox(width: 4),
                                Text('Preparing ([38;5;2m${_preparingOrders.length}[0m)'),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle, size: 16),
                                const SizedBox(width: 4),
                                Text('Ready ([38;5;2m${_readyOrders.length}[0m)'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildOrderList(_pendingOrders, 'pending'),
                            _buildOrderList(_preparingOrders, 'preparing'),
                            _buildOrderList(_readyOrders, 'ready'),
                          ],
                        ),
                      ),
                    ],
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOrderList(_pendingOrders, 'pending'),
                      _buildOrderList(_preparingOrders, 'preparing'),
                      _buildOrderList(_readyOrders, 'ready'),
                    ],
                  ),
        floatingActionButton: _isFullscreen
            ? FloatingActionButton.extended(
                onPressed: _toggleFullscreen,
                icon: const Icon(Icons.fullscreen_exit),
                label: const Text('Exit Fullscreen'),
                backgroundColor: Colors.black87,
              )
            : null,
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
          const SizedBox(height: 16),
          Text(
            'Error',
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
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadOrders,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<Order> orders, String status) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == 'pending' ? Icons.schedule :
              status == 'preparing' ? Icons.restaurant :
              Icons.check_circle,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${status.toUpperCase()} Orders',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Orders will appear here when they are ${status == 'pending' ? 'received' : status == 'preparing' ? 'being prepared' : 'ready for pickup'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        return GestureDetector(
          onTap: () => _showOrderDetailModal(order),
          child: _buildOrderCard(order),
        );
      },
    );
  }

  void _showOrderDetailModal(Order order) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: _OrderDetailModal(
            order: order,
            onReprint: () => _reprintKitchenTicket(order),
            onMarkUrgent: () => _markAsUrgent(order),
            onUpdateStatus: (OrderStatus status) => _updateOrderStatus(order, status),
            scrollController: scrollController,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final isUrgent = order.isUrgent;
    final isOverdue = order.isOverdue;
    final timeSinceReceived = DateTime.now().difference(order.orderTime);
    final timeInStatus = DateTime.now().difference(order.history.isNotEmpty ? order.history.last.timestamp : order.orderTime);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isUrgent ? 4 : 2,
      color: isUrgent ? Colors.red.shade50 : isOverdue ? Colors.yellow.shade100 : Colors.white,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: isUrgent ? Colors.red.shade300 : isOverdue ? Colors.yellow.shade700 : Colors.grey.shade300,
            width: isUrgent || isOverdue ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                        Row(
                          children: [
                            Text(
                              'Order #${order.orderNumber}',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isUrgent ? Colors.red.shade700 : isOverdue ? Colors.yellow.shade900 : null,
                              ),
                            ),
                            if (isUrgent) ...[
                              const SizedBox(width: 8),
                              _buildBadge('URGENT', Colors.red.shade700, Colors.red.shade100),
                            ],
                            if (isOverdue) ...[
                              const SizedBox(width: 8),
                              _buildBadge('OVERDUE', Colors.yellow.shade900, Colors.yellow.shade100),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${order.type.toString().split('.').last.toUpperCase()} • ${_formatTime(order.orderTime)}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.timer, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 2),
                            Text(_formatDuration(timeSinceReceived), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                            const SizedBox(width: 8),
                            Icon(Icons.timelapse, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 2),
                            Text(_formatDuration(timeInStatus), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                        if (order.tableId != null) ...[
                          const SizedBox(height: 2),
                          Consumer<TableService>(
                            builder: (context, tableService, child) {
                              final table = tableService.getTableById(order.tableId!);
                              
                              // Improved table number extraction and fallback
                              String tableDisplay;
                              if (table != null) {
                                tableDisplay = table.number.toString();
                              } else {
                                // Try to extract table number from ID pattern
                                final match = RegExp(r'table_(\d+)').firstMatch(order.tableId!);
                                if (match != null) {
                                  tableDisplay = match.group(1)!;
                                } else {
                                  // Fallback: try to extract any numbers from the ID
                                  final numbers = RegExp(r'\d+').allMatches(order.tableId!);
                                  if (numbers.isNotEmpty) {
                                    tableDisplay = numbers.first.group(0)!;
                                  } else {
                                    tableDisplay = 'Unknown';
                                  }
                                }
                              }
                              
                              return Text(
                                'Table $tableDisplay',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade600,
                                ),
                              );
                            },
                          ),
                        ],
                        if (order.customerName != null && order.customerName!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Customer: ${order.customerName}',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Status and actions
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildStatusChip(order.status),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () => _reprintKitchenTicket(order),
                            icon: const Icon(Icons.print, size: 20),
                            tooltip: 'Reprint Kitchen Ticket',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                              foregroundColor: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () => _markAsUrgent(order),
                            icon: Icon(
                              isUrgent ? Icons.priority_high : Icons.low_priority,
                              size: 20,
                            ),
                            tooltip: isUrgent ? 'Remove Urgent' : 'Mark as Urgent',
                            style: IconButton.styleFrom(
                              backgroundColor: isUrgent ? Colors.red.shade50 : Colors.orange.shade50,
                              foregroundColor: isUrgent ? Colors.red.shade700 : Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Items
              ...order.items.map((item) => _buildOrderItem(item)),
              const SizedBox(height: 12),
              // Special instructions
              if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.yellow.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.yellow.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          order.specialInstructions!,
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              // Action buttons
              _buildActionButtons(order),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '${twoDigits(h)}:${twoDigits(m)}:${twoDigits(s)}';
    } else {
      return '${twoDigits(m)}:${twoDigits(s)}';
    }
  }

  Widget _buildOrderItem(OrderItem item) {
    final isVoided = item.voided == true;
    final isComped = item.comped == true;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: isVoided ? Colors.red.shade100 :
                     isComped ? Colors.green.shade100 :
                     Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${item.quantity}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isVoided ? Colors.red.shade700 :
                         isComped ? Colors.green.shade700 :
                         Colors.blue.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.menuItem.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: isVoided ? TextDecoration.lineThrough : null,
                    color: isVoided ? Colors.grey.shade500 : null,
                  ),
                ),
                if (item.selectedVariant != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.selectedVariant!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (item.selectedModifiers.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.selectedModifiers.join(', '),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
                if (item.specialInstructions != null && item.specialInstructions!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Note: ${item.specialInstructions}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isVoided)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'VOID',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (isComped)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'COMP',
                style: TextStyle(
                  color: Colors.green.shade700,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
      default:
        color = Colors.grey;
        label = 'UNKNOWN';
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

  Widget _buildActionButtons(Order order) {
    return Row(
      children: [
        if (order.status == OrderStatus.pending || order.status == OrderStatus.confirmed) ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _updateOrderStatus(order, OrderStatus.preparing),
              icon: const Icon(Icons.restaurant),
              label: const Text('Start Preparing'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
        if (order.status == OrderStatus.preparing) ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _updateOrderStatus(order, OrderStatus.ready),
              icon: const Icon(Icons.check_circle),
              label: const Text('Mark Ready'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
        if (order.status == OrderStatus.ready) ...[
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _updateOrderStatus(order, OrderStatus.served),
              icon: const Icon(Icons.delivery_dining),
              label: const Text('Mark Served'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour;
    final ampm = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')} $ampm';
  }

  Widget _buildStatTile(String label, int count, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: color)),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$count', style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
        ),
      ],
    );
  }
}

class _OrderDetailModal extends StatelessWidget {
  final Order order;
  final VoidCallback onReprint;
  final VoidCallback onMarkUrgent;
  final ValueChanged<OrderStatus> onUpdateStatus;
  final ScrollController scrollController;

  const _OrderDetailModal({
    required this.order,
    required this.onReprint,
    required this.onMarkUrgent,
    required this.onUpdateStatus,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final isUrgent = order.isUrgent;
    final isOverdue = order.isOverdue;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                'Order #${order.orderNumber}', 
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            if (isUrgent)
              _buildBadge('URGENT', Colors.red.shade700, Colors.red.shade100),
            if (isOverdue)
              _buildBadge('OVERDUE', Colors.yellow.shade900, Colors.yellow.shade100),
          ],
        ),
        const SizedBox(height: 8),
        Consumer<TableService>(
          builder: (context, tableService, child) {
            final tableDisplay = order.tableId != null 
                ? () {
                    final table = tableService.getTableById(order.tableId!);
                    final tableNumber = table?.number.toString() ?? order.tableId!;
                    return ' • Table $tableNumber';
                  }()
                : '';
            
            return Text('${order.type.toString().split('.').last.toUpperCase()}$tableDisplay');
          },
        ),
        const SizedBox(height: 16),
        Text('Items', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const Divider(),
        ...order.items.map((item) => ListTile(
              title: Text(item.menuItem.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (item.selectedVariant != null) Text(item.selectedVariant!, style: const TextStyle(fontSize: 12)),
                  if (item.selectedModifiers.isNotEmpty) Text(item.selectedModifiers.join(', '), style: const TextStyle(fontSize: 12)),
                  if (item.specialInstructions != null && item.specialInstructions!.isNotEmpty) Text('Note: ${item.specialInstructions}', style: const TextStyle(fontSize: 12, color: Colors.orange)),
                ],
              ),
              trailing: Text('x${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
            )),
        const SizedBox(height: 16),
        if (order.specialInstructions != null && order.specialInstructions!.isNotEmpty) ...[
          Text('Special Instructions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const Divider(),
          Text(order.specialInstructions!, style: const TextStyle(color: Colors.orange)),
          const SizedBox(height: 16),
        ],
        Text('Order Notes', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const Divider(),
        if (order.notes.isEmpty)
          const Text('No notes.'),
        ...order.notes.map((note) => ListTile(
              leading: const Icon(Icons.note, size: 18),
              title: Text(note.note),
              subtitle: Text('${note.author ?? 'Unknown'} • ${note.timestamp}'),
            )),
        const SizedBox(height: 16),
        Text('Order History', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const Divider(),
        if (order.history.isEmpty)
          const Text('No history.'),
        ...order.history.map((h) => ListTile(
              leading: const Icon(Icons.history, size: 18),
              title: Text(h.status.toString().split('.').last.toUpperCase()),
              subtitle: Text('${h.updatedBy ?? 'System'} • ${h.timestamp}'),
              trailing: Text(h.notes ?? ''),
            )),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: onReprint,
              icon: const Icon(Icons.print),
              label: const Text('Reprint'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
            ElevatedButton.icon(
              onPressed: onMarkUrgent,
              icon: Icon(isUrgent ? Icons.priority_high : Icons.low_priority),
              label: Text(isUrgent ? 'Remove Urgent' : 'Mark Urgent'),
              style: ElevatedButton.styleFrom(backgroundColor: isUrgent ? Colors.red : Colors.orange),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () => onUpdateStatus(OrderStatus.preparing),
              icon: const Icon(Icons.restaurant),
              label: const Text('Start Preparing'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
            ),
            ElevatedButton.icon(
              onPressed: () => onUpdateStatus(OrderStatus.ready),
              icon: const Icon(Icons.check_circle),
              label: const Text('Mark Ready'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            ),
            ElevatedButton.icon(
              onPressed: () => onUpdateStatus(OrderStatus.served),
              icon: const Icon(Icons.delivery_dining),
              label: const Text('Mark Served'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBadge(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
} 