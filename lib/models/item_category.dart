/// Represents an item category in the POS system.
enum ItemCategory {
  starterVeg,
  starterNonVeg,
  mainCourseVeg,
  mainCourseNonVeg,
  dessert,
  beverage
}

extension ItemCategoryExtension on ItemCategory {
  String get displayName {
    switch (this) {
      case ItemCategory.starterVeg:
        return 'Starter (Veg)';
      case ItemCategory.starterNonVeg:
        return 'Starter (Non-Veg)';
      case ItemCategory.mainCourseVeg:
        return 'Main Course (Veg)';
      case ItemCategory.mainCourseNonVeg:
        return 'Main Course (Non-Veg)';
      case ItemCategory.dessert:
        return 'Dessert';
      case ItemCategory.beverage:
        return 'Beverage';
    }
  }
} 