import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/services/user_service.dart';
import 'package:ai_pos_system/widgets/user_profile_card.dart';
import 'package:ai_pos_system/screens/order_type_selection_screen.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<User> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final userService = Provider.of<UserService>(context, listen: false);
      final allUsers = await userService.getUsers();
      // Show all users, including admin
      setState(() {
        _users = allUsers;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Profile'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        automaticallyImplyLeading: false,
        actions: const [
          SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _users.isEmpty
                      ? _buildEmptyState()
                      : _buildUsersList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Users Available',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please contact your administrator to add users.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    // Group users by role
    final adminUsers = _users.where((user) => user.role == UserRole.admin).toList();
    final managerUsers = _users.where((user) => user.role == UserRole.manager).toList();
    final serverUsers = _users.where((user) => user.role == UserRole.server).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (adminUsers.isNotEmpty) ...[
          _buildRoleSection('Administrators', adminUsers, Icons.admin_panel_settings),
          const SizedBox(height: 24),
        ],
        if (managerUsers.isNotEmpty) ...[
          _buildRoleSection('Managers', managerUsers, Icons.manage_accounts),
          const SizedBox(height: 24),
        ],
        if (serverUsers.isNotEmpty) ...[
          _buildRoleSection('Servers', serverUsers, Icons.person),
        ],
      ],
    );
  }

  Widget _buildRoleSection(String title, List<User> users, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.2,
          ),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return UserProfileCard(
              user: user,
              onTap: () => _selectUser(user),
            );
          },
        ),
      ],
    );
  }

  void _selectUser(User user) async {
    try {
      // Set the selected user as current user in UserService
      final userService = Provider.of<UserService>(context, listen: false);
      userService.setCurrentUser(user);
      
      // Navigate to OrderTypeSelectionScreen without passing user parameter
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const OrderTypeSelectionScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
} 