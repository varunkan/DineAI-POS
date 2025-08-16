import 'package:flutter/material.dart';
import '../models/user.dart';
import '../widgets/back_button.dart';
import 'order_creation_screen.dart';

class TakeoutSetupScreen extends StatefulWidget {
  final User user;

  const TakeoutSetupScreen({super.key, required this.user});

  @override
  State<TakeoutSetupScreen> createState() => _TakeoutSetupScreenState();
}

class _TakeoutSetupScreenState extends State<TakeoutSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _pickupTimeController = TextEditingController();
  String _orderNumber = '';
  bool _isLoading = false;
  DateTime _selectedPickupTime = DateTime.now().add(const Duration(minutes: 15));

  @override
  void initState() {
    super.initState();
    _generateOrderNumber();
    _updatePickupTimeDisplay();
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _pickupTimeController.dispose();
    super.dispose();
  }

  void _generateOrderNumber() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    _orderNumber = 'TO-${timestamp.substring(timestamp.length - 6)}';
  }

  void _updatePickupTimeDisplay() {
    final timeString = '${_selectedPickupTime.hour.toString().padLeft(2, '0')}:${_selectedPickupTime.minute.toString().padLeft(2, '0')}';
    _pickupTimeController.text = timeString;
  }

  Future<void> _selectPickupTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedPickupTime),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteTextColor: Theme.of(context).primaryColor,
              hourMinuteColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              dialHandColor: Theme.of(context).primaryColor,
              dialBackgroundColor: Colors.grey.shade100,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedPickupTime = DateTime(
          DateTime.now().year,
          DateTime.now().month,
          DateTime.now().day,
          picked.hour,
          picked.minute,
        );
        _updatePickupTimeDisplay();
      });
    }
  }

  Future<void> _createTakeoutOrder() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Simulate processing time
      await Future.delayed(const Duration(milliseconds: 500));

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderCreationScreen(
            user: widget.user,
            orderNumber: _orderNumber,
            orderType: 'takeout',
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Takeout Setup'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: <Widget>[
          const CustomBackButton(),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress Indicator
            LinearProgressIndicator(
              value: 0.5,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            ),
            const SizedBox(height: 8),
            Text(
              'Step 2 of 4: Customer Info',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            // Title
            Text(
              'Customer Information',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Enter customer details and pickup time for the takeout order.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 32),

            // Order Number Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                children: [
                  Text(
                    'Order Number',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.green.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _orderNumber,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Customer Information Form
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _customerNameController,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                      hintText: 'Enter customer name',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter customer name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _customerPhoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                      hintText: 'Enter phone number',
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter phone number';
                      }
                      // Basic phone validation
                      if (value.length < 10) {
                        return 'Please enter a valid phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Pickup Time Selection
                  TextFormField(
                    controller: _pickupTimeController,
                    decoration: InputDecoration(
                      labelText: 'Pickup Time',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.access_time),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.schedule),
                        onPressed: _selectPickupTime,
                      ),
                    ),
                    enabled: false,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please select pickup time';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Quick Pickup Time Buttons
                  Text(
                    'Quick Pickup Times',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildQuickTimeButton('15 min', 15),
                      _buildQuickTimeButton('30 min', 30),
                      _buildQuickTimeButton('45 min', 45),
                      _buildQuickTimeButton('1 hour', 60),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Continue Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _createTakeoutOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Continue to Order',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickTimeButton(String label, int minutes) {
    final targetTime = DateTime.now().add(Duration(minutes: minutes));
    final isSelected = _selectedPickupTime.hour == targetTime.hour && 
                      _selectedPickupTime.minute == targetTime.minute;
    
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _selectedPickupTime = targetTime;
          _updatePickupTimeDisplay();
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade200,
        foregroundColor: isSelected ? Colors.white : Colors.black87,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Text(label),
    );
  }
} 