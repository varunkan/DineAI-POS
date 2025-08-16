import 'package:flutter/material.dart';
import '../services/printer_validation_service.dart';

/// Dialog to display printer validation results and provide corrective actions
class PrinterValidationDialog extends StatelessWidget {
  final PrinterValidationResult validationResult;
  final VoidCallback? onRetry;
  final VoidCallback? onConfigurePrinters;
  final VoidCallback? onProceedAnyway;

  const PrinterValidationDialog({
    Key? key,
    required this.validationResult,
    this.onRetry,
    this.onConfigurePrinters,
    this.onProceedAnyway,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 600,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: _buildContent(context),
            ),
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: validationResult.isValid ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Icon(
            validationResult.isValid ? Icons.check_circle : Icons.error,
            color: validationResult.isValid ? Colors.green : Colors.red,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  validationResult.isValid ? 'Validation Successful' : 'Validation Failed',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: validationResult.isValid ? Colors.green.shade800 : Colors.red.shade800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  validationResult.isValid ? 'Ready to send to kitchen' : 'Cannot send to kitchen',
                  style: TextStyle(
                    fontSize: 14,
                    color: validationResult.isValid ? Colors.green.shade600 : Colors.red.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMessage(),
            if (validationResult.details != null) ...[
              const SizedBox(height: 16),
              _buildDetails(),
            ],
            if (!validationResult.isValid) ...[
              const SizedBox(height: 24),
              _buildSuggestions(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(
        validationResult.message,
        style: const TextStyle(
          fontSize: 16,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildDetails() {
    final details = validationResult.details!;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Details',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...details.entries.map((entry) => _buildDetailItem(entry.key, entry.value)),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String key, dynamic value) {
    String displayValue;
    
    if (value is List) {
      displayValue = value.join(', ');
    } else if (value is Map) {
      displayValue = value.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    } else {
      displayValue = value.toString();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              _formatKey(key),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              displayValue,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatKey(String key) {
    return key.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(1)}',
    ).trim().toLowerCase().split(' ').map((word) => 
      word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : word
    ).join(' ') + ':';
  }

  Widget _buildSuggestions() {
    final suggestions = _getSuggestions();
    
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'Suggested Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...suggestions.map((suggestion) => _buildSuggestionItem(suggestion)),
        ],
      ),
    );
  }

  Widget _buildSuggestionItem(String suggestion) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.orange.shade600,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              suggestion,
              style: const TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getSuggestions() {
    final type = validationResult.failureType;
    
    switch (type) {
      case ValidationFailureType.missingAssignments:
        return [
          'Go to Admin Panel → Printer Assignment',
          'Assign menu items or categories to printers',
          'Ensure all items have at least one printer assignment',
        ];
      
      case ValidationFailureType.printersOffline:
        return [
          'Check printer power and network connections',
          'Verify printer IP addresses and ports',
          'Test printer connectivity in Admin Panel',
          'Consider using alternative printers if available',
        ];
      
      case ValidationFailureType.noPrintersConfigured:
        return [
          'Configure at least one printer in Admin Panel',
          'Set up network or Bluetooth printer connections',
          'Test printer connectivity after configuration',
        ];
      
      case ValidationFailureType.configurationIssues:
        return [
          'Review printer configurations in Admin Panel',
          'Enable disabled printers if needed',
          'Verify IP addresses and port numbers',
          'Test each printer connection individually',
        ];
      
      case ValidationFailureType.serviceNotReady:
        return [
          'Wait for printer services to initialize',
          'Restart the application if the issue persists',
          'Check system requirements and permissions',
        ];
      
      default:
        return [
          'Review printer configuration and assignments',
          'Check network connectivity',
          'Contact system administrator if issues persist',
        ];
    }
  }

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!validationResult.isValid && onConfigurePrinters != null) ...[
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onConfigurePrinters!();
              },
              icon: const Icon(Icons.settings),
              label: const Text('Configure Printers'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
                side: BorderSide(color: Colors.blue.shade300),
              ),
            ),
            const SizedBox(width: 12),
          ],
          
          if (!validationResult.isValid && onRetry != null) ...[
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry!();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.orange.shade700,
                side: BorderSide(color: Colors.orange.shade300),
              ),
            ),
            const SizedBox(width: 12),
          ],
          
          if (!validationResult.isValid && onProceedAnyway != null) ...[
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onProceedAnyway!();
              },
              icon: const Icon(Icons.warning),
              label: const Text('Proceed Anyway'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade700,
                side: BorderSide(color: Colors.red.shade300),
              ),
            ),
            const SizedBox(width: 12),
          ],
          
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              validationResult.isValid ? 'Continue' : 'Cancel',
              style: TextStyle(
                color: validationResult.isValid ? Colors.green.shade700 : Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper method to show printer validation dialog
Future<void> showPrinterValidationDialog(
  BuildContext context,
  PrinterValidationResult result, {
  VoidCallback? onRetry,
  VoidCallback? onConfigurePrinters,
  VoidCallback? onProceedAnyway,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PrinterValidationDialog(
      validationResult: result,
      onRetry: onRetry,
      onConfigurePrinters: onConfigurePrinters,
      onProceedAnyway: onProceedAnyway,
    ),
  );
} 