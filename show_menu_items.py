#!/usr/bin/env python3
import json

# Load the extracted data
with open('tablet_backup_20250829_234119/data/extracted_data.json', 'r') as f:
    data = json.load(f)

print("🍽️ MENU ITEMS FOUND:")
print("=" * 50)

for i, item in enumerate(data['menu_items']['data']):
    print(f"  {i+1}. {item['name']} - ${item['price']}")

print(f"\n📊 Total menu items: {len(data['menu_items']['data'])}")
print(f"📋 Total categories: {len(data['categories']['data'])}")
print(f"📦 Total orders: {len(data['orders']['data'])}")
print(f"🛒 Total order items: {len(data['order_items']['data'])}") 