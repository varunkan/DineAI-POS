const express = require('express');
const cors = require('cors');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Initialize Firebase Admin (for Firebase option)
let db = null;
if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  try {
    const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    initializeApp({
      credential: cert(serviceAccount),
      databaseURL: process.env.FIREBASE_DATABASE_URL
    });
    db = getFirestore();
    console.log('✅ Firebase Admin initialized');
  } catch (error) {
    console.log('⚠️ Firebase Admin not configured, using in-memory storage');
  }
}

// In-memory storage for other services
const inMemoryDB = {
  printJobs: new Map(),
  printers: new Map(),
  orders: new Map()
};

// Helper function to get database
function getDB() {
  if (db) return { type: 'firebase', db };
  return { type: 'memory', db: inMemoryDB };
}

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ 
    status: 'ok', 
    service: 'free-restaurant-printing',
    timestamp: new Date().toISOString(),
    database: getDB().type
  });
});

// Register printer
app.post('/api/printers/register', async (req, res) => {
  try {
    const { printerId, name, ip, port, type, restaurantId } = req.body;
    
    if (!printerId || !name || !ip || !restaurantId) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: printerId, name, ip, restaurantId'
      });
    }
    
    const printerData = {
      id: printerId,
      name,
      ip,
      port: port || 9100,
      type: type || 'epson_thermal',
      restaurantId,
      status: 'online',
      lastSeen: new Date().toISOString(),
      createdAt: new Date().toISOString()
    };
    
    const database = getDB();
    
    if (database.type === 'firebase') {
      await database.db.collection('printers').doc(printerId).set(printerData);
    } else {
      database.db.printers.set(printerId, printerData);
    }
    
    console.log(`✅ Printer registered: ${name} (${ip})`);
    
    res.json({
      success: true,
      message: 'Printer registered successfully',
      printer: printerData
    });
    
  } catch (error) {
    console.error('❌ Error registering printer:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Send print job
app.post('/api/print-jobs', async (req, res) => {
  try {
    const { 
      orderId, 
      orderNumber,
      restaurantId, 
      targetPrinterId, 
      items, 
      orderData,
      priority = 5 
    } = req.body;
    
    if (!orderId || !restaurantId || !targetPrinterId || !items) {
      return res.status(400).json({
        success: false,
        error: 'Missing required fields: orderId, restaurantId, targetPrinterId, items'
      });
    }
    
    const jobId = `job_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    
    const printJob = {
      id: jobId,
      orderId,
      orderNumber,
      restaurantId,
      targetPrinterId,
      items,
      orderData,
      priority,
      status: 'pending',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString()
    };
    
    const database = getDB();
    
    if (database.type === 'firebase') {
      await database.db.collection('printJobs').doc(jobId).set(printJob);
    } else {
      database.db.printJobs.set(jobId, printJob);
    }
    
    console.log(`✅ Print job queued: ${orderNumber} → ${targetPrinterId}`);
    
    res.json({
      success: true,
      jobId,
      message: 'Print job queued successfully',
      printJob
    });
    
  } catch (error) {
    console.error('❌ Error creating print job:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Get print jobs for printer
app.get('/api/printers/:printerId/jobs', async (req, res) => {
  try {
    const { printerId } = req.params;
    const { status = 'pending' } = req.query;
    
    const database = getDB();
    let jobs = [];
    
    if (database.type === 'firebase') {
      const snapshot = await database.db.collection('printJobs')
        .where('targetPrinterId', '==', printerId)
        .where('status', '==', status)
        .orderBy('priority')
        .orderBy('createdAt')
        .limit(10)
        .get();
      
      snapshot.forEach(doc => {
        jobs.push({ id: doc.id, ...doc.data() });
      });
    } else {
      jobs = Array.from(database.db.printJobs.values())
        .filter(job => job.targetPrinterId === printerId && job.status === status)
        .sort((a, b) => a.priority - b.priority || new Date(a.createdAt) - new Date(b.createdAt))
        .slice(0, 10);
    }
    
    res.json({
      success: true,
      jobs,
      count: jobs.length
    });
    
  } catch (error) {
    console.error('❌ Error getting print jobs:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Update print job status
app.put('/api/print-jobs/:jobId/status', async (req, res) => {
  try {
    const { jobId } = req.params;
    const { status, error } = req.body;
    
    if (!status) {
      return res.status(400).json({
        success: false,
        error: 'Status is required'
      });
    }
    
    const updateData = {
      status,
      updatedAt: new Date().toISOString()
    };
    
    if (error) {
      updateData.error = error;
    }
    
    const database = getDB();
    
    if (database.type === 'firebase') {
      await database.db.collection('printJobs').doc(jobId).update(updateData);
    } else {
      const job = database.db.printJobs.get(jobId);
      if (job) {
        database.db.printJobs.set(jobId, { ...job, ...updateData });
      }
    }
    
    console.log(`✅ Print job ${jobId} status updated to: ${status}`);
    
    res.json({
      success: true,
      message: 'Print job status updated',
      jobId,
      status
    });
    
  } catch (error) {
    console.error('❌ Error updating print job status:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Get status updates for restaurant
app.get('/api/status', async (req, res) => {
  try {
    const { restaurantId } = req.query;
    
    if (!restaurantId) {
      return res.status(400).json({
        success: false,
        error: 'restaurantId is required'
      });
    }
    
    const database = getDB();
    let confirmations = [];
    let failures = [];
    
    if (database.type === 'firebase') {
      const snapshot = await database.db.collection('printJobs')
        .where('restaurantId', '==', restaurantId)
        .where('status', 'in', ['completed', 'failed'])
        .where('updatedAt', '>', new Date(Date.now() - 5 * 60 * 1000).toISOString()) // Last 5 minutes
        .get();
      
      snapshot.forEach(doc => {
        const job = { id: doc.id, ...doc.data() };
        if (job.status === 'completed') {
          confirmations.push(job);
        } else {
          failures.push(job);
        }
      });
    } else {
      const recentJobs = Array.from(database.db.printJobs.values())
        .filter(job => 
          job.restaurantId === restaurantId && 
          ['completed', 'failed'].includes(job.status) &&
          new Date(job.updatedAt) > new Date(Date.now() - 5 * 60 * 1000)
        );
      
      confirmations = recentJobs.filter(job => job.status === 'completed');
      failures = recentJobs.filter(job => job.status === 'failed');
    }
    
    res.json({
      success: true,
      orderConfirmations: confirmations,
      failedOrders: failures,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ Error getting status updates:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Get restaurant statistics
app.get('/api/restaurants/:restaurantId/stats', async (req, res) => {
  try {
    const { restaurantId } = req.params;
    
    const database = getDB();
    let stats = {
      totalJobs: 0,
      completedJobs: 0,
      failedJobs: 0,
      pendingJobs: 0,
      printers: 0
    };
    
    if (database.type === 'firebase') {
      const jobsSnapshot = await database.db.collection('printJobs')
        .where('restaurantId', '==', restaurantId)
        .get();
      
      const printersSnapshot = await database.db.collection('printers')
        .where('restaurantId', '==', restaurantId)
        .get();
      
      jobsSnapshot.forEach(doc => {
        const job = doc.data();
        stats.totalJobs++;
        stats[`${job.status}Jobs`]++;
      });
      
      stats.printers = printersSnapshot.size;
    } else {
      const jobs = Array.from(database.db.printJobs.values())
        .filter(job => job.restaurantId === restaurantId);
      
      const printers = Array.from(database.db.printers.values())
        .filter(printer => printer.restaurantId === restaurantId);
      
      jobs.forEach(job => {
        stats.totalJobs++;
        stats[`${job.status}Jobs`]++;
      });
      
      stats.printers = printers.length;
    }
    
    res.json({
      success: true,
      restaurantId,
      stats,
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ Error getting restaurant stats:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('❌ Unhandled error:', error);
  res.status(500).json({
    success: false,
    error: 'Internal server error'
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Endpoint not found'
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`🆓 Free Restaurant Printing API running on port ${PORT}`);
  console.log(`📊 Health check: http://localhost:${PORT}/api/health`);
  console.log(`💡 Database: ${getDB().type}`);
});

module.exports = app; 