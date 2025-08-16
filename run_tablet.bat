@echo off
REM Script to run the Flutter app on Pixel Tablet by default
REM Usage: run_tablet.bat [debug|release|profile]

echo 🚀 Running Flutter POS App on Pixel Tablet...

REM Check if any emulator is running
for /f "tokens=1" %%i in ('adb devices ^| findstr emulator') do set TABLET_RUNNING=%%i

if "%TABLET_RUNNING%"=="" (
    echo 📱 Starting Pixel Tablet emulator...
    start /b flutter emulators --launch Pixel_Tablet_API_34
    
    echo ⏳ Waiting for emulator to start...
    timeout /t 10 /nobreak >nul
    
    REM Wait for device to be ready
    adb wait-for-device
    echo ✅ Emulator is ready!
)

REM Determine build mode
set MODE=%1
if "%MODE%"=="" set MODE=debug
set TARGET=lib/main_dev.dart

if /i "%MODE%"=="release" (
    echo 🏗️  Building and running in release mode...
    flutter run --release --target=%TARGET% -d Pixel_Tablet_API_34
) else if /i "%MODE%"=="profile" (
    echo 🏗️  Building and running in profile mode...
    flutter run --profile --target=%TARGET% -d Pixel_Tablet_API_34
) else (
    echo 🏗️  Building and running in debug mode...
    flutter run --debug --target=%TARGET% -d Pixel_Tablet_API_34
)

echo 🎉 App is running on Pixel Tablet!
pause 