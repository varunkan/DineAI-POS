import 'package:flutter/material.dart';
import '../services/unified_sync_service.dart';
import '../services/tenant_service.dart';

class TenantSetupScreen extends StatefulWidget {
  const TenantSetupScreen({Key? key}) : super(key: key);

  @override
  State<TenantSetupScreen> createState() => _TenantSetupScreenState();
}

class _TenantSetupScreenState extends State<TenantSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _restaurantNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  
  bool _isLoading = false;
  bool _isExistingTenant = false;
  String? _selectedTenantId;
  List<Tenant> _availableTenants = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableTenants();
  }

  @override
  void dispose() {
    _restaurantNameController.dispose();
    _ownerNameController.dispose();
    _ownerEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableTenants() async {
    try {
      // For now, just set empty list since getAllTenants method doesn't exist
      setState(() {
        _availableTenants = [];
      });
    } catch (e) {
    }
  }

  Future<void> _createNewTenant() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final tenant = Tenant(
        id: '', // Will be set by the service
        name: _ownerNameController.text,
        restaurantName: _restaurantNameController.text,
        ownerEmail: _ownerEmailController.text,
        createdAt: DateTime.now(),
      );

      final tenantId = await TenantService.instance.createTenant(tenant);
      await TenantService.instance.setCurrentTenant(tenantId);
      
      // Clear and sync data for the new tenant
      final syncService = UnifiedSyncService.instance;
      await syncService.forceSyncAllLocalData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Restaurant setup completed!'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _selectExistingTenant() async {
    if (_selectedTenantId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await TenantService.instance.setCurrentTenant(_selectedTenantId!);
      
      // Force sync data from Firebase
      final syncService = UnifiedSyncService.instance;
      await syncService.triggerImmediateSync();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Restaurant connected successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAndSyncData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await TenantService.instance.setCurrentTenant(_selectedTenantId!);
      final syncService = UnifiedSyncService.instance;
      await syncService.forceSyncAllLocalData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Data cleared and synced successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Setup'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      Icons.restaurant,
                      size: 64,
                      color: Colors.orange,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Restaurant Setup',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Configure your restaurant for multi-device sync',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Toggle between new and existing
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _isExistingTenant = false;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isExistingTenant ? Colors.grey : Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('New Restaurant'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _isExistingTenant = true;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isExistingTenant ? Colors.orange : Colors.grey,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Existing Restaurant'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Form based on selection
            if (_isExistingTenant) ...[
              // Existing tenant selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select Existing Restaurant',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      if (_availableTenants.isEmpty)
                        const Text('No restaurants found. Create a new one.')
                      else ...[
                        DropdownButtonFormField<String>(
                          value: _selectedTenantId,
                          decoration: const InputDecoration(
                            labelText: 'Select Restaurant',
                            border: OutlineInputBorder(),
                          ),
                          items: _availableTenants.map((tenant) {
                            return DropdownMenuItem(
                              value: tenant.id,
                              child: Text(tenant.restaurantName),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedTenantId = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _selectedTenantId != null ? _selectExistingTenant : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('Connect to Restaurant'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ] else ...[
              // New tenant creation
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Create New Restaurant',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _restaurantNameController,
                          decoration: const InputDecoration(
                            labelText: 'Restaurant Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.restaurant),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter restaurant name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _ownerNameController,
                          decoration: const InputDecoration(
                            labelText: 'Owner Name',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter owner name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        TextFormField(
                          controller: _ownerEmailController,
                          decoration: const InputDecoration(
                            labelText: 'Owner Email',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _createNewTenant,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isLoading
                                ? const CircularProgressIndicator(color: Colors.white)
                                : const Text('Create Restaurant'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Data management section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Data Management',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    const Text(
                      'Clear all data and sync from Firebase. This will reset all orders, menu items, and settings.',
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _clearAndSyncData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Clear & Sync Data'),
                      ),
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