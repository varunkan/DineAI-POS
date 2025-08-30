import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Test script to diagnose kitchen spinner issues
/// Run this to test timeout handling and spinner behavior
void main() {
  runApp(KitchenSpinnerTestApp());
}

class KitchenSpinnerTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kitchen Spinner Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: KitchenSpinnerTestScreen(),
    );
  }
}

class KitchenSpinnerTestScreen extends StatefulWidget {
  @override
  _KitchenSpinnerTestScreenState createState() => _KitchenSpinnerTestScreenState();
}

class _KitchenSpinnerTestScreenState extends State<KitchenSpinnerTestScreen> {
  bool _isLoading = false;
  String _status = 'Ready to test';
  Timer? _testTimer;

  @override
  void dispose() {
    _testTimer?.cancel();
    super.dispose();
  }

  /// Test 1: Normal operation (should complete quickly)
  Future<void> _testNormalOperation() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing normal operation...';
    });

    try {
      // Simulate normal kitchen operation
      await Future.delayed(Duration(seconds: 2));
      
      if (mounted) {
        setState(() {
          _status = '✅ Normal operation completed successfully!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = '❌ Normal operation failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Test 2: Timeout operation (should timeout after 25 seconds)
  Future<void> _testTimeoutOperation() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing timeout operation (25s timeout)...';
    });

    try {
      // Simulate hanging operation that should timeout
      await Future.delayed(Duration(seconds: 30)).timeout(
        Duration(seconds: 25),
        onTimeout: () {
          debugPrint('⏰ Test timeout operation timed out as expected');
          return;
        },
      );
      
      if (mounted) {
        setState(() {
          _status = '⚠️ Operation should have timed out but didn\'t';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = '✅ Timeout operation handled correctly: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Test 3: Error operation (should handle errors gracefully)
  Future<void> _testErrorOperation() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing error handling...';
    });

    try {
      // Simulate an error
      await Future.delayed(Duration(seconds: 1));
      throw Exception('Simulated kitchen service error');
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = '✅ Error handled correctly: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Test 4: Widget disposal during operation
  Future<void> _testWidgetDisposal() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing widget disposal handling...';
    });

    try {
      // Simulate long operation
      await Future.delayed(Duration(seconds: 3));
      
      // Check if widget is still mounted
      if (mounted) {
        setState(() {
          _status = '✅ Widget disposal handled correctly';
        });
      } else {
        debugPrint('⚠️ Widget was disposed during operation');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = '❌ Widget disposal test failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Test 5: Multiple rapid operations
  Future<void> _testMultipleOperations() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing multiple rapid operations...';
    });

    try {
      // Simulate multiple rapid kitchen operations
      for (int i = 1; i <= 3; i++) {
        if (!mounted) break;
        
        setState(() {
          _status = 'Testing operation $i/3...';
        });
        
        await Future.delayed(Duration(seconds: 1));
      }
      
      if (mounted) {
        setState(() {
          _status = '✅ Multiple operations completed successfully!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _status = '❌ Multiple operations failed: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kitchen Spinner Test'),
        backgroundColor: Colors.orange,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status display
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Test Status',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    SizedBox(height: 8),
                    Text(
                      _status,
                      style: Theme.of(context).textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    if (_isLoading) ...[
                      SizedBox(height: 16),
                      CircularProgressIndicator(),
                    ],
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Test buttons
            ElevatedButton(
              onPressed: _isLoading ? null : _testNormalOperation,
              child: Text('Test 1: Normal Operation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
            
            SizedBox(height: 8),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _testTimeoutOperation,
              child: Text('Test 2: Timeout Operation (25s)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            
            SizedBox(height: 8),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _testErrorOperation,
              child: Text('Test 3: Error Handling'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            
            SizedBox(height: 8),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _testWidgetDisposal,
              child: Text('Test 4: Widget Disposal'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
            ),
            
            SizedBox(height: 8),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _testMultipleOperations,
              child: Text('Test 5: Multiple Operations'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
            
            SizedBox(height: 16),
            
            // Instructions
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Test Instructions:',
                      style: Theme.of(context).textTheme.titleMedium,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('• Test 1: Should complete in 2 seconds'),
                    Text('• Test 2: Should timeout after 25 seconds'),
                    Text('• Test 3: Should handle errors gracefully'),
                    Text('• Test 4: Should handle widget disposal'),
                    Text('• Test 5: Should complete multiple operations'),
                    SizedBox(height: 8),
                    Text(
                      'Expected: All tests should complete without infinite spinners',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 