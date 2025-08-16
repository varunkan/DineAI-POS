import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/menu_item.dart';
import '../models/category.dart' as pos_category;
import '../services/menu_service.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/error_dialog.dart';
import '../widgets/form_field.dart';
import '../widgets/back_button.dart';

class AddMenuItemScreen extends StatefulWidget {
  const AddMenuItemScreen({super.key});

  @override
  State<AddMenuItemScreen> createState() => _AddMenuItemScreenState();
}

class _AddMenuItemScreenState extends State<AddMenuItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  List<pos_category.Category> _categories = [];
  pos_category.Category? _selectedCategory;
  bool _isLoading = false;
  bool _isSaving = false;
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

  Future<void> _saveMenuItem() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _formKey.currentState!.save();
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final menuService = Provider.of<MenuService>(context, listen: false);
      final newItem = MenuItem(
        name: _nameController.text,
        description: _descriptionController.text,
        price: double.parse(_priceController.text),
        categoryId: _selectedCategory!.id,
      );
      await menuService.addMenuItem(newItem);
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Menu item added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _error = 'Error saving menu item: $e';
      });
      if (mounted) {
        await ErrorDialogHelper.showError(
          context,
          title: 'Error Saving Menu Item',
          message: 'Failed to save menu item: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add Menu Item'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: <Widget>[
            const CustomBackButton(),
            const SizedBox(width: 16),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveMenuItem,
            ),
            IconButton(
              icon: const Icon(Icons.cancel),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        body: _error != null
            ? _buildErrorState(_error!)
            : Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      AppFormField(
                        label: 'Item Name',
                        hint: 'Enter item name',
                        controller: _nameController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Item name is required';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      PriceFormField(
                        label: 'Price',
                        hint: 'Enter price',
                        controller: _priceController,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Price is required';
                          }
                          final price = double.tryParse(value);
                          if (price == null || price < 0) {
                            return 'Please enter a valid price';
                          }
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      AppFormField(
                        label: 'Description',
                        hint: 'Enter description (optional)',
                        controller: _descriptionController,
                        maxLines: 3,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<pos_category.Category>(
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        value: _selectedCategory,
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category.name),
                          );
                        }).toList(),
                        onChanged: (category) => setState(() => _selectedCategory = category),
                        validator: (value) => value == null ? 'Please select a category' : null,
                      ),
                      const SizedBox(height: 32),
                      LoadingButton(
                        isLoading: _isSaving,
                        onPressed: _saveMenuItem,
                        loadingText: 'Saving...',
                        child: const Text('Add Item'),
                      ),
                    ],
                  ),
                ),
              ),
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
} 