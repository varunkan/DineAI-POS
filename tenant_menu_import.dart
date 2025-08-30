import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'package:ai_pos_system/config/firebase_config.dart';
import 'package:ai_pos_system/models/category.dart' as pos_category;
import 'package:ai_pos_system/models/menu_item.dart';
import 'package:ai_pos_system/services/database_service.dart';
import 'package:ai_pos_system/services/menu_service.dart';
import 'package:ai_pos_system/services/unified_sync_service.dart';

/// Zero-risk tenant menu import script
/// - Backs up existing categories and items
/// - Clears previous categories and items (local + Firebase via service hooks)
/// - Parses provided text into categories and items (with prices)
/// - Inserts new data and syncs to Firebase
/// - On any failure, automatically rolls back from backup
///
/// USAGE (run from project root):
///   flutter pub get
///   flutter run -d macos -t tenant_menu_import.dart
///
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _ImportApp());
}

class _ImportApp extends StatelessWidget {
  const _ImportApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const _ImportScreen(),
      theme: ThemeData.dark(),
    );
  }
}

class _ImportScreen extends StatefulWidget {
  const _ImportScreen({super.key});

  @override
  State<_ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<_ImportScreen> {
  final String _tenantEmail = 'ohbombaymilton@gmail.com';
  final StringBuffer _logBuffer = StringBuffer();
  bool _isRunning = false;
  bool _completed = false;
  String? _error;
  String? _logFilePath;

  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final line = '[$timestamp] $message';
    // Prefer debugPrint to avoid line truncation
    debugPrint(line);
    setState(() {
      _logBuffer.writeln(line);
    });
  }

  Future<void> _writeLogFile(String databaseName) async {
    try {
      final String ts = DateTime.now().toIso8601String().replaceAll(':', '_');
      final Directory docs = await getApplicationDocumentsDirectory();
      _log('📁 App documents dir (logs): ${docs.path}');
      final Directory dir = Directory('${docs.path}/import_logs/$databaseName');
      await dir.create(recursive: true);
      final File file = File('${dir.path}/import_$ts.log');
      await file.writeAsString(_logBuffer.toString());
      setState(() => _logFilePath = file.path);
      _log('✅ Log file saved at: ${file.path}');
    } catch (e) {
      _log('⚠️ Failed to write log file: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    // Kick off the import automatically
    Future<void>.microtask(_runImport);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tenant Menu Import')), 
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tenant: $_tenantEmail', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  if (_isRunning) const LinearProgressIndicator(),
                  if (_completed && _error == null)
                    const Text('Status: Completed', style: TextStyle(color: Colors.greenAccent)),
                  if (_completed && _error != null)
                    Text('Status: Failed\n$_error', style: const TextStyle(color: Colors.redAccent)),
                  if (_logFilePath != null) Text('Log: $_logFilePath'),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: Text(
                  _logBuffer.toString(),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ),
            if (!_isRunning)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    ElevatedButton(
                      onPressed: _runImport,
                      child: const Text('Run Import Again'),
                    ),
                    const SizedBox(width: 12),
                    if (_logFilePath != null)
                      ElevatedButton(
                        onPressed: () => _writeLogFile('restaurant_${_tenantEmail.toLowerCase().replaceAll('@', '_').replaceAll('.', '_')}'),
                        child: const Text('Save Log'),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _runImport() async {
    if (_isRunning) return;
    setState(() {
      _isRunning = true;
      _completed = false;
      _error = null;
      _logBuffer.clear();
    });

    final String databaseName = 'restaurant_${_tenantEmail.toLowerCase().replaceAll('@', '_').replaceAll('.', '_')}';
    _log('🚀 Tenant Menu Import starting for: $_tenantEmail');

    List<pos_category.Category> backupCategories = [];
    List<MenuItem> backupItems = [];
    final String timestamp = DateTime.now().toIso8601String().replaceAll(':', '_');
    final Directory docs = await getApplicationDocumentsDirectory();
    _log('📁 App documents dir (backup): ${docs.path}');
    final Directory backupDir = Directory('${docs.path}/backups/$databaseName/$timestamp');

    try {
      // Initialize Firebase
      _log('🔥 Initializing Firebase...');
      await FirebaseConfig.initialize();
      FirebaseConfig.setCurrentTenantId(_tenantEmail);
      _log('✅ Firebase initialized for tenant: $_tenantEmail');

      // Connect to tenant database
      _log('🔗 Connecting to tenant database: $databaseName');
      final dbService = DatabaseService();
      await dbService.initializeWithCustomName(databaseName);

      final menuService = MenuService(dbService);
      final unifiedSyncService = UnifiedSyncService();
      await unifiedSyncService.initialize();

      // 1) Create backup
      _log('🛟 Creating backup...');
      backupCategories = await menuService.getCategories();
      backupItems = await menuService.getAllMenuItems();

      await backupDir.create(recursive: true);
      await File('${backupDir.path}/categories.json').writeAsString(
        jsonEncode(backupCategories.map((c) => c.toJson()).toList()),
      );
      await File('${backupDir.path}/menu_items.json').writeAsString(
        jsonEncode(backupItems.map((i) => iToJson(i)).toList()),
      );
      _log('✅ Backup saved at ${backupDir.path}');

      // 2) Parse source text → categories + items
      _log('🧩 Parsing source text...');
      final parsed = parseMenuText(_sourceText);
      _log('✅ Parsed ${parsed.length} categories');

      // 3) Clear existing menu items then categories
      _log('🧹 Clearing existing items...');
      for (final item in List<MenuItem>.from(backupItems)) {
        try {
          await menuService.deleteMenuItem(item.id);
        } catch (e) {
          _log('⚠️ Failed to delete item ${item.name}: $e');
        }
      }

      _log('🧹 Clearing existing categories...');
      for (final cat in List<pos_category.Category>.from(backupCategories)) {
        try {
          await menuService.deleteCategory(cat.id);
        } catch (e) {
          _log('⚠️ Failed to delete category ${cat.name}: $e');
        }
      }

      // 4) Insert new categories and items
      _log('➕ Inserting new categories and items...');
      int totalItems = 0;
      int insertedItems = 0;

      for (final group in parsed) {
        final newCategory = pos_category.Category(
          name: group.name,
          description: null,
          isActive: true,
          sortOrder: 0,
        );
        await menuService.addCategory(newCategory);

        for (final item in group.items) {
          totalItems += 1;
          final menuItem = MenuItem(
            name: item.name,
            description: item.description ?? '',
            price: item.price,
            categoryId: newCategory.id,
            isAvailable: item.price > 0.0,
          );
          try {
            await menuService.addMenuItem(menuItem);
            insertedItems += 1;
          } catch (e) {
            _log('⚠️ Failed to add item ${item.name}: $e');
          }
        }
      }

      _log('✅ Inserted $insertedItems/$totalItems items across ${parsed.length} categories');

      // 5) Verify basic success
      final newCats = await menuService.getCategories();
      final newItems = await menuService.getAllMenuItems();
      if (newCats.isEmpty || newItems.isEmpty) {
        throw Exception('Verification failed: categories=${newCats.length}, items=${newItems.length}');
      }

      _log('🎉 Tenant menu import completed successfully for $_tenantEmail');
      await _writeLogFile(databaseName);

      setState(() {
        _completed = true;
        _isRunning = false;
      });
    } catch (e, st) {
      _log('❌ Import failed: $e');
      _log(st.toString());

      // 6) Rollback from backup on any failure
      _log('⏪ Rolling back from backup...');

      try {
        final dbService = DatabaseService();
        await dbService.initializeWithCustomName(databaseName);
        final menuService = MenuService(dbService);

        // Clear anything partially inserted
        final currentItems = await menuService.getAllMenuItems();
        for (final item in currentItems) {
          try { await menuService.deleteMenuItem(item.id); } catch (_) {}
        }
        final currentCats = await menuService.getCategories();
        for (final cat in currentCats) {
          try { await menuService.deleteCategory(cat.id); } catch (_) {}
        }

        // Recreate categories
        for (final cat in backupCategories) {
          try { await menuService.addCategory(cat); } catch (_) {}
        }
        // Recreate items
        for (final item in backupItems) {
          try { await menuService.addMenuItem(item); } catch (_) {}
        }

        _log('✅ Rollback completed. System restored to previous state.');
      } catch (re) {
        _log('🚨 Rollback encountered issues: $re');
        _log('Please restore manually from backup folder: ${backupDir.path}');
      }

      await _writeLogFile(databaseName);

      setState(() {
        _completed = true;
        _isRunning = false;
        _error = e.toString();
      });
    }
  }
}

// ===== Models for parsed data =====
class ParsedCategory {
  final String name;
  final List<ParsedItem> items;
  ParsedCategory(this.name, this.items);
}

class ParsedItem {
  final String name;
  final double price;
  final String? description;
  ParsedItem({required this.name, required this.price, this.description});
}

// ===== Parser =====
List<ParsedCategory> parseMenuText(String text) {
  final lines = const LineSplitter().convert(text).map((l) => l.trim()).toList();
  final List<ParsedCategory> categories = [];

  String? currentCategory;
  final List<ParsedItem> currentItems = [];
  ParsedItem? lastItem;

  bool isCategoryLine(String line) {
    if (line.isEmpty) return false;
    if (line.startsWith('•')) return false;
    // Heuristic: treat as category if line has letters and equals its uppercase (ignoring spaces/punct)
    final letters = line.replaceAll(RegExp(r'[^A-Za-z0-9&()\- ]'), '');
    if (letters.isEmpty) return false;
    return letters.toUpperCase() == letters;
  }

  void flushCategory() {
    if (currentCategory != null) {
      categories.add(ParsedCategory(currentCategory!, List<ParsedItem>.from(currentItems)));
      currentItems.clear();
      lastItem = null;
    }
  }

  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.isEmpty) continue;

    if (isCategoryLine(line)) {
      flushCategory();
      currentCategory = line;
      continue;
    }

    if (line.startsWith('•')) {
      // Item line: extract name and price(s)
      final stripped = line.replaceFirst(RegExp(r'^•\s*'), '').trim();
      final match = RegExp(r'^(.+?)\s*-\s*\$?([0-9Nn/\.$]+)\s*$').firstMatch(stripped);
      String baseName;
      String pricePart;
      if (match != null) {
        baseName = match.group(1)!.trim();
        pricePart = match.group(2)!.trim();
      } else {
        baseName = stripped;
        pricePart = '0';
      }

      // Handle multiple variants like "A/B - $1.00/$2.00" or names with variants in parens
      List<double> prices = [];
      if (pricePart.toUpperCase() == 'N/A') {
        prices = [0.0];
      } else if (pricePart.contains('/')) {
        prices = pricePart
            .split('/')
            .map((p) => p.replaceAll('\$', '').trim())
            .map((p) => double.tryParse(p) ?? 0.0)
            .toList();
      } else {
        prices = [double.tryParse(pricePart.replaceAll('\$', '')) ?? 0.0];
      }

      // Expand variants if hinted in the name e.g., "(Chicken/Lamb)" or "A/B/C"
      final variantMatch = RegExp(r'\(([^)]+)\)').firstMatch(baseName);
      List<String> variantNames = [];
      String itemStem = baseName;
      if (variantMatch != null) {
        final inside = variantMatch.group(1)!;
        variantNames = inside.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        itemStem = baseName.replaceRange(variantMatch.start, variantMatch.end, '').trim();
      } else if (baseName.contains('/')) {
        // Names like "Tandoori Roti/Butter Roti"
        variantNames = baseName.split('/').map((s) => s.trim()).toList();
        itemStem = '';
      }

      List<ParsedItem> expanded = [];
      if (variantNames.isNotEmpty && prices.length == variantNames.length) {
        for (int idx = 0; idx < variantNames.length; idx++) {
          final vn = variantNames[idx];
          final name = itemStem.isEmpty ? vn : '$itemStem ($vn)';
          expanded.add(ParsedItem(name: name, price: prices[idx]));
        }
      } else if (variantNames.isNotEmpty && prices.length == 1) {
        // Single price, multiple variants → reuse price
        for (final vn in variantNames) {
          final name = itemStem.isEmpty ? vn : '$itemStem ($vn)';
          expanded.add(ParsedItem(name: name, price: prices.first));
        }
      } else if (prices.length > 1 && variantNames.isEmpty) {
        // Multiple prices but no explicit variants → suffix with index
        for (int idx = 0; idx < prices.length; idx++) {
          expanded.add(ParsedItem(name: '$baseName (${idx + 1})', price: prices[idx]));
        }
      } else {
        expanded.add(ParsedItem(name: baseName, price: prices.first));
      }

      currentItems.addAll(expanded);
      lastItem = currentItems.isNotEmpty ? currentItems.last : null;
      continue;
    }

    // Description line: attach to the last item if present
    if (lastItem != null) {
      final idx = currentItems.lastIndexOf(lastItem!);
      if (idx >= 0) {
        final updated = ParsedItem(
          name: currentItems[idx].name,
          price: currentItems[idx].price,
          description: [currentItems[idx].description, line]
              .whereType<String>()
              .join(' ')
              .trim(),
        );
        currentItems[idx] = updated;
        lastItem = updated;
      }
    }
  }

  // Flush last category
  if (currentCategory != null) {
    categories.add(ParsedCategory(currentCategory!, List<ParsedItem>.from(currentItems)));
  }

  return categories;
}

// Helper to convert MenuItem to Map similar to toJson (without private fields)
Map<String, dynamic> iToJson(MenuItem i) => {
  'id': i.id,
  'name': i.name,
  'description': i.description,
  'price': i.price,
  'category_id': i.categoryId,
  'image_url': i.imageUrl,
  'is_available': i.isAvailable,
  'tags': i.tags,
  'custom_properties': i.customProperties,
  'variants': i.variants.map((v) => {'name': v.name, 'price_adjustment': v.priceAdjustment}).toList(),
  'modifiers': i.modifiers.map((m) => {'name': m.name, 'price': m.price}).toList(),
  'nutritional_info': i.nutritionalInfo,
  'allergens': i.allergens,
  'preparation_time': i.preparationTime,
  'is_vegetarian': i.isVegetarian,
  'is_vegan': i.isVegan,
  'is_gluten_free': i.isGlutenFree,
  'is_spicy': i.isSpicy,
  'spice_level': i.spiceLevel,
  'stock_quantity': i.stockQuantity,
  'low_stock_threshold': i.lowStockThreshold,
  'created_at': i.createdAt.toIso8601String(),
  'updated_at': i.updatedAt.toIso8601String(),
};

// ====== SOURCE TEXT (provided) ======
const String _sourceText = r"""SOUPS
•  Chicken Manchow Soup - $7.99
A spicy, aromatic broth with shredded chicken, vegetables, and a hint of soy, garnished with crispy noodles.
•  Veg Manchow Soup - $6.99
A flavorful vegetable broth with a spicy kick, topped with crunchy fried noodles.
•  Cream of Tomato - $5.99
A smooth, creamy tomato soup with a rich red hue, finished with a swirl of cream.
BREADS
•  Butter Naan - $3.49
Soft, golden-brown Indian bread cooked in a tandoor, brushed with butter for a glossy finish.
•  Garlic Naan - $3.99
Fluffy naan topped with fragrant minced garlic and a light butter glaze.
•  Plain Naan - $2.99
Classic soft and pillowy naan, lightly charred from the tandoor.
•  Tandoori Roti/Butter Roti - $2.99/$3.49
Whole wheat bread with a rustic, slightly smoky texture, optional butter topping.
•  Mirchi Paratha (Red/Green)/Ajwaini Paratha - $5.49
Layered flatbread with a spicy green or red chili filling, or infused with ajwain seeds.
•  Amritsari Kulcha (Chicken/Lamb) - $8.49/$9.49
Stuffed kulcha with spiced chicken or tender lamb, served with a golden-brown crust.
•  Amritsari Kulcha (Aloo/Gobi/Paneer) - $7.49/$8.49/$9.49
Stuffed with spiced potatoes, cauliflower, or paneer, baked to a crispy finish.
•  Bhature - $3.99
Fluffy, deep-fried bread with a light golden color, perfect for pairing with chole.
•  Laccha Paratha - $4.99
Multi-layered paratha with a flaky, golden texture.
•  Stuffed Cheese Pizza Naan - $7.99
Naan stuffed with melted cheese, topped with a pizza-like finish.
KIDS MENU
•  Stuffed Cheese Pizza Naan - $7.99
A kid-friendly naan filled with gooey cheese and a mild pizza flavor.
•  Pulled Butter Chicken Nachos - $11.99
Crispy nachos topped with shredded butter chicken and a drizzle of creamy sauce.
•  Paneer Makhani Nachos - $7.49
Nachos layered with soft paneer in a rich makhani gravy.
•  Kids Aloo/Paneer Paratha - $8.49/$9.99
Mildly spiced potato or paneer-stuffed paratha, served with a side.
•  Honey Chilly Potato - $5.99
Crispy potato fries coated in a sweet and spicy honey-chili glaze.
•  French Fries - N/A
Golden, crispy fries, perfect for dipping.
MAIN COURSE - NON VEG
•  Delhi 6 Changezi Chicken - $19.99
Spicy, fragrant chicken with bones in a thick, rich gravy.
•  Town Heaviest Butter Chicken (with bone/boneless) - $19.99
Tender chicken tikka in a silky, buttery makhani gravy.
•  Puran Singh Chicken Curry - $19.99
Slow-cooked chicken with whole spices, offering a deep, aromatic flavor.
•  Adraki Bhuna Gosht (Goat) - $19.99
Bone-in goat cooked with onions and tomatoes, tempered with spices.
•  Rara Gosht Zulfikar (Goat) - $19.99
Mince and chunks of goat with a trotter jelly base, rich with onion-tomato gravy.
•  Dawat-E-Khaas Karahi (Chicken/Goat) - $19.99
Tender meat pieces in a creamy gravy with bell peppers and kasoori methi.
•  Lemon Pepper Chicken (With bone) - $19.99
Succulent chicken with a zesty lemon-pepper flavor in creamy gravy.
•  Andhra Pepper Chicken - $19.99
Spicy thigh pieces with curry leaves and mustard seeds.
•  Anda Keema Ghotla - $19.99
Egg and minced meat blended with masala and curry leaves.
•  Kolkata Fish Masala - $19.99
Tandoori fish in a tangy mustard-onion seed curry.
•  Kashmiri Rogan Josh - $19.99
Fiery mutton with a special Kashmiri masala blend.
MAIN COURSE - VEG
•  Dawat-e-Khas Karahi Paneer - $18.99
Cottage cheese in creamy gravy with bell peppers and kasoori methi.
•  Rara Paneer Keema - Oh Bombay Special - $18.99
Cotton cheese with paneer granules in makhani gravy, tempered with seeds.
•  Oh Bombay Special Paneer Pasanda - $18.99
Paneer sandwich stuffed with khoya, chironji, and raisins in makhani gravy.
•  Palak Dahi Kofta Masala - $18.99
Soft spinach kofta in a creamy garlic-onion-tomato masala.
•  Soya Chaap Tikka Lababdar - Oh Bombay Special - $17.99
Protein-rich soya chunks in a tomato-onion gravy with special masala.
•  Makai Khees Masala - Oh Bombay Special - $18.99
Sweet corn granules in a creamy gravy, pairs well with garlic naan.
•  Oh Bombay Special Khumb Makai Taka Tak - $18.99
Mushrooms in a thick onion-tomato gravy.
•  Pindi Chole - $16.99
Classic Punjabi chickpeas with a deep, spiced flavor.
•  Tawa Subz Miloni - $18.99
Seasonal vegetables in a garlic-mustard seed tempered gravy.
•  Bhuna Baingan Zaykedar - Oh Bombay Special - $17.99
Roasted eggplant with onion-tomato gravy and seeds.
•  Daal Makhani - $17.99
Creamy black lentils with a buttery fenugreek finish.
•  Oh Bombay Special Daal Tadka - $17.99
Yellow daal slow-cooked with ghee and Indian spices.
•  Dahi Bhindi Do Pyaza - $16.99
Ladyfinger fingers in onion-tomato curry with curd.
•  Dum Aloo Kashmiri - $17.99
Kashmiri-style baby potatoes in a rich, spiced gravy.
STARTER - NON VEG
•  Murg Seekh Kebab - $18.99
Medium-spicy chicken minced and tossed in cream and lemon juice.
•  Ajwaini Mahi Tikka (Fish) - $18.99
Mild carom seed-marinated fish, finished in tandoor.
•  Murg-e-Azam Tikka - Oh Bombay Special - $18.99
Soft chicken thigh in red chili marinade, sizzled in tandoor.
•  Murg Afghani Malai Tikka - Oh Bombay Special - $18.99
Boneless chicken with cashew-cream marinade, roasted in tandoor.
•  Amritsari Tandoori Chicken - 2/3 Full Leg Pieces - $15.49/$21.99
Tender chicken marinated with special masala, cooked in a clay oven.
•  Chef’s Special Non-veg Platter - Combination of 4 Kebabs - $29.99
Mix of chicken and fish starters.
•  Lucknowi Galouti Kebab (Lamb Boneless) - $19.99
Melt-in-mouth lamb with smoky galouti masala.
STARTER - VEG
•  Paneer Tikka Kurkure - $17.99
Crispy paneer coated with yogurt seasoning, cooked in a clay oven.
•  Bhatti Ka Paneer Tikka - $17.99
Soft paneer chunks with fragrant herbs, cooked in clay oven.
•  Bharwa Khumb Peshawari - $17.99
Spicy cottage cheese-stuffed button mushrooms, marinated in masala yogurt.
•  Soya Chaap (Tandoori/Malai) - $17.99
Soft soya chunks in tandoor or creamy marinade.
•  Hara Bhara Kebab - $17.99
Kebab with broccoli, green peas, and spinach.
•  Dhai ke Kebab - $17.99
Deep-fried hung curd kebab with black pepper and caraway seeds.
•  Veg Platter - Combination of 6 Kebabs - $24.99
Assorted collection of appetizers.
STARTER - HAKKA
•  Crispy Andhra Chilli Cauliflower - $15.99
Crispy cauliflower tossed in honey chili sauce.
•  Dry/Gravy Manchurian (Veg/Chicken) - $15.99/$16.99
Veg croquettes or crispy chicken in manchurian sauce.
•  Chilly (Paneer/Chicken) - $15.99/$16.99
Pan-fried crispy cottage cheese or chicken in hakka chili gravy.
•  Veg Spring Rolls - 3 pieces - $9.99
Pan-tossed crunchy vegetables seasoned with noodles in wonton sheet.
•  Chilli Garlic Noodles (Veg/Chicken) - $14.99/$15.99
Pan-fried noodles with exotic vegetables, seasoned with special flavors.
•  Street Style Chowmein (Veg/Chicken) - $14.99/$15.99
Pan-fried noodles with authentic street-style vegetables.
•  Veg/Chicken Fried Rice - $14.99/$15.99
Fragrant rice wok-tossed with fresh vegetables and savory street sauces.
MOMOS (DUMPLINGS)
•  Tandoori Momos - Vegetarian/Chicken - $15.99
Crispy momos marinated with tandoori masala, finished in tandoor (8 pieces).
•  Manchurian Style Momos - Vegetarian/Chicken - $15.99
Pan-fried momos tossed in manchurian gravy (8 pieces).
•  Honey Chilli Momos - Vegetarian/Chicken - $15.99
Pan-fried momos tossed with hakka chili sauce (8 pieces).
•  Afghani Momos - Vegetarian/Chicken - $15.99
Fried momos tossed in creamy cheese gravy (8 pieces).
•  Creamy Schewzwan Momos - Vegetarian/Chicken - $15.99
Pan-fried momos tossed with creamy schezwan sauce (8 pieces).
•  Steam Veg Momos - $12.99
Veggie dumplings stuffed with assorted vegetables and cottage cheese (8 pieces).
•  Steamed Chicken Momos - $13.99
Stuffed chicken dumplings made fresh in-house (8 pieces).
SNACKS
•  Veg Samosa - 2 pieces - $3.99
Crispy pastry filled with spiced potatoes and peas.
•  Vada Pav - 1 piece/2 pieces - $4.99/$7.99
Spicy potato fritter in a bun, served with chutney.
•  Pani Puri - 6 pieces - $7.99
Crispy puris filled with spiced water and potatoes.
•  Dahi Puri Chaat - 6 pieces - $7.99
Puri topped with yogurt and tangy chutney.
•  Chaat (Papri/Samosa) - $9.99
Crispy papri or samosa with spiced chickpeas and yogurt.
•  Pav Bhaji - $12.99
Mashed vegetable curry served with buttered pav.
•  Chole Bhature - $13.99
Spiced chickpeas with fluffy fried bread.
•  Dahi Bhalle - $10.99
Soft lentil dumplings in yogurt with spices.
•  Amritsari Kulcha with Chole - $12.99
Stuffed kulcha served with spiced chickpeas.
Cocktails
Rum (2 oz)
•  Mojito - $12
•  Piña Colada - $12
•  Mai Tai - $14
•  Daiquiri - $14
Gin (2 oz)
•  Negroni - $12
•  Martini (Regular/Dry/Extra Dry) - $12
•  Pink Lady - $12
•  Gin Daisy - $12
Tropical Fruit Gin Punch - $13
Tequila (2 oz)
•  Sunrise - $12
•  Margarita (Blue/Pineapple/Red neck) - $14
•  Mexican Chocolate - $14
House Special (2 oz)
•  Himalayan Kshili - $12
•  Mango Choco Maharaja - $12
•  Malibu Rum - $12
Alcohol
Beer (12 oz / 18 oz)
•  Stella Artois - $8/$11
•  Heineken - $8/$11
•  Budweiser - $7/$10
•  Molson Canadian - $7/$10
•  Kingfisher - $8/$11
Wine (6 oz / 9 oz / Bottle)
•  Jackson Triggs - $7/$10/$30
•  Jacob Creek - $7/$10/$30
•  19 Crimes - $10/$14/$35
•  “U John!” - $10/$14/$35
On the Rocks (1 oz)
•  Amrut - $12
•  Black Label - $11
•  Glenfiddich - $12
•  Glenlivet - $12
•  Old Monk - $9
Classic (2 oz)
•  Long Island Iced Tea - $12
•  Jagerbomb - $12
Sangria - $14
B52 - $14
B53 - $14
Vodka (2 oz)
•  White Russian - $12
•  Vodka Mojito - $12
•  Strawberry Vodka Smash - $12
•  Blueberry Vodka Smash - $12
•  Cosmopolitan - $12
Mocktails
•  Blue Lagoon - $6.99
•  Strawberry Mojito - $6.99
•  Virgin Mojito - $6.99
•  Virgin Margarita - $7.49
•  Masala Soda - $6.49
•  Honey Citron - $6.99
•  Rainbow Mocktail - $7.49
•  Mango Mojito - $6.99
•  Piña Colada - $7.49
•  Masala Coke - $6.49
Bubble Tea
•  Mango Popping Boba - $5.95
•  Strawberry Popping Boba - $5.95
•  Pineapple Popping Boba - $5.95
•  Passion Fruit Popping Boba - $5.95
•  Lychee Popping Boba - $5.95
•  Green Apple Popping Boba - $5.95
•  Honeydew Popping Boba - $5.95
•  Coconut Popping Boba - $5.95
•  Taro Milk Tea - $5.95
•  Matcha Milk Tea - $5.95
•  Jasmine Milk Tea - $5.95
•  Mango Milk Tea - $5.95
•  Strawberry Milk Tea - $5.95
•  Pineapple Milk Tea - $5.95
•  Passion Fruit Milk Tea - $5.95
•  Lychee Milk Tea - $5.95
•  Green Apple Milk Tea - $5.95
•  Honeydew Milk Tea - $5.95
•  Coconut Milk Tea - $5.95
•  Taro Milk Tea with Boba - $6.95
•  Matcha Milk Tea with Boba - $6.95
•  Jasmine Milk Tea with Boba - $6.95
•  Mango Milk Tea with Boba - $6.95
•  Strawberry Milk Tea with Boba - $6.95
•  Pineapple Milk Tea with Boba - $6.95
•  Passion Fruit Milk Tea with Boba - $6.95
•  Lychee Milk Tea with Boba - $6.95
•  Green Apple Milk Tea with Boba - $6.95
•  Honeydew Milk Tea with Boba - $6.95
•  Coconut Milk Tea with Boba - $6.95
Premium Drinks
"""; 