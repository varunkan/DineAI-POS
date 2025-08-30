# 🖨️ Printer Type Mapping System

## Overview

The Printer Type Mapping System is a comprehensive solution that allows you to categorize printers into specific types (Receipt, Tandoor, Curry, Expo) and automatically route orders to the appropriate printers based on item categories and individual item assignments.

## 🎯 **Key Features**

### **Printer Types**
- **🧾 Receipt Printer**: Customer receipts and order summaries
- **🔥 Tandoor Printer**: Tandoor, grill, and kebab items
- **🍛 Curry Printer**: Curry, sauce, and gravy items  
- **📋 Expo Printer**: Assembly line items (salads, bread, rice)

### **Smart Assignment**
- **Item-level mapping**: Assign specific items to printer types
- **Category-level mapping**: Assign entire categories to printer types
- **Auto-detection**: Smart fallback based on item names and characteristics
- **Fallback logic**: Default to receipt printer if no specific mapping exists

### **Firebase Integration**
- **Cross-device sync**: Configuration automatically syncs across all devices
- **Real-time updates**: Changes propagate instantly to all connected devices
- **Secure access**: Restaurant-specific data with proper authentication

## 🚀 **Quick Start Guide**

### **1. Initial Setup**

The system automatically creates default configurations when first initialized:

```dart
// This happens automatically when the service is first used
await PrinterTypeManagementService.instance.initialize();
```

### **2. Assign Printers to Types**

```dart
// Assign a printer to the Tandoor printer type
await PrinterTypeManagementService.instance.assignPrinterToType(
  printerId: 'printer_123',
  printerType: PrinterTypeCategory.tandoor,
  isPrimary: true,
  userId: 'user_456',
);
```

### **3. Assign Categories to Types**

```dart
// Assign the "Tandoor Items" category to the Tandoor printer type
await PrinterTypeManagementService.instance.assignCategoryToType(
  categoryId: 'category_789',
  printerType: PrinterTypeCategory.tandoor,
  userId: 'user_456',
);
```

### **4. Assign Individual Items to Types**

```dart
// Assign a specific item to the Curry printer type
await PrinterTypeManagementService.instance.assignItemToType(
  itemId: 'item_101',
  itemName: 'Butter Chicken',
  categoryId: 'category_curry',
  categoryName: 'Curry Items',
  printerType: PrinterTypeCategory.curry,
  userId: 'user_456',
  restaurantId: 'restaurant_001',
);
```

## 🔧 **Configuration Management**

### **Printer Type Configuration**

Each printer type has its own configuration:

```dart
class PrinterTypeConfiguration {
  final PrinterTypeCategory type;        // Receipt, Tandoor, Curry, Expo
  final String name;                     // Display name
  final String description;              // Description
  final List<String> assignedPrinterIds; // Assigned printer IDs
  final List<String> assignedCategoryIds; // Assigned category IDs
  final List<String> assignedItemIds;    // Assigned item IDs
  final bool isActive;                   // Whether this type is active
}
```

### **Assignment Hierarchy**

The system follows this priority order for determining which printer to use:

1. **Item-specific assignment** (highest priority)
2. **Category assignment**
3. **Smart auto-detection** (based on item names)
4. **Default to receipt printer** (fallback)

## 📱 **User Interface**

### **Printer Type Management Screen**

Access the management interface through:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const PrinterTypeManagementScreen(),
  ),
);
```

### **Tab-based Interface**

- **🧾 Receipt Tab**: Manage receipt printer assignments
- **🔥 Tandoor Tab**: Manage tandoor printer assignments  
- **🍛 Curry Tab**: Manage curry printer assignments
- **📋 Expo Tab**: Manage expo printer assignments

### **Quick Actions**

- **Assign Printers**: Click "Assign" button to add printers to types
- **Assign Categories**: Bulk assign categories to printer types
- **Assign Items**: Individual item assignment for specific cases
- **Quick Assign**: Bulk assignment wizard for common scenarios

## 🖨️ **Printing Integration**

### **Automatic Order Routing**

When an order is placed, the system automatically routes items to appropriate printers:

```dart
// Process order with automatic printer type routing
final results = await OrderPrinterIntegrationService.instance.processOrder(order);

// Results show success/failure for each printer type
// {
//   'receipt': true,
//   'tandoor': true, 
//   'curry': false,
//   'expo': true
// }
```

### **Receipt Printing**

```dart
// Print customer receipt
final success = await PrintingService.instance.printReceipt(order);
```

### **Kitchen Printing**

```dart
// Print kitchen orders to appropriate printers
final results = await PrintingService.instance.printKitchenOrders(order);
```

## 🔄 **Firebase Collections**

### **Collection Structure**

```
printer_type_configs/
├── receipt_config_id/
│   ├── type: "PrinterTypeCategory.receipt"
│   ├── name: "Receipt Printer"
│   ├── description: "Main receipt printer"
│   ├── assignedPrinterIds: ["printer_1", "printer_2"]
│   ├── assignedCategoryIds: ["category_1"]
│   ├── assignedItemIds: ["item_1", "item_2"]
│   ├── restaurantId: "restaurant_001"
│   └── createdBy: "user_123"
│
printer_type_assignments/
├── assignment_id/
│   ├── printerTypeConfigId: "receipt_config_id"
│   ├── printerId: "printer_1"
│   ├── printerType: "PrinterTypeCategory.receipt"
│   ├── isPrimary: true
│   └── assignedBy: "user_123"
│
item_printer_type_mappings/
├── mapping_id/
│   ├── itemId: "item_1"
│   ├── itemName: "Butter Chicken"
│   ├── categoryId: "category_curry"
│   ├── categoryName: "Curry Items"
│   ├── printerType: "PrinterTypeCategory.curry"
│   ├── restaurantId: "restaurant_001"
│   └── createdBy: "user_123"
```

### **Security Rules**

```javascript
// Only authenticated users can access their restaurant's data
match /printer_type_configs/{configId} {
  allow read, write: if request.auth != null && 
    resource.data.restaurantId == request.auth.token.restaurant_id;
}
```

## 📊 **Monitoring and Analytics**

### **Configuration Status**

```dart
// Get overall configuration status
final status = OrderPrinterIntegrationService.instance.getConfigurationStatus();

// Check if all types are properly configured
final isConfigured = OrderPrinterIntegrationService.instance.arePrinterTypesConfigured();
```

### **Printing Statistics**

```dart
// Get printer type statistics
final stats = PrinterTypeManagementService.instance.getSummaryStats();

// Example output:
// {
//   'receipt': {'printerCount': 2, 'categoryCount': 5, 'itemCount': 25},
//   'tandoor': {'printerCount': 1, 'categoryCount': 2, 'itemCount': 8},
//   'curry': {'printerCount': 1, 'categoryCount': 3, 'itemCount': 12},
//   'expo': {'printerCount': 1, 'categoryCount': 2, 'itemCount': 6}
// }
```

### **Validation and Recommendations**

```dart
// Validate current configuration
final issues = OrderPrinterIntegrationService.instance.validateConfiguration();

// Get setup recommendations
final recommendations = OrderPrinterIntegrationService.instance.getQuickSetupRecommendations();
```

## 🚨 **Troubleshooting**

### **Common Issues**

#### **1. No Printers Assigned to Type**
```
Issue: "Tandoor printer type has no assigned printers"
Solution: Use the management screen to assign printers to the tandoor type
```

#### **2. Items Not Printing to Correct Printer**
```
Issue: Items printing to wrong printer type
Solution: Check item and category assignments in the management screen
```

#### **3. Firebase Sync Issues**
```
Issue: Changes not appearing on other devices
Solution: Check internet connection and Firebase authentication
```

### **Debug Information**

Enable debug logging to see detailed information:

```dart
// Debug logs show:
// 🔄 Processing order with printer type integration...
// 🧾 Receipt print: ✅
// 🍳 Kitchen print results: {tandoor: true, curry: false, expo: true}
// 📊 Order print summary: 3/4 successful
```

## 🔮 **Future Enhancements**

### **Planned Features**

1. **Smart Auto-Assignment**: AI-powered item categorization
2. **Print Queue Management**: Advanced queue handling for busy periods
3. **Printer Health Monitoring**: Real-time printer status and alerts
4. **Analytics Dashboard**: Detailed printing analytics and reports
5. **Mobile App Integration**: Remote printer management via mobile app

### **API Extensions**

```dart
// Future API methods
await PrinterTypeManagementService.instance.autoAssignItemsToPrinterTypes();
await PrinterTypeManagementService.instance.optimizePrinterAssignments();
await PrinterTypeManagementService.instance.getPrintingAnalytics();
```

## 📚 **API Reference**

### **Core Services**

- **`PrinterTypeManagementService`**: Main service for managing configurations
- **`OrderPrinterIntegrationService`**: Service for order processing integration
- **`PrintingService`**: Enhanced printing service with type support

### **Key Methods**

#### **Printer Type Management**
```dart
// Initialize service
await service.initialize();

// Create default configurations
await service.createDefaultConfigurations(restaurantId, userId);

// Assign printer to type
await service.assignPrinterToType(printerId, type, isPrimary, userId);

// Assign category to type
await service.assignCategoryToType(categoryId, type, userId);

// Assign item to type
await service.assignItemToType(itemId, itemName, categoryId, categoryName, type, userId, restaurantId);
```

#### **Order Processing**
```dart
// Process order with automatic routing
final results = await integrationService.processOrder(order);

// Get printing summary
final summary = integrationService.getOrderPrintingSummary(order);

// Validate configuration
final issues = integrationService.validateOrderPrinting(order);
```

#### **Configuration Queries**
```dart
// Get all printer types
final types = service.getAllPrinterTypes();

// Get printers for type
final printers = service.getPrintersForType(PrinterTypeCategory.tandoor);

// Get primary printer for type
final primary = service.getPrimaryPrinterForType(PrinterTypeCategory.receipt);

// Check if type has printers
final hasPrinters = service.hasAssignedPrinters(PrinterTypeCategory.curry);
```

## 🎉 **Success Metrics**

### **Configuration Completion**
- ✅ All 4 printer types configured
- ✅ Each type has at least 1 printer assigned
- ✅ Categories and items properly mapped

### **Printing Success Rate**
- 🎯 Target: >95% successful prints
- 📊 Monitor: Success rate by printer type
- 🔍 Track: Failed print attempts and reasons

### **User Experience**
- ⚡ Fast order processing (<2 seconds)
- 🎯 Accurate printer routing
- 🔄 Seamless cross-device synchronization

## 📞 **Support and Contact**

For technical support or feature requests:

- **Documentation**: This guide and inline code comments
- **Debug Logs**: Enable debug mode for detailed troubleshooting
- **Error Handling**: Comprehensive error messages and recovery suggestions

---

**🎯 The Printer Type Mapping System provides a robust, scalable solution for managing complex printing workflows in restaurant environments, ensuring orders reach the right kitchen stations efficiently and reliably.** 