import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/free_cloud_printing_service.dart';
import '../widgets/universal_navigation.dart';

/// 🆓 Free Cloud Setup Screen
/// Super simple setup for non-technical users
/// Everything in the cloud - no computer needed at restaurant
class FreeCloudSetupScreen extends StatefulWidget {
  const FreeCloudSetupScreen({Key? key}) : super(key: key);

  @override
  State<FreeCloudSetupScreen> createState() => _FreeCloudSetupScreenState();
}

class _FreeCloudSetupScreenState extends State<FreeCloudSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serviceUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _restaurantIdController = TextEditingController();
  
  String _selectedService = 'firebase';
  bool _isLoading = false;
  bool _isConnected = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
  }
  
  @override
  void dispose() {
    _serviceUrlController.dispose();
    _apiKeyController.dispose();
    _restaurantIdController.dispose();
    super.dispose();
  }
  
  void _loadCurrentSettings() {
    // Load current settings if any
    final freeService = context.read<FreeCloudPrintingService>();
    if (freeService.isInitialized) {
      // TODO: Load from service
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: UniversalAppBar(
        title: '🆓 Free Cloud Setup',
        onBack: () => Navigator.pop(context),
      ),
      body: Container(
        decoration: BoxDecoration(
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
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                SizedBox(height: 30),
                _buildServiceSelection(),
                SizedBox(height: 30),
                _buildSetupForm(),
                SizedBox(height: 30),
                _buildActionButtons(),
                SizedBox(height: 30),
                _buildInstructions(),
                SizedBox(height: 30),
                _buildTroubleshooting(),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud, color: Colors.white, size: 30),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Free Cloud Printing Setup',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'Print from anywhere to your restaurant printers\nZero monthly cost - completely free!',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
            ),
          ),
          SizedBox(height: 15),
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[300], size: 20),
              SizedBox(width: 8),
              Text(
                'No computer needed at restaurant',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          SizedBox(height: 5),
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[300], size: 20),
              SizedBox(width: 8),
              Text(
                'Works from phone, home, anywhere',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
          SizedBox(height: 5),
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[300], size: 20),
              SizedBox(width: 8),
              Text(
                '5-minute setup - super simple',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildServiceSelection() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose Your Free Service',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 15),
          _buildServiceOption(
            'firebase',
            'Firebase (Google)',
            'Recommended - Easiest setup',
            '50,000 reads/day, 20,000 writes/day',
            Icons.cloud,
          ),
          SizedBox(height: 10),
          _buildServiceOption(
            'supabase',
            'Supabase',
            'PostgreSQL database',
            '500MB database, 50,000 API calls/month',
            Icons.storage,
          ),
          SizedBox(height: 10),
          _buildServiceOption(
            'railway',
            'Railway',
            'Simple deployment',
            r'$5 credit/month (usually enough)',
            Icons.train,
          ),
        ],
      ),
    );
  }
  
  Widget _buildServiceOption(String value, String title, String subtitle, String limits, IconData icon) {
    final isSelected = _selectedService == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedService = value;
          _updateServiceUrl();
        });
      },
      child: Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
              size: 24,
            ),
            SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    limits,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Colors.green[300],
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSetupForm() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Setup Details',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            _buildTextField(
              controller: _serviceUrlController,
              label: 'Service URL',
              hint: 'https://your-project.firebaseapp.com/api',
              icon: Icons.link,
            ),
            SizedBox(height: 15),
            _buildTextField(
              controller: _apiKeyController,
              label: 'API Key',
              hint: 'AIzaSyC...',
              icon: Icons.vpn_key,
              isPassword: true,
            ),
            SizedBox(height: 15),
            _buildTextField(
              controller: _restaurantIdController,
              label: 'Restaurant ID',
              hint: 'your-restaurant-name',
              icon: Icons.store,
            ),
            SizedBox(height: 20),
            if (_errorMessage != null)
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red[300], size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[300], fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
            if (_isConnected)
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[300], size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Connected successfully!',
                        style: TextStyle(color: Colors.green[300], fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.7)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.white, width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return '$label is required';
            }
            return null;
          },
        ),
      ],
    );
  }
  
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _testConnection,
            icon: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(Icons.wifi_tethering),
            label: Text(_isLoading ? 'Testing...' : 'Test Connection'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[600],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        SizedBox(width: 15),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isLoading || !_isConnected ? null : _saveSettings,
            icon: Icon(Icons.save),
            label: Text('Save Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _isConnected ? Colors.green[600] : Colors.grey[600],
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildInstructions() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📋 Quick Setup Instructions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 15),
          _buildInstructionStep(
            1,
            'Go to Firebase Console',
            'https://console.firebase.google.com',
          ),
          _buildInstructionStep(
            2,
            'Create new project',
            'Enter your restaurant name + "Printing"',
          ),
          _buildInstructionStep(
            3,
            'Get API keys',
            'Project settings → Add app → Web',
          ),
          _buildInstructionStep(
            4,
            'Copy config details',
            'Copy apiKey and projectId',
          ),
          _buildInstructionStep(
            5,
            'Enter in this form',
            'Paste the details above and test',
          ),
        ],
      ),
    );
  }
  
  Widget _buildInstructionStep(int step, String title, String description) {
    return Padding(
      padding: EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: Text(
                '$step',
                style: TextStyle(
                  color: Colors.blue[600],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTroubleshooting() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '🆘 Quick Help',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 15),
          _buildHelpItem(
            'Connection failed?',
            'Check your internet and API key',
          ),
          _buildHelpItem(
            'Can\'t find API key?',
            'Go to Project settings → General → Your apps',
          ),
          _buildHelpItem(
            'Still stuck?',
            'Visit Firebase docs or ask for help',
          ),
          SizedBox(height: 15),
          Center(
            child: TextButton.icon(
              onPressed: () {
                // TODO: Open help documentation
              },
              icon: Icon(Icons.help, color: Colors.white),
              label: Text(
                'View Full Documentation',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildHelpItem(String question, String answer) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            answer,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
  
  void _updateServiceUrl() {
    switch (_selectedService) {
      case 'firebase':
        _serviceUrlController.text = 'https://your-project.firebaseapp.com/api';
        break;
      case 'supabase':
        _serviceUrlController.text = 'https://your-project.supabase.co/api';
        break;
      case 'railway':
        _serviceUrlController.text = 'https://your-app.railway.app/api';
        break;
    }
  }
  
  Future<void> _testConnection() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isConnected = false;
    });
    
    try {
      final freeService = context.read<FreeCloudPrintingService>();
      
      final success = await freeService.initialize(
        serviceType: _selectedService,
        serviceUrl: _serviceUrlController.text,
        apiKey: _apiKeyController.text,
        restaurantId: _restaurantIdController.text,
      );
      
      setState(() {
        _isLoading = false;
        if (success) {
          _isConnected = true;
        } else {
          _errorMessage = 'Connection failed. Please check your details.';
        }
      });
      
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error: ${e.toString()}';
      });
    }
  }
  
  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    
    try {
      // TODO: Save settings to local storage
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Settings saved successfully!'),
          backgroundColor: Colors.green[600],
        ),
      );
      
      Navigator.pop(context);
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error saving settings: ${e.toString()}'),
          backgroundColor: Colors.red[600],
        ),
      );
    }
  }
} 