import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/order.dart';
import '../models/user.dart';
import '../services/order_service.dart';
import '../widgets/universal_navigation.dart';
import '../widgets/loading_overlay.dart';

class ReportsScreen extends StatefulWidget {
  final User user;
  final bool showAppBar;

  const ReportsScreen({super.key, required this.user, this.showAppBar = true});

  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with TickerProviderStateMixin {
  bool _isLoading = false;
  String? _error;
  late TabController _tabController;
  String _selectedPeriod = 'today';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();

  // Filter options
  static const List<String> periodOptions = [
    'today',
    'yesterday',
    'week',
    'month',
    'custom',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await _updateFilteredOrders();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Failed to load data: $e';
      });
    }
  }

  List<Order> _filteredOrders = [];

  Future<void> _updateFilteredOrders() async {
    final orderService = Provider.of<OrderService>(context, listen: false);
    await orderService.loadOrders();
    final allOrders = orderService.allOrders;
    final now = DateTime.now();
    
    DateTime startDate;
    DateTime endDate;
    
    switch (_selectedPeriod) {
      case 'today':
        startDate = DateTime(now.year, now.month, now.day);
        endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
        break;
      case 'yesterday':
        final yesterday = now.subtract(const Duration(days: 1));
        startDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
        endDate = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
        break;
      case 'week':
        startDate = now.subtract(const Duration(days: 7));
        endDate = now;
        break;
      case 'month':
        startDate = DateTime(now.year, now.month - 1, now.day);
        endDate = now;
        break;
      case 'custom':
        startDate = _startDate;
        endDate = _endDate;
        break;
      default:
        startDate = now.subtract(const Duration(days: 7));
        endDate = now;
    }
    
    // Filter orders to include only completed orders within the date range
    _filteredOrders = allOrders.where((order) => 
      order.isCompleted && 
      order.orderTime.isAfter(startDate) && 
      order.orderTime.isBefore(endDate)
    ).toList();
  }

  // Sales Analytics
  double get _totalRevenue => _filteredOrders.fold(0, (sum, order) => sum + order.totalAmount);
  int get _totalOrders => _filteredOrders.length;
  double get _averageOrderValue => _totalOrders > 0 ? _totalRevenue / _totalOrders : 0;
  int get _totalItems => _filteredOrders.fold(0, (sum, order) => sum + order.itemCount.toInt());

  // Popular Items Analysis
  Map<String, int> get _popularItems {
    final itemCounts = <String, int>{};
    for (final order in _filteredOrders) {
      for (final item in order.items) {
        final itemName = item.menuItem.name;
        itemCounts[itemName] = (itemCounts[itemName] ?? 0) + item.quantity;
      }
    }
    return itemCounts;
  }

  List<MapEntry<String, int>> get _topSellingItems {
    final items = _popularItems.entries.toList();
    items.sort((a, b) => b.value.compareTo(a.value));
    return items.take(10).toList();
  }

  // Peak Hour Analytics
  Map<int, int> get _hourlyOrders {
    final hourlyCounts = <int, int>{};
    for (int i = 0; i < 24; i++) {
      hourlyCounts[i] = 0;
    }
    
    for (final order in _filteredOrders) {
      final hour = order.orderTime.hour;
      hourlyCounts[hour] = (hourlyCounts[hour] ?? 0) + 1;
    }
    
    return hourlyCounts;
  }

  // Customer Analytics
  Map<String, double> get _customerSpending {
    final customerSpending = <String, double>{};
    for (final order in _filteredOrders) {
      if (order.customerName != null && order.customerName!.isNotEmpty) {
        customerSpending[order.customerName!] = (customerSpending[order.customerName!] ?? 0) + order.totalAmount;
      }
    }
    return customerSpending;
  }

  List<MapEntry<String, double>> get _topCustomers {
    final customers = _customerSpending.entries.toList();
    customers.sort((a, b) => b.value.compareTo(a.value));
    return customers.take(10).toList();
  }

  Future<void> _showCustomDatePicker() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPeriod = 'custom';
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _updateFilteredOrders();
      setState(() {});
    }
  }

  String _getDateRangeText() {
    switch (_selectedPeriod) {
      case 'today':
        return 'Today';
      case 'yesterday':
        return 'Yesterday';
      case 'week':
        return 'Last 7 days';
      case 'month':
        return 'Last 30 days';
      case 'custom':
        return '${_startDate.day}/${_startDate.month}/${_startDate.year} - ${_endDate.day}/${_endDate.month}/${_endDate.year}';
      default:
        return 'Last 7 days';
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportsControls = Column(
      children: [
        // Period selector
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: periodOptions.map((period) {
              final isSelected = _selectedPeriod == period;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(period.toUpperCase()),
                  selected: isSelected,
                  onSelected: (selected) async {
                    if (period == 'custom') {
                      await _showCustomDatePicker();
                    } else {
                      setState(() {
                        _selectedPeriod = period;
                      });
                      await _updateFilteredOrders();
                      setState(() {});
                    }
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
          tabs: const [
            Tab(icon: Icon(Icons.analytics), text: 'Overview'),
            Tab(icon: Icon(Icons.trending_up), text: 'Sales'),
            Tab(icon: Icon(Icons.restaurant_menu), text: 'Items'),
            Tab(icon: Icon(Icons.access_time), text: 'Peak Hours'),
            Tab(icon: Icon(Icons.people), text: 'Customers'),
          ],
        ),
      ],
    );

    final body = _error != null
        ? _buildErrorState(_error!)
        : TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildSalesTab(),
              _buildItemsTab(),
              _buildPeakHoursTab(),
              _buildCustomersTab(),
            ],
          );

    if (!widget.showAppBar) {
      // When used as a tab in AdminPanelScreen, just return the body content
      return LoadingOverlay(
        isLoading: _isLoading,
        child: Container(
          color: Colors.grey.shade50,
          child: Column(
            children: [
              reportsControls,
              Expanded(child: body),
            ],
          ),
        ),
      );
    }

    // When used as a standalone screen, show the full Scaffold with AppBar
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        appBar: UniversalAppBar(
          currentUser: widget.user,
          title: 'Reports & Analytics',
          additionalActions: [
            IconButton(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Data',
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(80),
            child: reportsControls,
          ),
        ),
        body: body,
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
            onPressed: _loadData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Overview',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _getDateRangeText(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Summary card
          if (_filteredOrders.isNotEmpty) ...[
            Card(
              elevation: 2,
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.analytics, color: Colors.blue.shade700, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Analyzing ${_filteredOrders.length} completed orders',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Key metrics cards or empty state
          if (_filteredOrders.isEmpty)
            _buildEmptyState('No completed orders found for the selected period')
          else ...[
            Row(
              children: [
                Expanded(child: _buildMetricCard('Total Revenue', '\$${_totalRevenue.toStringAsFixed(2)}', Colors.green, Icons.attach_money)),
                const SizedBox(width: 12),
                Expanded(child: _buildMetricCard('Total Orders', _totalOrders.toString(), Colors.blue, Icons.receipt)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildMetricCard('Avg Order Value', '\$${_averageOrderValue.toStringAsFixed(2)}', Colors.orange, Icons.analytics)),
                const SizedBox(width: 12),
                Expanded(child: _buildMetricCard('Total Items', _totalItems.toString(), Colors.purple, Icons.restaurant_menu)),
              ],
            ),
          ],
          const SizedBox(height: 24),
          // Top selling items
          _buildTopSellingItems(),
        ],
      ),
    );
  }

  Widget _buildSalesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sales Analytics',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _getDateRangeText(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_filteredOrders.isEmpty)
            _buildEmptyState('No completed orders found for the selected period')
          else
            _buildSalesBreakdown(),
        ],
      ),
    );
  }

  Widget _buildItemsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Popular Items',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _getDateRangeText(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTopSellingItems(),
        ],
      ),
    );
  }

  Widget _buildPeakHoursTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Peak Hours Analysis',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _getDateRangeText(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPeakHoursBreakdown(),
        ],
      ),
    );
  }

  Widget _buildCustomersTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Customer Analytics',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _getDateRangeText(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_filteredOrders.isEmpty)
            _buildEmptyState('No completed orders found for the selected period')
          else ...[
            _buildTopCustomers(),
            const SizedBox(height: 24),
            _buildCustomerInsights(),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricCard(String title, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSellingItems() {
    if (_topSellingItems.isEmpty) {
      return _buildEmptyState('No items data available');
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Selling Items',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._topSellingItems.map((item) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  '${_topSellingItems.indexOf(item) + 1}',
                  style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(item.key),
              trailing: Text(
                '${item.value} sold',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildPeakHoursBreakdown() {
    final hourlyData = _hourlyOrders.entries.toList();
    final peakHours = hourlyData.where((entry) => entry.value > 0).toList();
    peakHours.sort((a, b) => b.value.compareTo(a.value));

    if (peakHours.isEmpty) {
      return _buildEmptyState('No peak hours data available');
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Peak Hours',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...peakHours.take(5).map((hour) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange.shade100,
                child: Text(
                  '${hour.key}:00',
                  style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text('${hour.key}:00 - ${hour.key + 1}:00'),
              trailing: Text(
                '${hour.value} orders',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildTopCustomers() {
    if (_topCustomers.isEmpty) {
      return _buildEmptyState('No customer data available');
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Top Customers',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._topCustomers.map((customer) => ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.green.shade100,
                child: Text(
                  '${_topCustomers.indexOf(customer) + 1}',
                  style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(customer.key),
              trailing: Text(
                '\$${customer.value.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomerInsights() {
    final totalCustomers = _customerSpending.length;
    final totalRevenue = _customerSpending.values.fold(0.0, (sum, value) => sum + value);
    final avgCustomerSpending = totalCustomers > 0 ? totalRevenue / totalCustomers : 0;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Customer Insights',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildMetricCard('Total Customers', totalCustomers.toString(), Colors.green, Icons.people)),
                const SizedBox(width: 12),
                Expanded(child: _buildMetricCard('Avg Customer Spend', '\$${avgCustomerSpending.toStringAsFixed(2)}', Colors.blue, Icons.person)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesBreakdown() {
    final dineInOrders = _filteredOrders.where((order) => order.type == OrderType.dineIn).length;
    final takeoutOrders = _filteredOrders.where((order) => order.type == OrderType.takeaway).length;
    final dineInRevenue = _filteredOrders.where((order) => order.type == OrderType.dineIn).fold(0.0, (sum, order) => sum + order.totalAmount);
    final takeoutRevenue = _filteredOrders.where((order) => order.type == OrderType.takeaway).fold(0.0, (sum, order) => sum + order.totalAmount);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sales Breakdown',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      const Icon(Icons.table_restaurant, size: 32, color: Colors.blue),
                      const SizedBox(height: 8),
                      Text('Dine-In', style: Theme.of(context).textTheme.titleMedium),
                      Text('$dineInOrders orders', style: Theme.of(context).textTheme.bodyMedium),
                      Text('\$${dineInRevenue.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Icon(Icons.takeout_dining, size: 32, color: Colors.orange),
                      const SizedBox(height: 8),
                      Text('Takeout', style: Theme.of(context).textTheme.titleMedium),
                      Text('$takeoutOrders orders', style: Theme.of(context).textTheme.bodyMedium),
                      Text('\$${takeoutRevenue.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.analytics, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 