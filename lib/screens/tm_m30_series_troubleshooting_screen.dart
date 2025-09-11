import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import '../services/printing_service.dart';
import '../models/printer_configuration.dart';

/// 🖨️ TM-M30 Series Bluetooth Troubleshooting Screen
/// 
/// This screen provides step-by-step troubleshooting for all TM-M30 series Bluetooth connection issues
/// Supports: TM-M30, TM-M30I, TM-M30II, TM-M30III, TM-M30III-L, TM-M30III-S
class TmM30SeriesTroubleshootingScreen extends StatefulWidget {
  const TmM30SeriesTroubleshootingScreen({Key? key}) : super(key: key);

  @override
  State<TmM30SeriesTroubleshootingScreen> createState() => _TmM30SeriesTroubleshootingScreenState();
}

class _TmM30SeriesTroubleshootingScreenState extends State<TmM30SeriesTroubleshootingScreen> {
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
    _addLogMessage('🚀 TM-M30 Series Troubleshooting Started');
    _addLogMessage('Supported Models: TM-M30, TM-M30I, TM-M30II, TM-M30III, TM-M30III-L, TM-M30III-S');
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
      _currentStep = 'Step 2: Discovering TM-M30 Series Printers';
      _isDiscovering = true;
    });
    _addLogMessage('🔍 Starting enhanced discovery for TM-M30 series...');

    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      final printers = await printingService.discoverBluetoothPrinters();
      
      setState(() {
        _discoveredPrinters = printers;
        _isDiscovering = false;
      });
      
      _addLogMessage('📱 Found ${printers.length} Bluetooth devices');
      
      // Look specifically for all TM-M30 series printers
      final tmM30SeriesPrinters = printers.where((p) => 
        p.name.toLowerCase().contains('tm-m30') ||
        p.name.toLowerCase().contains('tm-m30i') ||
        p.name.toLowerCase().contains('tm-m30ii') ||
        p.name.toLowerCase().contains('tm-m30iii') ||
        p.address.toLowerCase().contains('tm-m30')
      ).toList();
      
      if (tmM30SeriesPrinters.isNotEmpty) {
        _addLogMessage('🎯 Found ${tmM30SeriesPrinters.length} TM-M30 series printer(s)');
        for (final printer in tmM30SeriesPrinters) {
          _addLogMessage('   - ${printer.name} (${printer.address})');
        }
      } else {
        _addLogMessage('⚠️ No TM-M30 series printers found in paired devices');
        _addLogMessage('💡 Make sure your TM-M30 series printer is paired with this device');
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
      _currentStep = 'Step 3: Connecting to TM-M30 Series';
      _isConnecting = true;
    });
    
    // Find any TM-M30 series printer
    final tmM30SeriesPrinter = _discoveredPrinters.firstWhere(
      (p) => p.name.toLowerCase().contains('tm-m30') ||
             p.name.toLowerCase().contains('tm-m30i') ||
             p.name.toLowerCase().contains('tm-m30ii') ||
             p.name.toLowerCase().contains('tm-m30iii') ||
             p.address.toLowerCase().contains('tm-m30'),
      orElse: () => _discoveredPrinters.first,
    );
    
    if (_discoveredPrinters.isEmpty) {
      _addLogMessage('❌ No printers available for connection');
      setState(() {
        _isConnecting = false;
      });
      return;
    }
    
    _addLogMessage('🔗 Attempting to connect to ${tmM30SeriesPrinter.name}...');

    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      
      // Create printer configuration
      final config = PrinterConfiguration(
        name: tmM30SeriesPrinter.name,
        type: PrinterType.bluetooth,
        bluetoothAddress: tmM30SeriesPrinter.address,
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
        _addLogMessage('✅ Successfully connected to ${tmM30SeriesPrinter.name}');
      } else {
        setState(() {
          _isConnecting = false;
        });
        _addLogMessage('❌ Failed to connect to ${tmM30SeriesPrinter.name}');
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
      _currentStep = 'Step 4: Testing TM-M30 Series Connection';
      _isTesting = true;
    });
    _addLogMessage('🖨️ Testing print functionality...');

    try {
      final printingService = Provider.of<PrintingService>(context, listen: false);
      
      final testContent = '''
TM-M30 SERIES CONNECTION TEST
=============================
Time: ${DateTime.now().toString()}
Printer: ${_connectedPrinter!.name}
Address: ${_connectedPrinter!.bluetoothAddress}
Status: Bluetooth Connection Test
=============================
If you can read this message,
your TM-M30 series printer is working correctly!

✅ Connection Successful
=============================
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
      _addLogMessage('🎉 TM-M30 series printer is ready for customer orders!');
      
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
        title: const Text('Pair TM-M30 Series with Device'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('To connect to any TM-M30 series printer:'),
            SizedBox(height: 8),
            Text('1. Go to your device Bluetooth settings'),
            Text('2. Make sure your TM-M30 series printer is in pairing mode'),
            Text('3. Look for your printer name in the list'),
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
        title: const Text('TM-M30 Series Connection Troubleshooting'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('If your TM-M30 series printer won\'t connect:'),
            SizedBox(height: 8),
            Text('1. Check if printer is turned on'),
            Text('2. Ensure printer is in pairing mode'),
            Text('3. Move closer to the printer (within 10 meters)'),
            Text('4. Check for interference from other devices'),
            Text('5. Try unpairing and re-pairing the device'),
            SizedBox(height: 8),
            Text('Note: Some TM-M30 series models may require specific pairing procedures'),
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
        title: const Text('TM-M30 Series Troubleshooting'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Current Step
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue[50],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Step:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _currentStep,
                  style: const TextStyle(fontSize: 18, color: Colors.blue),
                ),
              ],
            ),
          ),

          // Action Buttons
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: _isDiscovering ? null : _step2DiscoverPrinters,
                  icon: const Icon(Icons.search),
                  label: const Text('Discover'),
                ),
                ElevatedButton.icon(
                  onPressed: _isConnecting ? null : _step3ConnectToPrinter,
                  icon: const Icon(Icons.bluetooth),
                  label: const Text('Connect'),
                ),
                ElevatedButton.icon(
                  onPressed: _isTesting ? null : _step4TestConnection,
                  icon: const Icon(Icons.print),
                  label: const Text('Test Print'),
                ),
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
                        color: printer.name.toLowerCase().contains('tm-m30') ||
                               printer.name.toLowerCase().contains('tm-m30i') ||
                               printer.name.toLowerCase().contains('tm-m30ii') ||
                               printer.name.toLowerCase().contains('tm-m30iii')
                          ? Colors.orange
                          : Colors.grey,
                      ),
                      title: Text(printer.name),
                      subtitle: Text('${printer.address} (${printer.type})'),
                      trailing: printer.name.toLowerCase().contains('tm-m30') ||
                               printer.name.toLowerCase().contains('tm-m30i') ||
                               printer.name.toLowerCase().contains('tm-m30ii') ||
                               printer.name.toLowerCase().contains('tm-m30iii')
                        ? const Chip(
                            label: Text('TM-M30 Series'),
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
} 