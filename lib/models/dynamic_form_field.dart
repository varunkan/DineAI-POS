enum FieldType {
  text,
  number,
  email,
  phone,
  date,
  time,
  select,
  multiselect,
  checkbox,
  radio,
  textarea,
  image,
  file,
}

class DynamicFormField {
  final String id;
  final String label;
  final String? hint;
  final FieldType type;
  final bool required;
  final String? defaultValue;
  final List<String>? options; // For select, multiselect, radio
  final Map<String, dynamic>? validation;
  final Map<String, dynamic>? properties;
  final int? order;
  final bool enabled;

  DynamicFormField({
    required this.id,
    required this.label,
    this.hint,
    required this.type,
    this.required = false,
    this.defaultValue,
    this.options,
    this.validation,
    this.properties,
    this.order,
    this.enabled = true,
  });

  factory DynamicFormField.fromJson(Map<String, dynamic> json) {
    try {
      return DynamicFormField(
        id: json['id'] as String? ?? '',
        label: json['label'] as String? ?? '',
        hint: json['hint'] as String?,
        type: FieldType.values.firstWhere(
          (e) => e.toString().split('.').last == (json['type'] ?? '').toString(),
          orElse: () => FieldType.text,
        ),
        required: json['required'] ?? false,
        defaultValue: json['defaultValue'],
        options: json['options'] != null 
            ? List<String>.from(json['options'])
            : null,
        validation: json['validation'],
        properties: json['properties'],
        order: json['order'],
        enabled: json['enabled'] ?? true,
      );
    } catch (e) {
      return DynamicFormField(id: '', label: '', type: FieldType.text);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'hint': hint,
      'type': type.toString().split('.').last,
      'required': required,
      'defaultValue': defaultValue,
      'options': options,
      'validation': validation,
      'properties': properties,
      'order': order,
      'enabled': enabled,
    };
  }

  DynamicFormField copyWith({
    String? id,
    String? label,
    String? hint,
    FieldType? type,
    bool? required,
    String? defaultValue,
    List<String>? options,
    Map<String, dynamic>? validation,
    Map<String, dynamic>? properties,
    int? order,
    bool? enabled,
  }) {
    return DynamicFormField(
      id: id ?? this.id,
      label: label ?? this.label,
      hint: hint ?? this.hint,
      type: type ?? this.type,
      required: required ?? this.required,
      defaultValue: defaultValue ?? this.defaultValue,
      options: options ?? this.options,
      validation: validation ?? this.validation,
      properties: properties ?? this.properties,
      order: order ?? this.order,
      enabled: enabled ?? this.enabled,
    );
  }
}

class DynamicForm {
  final String id;
  final String name;
  final String description;
  final List<DynamicFormField> fields;
  final Map<String, dynamic>? properties;
  final bool enabled;

  DynamicForm({
    required this.id,
    required this.name,
    this.description = '',
    required this.fields,
    this.properties,
    this.enabled = true,
  });

  factory DynamicForm.fromJson(Map<String, dynamic> json) {
    try {
      return DynamicForm(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] ?? '',
        fields: (json['fields'] as List?)?.map((field) => DynamicFormField.fromJson(field)).toList() ?? [],
        properties: json['properties'],
        enabled: json['enabled'] ?? true,
      );
    } catch (e) {
      return DynamicForm(id: '', name: '', fields: []);
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'fields': fields.map((field) => field.toJson()).toList(),
      'properties': properties,
      'enabled': enabled,
    };
  }

  DynamicForm copyWith({
    String? id,
    String? name,
    String? description,
    List<DynamicFormField>? fields,
    Map<String, dynamic>? properties,
    bool? enabled,
  }) {
    return DynamicForm(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      fields: fields ?? this.fields,
      properties: properties ?? this.properties,
      enabled: enabled ?? this.enabled,
    );
  }
} 