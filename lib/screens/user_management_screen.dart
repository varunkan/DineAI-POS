import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user.dart';
import '../services/user_service.dart';


class UserManagementScreen extends StatefulWidget {
  final User currentUser;

  const UserManagementScreen({super.key, required this.currentUser});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  bool _isLoading = false;
  bool _showAddUserForm = false;
  
  // Form controllers for adding new users
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  UserRole _selectedRole = UserRole.server;
  bool _grantAdminAccess = false;

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              setState(() {
                _showAddUserForm = !_showAddUserForm;
              });
            },
            tooltip: 'Add New User',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue[50]!, Colors.blue[100]!],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.people, size: 32, color: Colors.blue[800]),
                    const SizedBox(width: 12),
                    Text(
                      'Manage User Permissions',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Grant or revoke admin panel access for restaurant staff',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blue[600],
                  ),
                ),
              ],
            ),
          ),

          // Add User Form Section
          if (_showAddUserForm)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _buildAddUserForm(),
            ),

          // Users List Section
          Expanded(
            child: Consumer<UserService>(
              builder: (context, userService, _) {
                final users = userService.users;
                
                if (users.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No users found',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    return _buildUserCard(user);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(User user) {
    final hasAdminAccess = user.canAccessAdminPanel;
    final isCurrentUser = user.id == widget.currentUser.id;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // User Avatar
            CircleAvatar(
              radius: 25,
              backgroundColor: _getRoleColor(user.role),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
            const SizedBox(width: 16),
            
            // User Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'YOU',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _buildRoleBadge(user.role),
                      const SizedBox(width: 8),
                      Text(
                        'ID: ${user.id}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        hasAdminAccess ? Icons.admin_panel_settings : Icons.person,
                        size: 16,
                        color: hasAdminAccess ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasAdminAccess ? 'Admin Panel Access: GRANTED' : 'Admin Panel Access: DENIED',
                        style: TextStyle(
                          fontSize: 14,
                          color: hasAdminAccess ? Colors.green : Colors.grey[600],
                          fontWeight: hasAdminAccess ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Admin Access Toggle
            Column(
              children: [
                if (!isCurrentUser) ...[
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : () => _toggleAdminAccess(user),
                    icon: Icon(
                      hasAdminAccess ? Icons.lock : Icons.lock_open,
                      size: 16,
                    ),
                    label: Text(hasAdminAccess ? 'Revoke' : 'Grant'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasAdminAccess ? Colors.red : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Current User',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleBadge(UserRole role) {
    Color color;
    String label;
    
    switch (role) {
      case UserRole.admin:
        color = Colors.red;
        label = 'ADMIN';
        break;
      case UserRole.manager:
        color = Colors.orange;
        label = 'MANAGER';
        break;
      case UserRole.server:
        color = Colors.blue;
        label = 'SERVER';
        break;
      case UserRole.cashier:
        color = Colors.green;
        label = 'CASHIER';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Colors.red;
      case UserRole.manager:
        return Colors.orange;
      case UserRole.server:
        return Colors.blue;
      case UserRole.cashier:
        return Colors.green;
    }
  }

  Future<void> _toggleAdminAccess(User user) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userService = Provider.of<UserService>(context, listen: false);
      bool success;
      
      if (user.canAccessAdminPanel) {
        success = await userService.revokeAdminPanelAccess(user.id);
      } else {
        success = await userService.grantAdminPanelAccess(user.id);
      }

      if (success && mounted) {
        final action = user.canAccessAdminPanel ? 'revoked from' : 'granted to';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Admin panel access ${action} ${user.name}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Failed to update user permissions'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildAddUserForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_add, color: Colors.blue[800]),
              const SizedBox(width: 8),
              Text(
                'Add New User',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _showAddUserForm = false;
                  });
                  _clearForm();
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Name Field
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Full Name',
              hintText: 'Enter user\'s full name',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a name';
              }
              if (value.trim().length < 2) {
                return 'Name must be at least 2 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // PIN Field
          TextFormField(
            controller: _pinController,
            decoration: const InputDecoration(
              labelText: 'PIN',
              hintText: 'Enter 4-digit PIN',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
            keyboardType: TextInputType.number,
            maxLength: 4,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a PIN';
              }
              if (value.length != 4) {
                return 'PIN must be exactly 4 digits';
              }
              if (!RegExp(r'^\d{4}$').hasMatch(value)) {
                return 'PIN must contain only numbers';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          
          // Role Selection
          DropdownButtonFormField<UserRole>(
            value: _selectedRole,
            decoration: const InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.work),
            ),
            items: UserRole.values.map((role) {
              return DropdownMenuItem(
                value: role,
                child: Text(role.name.toUpperCase()),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedRole = value;
                  // Auto-grant admin access for admin role
                  if (value == UserRole.admin) {
                    _grantAdminAccess = true;
                  }
                });
              }
            },
          ),
          const SizedBox(height: 16),
          
          // Admin Access Toggle
          Row(
            children: [
              Checkbox(
                value: _grantAdminAccess,
                onChanged: (value) {
                  setState(() {
                    _grantAdminAccess = value ?? false;
                  });
                },
              ),
              const Text('Grant Admin Panel Access'),
              const Spacer(),
              Icon(
                Icons.admin_panel_settings,
                color: _grantAdminAccess ? Colors.green : Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _cancelAddUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _addUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Add User'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _clearForm() {
    _nameController.clear();
    _pinController.clear();
    _selectedRole = UserRole.server;
    _grantAdminAccess = false;
  }

  void _cancelAddUser() {
    setState(() {
      _showAddUserForm = false;
    });
    _clearForm();
  }

  Future<void> _addUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final userService = Provider.of<UserService>(context, listen: false);
      
      // Check if PIN is already in use
      final existingUsers = await userService.getUsers();
      final pinExists = existingUsers.any((user) => user.pin == _pinController.text.trim());
      
      if (pinExists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ PIN already in use. Please choose a different PIN.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Create new user
      final newUser = User(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        pin: _pinController.text.trim(),
        role: _selectedRole,
        adminPanelAccess: _grantAdminAccess,
      );

      await userService.addUser(newUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ User ${newUser.name} added successfully'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Clear form and hide it
        _clearForm();
        setState(() {
          _showAddUserForm = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error adding user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
} 