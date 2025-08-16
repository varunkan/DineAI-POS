import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Removed: import '../services/auto_printer_discovery_service.dart'; (redundant service)
import '../services/printer_configuration_service.dart';
import '../models/printer_configuration.dart';

/// Widget to display real-time printer connection status
class PrinterStatusWidget extends StatelessWidget {
  final bool showHeader;
  final bool showControls;
  final VoidCallback? onRefreshTap;

  const PrinterStatusWidget({
    super.key,
    this.showHeader = true,
    this.showControls = true,
    this.onRefreshTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PrinterConfigurationService?>(
      builder: (context, printerConfigService, child) {
        if (printerConfigService == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '⚠️ Printer services not initialized',
                style: TextStyle(color: Colors.orange),
              ),
            ),
          );
        }

        // Use printer configuration service instead of auto discovery
        final totalPrinters = printerConfigService.configurations.length;
        final onlinePrinters = printerConfigService.activeConfigurations.length;
        final isDiscovering = printerConfigService.isScanning;
        const isEnabled = true; // Always enabled in simplified version

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                if (showHeader) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.print,
                        color: onlinePrinters > 0 ? Colors.green : Colors.red,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Printer Status',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      if (isDiscovering)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Status summary
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: onlinePrinters > 0 ? Colors.green.shade50 : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: onlinePrinters > 0 ? Colors.green.shade200 : Colors.red.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        onlinePrinters > 0 ? Icons.check_circle : Icons.error,
                        color: onlinePrinters > 0 ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$onlinePrinters of $totalPrinters printers online',
                        style: TextStyle(
                          color: onlinePrinters > 0 ? Colors.green.shade800 : Colors.red.shade800,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Individual printer status
                if (totalPrinters > 0) ...[
                  Text(
                    'Printer Details:',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...printerConfigService.configurations.map((printer) {
                    final isOnline = printer.connectionStatus == PrinterConnectionStatus.connected;
                    final lastCheck = printer.lastConnected;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isOnline ? Colors.green.shade300 : Colors.red.shade300,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isOnline ? Colors.green : Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  printer.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  '${printer.ipAddress}:${printer.port}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                                if (lastCheck != null)
                                  Text(
                                    'Last checked: ${_formatTime(lastCheck)}',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            isOnline ? 'ONLINE' : 'OFFLINE',
                            style: TextStyle(
                              color: isOnline ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.search, color: Colors.blue.shade600),
                        const SizedBox(height: 8),
                        Text(
                          'No printers configured',
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isDiscovering 
                              ? 'Scanning for printers...'
                              : 'Configure printers to see their status',
                          style: TextStyle(
                            color: Colors.blue.shade600,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],

                // Controls
                if (showControls) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: isDiscovering ? null : () {
                          printerConfigService.manualDiscovery();
                          if (onRefreshTap != null) onRefreshTap!();
                        },
                        icon: Icon(
                          isDiscovering ? Icons.hourglass_empty : Icons.refresh,
                          size: 16,
                        ),
                        label: Text(isDiscovering ? 'Scanning...' : 'Scan Now'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          // Auto-discovery is always enabled
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Auto-discovery is always enabled'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.info_outline,
                          size: 16,
                        ),
                        label: const Text('Info'),
                        style: OutlinedButton.styleFrom(
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],

                // Discovery status info
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isEnabled ? Icons.sync : Icons.sync_disabled,
                        size: 14,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isEnabled 
                              ? 'Auto-discovery enabled - scanning every 5 minutes'
                              : 'Auto-discovery paused',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
} 