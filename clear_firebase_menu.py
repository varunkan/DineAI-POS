#!/usr/bin/env python3
"""
Clear all menu items and categories from Firebase except "Snacks" and "Receipts"
"""

import firebase_admin
from firebase_admin import credentials, firestore
import argparse
import sys
from datetime import datetime

def clear_firebase_menu(tenant_id, keep_categories=None):
    """
    Clear all menu items and categories from Firebase except specified categories
    
    Args:
        tenant_id (str): The tenant ID (e.g., 'ohbombaymilton@gmail.com')
        keep_categories (list): List of category names to keep
    """
    if keep_categories is None:
        keep_categories = ["Snacks", "Receipts"]
    
    print(f"🚀 Starting Firebase menu cleanup for tenant: {tenant_id}")
    print(f"📋 Categories to keep: {', '.join(keep_categories)}")
    
    # Initialize Firebase
    try:
        db = firestore.client()
        print("✅ Connected to Firebase")
    except Exception as e:
        print(f"❌ Failed to connect to Firebase: {e}")
        return False
    
    # Get tenant collections
    tenant_ref = db.collection('tenants').document(tenant_id)
    
    try:
        # Check if tenant exists
        tenant_doc = tenant_ref.get()
        if not tenant_doc.exists:
            print(f"❌ Tenant {tenant_id} not found in Firebase")
            return False
        print(f"✅ Found tenant: {tenant_id}")
    except Exception as e:
        print(f"❌ Error checking tenant: {e}")
        return False
    
    # Get categories collection
    categories_ref = tenant_ref.collection('categories')
    menu_items_ref = tenant_ref.collection('menu_items')
    
    deleted_categories = 0
    deleted_menu_items = 0
    kept_categories = []
    
    try:
        # First, get all categories
        print("\n📂 Fetching categories...")
        categories = list(categories_ref.stream())
        print(f"Found {len(categories)} categories")
        
        # Filter categories to keep
        categories_to_delete = []
        for cat in categories:
            cat_data = cat.to_dict()
            cat_name = cat_data.get('name', '')
            if cat_name in keep_categories:
                kept_categories.append(cat_name)
                print(f"✅ Keeping category: {cat_name}")
            else:
                categories_to_delete.append(cat)
                print(f"🗑️  Will delete category: {cat_name}")
        
        # Delete categories (this will cascade delete menu items)
        print(f"\n🗑️  Deleting {len(categories_to_delete)} categories...")
        for cat in categories_to_delete:
            cat_data = cat.to_dict()
            cat_name = cat_data.get('name', '')
            cat_id = cat.id
            
            # Delete all menu items in this category first
            menu_items_in_category = menu_items_ref.where('categoryId', '==', cat_id).stream()
            items_in_category = list(menu_items_in_category)
            
            if items_in_category:
                print(f"  🗑️  Deleting {len(items_in_category)} menu items from category '{cat_name}'")
                for item in items_in_category:
                    item.delete()
                    deleted_menu_items += 1
            
            # Delete the category
            cat.reference.delete()
            deleted_categories += 1
            print(f"  ✅ Deleted category: {cat_name}")
        
        # Also delete any orphaned menu items (not in kept categories)
        print("\n🔍 Checking for orphaned menu items...")
        all_menu_items = list(menu_items_ref.stream())
        orphaned_items = []
        
        for item in all_menu_items:
            item_data = item.to_dict()
            category_id = item_data.get('categoryId', '')
            
            # Check if this item belongs to a kept category
            belongs_to_kept_category = False
            for cat in categories:
                cat_data = cat.to_dict()
                if cat.id == category_id and cat_data.get('name', '') in keep_categories:
                    belongs_to_kept_category = True
                    break
            
            if not belongs_to_kept_category:
                orphaned_items.append(item)
        
        if orphaned_items:
            print(f"🗑️  Deleting {len(orphaned_items)} orphaned menu items...")
            for item in orphaned_items:
                item_data = item.to_dict()
                item_name = item_data.get('name', 'Unknown')
                item.delete()
                deleted_menu_items += 1
                print(f"  🗑️  Deleted orphaned item: {item_name}")
        
        print(f"\n✅ Cleanup completed successfully!")
        print(f"📊 Summary:")
        print(f"   • Deleted categories: {deleted_categories}")
        print(f"   • Deleted menu items: {deleted_menu_items}")
        print(f"   • Kept categories: {', '.join(kept_categories)}")
        
        # Verify final state
        remaining_categories = list(categories_ref.stream())
        remaining_items = list(menu_items_ref.stream())
        
        print(f"\n📋 Final state:")
        print(f"   • Remaining categories: {len(remaining_categories)}")
        for cat in remaining_categories:
            cat_data = cat.to_dict()
            print(f"     - {cat_data.get('name', 'Unknown')}")
        
        print(f"   • Remaining menu items: {len(remaining_items)}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error during cleanup: {e}")
        return False

def main():
    parser = argparse.ArgumentParser(description='Clear Firebase menu items and categories')
    parser.add_argument('--tenant', required=True, help='Tenant ID (e.g., ohbombaymilton@gmail.com)')
    parser.add_argument('--keep', nargs='+', default=['Snacks', 'Receipts'], 
                       help='Categories to keep (default: Snacks Receipts)')
    parser.add_argument('--confirm', action='store_true', 
                       help='Confirm the operation (required for safety)')
    
    args = parser.parse_args()
    
    if not args.confirm:
        print("⚠️  SAFETY WARNING: This will delete most menu items and categories!")
        print(f"📋 Will keep only: {', '.join(args.keep)}")
        print(f"🎯 Target tenant: {args.tenant}")
        print("\nTo proceed, add --confirm flag")
        sys.exit(1)
    
    # Initialize Firebase Admin SDK
    try:
        # Try to get default credentials
        firebase_admin.get_app()
        print("✅ Using existing Firebase app")
    except ValueError:
        # Initialize with default credentials
        try:
            cred = credentials.ApplicationDefault()
            firebase_admin.initialize_app(cred)
            print("✅ Initialized Firebase with default credentials")
        except Exception as e:
            print(f"❌ Failed to initialize Firebase: {e}")
            print("Make sure GOOGLE_APPLICATION_CREDENTIALS is set")
            sys.exit(1)
    
    success = clear_firebase_menu(args.tenant, args.keep)
    
    if success:
        print("\n🎉 Firebase cleanup completed successfully!")
        sys.exit(0)
    else:
        print("\n💥 Firebase cleanup failed!")
        sys.exit(1)

if __name__ == "__main__":
    main() 