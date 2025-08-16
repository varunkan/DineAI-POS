# Cloud Sync Implementation for AI POS System

## Overview

This implementation provides **real-time synchronization** across multiple Android devices on different networks, ensuring that changes made on one device using the "Oh Bombay Milton" tenant are immediately reflected on all other mobile devices.

## Architecture

### Components

1. **CloudSyncService** (`lib/services/cloud_sync_service.dart`)
   - WebSocket-based real-time communication
   - Automatic reconnection and heartbeat management
   - Multi-tenant data isolation
   - Change queuing and synchronization

2. **CloudSyncIntegrationService** (`lib/services/cloud_sync_integration_service.dart`)
   - Integrates cloud sync with existing POS services
   - Automatic broadcasting of local changes
   - Handling of remote updates
   - Service lifecycle management

3. **Cloud Sync Server** (`cloud-sync-server/`)
   - Node.js WebSocket server
   - REST API endpoints
   - Multi-tenant data storage
   - Real-time message broadcasting

## How It Works

### 1. Device Connection
```
Device A (Network 1) ←→ Cloud Server ←→ Device B (Network 2)
```

- Each device connects to the cloud server via WebSocket
- Devices identify themselves with `device_id`, `restaurant_id`, and `user_id`
- Server maintains separate connection pools for each restaurant

### 2. Real-time Updates
When a change occurs on Device A:

1. **Local Change Detection**: POS service triggers change event
2. **Cloud Broadcast**: Change is immediately sent to cloud server
3. **Server Processing**: Server validates and stores the change
4. **Multi-device Broadcast**: Server sends update to all connected devices in the same restaurant
5. **Remote Update**: Device B receives and applies the change locally

### 3. Data Types Supported

| Data Type | Actions | Description |
|-----------|---------|-------------|
| **Orders** | created, updated, status_changed, completed | Order lifecycle management |
| **Menu Items** | created, updated, deleted, availability_changed | Menu management |
| **Inventory** | stock_changed, item_added, item_removed, low_stock_alert | Stock management |
| **Tables** | occupied, available, reserved, cleaning | Table status management |
| **Users** | created, updated, deleted, role_changed | User management |
| **Printers** | added, removed, configured, assignment_changed | Printer management |

## Implementation Details

### CloudSyncService Features

```dart
class CloudSyncService extends ChangeNotifier {
  // Real-time connection management
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isOnline = false;
  
  // Event streams for different data types
  Stream<Map<String, dynamic>> get orderUpdates;
  Stream<Map<String, dynamic>> get menuUpdates;
  Stream<Map<String, dynamic>> get inventoryUpdates;
  // ... more streams
  
  // Automatic reconnection
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  
  // Change queuing
  final List<Map<String, dynamic>> _pendingChanges = [];
}
```

### Key Features

1. **Automatic Reconnection**
   - Detects network disconnections
   - Implements exponential backoff
   - Maintains connection state

2. **Change Deduplication**
   - Prevents processing same change multiple times
   - Uses unique change IDs
   - Tracks processed changes

3. **Offline Support**
   - Queues changes when offline
   - Syncs when connection restored
   - Maintains data integrity

4. **Multi-tenant Isolation**
   - Separate data per restaurant
   - Isolated WebSocket connections
   - Secure data boundaries

## Setup Instructions

### 1. Start Cloud Sync Server

```bash
cd cloud-sync-server
./setup.sh
```

Or manually:
```bash
npm install
npm start
```

### 2. Configure Flutter App

The cloud sync is automatically initialized in `main.dart`:

```dart
// Initialize cloud sync service
await CloudSyncManager.initialize(
  restaurantId: currentRestaurant.id,
  userId: currentSession?.userId,
  serverUrl: 'ws://localhost:3000', // Change for production
  apiUrl: 'http://localhost:3000/api',
);

// Initialize integration service
await CloudSyncIntegrationManager.initialize(
  cloudSyncService: CloudSyncManager.instance,
  orderService: _orderService,
  menuService: _menuService,
  // ... other services
);
```

### 3. Production Deployment

For production, update the server URLs:

```dart
serverUrl: 'wss://your-domain.com/ws',
apiUrl: 'https://your-domain.com/api',
```

## Usage Examples

### Broadcasting an Order Update

```dart
// Automatic (via integration service)
// Just update the order normally - it will be broadcast automatically

// Manual broadcasting
CloudSyncManager.instance.broadcastOrderUpdate(
  orderId: 'order_123',
  action: 'status_changed',
  data: {
    'status': 'completed',
    'total_amount': 25.50,
    'completed_at': DateTime.now().toIso8601String(),
  },
);
```

### Listening for Remote Updates

```dart
// Listen for order updates from other devices
CloudSyncManager.instance.orderUpdates.listen((data) {
  final orderId = data['order_id'];
  final action = data['action'];
  final orderData = data['data'];
  
  // Update local UI/database
  _updateLocalOrder(orderId, orderData);
});
```

### Checking Connection Status

```dart
final cloudSync = CloudSyncManager.instance;
if (cloudSync.isConnected) {
  print('✅ Connected to cloud sync');
} else if (cloudSync.isOnline) {
  print('🔄 Connecting...');
} else {
  print('❌ Offline');
}
```

## Testing

### 1. Local Testing

1. Start the cloud sync server
2. Run the Flutter app on multiple devices/emulators
3. Make changes on one device
4. Verify changes appear on other devices

### 2. Network Testing

1. Connect devices to different networks
2. Ensure both devices have internet access
3. Test real-time synchronization

### 3. Server Health Check

```bash
curl http://localhost:3000/api/health
```

Expected response:
```json
{
  "status": "ok",
  "timestamp": "2024-01-01T12:00:00.000Z",
  "connectedRestaurants": 1,
  "totalConnections": 2
}
```

## Monitoring and Debugging

### Logs

The system provides comprehensive logging:

```
☁️ CloudSyncService: Initializing for restaurant: restaurant_123
☁️ CloudSyncService: Connected to ws://localhost:3000
🔗 CloudSyncIntegrationService: Received remote order update: updated for order_456
📡 Broadcasted order_update to 2 clients in restaurant restaurant_123
```

### Connection Status

Monitor connection status in the app:
- Green indicator: Connected
- Yellow indicator: Connecting
- Red indicator: Offline

### Server Monitoring

Check server status:
```bash
curl http://localhost:3000/api/restaurants/restaurant_123/status
```

## Security Considerations

### Current Implementation
- Basic device identification
- Restaurant-level data isolation
- No authentication (for development)

### Production Recommendations
1. **JWT Authentication**: Implement token-based authentication
2. **API Keys**: Use API keys for server communication
3. **HTTPS/WSS**: Use secure connections
4. **Rate Limiting**: Implement request rate limiting
5. **Input Validation**: Validate all incoming data
6. **Data Encryption**: Encrypt sensitive data

## Performance Optimization

### Current Optimizations
- Change deduplication
- Efficient WebSocket messaging
- Automatic reconnection with backoff
- Offline change queuing

### Future Improvements
1. **Message Compression**: Compress large messages
2. **Batch Updates**: Batch multiple changes
3. **Selective Sync**: Sync only changed data
4. **Caching**: Implement client-side caching
5. **Load Balancing**: Multiple server instances

## Troubleshooting

### Common Issues

1. **Connection Failed**
   - Check server is running
   - Verify network connectivity
   - Check firewall settings

2. **Updates Not Syncing**
   - Verify restaurant ID matches
   - Check device IDs are unique
   - Monitor server logs

3. **High Memory Usage**
   - Monitor server memory usage
   - Implement data cleanup
   - Consider database storage

### Debug Commands

```bash
# Check server status
curl http://localhost:3000/api/health

# Check restaurant connections
curl http://localhost:3000/api/restaurants/restaurant_123/status

# View server logs
tail -f cloud-sync-server/logs/server.log
```

## Deployment Options

### 1. Local Development
```bash
cd cloud-sync-server
npm run dev
```

### 2. Production Server
```bash
# Using PM2
npm install -g pm2
pm2 start server.js --name "ai-pos-sync"
pm2 save
pm2 startup
```

### 3. Cloud Deployment
- **Heroku**: `heroku create ai-pos-sync && git push heroku main`
- **AWS**: Deploy to EC2 or ECS
- **Google Cloud**: Deploy to App Engine or Compute Engine
- **Azure**: Deploy to App Service or Container Instances

## Future Enhancements

1. **Database Integration**: Store data in PostgreSQL/MongoDB
2. **Push Notifications**: Send push notifications for important updates
3. **Conflict Resolution**: Handle concurrent updates
4. **Data Versioning**: Track data versions and changes
5. **Analytics**: Track sync performance and usage
6. **Mobile App**: Dedicated mobile app for monitoring

## Conclusion

This cloud sync implementation provides a robust, scalable solution for real-time synchronization across multiple devices. It ensures that changes made on any device are immediately reflected on all other devices, regardless of their network location.

The system is designed to be:
- **Reliable**: Automatic reconnection and error handling
- **Scalable**: Multi-tenant architecture
- **Efficient**: Optimized messaging and change tracking
- **Secure**: Data isolation and validation
- **Maintainable**: Clear separation of concerns and comprehensive logging

For production deployment, ensure to implement proper authentication, use secure connections, and monitor system performance. 