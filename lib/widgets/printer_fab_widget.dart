import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/printer_configuration_service.dart';
import '../models/printer_configuration.dart';
// import '../screens/smart_printer_hub_screen.dart'; // Temporarily disabled

/// 🖨️ SMART PRINTER FAB
/// 
/// Floating action button that provides quick access to printer management
/// from anywhere in the app. Shows real-time printer status and provides
/// one-touch navigation to the Smart Printer Hub.
class PrinterFabWidget extends StatefulWidget {
  final VoidCallback? onPressed;
  final bool showStatusIndicator;
  final Color? backgroundColor;
  final IconData? customIcon;

  const PrinterFabWidget({
    super.key,
    this.onPressed,
    this.showStatusIndicator = true,
    this.backgroundColor,
    this.customIcon,
  });

  @override
  State<PrinterFabWidget> createState() => _PrinterFabWidgetState();
}

class _PrinterFabWidgetState extends State<PrinterFabWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _bounceController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
    
    _bounceAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PrinterConfigurationService>(
      builder: (context, printerService, child) {
        final activePrinters = printerService.activeConfigurations.length;
        final connectedPrinters = printerService.activeConfigurations
            .where((p) => p.connectionStatus == PrinterConnectionStatus.connected)
            .length;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulsing background for online printers
            if (connectedPrinters > 0 && widget.showStatusIndicator)
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),

            // Main FAB
            AnimatedBuilder(
              animation: _bounceAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _bounceAnimation.value,
                  child: FloatingActionButton(
                    onPressed: _handlePress,
                    backgroundColor: widget.backgroundColor ?? _getFabColor(connectedPrinters, activePrinters),
                    elevation: 8,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(
                          widget.customIcon ?? Icons.print,
                          color: Colors.white,
                          size: 24,
                        ),
                        if (widget.showStatusIndicator && activePrinters > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: connectedPrinters > 0 ? Colors.green : Colors.red,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              child: Center(
                                child: Text(
                                  connectedPrinters.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // Connection status rings
            if (widget.showStatusIndicator && connectedPrinters > 0)
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: 1.0 + (0.1 * _pulseController.value),
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }

  Color _getFabColor(int connected, int total) {
    if (total == 0) return Colors.grey;
    if (connected == 0) return Colors.red;
    if (connected == total) return Colors.green;
    return Colors.orange;
  }

  void _handlePress() {
    _bounceController.forward().then((_) {
      _bounceController.reverse();
    });

    if (widget.onPressed != null) {
      widget.onPressed!();
    } else {
      _navigateToSmartPrinterHub();
    }
  }

  void _navigateToSmartPrinterHub() {
    Navigator.of(context).push(
      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
                  appBar: AppBar(title: const Text('Printer Hub')),
                  body: const Center(child: Text('Printer Hub - Coming Soon')),
                ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.ease;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }
}

/// 🎯 MINI PRINTER STATUS WIDGET
/// 
/// Compact widget showing printer status that can be embedded in app bars
/// or other tight spaces.
class MiniPrinterStatusWidget extends StatelessWidget {
  final bool showCount;
  final VoidCallback? onTap;

  const MiniPrinterStatusWidget({
    super.key,
    this.showCount = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PrinterConfigurationService>(
      builder: (context, printerService, child) {
        final activePrinters = printerService.activeConfigurations.length;
        final connectedPrinters = printerService.activeConfigurations
            .where((p) => p.connectionStatus == PrinterConnectionStatus.connected)
            .length;

        return GestureDetector(
          onTap: onTap ?? () => _navigateToSmartPrinterHub(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                                      color: _getStatusColor(connectedPrinters, activePrinters).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _getStatusColor(connectedPrinters, activePrinters),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.print,
                  size: 14,
                  color: _getStatusColor(connectedPrinters, activePrinters),
                ),
                if (showCount) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$connectedPrinters/$activePrinters',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(connectedPrinters, activePrinters),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(int connected, int total) {
    if (total == 0) return Colors.grey;
    if (connected == 0) return Colors.red;
    if (connected == total) return Colors.green;
    return Colors.orange;
  }

  void _navigateToSmartPrinterHub(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
                    builder: (context) => Scaffold(
              appBar: AppBar(title: const Text('Printer Hub')),
              body: const Center(child: Text('Printer Hub - Coming Soon')),
            ),
      ),
    );
  }
}

/// 🔄 PRINTER STATUS INDICATOR
/// 
/// Simple circular indicator showing printer connection status
class PrinterStatusIndicator extends StatefulWidget {
  final double size;
  final bool showPulse;

  const PrinterStatusIndicator({
    super.key,
    this.size = 12,
    this.showPulse = true,
  });

  @override
  State<PrinterStatusIndicator> createState() => _PrinterStatusIndicatorState();
}

class _PrinterStatusIndicatorState extends State<PrinterStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _pulseAnimation = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PrinterConfigurationService>(
      builder: (context, printerService, child) {
        final connectedPrinters = printerService.activeConfigurations
            .where((p) => p.connectionStatus == PrinterConnectionStatus.connected)
            .length;

        final color = connectedPrinters > 0 ? Colors.green : Colors.red;

        if (widget.showPulse && connectedPrinters > 0) {
          return AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                                          color: color.withValues(alpha: _pulseAnimation.value),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                                              color: color.withValues(alpha: 0.3),
                      blurRadius: 4,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              );
            },
          );
        }

        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
} 