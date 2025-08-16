import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/category.dart';
import '../models/menu_item.dart';
import '../models/user.dart';
import '../models/table.dart' as restaurant_table;
import '../services/menu_service.dart';
import '../widgets/universal_navigation.dart';
import '../widgets/loading_overlay.dart';

class CategoriesScreen extends StatefulWidget {
  final User? user;
  final restaurant_table.Table? table;

  const CategoriesScreen({super.key, this.user, this.table});

  @override
  _CategoriesScreenState createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<Category> _categories = [];
  Category? _selectedCategory;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final menuService = Provider.of<MenuService>(context, listen: false);
      final categories = await menuService.getCategories();
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error loading categories: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      isLoading: _isLoading,
      child: Scaffold(
        appBar: UniversalAppBar(
          currentUser: widget.user,
          title: widget.table != null
              ? 'Menu for ${widget.table!.displayName}'
              : 'Menu Categories',
          additionalActions: [
            if (widget.user != null)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Done"),
              ),
          ],
        ),
        body: _error != null
            ? _buildErrorState(_error!)
            : _selectedCategory == null
                ? _buildCategoryGrid()
                : _buildItemGrid(_selectedCategory!),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            'Error loading categories',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.red.shade700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade600,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadCategories,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    // Get responsive sizing based on device type
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
    
    // Responsive grid configuration - Mobile-friendly design
    final crossAxisCount = isPhone ? 1 : isTablet ? 2 : 3; // 1 column on mobile for better readability
    final crossAxisSpacing = isPhone ? 16.0 : isTablet ? 12.0 : 16.0; // Comfortable spacing on mobile
    final mainAxisSpacing = isPhone ? 16.0 : isTablet ? 12.0 : 16.0; // Comfortable spacing on mobile
    final childAspectRatio = isPhone ? 1.0 : isTablet ? 1.3 : 1.2; // Comfortable aspect ratio for mobile
    final padding = isPhone ? 16.0 : isTablet ? 12.0 : 16.0; // Comfortable padding on mobile
    
    // Responsive font sizes and spacing - Mobile-friendly design
    final iconSize = isPhone ? 32.0 : isTablet ? 42.0 : 48.0; // Comfortable icon for mobile readability
    final titleFontSize = isPhone ? 16.0 : isTablet ? 16.0 : 18.0; // Comfortable font for mobile readability
    final descriptionFontSize = isPhone ? 14.0 : isTablet ? 12.0 : 13.0; // Comfortable description for mobile
    final cardPadding = isPhone ? 16.0 : isTablet ? 14.0 : 16.0; // Comfortable padding for mobile
    final spacing = isPhone ? 12.0 : isTablet ? 10.0 : 12.0; // Comfortable spacing for mobile
    
    if (_categories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu, 
              size: isPhone ? 48.0 : 64.0, 
              color: Colors.grey.shade400
            ),
            SizedBox(height: isPhone ? 12.0 : 16.0),
            Text(
              'No Categories Available',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.grey.shade600,
                fontSize: isPhone ? 18.0 : 24.0,
              ),
            ),
            SizedBox(height: isPhone ? 6.0 : 8.0),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isPhone ? 16.0 : 32.0),
              child: Text(
                'Please contact your administrator to add menu categories',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey.shade500,
                  fontSize: isPhone ? 13.0 : 16.0,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.all(padding),
      child: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: crossAxisSpacing,
          mainAxisSpacing: mainAxisSpacing,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return Card(
            elevation: 4,
            child: InkWell(
              onTap: () => setState(() => _selectedCategory = category),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).colorScheme.primaryContainer,
                      Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(cardPadding),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant_menu,
                        size: iconSize,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                      SizedBox(height: spacing),
                      Text(
                        category.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontSize: titleFontSize,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: isPhone ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (category.description != null) ...[
                        SizedBox(height: isPhone ? 2.0 : 4.0),
                        Text(
                          category.description!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                            fontSize: descriptionFontSize,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: isPhone ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildItemGrid(Category category) {
    // Get responsive sizing based on device type
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
    
    // Responsive grid configuration - Mobile-friendly design
    final crossAxisCount = isPhone ? 1 : isTablet ? 2 : 3; // 1 column on mobile for better readability
    final crossAxisSpacing = isPhone ? 16.0 : isTablet ? 12.0 : 16.0; // Comfortable spacing on mobile
    final mainAxisSpacing = isPhone ? 16.0 : isTablet ? 12.0 : 16.0; // Comfortable spacing on mobile
    final childAspectRatio = isPhone ? 0.6 : isTablet ? 0.9 : 0.75; // Comfortable aspect ratio for mobile
    final padding = isPhone ? 16.0 : isTablet ? 12.0 : 16.0; // Comfortable padding on mobile
    
    // Responsive font sizes and spacing - Mobile-friendly design
    final headerPadding = isPhone ? 16.0 : isTablet ? 14.0 : 16.0; // Comfortable header padding for mobile
    final titleFontSize = isPhone ? 18.0 : isTablet ? 18.0 : 20.0; // Comfortable title for mobile readability
    final itemTitleFontSize = isPhone ? 16.0 : isTablet ? 14.0 : 15.0; // Comfortable item title for mobile
    final itemDescriptionFontSize = isPhone ? 14.0 : isTablet ? 12.0 : 13.0; // Comfortable description for mobile
    final priceFontSize = isPhone ? 16.0 : isTablet ? 16.0 : 18.0; // Comfortable price for mobile
    final cardPadding = isPhone ? 16.0 : isTablet ? 10.0 : 12.0; // Comfortable card padding for mobile
    final iconSize = isPhone ? 28.0 : isTablet ? 40.0 : 48.0; // Comfortable icon for mobile readability
    
    final menuService = Provider.of<MenuService>(context, listen: false);
    final itemsFuture = menuService.getMenuItemsByCategoryId(category.id);

    return Column(
      children: [
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: Padding(
            padding: EdgeInsets.all(headerPadding),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, size: isPhone ? 20.0 : 24.0),
                  onPressed: () => setState(() => _selectedCategory = null),
                ),
                SizedBox(width: isPhone ? 6.0 : 8.0),
                Expanded(
                  child: Text(
                    category.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: titleFontSize,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<MenuItem>>(
            future: itemsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline, 
                        size: isPhone ? 48.0 : 64.0, 
                        color: Colors.red.shade300
                      ),
                      SizedBox(height: isPhone ? 12.0 : 16.0),
                      Text(
                        'Error loading items',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.red.shade700,
                          fontSize: isPhone ? 18.0 : 24.0,
                        ),
                      ),
                      SizedBox(height: isPhone ? 6.0 : 8.0),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: isPhone ? 16.0 : 32.0),
                        child: Text(
                          snapshot.error.toString(),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: isPhone ? 13.0 : 16.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final items = snapshot.data ?? [];

              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.restaurant, 
                        size: isPhone ? 48.0 : 64.0, 
                        color: Colors.grey.shade400
                      ),
                      SizedBox(height: isPhone ? 12.0 : 16.0),
                      Text(
                        'No Items in ${category.name}',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.grey.shade600,
                          fontSize: isPhone ? 18.0 : 24.0,
                        ),
                      ),
                      SizedBox(height: isPhone ? 6.0 : 8.0),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: isPhone ? 16.0 : 32.0),
                        child: Text(
                          'This category doesn\'t have any menu items yet',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade500,
                            fontSize: isPhone ? 13.0 : 16.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return Padding(
                padding: EdgeInsets.all(padding),
                child: GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: crossAxisSpacing,
                    mainAxisSpacing: mainAxisSpacing,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Card(
                      elevation: 4,
                      child: InkWell(
                        onTap: () {
                          // Handle item selection - could navigate to order screen
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Selected: ${item.name}'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
                                  ),
                                  child: Icon(
                                    Icons.restaurant,
                                    size: iconSize,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: EdgeInsets.all(cardPadding),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.name,
                                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: itemTitleFontSize,
                                        ),
                                        maxLines: isPhone ? 1 : 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: isPhone ? 2.0 : 4.0),
                                      Text(
                                        item.description,
                                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Colors.grey.shade600,
                                          fontSize: itemDescriptionFontSize,
                                        ),
                                        maxLines: isPhone ? 1 : 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Spacer(),
                                      Text(
                                        '\$${item.price.toStringAsFixed(2)}',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.primary,
                                          fontSize: priceFontSize,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showItemDetails(MenuItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.description),
            const SizedBox(height: 8),
            Text('Price: \$${item.price.toStringAsFixed(2)}'),
            if (item.preparationTime > 0)
              Text('Prep Time: ${item.preparationTime} min'),
            if (item.isVegetarian)
              const Chip(label: Text('Vegetarian'), backgroundColor: Colors.green),
            if (item.isVegan)
              const Chip(label: Text('Vegan'), backgroundColor: Colors.green),
            if (item.isGlutenFree)
              const Chip(label: Text('Gluten Free'), backgroundColor: Colors.blue),
            if (item.isSpicy)
              Chip(
                label: Text('Spicy Level: ${item.spiceLevel}'),
                backgroundColor: Colors.red.shade100,
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Reusable card widget for displaying a category.
class CategoryCard extends StatelessWidget {
  final Category category;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final bool isSelected;

  const CategoryCard({
    super.key,
    required this.category,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              category.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable card widget for displaying a menu item.
class _MenuItemCard extends StatelessWidget {
  final MenuItem item;
  final VoidCallback onTap;

  const _MenuItemCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                item.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '\$${item.price.toStringAsFixed(2)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (item.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CategoryItem extends StatelessWidget {
  final Category category;
  final VoidCallback? onTap;
  final bool isSelected;

  const CategoryItem({
    Key? key,
    required this.category,
    this.onTap,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 2,
      color: isSelected ? Theme.of(context).primaryColor.withValues(alpha: 0.1) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              category.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
} 