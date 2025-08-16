# Multi-Tenant Authentication Guide

## 🎯 Overview

The AI POS System uses a **multi-tenant architecture** where each restaurant is a separate tenant with its own:
- Database
- Users
- Menu items
- Orders
- Settings

## 🔐 How Authentication Works

### 1. Restaurant Registration
When a restaurant registers, the system creates:
- **Restaurant record** in Firebase (`restaurants` collection)
- **Global registration** in Firebase (`global_restaurants` collection)
- **Tenant structure** in Firebase (`tenants/{restaurant-id}`)
- **Local database** for offline operations

### 2. User Authentication
Users can authenticate using:
- **Restaurant Email** + **User ID** + **Password**
- **Restaurant Email** + **User ID** + **PIN**

### 3. Multi-Device Sync
- All devices connect to the same Firebase tenant
- Real-time synchronization of orders, menu items, etc.
- Offline capability with local SQLite database

## 📱 Available Test Credentials

### Demo Restaurant (Primary Testing)
```
Restaurant Email: demo@restaurant.com
Admin User ID: admin
Admin Password: admin123
Admin PIN: 1234

Additional Users:
- Cashier: cashier1 (PIN: 1111)
- Manager: manager1 (PIN: 2222)
- Waiter: waiter1 (PIN: 3333)
```

### Test Restaurant One
```
Restaurant Email: test1@restaurant.com
Admin User ID: admin1
Admin Password: admin123
Admin PIN: 1234

Additional Users:
- Cashier: cashier1 (PIN: 1111)
- Manager: manager1 (PIN: 2222)
```

### Test Restaurant Two
```
Restaurant Email: test2@restaurant.com
Admin User ID: admin2
Admin Password: admin123
Admin PIN: 1234

Additional Users:
- Cashier: cashier1 (PIN: 1111)
- Manager: manager1 (PIN: 2222)
```

### Pizza Palace
```
Restaurant Email: pizza@restaurant.com
Admin User ID: pizza_admin
Admin Password: pizza123
Admin PIN: 1234

Additional Users:
- Cashier: pizza_cashier (PIN: 1111)
- Chef: pizza_chef (PIN: 4444)
```

### Sushi Bar
```
Restaurant Email: sushi@restaurant.com
Admin User ID: sushi_admin
Admin Password: sushi123
Admin PIN: 1234

Additional Users:
- Cashier: sushi_cashier (PIN: 1111)
- Chef: sushi_chef (PIN: 5555)
```

## 🔄 Cross-Device Testing

### Step 1: Login on Both Emulators
Use the **same restaurant credentials** on both emulators:
- Emulator 5554: Login with `demo@restaurant.com` / `admin` / `admin123`
- Emulator 5556: Login with `demo@restaurant.com` / `admin` / `admin123`

### Step 2: Test Real-time Sync
1. **Create Order on Emulator 5554**:
   - Go to "New Order"
   - Add some menu items
   - Save the order

2. **Check Order on Emulator 5556**:
   - Go to "Orders" section
   - The order should appear within 10-15 seconds

### Step 3: Test Menu Items Sync
- Both emulators should show identical menu items
- Both emulators should show identical categories

## 🏗️ Firebase Data Structure

```
Firebase Project: dineai-pos-system
├── restaurants/                    # Restaurant registrations
│   ├── demo-restaurant
│   ├── test-restaurant-1
│   └── ...
├── global_restaurants/            # Global restaurant registry
│   ├── demo-restaurant
│   ├── test-restaurant-1
│   └── ...
└── tenants/                       # Tenant-specific data
    ├── demo-restaurant/
    │   ├── users/                 # Restaurant users
    │   ├── categories/            # Menu categories
    │   ├── menu_items/            # Menu items
    │   └── orders/                # Orders
    ├── test-restaurant-1/
    └── ...
```

## 🔧 Troubleshooting

### "Incorrect Credentials" Error

**Possible Causes:**
1. **Wrong Restaurant Email**: Make sure you're using the exact email (case-sensitive)
2. **Wrong User ID**: Use the correct admin user ID for that restaurant
3. **Wrong Password**: Use the correct password for that restaurant
4. **Firebase Connection**: Check if the app can connect to Firebase

**Solutions:**
1. **Use Exact Credentials**: Copy-paste the credentials from this guide
2. **Clear App Data**: Clear app data and try again
3. **Check Network**: Ensure emulators have internet connectivity
4. **Restart App**: Force stop and restart the app

### "Restaurant Not Found" Error

**Possible Causes:**
1. Restaurant not registered in Firebase
2. Firebase connection issues
3. App not loading restaurant data

**Solutions:**
1. **Run Setup Script**: `source firebase_env/bin/activate && python3 force_firebase_auth_setup.py`
2. **Verify Data**: `source firebase_env/bin/activate && python3 verify_auth_setup.py`
3. **Clear and Restart**: Clear app data and restart

### Sync Not Working

**Possible Causes:**
1. Different restaurants logged in on different devices
2. Firebase real-time sync not connected
3. Network connectivity issues

**Solutions:**
1. **Same Restaurant**: Ensure both devices are logged into the same restaurant
2. **Check Logs**: Look for Firebase connection messages in app logs
3. **Wait for Sync**: Real-time updates can take 10-15 seconds

## 🚀 Quick Commands

### Setup Authentication Data
```bash
source firebase_env/bin/activate && python3 force_firebase_auth_setup.py
```

### Verify Setup
```bash
source firebase_env/bin/activate && python3 verify_auth_setup.py
```

### Test Cross-Device Sync
```bash
./test_firebase_sync_with_auth.sh
```

### Clear and Restart Apps
```bash
adb -s emulator-5554 shell pm clear com.restaurantpos.ai_pos_system.debug
adb -s emulator-5556 shell pm clear com.restaurantpos.ai_pos_system.debug
adb -s emulator-5554 shell am start -n com.restaurantpos.ai_pos_system.debug/com.restaurantpos.ai_pos_system.MainActivity
adb -s emulator-5556 shell am start -n com.restaurantpos.ai_pos_system.debug/com.restaurantpos.ai_pos_system.MainActivity
```

## 📊 Expected Results

### Successful Authentication
✅ Login screen accepts credentials
✅ App navigates to main dashboard
✅ Firebase real-time sync connects
✅ Menu items and categories load

### Successful Cross-Device Sync
✅ Both emulators show identical data
✅ Orders created on one device appear on the other
✅ Real-time updates work within 10-15 seconds
✅ No Firebase connection errors

## 🎯 Testing Checklist

- [ ] **Single Device Login**: Can login with correct credentials
- [ ] **Multi-Device Login**: Can login on both emulators with same restaurant
- [ ] **Menu Items Sync**: Both devices show identical menu items
- [ ] **Categories Sync**: Both devices show identical categories
- [ ] **Order Creation**: Can create orders on both devices
- [ ] **Real-time Sync**: Orders appear on both devices within 15 seconds
- [ ] **Different Restaurants**: Can login to different restaurants
- [ ] **User Roles**: Different user roles work correctly

## 🔍 Debug Information

### Check App Logs
```bash
adb -s emulator-5554 logcat -s "flutter" | grep -i "firebase\|auth\|login"
```

### Check Firebase Data
```bash
source firebase_env/bin/activate && python3 verify_auth_setup.py
```

### Check Network Connectivity
```bash
adb -s emulator-5554 shell ping -c 3 google.com
```

## 📞 Support

If you encounter issues:
1. **Check this guide** for troubleshooting steps
2. **Run verification scripts** to check Firebase data
3. **Clear app data** and restart
4. **Use exact credentials** from this guide
5. **Check network connectivity** on emulators

The multi-tenant authentication system is designed to be robust and support multiple restaurants with real-time synchronization across devices. 