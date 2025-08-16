# 🏪 Restaurant Registration - Automatic Dummy Data Population Guide

## 📋 **Overview**

When you register a new restaurant in the AI POS System, the system automatically creates comprehensive dummy data across all core tables. This ensures that every new restaurant starts with a fully functional setup and can begin operations immediately.

## 🚀 **What Happens During Registration**

### **Step 1: Restaurant Registration Process**
1. **Form Validation** - All required fields are validated
2. **Database Creation** - Unique tenant database created for the restaurant
3. **Admin User Creation** - Primary admin user with full access
4. **Automatic Data Population** - All core tables populated with dummy data
5. **Firebase Sync** - Data synced to cloud for cross-device access

### **Step 2: Core Tables Population**
The system automatically creates data in the following tables with **50+ total items**:

## 🍽️ **Menu Categories (8 Total)**

| Category | Description | Sort Order |
|----------|-------------|------------|
| **Appetizers & Starters** | Delicious starters to begin your meal | 1 |
| **Soups & Salads** | Fresh soups and healthy salads | 2 |
| **Main Course** | Delicious main dishes | 3 |
| **Side Dishes** | Perfect accompaniments to your main course | 4 |
| **Breads & Rice** | Fresh breads and aromatic rice dishes | 5 |
| **Desserts** | Sweet endings to your meal | 6 |
| **Beverages** | Refreshing drinks and hot beverages | 7 |
| **Chef Specials** | Unique dishes created by our chef | 8 |

## 🍛 **Menu Items (20+ Total)**

### **Appetizers & Starters**
- **Bruschetta** ($8.99) - Toasted bread with tomatoes, garlic, and basil
- **Spring Rolls** ($7.99) - Crispy vegetable rolls with sweet chili sauce
- **Chicken Wings** ($12.99) - Crispy wings with choice of sauce

### **Soups & Salads**
- **Caesar Salad** ($11.99) - Romaine lettuce with Caesar dressing
- **Tomato Soup** ($6.99) - Creamy tomato soup with herbs

### **Main Course**
- **Grilled Salmon** ($24.99) - Fresh Atlantic salmon with herbs
- **Vegetable Pasta** ($16.99) - Fresh pasta with seasonal vegetables
- **Beef Burger** ($18.99) - Juicy beef patty with special sauce

### **Side Dishes**
- **French Fries** ($5.99) - Crispy golden fries with sea salt
- **Steamed Vegetables** ($6.99) - Fresh seasonal vegetables

### **Breads & Rice**
- **Garlic Bread** ($4.99) - Toasted bread with garlic butter
- **Basmati Rice** ($4.99) - Fragrant rice with aromatic spices

### **Desserts**
- **Chocolate Cake** ($8.99) - Rich chocolate cake with ganache
- **Vanilla Ice Cream** ($6.99) - Creamy vanilla with fresh berries

### **Beverages**
- **Fresh Orange Juice** ($4.99) - Freshly squeezed orange juice
- **Espresso** ($3.99) - Strong Italian espresso

### **Chef Specials**
- **Chef's Daily Special** ($28.99) - Creative dish of the day

## 🪑 **Restaurant Tables (12 Total)**

### **Indoor Tables**
- **Table 1** (2 seats) - Indoor - Window
- **Table 2** (4 seats) - Indoor - Center
- **Table 3** (6 seats) - Indoor - Corner
- **Table 4** (4 seats) - Indoor - Bar Area
- **Table 5** (8 seats) - Indoor - Private Area

### **Outdoor Tables**
- **Outdoor Table 1** (4 seats) - Outdoor - Patio
- **Outdoor Table 2** (6 seats) - Outdoor - Garden

### **Bar Seating**
- **Bar Stool 1** (1 seat) - Bar - Left
- **Bar Stool 2** (1 seat) - Bar - Center
- **Bar Stool 3** (1 seat) - Bar - Right

### **Service Areas**
- **Takeout Counter** - Front - Takeout Area
- **Delivery Station** - Back - Delivery Area

## 📦 **Inventory Items (5 Total)**

| Item | Quantity | Unit | Supplier | Cost/Unit |
|------|----------|------|----------|-----------|
| **Fresh Tomatoes** | 100 | pieces | Local Farm Market | $0.50 |
| **Chicken Breast** | 50 | kg | Premium Meats Co. | $8.99 |
| **Basmati Rice** | 100 | kg | Global Foods Inc. | $3.99 |
| **Mixed Vegetables** | 75 | kg | Fresh Produce Co. | $2.99 |
| **Fresh Milk** | 60 | liters | Dairy Farm Fresh | $1.99 |

## 🖨️ **Printer Configurations (3 Total)**

| Printer | Type | Model | Location | Status |
|---------|------|-------|----------|---------|
| **Kitchen Printer** | WiFi | Thermal Printer Pro | Main Kitchen | Connected |
| **Bar Printer** | WiFi | Thermal Printer Mini | Bar Area | Connected |
| **Cashier Printer** | USB | Receipt Printer Plus | Front Desk | Connected |

## 👥 **User Accounts (5 Total)**

| User | Role | PIN | Admin Access | Status |
|------|------|-----|--------------|---------|
| **Admin** | Admin | 1234 | ✅ Full Access | Active |
| **Cashier 1** | Cashier | 1111 | ❌ No Access | Active |
| **Waiter 1** | Waiter | 2222 | ❌ No Access | Active |
| **Chef 1** | Chef | 3333 | ❌ No Access | Active |
| **Manager 1** | Manager | 4444 | ✅ Limited Access | Active |

## 👥 **Sample Customers (3 Total)**

| Customer | Phone | Email | Loyalty Points | Total Spent | Visit Count |
|----------|-------|-------|----------------|-------------|-------------|
| **John Smith** | +1-555-0101 | john.smith@email.com | 150 | $299.99 | 8 |
| **Sarah Johnson** | +1-555-0102 | sarah.j@email.com | 450 | $899.99 | 15 |
| **Mike Wilson** | +1-555-0103 | mike.w@email.com | 25 | $49.99 | 2 |

## 🎁 **Loyalty Rewards (3 Total)**

| Reward | Description | Points Required | Discount |
|--------|-------------|-----------------|----------|
| **10% Off Next Visit** | Get 10% off your next order | 100 | 10% |
| **Free Dessert** | Free dessert with any main course | 200 | Free Item |
| **25% Off Special** | 25% off your entire order | 500 | 25% |

## ⚙️ **App Settings (5 Total)**

| Setting | Value | Category | Description |
|---------|-------|----------|-------------|
| **Tax Rate** | 8.5% | Billing | Sales tax rate percentage |
| **Currency** | USD | Billing | Default currency for transactions |
| **Business Hours** | 7 days/week | Operations | Operating hours configuration |
| **Auto Print Orders** | Enabled | Printing | Automatically print to kitchen |
| **Loyalty Program** | Enabled | Loyalty | Customer loyalty program status |

## 🔄 **Automatic Features**

### **Data Synchronization**
- All data automatically synced to Firebase
- Real-time updates across all devices
- Offline capability with local SQLite database

### **Table Management**
- Tables automatically configured for different service types
- Support for dine-in, takeout, and delivery
- Capacity and location tracking

### **Inventory Management**
- Stock quantity tracking
- Low stock threshold alerts
- Supplier information management

### **User Management**
- Role-based access control
- PIN-based authentication
- Admin panel access control

## 🎯 **Benefits of Automatic Population**

1. **Immediate Operations** - Restaurant can start taking orders right away
2. **Professional Setup** - Pre-configured with industry-standard categories
3. **Training Ready** - Staff can learn the system with real data
4. **Customizable** - All data can be modified or expanded as needed
5. **Consistent Structure** - Standardized database schema across all restaurants
6. **Customer Management** - Sample customers and loyalty program ready
7. **Business Configuration** - Tax rates, business hours, and settings pre-configured

## 📱 **How to Access**

After registration, you can:
1. **Login** with your admin credentials
2. **View Menu** - All categories and items are ready
3. **Manage Tables** - All tables configured and ready
4. **Check Inventory** - Stock levels and suppliers set up
5. **Configure Printers** - Print settings ready for customization
6. **Manage Users** - Additional staff accounts can be created

## 🚀 **Next Steps After Registration**

1. **Customize Menu** - Modify categories and items to match your cuisine
2. **Adjust Pricing** - Update prices according to your business model
3. **Configure Printers** - Set up actual printer IP addresses
4. **Add Staff** - Create additional user accounts for your team
5. **Set Business Hours** - Configure operating hours and availability
6. **Customize Settings** - Adjust tax rates, currency, and other preferences

---

**🎉 Your restaurant is now ready to start operations with a complete, professional setup!** 