import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ai_pos_system/models/order_log.dart';
import 'package:ai_pos_system/services/order_log_service.dart';
import 'package:ai_pos_system/widgets/universal_navigation.dart';

class OrderAuditScreen extends StatefulWidget {
  final String? orderId;
  
  const OrderAuditScreen({super.key, this.orderId});

  @override
  State<OrderAuditScreen> createState() => _OrderAuditScreenState();
}

class _OrderAuditScreenState extends State<OrderAuditScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String _searchQuery = '';
  OrderLogAction? _selectedAction;
  LogLevel? _selectedLevel;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedUserId;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    
    // Reload logs for the specific order if orderId is provided
    if (widget.orderId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _reloadOrderLogs();
      });
    }
  }

  Future<void> _reloadOrderLogs() async {
    try {
      final orderLogService = Provider.of<OrderLogService>(context, listen: false);
      await orderLogService.reloadLogsForOrder(widget.orderId!);
      debugPrint('✅ Reloaded logs for order ${widget.orderId}');
    } catch (e) {
      debugPrint('❌ Failed to reload logs for order ${widget.orderId}: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: UniversalAppBar(
        title: widget.orderId != null ? 'Order Audit - ${widget.orderId}' : 'Order Audit Trail',
        onBack: () => Navigator.of(context).pop(),
      ),
      body: Consumer<OrderLogService>(
        builder: (context, orderLogService, child) {
          return Column(
            children: [
              _buildSearchAndFilters(orderLogService),
              _buildTabs(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAllLogsTab(orderLogService),
                    _buildFinancialLogsTab(orderLogService),
                    _buildKitchenLogsTab(orderLogService),
                    _buildAnalyticsTab(orderLogService),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchAndFilters(OrderLogService orderLogService) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search logs by description, order number, or user...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Filter chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Action filter
              FilterChip(
                label: Text(_selectedAction?.toString().split('.').last ?? 'All Actions'),
                selected: _selectedAction != null,
                onSelected: (selected) {
                  _showActionFilterDialog(context);
                },
              ),
              
              // Level filter
              FilterChip(
                label: Text(_selectedLevel?.toString().split('.').last ?? 'All Levels'),
                selected: _selectedLevel != null,
                onSelected: (selected) {
                  _showLevelFilterDialog(context);
                },
              ),
              
              // Date range filter
              FilterChip(
                label: Text(_startDate != null && _endDate != null 
                    ? '${DateFormat.MMMd().format(_startDate!)} - ${DateFormat.MMMd().format(_endDate!)}'
                    : 'Date Range'),
                selected: _startDate != null && _endDate != null,
                onSelected: (selected) {
                  _showDateRangeDialog(context);
                },
              ),
              
              // Clear filters
              if (_selectedAction != null || _selectedLevel != null || _startDate != null)
                ActionChip(
                  label: const Text('Clear Filters'),
                  onPressed: () {
                    setState(() {
                      _selectedAction = null;
                      _selectedLevel = null;
                      _startDate = null;
                      _endDate = null;
                      _selectedUserId = null;
                    });
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.2),
          ),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(
            icon: Icon(Icons.list_alt),
            text: 'All Logs',
          ),
          Tab(
            icon: Icon(Icons.attach_money),
            text: 'Financial',
          ),
          Tab(
            icon: Icon(Icons.restaurant),
            text: 'Kitchen',
          ),
          Tab(
            icon: Icon(Icons.analytics),
            text: 'Analytics',
          ),
        ],
      ),
    );
  }

  Widget _buildAllLogsTab(OrderLogService orderLogService) {
    final logs = widget.orderId != null 
        ? orderLogService.getLogsForOrder(widget.orderId!)
        : orderLogService.recentLogs;
    final filteredLogs = _getFilteredLogs(logs);
    
    debugPrint('🔍 Audit Debug: orderId=${widget.orderId}, totalLogs=${logs.length}, filteredLogs=${filteredLogs.length}');
    if (widget.orderId != null) {
      debugPrint('🔍 Order-specific logs: ${logs.map((l) => '${l.action}: ${l.description}').join(', ')}');
    }
    
    if (filteredLogs.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: 'No Logs Found',
        message: 'No order operations match your current filters.',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: filteredLogs.length,
      itemBuilder: (context, index) {
        final log = filteredLogs[index];
        return _buildLogCard(log);
      },
    );
  }

  Widget _buildFinancialLogsTab(OrderLogService orderLogService) {
    final logs = widget.orderId != null 
        ? orderLogService.getLogsForOrder(widget.orderId!)
        : orderLogService.financialLogs;
    final financialLogs = _getFilteredLogs(logs);
    
    if (financialLogs.isEmpty) {
      return _buildEmptyState(
        icon: Icons.account_balance_wallet,
        title: 'No Financial Operations',
        message: 'No financial operations found matching your filters.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: financialLogs.length,
      itemBuilder: (context, index) {
        final log = financialLogs[index];
        return _buildLogCard(log, showFinancialDetails: true);
      },
    );
  }

  Widget _buildKitchenLogsTab(OrderLogService orderLogService) {
    final logs = widget.orderId != null 
        ? orderLogService.getLogsForOrder(widget.orderId!)
        : orderLogService.kitchenLogs;
    final kitchenLogs = _getFilteredLogs(logs);
    
    if (kitchenLogs.isEmpty) {
      return _buildEmptyState(
        icon: Icons.restaurant_menu,
        title: 'No Kitchen Operations',
        message: 'No kitchen operations found matching your filters.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: kitchenLogs.length,
      itemBuilder: (context, index) {
        final log = kitchenLogs[index];
        return _buildLogCard(log, showKitchenDetails: true);
      },
    );
  }

  Widget _buildAnalyticsTab(OrderLogService orderLogService) {
    final analytics = orderLogService.getAnalytics(
      startDate: _startDate,
      endDate: _endDate,
    );
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalyticsCard(
            'Overview',
            [
              _buildAnalyticItem('Total Operations', analytics['total_logs'].toString()),
              _buildAnalyticItem('Financial Operations', analytics['financial_operations'].toString()),
              _buildAnalyticItem('Kitchen Operations', analytics['kitchen_operations'].toString()),
              _buildAnalyticItem('Errors', analytics['error_count'].toString()),
              _buildAnalyticItem('Warnings', analytics['warning_count'].toString()),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildAnalyticsCard(
            'Top Actions',
            (analytics['action_counts'] as Map<String, int>)
                .entries
                .take(5)
                .map((entry) => _buildAnalyticItem(entry.key, entry.value.toString()))
                .toList(),
          ),
          const SizedBox(height: 16),
          
          _buildAnalyticsCard(
            'User Activity',
            (analytics['user_counts'] as Map<String, int>)
                .entries
                .take(5)
                .map((entry) => _buildAnalyticItem(entry.key, entry.value.toString()))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(OrderLog log, {bool showFinancialDetails = false, bool showKitchenDetails = false}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _showLogDetails(log),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _getActionColor(log.action).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      log.actionIcon,
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          log.actionDescription,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Order ${log.orderNumber}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getLevelColor(log.level),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      log.level.toString().split('.').last.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              Text(
                log.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              
              if (showFinancialDetails && log.financialImpact != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: log.financialImpact! >= 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        log.financialImpact! >= 0 ? Icons.trending_up : Icons.trending_down,
                        color: log.financialImpact! >= 0 ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${log.financialImpact! >= 0 ? '+' : ''}\$${log.financialImpact!.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          color: log.financialImpact! >= 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    log.performedByName ?? log.performedBy,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM d, h:mm a').format(log.timestamp),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard(String title, List<Widget> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  List<OrderLog> _getFilteredLogs(List<OrderLog> logs) {
    return logs.where((log) {
      // Order ID filter (when viewing specific order audit)
      if (widget.orderId != null && log.orderId != widget.orderId) {
        return false;
      }
      
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final searchTerms = [
          log.description.toLowerCase(),
          log.orderNumber.toLowerCase(),
          log.performedByName?.toLowerCase() ?? '',
          log.performedBy.toLowerCase(),
        ];
        
        if (!searchTerms.any((term) => term.contains(_searchQuery))) {
          return false;
        }
      }
      
      // Action filter
      if (_selectedAction != null && log.action != _selectedAction) {
        return false;
      }
      
      // Level filter
      if (_selectedLevel != null && log.level != _selectedLevel) {
        return false;
      }
      
      // Date range filter
      if (_startDate != null && log.timestamp.isBefore(_startDate!)) {
        return false;
      }
      
      if (_endDate != null && log.timestamp.isAfter(_endDate!)) {
        return false;
      }
      
      return true;
    }).toList();
  }

  Color _getActionColor(OrderLogAction action) {
    switch (action) {
      case OrderLogAction.created:
        return Colors.green;
      case OrderLogAction.cancelled:
        return Colors.red;
      case OrderLogAction.completed:
        return Colors.blue;
      case OrderLogAction.paymentProcessed:
        return Colors.purple;
      case OrderLogAction.sentToKitchen:
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  Color _getLevelColor(LogLevel level) {
    switch (level) {
      case LogLevel.info:
        return Colors.blue;
      case LogLevel.warning:
        return Colors.orange;
      case LogLevel.error:
        return Colors.red;
      case LogLevel.critical:
        return Colors.purple;
    }
  }

  void _showActionFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Action'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('All Actions'),
                leading: Radio<OrderLogAction?>(
                  value: null,
                  groupValue: _selectedAction,
                  onChanged: (value) {
                    setState(() {
                      _selectedAction = value;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              ),
              ...OrderLogAction.values.map((action) => ListTile(
                title: Text(action.toString().split('.').last),
                leading: Radio<OrderLogAction?>(
                  value: action,
                  groupValue: _selectedAction,
                  onChanged: (value) {
                    setState(() {
                      _selectedAction = value;
                    });
                    Navigator.of(context).pop();
                  },
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _showLevelFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Level'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Levels'),
              leading: Radio<LogLevel?>(
                value: null,
                groupValue: _selectedLevel,
                onChanged: (value) {
                  setState(() {
                    _selectedLevel = value;
                  });
                  Navigator.of(context).pop();
                },
              ),
            ),
            ...LogLevel.values.map((level) => ListTile(
              title: Text(level.toString().split('.').last),
              leading: Radio<LogLevel?>(
                value: level,
                groupValue: _selectedLevel,
                onChanged: (value) {
                  setState(() {
                    _selectedLevel = value;
                  });
                  Navigator.of(context).pop();
                },
              ),
            )),
          ],
        ),
      ),
    );
  }

  void _showDateRangeDialog(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
    );
    
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  void _showLogDetails(OrderLog log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(log.actionDescription),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('Order Number', log.orderNumber),
                _buildDetailRow('Action', log.actionDescription),
                _buildDetailRow('Level', log.level.toString().split('.').last),
                _buildDetailRow('Performed By', log.performedByName ?? log.performedBy),
                _buildDetailRow('Timestamp', DateFormat('MMM d, yyyy h:mm:ss a').format(log.timestamp)),
                _buildDetailRow('Description', log.description),
                if (log.notes != null) _buildDetailRow('Notes', log.notes!),
                if (log.financialImpact != null) 
                  _buildDetailRow('Financial Impact', '\$${log.financialImpact!.toStringAsFixed(2)}'),
                
                // Special handling for sent to kitchen operations
                if (log.action == OrderLogAction.sentToKitchen && log.afterData.containsKey('items_sent')) ...[
                  const SizedBox(height: 16),
                  Text('Items Sent to Kitchen:', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...(_buildKitchenItemsList(log.afterData['items_sent'] as List<dynamic>? ?? [])),
                  
                  if (log.afterData.containsKey('items_details')) ...[
                    const SizedBox(height: 12),
                    Text('Item Summary:', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 4),
                    ...(log.afterData['items_details'] as List<dynamic>? ?? []).map((detail) => 
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 2),
                        child: Text('• $detail', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                      )
                    ),
                  ],
                ] else ...[
                  // Standard before/after data display for other actions
                  if (log.beforeData.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Before:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(_formatDataForDisplay(log.beforeData)),
                  ],
                  if (log.afterData.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('After:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(_formatDataForDisplay(log.afterData)),
                  ],
                ],
              ],
            ),
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
  
  List<Widget> _buildKitchenItemsList(List<dynamic> items) {
    return items.map((item) {
      final itemMap = item as Map<String, dynamic>;
      return Card(
        margin: const EdgeInsets.only(bottom: 6),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${itemMap['quantity']}x ${itemMap['name']}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                  Text(
                    '\$${(itemMap['total_price'] ?? 0.0).toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              if (itemMap['selected_variant'] != null && itemMap['selected_variant'].toString().isNotEmpty) 
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Variant: ${itemMap['selected_variant']}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              if (itemMap['selected_modifiers'] is List && (itemMap['selected_modifiers'] as List).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Modifiers: ${(itemMap['selected_modifiers'] as List).join(', ')}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ),
              if (itemMap['special_instructions'] != null && itemMap['special_instructions'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Instructions: ${itemMap['special_instructions']}',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontStyle: FontStyle.italic),
                  ),
                ),
              if (itemMap['notes'] != null && itemMap['notes'].toString().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Chef Notes: ${itemMap['notes']}',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700, fontStyle: FontStyle.italic),
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();
  }
  
  String _formatDataForDisplay(Map<String, dynamic> data) {
    if (data.isEmpty) return 'No data';
    
    final filteredData = Map<String, dynamic>.from(data);
    // Remove items that are better displayed in special format
    filteredData.removeWhere((key, value) => ['items_sent', 'items_details', 'total_items_sent'].contains(key));
    
    if (filteredData.isEmpty) return '';
    
    return filteredData.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
} 