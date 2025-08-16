# AI POS Cloud Sync Server

A real-time cloud synchronization server for the AI POS System that enables changes made on one device to be immediately reflected on all other devices across different networks.

## Features

- **Real-time Updates**: WebSocket-based real-time synchronization
- **Multi-tenant Support**: Separate data isolation for each restaurant
- **Cross-network Sync**: Works across different networks and devices
- **Automatic Reconnection**: Handles network disconnections gracefully
- **Data Persistence**: Stores restaurant data in memory (can be extended to database)
- **REST API**: HTTP endpoints for data retrieval and management

## Supported Data Types

- **Orders**: Order creation, updates, status changes, completion
- **Menu Items**: Item creation, updates, availability changes, deletion
- **Inventory**: Stock changes, item additions/removals, low stock alerts
- **Tables**: Occupation, availability, reservations, cleaning status
- **Users**: User management, role changes, authentication
- **Printers**: Printer configuration, assignments, status updates

## Installation

1. **Install Node.js** (version 16 or higher)

2. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd cloud-sync-server
   ```

3. **Install dependencies**
   ```bash
   npm install
   ```

4. **Start the server**
   ```bash
   npm start
   ```

   For development with auto-restart:
   ```bash
   npm run dev
   ```

## Configuration

The server runs on port 3000 by default. You can change this by setting the `PORT` environment variable:

```bash
PORT=8080 npm start
```

## API Endpoints

### Health Check
```
GET /api/health
```
Returns server status and connection statistics.

### Restaurant Status
```
GET /api/restaurants/:restaurantId/status
```
Returns connected devices and device count for a specific restaurant.

### Data Sync
```
POST /api/sync
```
Accepts changes from devices and broadcasts them to all connected clients.

**Request Body:**
```json
{
  "restaurant_id": "restaurant_123",
  "device_id": "pos_device_001",
  "changes": [
    {
      "type": "data_change",
      "data_type": "orders",
      "action": "updated",
      "data": {
        "id": "order_456",
        "status": "completed",
        "total_amount": 25.50
      }
    }
  ]
}
```

### Get Restaurant Data
```
GET /api/restaurants/:restaurantId/data
```
Returns all stored data for a specific restaurant.

## WebSocket Connection

Clients connect to the WebSocket endpoint with query parameters:

```
ws://localhost:3000?device_id=pos_device_001&restaurant_id=restaurant_123&user_id=user_456
```

### Message Types

#### Client to Server
- `register`: Initial client registration
- `heartbeat`: Keep-alive ping
- `order_update`: Order-related updates
- `menu_update`: Menu item updates
- `inventory_update`: Inventory changes
- `table_update`: Table status changes
- `user_update`: User management updates
- `printer_update`: Printer configuration updates
- `data_change`: Generic data changes

#### Server to Client
- `registered`: Registration confirmation
- `heartbeat_response`: Heartbeat acknowledgment
- `sync_update`: Synchronization updates from other devices
- `error`: Error messages

## Deployment

### Local Development
```bash
npm run dev
```

### Production Deployment

1. **Using PM2** (recommended for production):
   ```bash
   npm install -g pm2
   pm2 start server.js --name "ai-pos-sync"
   pm2 save
   pm2 startup
   ```

2. **Using Docker**:
   ```dockerfile
   FROM node:16-alpine
   WORKDIR /app
   COPY package*.json ./
   RUN npm install --production
   COPY . .
   EXPOSE 3000
   CMD ["npm", "start"]
   ```

3. **Using Heroku**:
   ```bash
   heroku create ai-pos-sync
   git push heroku main
   ```

## Security Considerations

- **Authentication**: Implement JWT or API key authentication
- **Rate Limiting**: Add rate limiting for API endpoints
- **Input Validation**: Validate all incoming data
- **HTTPS/WSS**: Use secure connections in production
- **Data Encryption**: Encrypt sensitive data

## Monitoring

The server provides health check endpoints for monitoring:

```bash
curl http://localhost:3000/api/health
```

## Troubleshooting

### Common Issues

1. **Connection Refused**: Ensure the server is running and port is available
2. **WebSocket Connection Failed**: Check firewall settings and network connectivity
3. **Memory Usage**: Monitor memory usage for large datasets
4. **Performance**: Consider horizontal scaling for high-traffic scenarios

### Logs

The server logs all connections, messages, and errors to the console. In production, redirect logs to a file:

```bash
npm start > server.log 2>&1
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

MIT License - see LICENSE file for details. 