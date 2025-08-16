import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:ai_pos_system/models/activity_log.dart';
import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/services/activity_log_service.dart';
import 'package:ai_pos_system/services/user_service.dart';
import 'package:ai_pos_system/widgets/universal_navigation.dart';

class UserActivityMonitoringScreen extends StatefulWidget {
  final User user;
  final bool showAppBar;
  
  const UserActivityMonitoringScreen({super.key, required this.user, this.showAppBar = true});

  @override
  State<UserActivityMonitoringScreen> createState() => _UserActivityMonitoringScreenState();
}

class _UserActivityMonitoringScreenState extends State<UserActivityMonitoringScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  String _searchQuery = '';
  ActivityAction? _selectedAction;
  ActivityCategory? _selectedCategory;
  ActivityLevel? _selectedLevel;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedUserId;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
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
    final body = Consumer<ActivityLogService>(
      builder: (context, activityLogService, child) {
        return Column(
          children: [
            _buildSearchAndFilters(activityLogService),
            _buildTabs(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAllActivitiesTab(activityLogService),
                  _buildUserActivitiesTab(activityLogService),
                  _buildFinancialActivitiesTab(activityLogService),
                  _buildSensitiveActivitiesTab(activityLogService),
                  _buildErrorsTab(activityLogService),
                  _buildAnalyticsTab(activityLogService),
                ],
              ),
            ),
          ],
        );
      },
    );

    if (!widget.showAppBar) {
      // When used as a tab in AdminPanelScreen, just return the body content
      return body;
    }

    // When used as a standalone screen, show the full Scaffold with AppBar
    return Scaffold(
      appBar: UniversalAppBar(
        title: 'User Activity Monitor',
        currentUser: widget.user,
        onBack: () => Navigator.of(context).pop(),
        additionalActions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportLogs,
            tooltip: 'Export Logs',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _showCleanupDialog,
            tooltip: 'Cleanup Old Logs',
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildSearchAndFilters(ActivityLogService activityLogService) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withOpacity(0.2),
          ),
        ),
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search activities...',
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
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Filters
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildActionFilter(),
              _buildCategoryFilter(),
              _buildLevelFilter(),
              _buildUserFilter(),
              _buildDateRangeFilter(context),
              _buildClearFiltersButton(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionFilter() {
    return DropdownButton<ActivityAction?>(
      value: _selectedAction,
      hint: const Text('Action'),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Actions')),
        ...ActivityAction.values.map((action) => DropdownMenuItem(
          value: action,
          child: Text(action.toString().split('.').last),
        )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedAction = value;
        });
      },
    );
  }

  Widget _buildCategoryFilter() {
    return DropdownButton<ActivityCategory?>(
      value: _selectedCategory,
      hint: const Text('Category'),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Categories')),
        ...ActivityCategory.values.map((category) => DropdownMenuItem(
          value: category,
          child: Text(category.toString().split('.').last),
        )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedCategory = value;
        });
      },
    );
  }

  Widget _buildLevelFilter() {
    return DropdownButton<ActivityLevel?>(
      value: _selectedLevel,
      hint: const Text('Level'),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Levels')),
        ...ActivityLevel.values.map((level) => DropdownMenuItem(
          value: level,
          child: Text(level.toString().split('.').last),
        )),
      ],
      onChanged: (value) {
        setState(() {
          _selectedLevel = value;
        });
      },
    );
  }

  Widget _buildUserFilter() {
    return Consumer<UserService>(
      builder: (context, userService, child) {
        final users = userService.users;
        return DropdownButton<String?>(
          value: _selectedUserId,
          hint: const Text('User'),
          items: [
            const DropdownMenuItem(value: null, child: Text('All Users')),
            ...users.map((user) => DropdownMenuItem(
              value: user.id,
              child: Text(user.name),
            )),
          ],
          onChanged: (value) {
            setState(() {
              _selectedUserId = value;
            });
          },
        );
      },
    );
  }

  Widget _buildDateRangeFilter(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.date_range),
      label: Text(_startDate != null && _endDate != null
          ? '${DateFormat('MMM d').format(_startDate!)} - ${DateFormat('MMM d').format(_endDate!)}'
          : 'Date Range'),
      onPressed: () => _selectDateRange(context),
    );
  }

  Widget _buildClearFiltersButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.clear_all),
      label: const Text('Clear'),
      onPressed: () {
        setState(() {
          _selectedAction = null;
          _selectedCategory = null;
          _selectedLevel = null;
          _selectedUserId = null;
          _startDate = null;
          _endDate = null;
          _searchController.clear();
          _searchQuery = '';
        });
      },
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabs: const [
          Tab(icon: Icon(Icons.list_alt), text: 'All Activities'),
          Tab(icon: Icon(Icons.people), text: 'User Activities'),
          Tab(icon: Icon(Icons.attach_money), text: 'Financial'),
          Tab(icon: Icon(Icons.security), text: 'Sensitive'),
          Tab(icon: Icon(Icons.error), text: 'Errors'),
          Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
        ],
      ),
    );
  }

  Widget _buildAllActivitiesTab(ActivityLogService activityLogService) {
    final filteredLogs = _getFilteredLogs(activityLogService.recentLogs);
    
    if (filteredLogs.isEmpty) {
      return _buildEmptyState(
        icon: Icons.history,
        title: 'No Activities Found',
        message: 'No activities match your current filters.',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: filteredLogs.length,
      itemBuilder: (context, index) {
        final log = filteredLogs[index];
        return _buildActivityCard(log);
      },
    );
  }

  Widget _buildUserActivitiesTab(ActivityLogService activityLogService) {
    return Consumer<UserService>(
      builder: (context, userService, child) {
        final users = userService.users;
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final userLogs = activityLogService.getLogsForUser(user.id);
            final summary = activityLogService.getUserActivitySummary(user.id);
            
            return _buildUserSummaryCard(user, summary, userLogs);
          },
        );
      },
    );
  }

  Widget _buildFinancialActivitiesTab(ActivityLogService activityLogService) {
    final financialLogs = _getFilteredLogs(activityLogService.financialLogs);
    
    if (financialLogs.isEmpty) {
      return _buildEmptyState(
        icon: Icons.account_balance_wallet,
        title: 'No Financial Activities',
        message: 'No financial operations found.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: financialLogs.length,
      itemBuilder: (context, index) {
        final log = financialLogs[index];
        return _buildActivityCard(log, showFinancialDetails: true);
      },
    );
  }

  Widget _buildSensitiveActivitiesTab(ActivityLogService activityLogService) {
    final sensitiveLogs = _getFilteredLogs(activityLogService.sensitiveOperationLogs);
    
    if (sensitiveLogs.isEmpty) {
      return _buildEmptyState(
        icon: Icons.security,
        title: 'No Sensitive Activities',
        message: 'No sensitive operations found.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sensitiveLogs.length,
      itemBuilder: (context, index) {
        final log = sensitiveLogs[index];
        return _buildActivityCard(log, showSensitiveDetails: true);
      },
    );
  }

  Widget _buildErrorsTab(ActivityLogService activityLogService) {
    final errorLogs = _getFilteredLogs(
      activityLogService.getLogsByLevel(ActivityLevel.error) +
      activityLogService.getLogsByLevel(ActivityLevel.critical)
    );
    
    if (errorLogs.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle,
        title: 'No Errors',
        message: 'No error logs found.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: errorLogs.length,
      itemBuilder: (context, index) {
        final log = errorLogs[index];
        return _buildActivityCard(log, showErrorDetails: true);
      },
    );
  }

  Widget _buildAnalyticsTab(ActivityLogService activityLogService) {
    final analytics = activityLogService.getAnalytics(
      startDate: _startDate,
      endDate: _endDate,
      userId: _selectedUserId,
    );
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAnalyticsCard('Overview', [
            _buildAnalyticItem('Total Activities', analytics['total_logs'].toString()),
            _buildAnalyticItem('Unique Users', analytics['unique_users'].toString()),
            _buildAnalyticItem('Unique Screens', analytics['unique_screens'].toString()),
            _buildAnalyticItem('Financial Operations', analytics['financial_operations'].toString()),
            _buildAnalyticItem('Sensitive Operations', analytics['sensitive_operations'].toString()),
            _buildAnalyticItem('Errors', analytics['error_count'].toString()),
            _buildAnalyticItem('Warnings', analytics['warning_count'].toString()),
          ]),
          const SizedBox(height: 16),
          
          _buildAnalyticsCard('Top Actions', 
            (analytics['action_counts'] as Map<String, int>)
                .entries.take(10)
                .map((entry) => _buildAnalyticItem(entry.key, entry.value.toString()))
                .toList()),
          const SizedBox(height: 16),
          
          _buildAnalyticsCard('Top Categories',
            (analytics['category_counts'] as Map<String, int>)
                .entries.take(10)
                .map((entry) => _buildAnalyticItem(entry.key, entry.value.toString()))
                .toList()),
          const SizedBox(height: 16),
          
          _buildAnalyticsCard('User Activity',
            (analytics['user_counts'] as Map<String, int>)
                .entries.take(10)
                .map((entry) => _buildAnalyticItem(entry.key, entry.value.toString()))
                .toList()),
        ],
      ),
    );
  }

  Widget _buildActivityCard(ActivityLog log, {
    bool showFinancialDetails = false,
    bool showSensitiveDetails = false,
    bool showErrorDetails = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getLevelColor(log.level),
          child: Icon(
            _getActionIcon(log.action),
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          log.description,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('By: ${log.performedByName} (${log.performedByRole})'),
            Text('Time: ${DateFormat('MMM d, yyyy h:mm:ss a').format(log.timestamp)}'),
            if (log.screenName != null) Text('Screen: ${log.screenName}'),
            if (showFinancialDetails && log.financialAmount != null)
              Text('Amount: \$${log.financialAmount!.toStringAsFixed(2)}', 
                   style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
            if (showErrorDetails && log.errorMessage != null)
              Text('Error: ${log.errorMessage}', 
                   style: const TextStyle(color: Colors.red)),
            if (log.notes != null) Text('Notes: ${log.notes}'),
          ],
        ),
        trailing: Chip(
          label: Text(
            log.category.toString().split('.').last,
            style: const TextStyle(fontSize: 10),
          ),
          backgroundColor: _getCategoryColor(log.category),
        ),
        onTap: () => _showActivityDetails(log),
      ),
    );
  }

  Widget _buildUserSummaryCard(User user, Map<String, dynamic> summary, List<ActivityLog> userLogs) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Text(user.name.substring(0, 1).toUpperCase()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(user.role.toString().split('.').last, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                Text('${summary['total_activities']} activities', 
                     style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildMetricChip('Financial', '${summary['sensitive_operations']}', Colors.green)),
                Expanded(child: _buildMetricChip('Sensitive', '${summary['sensitive_operations']}', Colors.orange)),
                Expanded(child: _buildMetricChip('Errors', '${summary['error_count']}', Colors.red)),
              ],
            ),
            if (userLogs.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Last activity: ${DateFormat('MMM d, h:mm a').format(userLogs.first.timestamp)}',
                   style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricChip(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: color, fontSize: 10)),
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
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...items,
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String title, required String message}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  List<ActivityLog> _getFilteredLogs(List<ActivityLog> logs) {
    return logs.where((log) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final searchTerms = [
          log.description.toLowerCase(),
          log.performedByName.toLowerCase(),
          log.performedByRole.toLowerCase(),
          log.targetName?.toLowerCase() ?? '',
          log.screenName?.toLowerCase() ?? '',
        ];
        
        if (!searchTerms.any((term) => term.contains(_searchQuery))) {
          return false;
        }
      }
      
      // Action filter
      if (_selectedAction != null && log.action != _selectedAction) {
        return false;
      }
      
      // Category filter
      if (_selectedCategory != null && log.category != _selectedCategory) {
        return false;
      }
      
      // Level filter
      if (_selectedLevel != null && log.level != _selectedLevel) {
        return false;
      }
      
      // User filter
      if (_selectedUserId != null && log.performedBy != _selectedUserId) {
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

  Color _getLevelColor(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.info:
        return Colors.blue;
      case ActivityLevel.warning:
        return Colors.orange;
      case ActivityLevel.error:
        return Colors.red;
      case ActivityLevel.critical:
        return Colors.purple;
      case ActivityLevel.security:
        return Colors.pink;
    }
  }

  Color _getCategoryColor(ActivityCategory category) {
    switch (category) {
      case ActivityCategory.authentication:
        return Colors.green;
      case ActivityCategory.userManagement:
        return Colors.blue;
      case ActivityCategory.menuManagement:
        return Colors.orange;
      case ActivityCategory.orderManagement:
        return Colors.purple;
      case ActivityCategory.financial:
        return Colors.green;
      case ActivityCategory.kitchen:
        return Colors.red;
      case ActivityCategory.inventory:
        return Colors.brown;
      case ActivityCategory.system:
        return Colors.grey;
      case ActivityCategory.navigation:
        return Colors.indigo;
      case ActivityCategory.printing:
        return Colors.deepOrange;
      case ActivityCategory.reporting:
        return Colors.teal;
    }
  }

  IconData _getActionIcon(ActivityAction action) {
    switch (action) {
      case ActivityAction.login:
        return Icons.login;
      case ActivityAction.logout:
        return Icons.logout;
      case ActivityAction.userCreated:
      case ActivityAction.userUpdated:
      case ActivityAction.userDeleted:
        return Icons.person;
      case ActivityAction.menuItemCreated:
      case ActivityAction.menuItemUpdated:
      case ActivityAction.menuItemDeleted:
        return Icons.restaurant_menu;
      case ActivityAction.orderCreated:
      case ActivityAction.orderUpdated:
        return Icons.receipt;
      case ActivityAction.paymentProcessed:
        return Icons.payment;
      case ActivityAction.screenAccessed:
        return Icons.screen_lock_portrait;
      case ActivityAction.adminPanelAccessed:
        return Icons.admin_panel_settings;
      default:
        return Icons.circle;
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
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

  void _showActivityDetails(ActivityLog log) {
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
                _buildDetailRow('Action', log.actionDescription),
                _buildDetailRow('Category', log.category.toString().split('.').last),
                _buildDetailRow('Level', log.level.toString().split('.').last),
                _buildDetailRow('Performed By', '${log.performedByName} (${log.performedByRole})'),
                _buildDetailRow('Timestamp', DateFormat('MMM d, yyyy h:mm:ss a').format(log.timestamp)),
                _buildDetailRow('Description', log.description),
                if (log.targetName != null) _buildDetailRow('Target', log.targetName!),
                if (log.screenName != null) _buildDetailRow('Screen', log.screenName!),
                if (log.financialAmount != null) 
                  _buildDetailRow('Amount', '\$${log.financialAmount!.toStringAsFixed(2)}'),
                if (log.notes != null) _buildDetailRow('Notes', log.notes!),
                if (log.errorMessage != null) _buildDetailRow('Error', log.errorMessage!),
                if (log.deviceId != null) _buildDetailRow('Device', log.deviceId!),
                if (log.sessionId != null) _buildDetailRow('Session', log.sessionId!),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _exportLogs() async {
    final activityLogService = Provider.of<ActivityLogService>(context, listen: false);
    
    try {
      await activityLogService.exportLogs(
        startDate: _startDate,
        endDate: _endDate,
        userId: _selectedUserId,
      );
      
      // Here you would implement file saving logic
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logs exported successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export logs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showCleanupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cleanup Old Logs'),
        content: const Text('This will remove activity logs older than 30 days. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              final activityLogService = Provider.of<ActivityLogService>(context, listen: false);
              await activityLogService.cleanupOldLogs();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Old logs cleaned up successfully'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Cleanup'),
          ),
        ],
      ),
    );
  }
} 