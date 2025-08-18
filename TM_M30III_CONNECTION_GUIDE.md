# TM-M30III Bluetooth Connection Troubleshooting Guide

## 🖨️ Quick Fix for TM-m30iii_020372 Connection Issues

### Immediate Steps to Try:

1. **Check Bluetooth Pairing**
   - Go to your device's Bluetooth settings
   - Look for "TM-m30iii_020372" in the paired devices list
   - If not paired, put the printer in pairing mode and pair it first

2. **Printer Power & Status**
   - Ensure the printer is turned ON
   - Check if the printer is not currently printing
   - Make sure it's not connected to another device

3. **Distance & Interference**
   - Keep your device within 10 meters of the printer
   - Move away from other Bluetooth devices that might cause interference
   - Try turning off other Bluetooth devices temporarily

### Enhanced Discovery Features Added:

✅ **Enhanced Bluetooth Discovery**
- Now specifically looks for TM-M30III printers
- Detects devices with "020372" in the name or address
- Improved logging to show exactly what devices are found

✅ **Retry Logic for Connections**
- Automatically retries failed connections up to 3 times
- 10-second timeout for each connection attempt
- 2-second delay between retry attempts

✅ **TM-M30III Specific Initialization**
- Sends proper ESC/POS initialization commands
- Configures character encoding and alignment
- Optimized for TM-M30III printer model

### How to Use the New Features:

1. **Open the Bluetooth Printer Management Screen**
   - Navigate to Settings → Bluetooth Printer Management

2. **Use the Troubleshooting Tool**
   - Tap the help icon (?) in the top-right corner
   - This opens the TM-M30III Troubleshooting Screen
   - Follow the step-by-step process

3. **Check the Log Messages**
   - The troubleshooting screen shows detailed logs
   - Look for specific error messages
   - Follow the suggested solutions

### Common Issues and Solutions:

#### Issue: "No TM-M30III printers found"
**Solution:**
- Make sure the printer is paired with your device
- Go to Bluetooth settings and pair "TM-m30iii_020372"
- Put the printer in pairing mode (usually hold a button for 3 seconds)

#### Issue: "Connection failed"
**Solution:**
- Check if printer is turned on and not printing
- Ensure it's not connected to another device
- Try restarting the printer
- Keep device within 10 meters

#### Issue: "Bluetooth not available"
**Solution:**
- Enable Bluetooth in your device settings
- Check if Bluetooth permissions are granted to the app
- Restart your device if needed

#### Issue: "Test print failed"
**Solution:**
- Check if printer has paper
- Ensure printer is not in error state
- Try restarting the printer
- Check if the print head is clean

### Advanced Troubleshooting:

1. **Reset Printer Settings**
   - Turn off the printer
   - Hold the feed button while turning it on
   - Release after 3 seconds
   - This resets Bluetooth settings

2. **Clear Bluetooth Cache**
   - Go to device Bluetooth settings
   - Forget the TM-m30iii_020372 device
   - Re-pair the printer

3. **Check Printer Firmware**
   - Ensure printer has latest firmware
   - Contact Epson support if needed

### Testing Your Connection:

1. **Use the Test Script**
   - Run `test_tm_m30iii_connection.dart` to quickly test
   - This will show detailed connection status

2. **Check Device Logs**
   - Look at the troubleshooting screen logs
   - Each step shows success/failure status

3. **Verify Print Output**
   - Send a test print
   - Check if the receipt prints correctly
   - Verify text alignment and formatting

### For Customer Orders:

Once connected successfully:
- The printer will automatically receive orders
- Test with a simple order first
- Monitor the connection status in the app
- Keep the device close to the printer during service

### Support Information:

If issues persist:
1. Check the troubleshooting logs for specific error messages
2. Note the exact error text and timing
3. Ensure all steps in this guide have been tried
4. Contact support with the specific error details

### Quick Reference Commands:

```bash
# Test connection (if you have Flutter installed)
flutter run test_tm_m30iii_connection.dart

# Check Bluetooth status
flutter run -d <device_id> --target=lib/main.dart
```

### Success Indicators:

✅ **Connection Successful When:**
- Troubleshooting screen shows "Connected" status
- Test print prints correctly
- No error messages in logs
- Printer responds to commands

🎉 **Ready for Customer Orders When:**
- All connection tests pass
- Test print is readable
- Printer stays connected during testing
- No timeout or disconnection errors

---

**Remember:** The TM-M30III is a reliable printer, and most connection issues are related to pairing or proximity. Follow this guide step-by-step, and your printer should connect successfully for customer orders. 