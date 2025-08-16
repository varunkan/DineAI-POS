import 'package:flutter/material.dart';

/// Tablet responsive utilities for better tablet experience
class TabletResponsive {
  /// Check if the current device is a tablet
  static bool isTablet(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final diagonal = _calculateDiagonal(size.width, size.height);
    return diagonal > 1100; // 11 inches diagonal threshold
  }

  /// Check if the current device is a large tablet
  static bool isLargeTablet(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final diagonal = _calculateDiagonal(size.width, size.height);
    return diagonal > 1300; // 13 inches diagonal threshold
  }

  /// Calculate screen diagonal
  static double _calculateDiagonal(double width, double height) {
    return (width * width + height * height) / (96 * 96);
  }

  /// Get responsive font size based on device type
  static double getResponsiveFontSize(BuildContext context, {
    double mobile = 14,
    double tablet = 16,
    double largeTablet = 18,
  }) {
    if (isLargeTablet(context)) return largeTablet;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  /// Get responsive padding based on device type
  static EdgeInsets getResponsivePadding(BuildContext context, {
    EdgeInsets? mobile,
    EdgeInsets? tablet,
    EdgeInsets? largeTablet,
  }) {
    final defaultMobile = EdgeInsets.all(16);
    final defaultTablet = EdgeInsets.all(24);
    final defaultLargeTablet = EdgeInsets.all(32);

    if (isLargeTablet(context)) {
      return largeTablet ?? defaultLargeTablet;
    }
    if (isTablet(context)) {
      return tablet ?? defaultTablet;
    }
    return mobile ?? defaultMobile;
  }

  /// Get responsive spacing based on device type
  static double getResponsiveSpacing(BuildContext context, {
    double mobile = 8,
    double tablet = 16,
    double largeTablet = 24,
  }) {
    if (isLargeTablet(context)) return largeTablet;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  /// Get responsive button size based on device type
  static Size getResponsiveButtonSize(BuildContext context, {
    Size? mobile,
    Size? tablet,
    Size? largeTablet,
  }) {
    final defaultMobile = Size(120, 48);
    final defaultTablet = Size(160, 56);
    final defaultLargeTablet = Size(200, 64);

    if (isLargeTablet(context)) {
      return largeTablet ?? defaultLargeTablet;
    }
    if (isTablet(context)) {
      return tablet ?? defaultTablet;
    }
    return mobile ?? defaultMobile;
  }

  /// Get responsive card width based on device type
  static double getResponsiveCardWidth(BuildContext context, {
    double mobile = 300,
    double tablet = 400,
    double largeTablet = 500,
  }) {
    if (isLargeTablet(context)) return largeTablet;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  /// Get responsive grid cross axis count based on device type
  static int getResponsiveGridCount(BuildContext context, {
    int mobile = 2,
    int tablet = 3,
    int largeTablet = 4,
  }) {
    if (isLargeTablet(context)) return largeTablet;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  /// Get responsive icon size based on device type
  static double getResponsiveIconSize(BuildContext context, {
    double mobile = 24,
    double tablet = 32,
    double largeTablet = 40,
  }) {
    if (isLargeTablet(context)) return largeTablet;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  /// Get responsive border radius based on device type
  static BorderRadius getResponsiveBorderRadius(BuildContext context, {
    BorderRadius? mobile,
    BorderRadius? tablet,
    BorderRadius? largeTablet,
  }) {
    final defaultMobile = BorderRadius.circular(8);
    final defaultTablet = BorderRadius.circular(12);
    final defaultLargeTablet = BorderRadius.circular(16);

    if (isLargeTablet(context)) {
      return largeTablet ?? defaultLargeTablet;
    }
    if (isTablet(context)) {
      return tablet ?? defaultTablet;
    }
    return mobile ?? defaultMobile;
  }

  /// Get responsive elevation based on device type
  static double getResponsiveElevation(BuildContext context, {
    double mobile = 2,
    double tablet = 4,
    double largeTablet = 6,
  }) {
    if (isLargeTablet(context)) return largeTablet;
    if (isTablet(context)) return tablet;
    return mobile;
  }

  /// Get responsive aspect ratio based on device type
  static double getResponsiveAspectRatio(BuildContext context, {
    double mobile = 16 / 9,
    double tablet = 4 / 3,
    double largeTablet = 3 / 2,
  }) {
    if (isLargeTablet(context)) return largeTablet;
    if (isTablet(context)) return tablet;
    return mobile;
  }
} 