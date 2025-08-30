#!/usr/bin/env node

const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin SDK
// This will use the default credentials from gcloud auth
admin.initializeApp({
  projectId: 'dineai-pos-system'
});

const db = admin.firestore();

async function clearFirebaseOrders(tenantId) {
  console.log(`🚀 Starting Firebase orders cleanup for tenant: ${tenantId}`);
  
  try {
    // Get tenant reference
    const tenantRef = db.collection('tenants').doc(tenantId);
    
    // Check if tenant exists
    const tenantDoc = await tenantRef.get();
    if (!tenantDoc.exists) {
      console.log(`❌ Tenant ${tenantId} not found in Firebase`);
      return;
    }
    
    console.log(`✅ Found tenant: ${tenantId}`);
    
    let totalOrdersDeleted = 0;
    let totalOrderItemsDeleted = 0;
    
    // Delete all orders from tenant's orders collection
    console.log(`🗑️  Deleting orders...`);
    const ordersSnapshot = await tenantRef.collection('orders').get();
    
    if (ordersSnapshot.empty) {
      console.log(`ℹ️  No orders found to delete`);
    } else {
      console.log(`📋 Found ${ordersSnapshot.size} orders to delete`);
      
      const orderDeletionPromises = ordersSnapshot.docs.map(async (orderDoc) => {
        const orderId = orderDoc.id;
        console.log(`  🗑️  Deleting order: ${orderId}`);
        
        // Delete all order items for this order
        const orderItemsSnapshot = await orderDoc.ref.collection('order_items').get();
        let orderItemsDeleted = 0;
        
        if (!orderItemsSnapshot.empty) {
          const orderItemDeletionPromises = orderItemsSnapshot.docs.map(async (itemDoc) => {
            console.log(`    🗑️  Deleting order item: ${itemDoc.id}`);
            await itemDoc.ref.delete();
            orderItemsDeleted++;
          });
          
          await Promise.all(orderItemDeletionPromises);
        }
        
        // Delete the order itself
        await orderDoc.ref.delete();
        totalOrdersDeleted++;
        totalOrderItemsDeleted += orderItemsDeleted;
        
        console.log(`  ✅ Deleted order ${orderId} with ${orderItemsDeleted} items`);
      });
      
      await Promise.all(orderDeletionPromises);
    }
    
    // Also check for any orphaned order items in the main order_items collection under tenant
    console.log(`🔍 Checking for orphaned order items...`);
    const orphanedOrderItemsSnapshot = await tenantRef.collection('order_items').get();
    
    if (!orphanedOrderItemsSnapshot.empty) {
      console.log(`📋 Found ${orphanedOrderItemsSnapshot.size} orphaned order items to delete`);
      
      const orphanedDeletionPromises = orphanedOrderItemsSnapshot.docs.map(async (itemDoc) => {
        console.log(`  🗑️  Deleting orphaned order item: ${itemDoc.id}`);
        await itemDoc.ref.delete();
        totalOrderItemsDeleted++;
      });
      
      await Promise.all(orphanedDeletionPromises);
    } else {
      console.log(`ℹ️  No orphaned order items found`);
    }
    
    console.log(`\n✅ Firebase orders cleanup completed successfully!`);
    console.log(`📊 Summary:`);
    console.log(`   - Orders deleted: ${totalOrdersDeleted}`);
    console.log(`   - Order items deleted: ${totalOrderItemsDeleted}`);
    console.log(`   - Tenant: ${tenantId}`);
    
  } catch (error) {
    console.error(`❌ Error during Firebase orders cleanup:`, error);
    process.exit(1);
  }
}

// Get tenant ID from command line argument
const tenantId = process.argv[2];

if (!tenantId) {
  console.log(`❌ Usage: node clear_firebase_orders.js <tenant_id>`);
  console.log(`   Example: node clear_firebase_orders.js ohbombaymilton@gmail.com`);
  process.exit(1);
}

// Run the cleanup
clearFirebaseOrders(tenantId)
  .then(() => {
    console.log(`\n🎉 Orders cleanup completed!`);
    process.exit(0);
  })
  .catch((error) => {
    console.error(`💥 Fatal error:`, error);
    process.exit(1);
  }); 