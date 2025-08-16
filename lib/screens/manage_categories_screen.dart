import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ai_pos_system/models/category.dart' as pos_category;
import 'package:ai_pos_system/models/user.dart';
import 'package:ai_pos_system/services/menu_service.dart';
import 'package:ai_pos_system/widgets/loading_overlay.dart';
import 'package:ai_pos_system/widgets/back_button.dart';
import 'package:ai_pos_system/widgets/error_dialog.dart';
import 'package:ai_pos_system/widgets/confirmation_dialog.dart';
import '../widgets/form_field.dart';

class ManageCategoriesScreen extends StatefulWidget {
  final User user;

  const ManageCategoriesScreen({super.key, required this.user});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  List<pos_category.Category> _categories = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final menuService = Provider.of<MenuService>(context, listen: false);
      final categories = await menuService.getCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error loading categories: $e';
      });
    }
  }

  Future<void> _editCategory(pos_category.Category category) async {
    final TextEditingController nameController = TextEditingController(text: category.name);
    final TextEditingController descriptionController = TextEditingController(text: category.description ?? '');

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Category'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppFormField(
              label: 'Category Name',
              hint: 'Enter category name',
              controller: nameController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Category name is required';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            AppFormField(
              label: 'Description',
              hint: 'Enter description (optional)',
              controller: descriptionController,
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.of(context).pop({
                  'name': nameController.text.trim(),
                  'description': descriptionController.text.trim(),
                });
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        final menuService = Provider.of<MenuService>(context, listen: false);
        final updatedCategory = category.copyWith(
          name: result['name']!,
          description: result['description']!.isEmpty ? null : result['description'],
        );
        await menuService.saveCategory(updatedCategory);
        await _loadCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Category updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
          _error = 'Error updating category: $e';
        });
        if (mounted) {
          await ErrorDialogHelper.showError(
            context,
            title: 'Error Updating Category',
            message: 'Failed to update category: $e',
          );
        }
      }
    }
  }

  Future<void> _deleteCategory(pos_category.Category category) async {
    final confirmed = await ConfirmationDialogHelper.showDeleteConfirmation(
      context,
      itemName: category.name,
      message: 'Are you sure you want to delete "${category.name}"? This action cannot be undone.',
    );

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      try {
        final menuService = Provider.of<MenuService>(context, listen: false);
        await menuService.deleteCategory(category.id);
        await _loadCategories();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Category deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
          _error = 'Error deleting category: $e';
        });
        if (mounted) {
          await ErrorDialogHelper.showError(
            context,
            title: 'Error Deleting Category',
            message: 'Failed to delete category: $e',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Categories'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadCategories,
              tooltip: 'Refresh',
            ),
            const SizedBox(width: 8),
            const CustomBackButton(),
            const SizedBox(width: 16),
          ],
        ),
        body: _error != null
            ? _buildErrorState(_error!)
            : _buildCategoriesList(),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            'Error loading categories',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.red.shade700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadCategories,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesList() {
    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.category, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'No categories found',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add some categories to get started!',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade500,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColor,
              child: Text(
                category.name[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              category.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            subtitle: category.description != null && category.description!.isNotEmpty
                ? Text(
                    category.description!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _editCategory(category),
                  tooltip: 'Edit category',
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteCategory(category),
                  tooltip: 'Delete category',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
} 