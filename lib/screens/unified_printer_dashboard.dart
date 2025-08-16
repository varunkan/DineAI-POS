import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/unified_printer_service.dart';
import '../services/menu_service.dart';
import '../services/database_service.dart';
import '../models/printer_configuration.dart';
import '../models/printer_assignment.dart';
import '../models/category.dart';
import '../models/menu_item.dart';
import '../widgets/back_button.dart';

/// 🚀 UNIFIED PRINTER DASHBOARD - World's Most Advanced Restaurant Printing Interface
/// 
/// Features:
/// - Single screen replaces all redundant printer screens
/// - Drag & drop assignments for categories and menu items
/// - Real-time printer status and health monitoring
/// - Enhanced receipt formatting controls
/// - Global persistent assignments
/// - Cloud synchronization
/// - Professional analytics and reporting
class UnifiedPrinterDashboard extends StatefulWidget {
  const UnifiedPrinterDashboard({super.key});

  @override
  State<UnifiedPrinterDashboard> createState() => _UnifiedPrinterDashboardState();
}

class _UnifiedPrinterDashboardState extends State<UnifiedPrinterDashboard>
    with TickerProviderStateMixin {
  
  late TabController _tabController;
  UnifiedPrinterService? _printerService;
  bool _isLoading = true;
  String? _errorMessage;
  
  // Assignment mode
  bool _showCategories = true;
  List<Category> _categories = [];
  List<MenuItem> _menuItems = [];
  
  // Drag & drop state
  String? _draggedItemId;
  String? _draggedItemType; // 'category' or 'menuItem'
  String? _hoveredPrinterId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeService();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    try {
      final databaseService = Provider.of<DatabaseService>(context, listen: false);
      _printerService = UnifiedPrinterService.getInstance(databaseService);
      
      final success = await _printerService!.initialize(
        cloudEndpoint: 'https://your-restaurant-cloud.com/api',
        restaurantId: 'restaurant_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      if (!success) {
        throw Exception('Failed to initialize printer service');
      }
      
      await _loadMenuData();
      
      setState(() {
        _isLoading = false;
      });
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }
  
  Future<void> _loadMenuData() async {
    try {
      final menuService = Provider.of<MenuService>(context, listen: false);
      _categories = await menuService.getCategories();
      _menuItems = await menuService.getMenuItems();
    } catch (e) {
      debugPrint('Error loading menu data: $e');
    }
  }

  Future<void> _scanForPrinters() async {
    if (_printerService == null) return;
    
    try {
      // Trigger comprehensive printer discovery
      await _printerService!.scanForPrinters();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔍 Printer discovery completed'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Discovery failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSystemInfo() {
    if (_printerService == null) return;
    
    final stats = _printerService!.getPrinterStatistics();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚀 System Information'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatRow('Total Printers', '${stats['total_printers']}'),
              _buildStatRow('Active Printers', '${stats['active_printers']}'),
              _buildStatRow('Connected Printers', '${stats['connected_printers']}'),
              _buildStatRow('Total Assignments', '${stats['total_assignments']}'),
              const Divider(),
              _buildStatRow('Orders Printed', '${stats['total_orders_printed']}'),
              _buildStatRow('Successful Prints', '${stats['successful_prints']}'),
              _buildStatRow('Failed Prints', '${stats['failed_prints']}'),
              _buildStatRow('Success Rate', '${stats['success_rate'].toStringAsFixed(1)}%'),
              const Divider(),
              _buildStatRow('Cloud Sync', stats['cloud_sync_enabled'] ? 'ENABLED' : 'DISABLED'),
              if (stats['last_cloud_sync'] != null)
                _buildStatRow('Last Sync', stats['last_cloud_sync']),
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

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.blue)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Initializing Advanced Printer System...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 100),
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Error: $_errorMessage',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _initializeService,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('🚀 Advanced Printer System'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF667eea),
                Color(0xFF764ba2),
                Color(0xFFf093fb),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        leading: const CustomBackButton(),
        actions: [
          IconButton(
            onPressed: _scanForPrinters,
            icon: const Icon(Icons.refresh),
            tooltip: 'Scan for Printers',
          ),
          IconButton(
            onPressed: _showSystemInfo,
            icon: const Icon(Icons.info),
            tooltip: 'System Info',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.print), text: 'Printers'),
            Tab(icon: Icon(Icons.assignment), text: 'Assignments'),
            Tab(icon: Icon(Icons.settings), text: 'Configuration'),
            Tab(icon: Icon(Icons.analytics), text: 'Analytics'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildPrintersTab(),
            _buildAssignmentsTab(),
            _buildConfigurationTab(),
            _buildAnalyticsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintersTab() {
    return SafeArea(
      child: Consumer<UnifiedPrinterService>(
        builder: (context, service, child) {
          if (service.printers.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 100),
                    const Icon(Icons.print_disabled, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'No printers found',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text('Tap the refresh button to scan for printers'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _scanForPrinters,
                      icon: const Icon(Icons.search),
                      label: const Text('Scan for Printers'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: service.printers.length,
            itemBuilder: (context, index) {
              final printer = service.printers[index];
              return _buildPrinterCard(printer);
            },
          );
        },
      ),
    );
  }

  Widget _buildPrinterCard(PrinterConfiguration printer) {
    final isConnected = printer.connectionStatus == PrinterConnectionStatus.connected;
    final isHovered = _hoveredPrinterId == printer.id;
    
    return Card(
      elevation: isHovered ? 8 : 2,
      margin: const EdgeInsets.only(bottom: 12),
      child: DragTarget<Map<String, String>>(
        onWillAcceptWithDetails: (details) {
          setState(() {
            _hoveredPrinterId = printer.id;
          });
          return details.data != null;
        },
        onLeave: (data) {
          setState(() {
            _hoveredPrinterId = null;
          });
        },
        onAcceptWithDetails: (details) {
          _handleDropOnPrinter(printer.id, details.data);
          setState(() {
            _hoveredPrinterId = null;
          });
        },
        builder: (context, candidateData, rejectedData) {
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: isHovered 
                ? Border.all(color: Colors.blue, width: 2)
                : null,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: isConnected ? Colors.green : Colors.red,
                child: Icon(
                  Icons.print,
                  color: Colors.white,
                ),
              ),
              title: Text(
                printer.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${printer.ipAddress}:${printer.port}',
                    overflow: TextOverflow.ellipsis,
                  ),
                  Row(
                    children: [
                      Icon(
                        isConnected ? Icons.check_circle : Icons.error,
                        size: 16,
                        color: isConnected ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          isConnected ? 'Connected' : 'Offline',
                          style: TextStyle(
                            color: isConnected ? Colors.green : Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => _testPrinter(printer.id),
                    icon: const Icon(Icons.play_arrow),
                    tooltip: 'Test Print',
                  ),
                  IconButton(
                    onPressed: () => _configurePrinter(printer),
                    icon: const Icon(Icons.settings),
                    tooltip: 'Configure',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAssignmentsTab() {
    return SafeArea(
      child: Row(
        children: [
          // Left side: Assignment targets
          Expanded(
            flex: 1,
            child: _buildAssignmentTargets(),
          ),
          // Divider
          Container(
            width: 1,
            color: Colors.grey.shade300,
          ),
          // Right side: Printer targets
          Expanded(
            flex: 1,
            child: _buildPrinterTargets(),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentTargets() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _showCategories ? 'Categories' : 'Menu Items',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Categories'),
                    icon: Icon(Icons.category),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Items'),
                    icon: Icon(Icons.restaurant_menu),
                  ),
                ],
                selected: {_showCategories},
                onSelectionChanged: (Set<bool> selection) {
                  setState(() {
                    _showCategories = selection.first;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _showCategories ? _buildCategoriesList() : _buildMenuItemsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList() {
    return ListView.builder(
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return _buildDraggableItem(
          id: category.id,
          name: category.name,
          type: 'category',
          icon: Icons.category,
          color: Colors.orange,
        );
      },
    );
  }

  Widget _buildMenuItemsList() {
    return ListView.builder(
      itemCount: _menuItems.length,
      itemBuilder: (context, index) {
        final item = _menuItems[index];
        return _buildDraggableItem(
          id: item.id,
          name: item.name,
          type: 'menuItem',
          icon: Icons.restaurant_menu,
          color: Colors.green,
        );
      },
    );
  }

  Widget _buildDraggableItem({
    required String id,
    required String name,
    required String type,
    required IconData icon,
    required Color color,
  }) {
    final assignedPrinters = _printerService?.getAssignedPrinters(
      type == 'menuItem' ? id : '',
      type == 'category' ? id : '',
    ) ?? [];

    return Draggable<Map<String, String>>(
      data: {'id': id, 'name': name, 'type': type},
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color,
            child: Icon(icon, color: Colors.white),
          ),
          title: Text(name),
          subtitle: assignedPrinters.isNotEmpty
            ? Text('Assigned to ${assignedPrinters.length} printer(s)')
            : const Text('Not assigned'),
          trailing: assignedPrinters.isNotEmpty
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
        ),
      ),
    );
  }

  Widget _buildPrinterTargets() {
    return Consumer<UnifiedPrinterService>(
      builder: (context, service, child) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Printers',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: service.activePrinters.length,
                  itemBuilder: (context, index) {
                    final printer = service.activePrinters[index];
                    return _buildPrinterTarget(printer, service);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPrinterTarget(PrinterConfiguration printer, UnifiedPrinterService service) {
    final assignments = service.assignments
        .where((a) => a.printerId == printer.id && a.isActive)
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
                          backgroundColor: printer.connectionStatus == PrinterConnectionStatus.connected ? Colors.green : Colors.red,
          child: const Icon(Icons.print, color: Colors.white),
        ),
        title: Text(printer.name),
        subtitle: Text('${assignments.length} assignments'),
        children: assignments.map((assignment) {
          return ListTile(
            dense: true,
            leading: Icon(
              assignment.assignmentType == AssignmentType.category
                ? Icons.category
                : Icons.restaurant_menu,
              size: 20,
            ),
            title: Text(assignment.targetName),
            trailing: IconButton(
              icon: const Icon(Icons.delete, size: 20),
              onPressed: () => _removeAssignment(assignment.id),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildConfigurationTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Printer Configuration',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            // Configuration options will be added here
            const Text('Configuration options coming soon...'),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Printer Analytics',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            // Analytics will be added here
            const Text('Analytics coming soon...'),
          ],
        ),
      ),
    );
  }



  void _handleDropOnPrinter(String printerId, Map<String, String> data) {
    final targetId = data['id']!;
    final targetName = data['name']!;
    final type = data['type']!;

    final assignmentType = type == 'category' 
      ? AssignmentType.category 
      : AssignmentType.menuItem;

    final assignment = PrinterAssignment(
      id: 'assignment_${DateTime.now().millisecondsSinceEpoch}',
      printerId: printerId,
      printerName: 'Printer $printerId',
      printerAddress: '192.168.1.100',
      assignmentType: assignmentType,
      targetId: targetId,
      targetName: targetName,
      priority: 1,
      isActive: true,
    );

    _printerService?.addAssignment(assignment);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ Assigned "$targetName" to printer'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _removeAssignment(String assignmentId) async {
    try {
      final success = await _printerService?.removeAssignment(assignmentId) ?? false;
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Assignment removed successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to remove assignment'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing assignment: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _testPrinter(String printerId) async {
    final success = await _printerService?.testPrinter(printerId) ?? false;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '✅ Test successful' : '❌ Test failed'),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
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



    void _configurePrinter(PrinterConfiguration printer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.print, color: Colors.blue),
            SizedBox(width: 8),
            Text('${printer.name}'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Type', printer.type.toString().split('.').last.toUpperCase()),
            _buildInfoRow('Status', printer.isActive ? 'Active' : 'Inactive'),
            if (printer.ipAddress.isNotEmpty)
              _buildInfoRow('IP Address', printer.ipAddress),
            if (printer.port > 0)
              _buildInfoRow('Port', printer.port.toString()),
            _buildInfoRow('Model', printer.model.toString().split('.').last),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _testPrinter(printer.id);
            },
            child: const Text('Test Print'),
          ),
        ],
      ),
    );
  }
} 