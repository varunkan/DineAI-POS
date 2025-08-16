import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../services/tenant_service.dart';
import '../services/multi_tenant_auth_service.dart';
import '../services/unified_sync_service.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/error_dialog.dart';
import '../widgets/confirmation_dialog.dart';

class TenantManagementScreen extends StatefulWidget {
  final User user;
  final bool showAppBar;

  const TenantManagementScreen({
    Key? key,
    required this.user,
    this.showAppBar = true,
  }) : super(key: key);

  @override
  State<TenantManagementScreen> createState() => _TenantManagementScreenState();
}

class _TenantManagementScreenState extends State<TenantManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _restaurantNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _ownerEmailController = TextEditingController();
  
  bool _isLoading = false;
  bool _isExistingTenant = false;
  String? _selectedTenantId;
  List<Tenant> _existingTenants = [];
  Tenant? _currentTenant;

  @override
  void initState() {
    super.initState();
    _loadCurrentTenant();
    _loadExistingTenants();
  }

  @override
  void dispose() {
    _restaurantNameController.dispose();
    _ownerNameController.dispose();
    _ownerEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentTenant() async {
    try {
      final tenantService = Provider.of<TenantService>(context, listen: false);
      final currentTenant = await tenantService.getCurrentTenant();
      setState(() {
        _currentTenant = currentTenant;
        if (currentTenant != null) {
          _restaurantNameController.text = currentTenant.restaurantName;
          _ownerNameController.text = currentTenant.name;
          _ownerEmailController.text = currentTenant.ownerEmail;
        }
      });
    } catch (e) {
      debugPrint('Error loading current tenant: $e');
    }
  }

  Future<void> _loadExistingTenants() async {
    try {
      final tenantService = Provider.of<TenantService>(context, listen: false);
      final tenants = await tenantService.getTenants();
      setState(() {
        _existingTenants = tenants;
      });
    } catch (e) {
      debugPrint('Error loading existing tenants: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar ? AppBar(
        title: const Text('Tenant Management'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ) : null,
      body: LoadingOverlay(
        isLoading: _isLoading,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildCurrentTenantInfo(),
              const SizedBox(height: 24),
              _buildTenantSetupForm(),
              const SizedBox(height: 24),
              _buildDataSyncSection(),
              const SizedBox(height: 24),
              _buildExistingTenantsSection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, size: 32, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Restaurant Tenant Management',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Configure your restaurant and manage multi-device sync',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentTenantInfo() {
    if (_currentTenant == null) {
      return Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'No tenant configured. Please set up your restaurant tenant to enable multi-device sync.',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                const SizedBox(width: 12),
                const Text(
                  'Current Tenant',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Restaurant', _currentTenant!.restaurantName),
            _buildInfoRow('Owner', _currentTenant!.name),
            _buildInfoRow('Email', _currentTenant!.ownerEmail),
            _buildInfoRow('Tenant ID', _currentTenant!.id),
            _buildInfoRow('Status', _currentTenant!.isActive ? 'Active' : 'Inactive'),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantSetupForm() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.settings, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 12),
                  const Text(
                    'Tenant Configuration',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter owner email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _saveTenant,
                      icon: const Icon(Icons.save),
                      label: const Text('Save Tenant'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _clearForm,
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataSyncSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sync, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                const Text(
                  'Data Synchronization',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Manage data synchronization between devices. This will ensure all devices have the same data.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _syncDataFromCloud,
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('Sync from Cloud'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _clearAndSyncData,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Clear & Sync'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _uploadDataToCloud,
                icon: const Icon(Icons.cloud_upload),
                label: const Text('Upload Data to Cloud'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExistingTenantsSection() {
    if (_existingTenants.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.list, color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                const Text(
                  'Available Tenants',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _existingTenants.length,
              itemBuilder: (context, index) {
                final tenant = _existingTenants[index];
                return ListTile(
                  leading: Icon(
                    tenant.isActive ? Icons.check_circle : Icons.cancel,
                    color: tenant.isActive ? Colors.green : Colors.red,
                  ),
                  title: Text(tenant.restaurantName),
                  subtitle: Text('${tenant.name} - ${tenant.ownerEmail}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (tenant.id == _currentTenant?.id)
                        const Chip(
                          label: Text('Current'),
                          backgroundColor: Colors.green,
                          labelStyle: TextStyle(color: Colors.white),
                        ),
                      IconButton(
                        icon: const Icon(Icons.swap_horiz),
                        onPressed: () => _switchToTenant(tenant),
                        tooltip: 'Switch to this tenant',
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTenant() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final tenantService = Provider.of<TenantService>(context, listen: false);
      
      if (_currentTenant != null) {
        // Update existing tenant
        final updatedTenant = Tenant(
          id: _currentTenant!.id,
          name: _ownerNameController.text,
          restaurantName: _restaurantNameController.text,
          ownerEmail: _ownerEmailController.text,
          createdAt: _currentTenant!.createdAt,
          isActive: true,
          settings: _currentTenant!.settings,
        );
        
        await tenantService.updateTenant(updatedTenant);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tenant updated successfully')),
        );
      } else {
        // Create new tenant
        final tenant = Tenant(
          id: '',
          name: _ownerNameController.text,
          restaurantName: _restaurantNameController.text,
          ownerEmail: _ownerEmailController.text,
          createdAt: DateTime.now(),
        );
        
        final newTenantId = await tenantService.createTenant(tenant);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tenant created successfully')),
        );
      }
      
      await _loadCurrentTenant();
      await _loadExistingTenants();
    } catch (e) {
      await ErrorDialogHelper.showError(
        context,
        title: 'Error saving tenant',
        message: e.toString(),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearForm() async {
    _formKey.currentState?.reset();
    _restaurantNameController.clear();
    _ownerNameController.clear();
    _ownerEmailController.clear();
  }

  Future<void> _syncDataFromCloud() async {
    final confirmed = await ConfirmationDialogHelper.showConfirmation(
      context,
      title: 'Sync from Cloud',
      message: 'This will download all data from Firebase and sync it with your local database. Continue?',
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final dataSyncService = Provider.of<UnifiedSyncService>(context, listen: false);
      await dataSyncService.downloadFromCloud();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data synced from cloud successfully')),
      );
    } catch (e) {
      await ErrorDialogHelper.showError(
        context,
        title: 'Error syncing data',
        message: e.toString(),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _clearAndSyncData() async {
    final confirmed = await ConfirmationDialogHelper.showConfirmation(
      context,
      title: 'Clear and Sync Data',
      message: 'This will clear all local data and download fresh data from Firebase. This action cannot be undone. Continue?',
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final dataSyncService = Provider.of<UnifiedSyncService>(context, listen: false);
      await dataSyncService.clearAndSyncData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data cleared and synced successfully')),
      );
    } catch (e) {
      await ErrorDialogHelper.showError(
        context,
        title: 'Error clearing and syncing data',
        message: e.toString(),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _uploadDataToCloud() async {
    final confirmed = await ConfirmationDialogHelper.showConfirmation(
      context,
      title: 'Upload to Cloud',
      message: 'This will upload all local data to Firebase. Continue?',
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final dataSyncService = Provider.of<UnifiedSyncService>(context, listen: false);
      await dataSyncService.uploadToCloud();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data uploaded to cloud successfully')),
      );
    } catch (e) {
      await ErrorDialogHelper.showError(
        context,
        title: 'Error uploading data',
        message: e.toString(),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _switchToTenant(Tenant tenant) async {
    final confirmed = await ConfirmationDialogHelper.showConfirmation(
      context,
      title: 'Switch Tenant',
      message: 'Switch to ${tenant.restaurantName}? This will change the current tenant and may affect data sync.',
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final tenantService = Provider.of<TenantService>(context, listen: false);
      await tenantService.setCurrentTenant(tenant.id);
      
      await _loadCurrentTenant();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Switched to ${tenant.restaurantName}')),
      );
    } catch (e) {
      await ErrorDialogHelper.showError(
        context,
        title: 'Error switching tenant',
        message: e.toString(),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
} 