#!/usr/bin/env node

const admin = require('firebase-admin');
const fs = require('fs');

// Initialize Firebase Admin SDK
// This will use the default credentials from gcloud auth
admin.initializeApp({
  projectId: 'dineai-pos-system'
});

const db = admin.firestore();

async function clearFirebaseMenu(tenantId, keepCategories = ['Snacks', 'Receipts']) {
  console.log(`🚀 Starting Firebase menu cleanup for tenant: ${tenantId}`);
  console.log(`📋 Categories to keep: ${keepCategories.join(', ')}`);
  
  try {
    // Get tenant reference
    const tenantRef = db.collection('tenants').doc(tenantId);
    
    // Check if tenant exists
    const tenantDoc = await tenantRef.get();
    if (!tenantDoc.exists) {
      console.log(`❌ Tenant ${tenantId} not found in Firebase`);
      return false;
    }
    console.log(`✅ Found tenant: ${tenantId}`);
    
    // Get collections
    const categoriesRef = tenantRef.collection('categories');
    const menuItemsRef = tenantRef.collection('menu_items');
    
    // Get all categories
    console.log('\n📂 Fetching categories...');
    const categoriesSnapshot = await categoriesRef.get();
    const categories = categoriesSnapshot.docs;
    console.log(`Found ${categories.length} categories`);
    
    // Filter categories
    const categoriesToDelete = [];
    const keptCategories = [];
    const keptCategoryIds = new Set();
    
    for (const cat of categories) {
      const catData = cat.data();
      const catName = catData.name || '';
      
      if (keepCategories.includes(catName)) {
        keptCategories.push(catName);
        keptCategoryIds.add(cat.id);
        console.log(`✅ Keeping category: ${catName}`);
      } else {
        categoriesToDelete.push(cat);
        console.log(`🗑️  Will delete category: ${catName}`);
      }
    }
    
    // Delete categories and their menu items
    console.log(`\n🗑️  Deleting ${categoriesToDelete.length} categories...`);
    let deletedMenuItems = 0;
    let deletedCategories = 0;
    
    for (const cat of categoriesToDelete) {
      const catData = cat.data();
      const catName = catData.name || '';
      const catId = cat.id;
      
      // Delete menu items in this category
      const menuItemsSnapshot = await menuItemsRef.where('categoryId', '==', catId).get();
      const itemsInCategory = menuItemsSnapshot.docs;
      
      if (itemsInCategory.length > 0) {
        console.log(`  🗑️  Deleting ${itemsInCategory.length} menu items from category '${catName}'`);
        
        const deletePromises = itemsInCategory.map(item => item.ref.delete());
        await Promise.all(deletePromises);
        deletedMenuItems += itemsInCategory.length;
      }
      
      // Delete the category
      await cat.ref.delete();
      deletedCategories++;
      console.log(`  ✅ Deleted category: ${catName}`);
    }
    
    // Delete orphaned menu items (not in kept categories)
    console.log('\n🔍 Checking for orphaned menu items...');
    const allMenuItemsSnapshot = await menuItemsRef.get();
    const allMenuItems = allMenuItemsSnapshot.docs;
    const orphanedItems = [];
    
    for (const item of allMenuItems) {
      const itemData = item.data();
      const categoryId = itemData.categoryId || '';
      
      if (!keptCategoryIds.has(categoryId)) {
        orphanedItems.push(item);
      }
    }
    
    if (orphanedItems.length > 0) {
      console.log(`🗑️  Deleting ${orphanedItems.length} orphaned menu items...`);
      
      const deletePromises = orphanedItems.map(item => {
        const itemData = item.data();
        const itemName = itemData.name || 'Unknown';
        console.log(`  🗑️  Deleting orphaned item: ${itemName}`);
        return item.ref.delete();
      });
      
      await Promise.all(deletePromises);
      deletedMenuItems += orphanedItems.length;
    }
    
    // Verify final state
    const remainingCategoriesSnapshot = await categoriesRef.get();
    const remainingItemsSnapshot = await menuItemsRef.get();
    
    console.log(`\n✅ Cleanup completed successfully!`);
    console.log(`📊 Summary:`);
    console.log(`   • Deleted categories: ${deletedCategories}`);
    console.log(`   • Deleted menu items: ${deletedMenuItems}`);
    console.log(`   • Kept categories: ${keptCategories.join(', ')}`);
    
    console.log(`\n📋 Final state:`);
    console.log(`   • Remaining categories: ${remainingCategoriesSnapshot.size}`);
    remainingCategoriesSnapshot.forEach(cat => {
      const catData = cat.data();
      console.log(`     - ${catData.name || 'Unknown'}`);
    });
    
    console.log(`   • Remaining menu items: ${remainingItemsSnapshot.size}`);
    
    return true;
    
  } catch (error) {
    console.error(`❌ Error during cleanup:`, error);
    return false;
  }
}

// Main execution
async function main() {
  const tenantId = 'ohbombaymilton@gmail.com';
  const keepCategories = ['Snacks', 'Receipts'];
  
  console.log('⚠️  SAFETY WARNING: This will delete most menu items and categories!');
  console.log(`📋 Will keep only: ${keepCategories.join(', ')}`);
  console.log(`🎯 Target tenant: ${tenantId}`);
  console.log('\nStarting cleanup in 3 seconds...');
  
  // Wait 3 seconds for safety
  await new Promise(resolve => setTimeout(resolve, 3000));
  
  const success = await clearFirebaseMenu(tenantId, keepCategories);
  
  if (success) {
    console.log('\n🎉 Firebase cleanup completed successfully!');
    process.exit(0);
  } else {
    console.log('\n💥 Firebase cleanup failed!');
    process.exit(1);
  }
}

// Run the script
main().catch(error => {
  console.error('💥 Script failed:', error);
  process.exit(1);
}); 