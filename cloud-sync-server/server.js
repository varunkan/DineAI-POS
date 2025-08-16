const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const cors = require('cors');
const bodyParser = require('body-parser');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Middleware
app.use(cors());
app.use(bodyParser.json());

// Store connected clients by restaurant
const connectedClients = new Map(); // restaurantId -> Set of WebSocket connections
const restaurantData = new Map(); // restaurantId -> Map of data

// WebSocket connection handling
wss.on('connection', (ws, req) => {
  const url = new URL(req.url, 'http://localhost');
  const deviceId = url.searchParams.get('device_id');
  const restaurantId = url.searchParams.get('restaurant_id');
  const userId = url.searchParams.get('user_id');
  
  console.log(`🔗 New connection: Device ${deviceId} for restaurant ${restaurantId}`);
  
  // Store connection info
  ws.deviceId = deviceId;
  ws.restaurantId = restaurantId;
  ws.userId = userId;
  
  // Add to restaurant's client set
  if (!connectedClients.has(restaurantId)) {
    connectedClients.set(restaurantId, new Set());
  }
  connectedClients.get(restaurantId).add(ws);
  
  // Initialize restaurant data if needed
  if (!restaurantData.has(restaurantId)) {
    restaurantData.set(restaurantId, {
      orders: new Map(),
      menuItems: new Map(),
      inventory: new Map(),
      tables: new Map(),
      users: new Map(),
      printers: new Map(),
    });
  }
  
  // Handle incoming messages
  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      console.log(`📨 Received message from ${deviceId}: ${data.type}`);
      
      switch (data.type) {
        case 'register':
          // Client registration - send confirmation
          ws.send(JSON.stringify({
            type: 'registered',
            device_id: deviceId,
            restaurant_id: restaurantId,
            timestamp: new Date().toISOString(),
          }));
          break;
          
        case 'heartbeat':
          // Heartbeat - send response
          ws.send(JSON.stringify({
            type: 'heartbeat_response',
            device_id: deviceId,
            timestamp: new Date().toISOString(),
          }));
          break;
          
        case 'order_update':
        case 'menu_update':
        case 'inventory_update':
        case 'table_update':
        case 'user_update':
        case 'printer_update':
        case 'data_change':
          // Broadcast to all other clients in the same restaurant
          broadcastToRestaurant(restaurantId, data, ws);
          break;
          
        default:
          console.log(`❓ Unknown message type: ${data.type}`);
      }
    } catch (error) {
      console.error('❌ Error processing message:', error);
    }
  });
  
  // Handle client disconnection
  ws.on('close', () => {
    console.log(`🔌 Client disconnected: ${deviceId} from restaurant ${restaurantId}`);
    
    // Remove from restaurant's client set
    const restaurantClients = connectedClients.get(restaurantId);
    if (restaurantClients) {
      restaurantClients.delete(ws);
      
      // Clean up empty restaurant
      if (restaurantClients.size === 0) {
        connectedClients.delete(restaurantId);
        restaurantData.delete(restaurantId);
      }
    }
  });
  
  // Handle errors
  ws.on('error', (error) => {
    console.error(`❌ WebSocket error for ${deviceId}:`, error);
  });
});

// Broadcast message to all clients in a restaurant (except sender)
function broadcastToRestaurant(restaurantId, message, sender) {
  const clients = connectedClients.get(restaurantId);
  if (!clients) return;
  
  const messageStr = JSON.stringify(message);
  let broadcastCount = 0;
  
  clients.forEach((client) => {
    if (client !== sender && client.readyState === WebSocket.OPEN) {
      client.send(messageStr);
      broadcastCount++;
    }
  });
  
  console.log(`📡 Broadcasted ${message.type} to ${broadcastCount} clients in restaurant ${restaurantId}`);
}

// REST API endpoints
app.get('/api/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString(),
    connectedRestaurants: connectedClients.size,
    totalConnections: Array.from(connectedClients.values()).reduce((sum, clients) => sum + clients.size, 0),
  });
});

app.get('/api/restaurants/:restaurantId/status', (req, res) => {
  const { restaurantId } = req.params;
  const clients = connectedClients.get(restaurantId);
  
  res.json({
    restaurant_id: restaurantId,
    connected_devices: clients ? Array.from(clients).map(ws => ({
      device_id: ws.deviceId,
      user_id: ws.userId,
      connected_at: ws.connectedAt || new Date().toISOString(),
    })) : [],
    device_count: clients ? clients.size : 0,
  });
});

app.post('/api/sync', (req, res) => {
  const { restaurant_id, device_id, changes } = req.body;
  
  console.log(`🔄 Sync request from ${device_id} for restaurant ${restaurant_id}: ${changes.length} changes`);
  
  try {
    // Process changes and update local data
    changes.forEach(change => {
      const { data_type, action, data } = change;
      
      if (!restaurantData.has(restaurant_id)) {
        restaurantData.set(restaurant_id, {
          orders: new Map(),
          menuItems: new Map(),
          inventory: new Map(),
          tables: new Map(),
          users: new Map(),
          printers: new Map(),
        });
      }
      
      const restaurant = restaurantData.get(restaurant_id);
      
      switch (data_type) {
        case 'orders':
          if (action === 'upsert' || action === 'created' || action === 'updated') {
            restaurant.orders.set(data.id, { ...data, last_sync: new Date().toISOString() });
          } else if (action === 'deleted') {
            restaurant.orders.delete(data.id);
          }
          break;
          
        case 'menu_items':
          if (action === 'upsert' || action === 'created' || action === 'updated') {
            restaurant.menuItems.set(data.id, { ...data, last_sync: new Date().toISOString() });
          } else if (action === 'deleted') {
            restaurant.menuItems.delete(data.id);
          }
          break;
          
        case 'inventory':
          if (action === 'upsert' || action === 'created' || action === 'updated') {
            restaurant.inventory.set(data.id, { ...data, last_sync: new Date().toISOString() });
          } else if (action === 'deleted') {
            restaurant.inventory.delete(data.id);
          }
          break;
          
        case 'tables':
          if (action === 'upsert' || action === 'created' || action === 'updated') {
            restaurant.tables.set(data.id, { ...data, last_sync: new Date().toISOString() });
          } else if (action === 'deleted') {
            restaurant.tables.delete(data.id);
          }
          break;
          
        case 'users':
          if (action === 'upsert' || action === 'created' || action === 'updated') {
            restaurant.users.set(data.id, { ...data, last_sync: new Date().toISOString() });
          } else if (action === 'deleted') {
            restaurant.users.delete(data.id);
          }
          break;
          
        case 'printers':
          if (action === 'upsert' || action === 'created' || action === 'updated') {
            restaurant.printers.set(data.id, { ...data, last_sync: new Date().toISOString() });
          } else if (action === 'deleted') {
            restaurant.printers.delete(data.id);
          }
          break;
      }
    });
    
    // Broadcast changes to all connected clients in the restaurant
    const clients = connectedClients.get(restaurant_id);
    if (clients) {
      const syncMessage = {
        type: 'sync_update',
        restaurant_id,
        changes,
        timestamp: new Date().toISOString(),
      };
      
      const messageStr = JSON.stringify(syncMessage);
      clients.forEach(client => {
        if (client.readyState === WebSocket.OPEN) {
          client.send(messageStr);
        }
      });
    }
    
    res.json({
      status: 'success',
      synced_changes: changes.length,
      timestamp: new Date().toISOString(),
    });
    
  } catch (error) {
    console.error('❌ Sync error:', error);
    res.status(500).json({
      status: 'error',
      message: error.message,
      timestamp: new Date().toISOString(),
    });
  }
});

// Get restaurant data
app.get('/api/restaurants/:restaurantId/data', (req, res) => {
  const { restaurantId } = req.params;
  const data = restaurantData.get(restaurantId);
  
  if (!data) {
    return res.status(404).json({
      status: 'error',
      message: 'Restaurant not found',
    });
  }
  
  res.json({
    restaurant_id: restaurantId,
    data: {
      orders: Array.from(data.orders.values()),
      menu_items: Array.from(data.menuItems.values()),
      inventory: Array.from(data.inventory.values()),
      tables: Array.from(data.tables.values()),
      users: Array.from(data.users.values()),
      printers: Array.from(data.printers.values()),
    },
    timestamp: new Date().toISOString(),
  });
});

// Start server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`🚀 Cloud Sync Server running on port ${PORT}`);
  console.log(`📡 WebSocket endpoint: ws://localhost:${PORT}`);
  console.log(`🌐 HTTP API endpoint: http://localhost:${PORT}/api`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('🛑 Shutting down server...');
  server.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('🛑 Shutting down server...');
  server.close(() => {
    console.log('✅ Server closed');
    process.exit(0);
  });
}); 