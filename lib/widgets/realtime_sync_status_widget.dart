import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/unified_sync_service.dart';

/// Widget to display real-time sync status and active devices
class RealtimeSyncStatusWidget extends StatelessWidget {
  const RealtimeSyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UnifiedSyncService>(
      builder: (context, syncService, child) {
        if (!syncService.isInitialized) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    syncService.isConnected ? Icons.cloud_done : Icons.cloud_off,
                    color: syncService.isConnected ? Colors.green : Colors.red,
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    syncService.isConnected ? 'Real-time Sync Active' : 'Real-time Sync Offline',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: syncService.isConnected ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                  const Spacer(),
                  if (syncService.lastSyncTime != null)
                    Text(
                      'Last sync: ${_formatTime(syncService.lastSyncTime!)}',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                ],
              ),
              if (syncService.isConnected) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.devices, size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      '${syncService.activeDevices.length} active device${syncService.activeDevices.length != 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 11, color: Colors.blue),
                    ),
                  ],
                ),
                if (syncService.activeDevices.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Devices: ${syncService.activeDevices.take(3).join(', ')}${syncService.activeDevices.length > 3 ? '...' : ''}',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ],
            ],
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

/// Expanded real-time sync status widget with more details
class ExpandedRealtimeSyncStatusWidget extends StatelessWidget {
  const ExpandedRealtimeSyncStatusWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<UnifiedSyncService>(
      builder: (context, syncService, child) {
        if (!syncService.isInitialized) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    syncService.isConnected ? Icons.cloud_done : Icons.cloud_off,
                    color: syncService.isConnected ? Colors.green : Colors.red,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    syncService.isConnected ? 'Real-time Sync Active' : 'Real-time Sync Offline',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: syncService.isConnected ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                  const Spacer(),
                  if (syncService.lastSyncTime != null)
                    Text(
                      'Last sync: ${_formatTime(syncService.lastSyncTime!)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
              if (syncService.isConnected) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.devices, size: 16, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      '${syncService.activeDevices.length} active device${syncService.activeDevices.length != 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 13, color: Colors.blue, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                if (syncService.activeDevices.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Devices: ${syncService.activeDevices.take(5).join(', ')}${syncService.activeDevices.length > 5 ? '...' : ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ],
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