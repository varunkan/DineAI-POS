import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import '../services/printing_service.dart';
import '../models/printer_configuration.dart';

/// 🖨️ TM-M30III Bluetooth Troubleshooting Screen
/// 
/// This screen provides step-by-step troubleshooting for TM-m30iii Bluetooth connection issues
class TmM30iiiTroubleshootingScreen extends StatefulWidget {
  const TmM30iiiTroubleshootingScreen({Key? key}) : super(key: key);

  @override
  State<TmM30iiiTroubleshootingScreen> createState() => _TmM30iiiTroubleshootingScreenState();
}

class _TmM30iiiTroubleshootingScreenState extends State<TmM30iiiTroubleshootingScreen> {
  bool _isDiscovering = false;
  bool _isConnecting = false;
  bool _isTesting = false;
  List<PrinterDevice> _discoveredPrinters = [];
  PrinterConfiguration? _connectedPrinter;
  String _currentStep = 'Initializing...';
  List<String> _logMessages = [];

  @override
  void initState() {
    super.initState();
    _addLogMessage('🚀 TM-M30III Troubleshooting Started');
    _addLogMessage('Printer ID: TM-m30iii_020372');
    _startTroubleshooting();
  }

  void _addLogMessage(String message) {
    setState(() {
      _logMessages.add('${DateTime.now().toString().substring(11, 19)}: $message');
      if (_logMessages.length > 20) {
        _logMessages.removeAt(0);
      }
    });
  }

  Future<void> _startTroubleshooting() async {
    await _step1CheckBluetoothStatus();
    await _step2DiscoverPrinters();
    await _step3ConnectToPrinter();
    await _step4TestConnection();
  }

  Future<void> _step1CheckBluetoothStatus() async {
    setState(() {
      _currentStep = 'Step 1: Checking Bluetooth Status';
    });
    _addLogMessage('📱 Checking Bluetooth availability...');

    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      final bluetooth = FlutterBluetoothSerial.instance;
      
      final isAvailable = await bluetooth.isAvailable;
      final isEnabled = await bluetooth.isEnabled;
      
      if (isAvailable == true) {
        _addLogMessage('✅ Bluetooth is available');
      } else {
        _addLogMessage('❌ Bluetooth is not available');
        _showErrorDialog('Bluetooth is not available on this device');
        return;
      }
      
      if (isEnabled == true) {
        _addLogMessage('✅ Bluetooth is enabled');
      } else {
        _addLogMessage('❌ Bluetooth is disabled');
        _showErrorDialog('Please enable Bluetooth in your device settings');
        return;
      }
      
    } catch (e) {
      _addLogMessage('❌ Error checking Bluetooth status: $e');
      _showErrorDialog('Error checking Bluetooth status: $e');
    }
  }

  Future<void> _step2DiscoverPrinters() async {
    setState(() {
      _currentStep = 'Step 2: Discovering TM-M30III Printers';
      _isDiscovering = true;
    });
    _addLogMessage('🔍 Starting enhanced discovery for TM-M30III...');

    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      final printers = await printingService.discoverBluetoothPrinters();
      
      setState(() {
        _discoveredPrinters = printers;
        _isDiscovering = false;
      });
      
      _addLogMessage('📱 Found ${printers.length} Bluetooth devices');
      
      // Look specifically for TM-m30iii
      final tmM30iiiPrinters = printers.where((p) => 
        p.name.toLowerCase().contains('tm-m30iii') || 
        p.name.toLowerCase().contains('020372') ||
        p.address.contains('020372')
      ).toList();
      
      if (tmM30iiiPrinters.isNotEmpty) {
        _addLogMessage('🎯 Found ${tmM30iiiPrinters.length} TM-M30III printer(s)');
        for (final printer in tmM30iiiPrinters) {
          _addLogMessage('   - ${printer.name} (${printer.address})');
        }
      } else {
        _addLogMessage('⚠️ No TM-M30III printers found in paired devices');
        _addLogMessage('💡 Make sure TM-m30iii_020372 is paired with this device');
        _showPairingInstructions();
      }
      
    } catch (e) {
      setState(() {
        _isDiscovering = false;
      });
      _addLogMessage('❌ Error discovering printers: $e');
      _showErrorDialog('Error discovering printers: $e');
    }
  }

  Future<void> _step3ConnectToPrinter() async {
    setState(() {
      _currentStep = 'Step 3: Connecting to TM-M30III';
      _isConnecting = true;
    });
    
    // Find TM-m30iii printer
    final tmM30iiiPrinter = _discoveredPrinters.firstWhere(
      (p) => p.name.toLowerCase().contains('tm-m30iii') || 
             p.name.toLowerCase().contains('020372') ||
             p.address.contains('020372'),
      orElse: () => _discoveredPrinters.first,
    );
    
    if (_discoveredPrinters.isEmpty) {
      _addLogMessage('❌ No printers available for connection');
      setState(() {
        _isConnecting = false;
      });
      return;
    }
    
    _addLogMessage('🔗 Attempting to connect to ${tmM30iiiPrinter.name}...');

    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      
      // Create printer configuration
      final config = PrinterConfiguration(
        name: tmM30iiiPrinter.name,
        type: PrinterType.bluetooth,
        bluetoothAddress: tmM30iiiPrinter.address,
        model: PrinterModel.epsonTMGeneric,
        isActive: true,
      );

      // Connect with enhanced retry logic
      final results = await printingService.connectToMultiplePrinters([config]);
      final success = results[config.id] ?? false;

      if (success) {
        setState(() {
          _connectedPrinter = config;
          _isConnecting = false;
        });
        _addLogMessage('✅ Successfully connected to ${tmM30iiiPrinter.name}');
      } else {
        setState(() {
          _isConnecting = false;
        });
        _addLogMessage('❌ Failed to connect to ${tmM30iiiPrinter.name}');
        _showConnectionTroubleshooting();
      }
    } catch (e) {
      setState(() {
        _isConnecting = false;
      });
      _addLogMessage('❌ Error connecting to printer: $e');
      _showErrorDialog('Error connecting to printer: $e');
    }
  }

  Future<void> _step4TestConnection() async {
    if (_connectedPrinter == null) {
      _addLogMessage('⚠️ Skipping test - no printer connected');
      return;
    }
    
    setState(() {
      _currentStep = 'Step 4: Testing TM-M30III Connection';
      _isTesting = true;
    });
    _addLogMessage('🖨️ Testing print functionality...');

    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      
      final testContent = '''
TM-M30III CONNECTION TEST
========================
Time: ${DateTime.now().toString()}
Printer: ${_connectedPrinter!.name}
Address: ${_connectedPrinter!.bluetoothAddress}
Status: Bluetooth Connection Test
========================
If you can read this message,
your TM-M30III is working correctly!

✅ Connection Successful
========================
      ''';

      await printingService.printToSpecificPrinter(
        _connectedPrinter!.id, 
        testContent, 
        PrinterType.bluetooth
      );
      
      setState(() {
        _isTesting = false;
      });
      _addLogMessage('✅ Test print sent successfully');
      _addLogMessage('🎉 TM-M30III is ready for customer orders!');
      
    } catch (e) {
      setState(() {
        _isTesting = false;
      });
      _addLogMessage('❌ Test print failed: $e');
      _showErrorDialog('Test print failed: $e');
    }
  }

  void _showPairingInstructions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pair TM-M30III with Device'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To connect to TM-m30iii_020372:'),
            SizedBox(height: 8),
            Text('1. Go to your device Bluetooth settings'),
            Text('2. Make sure TM-M30III is in pairing mode'),
            Text('3. Look for "TM-m30iii_020372" in the list'),
            Text('4. Tap to pair and enter PIN if prompted'),
            Text('5. Return to this app and try again'),
            SizedBox(height: 8),
            Text('Note: The printer must be in pairing mode (usually hold a button for 3 seconds)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showConnectionTroubleshooting() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connection Troubleshooting'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('If TM-M30III won\'t connect:'),
            SizedBox(height: 8),
            Text('1. Check if printer is turned on'),
            Text('2. Ensure printer is not printing'),
            Text('3. Try turning Bluetooth off/on'),
            Text('4. Restart the printer'),
            Text('5. Check if printer is connected to another device'),
            SizedBox(height: 8),
            Text('Common issues:'),
            Text('• Printer in sleep mode'),
            Text('• Bluetooth interference'),
            Text('• Out of range (keep within 10 meters)'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TM-M30III Troubleshooting'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isDiscovering || _isConnecting || _isTesting 
              ? null 
              : _startTroubleshooting,
          ),
        ],
      ),
      body: Column(
        children: [
          // Current Step
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.orange[50],
            child: Row(
              children: [
                Icon(
                  _connectedPrinter != null ? Icons.check_circle : Icons.info,
                  color: _connectedPrinter != null ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _currentStep,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Status Indicators
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildStatusIndicator('Discovery', _isDiscovering),
                const SizedBox(width: 16),
                _buildStatusIndicator('Connection', _isConnecting),
                const SizedBox(width: 16),
                _buildStatusIndicator('Test', _isTesting),
              ],
            ),
          ),

          // Discovered Printers
          if (_discoveredPrinters.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Discovered Printers',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...(_discoveredPrinters.map((printer) => Card(
                    child: ListTile(
                      leading: Icon(
                        Icons.print,
                        color: printer.name.toLowerCase().contains('tm-m30iii') || 
                               printer.name.toLowerCase().contains('020372')
                          ? Colors.orange
                          : Colors.grey,
                      ),
                      title: Text(printer.name),
                      subtitle: Text('${printer.address} (${printer.type})'),
                      trailing: printer.name.toLowerCase().contains('tm-m30iii') || 
                               printer.name.toLowerCase().contains('020372')
                        ? const Chip(
                            label: Text('TM-M30III'),
                            backgroundColor: Colors.orange,
                            labelStyle: TextStyle(color: Colors.white),
                          )
                        : null,
                    ),
                  )).toList()),
                ],
              ),
            ),
          ],

          // Connected Printer
          if (_connectedPrinter != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.green[50],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Connected Printer',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.print, color: Colors.green),
                      title: Text(_connectedPrinter!.name),
                      subtitle: Text('Bluetooth: ${_connectedPrinter!.bluetoothAddress}'),
                      trailing: const Chip(
                        label: Text('Connected'),
                        backgroundColor: Colors.green,
                        labelStyle: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Log Messages
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Troubleshooting Log',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: ListView.builder(
                        itemCount: _logMessages.length,
                        itemBuilder: (context, index) {
                          final message = _logMessages[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              message,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String label, bool isActive) {
    return Column(
      children: [
        Icon(
          isActive ? Icons.hourglass_empty : Icons.check_circle,
          color: isActive ? Colors.orange : Colors.green,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? Colors.orange : Colors.green,
          ),
        ),
      ],
    );
  }
} 