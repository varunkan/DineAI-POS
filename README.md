# 🏪 Multi-Tenant AI POS System

A world-class, cross-platform Point of Sale system built with Flutter for modern restaurants. Features intelligent order management, multi-device synchronization, thermal printing, and a beautiful responsive interface.

## ✨ Key Features

### 🎯 **Core Functionality**
- **Multi-Tenant Architecture** - Support for multiple restaurants
- **Cross-Platform** - Android, iOS, Web, macOS, Windows, Linux
- **Real-time Synchronization** - Orders sync across all devices instantly
- **Offline-First** - Works without internet connection
- **World-Class Mobile Interface** - Optimized for phones and tablets

### 📱 **Order Management**
- **Smart Order Creation** - Intuitive item selection with variants
- **Kitchen Integration** - Send orders to kitchen with thermal printing
- **Order Tracking** - Real-time status updates and notifications
- **Payment Processing** - Multiple payment methods with receipt generation
- **Table Management** - Dine-in setup with table assignment

### 🖨️ **Printing System**
- **Thermal Printer Support** - Epson ESC/POS compatible printers
- **Network Discovery** - Automatic printer detection on local network
- **Kitchen Receipts** - Professional 80mm thermal format
- **Multi-Printer Assignment** - Different printers for different stations
- **Cloud Printing** - Remote printing capabilities

### 👥 **User Management**
- **Multi-Server Support** - Multiple staff members with role-based access
- **Admin Panel** - Comprehensive restaurant management
- **Activity Logging** - Complete audit trail of all operations
- **Session Management** - Secure authentication and authorization

### 📊 **Analytics & Reporting**
- **Sales Analytics** - Real-time sales tracking and reporting
- **Order History** - Complete order audit trail
- **Performance Metrics** - Server and table performance analytics
- **Inventory Tracking** - Menu item availability and stock management

## 🚀 Quick Start

### Prerequisites
- Flutter SDK 3.0+
- Dart 3.0+
- Android Studio / Xcode (for mobile development)
- Git

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/ai-pos-system.git
   cd ai-pos-system
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the application**
   ```bash
   # For Android
   flutter run -d android
   
   # For iOS
   flutter run -d ios
   
   # For Web
   flutter run -d chrome
   
   # For Desktop
   flutter run -d macos
   ```

## 📱 Platform Support

| Platform | Status | Notes |
|----------|--------|-------|
| Android | ✅ Full Support | Optimized for tablets and phones |
| iOS | ✅ Full Support | iPhone and iPad optimized |
| Web | ✅ Full Support | Progressive Web App ready |
| macOS | ✅ Full Support | Native desktop experience |
| Windows | ✅ Full Support | Windows 10/11 compatible |
| Linux | ✅ Full Support | Ubuntu, Debian, etc. |

## 🏗️ Architecture

### **Multi-Tenant Design**
- **Global Database** - Restaurant management and user authentication
- **Tenant Databases** - Isolated data per restaurant
- **Cross-Platform Sync** - Real-time data synchronization
- **Offline Support** - Local caching with conflict resolution

### **Service Layer**
- **OrderService** - Order creation, modification, and tracking
- **UserService** - Authentication and user management
- **PrinterService** - Thermal printer integration
- **DatabaseService** - Cross-platform data persistence
- **SyncService** - Real-time data synchronization

### **UI/UX Design**
- **Responsive Layout** - Adapts to any screen size
- **Material Design** - Modern, intuitive interface
- **Dark/Light Themes** - Customizable appearance
- **Accessibility** - Screen reader and keyboard navigation support

## 🖨️ Printer Setup

### **Network Printers**
1. Connect thermal printer to network
2. Run printer discovery in app
3. Configure printer settings
4. Assign to kitchen stations

### **Local Printers**
1. Install printer drivers
2. Configure printer in app
3. Test print functionality
4. Set up automatic printing

## 📊 Database Schema

### **Core Tables**
- `restaurants` - Multi-tenant restaurant data
- `users` - Staff and admin accounts
- `orders` - Order information and status
- `order_items` - Individual items in orders
- `menu_items` - Restaurant menu catalog
- `tables` - Dine-in table management
- `printer_configurations` - Printer settings
- `activity_logs` - Audit trail

## 🔧 Configuration

### **Environment Setup**
```dart
// Development
flutter run --flavor development

// Production
flutter run --flavor production
```

### **Database Configuration**
```dart
// Local SQLite
DatabaseService.initialize('restaurant_name');

// Cloud Sync
CrossPlatformDatabaseService.initialize();
```

## 🧪 Testing

### **Unit Tests**
```bash
flutter test
```

### **Integration Tests**
```bash
flutter test integration_test/
```

### **Widget Tests**
```bash
flutter test test/widget_test.dart
```

## 📦 Building for Production

### **Android APK**
```bash
flutter build apk --release
```

### **iOS App Store**
```bash
flutter build ios --release
```

### **Web Deployment**
```bash
flutter build web --release
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: [Wiki](https://github.com/yourusername/ai-pos-system/wiki)
- **Issues**: [GitHub Issues](https://github.com/yourusername/ai-pos-system/issues)
- **Discussions**: [GitHub Discussions](https://github.com/yourusername/ai-pos-system/discussions)

## 🙏 Acknowledgments

- Flutter team for the amazing framework
- SQLite for reliable local storage
- Epson for thermal printer compatibility
- All contributors and beta testers

---

**Built with ❤️ for modern restaurants**
