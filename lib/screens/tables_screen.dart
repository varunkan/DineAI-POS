import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_pos_system/models/table.dart' as restaurant_table;
import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/services/table_service.dart';
import 'package:ai_pos_system/services/order_service.dart';
import 'package:ai_pos_system/widgets/loading_overlay.dart';
import 'package:ai_pos_system/widgets/error_dialog.dart';
import 'package:ai_pos_system/widgets/back_button.dart';
import 'package:ai_pos_system/widgets/confirmation_dialog.dart';
import '../widgets/form_field.dart';

/// Screen that displays and manages restaurant tables.
/// 
/// This screen shows all tables in a grid layout with their status and allows
/// users to interact with tables based on their role.
class TablesScreen extends StatefulWidget {
  final User? user;
  final bool showAppBar;

  const TablesScreen({super.key, this.user, this.showAppBar = true});

  @override
  _TablesScreenState createState() => _TablesScreenState();
}

class _TablesScreenState extends State<TablesScreen> with TickerProviderStateMixin {
  List<restaurant_table.Table> _tables = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all';
  late TabController _tabController;

  // Filter options
  static const List<String> filterOptions = [
    'all',
    'available',
    'occupied',
    'reserved',
    'cleaning',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTables();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  /// Loads the tables from the service.
  void _loadTables() {
    setState(() {
      _isLoading = true;
    });

    Provider.of<TableService>(context, listen: false).getTables().then((tables) {
      setState(() {
        _tables = tables;
        _isLoading = false;
      });
    }).catchError((e) {
      if (mounted) {
        ErrorDialogHelper.showError(
          context,
          title: 'Error Loading Tables',
          message: 'Failed to load tables: $e',
        );
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  /// Refreshes the tables list.
  void _refreshTables() {
    _loadTables();
  }

  List<restaurant_table.Table> get _filteredTables {
    List<restaurant_table.Table> tables = _tables;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      tables = tables.where((table) {
        final query = _searchQuery.toLowerCase();
        return table.number.toString().contains(query) ||
               table.customerName?.toLowerCase().contains(query) == true ||
               table.userId?.toLowerCase().contains(query) == true;
      }).toList();
    }

    // Apply status filter
    switch (_selectedFilter) {
      case 'available':
        tables = tables.where((table) => table.status == restaurant_table.TableStatus.available).toList();
        break;
      case 'occupied':
        tables = tables.where((table) => table.status == restaurant_table.TableStatus.occupied).toList();
        break;
      case 'reserved':
        tables = tables.where((table) => table.status == restaurant_table.TableStatus.reserved).toList();
        break;
      case 'cleaning':
        tables = tables.where((table) => table.status == restaurant_table.TableStatus.cleaning).toList();
        break;
    }

    // Sort tables by number
    tables.sort((a, b) => a.number.compareTo(b.number));
    return tables;
  }

  List<restaurant_table.Table> get _availableTables => _filteredTables.where((table) => 
    table.status == restaurant_table.TableStatus.available).toList();

  List<restaurant_table.Table> get _occupiedTables => _filteredTables.where((table) => 
    table.status == restaurant_table.TableStatus.occupied).toList();

  List<restaurant_table.Table> get _reservedTables => _filteredTables.where((table) => 
    table.status == restaurant_table.TableStatus.reserved).toList();

  List<restaurant_table.Table> get _cleaningTables => _filteredTables.where((table) => 
    table.status == restaurant_table.TableStatus.cleaning).toList();

  /// Creates a new table with validation and error handling.
  Future<void> _createTable(int number, int capacity) async {
    setState(() {
      _isLoading = true;
    });

    try {
      await Provider.of<TableService>(context, listen: false).createTable(
        number,
        capacity,
        userId: widget.user?.id,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Table $number created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshTables();
      }
    } catch (e) {
      if (mounted) {
        await ErrorDialogHelper.showError(
          context,
          title: 'Error Creating Table',
          message: 'Failed to create table: $e',
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

  /// Closes a table with confirmation and error handling.
  Future<void> _closeTable(restaurant_table.Table table) async {
    final confirmed = await ConfirmationDialogHelper.showCloseTableConfirmation(
      context,
      tableNumber: table.number.toString(),
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final tableService = Provider.of<TableService>(context, listen: false);
        
        // Clear any orders and reset table status
        await tableService.clearOrder(table.id);
        await tableService.updateTableStatus(table.id, restaurant_table.TableStatus.available);
        await tableService.releaseTable(table.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${table.displayName} has been closed'),
              backgroundColor: Colors.green,
            ),
          );
          _refreshTables();
        }
      } catch (e) {
        if (mounted) {
          await ErrorDialogHelper.showError(
            context,
            title: 'Error Closing Table',
            message: 'Failed to close table: $e',
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

  /// Transfer table to another table
  Future<void> _transferTable(restaurant_table.Table fromTable, restaurant_table.Table toTable) async {
    final confirmed = await ConfirmationDialogHelper.showConfirmation(
      context,
      title: 'Transfer Table',
      message: 'Transfer ${fromTable.displayName} to ${toTable.displayName}?',
      confirmText: 'Transfer',
      cancelText: 'Cancel',
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final tableService = Provider.of<TableService>(context, listen: false);
        final orderService = Provider.of<OrderService>(context, listen: false);
        
        // Get orders for the from table
        final orders = orderService.activeOrders.where((order) => order.tableId == fromTable.id).toList();
        
        // Update orders to new table
        for (final order in orders) {
          final updatedOrder = order.copyWith(tableId: toTable.id);
          await orderService.saveOrder(updatedOrder);
        }
        
        // Update table statuses
        await tableService.updateTableStatus(fromTable.id, restaurant_table.TableStatus.available);
        await tableService.updateTableStatus(toTable.id, restaurant_table.TableStatus.occupied);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${fromTable.displayName} transferred to ${toTable.displayName}'),
              backgroundColor: Colors.green,
            ),
          );
          _refreshTables();
        }
      } catch (e) {
        if (mounted) {
          await ErrorDialogHelper.showError(
            context,
            title: 'Error Transferring Table',
            message: 'Failed to transfer table: $e',
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

  /// Merge two tables
  Future<void> _mergeTables(restaurant_table.Table table1, restaurant_table.Table table2) async {
    final confirmed = await ConfirmationDialogHelper.showConfirmation(
      context,
      title: 'Merge Tables',
      message: 'Merge ${table1.displayName} and ${table2.displayName}?',
      confirmText: 'Merge',
      cancelText: 'Cancel',
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        final tableService = Provider.of<TableService>(context, listen: false);
        final orderService = Provider.of<OrderService>(context, listen: false);
        
        // Get orders for table2
        final orders2 = orderService.activeOrders.where((order) => order.tableId == table2.id).toList();
        
        // Merge orders to table1
        for (final order in orders2) {
          final updatedOrder = order.copyWith(tableId: table1.id);
          await orderService.saveOrder(updatedOrder);
        }
        
        // Update table statuses
        await tableService.updateTableStatus(table2.id, restaurant_table.TableStatus.available);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${table1.displayName} and ${table2.displayName} merged'),
              backgroundColor: Colors.green,
            ),
          );
          _refreshTables();
        }
      } catch (e) {
        if (mounted) {
          await ErrorDialogHelper.showError(
            context,
            title: 'Error Merging Tables',
            message: 'Failed to merge tables: $e',
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

  /// Quick status change
  Future<void> _quickStatusChange(restaurant_table.Table table, restaurant_table.TableStatus newStatus) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final tableService = Provider.of<TableService>(context, listen: false);
      await tableService.updateTableStatus(table.id, newStatus);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${table.displayName} status updated'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshTables();
      }
    } catch (e) {
      if (mounted) {
        await ErrorDialogHelper.showError(
          context,
          title: 'Error Updating Status',
          message: 'Failed to update table status: $e',
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

  /// Shows a dialog for creating a new table.
  void _showCreateTableDialog() {
    final TextEditingController numberController = TextEditingController();
    final TextEditingController capacityController = TextEditingController();
    capacityController.text = '4'; // Default capacity

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create a New Table'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NumericFormField(
              label: 'Table Number',
              hint: 'Enter table number',
              controller: numberController,
              autofocus: true,
              allowDecimal: false,
              allowNegative: false,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Table number is required';
                }
                final number = int.tryParse(value);
                if (number == null || number <= 0) {
                  return 'Please enter a valid positive number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            NumericFormField(
              label: 'Table Capacity',
              hint: 'Enter table capacity',
              controller: capacityController,
              allowDecimal: false,
              allowNegative: false,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Table capacity is required';
                }
                final capacity = int.tryParse(value);
                if (capacity == null || capacity <= 0) {
                  return 'Please enter a valid positive number';
                }
                return null;
              },
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
              final number = int.tryParse(numberController.text);
              final capacity = int.tryParse(capacityController.text);
              
              if (number != null && capacity != null) {
                Navigator.of(context).pop();
                await _createTable(number, capacity);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  /// Shows quick actions menu for a table
  void _showQuickActions(restaurant_table.Table table) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Quick Actions - ${table.displayName}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildQuickActionButton(
                  'Available',
                  Icons.check_circle,
                  Colors.green,
                  () => _quickStatusChange(table, restaurant_table.TableStatus.available),
                ),
                _buildQuickActionButton(
                  'Reserved',
                  Icons.schedule,
                  Colors.orange,
                  () => _quickStatusChange(table, restaurant_table.TableStatus.reserved),
                ),
                _buildQuickActionButton(
                  'Cleaning',
                  Icons.cleaning_services,
                  Colors.blue,
                  () => _quickStatusChange(table, restaurant_table.TableStatus.cleaning),
                ),
                if (table.status == restaurant_table.TableStatus.occupied)
                  _buildQuickActionButton(
                    'Transfer',
                    Icons.swap_horiz,
                    Colors.purple,
                    () => _showTransferDialog(table),
                  ),
                if (table.status == restaurant_table.TableStatus.occupied)
                  _buildQuickActionButton(
                    'Merge',
                    Icons.merge,
                    Colors.indigo,
                    () => _showMergeDialog(table),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        minimumSize: const Size(100, 40),
      ),
    );
  }

  void _showTransferDialog(restaurant_table.Table fromTable) {
    final availableTables = _availableTables.where((table) => table.id != fromTable.id).toList();
    
    if (availableTables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No available tables to transfer to'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Transfer ${fromTable.displayName}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableTables.length,
            itemBuilder: (context, index) {
              final table = availableTables[index];
              return ListTile(
                title: Text(table.displayName),
                subtitle: Text('Capacity: ${table.capacity}'),
                onTap: () {
                  Navigator.of(context).pop();
                  _transferTable(fromTable, table);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showMergeDialog(restaurant_table.Table table1) {
    final occupiedTables = _occupiedTables.where((table) => table.id != table1.id).toList();
    
    if (occupiedTables.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No other occupied tables to merge with'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Merge ${table1.displayName}'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: occupiedTables.length,
            itemBuilder: (context, index) {
              final table = occupiedTables[index];
              return ListTile(
                title: Text(table.displayName),
                subtitle: Text('Capacity: ${table.capacity}'),
                onTap: () {
                  Navigator.of(context).pop();
                  _mergeTables(table1, table);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tablesControls = Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search tables...',
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
                  const Icon(Icons.check_circle, size: 16),
                  const SizedBox(width: 4),
                  Text('Available (${_availableTables.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people, size: 16),
                  const SizedBox(width: 4),
                  Text('Occupied (${_occupiedTables.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.schedule, size: 16),
                  const SizedBox(width: 4),
                  Text('Reserved (${_reservedTables.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cleaning_services, size: 16),
                  const SizedBox(width: 4),
                  Text('Cleaning (${_cleaningTables.length})'),
                ],
              ),
            ),
          ],
        ),
      ],
    );

    final body = TabBarView(
      controller: _tabController,
      children: [
        _buildTableList(_availableTables, 'available'),
        _buildTableList(_occupiedTables, 'occupied'),
        _buildTableList(_reservedTables, 'reserved'),
        _buildTableList(_cleaningTables, 'cleaning'),
      ],
    );

    if (!widget.showAppBar) {
      // When used as a tab in AdminPanelScreen, just return the body content
      return LoadingOverlay(
        isLoading: _isLoading,
        child: Column(
          children: [
            tablesControls,
            Expanded(child: body),
          ],
        ),
      );
    }

    // When used as a standalone screen, show the full Scaffold with AppBar
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tables'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            IconButton(
              onPressed: _refreshTables,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh Tables',
            ),
            const CustomBackButton(),
            const SizedBox(width: 16),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(120),
            child: tablesControls,
          ),
        ),
        body: body,
        floatingActionButton: FloatingActionButton(
          onPressed: _showCreateTableDialog,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildTableList(List<restaurant_table.Table> tables, String status) {
    if (tables.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == 'available' ? Icons.check_circle :
              status == 'occupied' ? Icons.people :
              status == 'reserved' ? Icons.schedule :
              Icons.cleaning_services,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${status.toUpperCase()} Tables',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tables will appear here when they are ${status == 'available' ? 'free' : status == 'occupied' ? 'in use' : status == 'reserved' ? 'reserved' : 'being cleaned'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.2,
      ),
      itemCount: tables.length,
      itemBuilder: (context, index) {
        final table = tables[index];
        return GestureDetector(
          onTap: () => _showQuickActions(table),
          onLongPress: () => _showTableDetails(table),
          child: _buildEnhancedTableCard(table),
        );
      },
    );
  }

  Widget _buildEnhancedTableCard(restaurant_table.Table table) {
    final isOccupied = table.status == restaurant_table.TableStatus.occupied;
    
    Color cardColor;
    Color borderColor;
    IconData statusIcon;
    
    switch (table.status) {
      case restaurant_table.TableStatus.available:
        cardColor = Colors.green.shade50;
        borderColor = Colors.green.shade300;
        statusIcon = Icons.check_circle;
        break;
      case restaurant_table.TableStatus.occupied:
        cardColor = Colors.orange.shade50;
        borderColor = Colors.orange.shade300;
        statusIcon = Icons.people;
        break;
      case restaurant_table.TableStatus.reserved:
        cardColor = Colors.blue.shade50;
        borderColor = Colors.blue.shade300;
        statusIcon = Icons.schedule;
        break;
      case restaurant_table.TableStatus.cleaning:
        cardColor = Colors.purple.shade50;
        borderColor = Colors.purple.shade300;
        statusIcon = Icons.cleaning_services;
        break;
    }

    return Card(
      elevation: 3,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(statusIcon, color: borderColor, size: 24),
                if (isOccupied && table.occupiedAt != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatDuration(table.occupancyDuration),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              table.displayName,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: borderColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Capacity: ${table.capacity}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
            ),
            if (table.customerName != null && table.customerName!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Customer: ${table.customerName}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (isOccupied)
                  IconButton(
                    onPressed: () => _closeTable(table),
                    icon: const Icon(Icons.close, size: 18),
                    tooltip: 'Close Table',
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red.shade700,
                    ),
                  ),
                IconButton(
                  onPressed: () => _showQuickActions(table),
                  icon: const Icon(Icons.more_vert, size: 18),
                  tooltip: 'Quick Actions',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.shade50,
                    foregroundColor: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTableDetails(restaurant_table.Table table) {
    final isOccupied = table.status == restaurant_table.TableStatus.occupied;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${table.displayName} Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Number: ${table.number}'),
            Text('Capacity: ${table.capacity}'),
            Text('Status: ${table.status.toString().split('.').last.toUpperCase()}'),
            if (table.customerName != null) Text('Customer: ${table.customerName}'),
            if (table.occupiedAt != null) Text('Occupied: ${_formatDateTime(table.occupiedAt!)}'),
            if (table.reservedAt != null) Text('Reserved: ${_formatDateTime(table.reservedAt!)}'),
            if (isOccupied && table.occupiedAt != null) 
              Text('Duration: ${_formatDuration(table.occupancyDuration)}'),
          ],
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

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
} 