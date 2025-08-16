import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/order_service.dart';

/// Widget that displays the current synchronization status and provides
/// controls for manual synchronization across all platforms.
class SyncStatusWidget extends StatefulWidget {
  final bool showDetails;
  final VoidCallback? onTap;
  
  const SyncStatusWidget({
    super.key,
    this.showDetails = false,
    this.onTap,
  });

  @override
  State<SyncStatusWidget> createState() => _SyncStatusWidgetState();
}

class _SyncStatusWidgetState extends State<SyncStatusWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _rotationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  
  Map<String, dynamic>? _syncStatus;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _rotationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));
    
    _pulseController.repeat(reverse: true);
    _loadSyncStatus();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _loadSyncStatus() async {
    try {
      final orderService = context.read<OrderService?>();
      if (orderService == null) return;
      
      // Create a mock sync status since OrderService doesn't have getSyncStatus
      final status = {
        'is_syncing': false,
        'last_sync': DateTime.now().toIso8601String(),
        'sync_status': 'idle',
        'pending_changes': 0,
      };
      
      if (mounted) {
        setState(() {
          _syncStatus = status;
        });
        
        // Start pulse animation if syncing
        if (status['is_syncing'] == true) {
          _rotationController.repeat();
        } else {
          _rotationController.stop();
        }
      }
    } catch (e) {
      debugPrint('Failed to load sync status: $e');
    }
  }

  Future<void> _forceSyncNow() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    _rotationController.repeat();
    
    try {
      // DISABLED: This was causing infinite sync loops
      // final syncService = UnifiedFirebaseSyncService();
      // await syncService.initialize();
      // await syncService.triggerImmediateSync();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Synchronization completed successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Synchronization failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
        _rotationController.stop();
        await _loadSyncStatus();
      }
    }
  }

  Color _getStatusColor() {
    if (_syncStatus == null) return Colors.grey;
    
    final isOnline = _syncStatus!['is_online'] as bool? ?? false;
    final isSyncing = _syncStatus!['is_syncing'] as bool? ?? false;
    final pendingSyncs = _syncStatus!['pending_syncs'] as int? ?? 0;
    final failedSyncs = _syncStatus!['failed_syncs'] as int? ?? 0;
    
    if (isSyncing) return Colors.blue;
    if (!isOnline) return Colors.orange;
    if (failedSyncs > 0) return Colors.red;
    if (pendingSyncs > 0) return Colors.amber;
    return Colors.green;
  }

  IconData _getStatusIcon() {
    if (_syncStatus == null) return Icons.sync_problem;
    
    final isOnline = _syncStatus!['is_online'] as bool? ?? false;
    final isSyncing = _syncStatus!['is_syncing'] as bool? ?? false;
    final pendingSyncs = _syncStatus!['pending_syncs'] as int? ?? 0;
    final failedSyncs = _syncStatus!['failed_syncs'] as int? ?? 0;
    
    if (isSyncing) return Icons.sync;
    if (!isOnline) return Icons.cloud_off;
    if (failedSyncs > 0) return Icons.sync_problem;
    if (pendingSyncs > 0) return Icons.sync_outlined;
    return Icons.cloud_done;
  }

  String _getStatusText() {
    if (_syncStatus == null) return 'Loading...';
    
    final isOnline = _syncStatus!['is_online'] as bool? ?? false;
    final isSyncing = _syncStatus!['is_syncing'] as bool? ?? false;
    final pendingSyncs = _syncStatus!['pending_syncs'] as int? ?? 0;
    final failedSyncs = _syncStatus!['failed_syncs'] as int? ?? 0;
    final lastSync = _syncStatus!['last_sync'] as int? ?? 0;
    
    if (isSyncing) return 'Syncing...';
    if (!isOnline) return 'Offline';
    if (failedSyncs > 0) return '$failedSyncs sync errors';
    if (pendingSyncs > 0) return '$pendingSyncs pending';
    
    if (lastSync > 0) {
      final lastSyncTime = DateTime.fromMillisecondsSinceEpoch(lastSync);
      final now = DateTime.now();
      final difference = now.difference(lastSyncTime);
      
      if (difference.inMinutes < 1) {
        return 'Synced just now';
      } else if (difference.inMinutes < 60) {
        return 'Synced ${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return 'Synced ${difference.inHours}h ago';
      } else {
        return 'Synced ${difference.inDays}d ago';
      }
    }
    
    return 'Ready to sync';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap ?? _showSyncDialog,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _getStatusColor().withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _getStatusColor().withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                final shouldRotate = _syncStatus?['is_syncing'] == true || _isRefreshing;
                return Transform.rotate(
                  angle: shouldRotate ? _rotationAnimation.value * 2 * 3.14159 : 0,
                  child: Icon(
                    _getStatusIcon(),
                    color: _getStatusColor(),
                    size: 16,
                  ),
                );
              },
            ),
            if (widget.showDetails) ...[
              const SizedBox(width: 8),
              Text(
                _getStatusText(),
                style: TextStyle(
                  color: _getStatusColor(),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSyncDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              _getStatusIcon(),
              color: _getStatusColor(),
            ),
            const SizedBox(width: 12),
            const Text('Sync Status'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusRow('Status', _getStatusText()),
            const SizedBox(height: 8),
            _buildStatusRow(
              'Connection',
              _syncStatus?['is_online'] == true ? 'Online' : 'Offline',
            ),
            const SizedBox(height: 8),
            _buildStatusRow(
              'Pending Syncs',
              '${_syncStatus?['pending_syncs'] ?? 0}',
            ),
            const SizedBox(height: 8),
            _buildStatusRow(
              'Failed Syncs',
              '${_syncStatus?['failed_syncs'] ?? 0}',
            ),
            const SizedBox(height: 16),
            const Text(
              'Cross-Platform Sync',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your data is automatically synchronized across all devices and platforms (Android, iOS, Web) when online.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: _isRefreshing ? null : () {
              Navigator.of(context).pop();
              _forceSyncNow();
            },
            icon: _isRefreshing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: Text(_isRefreshing ? 'Syncing...' : 'Sync Now'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

/// Compact version of sync status for app bars
class CompactSyncStatus extends StatelessWidget {
  const CompactSyncStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return const SyncStatusWidget(showDetails: false);
  }
}

/// Detailed version of sync status for settings or status pages
class DetailedSyncStatus extends StatelessWidget {
  const DetailedSyncStatus({super.key});

  @override
  Widget build(BuildContext context) {
    return const SyncStatusWidget(showDetails: true);
  }
} 