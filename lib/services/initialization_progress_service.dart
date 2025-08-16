import 'package:flutter/foundation.dart';

/// Service to track and display initialization progress messages
class InitializationProgressService extends ChangeNotifier {
  final List<String> _messages = [];
  bool _isCompleted = false;
  String _currentStep = '';
  double _progress = 0.0;
  
  /// Get all progress messages
  List<String> get messages => List.unmodifiable(_messages);
  
  /// Get the current step being executed
  String get currentStep => _currentStep;
  
  /// Get the completion progress (0.0 to 1.0)
  double get progress => _progress;
  
  /// Check if initialization is completed
  bool get isCompleted => _isCompleted;
  
  /// Add a new progress message
  void addMessage(String message) {
    _messages.add(message);
    _currentStep = message;
    notifyListeners();
  }
  
  /// Update progress percentage
  void updateProgress(double progress) {
    _progress = progress.clamp(0.0, 1.0);
    notifyListeners();
  }
  
  /// Mark initialization as completed
  void markCompleted() {
    _isCompleted = true;
    _progress = 1.0;
    _currentStep = '✅ Initialization completed successfully!';
    notifyListeners();
  }
  
  /// Clear all messages and reset
  void reset() {
    _messages.clear();
    _isCompleted = false;
    _currentStep = '';
    _progress = 0.0;
    notifyListeners();
  }
  
  /// Helper method to add timestamped message
  void addTimestampedMessage(String message) {
    final timestamp = DateTime.now().toLocal().toString().substring(11, 19);
    addMessage('[$timestamp] $message');
  }
} 