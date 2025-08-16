import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/initialization_progress_service.dart';

/// Widget to display initialization progress with real-time messages
class InitializationProgressScreen extends StatefulWidget {
  final String restaurantName;
  final VoidCallback? onCompleted;
  
  const InitializationProgressScreen({
    Key? key,
    required this.restaurantName,
    this.onCompleted,
  }) : super(key: key);
  
  @override
  State<InitializationProgressScreen> createState() => _InitializationProgressScreenState();
}

class _InitializationProgressScreenState extends State<InitializationProgressScreen> 
    with TickerProviderStateMixin {
  late AnimationController _spinnerController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _spinnerController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));
    
    _fadeController.forward();
  }
  
  @override
  void dispose() {
    _spinnerController.dispose();
    _fadeController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Consumer<InitializationProgressService>(
            builder: (context, progressService, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    // Header section
                    _buildHeader(),
                    
                    // Main content
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            // Progress indicator
                            _buildProgressIndicator(progressService),
                            
                            const SizedBox(height: 32),
                            
                            // Current step
                            _buildCurrentStep(progressService),
                            
                            const SizedBox(height: 24),
                            
                            // Progress messages
                            Expanded(
                              child: _buildProgressMessages(progressService),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Restaurant logo/icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
            ),
            child: const Icon(
              Icons.restaurant,
              size: 48,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Restaurant name
          Text(
            widget.restaurantName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 8),
          
          // Subtitle
          Text(
            'Setting up your POS system...',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgressIndicator(InitializationProgressService progressService) {
    return Column(
      children: [
        // Animated spinner
        AnimatedBuilder(
          animation: _spinnerController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _spinnerController.value * 2.0 * 3.14159,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                    width: 3,
                  ),
                ),
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  strokeWidth: 3,
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 16),
        
        // Progress bar
        Container(
          width: double.infinity,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressService.progress,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Progress percentage
        Text(
          '${(progressService.progress * 100).toInt()}%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildCurrentStep(InitializationProgressService progressService) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current Step:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            progressService.currentStep.isEmpty 
                ? 'Starting initialization...' 
                : progressService.currentStep,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProgressMessages(InitializationProgressService progressService) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Progress Log:',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: progressService.messages.isEmpty
                ? const Center(
                    child: Text(
                      'Preparing to initialize services...',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    reverse: true, // Show newest messages at the top
                    itemCount: progressService.messages.length,
                    itemBuilder: (context, index) {
                      final message = progressService.messages[progressService.messages.length - 1 - index];
                      
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: index == 0 
                              ? Colors.white.withValues(alpha: 0.2)  // Highlight current message
                              : Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: index == 0 
                              ? Border.all(color: Colors.white.withValues(alpha: 0.3))
                              : null,
                        ),
                        child: Row(
                          children: [
                            // Icon based on message type
                            Icon(
                              _getMessageIcon(message),
                              size: 16,
                              color: index == 0 ? Colors.white : Colors.white70,
                            ),
                            const SizedBox(width: 8),
                            // Message text
                            Expanded(
                              child: Text(
                                message,
                                style: TextStyle(
                                  color: index == 0 ? Colors.white : Colors.white70,
                                  fontSize: 13,
                                  fontWeight: index == 0 ? FontWeight.w500 : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
  
  IconData _getMessageIcon(String message) {
    if (message.contains('✅')) return Icons.check_circle;
    if (message.contains('🔐')) return Icons.security;
    if (message.contains('📱')) return Icons.phone_android;
    if (message.contains('🍽️')) return Icons.restaurant_menu;
    if (message.contains('📝')) return Icons.note;
    if (message.contains('🏪')) return Icons.store;
    if (message.contains('🔧')) return Icons.build;
    if (message.contains('🧹')) return Icons.cleaning_services;
    if (message.contains('❌')) return Icons.error;
    return Icons.info;
  }
} 