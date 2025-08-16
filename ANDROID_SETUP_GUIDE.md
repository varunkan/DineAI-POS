# Android Setup Guide for Flutter POS System

## 🎯 **Quick Start Options**

### Option 1: Android Studio (Recommended)
```bash
# 1. Download Android Studio from:
# https://developer.android.com/studio

# 2. Install Android Studio and open it
# 3. Go to Tools → AVD Manager
# 4. Create Virtual Device → Select Phone → Download System Image
# 5. Choose API 34 (Android 14) or latest stable version
# 6. Finish setup and start emulator
```

### Option 2: Command Line Setup
```bash
# Install Android SDK command line tools
# Download from: https://developer.android.com/studio#command-tools

# Set environment variables (add to ~/.zshrc or ~/.bash_profile)
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools

# Create and start emulator
avdmanager create avd -n MyAndroidEmulator -k "system-images;android-34;google_apis;arm64-v8a"
emulator -avd MyAndroidEmulator
```

### Option 3: Physical Android Device
```bash
# 1. Enable Developer Options on your Android device:
#    Settings → About Phone → Tap "Build Number" 7 times

# 2. Enable USB Debugging:
#    Settings → Developer Options → USB Debugging

# 3. Connect device via USB cable
# 4. Accept debugging prompt on device
# 5. Run: flutter devices
```

## 🔧 **Step-by-Step Android Studio Setup**

### 1. Download and Install Android Studio
- Go to [Android Studio](https://developer.android.com/studio)
- Download for macOS
- Install by dragging to Applications folder
- Launch Android Studio

### 2. Configure Android Studio
```bash
# When Android Studio starts:
1. Choose "Standard" installation
2. Accept license agreements
3. Let it download SDK components
4. Wait for indexing to complete
```

### 3. Create Android Virtual Device (AVD)
```bash
# In Android Studio:
1. Click "More Actions" → "AVD Manager"
2. Click "Create Virtual Device"
3. Select "Phone" category
4. Choose "Pixel 7" or similar
5. Click "Next"
6. Download system image (API 34 recommended)
7. Click "Next" → "Finish"
8. Click ▶️ to start emulator
```

### 4. Verify Flutter Android Setup
```bash
# Run Flutter doctor to check Android setup
flutter doctor

# You should see ✓ for Android toolchain
# If not, follow the suggested fixes
```

## 🚀 **Running Your POS App on Android**

### Once Emulator is Running:
```bash
# Check available devices
flutter devices

# Run on Android emulator
flutter run -d android

# Or specify device ID if multiple devices
flutter run -d emulator-5554
```

### Build APK for Distribution:
```bash
# Debug APK (for testing)
flutter build apk --debug

# Release APK (for production)
flutter build apk --release

# App Bundle (for Google Play Store)
flutter build appbundle --release
```

## 📱 **Physical Device Setup**

### Enable Developer Mode:
1. **Settings** → **About Phone**
2. Tap **Build Number** 7 times
3. Go back to **Settings** → **Developer Options**
4. Enable **USB Debugging**
5. Connect USB cable to Mac

### Trust Development Certificate:
1. Connect device to Mac
2. Device will show "Allow USB Debugging?" popup
3. Check "Always allow from this computer"
4. Tap "OK"

### Verify Connection:
```bash
# List connected devices
adb devices

# Should show your device listed
# Example: ABC123DEF456    device
```

## 🛠️ **Troubleshooting Common Issues**

### Issue 1: No Android SDK Found
```bash
# Solution: Set ANDROID_HOME environment variable
echo 'export ANDROID_HOME=$HOME/Library/Android/sdk' >> ~/.zshrc
echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools' >> ~/.zshrc
source ~/.zshrc
```

### Issue 2: Emulator Won't Start
```bash
# Solution: Check virtualization support
# Intel Macs: Enable Intel HAXM
# M1/M2 Macs: Use ARM64 system images

# For M1/M2 Macs, create ARM emulator:
avdmanager create avd -n M1Emulator -k "system-images;android-34;google_apis;arm64-v8a"
```

### Issue 3: Device Not Recognized
```bash
# Solution: Restart ADB server
adb kill-server
adb start-server
adb devices
```

### Issue 4: Build Errors
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter build apk --debug
```

## 📊 **Quick Commands Reference**

```bash
# Check setup
flutter doctor -v

# List devices
flutter devices

# Run on specific device
flutter run -d android
flutter run -d chrome
flutter run -d macos

# Build for Android
flutter build apk --release       # APK file
flutter build appbundle --release # App Bundle (Play Store)

# Install on device
flutter install -d android

# Hot reload during development
# Press 'r' in terminal while app is running

# Hot restart
# Press 'R' in terminal while app is running
```

## 🎯 **Performance Tips for Android**

### Optimize Build Performance:
```bash
# Add to android/gradle.properties
org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=1g -XX:+HeapDumpOnOutOfMemoryError
org.gradle.parallel=true
org.gradle.configureondemand=true
org.gradle.daemon=true
```

### Enable R8 Shrinking:
```bash
# In android/app/build.gradle
android {
    buildTypes {
        release {
            shrinkResources true
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
}
```

## 🔐 **App Signing for Release**

### Generate Signing Key:
```bash
# Create keystore
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Create key.properties file
echo 'storePassword=your_password' > android/key.properties
echo 'keyPassword=your_password' >> android/key.properties
echo 'keyAlias=upload' >> android/key.properties
echo 'storeFile=../upload-keystore.jks' >> android/key.properties
```

### Configure Signing in build.gradle:
```gradle
// In android/app/build.gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
        }
    }
}
```

## 📱 **Testing Your POS App**

### Test Checklist:
- [ ] App launches successfully
- [ ] Login/server selection works
- [ ] Menu items load correctly
- [ ] Order creation functions
- [ ] Cross-platform sync works
- [ ] Offline functionality
- [ ] Print functionality (if printer connected)
- [ ] UI responsive on different screen sizes

### Performance Testing:
```bash
# Run with performance overlay
flutter run --profile

# Monitor GPU performance
flutter run --trace-skia

# Analyze bundle size
flutter build apk --analyze-size
```

## 🚀 **Next Steps After Setup**

1. **Run the app**: `flutter run -d android`
2. **Test cross-platform sync** with web version
3. **Configure Firebase** for production
4. **Test offline functionality**
5. **Build release version** for distribution

---

## 🆘 **Need Help?**

If you encounter issues:
1. Run `flutter doctor -v` and share output
2. Check Android Studio's Event Log for errors
3. Verify device is in Developer Mode
4. Restart Android Studio and emulator
5. Clean and rebuild: `flutter clean && flutter pub get`

Your POS system is designed to work seamlessly across all platforms, including Android! 🎯 