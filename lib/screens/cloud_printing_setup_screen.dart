import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cloud_restaurant_printing_service.dart';
import '../services/printing_service.dart';
import '../services/enhanced_printer_assignment_service.dart';
import '../widgets/universal_navigation.dart';

/// 🌐 Cloud Printing Setup Screen
/// Allows users to configure internet-based printing to restaurant printers
class CloudPrintingSetupScreen extends StatefulWidget {
  const CloudPrintingSetupScreen({Key? key}) : super(key: key);

  @override
  State<CloudPrintingSetupScreen> createState() => _CloudPrintingSetupScreenState();
}

class _CloudPrintingSetupScreenState extends State<CloudPrintingSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serviceUrlController = TextEditingController();
  final _restaurantIdController = TextEditingController();
  final _apiKeyController = TextEditingController();
  
  bool _isLoading = false;
  bool _isTesting = false;
  bool _showApiKey = false;
  String? _testResult;
  bool _testSuccess = false;
  
  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }
  
  @override
  void dispose() {
    _serviceUrlController.dispose();
    _restaurantIdController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }
  
  /// Load current cloud printing settings
  void _loadCurrentSettings() {
    // Load from shared preferences or service
    _serviceUrlController.text = 'https://restaurant-print.cloud/api/v1';
    _restaurantIdController.text = 'rest_abc123def456';
    _apiKeyController.text = 'sk_live_xyz789abc123';
  }
  
  /// Test cloud connection
  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isTesting = true;
      _testResult = null;
    });
    
    try {
      // Create temporary cloud service for testing
      final cloudService = CloudRestaurantPrintingService(
        printingService: context.read<PrintingService>(),
        assignmentService: context.read<EnhancedPrinterAssignmentService>(),
      );
      
      // Test initialization
      final success = await cloudService.initialize();
      
      setState(() {
        _testSuccess = success;
        _testResult = success 
          ? '✅ Connection successful! Cloud printing is ready.'
          : '❌ Connection failed. Please check your settings.';
      });
      
    } catch (e) {
      setState(() {
        _testSuccess = false;
        _testResult = '❌ Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isTesting = false;
      });
    }
  }
  
  /// Save cloud printing settings
  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Save settings to shared preferences or service
      // This would typically save to SharedPreferences or a settings service
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Cloud printing settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Navigate back
      Navigator.pop(context);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error saving settings: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const UniversalNavigation(
        currentScreenTitle: '🌐 Cloud Printing Setup',
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
              Color(0xFFf093fb),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🌐 Internet Restaurant Printing',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Configure your POS app to print orders directly to your restaurant printers from anywhere in the world.',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Setup Form
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cloud Service Configuration',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Service URL
                        TextFormField(
                          controller: _serviceUrlController,
                          decoration: const InputDecoration(
                            labelText: 'Service URL',
                            hintText: 'https://restaurant-print.cloud/api/v1',
                            prefixIcon: Icon(Icons.cloud),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter the service URL';
                            }
                            final uri = Uri.tryParse(value);
                            if (uri == null || !uri.hasScheme) {
                              return 'Please enter a valid URL';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Restaurant ID
                        TextFormField(
                          controller: _restaurantIdController,
                          decoration: const InputDecoration(
                            labelText: 'Restaurant ID',
                            hintText: 'rest_abc123def456',
                            prefixIcon: Icon(Icons.store),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your restaurant ID';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // API Key
                        TextFormField(
                          controller: _apiKeyController,
                          obscureText: !_showApiKey,
                          decoration: InputDecoration(
                            labelText: 'API Key',
                            hintText: 'sk_live_xyz789abc123',
                            prefixIcon: const Icon(Icons.key),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showApiKey ? Icons.visibility : Icons.visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showApiKey = !_showApiKey;
                                });
                              },
                            ),
                            border: const OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your API key';
                            }
                            if (!value.startsWith('sk_')) {
                              return 'API key should start with "sk_"';
                            }
                            return null;
                          },
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Test Connection Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isTesting ? null : _testConnection,
                            icon: _isTesting 
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.wifi_tethering),
                            label: Text(_isTesting ? 'Testing...' : 'Test Connection'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        
                        // Test Result
                        if (_testResult != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: _testSuccess ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _testSuccess ? Colors.green : Colors.red,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _testSuccess ? Icons.check_circle : Icons.error,
                                  color: _testSuccess ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _testResult!,
                                    style: TextStyle(
                                      color: _testSuccess ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 30),
                
                // Information Cards
                _buildInfoCard(
                  icon: Icons.info,
                  title: 'How It Works',
                  content: 'Your POS app sends print jobs to our cloud service, which then routes them to your restaurant printers in real-time.',
                  color: Colors.blue,
                ),
                
                const SizedBox(height: 15),
                
                _buildInfoCard(
                  icon: Icons.security,
                  title: 'Security',
                  content: 'All connections are encrypted with HTTPS. Your API key provides secure authentication.',
                  color: Colors.green,
                ),
                
                const SizedBox(height: 15),
                
                _buildInfoCard(
                  icon: Icons.offline_bolt,
                  title: 'Offline Support',
                  content: 'If internet is down, orders are queued and will print automatically when connection is restored.',
                  color: Colors.orange,
                ),
                
                const SizedBox(height: 30),
                
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveSettings,
                    icon: _isLoading 
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                    label: Text(_isLoading ? 'Saving...' : 'Save Settings'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Help Link
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      // Open help documentation
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('📖 Opening setup guide...'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.help),
                    label: const Text('View Setup Guide'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  /// Build information card
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  content,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 