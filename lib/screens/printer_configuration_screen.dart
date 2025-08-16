import 'package:flutter/material.dart';
import '../models/printer_configuration.dart';

/// Simple Printer Configuration Screen
/// Temporarily simplified to fix compilation errors while preserving core functionality
class PrinterConfigurationScreen extends StatefulWidget {
  final PrinterConfiguration? printerConfiguration;

  const PrinterConfigurationScreen({
    Key? key,
    this.printerConfiguration,
  }) : super(key: key);

  @override
  State<PrinterConfigurationScreen> createState() => _PrinterConfigurationScreenState();
}

class _PrinterConfigurationScreenState extends State<PrinterConfigurationScreen> {
  final _nameController = TextEditingController();
  final _ipController = TextEditingController();
  final _portController = TextEditingController();
  
  PrinterType _selectedType = PrinterType.wifi;
  PrinterModel _selectedModel = PrinterModel.epsonTMT88VI;

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    if (widget.printerConfiguration != null) {
      final config = widget.printerConfiguration!;
      _nameController.text = config.name;
      _selectedType = config.type;
      _selectedModel = config.model;
      _ipController.text = config.ipAddress ?? '';
      _portController.text = config.port.toString();
    } else {
      _nameController.text = 'New Printer';
      _ipController.text = '192.168.1.100';
      _portController.text = '9100';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _savePrinterConfiguration() {
    Navigator.pop(context, {
      'name': _nameController.text,
      'type': _selectedType,
      'model': _selectedModel,
      'ipAddress': _ipController.text,
      'port': int.tryParse(_portController.text) ?? 9100,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.printerConfiguration == null 
          ? 'Add Printer' 
          : 'Edit Printer'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          TextButton(
            onPressed: _savePrinterConfiguration,
            child: const Text(
              'SAVE',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Printer Name
            const Text(
              'Printer Name',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter printer name',
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Printer Type
            const Text(
              'Printer Type',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<PrinterType>(
              value: _selectedType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: PrinterType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.name.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedType = value);
                }
              },
            ),
            
            const SizedBox(height: 24),
            
            // IP Address
            const Text(
              'IP Address',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _ipController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter IP address',
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Port
            const Text(
              'Port',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _portController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter port number',
              ),
              keyboardType: TextInputType.number,
            ),
            
            const SizedBox(height: 24),
            
            // Printer Model
            const Text(
              'Printer Model',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<PrinterModel>(
              value: _selectedModel,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
              ),
              items: PrinterModel.values.map((model) {
                return DropdownMenuItem(
                  value: model,
                  child: Text(model.name),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedModel = value);
                }
              },
            ),
            
            const SizedBox(height: 32),
            
            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _savePrinterConfiguration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Save Configuration',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Info Card
            Card(
              color: Colors.blue.shade50,
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Configuration Notes',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      '• Ensure your printer is connected to the same network\n'
                      '• Default port for most thermal printers is 9100\n'
                      '• Test the connection after saving',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 