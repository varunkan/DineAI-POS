import 'package:flutter/material.dart';
import 'package:ai_pos_system/models/inventory_item.dart';
import 'package:ai_pos_system/services/inventory_service.dart';
import 'package:ai_pos_system/widgets/loading_overlay.dart';
import 'package:ai_pos_system/widgets/error_dialog.dart';
import 'package:ai_pos_system/widgets/confirmation_dialog.dart';
import 'package:ai_pos_system/widgets/universal_navigation.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class InventoryScreen extends StatefulWidget {
  final bool showAppBar;
  
  const InventoryScreen({super.key, this.showAppBar = true});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final InventoryService _inventoryService = InventoryService();
  final TextEditingController _searchController = TextEditingController();
  
  List<InventoryItem> _allItems = [];
  List<InventoryItem> _filteredItems = [];
  List<InventoryTransaction> _transactions = [];
  InventoryCategory? _selectedCategory;
  bool _isLoading = true;
  bool _showLowStockOnly = false;
  bool _showOutOfStockOnly = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    
    try {
      await _inventoryService.initialize();
      await _loadData();
    } catch (e) {
      if (mounted) {
        ErrorDialogHelper.showError(context, title: 'Error', message: 'Error loading inventory data: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadData() async {
    _allItems = _inventoryService.getAllItems();
    _transactions = _inventoryService.getAllTransactions();
    _applyFilters();
  }

  void _applyFilters() {
    _filteredItems = _allItems.where((item) {
      // Category filter
      if (_selectedCategory != null && item.category != _selectedCategory) {
        return false;
      }
      
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!item.name.toLowerCase().contains(query) &&
            !(item.description?.toLowerCase().contains(query) ?? false)) {
          return false;
        }
      }
      
      // Stock filters
      if (_showLowStockOnly && !item.isLowStock) return false;
      if (_showOutOfStockOnly && !item.isOutOfStock) return false;
      
      return true;
    }).toList();
    
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final body = LoadingOverlay(
      isLoading: _isLoading,
      child: Column(
        children: [
          // Add tabs manually when not showing app bar
          if (!widget.showAppBar)
            Container(
              color: Theme.of(context).colorScheme.primary,
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
                  Tab(text: 'Items', icon: Icon(Icons.inventory)),
                  Tab(text: 'Transactions', icon: Icon(Icons.receipt_long)),
                  Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildItemsTab(),
                _buildTransactionsTab(),
                _buildAnalyticsTab(),
              ],
            ),
          ),
        ],
      ),
    );

    if (!widget.showAppBar) {
      // When used as a tab in AdminPanelScreen, just return the body content
      return body;
    }

    // When used as a standalone screen, show the full Scaffold with AppBar
    return Scaffold(
      appBar: UniversalAppBar(
        currentUser: null, // This screen doesn't have user context
        title: 'Inventory Management',
        additionalActions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddItemDialog,
            tooltip: 'Add Item',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'load_sample',
                child: Row(
                  children: [
                    Icon(Icons.data_usage),
                    SizedBox(width: 8),
                    Text('Load Sample Data'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'clear_data',
                child: Row(
                  children: [
                    Icon(Icons.clear_all),
                    SizedBox(width: 8),
                    Text('Clear All Data'),
                  ],
                ),
              ),
            ],
          ),
        ],
        showQuickActions: false, // Disable quick actions for this admin screen
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Overview', icon: Icon(Icons.dashboard)),
            Tab(text: 'Items', icon: Icon(Icons.inventory)),
            Tab(text: 'Transactions', icon: Icon(Icons.receipt_long)),
            Tab(text: 'Analytics', icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildOverviewTab(),
            _buildItemsTab(),
            _buildTransactionsTab(),
            _buildAnalyticsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    final lowStockItems = _inventoryService.getLowStockItems();
    final outOfStockItems = _inventoryService.getOutOfStockItems();
    final expiringSoonItems = _inventoryService.getExpiringSoonItems();
    final totalValue = _inventoryService.getTotalInventoryValue();
    final categorySummary = _inventoryService.getCategorySummary();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Total Items',
                  _allItems.length.toString(),
                  Icons.inventory,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Total Value',
                  '\$${totalValue.toStringAsFixed(2)}',
                  Icons.attach_money,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Low Stock',
                  lowStockItems.length.toString(),
                  Icons.warning,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Out of Stock',
                  outOfStockItems.length.toString(),
                  Icons.error,
                  Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Alerts Section
          if (lowStockItems.isNotEmpty || outOfStockItems.isNotEmpty || expiringSoonItems.isNotEmpty)
            _buildAlertsSection(lowStockItems, outOfStockItems, expiringSoonItems),

          const SizedBox(height: 24),

          // Category Summary
          _buildCategorySummarySection(categorySummary),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsSection(
    List<InventoryItem> lowStockItems,
    List<InventoryItem> outOfStockItems,
    List<InventoryItem> expiringSoonItems,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Alerts',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (outOfStockItems.isNotEmpty) ...[
              _buildAlertItem(
                'Out of Stock',
                outOfStockItems.length,
                Colors.red,
                Icons.error,
                () => _showItemsList(outOfStockItems, 'Out of Stock Items'),
              ),
              const SizedBox(height: 8),
            ],
            if (lowStockItems.isNotEmpty) ...[
              _buildAlertItem(
                'Low Stock',
                lowStockItems.length,
                Colors.orange,
                Icons.warning,
                () => _showItemsList(lowStockItems, 'Low Stock Items'),
              ),
              const SizedBox(height: 8),
            ],
            if (expiringSoonItems.isNotEmpty) ...[
              _buildAlertItem(
                'Expiring Soon',
                expiringSoonItems.length,
                Colors.purple,
                Icons.schedule,
                () => _showItemsList(expiringSoonItems, 'Expiring Soon Items'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAlertItem(
    String title,
    int count,
    Color color,
    IconData icon,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySummarySection(Map<InventoryCategory, Map<String, dynamic>> summary) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category Summary',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ...summary.entries.map((entry) {
              final category = entry.key;
              final data = entry.value;
              return _buildCategoryItem(category, data);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(InventoryCategory category, Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              category.categoryDisplay,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Expanded(
            child: Text(
              '${data['totalItems']} items',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Text(
              '\$${data['totalValue'].toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (data['lowStockItems'] > 0)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${data['lowStockItems']}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                if (data['outOfStockItems'] > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${data['outOfStockItems']}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsTab() {
    return Column(
      children: [
        // Search and Filters
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search items...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _searchQuery = '';
                            _applyFilters();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) {
                  _searchQuery = value;
                  _applyFilters();
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<InventoryCategory>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Categories'),
                        ),
                        ...InventoryCategory.values.map((category) =>
                          DropdownMenuItem(
                            value: category,
                            child: Text(category.categoryDisplay),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        _selectedCategory = value;
                        _applyFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: FilterChip(
                            label: const Text('Low Stock'),
                            selected: _showLowStockOnly,
                            onSelected: (selected) {
                              _showLowStockOnly = selected;
                              if (selected) _showOutOfStockOnly = false;
                              _applyFilters();
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilterChip(
                            label: const Text('Out of Stock'),
                            selected: _showOutOfStockOnly,
                            onSelected: (selected) {
                              _showOutOfStockOnly = selected;
                              if (selected) _showLowStockOnly = false;
                              _applyFilters();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Items List
        Expanded(
          child: _filteredItems.isEmpty
              ? const Center(
                  child: Text('No items found'),
                )
              : ListView.builder(
                  itemCount: _filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = _filteredItems[index];
                    return _buildInventoryItemCard(item);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInventoryItemCard(InventoryItem item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getItemStatusColor(item),
          child: Icon(
            _getItemStatusIcon(item),
            color: Colors.white,
          ),
        ),
        title: Text(
          item.name,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.description != null)
              Text(
                item.description!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  '${item.currentStock} ${item.unitDisplay}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '\$${item.costPerUnit}/${item.unitDisplay}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: item.stockPercentage / 100,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(_getItemStatusColor(item)),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Min: ${item.minimumStock}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                Text(
                  'Max: ${item.maximumStock}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleItemAction(value, item),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit),
                  SizedBox(width: 8),
                  Text('Edit'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'restock',
              child: Row(
                children: [
                  Icon(Icons.add),
                  SizedBox(width: 8),
                  Text('Restock'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'use',
              child: Row(
                children: [
                  Icon(Icons.remove),
                  SizedBox(width: 8),
                  Text('Use Stock'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'waste',
              child: Row(
                children: [
                  Icon(Icons.delete),
                  SizedBox(width: 8),
                  Text('Record Waste'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'transactions',
              child: Row(
                children: [
                  Icon(Icons.history),
                  SizedBox(width: 8),
                  Text('View History'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_forever),
                  SizedBox(width: 8),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _showItemDetails(item),
      ),
    );
  }

  Color _getItemStatusColor(InventoryItem item) {
    if (item.isOutOfStock) return Colors.red;
    if (item.isLowStock) return Colors.orange;
    if (item.isOverstocked) return Colors.purple;
    if (item.isExpired) return Colors.red;
    if (item.isExpiringSoon) return Colors.purple;
    return Colors.green;
  }

  IconData _getItemStatusIcon(InventoryItem item) {
    if (item.isOutOfStock) return Icons.error;
    if (item.isLowStock) return Icons.warning;
    if (item.isOverstocked) return Icons.inventory_2;
    if (item.isExpired) return Icons.block;
    if (item.isExpiringSoon) return Icons.schedule;
    return Icons.check_circle;
  }

  Widget _buildTransactionsTab() {
    final recentTransactions = _transactions
        .take(50) // Show last 50 transactions
        .toList();

    return Column(
      children: [
        // Transaction Summary
        Container(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Activity',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTransactionTypeCard('Restock', 'restock', Colors.green),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTransactionTypeCard('Usage', 'usage', Colors.blue),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTransactionTypeCard('Waste', 'waste', Colors.red),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),

        // Transactions List
        Expanded(
          child: recentTransactions.isEmpty
              ? const Center(
                  child: Text('No transactions found'),
                )
              : ListView.builder(
                  itemCount: recentTransactions.length,
                  itemBuilder: (context, index) {
                    final transaction = recentTransactions[index];
                    return _buildTransactionCard(transaction);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTransactionTypeCard(String title, String type, Color color) {
    final count = _transactions.where((t) => t.type == type).length;
    return Column(
      children: [
        Icon(Icons.circle, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildTransactionCard(InventoryTransaction transaction) {
    final item = _inventoryService.getItemById(transaction.inventoryItemId);
    final isPositive = transaction.type == 'restock' || transaction.type == 'adjustment';
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPositive ? Colors.green : Colors.red,
          child: Icon(
            isPositive ? Icons.add : Icons.remove,
            color: Colors.white,
          ),
        ),
        title: Text(
          item?.name ?? 'Unknown Item',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${transaction.type.toUpperCase()}: ${transaction.quantity} ${item?.unitDisplay ?? ''}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (transaction.reason != null)
              Text(
                transaction.reason!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            Text(
              DateFormat('MMM dd, yyyy HH:mm').format(transaction.timestamp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey,
              ),
            ),
          ],
        ),
        trailing: Text(
          isPositive ? '+${transaction.quantity}' : '-${transaction.quantity}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: isPositive ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    final totalValue = _inventoryService.getTotalInventoryValue();
    final lowStockValue = _inventoryService.getLowStockValue();
    final categorySummary = _inventoryService.getCategorySummary();
    final recentTransactionsSummary = _inventoryService.getRecentTransactionsSummary(7);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Value Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inventory Value',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildValueCard(
                          'Total Value',
                          '\$${totalValue.toStringAsFixed(2)}',
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildValueCard(
                          'Low Stock Value',
                          '\$${lowStockValue.toStringAsFixed(2)}',
                          Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Category Distribution
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Category Distribution',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  ...categorySummary.entries.map((entry) {
                    final category = entry.key;
                    final data = entry.value;
                    final percentage = totalValue > 0 ? (data['totalValue'] / totalValue) * 100 : 0;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(category.categoryDisplay),
                              ),
                              Text('${percentage.toStringAsFixed(1)}%'),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: percentage / 100,
                            backgroundColor: Colors.grey[300],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Recent Activity
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last 7 Days Activity',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActivityCard(
                          'Transactions',
                          recentTransactionsSummary['totalTransactions'].toString(),
                          Icons.receipt_long,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActivityCard(
                          'Restock Value',
                          '\$${recentTransactionsSummary['valueByType']?['restock']?.toStringAsFixed(2) ?? '0.00'}',
                          Icons.add_shopping_cart,
                          Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildValueCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Action Handlers

  void _handleMenuAction(String action) {
    switch (action) {
      case 'load_sample':
        _loadSampleData();
        break;
      case 'clear_data':
        _clearAllData();
        break;
    }
  }

  void _handleItemAction(String action, InventoryItem item) {
    switch (action) {
      case 'edit':
        _showEditItemDialog(item);
        break;
      case 'restock':
        _showRestockDialog(item);
        break;
      case 'use':
        _showUseStockDialog(item);
        break;
      case 'waste':
        _showWasteDialog(item);
        break;
      case 'transactions':
        _showItemTransactions(item);
        break;
      case 'delete':
        _showDeleteConfirmation(item);
        break;
    }
  }

  // Dialog Methods

  void _showAddItemDialog() {
    _showItemDialog();
  }

  void _showEditItemDialog(InventoryItem item) {
    _showItemDialog(item: item);
  }

  void _showItemDialog({InventoryItem? item}) {
    final isEditing = item != null;
    final formKey = GlobalKey<FormState>();
    
    // Controllers for form fields
    final nameController = TextEditingController(text: item?.name ?? '');
    final descriptionController = TextEditingController(text: item?.description ?? '');
    final currentStockController = TextEditingController(text: item?.currentStock.toString() ?? '0');
    final minimumStockController = TextEditingController(text: item?.minimumStock.toString() ?? '5');
    final maximumStockController = TextEditingController(text: item?.maximumStock.toString() ?? '100');
    final costPerUnitController = TextEditingController(text: item?.costPerUnit.toString() ?? '0.00');
    final supplierController = TextEditingController(text: item?.supplier ?? '');
    final supplierContactController = TextEditingController(text: item?.supplierContact ?? '');
    
    // Selected values
    InventoryCategory selectedCategory = item?.category ?? InventoryCategory.other;
    InventoryUnit selectedUnit = item?.unit ?? InventoryUnit.pieces;
    DateTime? selectedExpiryDate = item?.expiryDate;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEditing ? 'Edit Inventory Item' : 'Add Inventory Item'),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.7,
            child: Form(
              key: formKey,
              child: ListView(
                children: [
                  // Basic Information
                  Text(
                    'Basic Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Item Name
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Item Name *',
                      hintText: 'Enter inventory item name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.inventory_2),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Item name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Description
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'Enter item description (optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  
                  // Category and Unit
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<InventoryCategory>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.category),
                          ),
                          items: InventoryCategory.values.map((category) {
                            return DropdownMenuItem(
                              value: category,
                              child: Text(category.categoryDisplay),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedCategory = value!;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: DropdownButtonFormField<InventoryUnit>(
                          value: selectedUnit,
                          decoration: const InputDecoration(
                            labelText: 'Unit *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.straighten),
                          ),
                          items: InventoryUnit.values.map((unit) {
                            return DropdownMenuItem(
                              value: unit,
                              child: Text(_getUnitDisplay(unit)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedUnit = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Stock Information
                  Text(
                    'Stock Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: currentStockController,
                          decoration: const InputDecoration(
                            labelText: 'Current Stock *',
                            hintText: '0',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.inventory),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Current stock is required';
                            }
                            final stock = double.tryParse(value);
                            if (stock == null || stock < 0) {
                              return 'Enter valid stock amount';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: minimumStockController,
                          decoration: const InputDecoration(
                            labelText: 'Minimum Stock *',
                            hintText: '5',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.warning_amber),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Minimum stock is required';
                            }
                            final stock = double.tryParse(value);
                            if (stock == null || stock < 0) {
                              return 'Enter valid minimum stock';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: maximumStockController,
                          decoration: const InputDecoration(
                            labelText: 'Maximum Stock *',
                            hintText: '100',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.trending_up),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Maximum stock is required';
                            }
                            final maxStock = double.tryParse(value);
                            if (maxStock == null || maxStock <= 0) {
                              return 'Enter valid maximum stock';
                            }
                            final minStock = double.tryParse(minimumStockController.text) ?? 0;
                            if (maxStock <= minStock) {
                              return 'Maximum must be greater than minimum';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: costPerUnitController,
                          decoration: const InputDecoration(
                            labelText: 'Cost per Unit *',
                            hintText: '0.00',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType: TextInputType.numberWithOptions(decimal: true),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Cost per unit is required';
                            }
                            final cost = double.tryParse(value);
                            if (cost == null || cost < 0) {
                              return 'Enter valid cost';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Supplier Information
                  Text(
                    'Supplier Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: supplierController,
                    decoration: const InputDecoration(
                      labelText: 'Supplier',
                      hintText: 'Enter supplier name (optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: supplierContactController,
                    decoration: const InputDecoration(
                      labelText: 'Supplier Contact',
                      hintText: 'Enter supplier contact (optional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.contact_phone),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Expiry Date
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedExpiryDate ?? DateTime.now().add(const Duration(days: 30)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                      );
                      if (date != null) {
                        setState(() {
                          selectedExpiryDate = date;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Colors.grey),
                          const SizedBox(width: 12),
                          Text(
                            selectedExpiryDate != null
                                ? 'Expiry Date: ${DateFormat('MMM dd, yyyy').format(selectedExpiryDate!)}'
                                : 'Set Expiry Date (Optional)',
                            style: TextStyle(
                              color: selectedExpiryDate != null ? Colors.black87 : Colors.grey.shade600,
                            ),
                          ),
                          const Spacer(),
                          if (selectedExpiryDate != null)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedExpiryDate = null;
                                });
                              },
                              child: Icon(Icons.clear, color: Colors.grey.shade600),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  // Create or update inventory item
                  final inventoryItem = InventoryItem(
                    id: item?.id, // Keep existing ID for edits
                    name: nameController.text.trim(),
                    description: descriptionController.text.trim().isEmpty 
                        ? null 
                        : descriptionController.text.trim(),
                    category: selectedCategory,
                    unit: selectedUnit,
                    currentStock: double.parse(currentStockController.text),
                    minimumStock: double.parse(minimumStockController.text),
                    maximumStock: double.parse(maximumStockController.text),
                    costPerUnit: double.parse(costPerUnitController.text),
                    supplier: supplierController.text.trim().isEmpty 
                        ? null 
                        : supplierController.text.trim(),
                    supplierContact: supplierContactController.text.trim().isEmpty 
                        ? null 
                        : supplierContactController.text.trim(),
                    expiryDate: selectedExpiryDate,
                    createdAt: item?.createdAt ?? DateTime.now(),
                    updatedAt: DateTime.now(),
                  );

                  bool success;
                  if (isEditing) {
                    success = await _inventoryService.updateItem(inventoryItem);
                  } else {
                    success = await _inventoryService.addItem(inventoryItem);
                  }

                  if (success) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEditing 
                              ? '✅ Item "${inventoryItem.name}" updated successfully'
                              : '✅ Item "${inventoryItem.name}" added successfully',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadData(); // Refresh the data
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isEditing 
                              ? '❌ Failed to update item. Name might already exist.'
                              : '❌ Failed to add item. Name might already exist.',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isEditing ? Colors.orange : Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(isEditing ? 'Update Item' : 'Add Item'),
            ),
          ],
        ),
      ),
    );
  }

  String _getUnitDisplay(InventoryUnit unit) {
    switch (unit) {
      case InventoryUnit.pieces:
        return 'Pieces (pcs)';
      case InventoryUnit.grams:
        return 'Grams (g)';
      case InventoryUnit.kilograms:
        return 'Kilograms (kg)';
      case InventoryUnit.liters:
        return 'Liters (L)';
      case InventoryUnit.milliliters:
        return 'Milliliters (mL)';
      case InventoryUnit.ounces:
        return 'Ounces (oz)';
      case InventoryUnit.pounds:
        return 'Pounds (lbs)';
      case InventoryUnit.units:
        return 'Units';
    }
  }

  void _showRestockDialog(InventoryItem item) {
    final quantityController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restock ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              decoration: InputDecoration(
                labelText: 'Quantity (${item.unitDisplay})',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final quantity = double.tryParse(quantityController.text);
              if (quantity != null && quantity > 0) {
                await _inventoryService.restockItem(
                  item.id,
                  quantity,
                  reason: reasonController.text.isNotEmpty ? reasonController.text : null,
                );
                await _loadData();
                if (mounted) Navigator.of(context).pop();
              }
            },
            child: const Text('Restock'),
          ),
        ],
      ),
    );
  }

  void _showUseStockDialog(InventoryItem item) {
    final quantityController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Use Stock - ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              decoration: InputDecoration(
                labelText: 'Quantity (${item.unitDisplay})',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final quantity = double.tryParse(quantityController.text);
              if (quantity != null && quantity > 0) {
                await _inventoryService.useStock(
                  item.id,
                  quantity,
                  reason: reasonController.text.isNotEmpty ? reasonController.text : null,
                );
                await _loadData();
                if (mounted) Navigator.of(context).pop();
              }
            },
            child: const Text('Use Stock'),
          ),
        ],
      ),
    );
  }

  void _showWasteDialog(InventoryItem item) {
    final quantityController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Record Waste - ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              decoration: InputDecoration(
                labelText: 'Quantity (${item.unitDisplay})',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final quantity = double.tryParse(quantityController.text);
              if (quantity != null && quantity > 0) {
                await _inventoryService.recordWaste(
                  item.id,
                  quantity,
                  reason: reasonController.text.isNotEmpty ? reasonController.text : null,
                );
                await _loadData();
                if (mounted) Navigator.of(context).pop();
              }
            },
            child: const Text('Record Waste'),
          ),
        ],
      ),
    );
  }

  void _showItemDetails(InventoryItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (item.description != null) ...[
                Text('Description: ${item.description}'),
                const SizedBox(height: 8),
              ],
              Text('Category: ${item.category.categoryDisplay}'),
              Text('Unit: ${item.unitDisplay}'),
              Text('Current Stock: ${item.currentStock} ${item.unitDisplay}'),
              Text('Minimum Stock: ${item.minimumStock} ${item.unitDisplay}'),
              Text('Maximum Stock: ${item.maximumStock} ${item.unitDisplay}'),
              Text('Cost per Unit: \$${item.costPerUnit}'),
              Text('Total Value: \$${item.totalValue.toStringAsFixed(2)}'),
              if (item.supplier != null) Text('Supplier: ${item.supplier}'),
              if (item.supplierContact != null) Text('Contact: ${item.supplierContact}'),
              if (item.lastRestocked != null)
                Text('Last Restocked: ${DateFormat('MMM dd, yyyy').format(item.lastRestocked!)}'),
              if (item.expiryDate != null)
                Text('Expiry Date: ${DateFormat('MMM dd, yyyy').format(item.expiryDate!)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showItemTransactions(InventoryItem item) {
    final transactions = _inventoryService.getTransactionsForItem(item.id);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${item.name} - Transaction History'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: transactions.isEmpty
              ? const Center(child: Text('No transactions found'))
              : ListView.builder(
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    return _buildTransactionCard(transaction);
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showItemsList(List<InventoryItem> items, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListTile(
                title: Text(item.name),
                subtitle: Text('${item.currentStock} ${item.unitDisplay}'),
                trailing: Text('\$${item.totalValue.toStringAsFixed(2)}'),
                onTap: () {
                  Navigator.of(context).pop();
                  _showItemDetails(item);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(InventoryItem item) async {
    final confirmed = await ConfirmationDialogHelper.showDeleteConfirmation(
      context,
      itemName: item.name,
      message: 'Are you sure you want to delete "${item.name}"? This action cannot be undone.',
    );

    if (confirmed == true) {
      await _inventoryService.deleteItem(item.id);
      await _loadData();
    }
  }

  Future<void> _loadSampleData() async {
    setState(() => _isLoading = true);
    try {
      await _inventoryService.loadSampleData();
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sample data loaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ErrorDialogHelper.showError(context, title: 'Error', message: 'Error loading sample data: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await ConfirmationDialogHelper.showConfirmation(
      context,
      title: 'Clear All Data',
      message: 'Are you sure you want to clear all inventory data? This action cannot be undone.',
      confirmText: 'Clear',
      cancelText: 'Cancel',
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _inventoryService.clearAllData();
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All data cleared successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ErrorDialogHelper.showError(context, title: 'Error', message: 'Error clearing data: $e');
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
} 