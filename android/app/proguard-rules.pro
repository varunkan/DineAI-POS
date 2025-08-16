# Flutter-specific ProGuard rules for tablet optimization

# Keep Flutter engine
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.plugin.platform.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep Google Play Core classes (fix for R8 minification issues)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Fix for Flutter Play Store deferred components issue
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# Keep printer-related classes
-keep class net.posprinter.** { *; }
-keep class com.dantsu.escposprinter.** { *; }

# Keep database-related classes
-keep class sqflite.** { *; }
-keep class com.tekartik.sqflite.** { *; }

# Keep platform channels
-keep class io.flutter.plugin.common.MethodChannel { *; }
-keep class io.flutter.plugin.common.EventChannel { *; }

# Keep JSON serialization
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Keep tablet-specific optimizations
-keep class androidx.window.** { *; }
-keep class androidx.lifecycle.** { *; }

# Tablet performance optimizations
-optimizations !code/simplification/arithmetic,!field/*,!class/merging/*
-allowaccessmodification
-dontpreverify

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep R class
-keep class **.R$* { *; }

# General Android optimizations
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.** 