import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/enhanced_printer_assignment_service.dart';
import '../services/printer_configuration_service.dart';
import '../services/menu_service.dart';
import '../models/printer_configuration.dart';
import '../models/printer_assignment.dart';
import '../models/category.dart';
import '../models/menu_item.dart';
import '../widgets/back_button.dart';

/// Comprehensive Printer Assignment Management Screen
/// Provides cross-platform persistent printer assignments for categories and menu items
class ComprehensivePrinterAssignmentScreen extends StatefulWidget {
  const ComprehensivePrinterAssignmentScreen({super.key});

  @override
  State<ComprehensivePrinterAssignmentScreen> createState() => _ComprehensivePrinterAssignmentScreenState();
}

class _ComprehensivePrinterAssignmentScreenState extends State<ComprehensivePrinterAssignmentScreen>
    with TickerProviderStateMixin {
  
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;
  
  // Data
  List<PrinterConfiguration> _printers = [];
  List<Category> _categories = [];
  List<MenuItem> _menuItems = [];
  List<PrinterAssignment> _assignments = [];
  
  // UI State
  String _searchQuery = '';
  bool _showOnlyAssigned = false;
  String? _selectedPrinterId;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // Load all data in parallel
      final futures = await Future.wait([
        _loadPrinters(),
        _loadCategories(),
        _loadMenuItems(),
        _loadAssignments(),
      ]);

      setState(() {
        _isLoading = false;
      });

      debugPrint('🖨️ Comprehensive Printer Assignment: Data loaded successfully');
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load data: $e';
      });
      debugPrint('❌ Error loading printer assignment data: $e');
    }
  }

  Future<void> _loadPrinters() async {
    final printerService = Provider.of<PrinterConfigurationService>(context, listen: false);
    _printers = printerService.configurations;
  }

  Future<void> _loadCategories() async {
    final menuService = Provider.of<MenuService>(context, listen: false);
    _categories = menuService.categories;
  }

  Future<void> _loadMenuItems() async {
    final menuService = Provider.of<MenuService>(context, listen: false);
    _menuItems = menuService.menuItems;
  }

  Future<void> _loadAssignments() async {
    final assignmentService = Provider.of<EnhancedPrinterAssignmentService>(context, listen: false);
    _assignments = assignmentService.assignments;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: const CustomBackButton(),
        title: const Text(
          'Printer Assignment Management',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(
              icon: Icon(Icons.category),
              text: 'Categories',
            ),
            Tab(
              icon: Icon(Icons.restaurant_menu),
              text: 'Menu Items',
            ),
            Tab(
              icon: Icon(Icons.analytics),
              text: 'Overview',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildCategoryAssignmentTab(),
                          _buildMenuItemAssignmentTab(),
                          _buildOverviewTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildErrorWidget() {
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
            'Error Loading Data',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? 'Unknown error occurred',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
            ),
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

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search categories or menu items...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              FilterChip(
                label: const Text('Only Assigned'),
                selected: _showOnlyAssigned,
                onSelected: (selected) {
                  setState(() {
                    _showOnlyAssigned = selected;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildPrinterStatusRow(),
        ],
      ),
    );
  }

  Widget _buildPrinterStatusRow() {
    return Container(
      padding: const EdgeInsets.all(12),
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
              Icon(
                Icons.print,
                color: Colors.blue.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Available Printers (${_printers.length})',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
              const Spacer(),
              Text(
                'Assignments: ${_assignments.length}',
                style: TextStyle(
                  color: Colors.blue.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _printers.map((printer) => _buildPrinterChip(printer)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPrinterChip(PrinterConfiguration printer) {
    final isSelected = _selectedPrinterId == printer.id;
    final assignmentCount = _assignments.where((a) => a.printerId == printer.id).length;
    
    return FilterChip(
      label: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            printer.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (assignmentCount > 0)
            Text(
              '$assignmentCount items',
              style: TextStyle(
                fontSize: 10,
                color: Colors.green.shade600,
              ),
            ),
        ],
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedPrinterId = selected ? printer.id : null;
        });
      },
      avatar: CircleAvatar(
        radius: 8,
        backgroundColor: printer.isActive ? Colors.green : Colors.red,
      ),
    );
  }

  Widget _buildCategoryAssignmentTab() {
    final filteredCategories = _categories.where((category) {
      if (_searchQuery.isNotEmpty && !category.name.toLowerCase().contains(_searchQuery)) {
        return false;
      }
      if (_showOnlyAssigned) {
        return _assignments.any((a) => a.assignmentType == AssignmentType.category && a.targetId == category.id);
      }
      return true;
    }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.category,
                color: Colors.orange.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                'Category Assignments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
              const Spacer(),
              Text(
                '${filteredCategories.length} categories',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filteredCategories.length,
            itemBuilder: (context, index) {
              final category = filteredCategories[index];
              return _buildCategoryCard(category);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard(Category category) {
    final assignments = _assignments.where(
      (a) => a.assignmentType == AssignmentType.category && a.targetId == category.id
    ).toList();
    
    final isHighlighted = _selectedPrinterId != null && 
        assignments.any((a) => a.printerId == _selectedPrinterId);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isHighlighted ? 4 : 1,
      color: isHighlighted ? Colors.blue.shade50 : null,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: assignments.isNotEmpty ? Colors.green.shade100 : Colors.grey.shade100,
          child: Icon(
            Icons.category,
            color: assignments.isNotEmpty ? Colors.green.shade700 : Colors.grey.shade600,
            size: 20,
          ),
        ),
        title: Text(
          category.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: assignments.isNotEmpty
            ? Text('Assigned to ${assignments.length} printer${assignments.length == 1 ? '' : 's'}')
            : const Text('Not assigned to any printer'),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (assignments.isNotEmpty) ...[
                  Text(
                    'Current Assignments:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...assignments.map((assignment) => _buildAssignmentChip(assignment)),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Assign to Printer:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _printers.map((printer) => 
                    _buildAssignmentActionChip(category.id, category.name, AssignmentType.category, printer)
                  ).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItemAssignmentTab() {
    final filteredMenuItems = _menuItems.where((item) {
      if (_searchQuery.isNotEmpty && !item.name.toLowerCase().contains(_searchQuery)) {
        return false;
      }
      if (_showOnlyAssigned) {
        return _assignments.any((a) => a.assignmentType == AssignmentType.menuItem && a.targetId == item.id);
      }
      return true;
    }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.restaurant_menu,
                color: Colors.green.shade600,
              ),
              const SizedBox(width: 8),
              Text(
                'Menu Item Assignments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
              const Spacer(),
              Text(
                '${filteredMenuItems.length} items',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: filteredMenuItems.length,
            itemBuilder: (context, index) {
              final menuItem = filteredMenuItems[index];
              return _buildMenuItemCard(menuItem);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItemCard(MenuItem menuItem) {
    final assignments = _assignments.where(
      (a) => a.assignmentType == AssignmentType.menuItem && a.targetId == menuItem.id
    ).toList();
    
    final isHighlighted = _selectedPrinterId != null && 
        assignments.any((a) => a.printerId == _selectedPrinterId);

    // Get category for this menu item
    final category = _categories.firstWhere(
      (c) => c.id == menuItem.categoryId,
      orElse: () => Category(id: '', name: 'Unknown', description: ''),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isHighlighted ? 4 : 1,
      color: isHighlighted ? Colors.blue.shade50 : null,
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: assignments.isNotEmpty ? Colors.green.shade100 : Colors.grey.shade100,
          child: Icon(
            Icons.restaurant_menu,
            color: assignments.isNotEmpty ? Colors.green.shade700 : Colors.grey.shade600,
            size: 20,
          ),
        ),
        title: Text(
          menuItem.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Category: ${category.name}'),
            assignments.isNotEmpty
                ? Text('Assigned to ${assignments.length} printer${assignments.length == 1 ? '' : 's'}')
                : const Text('Not assigned to any printer'),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (assignments.isNotEmpty) ...[
                  Text(
                    'Current Assignments:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...assignments.map((assignment) => _buildAssignmentChip(assignment)),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Assign to Printer:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _printers.map((printer) => 
                    _buildAssignmentActionChip(menuItem.id, menuItem.name, AssignmentType.menuItem, printer)
                  ).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentChip(PrinterAssignment assignment) {
    return Chip(
      label: Text(
        assignment.printerName,
        style: const TextStyle(fontSize: 12),
      ),
      avatar: const Icon(Icons.print, size: 16),
      backgroundColor: Colors.green.shade100,
      deleteIcon: const Icon(Icons.close, size: 16),
      onDeleted: () => _removeAssignment(assignment),
    );
  }

  Widget _buildAssignmentActionChip(String targetId, String targetName, AssignmentType assignmentType, PrinterConfiguration printer) {
    final isAssigned = _assignments.any(
      (a) => a.assignmentType == assignmentType && a.targetId == targetId && a.printerId == printer.id
    );

    return ActionChip(
      label: Text(
        printer.name,
        style: TextStyle(
          fontSize: 12,
          color: isAssigned ? Colors.green.shade700 : Colors.blue.shade700,
        ),
      ),
      avatar: Icon(
        isAssigned ? Icons.check : Icons.add,
        size: 16,
        color: isAssigned ? Colors.green.shade700 : Colors.blue.shade700,
      ),
      backgroundColor: isAssigned ? Colors.green.shade100 : Colors.blue.shade50,
      onPressed: isAssigned 
          ? null 
          : () => _assignToPrinter(targetId, targetName, assignmentType, printer),
    );
  }

  Widget _buildOverviewTab() {
    final categoryAssignments = _assignments.where((a) => a.assignmentType == AssignmentType.category).length;
    final menuItemAssignments = _assignments.where((a) => a.assignmentType == AssignmentType.menuItem).length;
    final unassignedCategories = _categories.where(
      (c) => !_assignments.any((a) => a.assignmentType == AssignmentType.category && a.targetId == c.id)
    ).length;
    final unassignedMenuItems = _menuItems.where(
      (m) => !_assignments.any((a) => a.assignmentType == AssignmentType.menuItem && a.targetId == m.id)
    ).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assignment Overview',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 24),
          
          // Statistics Cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            children: [
              _buildStatCard(
                'Total Assignments',
                '${_assignments.length}',
                Icons.assignment,
                Colors.blue,
              ),
              _buildStatCard(
                'Active Printers',
                '${_printers.where((p) => p.isActive).length}',
                Icons.print,
                Colors.green,
              ),
              _buildStatCard(
                'Category Assignments',
                '$categoryAssignments',
                Icons.category,
                Colors.orange,
              ),
              _buildStatCard(
                'Menu Item Assignments',
                '$menuItemAssignments',
                Icons.restaurant_menu,
                Colors.purple,
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Unassigned Items Warning
          if (unassignedCategories > 0 || unassignedMenuItems > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange.shade600),
                      const SizedBox(width: 8),
                      Text(
                        'Unassigned Items',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (unassignedCategories > 0)
                    Text('• $unassignedCategories categories without printer assignments'),
                  if (unassignedMenuItems > 0)
                    Text('• $unassignedMenuItems menu items without printer assignments'),
                  const SizedBox(height: 12),
                  const Text(
                    'Unassigned items will be sent to the default printer when ordered.',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          
          // Printer Assignment Summary
          Text(
            'Printer Assignment Summary',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          
          ..._printers.map((printer) => _buildPrinterSummaryCard(printer)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrinterSummaryCard(PrinterConfiguration printer) {
    final printerAssignments = _assignments.where((a) => a.printerId == printer.id).toList();
    final categoryCount = printerAssignments.where((a) => a.assignmentType == AssignmentType.category).length;
    final menuItemCount = printerAssignments.where((a) => a.assignmentType == AssignmentType.menuItem).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: printer.isActive ? Colors.green.shade100 : Colors.red.shade100,
          child: Icon(
            Icons.print,
            color: printer.isActive ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
        title: Text(
          printer.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${printer.ipAddress}:${printer.port} • '
          '${printerAssignments.length} assignments '
          '($categoryCount categories, $menuItemCount items)',
        ),
        trailing: printer.isActive
            ? Icon(Icons.check_circle, color: Colors.green.shade600)
            : Icon(Icons.error, color: Colors.red.shade600),
      ),
    );
  }

  Future<void> _assignToPrinter(String targetId, String targetName, AssignmentType assignmentType, PrinterConfiguration printer) async {
    try {
      final assignmentService = Provider.of<EnhancedPrinterAssignmentService>(context, listen: false);
      
      final success = await assignmentService.addAssignment(
        printerId: printer.id,
        assignmentType: assignmentType,
        targetId: targetId,
        targetName: targetName,
      );

      if (success) {
        // Reload assignments
        await _loadAssignments();
        setState(() {});
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Assigned "$targetName" to "${printer.name}"'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Failed to create assignment');
      }
    } catch (e) {
      debugPrint('❌ Error creating assignment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to assign to printer: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _removeAssignment(PrinterAssignment assignment) async {
    try {
      final assignmentService = Provider.of<EnhancedPrinterAssignmentService>(context, listen: false);
      
      final success = await assignmentService.removeAssignment(assignment.id);

      if (success) {
        // Reload assignments
        await _loadAssignments();
        setState(() {});
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Removed assignment: "${assignment.targetName}" from "${assignment.printerName}"'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        throw Exception('Failed to remove assignment');
      }
    } catch (e) {
      debugPrint('❌ Error removing assignment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to remove assignment: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }
} 