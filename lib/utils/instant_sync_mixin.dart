import 'package:flutter/material.dart';
import '../services/unified_sync_service.dart';

/// Mixin to add instant sync functionality to any widget
mixin InstantSyncMixin<T extends StatefulWidget> on State<T> {
  UnifiedSyncService? _syncService;

  @override
  void initState() {
    super.initState();
    _syncService = UnifiedSyncService();
  }

  /// Trigger instant sync on any user interaction
  Future<void> triggerInstantSync() async {
    try {
      debugPrint('⚡ INSTANT SYNC: Triggered from ${widget.runtimeType}');
      await _syncService?.triggerInstantSync();
    } catch (e) {
      debugPrint('❌ INSTANT SYNC failed: $e');
    }
  }

  /// Wrap any user interaction with instant sync
  Future<void> withInstantSync(Future<void> Function() action) async {
    await action();
    await triggerInstantSync();
  }

  /// Wrap synchronous user interaction with instant sync
  void withInstantSyncSync(void Function() action) {
    action();
    triggerInstantSync();
  }
} 