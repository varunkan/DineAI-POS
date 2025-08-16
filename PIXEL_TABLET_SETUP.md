# Pixel Tablet Development Setup

This Flutter POS system is now configured to run on the **Pixel Tablet API 34** emulator by default, providing an optimal tablet experience for restaurant point-of-sale operations.

## 🚀 Quick Start

### Method 1: Using the Run Script (Recommended)
```bash
# Run in debug mode (default)
./run_tablet.sh

# Run in release mode
./run_tablet.sh release

# Run in profile mode
./run_tablet.sh profile
```

### Method 2: Using VS Code
1. Open the project in VS Code
2. Press `F5` or go to Run > Start Debugging
3. Select "Launch (Pixel Tablet)" from the configuration dropdown
4. The app will automatically launch on the Pixel Tablet emulator

### Method 3: Using Command Line Aliases
```bash
# Set up convenient aliases
source setup_aliases.sh

# Then use any of these commands:
run-pos           # Run app on Pixel Tablet (debug)
run-pos-release   # Run app on Pixel Tablet (release)
build-pos         # Build APK for development
install-pos       # Install and launch APK on Pixel Tablet
start-tablet      # Start Pixel Tablet emulator
check-devices     # List available devices
clean-pos         # Clean, rebuild, and build APK
```

### Method 4: Direct Flutter Commands
```bash
# Start emulator if not running
flutter emulators --launch Pixel_Tablet_API_34

# Run the app
flutter run --debug --target=lib/main_dev.dart -d Pixel_Tablet_API_34
```

## 📱 Available Emulators

The project supports these emulators:
- **Pixel_Tablet_API_34** (Default - Recommended for POS)
- **Pixel_7_API_34** (Phone form factor)
- **Simple_Tablet** (Alternative tablet)
- **Medium_Phone_API_36.0** (Testing phone compatibility)

## 🛠️ VS Code Configuration

The project includes:
- **`.vscode/launch.json`** - Launch configurations for different targets
- **`.vscode/settings.json`** - Flutter development settings optimized for tablet development

## 📁 Files Created

- `run_tablet.sh` - Cross-platform script to run on Pixel Tablet
- `run_tablet.bat` - Windows batch script
- `setup_aliases.sh` - Convenient command aliases
- `.vscode/launch.json` - VS Code launch configurations
- `.vscode/settings.json` - VS Code Flutter settings

## 🎯 Why Pixel Tablet?

The Pixel Tablet API 34 provides:
- **Optimal Screen Size**: 10.95" display perfect for POS operations
- **Modern Android**: API 34 (Android 14) with latest features
- **Touch-Optimized**: Ideal for restaurant staff interaction
- **Performance**: Smooth operation for real-time order management

## 🔧 Customization

To change the default emulator:
1. Edit the `deviceId` in `.vscode/launch.json`
2. Update the device ID in `run_tablet.sh` and `run_tablet.bat`
3. Modify the aliases in `setup_aliases.sh`

## 📊 Square Tile Layout

The POS Dashboard now features:
- **4 orders per row** in square tiles
- **Responsive design** optimized for tablet screens
- **Touch-friendly** interface for restaurant staff
- **Color-coded status** indicators for quick visual identification

## 🐛 Troubleshooting

**Emulator not starting?**
```bash
# Check available emulators
flutter emulators

# Manually start emulator
flutter emulators --launch Pixel_Tablet_API_34

# Check if device is connected
flutter devices
```

**Build issues?**
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --target=lib/main_dev.dart --debug
```

## 🎉 Ready to Go!

Your Flutter POS system is now configured for optimal tablet development. Simply run `./run_tablet.sh` and start building amazing restaurant experiences! 