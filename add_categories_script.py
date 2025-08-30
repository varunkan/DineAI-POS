#!/usr/bin/env python3
"""
Script to add all categories from the Oh Bombay menu to the AI POS System
"""

import sqlite3
import uuid
from datetime import datetime
import os

# Database path - adjust this to match your app's database location
DB_PATH = "restaurant_ohbombaymilton_at_gmail_com.db"

def create_categories():
    """Create all categories from the Oh Bombay menu"""
    
    categories = [
        {
            "id": f"cat_soups_{int(datetime.now().timestamp() * 1000)}",
            "name": "SOUPS",
            "description": "Hot and cold soups including Manchow, Cream of Tomato, and more",
            "color": "#FF6B6B",
            "icon": "🍲",
            "sort_order": 1,
            "is_active": True
        },
        {
            "id": f"cat_breads_{int(datetime.now().timestamp() * 1000)}",
            "name": "BREADS",
            "description": "Fresh Indian breads including Naan, Roti, Paratha, and Kulcha",
            "color": "#FFE66D",
            "icon": "🫓",
            "sort_order": 2,
            "is_active": True
        },
        {
            "id": f"cat_kids_menu_{int(datetime.now().timestamp() * 1000)}",
            "name": "KIDS MENU",
            "description": "Kid-friendly dishes with mild flavors and smaller portions",
            "color": "#4ECDC4",
            "icon": "👶",
            "sort_order": 3,
            "is_active": True
        },
        {
            "id": f"cat_main_course_non_veg_{int(datetime.now().timestamp() * 1000)}",
            "name": "MAIN COURSE - NON VEG",
            "description": "Non-vegetarian main dishes including chicken, goat, and fish curries",
            "color": "#FF8A80",
            "icon": "🍗",
            "sort_order": 4,
            "is_active": True
        },
        {
            "id": f"cat_main_course_veg_{int(datetime.now().timestamp() * 1000)}",
            "name": "MAIN COURSE - VEG",
            "description": "Vegetarian main dishes including paneer, dal, and vegetable curries",
            "color": "#81C784",
            "icon": "🥬",
            "sort_order": 5,
            "is_active": True
        },
        {
            "id": f"cat_starter_non_veg_{int(datetime.now().timestamp() * 1000)}",
            "name": "STARTER - NON VEG",
            "description": "Non-vegetarian appetizers and kebabs",
            "color": "#FFB74D",
            "icon": "🍖",
            "sort_order": 6,
            "is_active": True
        },
        {
            "id": f"cat_starter_veg_{int(datetime.now().timestamp() * 1000)}",
            "name": "STARTER - VEG",
            "description": "Vegetarian appetizers and kebabs",
            "color": "#A5D6A7",
            "icon": "🥗",
            "sort_order": 7,
            "is_active": True
        },
        {
            "id": f"cat_starter_hakka_{int(datetime.now().timestamp() * 1000)}",
            "name": "STARTER - HAKKA",
            "description": "Chinese-style appetizers and Hakka dishes",
            "color": "#FFCC02",
            "icon": "🥢",
            "sort_order": 8,
            "is_active": True
        },
        {
            "id": f"cat_momos_{int(datetime.now().timestamp() * 1000)}",
            "name": "MOMOS (DUMPLINGS)",
            "description": "Steamed and fried dumplings with various fillings and sauces",
            "color": "#E1BEE7",
            "icon": "🥟",
            "sort_order": 9,
            "is_active": True
        },
        {
            "id": f"cat_snacks_{int(datetime.now().timestamp() * 1000)}",
            "name": "SNACKS",
            "description": "Indian street food and snacks including Samosa, Vada Pav, and Chaat",
            "color": "#FFAB91",
            "icon": "🍿",
            "sort_order": 10,
            "is_active": True
        }
    ]
    
    return categories

def add_categories_to_database(categories):
    """Add categories to the SQLite database"""
    
    try:
        # Connect to the database
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        print(f"🔗 Connected to database: {DB_PATH}")
        
        # Check if categories table exists
        cursor.execute("""
            SELECT name FROM sqlite_master 
            WHERE type='table' AND name='categories'
        """)
        
        if not cursor.fetchone():
            print("❌ Categories table not found!")
            print("Make sure you're running this script in the correct directory with the app database")
            return False
        
        # Insert categories
        for category in categories:
            try:
                cursor.execute("""
                    INSERT INTO categories (
                        id, name, description, color, icon, sort_order, 
                        is_active, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    category["id"],
                    category["name"],
                    category["description"],
                    category["color"],
                    category["icon"],
                    category["sort_order"],
                    category["is_active"],
                    datetime.now().isoformat(),
                    datetime.now().isoformat()
                ))
                
                print(f"✅ Added category: {category['name']} ({category['icon']})")
                
            except sqlite3.IntegrityError as e:
                if "UNIQUE constraint failed" in str(e):
                    print(f"⚠️  Category already exists: {category['name']}")
                else:
                    print(f"❌ Error adding category {category['name']}: {e}")
            except Exception as e:
                print(f"❌ Error adding category {category['name']}: {e}")
        
        # Commit changes
        conn.commit()
        print(f"\n🎉 Successfully added {len(categories)} categories to the database!")
        
        # Show summary
        cursor.execute("SELECT COUNT(*) FROM categories")
        total_categories = cursor.fetchone()[0]
        print(f"📊 Total categories in database: {total_categories}")
        
        return True
        
    except sqlite3.Error as e:
        print(f"❌ Database error: {e}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        return False
    finally:
        if conn:
            conn.close()

def find_database_file():
    """Try to find the database file in common locations"""
    
    possible_paths = [
        "restaurant_ohbombaymilton_at_gmail_com.db",
        "app.db",
        "database.db",
        "pos_system.db",
        "flutter.db",
        "ai_pos_system.db"
    ]
    
    # Also check in subdirectories
    for root, dirs, files in os.walk("."):
        for file in files:
            if file.endswith(".db"):
                possible_paths.append(os.path.join(root, file))
    
    print("🔍 Searching for database files...")
    for path in possible_paths:
        if os.path.exists(path):
            print(f"📁 Found database: {path}")
            return path
    
    print("❌ No database file found!")
    print("Please make sure you're running this script in the correct directory")
    return None

def main():
    """Main function"""
    
    print("🍽️  Oh Bombay Menu Categories Import Script")
    print("=" * 50)
    
    # Find database file
    db_path = find_database_file()
    if not db_path:
        print("\n💡 To use this script:")
        print("1. Copy this script to your app's database directory")
        print("2. Or update the DB_PATH variable in the script")
        print("3. Run: python3 add_categories_script.py")
        return
    
    # Update global DB_PATH
    global DB_PATH
    DB_PATH = db_path
    
    # Create categories
    categories = create_categories()
    
    print(f"\n📋 Found {len(categories)} categories to add:")
    for i, category in enumerate(categories, 1):
        print(f"  {i}. {category['icon']} {category['name']}")
    
    # Confirm with user
    response = input(f"\n🤔 Add these {len(categories)} categories to the database? (y/N): ")
    if response.lower() not in ['y', 'yes']:
        print("❌ Operation cancelled")
        return
    
    # Add categories to database
    print("\n🚀 Adding categories to database...")
    success = add_categories_to_database(categories)
    
    if success:
        print("\n✅ Categories import completed successfully!")
        print("\n🎯 Next steps:")
        print("1. Restart your Flutter app")
        print("2. Go to Admin Panel > Categories")
        print("3. Verify all categories are displayed")
        print("4. Start adding menu items to each category")
    else:
        print("\n❌ Categories import failed!")
        print("Please check the error messages above")

if __name__ == "__main__":
    main() 