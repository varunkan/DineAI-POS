/**
 * REMOTE PRINTING CLOUD SERVICE API
 * 
 * This Node.js/Express server acts as the cloud intermediary for remote printing.
 * Deploy this to Firebase Functions, AWS Lambda, Heroku, or any cloud provider.
 * 
 * FEATURES:
 * - Order routing between POS app and kitchen printers
 * - Real-time order polling
 * - Printer registration and management
 * - Order acknowledgment and status tracking
 * - Error handling and retry logic
 * - API authentication
 * 
 * DEPLOYMENT INSTRUCTIONS:
 * 1. npm install express cors body-parser
 * 2. Replace 'your-secret-api-key' with your actual API key
 * 3. Deploy to your preferred cloud provider
 * 4. Update the Flutter app with your deployed URL
 */

const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');

const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(bodyParser.json());

// Configuration
const API_KEY = 'your-secret-api-key'; // Replace with your actual API key
const POLL_TIMEOUT = 30000; // 30 seconds

// In-memory data storage (use database in production)
const registeredPrinters = new Map();
const pendingOrders = new Map();
const orderHistory = new Map();

// Example configuration for restaurant 123456
const exampleRestaurantConfig = {
  '123456': {
    name: 'Oh Bombay Milton',
    printers: {
      'kitchen_printer_01': {
        name: 'Kitchen Printer',
        type: 'thermal',
        status: 'online'
      }
    },
    orders: []
  }
};

// Initialize restaurant data if needed
function initializeRestaurantData(restaurantId) {
  if (!orders[restaurantId]) {
    orders[restaurantId] = {};
  }
  if (!printers[restaurantId]) {
    printers[restaurantId] = {};
  }
  
  // Initialize with example config if it's restaurant 123456
  if (restaurantId === '123456' && Object.keys(printers[restaurantId]).length === 0) {
    printers[restaurantId] = exampleRestaurantConfig['123456'].printers;
    console.log(`Initialized restaurant ${restaurantId} with example configuration`);
  }
}

// Middleware for API authentication
const authenticateAPI = (req, res, next) => {
  const authHeader = req.headers.authorization;
  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'Missing or invalid Authorization header' });
  }
  
  const token = authHeader.substring(7);
  if (token !== API_KEY) {
    return res.status(401).json({ error: 'Invalid API key' });
  }
  
  next();
};

// Health check endpoint
app.get('/api/v1/health', (req, res) => {
  res.json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    uptime: process.uptime(),
    registered_printers: registeredPrinters.size,
    pending_orders: pendingOrders.size
  });
});

// Register printer endpoint
app.post('/api/v1/printers/register', authenticateAPI, (req, res) => {
  try {
    const { printerId, restaurantId, printerType, capabilities, location } = req.body;
    
    if (!printerId || !restaurantId) {
      return res.status(400).json({ error: 'printerId and restaurantId are required' });
    }
    
    // Initialize restaurant data if needed
    initializeRestaurantData(restaurantId);
    
    const printerData = {
      printerId,
      restaurantId,
      printerType: printerType || 'thermal',
      capabilities: capabilities || ['ESC/POS'],
      location: location || 'kitchen',
      registeredAt: new Date().toISOString(),
      lastSeen: new Date().toISOString(),
      status: 'online'
    };
    
    registeredPrinters.set(printerId, printerData);
    
    // Initialize pending orders for this printer
    if (!pendingOrders.has(printerId)) {
      pendingOrders.set(printerId, []);
    }
    
    console.log(`📝 Printer registered: ${printerId} for restaurant: ${restaurantId}`);
    
    res.json({
      success: true,
      message: 'Printer registered successfully',
      printer: printerData
    });
    
  } catch (error) {
    console.error('❌ Error registering printer:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Send order to printer endpoint
app.post('/api/v1/orders/send', authenticateAPI, (req, res) => {
  try {
    const { orderId, restaurantId, targetPrinterId, orderData, priority } = req.body;
    
    if (!orderId || !restaurantId || !targetPrinterId || !orderData) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    
    // Check if printer is registered
    if (!registeredPrinters.has(targetPrinterId)) {
      return res.status(404).json({ error: 'Printer not found or not registered' });
    }
    
    // Create order entry
    const orderEntry = {
      id: `order_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      orderId,
      restaurantId,
      targetPrinterId,
      orderData,
      priority: priority || 3,
      createdAt: new Date().toISOString(),
      status: 'pending',
      attempts: 0
    };
    
    // Add to pending orders for the target printer
    const printerOrders = pendingOrders.get(targetPrinterId) || [];
    printerOrders.push(orderEntry);
    
    // Sort by priority (lower number = higher priority)
    printerOrders.sort((a, b) => a.priority - b.priority);
    
    pendingOrders.set(targetPrinterId, printerOrders);
    
    console.log(`📤 Order queued: ${orderId} for printer: ${targetPrinterId}`);
    
    res.json({
      success: true,
      message: 'Order sent successfully',
      orderEntry: {
        id: orderEntry.id,
        orderId: orderEntry.orderId,
        status: orderEntry.status,
        createdAt: orderEntry.createdAt
      }
    });
    
  } catch (error) {
    console.error('❌ Error sending order:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Poll for orders endpoint
app.get('/api/v1/orders/poll', authenticateAPI, (req, res) => {
  try {
    const { printerId } = req.query;
    
    if (!printerId) {
      return res.status(400).json({ error: 'printerId is required' });
    }
    
    // Check if printer is registered
    if (!registeredPrinters.has(printerId)) {
      return res.status(404).json({ error: 'Printer not found or not registered' });
    }
    
    // Update last seen timestamp
    const printer = registeredPrinters.get(printerId);
    printer.lastSeen = new Date().toISOString();
    registeredPrinters.set(printerId, printer);
    
    // Get pending orders for this printer
    const printerOrders = pendingOrders.get(printerId) || [];
    
    if (printerOrders.length === 0) {
      return res.status(204).json({ message: 'No pending orders' });
    }
    
    // Return up to 5 orders at a time
    const ordersToSend = printerOrders.slice(0, 5);
    
    console.log(`📥 Polling: ${ordersToSend.length} orders for printer: ${printerId}`);
    
    res.json({
      success: true,
      orders: ordersToSend,
      total: printerOrders.length,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ Error polling orders:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Acknowledge processed orders endpoint
app.post('/api/v1/orders/acknowledge', authenticateAPI, (req, res) => {
  try {
    const { orderIds, printerId } = req.body;
    
    if (!orderIds || !Array.isArray(orderIds) || !printerId) {
      return res.status(400).json({ error: 'orderIds (array) and printerId are required' });
    }
    
    // Get pending orders for this printer
    const printerOrders = pendingOrders.get(printerId) || [];
    
    // Remove acknowledged orders and move to history
    const remainingOrders = printerOrders.filter(order => {
      if (orderIds.includes(order.id)) {
        // Move to history
        order.status = 'processed';
        order.processedAt = new Date().toISOString();
        
        if (!orderHistory.has(printerId)) {
          orderHistory.set(printerId, []);
        }
        
        const history = orderHistory.get(printerId);
        history.push(order);
        
        // Keep only last 100 processed orders
        if (history.length > 100) {
          history.splice(0, history.length - 100);
        }
        
        orderHistory.set(printerId, history);
        
        console.log(`✅ Order acknowledged: ${order.orderId} for printer: ${printerId}`);
        return false; // Remove from pending
      }
      return true; // Keep in pending
    });
    
    pendingOrders.set(printerId, remainingOrders);
    
    res.json({
      success: true,
      message: 'Orders acknowledged successfully',
      acknowledgedCount: orderIds.length,
      remainingCount: remainingOrders.length
    });
    
  } catch (error) {
    console.error('❌ Error acknowledging orders:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get printer status endpoint
app.get('/api/v1/printers/:printerId/status', authenticateAPI, (req, res) => {
  try {
    const { printerId } = req.params;
    
    if (!registeredPrinters.has(printerId)) {
      return res.status(404).json({ error: 'Printer not found' });
    }
    
    const printer = registeredPrinters.get(printerId);
    const pendingCount = (pendingOrders.get(printerId) || []).length;
    const processedCount = (orderHistory.get(printerId) || []).length;
    
    // Check if printer is online (last seen within 2 minutes)
    const lastSeen = new Date(printer.lastSeen);
    const now = new Date();
    const offlineThreshold = 2 * 60 * 1000; // 2 minutes
    const isOnline = (now - lastSeen) < offlineThreshold;
    
    res.json({
      success: true,
      printer: {
        ...printer,
        status: isOnline ? 'online' : 'offline',
        pendingOrders: pendingCount,
        processedOrders: processedCount,
        lastSeenMinutesAgo: Math.floor((now - lastSeen) / (60 * 1000))
      }
    });
    
  } catch (error) {
    console.error('❌ Error getting printer status:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get restaurant printers endpoint
app.get('/api/v1/restaurants/:restaurantId/printers', authenticateAPI, (req, res) => {
  try {
    const { restaurantId } = req.params;
    
    const restaurantPrinters = [];
    
    for (const [printerId, printer] of registeredPrinters.entries()) {
      if (printer.restaurantId === restaurantId) {
        const pendingCount = (pendingOrders.get(printerId) || []).length;
        const processedCount = (orderHistory.get(printerId) || []).length;
        
        // Check if printer is online
        const lastSeen = new Date(printer.lastSeen);
        const now = new Date();
        const offlineThreshold = 2 * 60 * 1000; // 2 minutes
        const isOnline = (now - lastSeen) < offlineThreshold;
        
        restaurantPrinters.push({
          ...printer,
          status: isOnline ? 'online' : 'offline',
          pendingOrders: pendingCount,
          processedOrders: processedCount,
          lastSeenMinutesAgo: Math.floor((now - lastSeen) / (60 * 1000))
        });
      }
    }
    
    res.json({
      success: true,
      restaurantId,
      printers: restaurantPrinters,
      total: restaurantPrinters.length
    });
    
  } catch (error) {
    console.error('❌ Error getting restaurant printers:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get system statistics endpoint
app.get('/api/v1/statistics', authenticateAPI, (req, res) => {
  try {
    let totalPendingOrders = 0;
    let totalProcessedOrders = 0;
    let onlinePrinters = 0;
    
    const now = new Date();
    const offlineThreshold = 2 * 60 * 1000; // 2 minutes
    
    for (const [printerId, printer] of registeredPrinters.entries()) {
      const pendingCount = (pendingOrders.get(printerId) || []).length;
      const processedCount = (orderHistory.get(printerId) || []).length;
      
      totalPendingOrders += pendingCount;
      totalProcessedOrders += processedCount;
      
      const lastSeen = new Date(printer.lastSeen);
      if ((now - lastSeen) < offlineThreshold) {
        onlinePrinters++;
      }
    }
    
    res.json({
      success: true,
      statistics: {
        totalPrinters: registeredPrinters.size,
        onlinePrinters,
        offlinePrinters: registeredPrinters.size - onlinePrinters,
        totalPendingOrders,
        totalProcessedOrders,
        uptime: process.uptime(),
        timestamp: new Date().toISOString()
      }
    });
    
  } catch (error) {
    console.error('❌ Error getting statistics:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Cleanup old orders periodically
setInterval(() => {
  const now = new Date();
  const cleanupThreshold = 24 * 60 * 60 * 1000; // 24 hours
  
  for (const [printerId, history] of orderHistory.entries()) {
    const cleanedHistory = history.filter(order => {
      const orderDate = new Date(order.processedAt);
      return (now - orderDate) < cleanupThreshold;
    });
    
    if (cleanedHistory.length !== history.length) {
      orderHistory.set(printerId, cleanedHistory);
      console.log(`🧹 Cleaned up ${history.length - cleanedHistory.length} old orders for printer: ${printerId}`);
    }
  }
}, 60 * 60 * 1000); // Run every hour

// Error handling middleware
app.use((err, req, res, next) => {
  console.error('❌ Unhandled error:', err);
  res.status(500).json({ error: 'Internal server error' });
});

// Start the server
app.listen(port, () => {
  console.log(`🚀 Remote Printing Cloud Service API running on port ${port}`);
  console.log(`📊 Health check: http://localhost:${port}/api/v1/health`);
  console.log(`🔑 API Key: ${API_KEY}`);
  console.log(`⏰ Poll timeout: ${POLL_TIMEOUT}ms`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('🛑 Received SIGTERM, shutting down gracefully...');
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log('🛑 Received SIGINT, shutting down gracefully...');
  process.exit(0);
});

module.exports = app; 