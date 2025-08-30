import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/user.dart';
import '../models/printer_type_mapping.dart';
import '../models/printer_configuration.dart';
import '../services/printer_type_management_service.dart';
import '../services/printing_service.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/confirmation_dialog.dart';

/// Unified printer management screen combining discovery, types, and assignments
class UnifiedPrinterManagementScreen extends StatefulWidget {
  final User user;

  const UnifiedPrinterManagementScreen({super.key, required this.user});

  @override
  State<UnifiedPrinterManagementScreen> createState() => _UnifiedPrinterManagementScreenState();
}

class _UnifiedPrinterManagementScreenState extends State<UnifiedPrinterManagementScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final PrinterTypeManagementService _printerTypeService = PrinterTypeManagementService.instance;
  late PrintingService _printingService;

  List<PrinterConfiguration> _discoveredPrinters = [];
  List<PrinterTypeConfiguration> _printerTypeConfigs = [];
  List<PrinterTypeAssignment> _printerTypeAssignments = [];
  List<ItemPrinterTypeMapping> _itemMappings = [];
  
  bool _isLoading = false;
  bool _isDiscovering = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeServices();
    _loadData();
  }
  
  Future<void> _initializeServices() async {
    final prefs = await SharedPreferences.getInstance();
    _printingService = PrintingService(prefs, NetworkInfo());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _printerTypeService.initialize();
      await _refreshData();
    } catch (e) {
      setState(() => _statusMessage = 'Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshData() async {
    final configs = _printerTypeService.printerTypeConfigs;
    final assignments = _printerTypeService.printerTypeAssignments;
    final mappings = _printerTypeService.itemPrinterTypeMappings;
    
    setState(() {
      _printerTypeConfigs = configs;
      _printerTypeAssignments = assignments;
      _itemMappings = mappings;
    });
  }

  Future<void> _discoverPrinters() async {
    setState(() {
      _isDiscovering = true;
      _statusMessage = 'Discovering printers...';
    });

    try {
      // URGENT: Use direct Epson printer addition first
      setState(() => _statusMessage = 'Adding known Epson TM-M30II printers...');
      await _printingService.addKnownEpsonPrinters();
      
      // Then try regular discovery as backup
      setState(() => _statusMessage = 'Scanning network for additional printers...');
      await _printingService.discoverGenericESCPOSPrinters();
      
      final printers = _printingService.discoveredPrinters;
      
      setState(() {
        // Convert PrinterDevice to PrinterConfiguration for display
        _discoveredPrinters = printers.map((device) => PrinterConfiguration(
          id: device.id,
          name: device.name,
          type: device.type,
          model: device.model == 'TM-M30II' ? PrinterModel.epsonTMm30 : PrinterModel.epsonTMGeneric,
          ipAddress: device.address,
          description: device.model == 'TM-M30II' ? 'Epson TM-M30II Thermal Printer' : 'Discovered printer',
        )).toList();
        _statusMessage = printers.isNotEmpty 
          ? 'Found ${printers.length} printers (${printers.where((p) => p.model == 'TM-M30II').length} Epson TM-M30II)'
          : 'No printers found. Check network connection and printer power.';
      });
    } catch (e) {
      setState(() => _statusMessage = 'Error discovering printers: $e');
    } finally {
      setState(() => _isDiscovering = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      message: 'Loading printer management...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('🖨️ Unified Printer Management'),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: Column(
          children: [
            // Status Bar
            if (_statusMessage.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                color: Colors.blue.shade50,
                child: Text(
                  _statusMessage,
                  style: TextStyle(color: Colors.blue.shade700),
                  textAlign: TextAlign.center,
                ),
              ),
            
            // Tab Bar
            Container(
              color: Colors.green.shade50,
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.green.shade700,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: Colors.green.shade700,
                tabs: const [
                  Tab(icon: Icon(Icons.search), text: 'Discover'),
                  Tab(icon: Icon(Icons.category), text: 'Types'),
                  Tab(icon: Icon(Icons.link), text: 'Assignments'),
                  Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
                ],
              ),
            ),
            
            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDiscoveryTab(),
                  _buildTypesTab(),
                  _buildAssignmentsTab(),
                  _buildOverviewTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoveryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
                      Row(
            children: [
              Expanded(
                child: Text(
                  'Printer Discovery',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
              // URGENT: Direct Epson button
              ElevatedButton.icon(
                onPressed: _isDiscovering ? null : () async {
                  setState(() {
                    _isDiscovering = true;
                    _statusMessage = 'Adding Epson TM-M30II printers...';
                  });
                  try {
                    await _printingService.addKnownEpsonPrinters();
                    final printers = _printingService.discoveredPrinters;
                    setState(() {
                      _discoveredPrinters = printers.map((device) => PrinterConfiguration(
                        id: device.id,
                        name: device.name,
                        type: device.type,
                                                 model: PrinterModel.epsonTMm30,
                        ipAddress: device.address,
                        description: 'Epson TM-M30II Thermal Printer',
                      )).toList();
                      _statusMessage = 'Added ${printers.length} Epson TM-M30II printers';
                    });
                  } catch (e) {
                    setState(() => _statusMessage = 'Error adding Epson printers: $e');
                  } finally {
                    setState(() => _isDiscovering = false);
                  }
                },
                icon: const Icon(Icons.print, color: Colors.white),
                label: const Text('Add Epson TM-M30II'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isDiscovering ? null : _discoverPrinters,
                icon: _isDiscovering
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
                label: Text(_isDiscovering ? 'Discovering...' : 'Discover All'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Discovered Printers
          if (_discoveredPrinters.isNotEmpty) ...[
            Text(
              'Discovered Printers (${_discoveredPrinters.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._discoveredPrinters.map((printer) => _buildPrinterCard(printer)),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.print_disabled,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No printers discovered yet',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Click "Discover Printers" to scan for available printers',
                      style: TextStyle(color: Colors.grey.shade500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Text(
                  'Printer Types',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _createDefaultTypes,
                icon: const Icon(Icons.add),
                label: const Text('Create Default Types'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Printer Type Cards
          if (_printerTypeConfigs.isNotEmpty) ...[
            ..._printerTypeConfigs.map((config) => _buildPrinterTypeCard(config)),
          ] else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      Icons.category_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No printer types configured',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create default printer types to get started',
                      style: TextStyle(color: Colors.grey.shade500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAssignmentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Printer Assignments',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 16),
          
          // Assignment Summary
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Assignment Summary',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildAssignmentSummary(),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Quick Assignment Tools
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Assignment Tools',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showPrinterAssignmentDialog,
                          icon: const Icon(Icons.link),
                          label: const Text('Assign Printer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showCategoryAssignmentDialog,
                          icon: const Icon(Icons.category),
                          label: const Text('Assign Category'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade600,
                            foregroundColor: Colors.white,
                          ),
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

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'System Overview',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 16),
          
          // Statistics Cards
          Row(
            children: [
              Expanded(child: _buildStatCard('Total Printers', '${_discoveredPrinters.length}', Icons.print, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Printer Types', '${_printerTypeConfigs.length}', Icons.category, Colors.green)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard('Assignments', '${_printerTypeAssignments.length}', Icons.link, Colors.orange)),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Configuration Status
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Configuration Status',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildConfigurationStatus(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrinterCard(PrinterConfiguration printer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: Icon(Icons.print, color: Colors.blue.shade700),
        ),
        title: Text(printer.name ?? 'Unknown Printer'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${printer.type?.name ?? 'Unknown'}'),
            Text('Connection: ${printer.connectionType?.name ?? 'Unknown'}'),
            if (printer.ipAddress != null) Text('IP: ${printer.ipAddress}'),
            if (printer.port != null) Text('Port: ${printer.port}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handlePrinterAction(value, printer),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'assign',
              child: Text('Assign to Type'),
            ),
            const PopupMenuItem(
              value: 'test',
              child: Text('Test Connection'),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: Text('Remove'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrinterTypeCard(PrinterTypeConfiguration config) {
    final assignments = _printerTypeAssignments
        .where((a) => a.printerTypeConfigId == config.id)
        .toList();
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getPrinterTypeIcon(config.type),
                  color: _getPrinterTypeColor(config.type),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    config.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: config.isActive,
                  onChanged: (value) => _togglePrinterType(config, value),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              config.description,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            
            // Assignment Summary
            Row(
              children: [
                _buildAssignmentChip('Printers', '${assignments.length}'),
                const SizedBox(width: 8),
                _buildAssignmentChip('Categories', '${config.assignedCategoryIds.length}'),
                const SizedBox(width: 8),
                _buildAssignmentChip('Items', '${config.assignedItemIds.length}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentSummary() {
    final summary = <String, int>{};
    for (final assignment in _printerTypeAssignments) {
      final typeName = assignment.printerType.name;
      summary[typeName] = (summary[typeName] ?? 0) + 1;
    }
    
    return Column(
      children: summary.entries.map((entry) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(_getPrinterTypeIcon(PrinterTypeCategory.values.firstWhere((e) => e.name == entry.key)), 
                 color: _getPrinterTypeColor(PrinterTypeCategory.values.firstWhere((e) => e.name == entry.key))),
            const SizedBox(width: 8),
            Text('${entry.key}: ${entry.value} printers'),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildConfigurationStatus() {
    final hasTypes = _printerTypeConfigs.isNotEmpty;
    final hasAssignments = _printerTypeAssignments.isNotEmpty;
    final hasMappings = _itemMappings.isNotEmpty;
    
    return Column(
      children: [
        _buildStatusItem('Printer Types', hasTypes, Icons.category),
        _buildStatusItem('Printer Assignments', hasAssignments, Icons.link),
        _buildStatusItem('Item Mappings', hasMappings, Icons.restaurant_menu),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
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
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, bool isComplete, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            isComplete ? Icons.check_circle : Icons.error,
            color: isComplete ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(label),
          const Spacer(),
          Text(
            isComplete ? 'Complete' : 'Incomplete',
            style: TextStyle(
              color: isComplete ? Colors.green : Colors.orange,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPrinterTypeIcon(PrinterTypeCategory type) {
    switch (type) {
      case PrinterTypeCategory.receipt:
        return Icons.receipt;
      case PrinterTypeCategory.tandoor:
        return Icons.local_fire_department;
      case PrinterTypeCategory.curry:
        return Icons.restaurant;
      case PrinterTypeCategory.expo:
        return Icons.kitchen;
    }
  }

  Color _getPrinterTypeColor(PrinterTypeCategory type) {
    switch (type) {
      case PrinterTypeCategory.receipt:
        return Colors.blue;
      case PrinterTypeCategory.tandoor:
        return Colors.orange;
      case PrinterTypeCategory.curry:
        return Colors.green;
      case PrinterTypeCategory.expo:
        return Colors.purple;
    }
  }

  Future<void> _createDefaultTypes() async {
    try {
      await _printerTypeService.createDefaultConfigurations(
        widget.user.restaurantId ?? 'default',
        widget.user.id,
      );
      await _refreshData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Default printer types created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error creating printer types: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _togglePrinterType(PrinterTypeConfiguration config, bool value) async {
    try {
      final updatedConfig = config.copyWith(isActive: value);
      // TODO: Update in service
      await _refreshData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error updating printer type: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handlePrinterAction(String action, PrinterConfiguration printer) {
    switch (action) {
      case 'assign':
        _showPrinterAssignmentDialog(printer: printer);
        break;
      case 'test':
        _testPrinterConnection(printer);
        break;
      case 'remove':
        _removePrinter(printer);
        break;
    }
  }

  void _showPrinterAssignmentDialog({PrinterConfiguration? printer}) {
    // TODO: Implement printer assignment dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Printer assignment dialog coming soon!')),
    );
  }

  void _showCategoryAssignmentDialog() {
    // TODO: Implement category assignment dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Category assignment dialog coming soon!')),
    );
  }

  Future<void> _testPrinterConnection(PrinterConfiguration printer) async {
    // TODO: Implement printer connection test
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Printer connection test coming soon!')),
    );
  }

  Future<void> _removePrinter(PrinterConfiguration printer) async {
    final confirmed = await ConfirmationDialogHelper.showConfirmation(
      context,
      title: 'Remove Printer',
      message: 'Are you sure you want to remove ${printer.name}?',
      confirmText: 'Remove',
      cancelText: 'Cancel',
    );
    
    if (confirmed == true) {
      // TODO: Implement printer removal
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printer removal coming soon!')),
      );
    }
  }
} 