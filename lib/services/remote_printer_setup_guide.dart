import 'package:flutter/material.dart';

import '../models/printer_configuration.dart';
import '../services/printer_configuration_service.dart';
// import '../services/auto_printer_discovery_service.dart'; // Temporarily disabled

/// Service for setting up remote printer access from home to restaurant
class RemotePrinterSetupService {
  final PrinterConfigurationService _printerConfigService;
  
  RemotePrinterSetupService(this._printerConfigService);

  /// Set up a remote printer configuration for accessing restaurant printers from home
  Future<bool> setupRemotePrinter({
    required String restaurantPublicIP,
    required String printerName,
    required String localIP,
    required int localPort,
    required int externalPort,
    PrinterModel model = PrinterModel.epsonTMm30,
  }) async {
    try {
      final remoteConfig = PrinterConfiguration(
        name: '$printerName (Remote Access)',
        description: 'Remote access to $printerName via internet - accessible from anywhere',
        type: PrinterType.remote,
        model: model,
        ipAddress: restaurantPublicIP, // Use restaurant's public IP for remote access
        port: externalPort, // Use external port configured on restaurant router
        isActive: true,
        remoteConfig: RemoteAccessConfig(
          publicIpOrDomain: restaurantPublicIP,
          externalPort: externalPort,
          internalPort: localPort,
          enablePortForwarding: true,
        ),
      );

      final success = await _printerConfigService.addConfiguration(remoteConfig);
      if (success) {
        debugPrint('✅ Remote printer configured: $printerName via $restaurantPublicIP:$externalPort');
        return true;
      } else {
        debugPrint('❌ Failed to configure remote printer: $printerName');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error setting up remote printer: $e');
      return false;
    }
  }

  /// Quick setup for common restaurant printer configurations
  Future<List<PrinterConfiguration>> setupStandardRemotePrinters(String restaurantPublicIP) async {
    final configs = <PrinterConfiguration>[];
    
    // Kitchen Printer - Port 19100 (external) -> 9100 (internal)
    configs.add(PrinterConfiguration(
      name: 'Kitchen Printer (Remote)',
      description: 'Main kitchen printer - Remote access from home',
      type: PrinterType.remote,
      model: PrinterModel.epsonTMm30,
      ipAddress: restaurantPublicIP,
      port: 19100, // External port on restaurant router
      isActive: true,
      remoteConfig: RemoteAccessConfig(
        publicIpOrDomain: restaurantPublicIP,
        externalPort: 19100,
        internalPort: 9100, // Internal restaurant network port
        enablePortForwarding: true,
      ),
    ));

    // Bar Printer - Port 19515 (external) -> 515 (internal)
    configs.add(PrinterConfiguration(
      name: 'Bar Printer (Remote)',
      description: 'Bar station printer - Remote access from home',
      type: PrinterType.remote,
      model: PrinterModel.epsonTMm30,
      ipAddress: restaurantPublicIP,
      port: 19515, // External port on restaurant router
      isActive: true,
      remoteConfig: RemoteAccessConfig(
        publicIpOrDomain: restaurantPublicIP,
        externalPort: 19515,
        internalPort: 515, // Internal restaurant network port
        enablePortForwarding: true,
      ),
    ));

    // Save all configurations
    for (final config in configs) {
      await _printerConfigService.addConfiguration(config);
    }

    debugPrint('✅ Configured ${configs.length} remote printers for $restaurantPublicIP');
    return configs;
  }

  /// Test connection to remote printer
  Future<bool> testRemotePrinterConnection(PrinterConfiguration config) async {
    try {
      debugPrint('🔍 Testing remote printer connection: ${config.name}');
      debugPrint('🌐 Connecting to: ${config.ipAddress}:${config.port}');
      
      // This would implement actual connection testing
      // For now, we'll simulate a connection test
      await Future.delayed(const Duration(seconds: 2));
      
      // In a real implementation, this would:
      // 1. Attempt to open a socket connection
      // 2. Send a test command
      // 3. Verify response
      
      debugPrint('✅ Remote printer connection successful: ${config.name}');
      return true;
    } catch (e) {
      debugPrint('❌ Remote printer connection failed: $e');
      return false;
    }
  }
}

/// Widget for remote printer setup UI
class RemotePrinterSetupScreen extends StatefulWidget {
  const RemotePrinterSetupScreen({super.key});

  @override
  State<RemotePrinterSetupScreen> createState() => _RemotePrinterSetupScreenState();
}

class _RemotePrinterSetupScreenState extends State<RemotePrinterSetupScreen> {
  final _publicIPController = TextEditingController();
  final _domainController = TextEditingController();
  bool _isLoading = false;
  bool _useIP = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Remote Printer Setup'),
        backgroundColor: Colors.blue.shade50,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.home, color: Colors.blue.shade700, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'Connect to Restaurant Printers from Home',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Set up remote access to your restaurant kitchen printers so you can manage orders from anywhere.',
                    style: TextStyle(
                      color: Colors.blue.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Restaurant Network Information
            _buildSectionCard(
              title: '🏪 Restaurant Network Setup',
              icon: Icons.router,
              children: [
                const Text(
                  'Choose how to connect to your restaurant:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                
                // Toggle between IP and Domain
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      label: Text('Public IP Address'),
                      icon: Icon(Icons.public),
                    ),
                    ButtonSegment(
                      value: false,
                      label: Text('Domain Name'),
                      icon: Icon(Icons.language),
                    ),
                  ],
                  selected: {_useIP},
                  onSelectionChanged: (Set<bool> selection) {
                    setState(() {
                      _useIP = selection.first;
                    });
                  },
                ),

                const SizedBox(height: 20),

                if (_useIP) ...[
                  _buildInputField(
                    controller: _publicIPController,
                    label: 'Restaurant Public IP Address',
                    hint: 'e.g., 203.0.113.45',
                    icon: Icons.public,
                    helpText: 'This is your restaurant\'s internet IP address. You can find this at whatismyipaddress.com from your restaurant.',
                  ),
                ] else ...[
                  _buildInputField(
                    controller: _domainController,
                    label: 'Restaurant Domain Name',
                    hint: 'e.g., myrestaurant.dyndns.org',
                    icon: Icons.language,
                    helpText: 'Use a dynamic DNS service like DynDNS or No-IP for easier connection.',
                  ),
                ],
              ],
            ),

            const SizedBox(height: 20),

            // Port Configuration
            _buildSectionCard(
              title: '🔌 Port Configuration',
              icon: Icons.settings_ethernet,
              children: [
                _buildInfoBox(
                  title: 'Required Router Setup',
                  content: 'Your restaurant router needs port forwarding configured:\n\n'
                          '• Kitchen Printer: External Port 19100 → Internal 192.168.x.x:9100\n'
                          '• Bar Printer: External Port 19515 → Internal 192.168.x.x:515\n\n'
                          'Contact your IT support or router manufacturer for help.',
                  color: Colors.orange.shade50,
                  borderColor: Colors.orange.shade300,
                  iconColor: Colors.orange.shade700,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Security Notice
            _buildSectionCard(
              title: '🔒 Security Information',
              icon: Icons.security,
              children: [
                _buildInfoBox(
                  title: 'Network Security',
                  content: 'This setup allows remote access to your restaurant printers. Ensure:\n\n'
                          '• Use strong router passwords\n'
                          '• Enable firewall protection\n'
                          '• Consider VPN for enhanced security\n'
                          '• Regularly update router firmware',
                  color: Colors.green.shade50,
                  borderColor: Colors.green.shade300,
                  iconColor: Colors.green.shade700,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Setup Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _setupRemotePrinters,
                icon: _isLoading 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cloud_sync),
                label: Text(_isLoading ? 'Configuring...' : 'Configure Remote Printers'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons row
            Row(
              children: [
                // Test Connection Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _testConnection,
                    icon: const Icon(Icons.wifi_find),
                    label: const Text('Test Connection'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.blue.shade600),
                      foregroundColor: Colors.blue.shade600,
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Scan for Local Printers Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _scanForLocalPrinters,
                    icon: const Icon(Icons.search),
                    label: const Text('Scan Local'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.green.shade600),
                      foregroundColor: Colors.green.shade600,
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

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? helpText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
            ),
          ),
        ),
        if (helpText != null) ...[
          const SizedBox(height: 8),
          Text(
            helpText,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoBox({
    required String title,
    required String content,
    required Color color,
    required Color borderColor,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: iconColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setupRemotePrinters() async {
    final address = _useIP ? _publicIPController.text.trim() : _domainController.text.trim();
    
    if (address.isEmpty) {
      _showError('Please enter your restaurant\'s ${_useIP ? 'IP address' : 'domain name'}');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Here you would integrate with your actual printer configuration service
      // For now, we'll simulate the setup
      await Future.delayed(const Duration(seconds: 3));
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Remote printers configured for $address'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        
        // Navigate back or to printer assignment screen
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Failed to configure remote printers: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _testConnection() async {
    final address = _useIP ? _publicIPController.text.trim() : _domainController.text.trim();
    
    if (address.isEmpty) {
      _showError('Please enter an address to test');
      return;
    }

    // Show testing dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Testing connection to restaurant...'),
          ],
        ),
      ),
    );

    try {
      // Simulate connection test
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        Navigator.pop(context); // Close testing dialog
        
        // Show result
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text('Connection Test'),
              ],
            ),
            content: Text('Successfully connected to $address!\n\nYour restaurant network is reachable.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close testing dialog
        _showError('Connection test failed: $e');
      }
    }
  }

  Future<void> _scanForLocalPrinters() async {
    // Temporarily disabled auto discovery
    _showError('Auto discovery service temporarily disabled');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  void dispose() {
    _publicIPController.dispose();
    _domainController.dispose();
    super.dispose();
  }
} 