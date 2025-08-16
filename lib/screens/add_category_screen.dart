import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category.dart' as pos_category;
import '../services/menu_service.dart';
import '../widgets/loading_overlay.dart';
import '../widgets/error_dialog.dart';
import '../widgets/form_field.dart';
import '../widgets/back_button.dart';

class AddCategoryScreen extends StatefulWidget {
  const AddCategoryScreen({super.key});

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();

      final menuService = Provider.of<MenuService>(context, listen: false);
      final newCategory = pos_category.Category(
        name: name,
        description: description.isEmpty ? null : description,
      );
      await menuService.saveCategory(newCategory);

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Category added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        await ErrorDialogHelper.showError(
          context,
          title: 'Error Adding Category',
          message: 'Failed to add category: $e',
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
          title: const Text('Add Category'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: <Widget>[
            const CustomBackButton(),
            const SizedBox(width: 16),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppFormField(
                  label: 'Category Name',
                  hint: 'e.g., Appetizers, Main Course',
                  controller: _nameController,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Category name is required';
                    }
                    return null;
                  },
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 16),
                AppFormField(
                  label: 'Description',
                  hint: 'Brief description of the category (optional)',
                  controller: _descriptionController,
                  maxLines: 3,
                  textInputAction: TextInputAction.done,
                ),
                const SizedBox(height: 32),
                LoadingButton(
                  isLoading: _isLoading,
                  onPressed: _saveCategory,
                  loadingText: 'Saving...',
                  child: const Text('Add Category'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 