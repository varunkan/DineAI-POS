import 'package:flutter/material.dart';
import '../models/dynamic_form_field.dart';

class DynamicFormWidget extends StatefulWidget {
  final DynamicForm form;
  final Map<String, dynamic>? initialValues;
  final Function(Map<String, dynamic>) onSubmitted;
  final Function(Map<String, dynamic>)? onChanged;
  final bool readOnly;

  const DynamicFormWidget({
    super.key,
    required this.form,
    this.initialValues,
    required this.onSubmitted,
    this.onChanged,
    this.readOnly = false,
  });

  @override
  State<DynamicFormWidget> createState() => _DynamicFormWidgetState();
}

class _DynamicFormWidgetState extends State<DynamicFormWidget> {
  final Map<String, dynamic> _formData = {};
  final Map<String, GlobalKey<FormFieldState>> _fieldKeys = {};
  final Map<String, String?> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _initializeFormData();
  }

  void _initializeFormData() {
    // Initialize with default values
    for (final field in widget.form.fields) {
      _formData[field.id] = widget.initialValues?[field.id] ?? field.defaultValue ?? '';
      _fieldKeys[field.id] = GlobalKey<FormFieldState>();
    }
  }

  void _updateFormData(String fieldId, dynamic value) {
    setState(() {
      _formData[fieldId] = value;
      _fieldErrors[fieldId] = null; // Clear error when field changes
    });
    widget.onChanged?.call(_formData);
  }

  bool _validateForm() {
    bool isValid = true;
    final errors = <String, String>{};

    for (final field in widget.form.fields) {
      if (field.required && (_formData[field.id] == null || _formData[field.id].toString().isEmpty)) {
        errors[field.id] = '${field.label} is required';
        isValid = false;
      } else if (field.validation != null) {
        final validationError = _validateField(field, _formData[field.id]);
        if (validationError != null) {
          errors[field.id] = validationError;
          isValid = false;
        }
      }
    }

    setState(() {
      _fieldErrors.addAll(errors);
    });

    return isValid;
  }

  String? _validateField(DynamicFormField field, dynamic value) {
    if (value == null || value.toString().isEmpty) return null;

    final validation = field.validation!;

    if (validation['minLength'] != null) {
      final minLength = validation['minLength'] as int;
      if (value.toString().length < minLength) {
        return '${field.label} must be at least $minLength characters';
      }
    }

    if (validation['maxLength'] != null) {
      final maxLength = validation['maxLength'] as int;
      if (value.toString().length > maxLength) {
        return '${field.label} must be at most $maxLength characters';
      }
    }

    if (validation['pattern'] != null) {
      final pattern = RegExp(validation['pattern']);
      if (!pattern.hasMatch(value.toString())) {
        return validation['patternMessage'] ?? '${field.label} format is invalid';
      }
    }

    if (validation['min'] != null && field.type == FieldType.number) {
      final min = validation['min'] as num;
      final numValue = num.tryParse(value.toString());
      if (numValue != null && numValue < min) {
        return '${field.label} must be at least $min';
      }
    }

    if (validation['max'] != null && field.type == FieldType.number) {
      final max = validation['max'] as num;
      final numValue = num.tryParse(value.toString());
      if (numValue != null && numValue > max) {
        return '${field.label} must be at most $max';
      }
    }

    return null;
  }

  void _submitForm() {
    if (_validateForm()) {
      widget.onSubmitted(_formData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedFields = List<DynamicFormField>.from(widget.form.fields)
      ..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));

    return Form(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...sortedFields.map((field) => _buildField(field)),
          const SizedBox(height: 24),
          if (!widget.readOnly)
            ElevatedButton(
              onPressed: _submitForm,
              child: const Text('Submit'),
            ),
        ],
      ),
    );
  }

  Widget _buildField(DynamicFormField field) {
    if (!field.enabled) return const SizedBox.shrink();

    final error = _fieldErrors[field.id];

    switch (field.type) {
      case FieldType.text:
        return _buildTextField(field, error);
      case FieldType.number:
        return _buildNumberField(field, error);
      case FieldType.email:
        return _buildEmailField(field, error);
      case FieldType.phone:
        return _buildPhoneField(field, error);
      case FieldType.date:
        return _buildDateField(field, error);
      case FieldType.time:
        return _buildTimeField(field, error);
      case FieldType.select:
        return _buildSelectField(field, error);
      case FieldType.multiselect:
        return _buildMultiSelectField(field, error);
      case FieldType.checkbox:
        return _buildCheckboxField(field, error);
      case FieldType.radio:
        return _buildRadioField(field, error);
      case FieldType.textarea:
        return _buildTextareaField(field, error);
      case FieldType.image:
        return _buildImageField(field, error);
      case FieldType.file:
        return _buildFileField(field, error);
    }
  }

  Widget _buildTextField(DynamicFormField field, String? error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: _fieldKeys[field.id],
        decoration: InputDecoration(
          labelText: field.label,
          hintText: field.hint,
          errorText: error,
        ),
        initialValue: _formData[field.id]?.toString(),
        enabled: !widget.readOnly,
        onChanged: (value) => _updateFormData(field.id, value),
      ),
    );
  }

  Widget _buildNumberField(DynamicFormField field, String? error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: _fieldKeys[field.id],
        decoration: InputDecoration(
          labelText: field.label,
          hintText: field.hint,
          errorText: error,
        ),
        initialValue: _formData[field.id]?.toString(),
        enabled: !widget.readOnly,
        keyboardType: TextInputType.number,
        onChanged: (value) => _updateFormData(field.id, value),
      ),
    );
  }

  Widget _buildEmailField(DynamicFormField field, String? error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: _fieldKeys[field.id],
        decoration: InputDecoration(
          labelText: field.label,
          hintText: field.hint,
          errorText: error,
        ),
        initialValue: _formData[field.id]?.toString(),
        enabled: !widget.readOnly,
        keyboardType: TextInputType.emailAddress,
        onChanged: (value) => _updateFormData(field.id, value),
      ),
    );
  }

  Widget _buildPhoneField(DynamicFormField field, String? error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: _fieldKeys[field.id],
        decoration: InputDecoration(
          labelText: field.label,
          hintText: field.hint,
          errorText: error,
        ),
        initialValue: _formData[field.id]?.toString(),
        enabled: !widget.readOnly,
        keyboardType: TextInputType.phone,
        onChanged: (value) => _updateFormData(field.id, value),
      ),
    );
  }

  Widget _buildDateField(DynamicFormField field, String? error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: widget.readOnly ? null : () => _selectDate(field),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: field.label,
            errorText: error,
          ),
          child: Text(
            _formData[field.id]?.toString() ?? 'Select date',
            style: TextStyle(
              color: _formData[field.id] != null ? null : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeField(DynamicFormField field, String? error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: widget.readOnly ? null : () => _selectTime(field),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: field.label,
            errorText: error,
          ),
          child: Text(
            _formData[field.id]?.toString() ?? 'Select time',
            style: TextStyle(
              color: _formData[field.id] != null ? null : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectField(DynamicFormField field, String? error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: field.label,
          errorText: error,
        ),
        value: _formData[field.id]?.toString(),
        items: field.options?.map((option) {
          return DropdownMenuItem(
            value: option,
            child: Text(option),
          );
        }).toList() ?? [],
        onChanged: widget.readOnly ? null : (value) => _updateFormData(field.id, value),
      ),
    );
  }

  Widget _buildMultiSelectField(DynamicFormField field, String? error) {
    final selectedValues = _formData[field.id] is List 
        ? List<String>.from(_formData[field.id])
        : <String>[];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field.label, style: Theme.of(context).textTheme.titleSmall),
          if (error != null) Text(error, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: field.options?.map((option) {
              final isSelected = selectedValues.contains(option);
              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: widget.readOnly ? null : (selected) {
                  setState(() {
                    if (selected) {
                      selectedValues.add(option);
                    } else {
                      selectedValues.remove(option);
                    }
                    _updateFormData(field.id, selectedValues);
                  });
                },
              );
            }).toList() ?? [],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckboxField(DynamicFormField field, String? error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CheckboxListTile(
        title: Text(field.label),
        subtitle: error != null ? Text(error, style: const TextStyle(color: Colors.red)) : null,
        value: _formData[field.id] == true,
        onChanged: widget.readOnly ? null : (value) => _updateFormData(field.id, value),
      ),
    );
  }

  Widget _buildRadioField(DynamicFormField field, String? error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field.label, style: Theme.of(context).textTheme.titleSmall),
          if (error != null) Text(error, style: const TextStyle(color: Colors.red)),
          ...field.options?.map((option) {
            return RadioListTile<String>(
              title: Text(option),
              value: option,
              groupValue: _formData[field.id]?.toString(),
              onChanged: widget.readOnly ? null : (value) => _updateFormData(field.id, value),
            );
          }).toList() ?? [],
        ],
      ),
    );
  }

  Widget _buildTextareaField(DynamicFormField field, String? error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: _fieldKeys[field.id],
        decoration: InputDecoration(
          labelText: field.label,
          hintText: field.hint,
          errorText: error,
        ),
        initialValue: _formData[field.id]?.toString(),
        enabled: !widget.readOnly,
        maxLines: 4,
        onChanged: (value) => _updateFormData(field.id, value),
      ),
    );
  }

  Widget _buildImageField(DynamicFormField field, String? error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field.label, style: Theme.of(context).textTheme.titleSmall),
          if (error != null) Text(error, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: widget.readOnly ? null : () => _selectImage(field),
            icon: const Icon(Icons.image),
            label: const Text('Select Image'),
          ),
        ],
      ),
    );
  }

  Widget _buildFileField(DynamicFormField field, String? error) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(field.label, style: Theme.of(context).textTheme.titleSmall),
          if (error != null) Text(error, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: widget.readOnly ? null : () => _selectFile(field),
            icon: const Icon(Icons.attach_file),
            label: const Text('Select File'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(DynamicFormField field) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      _updateFormData(field.id, picked.toIso8601String().split('T')[0]);
    }
  }

  Future<void> _selectTime(DynamicFormField field) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      _updateFormData(field.id, picked.format(context));
    }
  }

  Future<void> _selectImage(DynamicFormField field) async {
    // TODO: Implement image picker
    _updateFormData(field.id, 'image_path');
  }

  Future<void> _selectFile(DynamicFormField field) async {
    // TODO: Implement file picker
    _updateFormData(field.id, 'file_path');
  }
} 