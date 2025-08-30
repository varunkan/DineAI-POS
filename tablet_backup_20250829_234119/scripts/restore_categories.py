#!/usr/bin/env python3
"""
Categories Restore Script
Generated on: 2025-08-29 23:41:19
"""

import sqlite3
import uuid
from datetime import datetime

def restore_categories():
    """Restore all categories from tablet backup"""
    
    DB_PATH = "restaurant_ohbombaymilton_at_gmail_com.db"
    
    categories = [
    {
        "id": "cat_appetizers_1756196398460",
        "name": "Appetizers & Starters",
        "description": "Delicious starters to begin your meal",
        "image_url": null,
        "is_active": 1,
        "sort_order": 1,
        "created_at": "2025-08-26T04:19:58.460761",
        "updated_at": "2025-08-26T04:19:58.460764"
    },
    {
        "id": "cat_beverages_1756196398460",
        "name": "Beverages",
        "description": "Refreshing drinks and hot beverages",
        "image_url": null,
        "is_active": 1,
        "sort_order": 7,
        "created_at": "2025-08-26T04:19:58.460774",
        "updated_at": "2025-08-26T04:19:58.460774"
    },
    {
        "id": "cat_breads_1756196398460",
        "name": "Breads & Rice",
        "description": "Fresh breads and aromatic rice dishes",
        "image_url": null,
        "is_active": 1,
        "sort_order": 5,
        "created_at": "2025-08-26T04:19:58.460770",
        "updated_at": "2025-08-26T04:19:58.460771"
    },
    {
        "id": "cat_desserts_1756196398460",
        "name": "Desserts",
        "description": "Sweet endings to your meal",
        "image_url": null,
        "is_active": 1,
        "sort_order": 6,
        "created_at": "2025-08-26T04:19:58.460772",
        "updated_at": "2025-08-26T04:19:58.460772"
    },
    {
        "id": "cat_main_course_1756196398460",
        "name": "Main Course",
        "description": "Delicious main dishes",
        "image_url": null,
        "is_active": 1,
        "sort_order": 3,
        "created_at": "2025-08-26T04:19:58.460767",
        "updated_at": "2025-08-26T04:19:58.460768"
    },
    {
        "id": "cat_sides_1756196398460",
        "name": "Side Dishes",
        "description": "Perfect accompaniments to your main course",
        "image_url": null,
        "is_active": 1,
        "sort_order": 4,
        "created_at": "2025-08-26T04:19:58.460769",
        "updated_at": "2025-08-26T04:19:58.460769"
    },
    {
        "id": "cat_soups_1756196398460",
        "name": "Soups & Salads",
        "description": "Fresh soups and healthy salads",
        "image_url": null,
        "is_active": 1,
        "sort_order": 2,
        "created_at": "2025-08-26T04:19:58.460765",
        "updated_at": "2025-08-26T04:19:58.460766"
    },
    {
        "id": "cat_specials_1756196398460",
        "name": "Chef Specials",
        "description": "Unique dishes created by our chef",
        "image_url": null,
        "is_active": 1,
        "sort_order": 8,
        "created_at": "2025-08-26T04:19:58.460775",
        "updated_at": "2025-08-26T04:19:58.460775"
    }
]
    
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        print(f"Restoring {len(categories)} categories...")
        
        for category in categories:
            try:
                cursor.execute("""
                    INSERT OR REPLACE INTO categories (
                        id, name, description, color, icon, sort_order, is_active, 
                        created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    category.get('id', str(uuid.uuid4())),
                    category.get('name', ''),
                    category.get('description', ''),
                    category.get('color', '#FF6B6B'),
                    category.get('icon', '🍽️'),
                    category.get('sort_order', 0),
                    category.get('is_active', 1),
                    category.get('created_at', datetime.now().isoformat()),
                    category.get('updated_at', datetime.now().isoformat())
                ))
                
                print(f"Restored category: {category.get('name', 'Unknown')}")
                
            except Exception as e:
                print(f"Error restoring category {category.get('name', 'Unknown')}: {e}")
        
        conn.commit()
        conn.close()
        print("Categories restoration completed!")
        
    except Exception as e:
        print(f"Error restoring categories: {e}")

if __name__ == "__main__":
    restore_categories()
