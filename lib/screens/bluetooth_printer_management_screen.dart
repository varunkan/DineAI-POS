import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/printing_service.dart';
import '../models/printer_configuration.dart';
import 'tm_m30iii_troubleshooting_screen.dart';

/// 🖨️ Bluetooth Printer Management Screen
/// 
/// This screen allows users to:
/// - Discover Bluetooth printers
/// - Connect to multiple Bluetooth printers simultaneously
/// - Manage printer assignments
/// - Test printer connections
class BluetoothPrinterManagementScreen extends StatefulWidget {
  const BluetoothPrinterManagementScreen({Key? key}) : super(key: key);

  @override
  State<BluetoothPrinterManagementScreen> createState() => _BluetoothPrinterManagementScreenState();
}

class _BluetoothPrinterManagementScreenState extends State<BluetoothPrinterManagementScreen> {
  bool _isDiscovering = false;
  bool _isConnecting = false;
  List<PrinterDevice> _discoveredPrinters = [];
  List<PrinterConfiguration> _connectedPrinters = [];

  @override
  void initState() {
    super.initState();
    _loadConnectedPrinters();
  }

  Future<void> _loadConnectedPrinters() async {
    final printingService = Provider.of<PrintingService>(context, listen: false);
    // Load existing printer configurations
    // This would typically come from your database
  }

  Future<void> _discoverBluetoothPrinters() async {
    setState(() {
      _isDiscovering = true;
      _discoveredPrinters.clear();
    });

    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      final printers = await printingService.discoverBluetoothPrinters();
      
      setState(() {
        _discoveredPrinters = printers;
        _isDiscovering = false;
      });
    } catch (e) {
      setState(() {
        _isDiscovering = false;
      });
      _showErrorSnackBar('Error discovering printers: $e');
    }
  }

  Future<void> _connectToPrinter(PrinterDevice printer) async {
    setState(() {
      _isConnecting = true;
    });

    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      
      // Create printer configuration
      final config = PrinterConfiguration(
        name: printer.name,
        type: PrinterType.bluetooth,
        bluetoothAddress: printer.address,
        model: PrinterModel.epsonTMGeneric,
        isActive: true,
      );

      // Connect to the printer
      final results = await printingService.connectToMultiplePrinters([config]);
      final success = results[config.id] ?? false;

      if (success) {
        setState(() {
          _connectedPrinters.add(config);
        });
        _showSuccessSnackBar('Connected to ${printer.name}');
      } else {
        _showErrorSnackBar('Failed to connect to ${printer.name}');
      }
    } catch (e) {
      _showErrorSnackBar('Error connecting to printer: $e');
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _disconnectFromPrinter(PrinterConfiguration printer) async {
    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      final success = await printingService.disconnectFromPrinter(printer.id);
      
      if (success) {
        setState(() {
          _connectedPrinters.removeWhere((p) => p.id == printer.id);
        });
        _showSuccessSnackBar('Disconnected from ${printer.name}');
      } else {
        _showErrorSnackBar('Failed to disconnect from ${printer.name}');
      }
    } catch (e) {
      _showErrorSnackBar('Error disconnecting from printer: $e');
    }
  }

  Future<void> _testPrinter(PrinterConfiguration printer) async {
    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      
      // Create test content
      final testContent = '''
TEST PRINT - ${printer.name}
Time: ${DateTime.now().toString()}
Status: Bluetooth Connection Test
================================
If you can read this message,
your Bluetooth printer is working correctly!

Printer: ${printer.name}
Address: ${printer.bluetoothAddress}
Type: ${printer.type}
================================
      ''';

      // Send test print
      await printingService.printToSpecificPrinter(printer.id, testContent, PrinterType.bluetooth);
      _showSuccessSnackBar('Test print sent to ${printer.name}');
    } catch (e) {
      _showErrorSnackBar('Error testing printer: $e');
    }
  }

  Future<void> _printToAllConnectedPrinters() async {
    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      
      final testContent = '''
MULTI-PRINTER TEST
Time: ${DateTime.now().toString()}
Status: Multiple Bluetooth Printers Test
================================
This message was sent to ALL connected
Bluetooth printers simultaneously!

Connected Printers: ${_connectedPrinters.length}
================================
      ''';

      // Print to all connected printers
      for (final printer in _connectedPrinters) {
        try {
          await printingService.printToSpecificPrinter(printer.id, testContent, PrinterType.bluetooth);
        } catch (e) {
        }
      }
      
      _showSuccessSnackBar('Sent to ${_connectedPrinters.length} printers');
    } catch (e) {
      _showErrorSnackBar('Error printing to all printers: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Printer Management'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.help),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TmM30iiiTroubleshootingScreen(),
                ),
              );
            },
            tooltip: 'TM-M30III Troubleshooting',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isDiscovering ? null : _discoverBluetoothPrinters,
          ),
        ],
      ),
      body: Column(
        children: [
          // Status Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Icon(
                  Icons.bluetooth,
                  color: _connectedPrinters.isNotEmpty ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Connected: ${_connectedPrinters.length} printers',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_connectedPrinters.isNotEmpty)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.print),
                    label: const Text('Test All'),
                    onPressed: _printToAllConnectedPrinters,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),

          // Discovered Printers Section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text(
                        'Discovered Bluetooth Printers',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (_isDiscovering)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: _discoveredPrinters.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bluetooth_searching,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No Bluetooth printers found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Make sure your printers are paired with this device',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: _discoveredPrinters.length,
                          itemBuilder: (context, index) {
                            final printer = _discoveredPrinters[index];
                            final isConnected = _connectedPrinters
                                .any((p) => p.bluetoothAddress == printer.address);

                            return Card(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              child: ListTile(
                                leading: Icon(
                                  Icons.print,
                                  color: isConnected ? Colors.green : Colors.grey,
                                ),
                                title: Text(printer.name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Address: ${printer.address}'),
                                    Text('Type: ${printer.type}'),
                                  ],
                                ),
                                trailing: isConnected
                                    ? const Chip(
                                        label: Text('Connected'),
                                        backgroundColor: Colors.green,
                                        labelStyle: TextStyle(color: Colors.white),
                                      )
                                    : ElevatedButton(
                                        onPressed: _isConnecting
                                            ? null
                                            : () => _connectToPrinter(printer),
                                        child: _isConnecting
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Text('Connect'),
                                      ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // Connected Printers Section
          if (_connectedPrinters.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.green[50],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connected Printers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...(_connectedPrinters.map((printer) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.print, color: Colors.green),
                      title: Text(printer.name),
                      subtitle: Text('Bluetooth: ${printer.bluetoothAddress}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.print),
                            onPressed: () => _testPrinter(printer),
                            tooltip: 'Test Print',
                          ),
                          IconButton(
                            icon: const Icon(Icons.bluetooth_disabled),
                            onPressed: () => _disconnectFromPrinter(printer),
                            tooltip: 'Disconnect',
                          ),
                        ],
                      ),
                    ),
                  )).toList()),
                ],
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isDiscovering ? null : _discoverBluetoothPrinters,
        icon: _isDiscovering
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.bluetooth_searching),
        label: Text(_isDiscovering ? 'Discovering...' : 'Discover Printers'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
    );
  }
} 