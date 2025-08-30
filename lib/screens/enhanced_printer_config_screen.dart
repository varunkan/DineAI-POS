import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/printer_configuration.dart';
import '../services/tenant_printer_config_service.dart';
import '../services/enhanced_thermal_printer_service.dart';
import '../widgets/confirmation_dialog.dart';

/// 🖨️ Enhanced Printer Configuration Screen
/// 
/// This screen provides comprehensive configuration for Epson thermal printers with 80mm support.
/// Features:
/// - Printer type selection (WiFi, Ethernet, Bluetooth, USB)
/// - Paper size configuration (58mm, 80mm, 112mm)
/// - Print density and speed control
/// - Connection testing and validation
/// - Real-time Firebase sync
/// - Multi-tenant support
class EnhancedPrinterConfigScreen extends StatefulWidget {
  final String? existingPrinterId;
  
  const EnhancedPrinterConfigScreen({
    super.key,
    this.existingPrinterId,
  });

  @override
  State<EnhancedPrinterConfigScreen> createState() => _EnhancedPrinterConfigScreenState();
}

class _EnhancedPrinterConfigScreenState extends State<EnhancedPrinterConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _ipAddressController = TextEditingController();
  final _portController = TextEditingController();
  final _bluetoothAddressController = TextEditingController();
  final _macAddressController = TextEditingController();
  
  // Configuration values
  PrinterType _selectedPrinterType = PrinterType.thermal;
  PrinterModel _selectedPrinterModel = PrinterModel.epsonTMT88VI;
  PaperSize _selectedPaperSize = PaperSize.paper80mm;
  PrintDensity _selectedPrintDensity = PrintDensity.normal;
  int _printSpeed = 3;
  bool _autoCut = true;
  bool _autoFeed = true;
  int _feedLines = 3;
  bool _enableBarcode = true;
  bool _enableQRCode = true;
  int _dpi = 203;
  bool _enableStatusBack = true;
  
  // Form state
  bool _isLoading = false;
  bool _isEditing = false;
  PrinterConfiguration? _editingPrinter;
  
  @override
  void initState() {
    super.initState();
    _initializeForm();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _ipAddressController.dispose();
    _portController.dispose();
    _bluetoothAddressController.dispose();
    _macAddressController.dispose();
    super.dispose();
  }
  
  /// Initialize form with existing data or defaults
  void _initializeForm() {
    if (widget.existingPrinterId != null) {
      _loadExistingPrinter();
    } else {
      _setDefaultValues();
    }
  }
  
  /// Load existing printer configuration for editing
  void _loadExistingPrinter() {
    final printerService = context.read<TenantPrinterConfigService>();
    final printer = printerService.getPrinterConfig(widget.existingPrinterId!);
    
    if (printer != null) {
      _editingPrinter = printer;
      _isEditing = true;
      
      // Populate form fields
      _nameController.text = printer.name;
      _descriptionController.text = printer.description;
      _ipAddressController.text = printer.ipAddress;
      _portController.text = printer.port.toString();
      _bluetoothAddressController.text = printer.bluetoothAddress;
      _macAddressController.text = printer.macAddress;
      
      _selectedPrinterType = printer.type;
      _selectedPrinterModel = printer.model;
      _selectedPaperSize = printer.thermalSettings.paperSize;
      _selectedPrintDensity = printer.thermalSettings.printDensity;
      _printSpeed = printer.thermalSettings.printSpeed;
      _autoCut = printer.thermalSettings.autoCut;
      _autoFeed = printer.thermalSettings.autoFeed;
      _feedLines = printer.thermalSettings.feedLines;
      _enableBarcode = printer.thermalSettings.enableBarcode;
      _enableQRCode = printer.thermalSettings.enableQRCode;
      _dpi = printer.thermalSettings.dpi;
      _enableStatusBack = printer.thermalSettings.enableStatusBack;
      
      setState(() {});
    }
  }
  
  /// Set default values for new printer
  void _setDefaultValues() {
    _nameController.text = '';
    _descriptionController.text = '';
    _ipAddressController.text = '';
    _portController.text = '9100';
    _bluetoothAddressController.text = '';
    _macAddressController.text = '';
    
    _selectedPrinterType = PrinterType.thermal;
    _selectedPrinterModel = PrinterModel.epsonTMT88VI;
    _selectedPaperSize = PaperSize.paper80mm;
    _selectedPrintDensity = PrintDensity.normal;
    _printSpeed = 3;
    _autoCut = true;
    _autoFeed = true;
    _feedLines = 3;
    _enableBarcode = true;
    _enableQRCode = true;
    _dpi = 203;
    _enableStatusBack = true;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Printer' : 'Add New Printer'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: Consumer<TenantPrinterConfigService>(
        builder: (context, printerService, child) {
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBasicInfoSection(),
                  const SizedBox(height: 24),
                  _buildConnectionSection(),
                  const SizedBox(height: 24),
                  _buildThermalSettingsSection(),
                  const SizedBox(height: 24),
                  _buildAdvancedSettingsSection(),
                  const SizedBox(height: 32),
                  _buildActionButtons(printerService),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  /// Basic printer information section
  Widget _buildBasicInfoSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Printer Name *',
                hintText: 'e.g., Main Kitchen Printer',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Printer name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Optional description of the printer',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PrinterModel>(
              value: _selectedPrinterModel,
              decoration: const InputDecoration(
                labelText: 'Printer Model *',
                border: OutlineInputBorder(),
              ),
              items: PrinterModel.values.map((model) {
                return DropdownMenuItem(
                  value: model,
                  child: Text('${model.displayName} (${model.defaultPaperSize})'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPrinterModel = value;
                    // Auto-set paper size based on model
                    if (value.defaultPaperSize == '80mm') {
                      _selectedPaperSize = PaperSize.paper80mm;
                    } else if (value.defaultPaperSize == '58mm') {
                      _selectedPaperSize = PaperSize.paper58mm;
                    }
                  });
                }
              },
            ),
          ],
        ),
      ),
    );
  }
  
  /// Connection settings section
  Widget _buildConnectionSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connection Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PrinterType>(
              value: _selectedPrinterType,
              decoration: const InputDecoration(
                labelText: 'Connection Type *',
                border: OutlineInputBorder(),
              ),
              items: PrinterType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.toString().split('.').last.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPrinterType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            if (_selectedPrinterType == PrinterType.wifi || 
                _selectedPrinterType == PrinterType.ethernet ||
                _selectedPrinterType == PrinterType.thermal) ...[
              TextFormField(
                controller: _ipAddressController,
                decoration: const InputDecoration(
                  labelText: 'IP Address *',
                  hintText: 'e.g., 192.168.1.100',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'IP address is required for network printers';
                  }
                  // Basic IP validation
                  final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
                  if (!ipRegex.hasMatch(value)) {
                    return 'Please enter a valid IP address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _portController,
                decoration: const InputDecoration(
                  labelText: 'Port *',
                  hintText: 'e.g., 9100',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Port is required';
                  }
                  final port = int.tryParse(value);
                  if (port == null || port <= 0 || port > 65535) {
                    return 'Port must be between 1 and 65535';
                  }
                  return null;
                },
              ),
            ],
            if (_selectedPrinterType == PrinterType.bluetooth) ...[
              TextFormField(
                controller: _bluetoothAddressController,
                decoration: const InputDecoration(
                  labelText: 'Bluetooth MAC Address *',
                  hintText: 'e.g., 00:11:22:33:44:55',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Bluetooth address is required for Bluetooth printers';
                  }
                  return null;
                },
              ),
            ],
            if (_selectedPrinterType == PrinterType.usb) ...[
              TextFormField(
                controller: _macAddressController,
                decoration: const InputDecoration(
                  labelText: 'USB Device ID',
                  hintText: 'USB device identifier',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  /// Thermal printer specific settings
  Widget _buildThermalSettingsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thermal Printer Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PaperSize>(
              value: _selectedPaperSize,
              decoration: const InputDecoration(
                labelText: 'Paper Size *',
                border: OutlineInputBorder(),
              ),
              items: PaperSize.values.map((size) {
                return DropdownMenuItem(
                  value: size,
                  child: Text('${size.displayName} (${size.dotWidth} dots)'),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPaperSize = value;
                    // Adjust DPI based on paper size
                    if (value == PaperSize.paper80mm) {
                      _dpi = 203; // Standard for 80mm
                    } else if (value == PaperSize.paper58mm) {
                      _dpi = 203; // Standard for 58mm
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<PrintDensity>(
              value: _selectedPrintDensity,
              decoration: const InputDecoration(
                labelText: 'Print Density *',
                border: OutlineInputBorder(),
              ),
              items: PrintDensity.values.map((density) {
                return DropdownMenuItem(
                  value: density,
                  child: Text(density.displayName),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPrintDensity = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: _printSpeed.toString(),
                    decoration: const InputDecoration(
                      labelText: 'Print Speed',
                      hintText: '1-5 (1=slow, 5=fast)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final speed = int.tryParse(value);
                      if (speed != null && speed >= 1 && speed <= 5) {
                        _printSpeed = speed;
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    initialValue: _dpi.toString(),
                    decoration: const InputDecoration(
                      labelText: 'DPI',
                      hintText: '203 or 300',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      final dpi = int.tryParse(value);
                      if (dpi == 203 || dpi == 300) {
                        _dpi = dpi;
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Auto Cut'),
                    value: _autoCut,
                    onChanged: (value) {
                      setState(() {
                        _autoCut = value ?? true;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Auto Feed'),
                    value: _autoFeed,
                    onChanged: (value) {
                      setState(() {
                        _autoFeed = value ?? true;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: _feedLines.toString(),
              decoration: const InputDecoration(
                labelText: 'Feed Lines After Print',
                hintText: 'Number of lines to feed',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                final lines = int.tryParse(value);
                if (lines != null && lines >= 0) {
                  _feedLines = lines;
                }
              },
            ),
          ],
        ),
      ),
    );
  }
  
  /// Advanced settings section
  Widget _buildAdvancedSettingsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Advanced Settings',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.blue[700],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Enable Barcode'),
                    subtitle: const Text('Support barcode printing'),
                    value: _enableBarcode,
                    onChanged: (value) {
                      setState(() {
                        _enableBarcode = value ?? true;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    title: const Text('Enable QR Code'),
                    subtitle: const Text('Support QR code printing'),
                    value: _enableQRCode,
                    onChanged: (value) {
                      setState(() {
                        _enableQRCode = value ?? true;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Enable Status Back'),
              subtitle: const Text('Receive printer status updates'),
              value: _enableStatusBack,
              onChanged: (value) {
                setState(() {
                  _enableStatusBack = value ?? true;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
  
  /// Action buttons section
  Widget _buildActionButtons(TenantPrinterConfigService printerService) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : () => _testConnection(printerService),
            icon: const Icon(Icons.wifi_find),
            label: const Text('Test Connection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : () => _savePrinter(printerService),
            icon: Icon(_isEditing ? Icons.save : Icons.add),
            label: Text(_isEditing ? 'Update' : 'Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }
  
  /// Test printer connection
  Future<void> _testConnection(TenantPrinterConfigService printerService) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Create temporary configuration for testing
      final testConfig = _createPrinterConfiguration();
      
      final success = await printerService.testPrinterConnection(testConfig.id);
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Connection test successful!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Connection test failed: ${printerService.lastError}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error testing connection: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Save printer configuration
  Future<void> _savePrinter(TenantPrinterConfigService printerService) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final config = _createPrinterConfiguration();
      
      bool success;
      if (_isEditing) {
        success = await printerService.updatePrinterConfig(config);
      } else {
        success = await printerService.createPrinterConfig(config);
      }
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditing ? '✅ Printer updated successfully!' : '✅ Printer added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true); // Return success
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to save printer: ${printerService.lastError}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error saving printer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Create printer configuration from form data
  PrinterConfiguration _createPrinterConfiguration() {
    final thermalSettings = ThermalPrinterSettings(
      paperSize: _selectedPaperSize,
      printDensity: _selectedPrintDensity,
      printSpeed: _printSpeed,
      autoCut: _autoCut,
      autoFeed: _autoFeed,
      feedLines: _feedLines,
      enableBarcode: _enableBarcode,
      enableQRCode: _enableQRCode,
      dpi: _dpi,
      enableStatusBack: _enableStatusBack,
    );
    
    return PrinterConfiguration(
      id: _editingPrinter?.id ?? '',
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      type: _selectedPrinterType,
      model: _selectedPrinterModel,
      ipAddress: _ipAddressController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 9100,
      bluetoothAddress: _bluetoothAddressController.text.trim(),
      macAddress: _macAddressController.text.trim(),
      isActive: true,
      thermalSettings: thermalSettings,
    );
  }
} 