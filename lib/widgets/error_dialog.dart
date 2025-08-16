import 'package:flutter/material.dart';
import 'dart:math' as math;

/// A reusable error dialog widget for consistent error handling.
/// 
/// This widget provides a standardized way to display errors to users.
class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final String? actionText;
  final VoidCallback? onAction;
  final bool showRetry;

  const ErrorDialog({
    Key? key,
    required this.title,
    required this.message,
    this.actionText,
    this.onAction,
    this.showRetry = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // FIXED: Add responsive constraints to prevent overflow
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = math.min(constraints.maxWidth * 0.8, 400.0);
        final maxHeight = math.min(constraints.maxHeight * 0.6, 300.0);
        
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: maxHeight,
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with icon and title
                Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.shade600,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade800,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Scrollable message content
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (showRetry)
                      TextButton(
                        onPressed: onAction,
                        child: Text(
                          actionText ?? 'Retry',
                          style: TextStyle(color: Theme.of(context).primaryColor),
                        ),
                      ),
                    if (showRetry) const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey.shade100,
                        foregroundColor: Colors.grey.shade800,
                        elevation: 0,
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A specialized error dialog for network errors.
class NetworkErrorDialog extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const NetworkErrorDialog({
    super.key,
    this.message = 'Network connection error. Please check your internet connection and try again.',
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorDialog(
      title: 'Network Error',
      message: message,
      showRetry: onRetry != null,
    );
  }
}

/// A specialized error dialog for validation errors.
class ValidationErrorDialog extends StatelessWidget {
  final String message;

  const ValidationErrorDialog({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorDialog(
      title: 'Validation Error',
      message: message,
    );
  }
}

/// A utility class for showing error dialogs.
class ErrorDialogHelper {
  /// Shows a general error dialog.
  static Future<void> showError(
    BuildContext context, {
    required String title,
    required String message,
    String? actionText,
    VoidCallback? onAction,
    bool showRetry = false,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => ErrorDialog(
        title: title,
        message: message,
        actionText: actionText,
        onAction: onAction,
        showRetry: showRetry,
      ),
    );
  }

  /// Shows a network error dialog.
  static Future<void> showNetworkError(
    BuildContext context, {
    String message = 'Network connection error. Please check your internet connection and try again.',
    VoidCallback? onRetry,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => NetworkErrorDialog(
        message: message,
        onRetry: onRetry,
      ),
    );
  }

  /// Shows a validation error dialog.
  static Future<void> showValidationError(
    BuildContext context, {
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => ValidationErrorDialog(
        message: message,
      ),
    );
  }
} 