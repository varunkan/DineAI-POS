#!/usr/bin/env python3
"""
Comprehensive Data Restore Script
Generated on: 2025-08-29 23:41:19
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
                print(f"Skipping {table_name} due to error: {table_info['error']}")
                continue
                
            print(f"Restoring table: {table_name} ({table_info['count']} records)")
            
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
                    
                    cursor.execute(f"INSERT OR REPLACE INTO {table_name} ({column_names}) VALUES ({placeholders})", values)
                    
                except Exception as e:
                    print(f"Error restoring row in {table_name}: {e}")
                    continue
        
        conn.commit()
        conn.close()
        print("Comprehensive data restoration completed!")
        
    except Exception as e:
        print(f"Error during restoration: {e}")

if __name__ == "__main__":
    restore_all_data()
