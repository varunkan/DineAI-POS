#!/usr/bin/env dart

import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

Future<void> clearLocalData() async {
  try {
    print('🧹 Clearing local database data...');
    
    // Get the database directory
    final databasesPath = await getDatabasesPath();
    
    // List of possible database files
    final dbFiles = [
      'ai_pos_dev.db',
      'ai_pos_prod.db', 
      'ai_pos_system.db',
      'pos_database.db'
    ];
    
    int deletedFiles = 0;
    for (final dbFile in dbFiles) {
      final dbPath = join(databasesPath, dbFile);
      final file = File(dbPath);
      
      if (await file.exists()) {
        await file.delete();
        print('   ✅ Deleted: $dbFile');
        deletedFiles++;
      }
    }
    
    if (deletedFiles == 0) {
      print('   ℹ️ No database files found to delete');
    }
    
    print('✅ Local data cleared successfully!');
    print('📱 Ready for fresh app initialization');
    
  } catch (e) {
    print('❌ Error clearing local data: $e');
    exit(1);
  }
}

void main() async {
  await clearLocalData();
} 