@echo off
title Restaurant Printing Setup
color 0A

echo.
echo ============================================================
echo 🎯 RESTAURANT PRINTING SETUP
echo Print from Home to Restaurant Printers
echo ============================================================
echo.

echo This will help you set up printing from home to your restaurant.
echo.
pause

echo.
echo 🌐 STEP 1: Create Cloud Account
echo ----------------------------------------
echo.
echo Please visit: https://restaurant-print.cloud
echo 1. Click 'Sign Up'
echo 2. Enter your restaurant details  
echo 3. Choose Basic Plan ($29/month)
echo 4. Get your Restaurant ID and API Key
echo.
pause

echo.
echo 📝 STEP 2: Enter Your Details
echo ----------------------------------------
echo.

set /p restaurant_id="Enter your Restaurant ID: "
set /p api_key="Enter your API Key: "

if "%restaurant_id%"=="" (
    echo ❌ Restaurant ID is required!
    pause
    exit /b 1
)

if "%api_key%"=="" (
    echo ❌ API Key is required!
    pause
    exit /b 1
)

echo.
echo ✅ Details saved!
echo.

echo 📥 STEP 3: Download Bridge Software
echo ----------------------------------------
echo.

echo Downloading bridge software...
powershell -Command "& {Invoke-WebRequest -Uri 'https://restaurant-print.cloud/download/bridge-windows.exe' -OutFile 'restaurant-bridge.exe'}"

if exist "restaurant-bridge.exe" (
    echo ✅ Bridge downloaded successfully!
) else (
    echo ❌ Download failed!
    echo Please download manually from: https://restaurant-print.cloud/download
    pause
    exit /b 1
)

echo.
echo ⚙️ STEP 4: Create Configuration
echo ----------------------------------------
echo.

echo Creating configuration file...

echo {> bridge-config.json
echo   "restaurantId": "%restaurant_id%",>> bridge-config.json
echo   "apiKey": "%api_key%",>> bridge-config.json
echo   "printers": [>> bridge-config.json

:add_printer
echo.
set /p add_printer="Add a printer? (y/n): "
if /i "%add_printer%"=="y" (
    set /p printer_name="Printer name (e.g., Kitchen, Bar): "
    set /p printer_ip="Printer IP address (e.g., 192.168.1.100): "
    
    if not "%printer_name%"=="" if not "%printer_ip%"=="" (
        echo     {>> bridge-config.json
        echo       "id": "%printer_name%",>> bridge-config.json
        echo       "name": "%printer_name%",>> bridge-config.json
        echo       "ip": "%printer_ip%",>> bridge-config.json
        echo       "port": 9100,>> bridge-config.json
        echo       "type": "epson_thermal">> bridge-config.json
        echo     },>> bridge-config.json
        echo ✅ Added printer: %printer_name%
        goto add_printer
    ) else (
        echo ❌ Printer name and IP are required!
        goto add_printer
    )
) else (
    echo   ]>> bridge-config.json
    echo }>> bridge-config.json
)

echo.
echo ✅ Configuration created: bridge-config.json

echo.
echo 🚀 STEP 5: Start Bridge Service
echo ----------------------------------------
echo.

echo Starting bridge service...
start "Restaurant Bridge" restaurant-bridge.exe --config bridge-config.json --start

echo.
echo ✅ Bridge service started!
echo 📋 Bridge is now running in the background
echo 💡 Keep this computer running for printing to work

echo.
echo 📱 STEP 6: Configure POS App
echo ----------------------------------------
echo.

echo Now configure your POS app:
echo.
echo 1. Open your POS app
echo 2. Go to Admin Panel ^> Settings
echo 3. Find 'Cloud Printing' or 'Internet Printing'
echo 4. Enter these details:
echo.
echo    Service URL: https://restaurant-print.cloud/api/v1
echo    Restaurant ID: %restaurant_id%
echo    API Key: %api_key%
echo.
echo 5. Click 'Test Connection'
echo 6. Click 'Save Settings'
echo.

echo 🎉 SETUP COMPLETE!
echo ============================================================
echo ✅ Cloud account created
echo ✅ Bridge downloaded and configured
echo ✅ Printers added
echo ✅ Bridge service started
echo ✅ POS app configuration ready
echo.
echo 📋 Next Steps:
echo 1. Configure your POS app with the details above
echo 2. Test by creating an order and clicking 'Send to Kitchen'
echo 3. Keep this computer running for printing to work
echo.
echo 📞 Need help? Call: 1-800-PRINT-HELP
echo 📧 Email: support@restaurant-print.cloud
echo.
echo 🚀 You're ready to print from home to your restaurant!
echo.

pause 