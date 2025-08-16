import 'package:uuid/uuid.dart';

/// Enum for assignment types
enum AssignmentType {
  category,
  menuItem,
}

/// Represents a printer assignment for menu items or categories
class PrinterAssignment {
  final String id;
  final String printerId;
  final String printerName;
  final String printerAddress;
  final AssignmentType assignmentType;
  final String targetId; // Category ID or Menu Item ID
  final String targetName; // Category name or Menu Item name
  final bool isActive;
  final int priority; // Higher priority takes precedence
  final DateTime createdAt;
  final DateTime updatedAt;

  PrinterAssignment({
    String? id,
    required this.printerId,
    required this.printerName,
    required this.printerAddress,
    required this.assignmentType,
    required this.targetId,
    required this.targetName,
    this.isActive = true,
    this.priority = 1,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : 
    id = id ?? const Uuid().v4(),
    createdAt = createdAt ?? DateTime.now(),
    updatedAt = updatedAt ?? DateTime.now();

  /// Creates a [PrinterAssignment] from JSON
  factory PrinterAssignment.fromJson(Map<String, dynamic> json) {
    return PrinterAssignment(
      id: json['id'] as String? ?? const Uuid().v4(),
      printerId: json['printer_id'] as String? ?? '',
      printerName: json['printer_name'] as String? ?? '',
      printerAddress: json['printer_address'] as String? ?? '',
      assignmentType: AssignmentType.values.firstWhere(
        (e) => e.toString().split('.').last == (json['assignment_type'] as String? ?? 'category'),
        orElse: () => AssignmentType.category,
      ),
      targetId: json['target_id'] as String? ?? '',
      targetName: json['target_name'] as String? ?? '',
      isActive: (json['is_active'] as int?) == 1,
      priority: json['priority'] as int? ?? 1,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  /// Converts this [PrinterAssignment] to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'printer_id': printerId,
      'printer_name': printerName,
      'printer_address': printerAddress,
      'assignment_type': assignmentType.toString().split('.').last,
      'target_id': targetId,
      'target_name': targetName,
      'is_active': isActive ? 1 : 0,
      'priority': priority,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Returns a copy of this [PrinterAssignment] with updated fields
  PrinterAssignment copyWith({
    String? id,
    String? printerId,
    String? printerName,
    String? printerAddress,
    AssignmentType? assignmentType,
    String? targetId,
    String? targetName,
    bool? isActive,
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PrinterAssignment(
      id: id ?? this.id,
      printerId: printerId ?? this.printerId,
      printerName: printerName ?? this.printerName,
      printerAddress: printerAddress ?? this.printerAddress,
      assignmentType: assignmentType ?? this.assignmentType,
      targetId: targetId ?? this.targetId,
      targetName: targetName ?? this.targetName,
      isActive: isActive ?? this.isActive,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PrinterAssignment && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 