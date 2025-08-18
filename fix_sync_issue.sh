#!/bin/bash

echo "🔧 Fixing Sync Issue on Pixel Tablet Emulator"
echo "============================================="

# Check if emulator is running
EMULATOR_ID=$(adb devices | grep emulator | head -1 | cut -f1)
if [ -z "$EMULATOR_ID" ]; then
    echo "❌ No emulator found. Please start an emulator first."
    exit 1
fi

echo "📱 Using emulator: $EMULATOR_ID"

# Check if app is running
APP_RUNNING=$(adb -s $EMULATOR_ID shell dumpsys activity activities | grep "ai_pos_system" | wc -l)
if [ $APP_RUNNING -eq 0 ]; then
    echo "❌ App is not running. Launching app..."
    adb -s $EMULATOR_ID shell am start -n com.restaurantpos.ai_pos_system/com.restaurantpos.ai_pos_system.MainActivity
    sleep 3
else
    echo "✅ App is running"
fi

echo ""
echo "🔍 Troubleshooting Steps:"
echo "========================="
echo ""
echo "1. 📱 Check if you're logged in:"
echo "   • Look for a login screen or restaurant selection"
echo "   • If you see a login screen, enter your credentials"
echo "   • If you see restaurant selection, choose your restaurant"
echo ""
echo "2. 🔄 Look for the sync button:"
echo "   • The sync button should be in the top-right corner"
echo "   • It looks like this: 🔄 (sync icon)"
echo "   • If you don't see it, try scrolling or check if you're on the main dashboard"
echo ""
echo "3. 🎯 Try these actions:"
echo "   • Tap the menu button (⋮) in the top-right corner"
echo "   • Look for 'Admin Panel' or 'Admin Orders'"
echo "   • These screens also have sync functionality"
echo ""
echo "4. 🔧 If sync button doesn't work:"
echo "   • Try the refresh button (🔄) first"
echo "   • Then try the sync button"
echo "   • Check for any error messages or notifications"
echo ""
echo "5. 📊 Check current orders:"
echo "   • Look at the orders list on the main screen"
echo "   • Count how many orders you see locally"
echo "   • This will help us know if sync is needed"
echo ""

# Monitor logs for sync activity
echo "📋 Monitoring sync logs (press Ctrl+C to stop):"
echo "=============================================="
adb -s $EMULATOR_ID logcat -s flutter | grep -E "(sync|firebase|order|error|success)" --color=never 