# Tablet Data Backup

**Generated on:** 2025-08-29 23:41:19
**Source:** Existing backup database

## 📊 Backup Summary

- **android_metadata**: ✅ 1 records
- **orders**: ✅ 76 records
- **order_items**: ✅ 65 records
- **menu_items**: ✅ 17 records
- **categories**: ✅ 8 records
- **users**: ✅ 2 records
- **tables**: ✅ 4 records
- **inventory**: ✅ 0 records
- **customers**: ✅ 0 records
- **transactions**: ✅ 0 records
- **reservations**: ✅ 0 records
- **app_metadata**: ✅ 2 records
- **loyalty_rewards**: ✅ 0 records
- **app_settings**: ✅ 0 records
- **schema_validation_backup_1756484360310_orders**: ✅ 0 records
- **schema_validation_backup_1756484360310_order_items**: ✅ 0 records
- **activity_logs**: ✅ 2 records
- **enhanced_printer_assignments**: ✅ 0 records
- **tenant_printer_configurations**: ✅ 0 records
- **tenant_printer_assignments**: ✅ 0 records
- **printer_public_ips**: ✅ 0 records
- **cross_platform_sync**: ✅ 15 records
- **order_logs**: ✅ 0 records
- **printer_configurations**: ✅ 0 records
- **printer_assignments**: ✅ 0 records


## 📁 Files

- `data/extracted_data.json` - Complete extracted data
- `data/restaurant_ohbombaymilton_at_gmail_com.db` - Original database file
- `scripts/restore_categories.py` - Restore categories only
- `scripts/restore_all_data.py` - Restore all data

## 🚀 Usage

### Restore All Data
```bash
cd tablet_backup_20250829_234119/scripts
python3 restore_all_data.py
```

### Restore Categories Only
```bash
cd tablet_backup_20250829_234119/scripts
python3 restore_categories.py
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
