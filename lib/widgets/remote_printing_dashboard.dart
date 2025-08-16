import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/remote_printer_service.dart';
import '../services/printing_service.dart';
import '../models/order.dart';

/// Remote Printing Dashboard Widget
/// Shows remote printing service status and configuration options
class RemotePrintingDashboard extends StatefulWidget {
  const RemotePrintingDashboard({super.key});

  @override
  State<RemotePrintingDashboard> createState() => _RemotePrintingDashboardState();
}

class _RemotePrintingDashboardState extends State<RemotePrintingDashboard> {
  late RemotePrinterService _remotePrinterService;
  late PrinterBridgeService _printerBridgeService;
  bool _isInitialized = false;
  
  final TextEditingController _restaurantIdController = TextEditingController(text: '123456'); // Set default restaurant code
  final TextEditingController _printerIdController = TextEditingController(text: 'kitchen_printer_01');
  
  @override
  void initState() {
    super.initState();
    _initializeServices();
  }
  
  void _initializeServices() {
    final printingService = Provider.of<PrintingService>(context, listen: false);
    _remotePrinterService = RemotePrinterService(printingService);
    _printerBridgeService = PrinterBridgeService(_remotePrinterService, printingService);
    
    // Add listeners
    _remotePrinterService.addListener(_onServiceUpdate);
    _printerBridgeService.addListener(_onBridgeUpdate);
    
    setState(() {
      _isInitialized = true;
    });
  }
  
  void _onServiceUpdate() {
    if (mounted) {
      setState(() {});
    }
  }
  
  void _onBridgeUpdate() {
    if (mounted) {
      setState(() {});
    }
  }
  
  @override
  void dispose() {
    _remotePrinterService.removeListener(_onServiceUpdate);
    _printerBridgeService.removeListener(_onBridgeUpdate);
    _remotePrinterService.dispose();
    _restaurantIdController.dispose();
    _printerIdController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote Printing Dashboard'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.indigo, Colors.deepPurple],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 20),
                  _buildConfigurationCard(),
                  const SizedBox(height: 20),
                  _buildStatusCard(),
                  const SizedBox(height: 20),
                  _buildStatisticsCard(),
                  const SizedBox(height: 20),
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeaderCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.cloud_queue, size: 32, color: Colors.indigo),
                const SizedBox(width: 12),
                const Text(
                  'Internet-Based Printing',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Send orders from anywhere in the world to your kitchen printers via cloud connection.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildConfigurationCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Configuration',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _restaurantIdController,
              decoration: const InputDecoration(
                labelText: 'Restaurant ID',
                hintText: 'Enter your unique restaurant ID',
                prefixIcon: Icon(Icons.restaurant),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _printerIdController,
              decoration: const InputDecoration(
                labelText: 'Printer ID',
                hintText: 'Enter your kitchen printer ID',
                prefixIcon: Icon(Icons.print),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _remotePrinterService.isInitialized
                        ? null
                        : () => _initializeRemotePrinting(),
                    icon: const Icon(Icons.rocket_launch),
                    label: const Text('Initialize Remote Printing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _printerBridgeService.isRunning
                        ? () => _stopPrinterBridge()
                        : () => _startPrinterBridge(),
                    icon: Icon(_printerBridgeService.isRunning
                        ? Icons.stop
                        : Icons.play_arrow),
                    label: Text(_printerBridgeService.isRunning
                        ? 'Stop Bridge'
                        : 'Start Bridge'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _printerBridgeService.isRunning
                          ? Colors.red
                          : Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusCard() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Connection Status',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildStatusItem(
              'Remote Service',
              _remotePrinterService.isInitialized ? 'Connected' : 'Disconnected',
              _remotePrinterService.isInitialized ? Colors.green : Colors.red,
              _remotePrinterService.isInitialized ? Icons.check_circle : Icons.error,
            ),
            _buildStatusItem(
              'Printer Bridge',
              _printerBridgeService.isRunning ? 'Running' : 'Stopped',
              _printerBridgeService.isRunning ? Colors.green : Colors.orange,
              _printerBridgeService.isRunning ? Icons.check_circle : Icons.pause_circle,
            ),
            _buildStatusItem(
              'Polling Status',
              _remotePrinterService.isPolling ? 'Active' : 'Inactive',
              _remotePrinterService.isPolling ? Colors.green : Colors.grey,
              _remotePrinterService.isPolling ? Icons.sync : Icons.sync_disabled,
            ),
            if (_remotePrinterService.lastActivity != null)
              _buildStatusItem(
                'Last Activity',
                _formatDateTime(_remotePrinterService.lastActivity!),
                Colors.blue,
                Icons.access_time,
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusItem(String label, String value, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatisticsCard() {
    final stats = _remotePrinterService.getStatistics();
    
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Statistics',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: () => _remotePrinterService.resetStatistics(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Orders Sent',
                    stats['ordersSent'].toString(),
                    Colors.blue,
                    Icons.send,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Orders Received',
                    stats['ordersReceived'].toString(),
                    Colors.green,
                    Icons.receipt,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Failed Orders',
                    stats['failedOrders'].toString(),
                    Colors.red,
                    Icons.error,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Pending Orders',
                    stats['pendingOrders'].toString(),
                    Colors.orange,
                    Icons.pending,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
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
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButtons() {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Actions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _remotePrinterService.isInitialized
                        ? () => _remotePrinterService.manualSync()
                        : null,
                    icon: const Icon(Icons.sync),
                    label: const Text('Manual Sync'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _remotePrinterService.isInitialized
                        ? () => _sendTestOrder()
                        : null,
                    icon: const Icon(Icons.print),
                    label: const Text('Send Test Order'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showSetupInstructions(),
                icon: const Icon(Icons.help_outline),
                label: const Text('Setup Instructions'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _initializeRemotePrinting() async {
    if (_restaurantIdController.text.isEmpty || _printerIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Restaurant ID and Printer ID')),
      );
      return;
    }
    
    final success = await _remotePrinterService.initialize(
      _restaurantIdController.text,
      _printerIdController.text,
    );
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Remote printing service initialized successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to initialize remote printing service'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _startPrinterBridge() async {
    if (_restaurantIdController.text.isEmpty || _printerIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter Restaurant ID and Printer ID')),
      );
      return;
    }
    
    final success = await _printerBridgeService.startBridge(
      _restaurantIdController.text,
      _printerIdController.text,
    );
    
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Printer bridge started successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start printer bridge'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  void _stopPrinterBridge() {
    _printerBridgeService.stopBridge();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Printer bridge stopped'),
        backgroundColor: Colors.orange,
      ),
    );
  }
  
  void _sendTestOrder() {
    // Create a test order
    final testOrder = Order(
      id: 'test_${DateTime.now().millisecondsSinceEpoch}',
      tableId: 'Table 1',
      items: [],
      type: OrderType.dineIn,
      status: OrderStatus.pending,
      customerName: 'Test Customer',
      specialInstructions: 'Test order from remote printing dashboard',
    );
    
    _remotePrinterService.sendOrderToRemotePrinter(testOrder, _printerIdController.text);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Test order sent!'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  void _showSetupInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Setup Instructions'),
        content: const SingleChildScrollView(
          child: Text('''
🌐 REMOTE PRINTING SETUP GUIDE

STEP 1: CLOUD SERVICE SETUP
1. Replace 'your-cloud-service.com' with your actual cloud service URL
2. Replace 'your-api-key-here' with your actual API key
3. Deploy the cloud service (Firebase, AWS, etc.)

STEP 2: KITCHEN SETUP (Restaurant Side)
1. Install POS app on kitchen device
2. Connect kitchen device to internet
3. Connect thermal printer to kitchen network
4. Enter Restaurant ID and Printer ID
5. Click "Start Bridge" to begin listening for orders

STEP 3: POS APP SETUP (Remote Side)
1. Install POS app on any device with internet
2. Enter same Restaurant ID and target Printer ID
3. Click "Initialize Remote Printing"
4. Start sending orders!

STEP 4: TESTING
1. Use "Send Test Order" button
2. Check kitchen printer for test receipt
3. Monitor statistics for successful transmission

FEATURES:
✅ Works from anywhere in the world
✅ Automatic retry for failed orders
✅ Real-time order polling
✅ Offline order queuing
✅ Priority-based order processing
✅ Comprehensive statistics tracking

REQUIREMENTS:
- Internet connection on both sides
- Cloud service with API endpoints
- Kitchen printer connected to network
- Restaurant ID and Printer ID configuration
          '''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
} 