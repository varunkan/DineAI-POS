#!/usr/bin/env python3
"""
Extract Data from Existing Backup Database
Creates backup scripts from the existing database backup
"""

import sqlite3
import json
import os
from datetime import datetime

def extract_from_backup():
    """Extract data from existing backup database"""
    
    # Path to the backup database
    backup_db_path = "backups/emulator-5556/20250829-122947/databases/restaurant_ohbombaymilton_at_gmail_com.db"
    
    if not os.path.exists(backup_db_path):
        print(f"❌ Database not found: {backup_db_path}")
        return False
    
    backup_dir = f"tablet_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    
    print("🚀 Starting data extraction from backup database...")
    
    # Create backup directory
    os.makedirs(backup_dir, exist_ok=True)
    os.makedirs(f"{backup_dir}/scripts", exist_ok=True)
    os.makedirs(f"{backup_dir}/data", exist_ok=True)
    
    print(f"📁 Created backup directory: {backup_dir}")
    
    # Copy the database file
    import shutil
    shutil.copy2(backup_db_path, f"{backup_dir}/data/restaurant_ohbombaymilton_at_gmail_com.db")
    print(f"📋 Copied database to: {backup_dir}/data/restaurant_ohbombaymilton_at_gmail_com.db")
    
    # Extract data from database
    print(f"📊 Extracting data from: {backup_db_path}")
    
    try:
        conn = sqlite3.connect(backup_db_path)
        cursor = conn.cursor()
        
        # Get all table names
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = cursor.fetchall()
        
        extracted_data = {}
        
        for table in tables:
            table_name = table[0]
            print(f"📋 Extracting table: {table_name}")
            
            try:
                cursor.execute(f"SELECT * FROM {table_name}")
                rows = cursor.fetchall()
                
                # Get column names
                cursor.execute(f"PRAGMA table_info({table_name})")
                columns = [col[1] for col in cursor.fetchall()]
                
                # Convert rows to dictionaries
                table_data = []
                for row in rows:
                    row_dict = dict(zip(columns, row))
                    table_data.append(row_dict)
                
                extracted_data[table_name] = {
                    'columns': columns,
                    'data': table_data,
                    'count': len(table_data)
                }
                
                print(f"   ✅ Extracted {len(table_data)} rows")
                
            except Exception as e:
                print(f"   ❌ Error extracting {table_name}: {e}")
                extracted_data[table_name] = {
                    'error': str(e),
                    'data': [],
                    'count': 0
                }
        
        conn.close()
        
        # Save extracted data
        with open(f"{backup_dir}/data/extracted_data.json", 'w') as f:
            json.dump(extracted_data, f, indent=2, default=str)
        
        print(f"💾 Saved extracted data to: {backup_dir}/data/extracted_data.json")
        
        # Create restore scripts
        create_restore_scripts(backup_dir, extracted_data)
        
        # Create README
        create_readme(backup_dir, extracted_data)
        
        print(f"\n🎉 Extraction completed successfully!")
        print(f"📁 Backup location: {backup_dir}")
        print(f"📊 Total tables extracted: {len(extracted_data)}")
        
        total_records = sum(
            table_info.get('count', 0) 
            for table_info in extracted_data.values() 
            if 'error' not in table_info
        )
        print(f"📈 Total records: {total_records}")
        
        return True
        
    except Exception as e:
        print(f"❌ Error extracting data: {e}")
        return False

def create_restore_scripts(backup_dir, extracted_data):
    """Create restore scripts for the extracted data"""
    
    # Create categories restore script
    if 'categories' in extracted_data and 'error' not in extracted_data['categories']:
        categories = extracted_data['categories']['data']
        
        script_content = f'''#!/usr/bin/env python3
"""
Categories Restore Script
Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
"""

import sqlite3
import uuid
from datetime import datetime

def restore_categories():
    """Restore all categories from tablet backup"""
    
    DB_PATH = "restaurant_ohbombaymilton_at_gmail_com.db"
    
    categories = {json.dumps(categories, indent=4)}
    
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
                
                print(f"Restored category: {{category.get('name', 'Unknown')}}")
                
            except Exception as e:
                print(f"Error restoring category {{category.get('name', 'Unknown')}}: {{e}}")
        
        conn.commit()
        conn.close()
        print("Categories restoration completed!")
        
    except Exception as e:
        print(f"Error restoring categories: {{e}}")

if __name__ == "__main__":
    restore_categories()
'''
        
        with open(f"{backup_dir}/scripts/restore_categories.py", 'w') as f:
            f.write(script_content)
        
        print(f"📝 Created categories restore script: {backup_dir}/scripts/restore_categories.py")
    
    # Create menu items restore script
    if 'menu_items' in extracted_data and 'error' not in extracted_data['menu_items']:
        menu_items = extracted_data['menu_items']['data']
        
        script_content = f'''#!/usr/bin/env python3
"""
Menu Items Restore Script
Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
"""

import sqlite3
import uuid
import json
from datetime import datetime

def restore_menu_items():
    """Restore all menu items from tablet backup"""
    
    DB_PATH = "restaurant_ohbombaymilton_at_gmail_com.db"
    
    menu_items = {json.dumps(menu_items, indent=4)}
    
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        print(f"Restoring {len(menu_items)} menu items...")
        
        for item in menu_items:
            try:
                cursor.execute("""
                    INSERT OR REPLACE INTO menu_items (
                        id, name, description, price, category_id, tags, custom_properties,
                        variants, modifiers, nutritional_info, allergens, preparation_time,
                        is_vegetarian, is_vegan, is_gluten_free, is_spicy, spice_level,
                        stock_quantity, low_stock_threshold, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    item.get('id', str(uuid.uuid4())),
                    item.get('name', ''),
                    item.get('description', ''),
                    item.get('price', 0.0),
                    item.get('category_id', ''),
                    json.dumps(item.get('tags', [])),
                    json.dumps(item.get('custom_properties', {})),
                    json.dumps(item.get('variants', [])),
                    json.dumps(item.get('modifiers', [])),
                    json.dumps(item.get('nutritional_info', {})),
                    json.dumps(item.get('allergens', {})),
                    item.get('preparation_time', 10),
                    item.get('is_vegetarian', 0),
                    item.get('is_vegan', 0),
                    item.get('is_gluten_free', 0),
                    item.get('is_spicy', 0),
                    item.get('spice_level', 0),
                    item.get('stock_quantity', 100),
                    item.get('low_stock_threshold', 10),
                    item.get('created_at', datetime.now().isoformat()),
                    item.get('updated_at', datetime.now().isoformat())
                ))
                
                print(f"Restored menu item: {{item.get('name', 'Unknown')}}")
                
            except Exception as e:
                print(f"Error restoring menu item {{item.get('name', 'Unknown')}}: {{e}}")
        
        conn.commit()
        conn.close()
        print("Menu items restoration completed!")
        
    except Exception as e:
        print(f"Error restoring menu items: {{e}}")

if __name__ == "__main__":
    restore_menu_items()
'''
        
        with open(f"{backup_dir}/scripts/restore_menu_items.py", 'w') as f:
            f.write(script_content)
        
        print(f"📝 Created menu items restore script: {backup_dir}/scripts/restore_menu_items.py")
    
    # Create comprehensive restore script
    script_content = f'''#!/usr/bin/env python3
"""
Comprehensive Data Restore Script
Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
"""

import sqlite3
import json
import uuid
from datetime import datetime

def restore_all_data():
    """Restore all data from tablet backup"""
    
    DB_PATH = "restaurant_ohbombaymilton_at_gmail_com.db"
    
    # Load extracted data
    with open('data/extracted_data.json', 'r') as f:
        extracted_data = json.load(f)
    
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        print("Starting comprehensive data restoration...")
        
        # Restore each table
        for table_name, table_info in extracted_data.items():
            if 'error' in table_info:
                print(f"Skipping {table_name} due to error: {{table_info['error']}}")
                continue
                
            print(f"Restoring table: {{table_name}} ({{table_info['count']}} records)")
            
            for row in table_info['data']:
                try:
                    # Generate placeholders for INSERT statement
                    columns = table_info['columns']
                    placeholders = ', '.join(['?' for _ in columns])
                    column_names = ', '.join(columns)
                    
                    # Prepare values (handle None values)
                    values = []
                    for col in columns:
                        value = row.get(col)
                        if value is None:
                            value = '' if isinstance(col, str) else 0
                        values.append(value)
                    
                    cursor.execute(f"INSERT OR REPLACE INTO {{table_name}} ({{column_names}}) VALUES ({{placeholders}})", values)
                    
                except Exception as e:
                    print(f"Error restoring row in {{table_name}}: {{e}}")
                    continue
        
        conn.commit()
        conn.close()
        print("Comprehensive data restoration completed!")
        
    except Exception as e:
        print(f"Error during restoration: {{e}}")

if __name__ == "__main__":
    restore_all_data()
'''
    
    with open(f"{backup_dir}/scripts/restore_all_data.py", 'w') as f:
        f.write(script_content)
    
    print(f"📝 Created comprehensive restore script: {backup_dir}/scripts/restore_all_data.py")

def create_readme(backup_dir, extracted_data):
    """Create README with backup information"""
    
    readme_content = f"""# Tablet Data Backup

**Generated on:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
**Source:** Existing backup database

## 📊 Backup Summary

"""
    
    for table_name, table_info in extracted_data.items():
        if 'error' in table_info:
            readme_content += f"- **{table_name}**: ❌ Error - {table_info['error']}\n"
        else:
            readme_content += f"- **{table_name}**: ✅ {table_info['count']} records\n"
    
    readme_content += f"""

## 📁 Files

- `data/extracted_data.json` - Complete extracted data
- `data/restaurant_ohbombaymilton_at_gmail_com.db` - Original database file
- `scripts/restore_categories.py` - Restore categories only
- `scripts/restore_menu_items.py` - Restore menu items only
- `scripts/restore_all_data.py` - Restore all data

## 🚀 Usage

### Restore All Data
```bash
cd {backup_dir}/scripts
python3 restore_all_data.py
```

### Restore Categories Only
```bash
cd {backup_dir}/scripts
python3 restore_categories.py
```

### Restore Menu Items Only
```bash
cd {backup_dir}/scripts
python3 restore_menu_items.py
```

## ⚠️ Important Notes

1. **Backup your current database** before running restore scripts
2. **Adjust database path** in scripts if needed
3. **Test on development environment** first
4. **Check data integrity** after restoration

## 🔧 Troubleshooting

If you encounter issues:

1. Check database file permissions
2. Verify database path in scripts
3. Ensure SQLite3 is installed
4. Check for foreign key constraints
"""
    
    with open(f"{backup_dir}/README.md", 'w') as f:
        f.write(readme_content)
    
    print(f"📝 Created README: {backup_dir}/README.md")

def main():
    success = extract_from_backup()
    
    if success:
        print("\n✅ Backup completed successfully!")
        print("📋 You can now use the restore scripts to restore data when needed.")
    else:
        print("\n❌ Backup failed. Please check the error messages above.")

if __name__ == "__main__":
    main() 