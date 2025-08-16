plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.restaurantpos.ai_pos_system"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    sourceSets {
        named("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        // This will be overridden by product flavors
        applicationId = "com.restaurantpos.ai_pos_system"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Tablet-specific settings
        // resConfigs("en", "xxhdpi", "xxxhdpi")
    }



    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            // Tablet-specific optimizations
            resValue("bool", "enable_tablet_optimizations", "true")
        }
        
        debug {
            isMinifyEnabled = false
            isDebuggable = true
            // Removed applicationIdSuffix to fix Google Services issue
            versionNameSuffix = "-debug"
        }
    }
    
    // Enable split APKs by ABI for smaller downloads
    /*
    splits {
        abi {
            isEnable = true
            reset()
            include("arm64-v8a", "armeabi-v7a", "x86_64")
            isUniversalApk = false
        }
    }
    */

    // Tablet-specific packaging options
    packagingOptions {
        pickFirst("**/libc++_shared.so")
        pickFirst("**/libfbjni.so")
    }
}

flutter {
    source = "../.."
}

// Dependencies with tablet-specific libraries
dependencies {
    implementation("androidx.window:window:1.2.0")
    implementation("androidx.window:window-java:1.2.0")
    
    // Tablet UI enhancements
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("androidx.recyclerview:recyclerview:1.3.2")
    
    // For better tablet performance
    implementation("androidx.lifecycle:lifecycle-viewmodel-ktx:2.7.0")
    implementation("androidx.lifecycle:lifecycle-livedata-ktx:2.7.0")
}
