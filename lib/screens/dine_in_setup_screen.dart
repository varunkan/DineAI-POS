import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/user.dart';
import '../models/table.dart' as restaurant_table;
import '../services/table_service.dart';
import 'order_creation_screen.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;

class DineInSetupScreen extends StatefulWidget {
  final User user;

  const DineInSetupScreen({super.key, required this.user});

  @override
  State<DineInSetupScreen> createState() => _DineInSetupScreenState();
}

class _DineInSetupScreenState extends State<DineInSetupScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _tableNumberController = TextEditingController();
  final TextEditingController _capacityController = TextEditingController(text: '4');
  int _numberOfPeople = 4;
  bool _isLoading = false;
  List<restaurant_table.Table> _tables = [];
  restaurant_table.Table? _selectedTable;
  
  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  
  // Animations
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;
  
  int _currentStep = 0; // Start with table selection (0)
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadTables();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _rotationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.bounceOut),
    );
    
    _rotationAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start animations
    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
    _rotationController.repeat();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _tableNumberController.dispose();
    _capacityController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadTables() async {
    final tableService = Provider.of<TableService>(context, listen: false);
    
    // Always ensure we have exactly 16 tables for restaurant operation
    await tableService.resetTablesToDefault();
    final tables = await tableService.getTables();
    
    setState(() {
      _tables = tables;
    });
    
  }

  void _selectTable(restaurant_table.Table table) {
    if (table.isAvailable) {
      HapticFeedback.lightImpact();
      setState(() {
        _selectedTable = table;
        _tableNumberController.text = table.number.toString();
        _capacityController.text = table.capacity.toString();
        _numberOfPeople = table.capacity;
      });
      
      // Animate to next step
      _nextStep();
    } else {
      HapticFeedback.heavyImpact();
      _showErrorSnackBar('Table ${table.number} is currently occupied!');
    }
  }

  void _nextStep() {
    if (_currentStep < 1) { // Only 2 steps now (0: table selection, 1: guest configuration)
      setState(() => _currentStep++);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.animateToPage(
        _currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: const Color(0xFFE57373),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
    }
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: const Color(0xFF66BB6A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
    }
  }

  Future<void> _createOrUseTable() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();
    
    try {
      final tableService = Provider.of<TableService>(context, listen: false);
      
      // Use selected table if available, otherwise create/use custom table
      if (_selectedTable != null) {
        if (_selectedTable!.isAvailable) {
          _navigateToOrderCreation(_selectedTable!);
        } else {
          throw Exception('Table ${_selectedTable!.number} is currently occupied!');
        }
      } else {
        // Create custom table with current settings
        final inputTableNumber = int.tryParse(_tableNumberController.text.trim()) ?? 1;
        final inputCapacity = _numberOfPeople;
        
        restaurant_table.Table? existingTable;
        for (final table in _tables) {
          if (table.number == inputTableNumber) {
            existingTable = table;
            break;
          }
        }

        if (existingTable != null) {
          if (existingTable.isAvailable) {
            _navigateToOrderCreation(existingTable);
          } else {
            throw Exception('Table $inputTableNumber is currently occupied!');
          }
        } else {
          await tableService.createTable(inputTableNumber, inputCapacity);
          final newTable = restaurant_table.Table(
            number: inputTableNumber,
            capacity: inputCapacity,
            status: restaurant_table.TableStatus.available,
          );
          _navigateToOrderCreation(newTable);
        }
      }
    } catch (e) {
      _showErrorSnackBar(e.toString().replaceAll('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToOrderCreation(restaurant_table.Table table) {
    if (!mounted) return;
    
    HapticFeedback.heavyImpact();
    _showSuccessSnackBar('Table ${table.number} selected! Starting order...');
    
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      
      try {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => OrderCreationScreen(
              user: widget.user,
              table: table,
              numberOfPeople: _numberOfPeople,
              orderType: 'dine-in',
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
                child: child,
              );
            },
          ),
        );
      } catch (e) {
        if (mounted) {
          _showErrorSnackBar('Failed to start order creation. Please try again.');
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF667eea),
              const Color(0xFF764ba2),
              const Color(0xFFf093fb),
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  // Custom App Bar - responsive height
                  SizedBox(
                    height: constraints.maxHeight * 0.12,
                    child: _buildCustomAppBar(theme, constraints),
                  ),
                  
                  // Progress Indicator - responsive height
                  SizedBox(
                    height: constraints.maxHeight * 0.08,
                    child: _buildProgressIndicator(theme, constraints),
                  ),
                  
                  // Main Content - takes remaining space
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildTableSelectionStep(constraints, theme),
                        _buildGuestConfigurationStep(constraints, theme),
                      ],
                    ),
                  ),
                  
                  // Navigation Buttons - responsive height
                  SizedBox(
                    height: constraints.maxHeight * 0.1,
                    child: _buildNavigationButtons(theme, constraints),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCustomAppBar(ThemeData theme, BoxConstraints constraints) {
    final horizontalPadding = constraints.maxWidth * 0.02;
    final iconSize = math.min(constraints.maxHeight * 0.03, 24.0);
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: iconSize),
                padding: EdgeInsets.all(8),
              ),
            ),
            SizedBox(width: constraints.maxWidth * 0.02),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Dine-In Setup',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: math.min(constraints.maxHeight * 0.025, 20),
                    ),
                  ),
                  Text(
                    'Configure your dining experience',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: math.min(constraints.maxHeight * 0.018, 14),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value,
                  child: Container(
                    padding: EdgeInsets.all(constraints.maxHeight * 0.015),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: Icon(
                      Icons.restaurant,
                      color: Colors.white,
                      size: iconSize,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(ThemeData theme, BoxConstraints constraints) {
    final horizontalPadding = constraints.maxWidth * 0.02;
    
    return SlideTransition(
      position: _slideAnimation,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: List.generate(2, (index) {
                  final isActive = index <= _currentStep;
                  
                  return Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 4,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(2),
                              color: isActive
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        if (index < 1) SizedBox(width: constraints.maxWidth * 0.01),
                      ],
                    ),
                  );
                }),
              ),
            ),
            SizedBox(height: constraints.maxHeight * 0.01),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStepLabel('Select Table', 0, constraints),
                _buildStepLabel('Configure Guests', 1, constraints),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepLabel(String label, int stepIndex, BoxConstraints constraints) {
    final isActive = stepIndex == _currentStep;
    return AnimatedDefaultTextStyle(
      duration: const Duration(milliseconds: 300),
      style: TextStyle(
        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.6),
        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
        fontSize: math.min(constraints.maxHeight * 0.015, 12),
      ),
      child: Text(label),
    );
  }

  Widget _buildTableSelectionStep(BoxConstraints constraints, ThemeData theme) {
    final horizontalPadding = constraints.maxWidth * 0.02;
    
    return SlideTransition(
      position: _slideAnimation,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - responsive height
            SizedBox(
              height: constraints.maxHeight * 0.15,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Choose Your Table',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: math.min(constraints.maxHeight * 0.03, 24),
                    ),
                  ),
                  SizedBox(height: constraints.maxHeight * 0.005),
                  Text(
                    'Select from our available tables or create a custom seating arrangement',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: math.min(constraints.maxHeight * 0.018, 14),
                    ),
                  ),
                ],
              ),
            ),
            
            // Restaurant Floor Plan - takes most of the space
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: _tables.isEmpty
                    ? const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : _buildResponsiveTableGrid(constraints),
              ),
            ),
            
            SizedBox(height: constraints.maxHeight * 0.01),
            
            // Manual Input Section - responsive height
            Container(
              height: constraints.maxHeight * 0.12,
              padding: EdgeInsets.all(constraints.maxWidth * 0.02),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Custom Table Setup',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: math.min(constraints.maxHeight * 0.02, 16),
                    ),
                  ),
                  SizedBox(height: constraints.maxHeight * 0.01),
                  Expanded(
                    child: Form(
                      key: _formKey,
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildCustomTextField(
                              controller: _tableNumberController,
                              label: 'Table #',
                              icon: Icons.table_restaurant,
                              keyboardType: TextInputType.number,
                              constraints: constraints,
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Required';
                                if (int.tryParse(value) == null) return 'Invalid';
                                return null;
                              },
                            ),
                          ),
                          SizedBox(width: constraints.maxWidth * 0.02),
                          Expanded(
                            child: _buildCustomTextField(
                              controller: _capacityController,
                              label: 'Capacity',
                              icon: Icons.people,
                              keyboardType: TextInputType.number,
                              constraints: constraints,
                              validator: (value) {
                                if (value == null || value.isEmpty) return 'Required';
                                final capacity = int.tryParse(value);
                                if (capacity == null || capacity < 1) return 'Invalid';
                                return null;
                              },
                              onChanged: (value) {
                                final capacity = int.tryParse(value);
                                if (capacity != null && capacity > 0) {
                                  setState(() => _numberOfPeople = capacity);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveTableGrid(BoxConstraints constraints) {
    return LayoutBuilder(
      builder: (context, gridConstraints) {
        final availableWidth = gridConstraints.maxWidth - (constraints.maxWidth * 0.04);
        final tableCount = _tables.length;
        
        // Calculate optimal grid layout with better spacing
        int columns;
        double itemSize;
        
        if (availableWidth > 1200) {
          columns = 6;
          itemSize = math.min(140, availableWidth / 6 - 12);
        } else if (availableWidth > 900) {
          columns = 5;
          itemSize = math.min(120, availableWidth / 5 - 12);
        } else if (availableWidth > 600) {
          columns = 4;
          itemSize = math.min(100, availableWidth / 4 - 12);
        } else {
          columns = 3;
          itemSize = math.min(90, availableWidth / 3 - 12);
        }
        
        final spacing = math.max(8.0, math.min(availableWidth * 0.015, 16.0));
        
        return Padding(
          padding: EdgeInsets.all(constraints.maxWidth * 0.02),
          child: GridView.builder(
            physics: const BouncingScrollPhysics(), // Allow scrolling to prevent overflow
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: 1.0,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
            ),
            itemCount: _tables.length,
            itemBuilder: (context, index) => _buildTableCard(_tables[index], itemSize, constraints),
          ),
        );
      },
    );
  }

  Widget _buildTableCard(restaurant_table.Table table, double size, BoxConstraints constraints) {
    final isSelected = _selectedTable?.id == table.id;
    
    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isSelected ? _pulseAnimation.value : _scaleAnimation.value,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isSelected
                    ? [Colors.amber.shade300, Colors.amber.shade500]
                    : table.isAvailable
                        ? [Colors.green.shade100, Colors.green.shade200]
                        : [Colors.red.shade100, Colors.red.shade200],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected 
                    ? Colors.amber.shade700 
                    : table.isAvailable
                        ? Colors.green.shade400
                        : Colors.red.shade400,
                width: isSelected ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isSelected 
                      ? Colors.amber 
                      : table.isAvailable 
                          ? Colors.green 
                          : Colors.red).withValues(alpha: 0.3),
                  blurRadius: isSelected ? 12 : 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: table.isAvailable ? () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _selectedTable = table;
                  });
                } : () {
                  HapticFeedback.heavyImpact();
                  _showErrorSnackBar('Table ${table.number} is currently occupied!');
                },
                child: Padding(
                  padding: EdgeInsets.all(math.max(size * 0.08, 8.0)),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        table.isAvailable ? Icons.table_restaurant : Icons.table_restaurant_outlined,
                        size: math.max(size * 0.35, 24.0),
                        color: isSelected 
                            ? Colors.amber.shade800 
                            : table.isAvailable 
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                      ),
                      SizedBox(height: math.max(size * 0.06, 4.0)),
                      Flexible(
                        child:                           Text(
                            'Table ${table.number}',
                            style: TextStyle(
                              fontSize: math.max(size * 0.18, 14.0), // Bigger text
                              fontWeight: FontWeight.w900, // Extra bold
                              color: isSelected 
                                  ? Colors.amber.shade900 
                                  : table.isAvailable 
                                      ? Colors.green.shade800
                                      : Colors.red.shade800,
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ),
                      SizedBox(height: math.max(size * 0.02, 2.0)),
                      Flexible(
                        child:                           Text(
                            '${table.capacity} seats',
                            style: TextStyle(
                              fontSize: math.max(size * 0.13, 11.0), // Bigger text
                              fontWeight: FontWeight.w700, // Bold
                              color: isSelected 
                                  ? Colors.amber.shade700 
                                  : table.isAvailable 
                                      ? Colors.green.shade600
                                      : Colors.red.shade600,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ),
                      if (isSelected) ...[
                        SizedBox(height: math.max(size * 0.04, 3.0)),
                        Icon(
                          Icons.check_circle,
                          size: math.max(size * 0.18, 16.0),
                          color: Colors.amber.shade800,
                        ),
                      ] else if (!table.isAvailable) ...[
                        SizedBox(height: math.max(size * 0.04, 3.0)),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: math.max(size * 0.08, 4.0),
                            vertical: math.max(size * 0.02, 2.0),
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'OCCUPIED',
                            style: TextStyle(
                              fontSize: math.max(size * 0.08, 8.0),
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    BoxConstraints? constraints,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    final textSize = constraints != null ? math.min(constraints.maxHeight * 0.016, 12.0) : 12.0;
    final iconSize = constraints != null ? math.min(constraints.maxHeight * 0.02, 16.0) : 16.0;
    
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      style: TextStyle(
        color: Colors.white,
        fontSize: textSize,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: textSize,
        ),
        prefixIcon: Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: iconSize),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        errorStyle: TextStyle(
          color: Colors.red.shade300,
          fontSize: textSize * 0.8,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.1),
        contentPadding: EdgeInsets.symmetric(
          horizontal: constraints != null ? constraints.maxWidth * 0.02 : 12,
          vertical: constraints != null ? constraints.maxHeight * 0.015 : 12,
        ),
      ),
    );
  }

  Widget _buildGuestConfigurationStep(BoxConstraints constraints, ThemeData theme) {
    final horizontalPadding = constraints.maxWidth * 0.02;
    
    return SlideTransition(
      position: _slideAnimation,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            SizedBox(
              height: constraints.maxHeight * 0.15,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Configure Guests',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: math.min(constraints.maxHeight * 0.03, 24),
                    ),
                  ),
                  SizedBox(height: constraints.maxHeight * 0.005),
                  Text(
                    'Set the number of guests for your dining experience',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: math.min(constraints.maxHeight * 0.018, 14),
                    ),
                  ),
                ],
              ),
            ),
            
            // Selected Table Display
            if (_selectedTable != null)
              Container(
                height: constraints.maxHeight * 0.12,
                padding: EdgeInsets.all(constraints.maxWidth * 0.02),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.white.withValues(alpha: 0.2), Colors.white.withValues(alpha: 0.1)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(constraints.maxHeight * 0.02),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.table_restaurant,
                        color: Colors.white,
                        size: math.min(constraints.maxHeight * 0.04, 32),
                      ),
                    ),
                    SizedBox(width: constraints.maxWidth * 0.02),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Table ${_selectedTable!.number}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: math.min(constraints.maxHeight * 0.025, 20),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Capacity: ${_selectedTable!.capacity} guests',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: math.min(constraints.maxHeight * 0.02, 16),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: constraints.maxWidth * 0.015,
                        vertical: constraints.maxHeight * 0.008,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        'Selected',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: math.min(constraints.maxHeight * 0.015, 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            SizedBox(height: constraints.maxHeight * 0.02),
            
            // Guest Count Configuration
            Expanded(
              child: Container(
                padding: EdgeInsets.all(constraints.maxWidth * 0.02),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: LayoutBuilder(
                  builder: (context, innerConstraints) {
                    final availableHeight = innerConstraints.maxHeight - (constraints.maxWidth * 0.04);
                    final circleSize = math.min(
                      math.min(constraints.maxWidth * 0.2, constraints.maxHeight * 0.15),
                      availableHeight * 0.35
                    );
                    
                    return Column(
                      children: [
                        // Title
                        Text(
                          'Number of Guests',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: math.min(constraints.maxHeight * 0.025, 20),
                          ),
                        ),
                        
                        SizedBox(height: math.min(constraints.maxHeight * 0.02, availableHeight * 0.05)),
                        
                        // Guest count display circle - flexible sizing
                        Expanded(
                          flex: 3,
                          child: Center(
                            child: AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: _pulseAnimation.value,
                                  child: Container(
                                    width: circleSize,
                                    height: circleSize,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Colors.blue.shade400, Colors.purple.shade500],
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.blue.withValues(alpha: 0.4),
                                          blurRadius: circleSize * 0.15,
                                          spreadRadius: circleSize * 0.05,
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.people,
                                            color: Colors.white,
                                            size: circleSize * 0.3,
                                          ),
                                          SizedBox(height: circleSize * 0.05),
                                          Text(
                                            '$_numberOfPeople',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: circleSize * 0.2,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            _numberOfPeople == 1 ? 'Guest' : 'Guests',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.8),
                                              fontSize: circleSize * 0.08,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        
                        // Slider - flexible spacing
                        Flexible(
                          flex: 1,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: Colors.white,
                              inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                              thumbColor: Colors.white,
                              overlayColor: Colors.white.withValues(alpha: 0.2),
                              valueIndicatorColor: Colors.white,
                              valueIndicatorTextStyle: const TextStyle(color: Colors.black),
                            ),
                            child: Slider(
                              value: _numberOfPeople.toDouble(),
                              min: 1,
                              max: 12,
                              divisions: 11,
                              label: '$_numberOfPeople guests',
                              onChanged: (value) {
                                HapticFeedback.selectionClick();
                                setState(() => _numberOfPeople = value.round());
                                _capacityController.text = value.round().toString();
                              },
                            ),
                          ),
                        ),
                        
                        // Quick selection buttons - flexible spacing
                        Flexible(
                          flex: 1,
                          child: Wrap(
                            alignment: WrapAlignment.spaceEvenly,
                            spacing: 8.0,
                            runSpacing: 8.0,
                            children: [2, 4, 6, 8].map((count) {
                              final isSelected = _numberOfPeople == count;
                              final buttonSize = math.min(
                                constraints.maxWidth * 0.08, 
                                math.min(constraints.maxHeight * 0.06, availableHeight * 0.15)
                              );
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  setState(() => _numberOfPeople = count);
                                  _capacityController.text = count.toString();
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: buttonSize,
                                  height: buttonSize * 0.6,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.3)
                                        : Colors.white.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$count',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: math.min(constraints.maxHeight * 0.02, 16),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        
                        SizedBox(height: math.min(constraints.maxHeight * 0.02, availableHeight * 0.05)),
                        
                        // Summary - flexible height
                        Container(
                          constraints: BoxConstraints(
                            minHeight: math.min(constraints.maxHeight * 0.08, availableHeight * 0.15),
                          ),
                          padding: EdgeInsets.all(constraints.maxWidth * 0.02),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.green.shade400, Colors.teal.shade500],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withValues(alpha: 0.3),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: math.min(constraints.maxHeight * 0.03, 24),
                              ),
                              SizedBox(width: constraints.maxWidth * 0.015),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Ready to Begin',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: math.min(constraints.maxHeight * 0.02, 16),
                                      ),
                                    ),
                                    Text(
                                      'Table ${_selectedTable?.number ?? 'Custom'} • $_numberOfPeople guests',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: math.min(constraints.maxHeight * 0.018, 14),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons(ThemeData theme, BoxConstraints constraints) {
    final horizontalPadding = constraints.maxWidth * 0.02;
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              flex: 1,
              child: Container(
                height: constraints.maxHeight * 0.06,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: TextButton(
                  onPressed: _previousStep,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.arrow_back_ios,
                        color: Colors.white,
                        size: math.min(constraints.maxHeight * 0.02, 16),
                      ),
                      SizedBox(width: constraints.maxWidth * 0.01),
                      Text(
                        'Back',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: math.min(constraints.maxHeight * 0.02, 16),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          if (_currentStep > 0) SizedBox(width: constraints.maxWidth * 0.02),
          
          Expanded(
            flex: _currentStep == 0 ? 1 : 1,
            child: Container(
              height: constraints.maxHeight * 0.06,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.white.withValues(alpha: 0.9)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: TextButton(
                onPressed: _isLoading
                    ? null
                    : _currentStep == 1
                        ? _createOrUseTable
                        : (_currentStep == 0 && _selectedTable != null)
                            ? _nextStep
                            : null,
                child: _isLoading
                    ? SizedBox(
                        width: math.min(constraints.maxHeight * 0.025, 20),
                        height: math.min(constraints.maxHeight * 0.025, 20),
                        child: const CircularProgressIndicator(
                          color: Colors.deepPurple,
                          strokeWidth: 2,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              _currentStep == 0
                                  ? 'Configure Guests'
                                  : 'Start Dining Experience',
                              style: TextStyle(
                                color: Colors.deepPurple,
                                fontSize: math.min(constraints.maxHeight * 0.02, 16),
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: constraints.maxWidth * 0.01),
                          Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.deepPurple,
                            size: math.min(constraints.maxHeight * 0.02, 16),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 