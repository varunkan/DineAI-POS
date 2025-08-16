import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

/// Real-time service for live updates across all POS terminals
class RealtimeService extends ChangeNotifier {
  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  bool _isConnected = false;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  
  // Event streams
  final StreamController<Map<String, dynamic>> _orderUpdatesController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _kitchenUpdatesController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _inventoryUpdatesController = 
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _tableUpdatesController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  // Configuration
  static const Duration _reconnectDelay = Duration(seconds: 5);
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const int _maxReconnectAttempts = 10;
  static const String _defaultServerUrl = 'ws://localhost:8080/ws';
  
  String _serverUrl = _defaultServerUrl;
  String? _deviceId;
  String? _restaurantId;

  // Getters
  bool get isConnected => _isConnected;
  bool get isReconnecting => _isReconnecting;
  Stream<Map<String, dynamic>> get orderUpdates => _orderUpdatesController.stream;
  Stream<Map<String, dynamic>> get kitchenUpdates => _kitchenUpdatesController.stream;
  Stream<Map<String, dynamic>> get inventoryUpdates => _inventoryUpdatesController.stream;
  Stream<Map<String, dynamic>> get tableUpdates => _tableUpdatesController.stream;

  RealtimeService({String? serverUrl, String? deviceId, String? restaurantId}) {
    _serverUrl = serverUrl ?? _defaultServerUrl;
    _deviceId = deviceId ?? _generateDeviceId();
    _restaurantId = restaurantId ?? 'default_restaurant';
  }

  @override
  void dispose() {
    _disconnect();
    _orderUpdatesController.close();
    _kitchenUpdatesController.close();
    _inventoryUpdatesController.close();
    _tableUpdatesController.close();
    super.dispose();
  }

  /// Initialize connection to real-time server
  Future<void> connect() async {
    if (_isConnected || _isReconnecting) return;
    
    try {
      _isReconnecting = true;
      notifyListeners();
      
      final uri = Uri.parse('$_serverUrl?device_id=$_deviceId&restaurant_id=$_restaurantId');
      _channel = IOWebSocketChannel.connect(uri);
      
      await _channel!.ready;
      
      _isConnected = true;
      _isReconnecting = false;
      _reconnectAttempts = 0;
      
      debugPrint('RealtimeService: Connected to $_serverUrl');
      
      // Start listening for messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
      );
      
      // Start heartbeat
      _startHeartbeat();
      
      // Send initial registration
      _sendMessage({
        'type': 'register',
        'device_id': _deviceId,
        'restaurant_id': _restaurantId,
        'timestamp': DateTime.now().toIso8601String(),
      });
      
      notifyListeners();
      
    } catch (e) {
      debugPrint('RealtimeService: Connection failed: $e');
      _isConnected = false;
      _isReconnecting = false;
      _scheduleReconnect();
      notifyListeners();
    }
  }

  /// Disconnect from real-time server
  void _disconnect() {
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();
    _channel?.sink.close();
    _isConnected = false;
    _isReconnecting = false;
    notifyListeners();
  }

  /// Handle incoming messages
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;
      
      debugPrint('RealtimeService: Received message type: $type');
      
      switch (type) {
        case 'order_update':
          _orderUpdatesController.add(data);
          break;
        case 'kitchen_update':
          _kitchenUpdatesController.add(data);
          break;
        case 'inventory_update':
          _inventoryUpdatesController.add(data);
          break;
        case 'table_update':
          _tableUpdatesController.add(data);
          break;
        case 'heartbeat_response':
          // Heartbeat acknowledged
          break;
        case 'error':
          debugPrint('RealtimeService: Server error: ${data['message']}');
          break;
        default:
          debugPrint('RealtimeService: Unknown message type: $type');
      }
    } catch (e) {
      debugPrint('RealtimeService: Error parsing message: $e');
    }
  }

  /// Handle connection errors
  void _handleError(error) {
    debugPrint('RealtimeService: WebSocket error: $error');
    _isConnected = false;
    _scheduleReconnect();
    notifyListeners();
  }

  /// Handle disconnection
  void _handleDisconnection() {
    debugPrint('RealtimeService: WebSocket disconnected');
    _isConnected = false;
    _heartbeatTimer?.cancel();
    _scheduleReconnect();
    notifyListeners();
  }

  /// Schedule reconnection attempt
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('RealtimeService: Max reconnect attempts reached');
      return;
    }
    
    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectDelay.inSeconds * _reconnectAttempts);
    
    debugPrint('RealtimeService: Scheduling reconnect in ${delay.inSeconds}s (attempt $_reconnectAttempts)');
    
    _reconnectTimer = Timer(delay, () {
      if (!_isConnected) {
        connect();
      }
    });
  }

  /// Start heartbeat to keep connection alive
  void _startHeartbeat() {
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (_) {
      if (_isConnected) {
        _sendMessage({
          'type': 'heartbeat',
          'device_id': _deviceId,
          'timestamp': DateTime.now().toIso8601String(),
        });
      }
    });
  }

  /// Send message to server
  void _sendMessage(Map<String, dynamic> message) {
    if (_isConnected && _channel != null) {
      try {
        _channel!.sink.add(jsonEncode(message));
      } catch (e) {
        debugPrint('RealtimeService: Error sending message: $e');
      }
    }
  }

  /// Broadcast order update to all connected devices
  void broadcastOrderUpdate(String orderId, String action, Map<String, dynamic> data) {
    _sendMessage({
      'type': 'order_update',
      'order_id': orderId,
      'action': action, // 'created', 'updated', 'status_changed', 'completed'
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'device_id': _deviceId,
    });
  }

  /// Broadcast kitchen update
  void broadcastKitchenUpdate(String orderId, String itemId, String status, Map<String, dynamic>? data) {
    _sendMessage({
      'type': 'kitchen_update',
      'order_id': orderId,
      'item_id': itemId,
      'status': status, // 'received', 'preparing', 'ready', 'served'
      'data': data ?? {},
      'timestamp': DateTime.now().toIso8601String(),
      'device_id': _deviceId,
    });
  }

  /// Broadcast inventory update
  void broadcastInventoryUpdate(String itemId, String action, Map<String, dynamic> data) {
    _sendMessage({
      'type': 'inventory_update',
      'item_id': itemId,
      'action': action, // 'stock_changed', 'item_added', 'item_removed', 'low_stock_alert'
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'device_id': _deviceId,
    });
  }

  /// Broadcast table update
  void broadcastTableUpdate(String tableId, String action, Map<String, dynamic> data) {
    _sendMessage({
      'type': 'table_update',
      'table_id': tableId,
      'action': action, // 'occupied', 'available', 'reserved', 'cleaning'
      'data': data,
      'timestamp': DateTime.now().toIso8601String(),
      'device_id': _deviceId,
    });
  }

  /// Generate unique device ID
  String _generateDeviceId() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp % 10000).toString().padLeft(4, '0');
    return 'pos_device_$random';
  }

  /// Update server URL and reconnect
  Future<void> updateServerUrl(String newUrl) async {
    if (_serverUrl != newUrl) {
      _serverUrl = newUrl;
      if (_isConnected) {
        _disconnect();
        await Future.delayed(const Duration(milliseconds: 500));
        await connect();
      }
    }
  }

  /// Force reconnection
  Future<void> forceReconnect() async {
    _disconnect();
    _reconnectAttempts = 0;
    await Future.delayed(const Duration(milliseconds: 500));
    await connect();
  }
}

/// Singleton instance for global access
class RealtimeManager {
  static RealtimeService? _instance;
  
  static RealtimeService get instance {
    _instance ??= RealtimeService();
    return _instance!;
  }
  
  static void initialize({String? serverUrl, String? deviceId, String? restaurantId}) {
    _instance = RealtimeService(
      serverUrl: serverUrl,
      deviceId: deviceId,
      restaurantId: restaurantId,
    );
  }
} 