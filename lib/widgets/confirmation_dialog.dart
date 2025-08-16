import 'package:flutter/material.dart';

/// A reusable confirmation dialog widget.
/// 
/// This widget provides a standardized way to ask for user confirmation.
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final IconData? icon;
  final Color? confirmColor;
  final Color? cancelColor;
  final bool isDestructive;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmText = 'Confirm',
    this.cancelText = 'Cancel',
    this.icon,
    this.confirmColor,
    this.cancelColor,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: isDestructive ? Colors.red : Theme.of(context).primaryColor,
              size: 24,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: isDestructive ? Colors.red : null,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: cancelColor ?? Colors.grey.shade600,
          ),
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor ?? (isDestructive ? Colors.red : Theme.of(context).primaryColor),
            foregroundColor: Colors.white,
          ),
          child: Text(confirmText),
        ),
      ],
    );
  }
}

/// A specialized confirmation dialog for delete operations.
class DeleteConfirmationDialog extends StatelessWidget {
  final String itemName;
  final String? message;

  const DeleteConfirmationDialog({
    super.key,
    required this.itemName,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return ConfirmationDialog(
      title: 'Delete $itemName',
      message: message ?? 'Are you sure you want to delete "$itemName"? This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      icon: Icons.delete_forever,
      isDestructive: true,
      confirmColor: Colors.red,
    );
  }
}

/// A utility class for showing confirmation dialogs.
class ConfirmationDialogHelper {
  /// Shows a general confirmation dialog.
  static Future<bool?> showConfirmation(
    BuildContext context, {
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    IconData? icon,
    Color? confirmColor,
    Color? cancelColor,
    bool isDestructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => ConfirmationDialog(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
        icon: icon,
        confirmColor: confirmColor,
        cancelColor: cancelColor,
        isDestructive: isDestructive,
      ),
    );
  }

  /// Shows a delete confirmation dialog.
  static Future<bool?> showDeleteConfirmation(
    BuildContext context, {
    required String itemName,
    String? message,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => DeleteConfirmationDialog(
        itemName: itemName,
        message: message,
      ),
    );
  }

  /// Shows a confirmation dialog for closing a table.
  static Future<bool?> showCloseTableConfirmation(
    BuildContext context, {
    required String tableNumber,
  }) {
    return showConfirmation(
      context,
      title: 'Close Table $tableNumber',
      message: 'Are you sure you want to close Table $tableNumber? This will clear all orders and reset the table status.',
      confirmText: 'Close Table',
      cancelText: 'Cancel',
      icon: Icons.table_restaurant,
      isDestructive: true,
      confirmColor: Colors.orange,
    );
  }

  /// Shows a confirmation dialog for sending orders to kitchen.
  static Future<bool?> showSendToKitchenConfirmation(
    BuildContext context, {
    required int itemCount,
  }) {
    return showConfirmation(
      context,
      title: 'Send to Kitchen',
      message: 'Send $itemCount item${itemCount == 1 ? '' : 's'} to the kitchen?',
      confirmText: 'Send',
      cancelText: 'Cancel',
      icon: Icons.restaurant,
      confirmColor: Colors.green,
    );
  }
} 