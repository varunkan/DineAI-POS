#!/usr/bin/env python3
"""
Comprehensive Tablet Data Extraction and Backup Script
Extracts all data from the AI POS System tablet database
"""

import sqlite3
import json
import os
import shutil
from datetime import datetime
import subprocess
import sys

class TabletDataExtractor:
    def __init__(self):
        self.device_id = "202525900101062"  # Your tablet device ID
        self.backup_dir = f"tablet_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}"
        self.db_path = None
        
    def create_backup_directory(self):
        """Create backup directory structure"""
        os.makedirs(self.backup_dir, exist_ok=True)
        os.makedirs(f"{self.backup_dir}/scripts", exist_ok=True)
        os.makedirs(f"{self.backup_dir}/data", exist_ok=True)
        print(f"📁 Created backup directory: {self.backup_dir}")
        
    def find_database_files(self):
        """Find database files on the tablet"""
        print("🔍 Searching for database files on tablet...")
        
        # Try different possible database locations
        possible_paths = [
            "/data/data/com.restaurantpos.ai_pos_system/databases/",
            "/storage/emulated/0/Android/data/com.restaurantpos.ai_pos_system/databases/",
            "/data/data/com.restaurantpos.ai_pos_system/app_flutter/",
            "/storage/emulated/0/ai_pos_system/",
        ]
        
        for path in possible_paths:
            try:
                result = subprocess.run([
                    "adb", "-s", self.device_id, "shell", 
                    f"ls {path}*.db 2>/dev/null || echo 'No .db files found'"
                ], capture_output=True, text=True, timeout=10)
                
                if result.stdout and "No .db files found" not in result.stdout:
                    print(f"✅ Found database files in: {path}")
                    print(f"   Files: {result.stdout.strip()}")
                    return path
                    
            except subprocess.TimeoutExpired:
                print(f"⏰ Timeout checking: {path}")
                continue
            except Exception as e:
                print(f"❌ Error checking {path}: {e}")
                continue
                
        print("❌ Could not find database files automatically")
        return None
        
    def extract_database(self):
        """Extract database from tablet"""
        print("📥 Extracting database from tablet...")
        
        # Try to pull database files
        db_files = [
            "restaurant_ohbombaymilton_at_gmail_com.db",
            "ai_pos_system.db",
            "flutter.db",
            "database.db"
        ]
        
        for db_file in db_files:
            try:
                # Try to pull from different locations
                locations = [
                    f"/data/data/com.restaurantpos.ai_pos_system/databases/{db_file}",
                    f"/storage/emulated/0/Android/data/com.restaurantpos.ai_pos_system/databases/{db_file}",
                    f"/data/data/com.restaurantpos.ai_pos_system/app_flutter/{db_file}",
                    f"/storage/emulated/0/ai_pos_system/{db_file}"
                ]
                
                for location in locations:
                    try:
                        result = subprocess.run([
                            "adb", "-s", self.device_id, "pull", 
                            location, f"{self.backup_dir}/data/{db_file}"
                        ], capture_output=True, text=True, timeout=30)
                        
                        if result.returncode == 0 and os.path.exists(f"{self.backup_dir}/data/{db_file}"):
                            print(f"✅ Successfully extracted: {db_file}")
                            self.db_path = f"{self.backup_dir}/data/{db_file}"
                            return True
                            
                    except subprocess.TimeoutExpired:
                        continue
                    except Exception as e:
                        continue
                        
            except Exception as e:
                print(f"❌ Error extracting {db_file}: {e}")
                continue
                
        print("❌ Could not extract database files")
        return False
        
    def extract_data_from_database(self):
        """Extract all data from the database"""
        if not self.db_path or not os.path.exists(self.db_path):
            print("❌ Database file not found")
            return False
            
        print(f"📊 Extracting data from: {self.db_path}")
        
        try:
            conn = sqlite3.connect(self.db_path)
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
            with open(f"{self.backup_dir}/data/extracted_data.json", 'w') as f:
                json.dump(extracted_data, f, indent=2, default=str)
                
            print(f"💾 Saved extracted data to: {self.backup_dir}/data/extracted_data.json")
            return extracted_data
            
        except Exception as e:
            print(f"❌ Error extracting data: {e}")
            return None
            
    def create_categories_script(self, extracted_data):
        """Create script to restore categories"""
        if 'categories' not in extracted_data:
            print("❌ No categories data found")
            return
            
        categories = extracted_data['categories']['data']
        
        script_content = '''#!/usr/bin/env python3
"""
Auto-generated Categories Restore Script
Generated on: ''' + datetime.now().strftime('%Y-%m-%d %H:%M:%S') + '''
"""

import sqlite3
import uuid
from datetime import datetime

def restore_categories():
    """Restore all categories from tablet backup"""
    
    # Database path - adjust as needed
    DB_PATH = "restaurant_ohbombaymilton_at_gmail_com.db"
    
    categories = ''' + json.dumps(categories, indent=8) + '''
    
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        print(f"🔄 Restoring {len(categories)} categories...")
        
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
                
                print(f"✅ Restored category: {category.get('name', 'Unknown')}")
                
            except Exception as e:
                print(f"❌ Error restoring category {category.get('name', 'Unknown')}: {e}")
        
        conn.commit()
        conn.close()
        print("✅ Categories restoration completed!")
        
    except Exception as e:
        print(f"❌ Error restoring categories: {e}")

if __name__ == "__main__":
    restore_categories()
'''
        
        with open(f"{self.backup_dir}/scripts/restore_categories.py", 'w') as f:
            f.write(script_content)
            
        print(f"📝 Created categories restore script: {self.backup_dir}/scripts/restore_categories.py")
        
    def create_menu_items_script(self, extracted_data):
        """Create script to restore menu items"""
        if 'menu_items' not in extracted_data:
            print("❌ No menu items data found")
            return
            
        menu_items = extracted_data['menu_items']['data']
        
        script_content = f'''#!/usr/bin/env python3
"""
Auto-generated Menu Items Restore Script
Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
"""

import sqlite3
import uuid
from datetime import datetime

def restore_menu_items():
    """Restore all menu items from tablet backup"""
    
    # Database path - adjust as needed
    DB_PATH = "restaurant_ohbombaymilton_at_gmail_com.db"
    
    menu_items = {json.dumps(menu_items, indent=8)}
    
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        print(f"🔄 Restoring {len(menu_items)} menu items...")
        
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
                
                print(f"✅ Restored menu item: {{item.get('name', 'Unknown')}}")
                
            except Exception as e:
                print(f"❌ Error restoring menu item {{item.get('name', 'Unknown')}}: {{e}}")
        
        conn.commit()
        conn.close()
        print("✅ Menu items restoration completed!")
        
    except Exception as e:
        print(f"❌ Error restoring menu items: {{e}}")

if __name__ == "__main__":
    restore_menu_items()
'''
        
        with open(f"{self.backup_dir}/scripts/restore_menu_items.py", 'w') as f:
            f.write(script_content)
            
        print(f"📝 Created menu items restore script: {self.backup_dir}/scripts/restore_menu_items.py")
        
    def create_comprehensive_restore_script(self, extracted_data):
        """Create comprehensive restore script for all data"""
        script_content = f'''#!/usr/bin/env python3
"""
Comprehensive Data Restore Script
Restores all data from tablet backup
Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
"""

import sqlite3
import json
import uuid
from datetime import datetime

def restore_all_data():
    """Restore all data from tablet backup"""
    
    # Database path - adjust as needed
    DB_PATH = "restaurant_ohbombaymilton_at_gmail_com.db"
    
    # Load extracted data
    with open('data/extracted_data.json', 'r') as f:
        extracted_data = json.load(f)
    
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        print("🔄 Starting comprehensive data restoration...")
        
        # Restore each table
        for table_name, table_info in extracted_data.items():
            if 'error' in table_info:
                print(f"⚠️ Skipping {table_name} due to error: {{table_info['error']}}")
                continue
                
            print(f"📋 Restoring table: {{table_name}} ({{table_info['count']}} records)")
            
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
                    print(f"❌ Error restoring row in {{table_name}}: {{e}}")
                    continue
        
        conn.commit()
        conn.close()
        print("✅ Comprehensive data restoration completed!")
        
    except Exception as e:
        print(f"❌ Error during restoration: {{e}}")

if __name__ == "__main__":
    restore_all_data()
'''
        
        with open(f"{self.backup_dir}/scripts/restore_all_data.py", 'w') as f:
            f.write(script_content)
            
        print(f"📝 Created comprehensive restore script: {self.backup_dir}/scripts/restore_all_data.py")
        
    def create_readme(self, extracted_data):
        """Create README with backup information"""
        readme_content = f'''# Tablet Data Backup

**Generated on:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
**Device ID:** {self.device_id}

## 📊 Backup Summary

'''
        
        for table_name, table_info in extracted_data.items():
            if 'error' in table_info:
                readme_content += f"- **{table_name}**: ❌ Error - {table_info['error']}\n"
            else:
                readme_content += f"- **{table_name}**: ✅ {table_info['count']} records\n"
                
        readme_content += f'''

## 📁 Files

- `data/extracted_data.json` - Complete extracted data
- `data/*.db` - Original database files
- `scripts/restore_categories.py` - Restore categories only
- `scripts/restore_menu_items.py` - Restore menu items only
- `scripts/restore_all_data.py` - Restore all data

## 🚀 Usage

### Restore All Data
```bash
cd {self.backup_dir}/scripts
python3 restore_all_data.py
```

### Restore Categories Only
```bash
cd {self.backup_dir}/scripts
python3 restore_categories.py
```

### Restore Menu Items Only
```bash
cd {self.backup_dir}/scripts
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
'''
        
        with open(f"{self.backup_dir}/README.md", 'w') as f:
            f.write(readme_content)
            
        print(f"📝 Created README: {self.backup_dir}/README.md")
        
    def run_extraction(self):
        """Run complete extraction process"""
        print("🚀 Starting tablet data extraction...")
        
        # Create backup directory
        self.create_backup_directory()
        
        # Find database location
        db_location = self.find_database_files()
        
        # Extract database
        if self.extract_database():
            # Extract data
            extracted_data = self.extract_data_from_database()
            
            if extracted_data:
                # Create restore scripts
                self.create_categories_script(extracted_data)
                self.create_menu_items_script(extracted_data)
                self.create_comprehensive_restore_script(extracted_data)
                self.create_readme(extracted_data)
                
                print(f"\n🎉 Extraction completed successfully!")
                print(f"📁 Backup location: {self.backup_dir}")
                print(f"📊 Total tables extracted: {len(extracted_data)}")
                
                # Show summary
                total_records = sum(
                    table_info.get('count', 0) 
                    for table_info in extracted_data.values() 
                    if 'error' not in table_info
                )
                print(f"📈 Total records: {total_records}")
                
                return True
            else:
                print("❌ Failed to extract data from database")
                return False
        else:
            print("❌ Failed to extract database files")
            return False

def main():
    extractor = TabletDataExtractor()
    success = extractor.run_extraction()
    
    if success:
        print("\n✅ Backup completed successfully!")
        print("📋 You can now use the restore scripts to restore data when needed.")
    else:
        print("\n❌ Backup failed. Please check the error messages above.")

if __name__ == "__main__":
    main() 