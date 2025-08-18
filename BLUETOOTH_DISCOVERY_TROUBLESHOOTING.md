# Bluetooth Discovery Troubleshooting Guide

## 🔵 Why Bluetooth Printers Are Not Getting Discovered

### **Common Causes & Solutions:**

### 1. **Android Emulator Limitations**
**Problem:** Android emulators don't have real Bluetooth hardware
**Solution:** 
- Use a real Android device for Bluetooth testing
- Or use a physical tablet/phone with Bluetooth capability
- Emulators can only simulate Bluetooth, not discover real devices

### 2. **Missing Permissions**
**Problem:** App doesn't have proper Bluetooth permissions
**Solution:**
- ✅ Added Android 12+ permissions to AndroidManifest.xml
- ✅ Added permission_handler dependency
- ✅ Enhanced permission checking in the app

### 3. **Bluetooth Not Enabled**
**Problem:** Bluetooth is disabled on the device
**Solution:**
- Go to device Settings → Bluetooth
- Turn on Bluetooth
- Make sure location services are enabled (required for Bluetooth scanning)

### 4. **Printer Not Paired**
**Problem:** TM-M30III printer is not paired with the device
**Solution:**
- Go to device Bluetooth settings
- Look for "TM-m30iii_020372" in available devices
- If not visible, put printer in pairing mode:
  - Turn off printer
  - Hold feed button while turning on
  - Release after 3 seconds
  - Printer should now be discoverable

### 5. **Android Version Issues**
**Problem:** Different permission requirements for Android versions
**Solution:**
- ✅ Added support for Android 12+ (BLUETOOTH_SCAN, BLUETOOTH_CONNECT)
- ✅ Added support for older Android versions (BLUETOOTH, LOCATION)

## 🛠️ **Enhanced Features Added:**

### ✅ **Improved Permission Handling**
```xml
<!-- Android 12+ Bluetooth permissions -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" 
                 android:usesPermissionFlags="neverForLocation"
                 tools:targetApi="s" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
```

### ✅ **Enhanced Discovery Logic**
- Automatic permission requests
- Better error handling
- Retry logic for failed connections
- TM-M30III specific detection

### ✅ **Comprehensive Logging**
- Detailed step-by-step logs
- Error messages with solutions
- Device discovery status

## 📱 **Testing Steps:**

### **Step 1: Check Device Compatibility**
```bash
# Run the Bluetooth test
flutter run test_bluetooth_discovery.dart -d <device_id>
```

### **Step 2: Use Real Device**
- Connect a real Android device (not emulator)
- Enable Bluetooth and location services
- Pair your TM-M30III printer first

### **Step 3: Test in App**
1. Open the app
2. Go to Settings → Bluetooth Printer Management
3. Tap the help icon (?) for TM-M30III troubleshooting
4. Follow the step-by-step process

## 🔧 **Manual Testing Commands:**

### **Check Bluetooth Status:**
```bash
# Check if Bluetooth is working
flutter run test_bluetooth_discovery.dart
```

### **Check Permissions:**
```bash
# The app will automatically request permissions
# Check device settings if permissions are denied
```

### **Test Connection:**
```bash
# Use the troubleshooting screen in the app
# Or run the TM-M30III specific test
flutter run test_tm_m30iii_connection.dart
```

## 🎯 **For Your TM-m30iii_020372:**

### **Specific Steps:**
1. **Ensure printer is paired:**
   - Go to device Bluetooth settings
   - Look for "TM-m30iii_020372"
   - If not there, pair it first

2. **Check printer status:**
   - Turn on the printer
   - Make sure it's not printing
   - Ensure it's not connected to another device

3. **Test in app:**
   - Use the TM-M30III troubleshooting screen
   - Check the detailed logs
   - Follow any error messages

## 🚨 **Common Error Messages & Solutions:**

### **"Bluetooth is not available"**
- Use a real device, not an emulator
- Check if device has Bluetooth hardware

### **"Bluetooth is not enabled"**
- Enable Bluetooth in device settings
- Enable location services (required for scanning)

### **"No TM-M30III printers found"**
- Pair the printer with your device first
- Check if printer is in pairing mode
- Ensure printer is turned on

### **"Permission denied"**
- Grant Bluetooth permissions when prompted
- Go to device settings → Apps → Your App → Permissions
- Enable Bluetooth and Location permissions

### **"Connection failed"**
- Check if printer is turned on
- Ensure it's not connected to another device
- Keep device within 10 meters of printer
- Try restarting the printer

## 📋 **Checklist for Success:**

- [ ] Using a real Android device (not emulator)
- [ ] Bluetooth enabled on device
- [ ] Location services enabled
- [ ] TM-M30III printer paired with device
- [ ] Printer turned on and ready
- [ ] App has Bluetooth permissions
- [ ] Device within 10 meters of printer
- [ ] No other devices connected to printer

## 🔄 **Next Steps:**

1. **Test on a real device** - Emulators can't discover real Bluetooth devices
2. **Pair your printer first** - Go to device Bluetooth settings
3. **Use the troubleshooting screen** - Tap the help icon in Bluetooth Printer Management
4. **Check the logs** - Look for specific error messages
5. **Follow the solutions** - Each error has a specific fix

## 💡 **Pro Tips:**

- **Real Device Required:** Bluetooth discovery only works on real devices, not emulators
- **Pair First:** Always pair the printer in device settings before using the app
- **Location Required:** Android requires location permission for Bluetooth scanning
- **Keep Close:** Stay within 10 meters of the printer during testing
- **Check Logs:** The troubleshooting screen shows detailed logs for debugging

---

**Remember:** The most common issue is trying to test Bluetooth on an emulator. Use a real Android device for proper Bluetooth testing! 