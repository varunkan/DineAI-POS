import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/multi_tenant_auth_service.dart';
import '../utils/validation_utils.dart';
import '../utils/tablet_responsive.dart';
import 'order_type_selection_screen.dart';

/// Restaurant authentication screen for multi-tenant POS system
/// Handles both restaurant registration and user login
class RestaurantAuthScreen extends StatefulWidget {
  const RestaurantAuthScreen({super.key});

  @override
  State<RestaurantAuthScreen> createState() => _RestaurantAuthScreenState();
}

class _RestaurantAuthScreenState extends State<RestaurantAuthScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Controllers for registration
  final _regNameController = TextEditingController();
  final _regBusinessTypeController = TextEditingController();
  final _regAddressController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regAdminUserController = TextEditingController();
  final _regAdminPasswordController = TextEditingController();

  // Controllers for login
  final _loginEmailController = TextEditingController();
  final _loginUserController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // Form keys
  final _registrationFormKey = GlobalKey<FormState>();
  final _loginFormKey = GlobalKey<FormState>();

  // UI state
  bool _obscureRegPassword = true;
  bool _obscureLoginPassword = true;
  
  // Validation state
  Map<String, ValidationResult> _validationResults = {};
  String _selectedBusinessType = 'Restaurant';
  String _selectedCountryCode = 'US';
  int _passwordStrength = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    _regNameController.dispose();
    _regBusinessTypeController.dispose();
    _regAddressController.dispose();
    _regPhoneController.dispose();
    _regEmailController.dispose();
    _regAdminUserController.dispose();
    _regAdminPasswordController.dispose();
    _loginEmailController.dispose();
    _loginUserController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  /// Validate registration form
  void _validateRegistrationForm() {
    setState(() {
      _validationResults = ValidationUtils.validateRestaurantData(
        name: _regNameController.text,
        businessType: _selectedBusinessType,
        email: _regEmailController.text,
        phone: _regPhoneController.text,
        address: _regAddressController.text,
        adminUserId: _regAdminUserController.text,
        adminPassword: _regAdminPasswordController.text,
        countryCode: _selectedCountryCode,
      );
      
      _passwordStrength = ValidationUtils.getPasswordStrength(_regAdminPasswordController.text);
    });
  }

  /// Check if registration form is valid
  bool _isRegistrationFormValid() {
    return ValidationUtils.allValidationsPassed(_validationResults);
  }

  /// Get validation error message for a field
  String? _getValidationError(String field) {
    final result = _validationResults[field];
    return result?.isValid == false ? result!.message : null;
  }

  /// Update password strength when password changes
  void _onPasswordChanged(String password) {
    setState(() {
      _passwordStrength = ValidationUtils.getPasswordStrength(password);
    });
  }

  /// Build business type dropdown
  Widget _buildBusinessTypeDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getValidationError('businessType') != null 
              ? Colors.red.shade300 
              : Colors.grey.shade300,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedBusinessType,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Business Type',
          prefixIcon: const Icon(Icons.business, color: Color(0xFF667eea)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          errorText: _getValidationError('businessType'),
        ),
        items: ValidationUtils.validBusinessTypes.map((type) {
          return DropdownMenuItem<String>(
            value: type,
            child: Text(type, style: const TextStyle(fontSize: 14)),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _selectedBusinessType = value!;
            _validateRegistrationForm();
          });
        },
        validator: (value) => _getValidationError('businessType'),
        menuMaxHeight: 300,
      ),
    );
  }

  /// Build country code dropdown
  Widget _buildCountryCodeDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedCountryCode,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Country Code',
          prefixIcon: Icon(Icons.flag, color: Color(0xFF667eea)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
                                items: const [
                          DropdownMenuItem(value: 'US', child: Text('🇺🇸 US (+1)', style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 'CA', child: Text('🇨🇦 Canada (+1)', style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 'UK', child: Text('🇬🇧 UK (+44)', style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 'IN', child: Text('🇮🇳 India (+91)', style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 'AU', child: Text('🇦🇺 Australia (+61)', style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 'DE', child: Text('🇩🇪 Germany (+49)', style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 'FR', child: Text('🇫🇷 France (+33)', style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 'JP', child: Text('🇯🇵 Japan (+81)', style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 'CN', child: Text('🇨🇳 China (+86)', style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 'BR', child: Text('🇧🇷 Brazil (+55)', style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 'MX', child: Text('🇲🇽 Mexico (+52)', style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 'ES', child: Text('🇪🇸 Spain (+34)', style: TextStyle(fontSize: 14))),
                          DropdownMenuItem(value: 'IT', child: Text('🇮🇹 Italy (+39)', style: TextStyle(fontSize: 14))),
                        ],
        onChanged: (value) {
          setState(() {
            _selectedCountryCode = value!;
            _validateRegistrationForm();
          });
        },
        menuMaxHeight: 300,
      ),
    );
  }

  /// Build password strength indicator
  Widget _buildPasswordStrengthIndicator() {
    Color strengthColor;
    String strengthText;
    
    if (_passwordStrength >= 80) {
      strengthColor = Colors.green;
      strengthText = 'Very Strong';
    } else if (_passwordStrength >= 60) {
      strengthColor = Colors.blue;
      strengthText = 'Strong';
    } else if (_passwordStrength >= 40) {
      strengthColor = Colors.orange;
      strengthText = 'Good';
    } else if (_passwordStrength >= 20) {
      strengthColor = Colors.yellow.shade700;
      strengthText = 'Fair';
    } else {
      strengthColor = Colors.red;
      strengthText = 'Weak';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: _passwordStrength / 100,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$strengthText (${_passwordStrength}%)',
              style: TextStyle(
                fontSize: 12,
                color: strengthColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        if (_getValidationError('adminPassword') != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _getValidationError('adminPassword')!,
              style: TextStyle(
                fontSize: 12,
                color: Colors.red.shade600,
              ),
            ),
          ),
      ],
    );
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
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: _buildContent(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Use tablet responsive utilities
        final isTablet = TabletResponsive.isTablet(context);
        final isLargeTablet = TabletResponsive.isLargeTablet(context);
        final logoSize = isLargeTablet ? 120.0 : isTablet ? 100.0 : 70.0;
        final iconSize = isLargeTablet ? 60.0 : isTablet ? 50.0 : 35.0;
        
        return Container(
          padding: TabletResponsive.getResponsivePadding(context),
          child: Column(
            children: [
              // App Logo
              Container(
                width: logoSize,
                height: logoSize,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(isLargeTablet ? 28 : isTablet ? 24 : 18),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.restaurant_menu,
                  size: iconSize,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: isLargeTablet ? 24 : isTablet ? 20 : 16),

              // Title
              Text(
                'Restaurant POS',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isLargeTablet ? 36 : isTablet ? 32 : 24,
                      letterSpacing: 0.5,
                    ),
              ),
              SizedBox(height: isLargeTablet ? 16 : isTablet ? 12 : 8),

              Text(
                'Multi-Tenant Point of Sale System',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: isLargeTablet ? 18 : isTablet ? 16 : 14,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContent() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Register Restaurant'),
                Tab(text: 'Login'),
              ],
              labelColor: const Color(0xFF667eea),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF667eea),
              indicatorWeight: 3,
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRegistrationTab(),
                _buildLoginTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegistrationTab() {
    return Consumer<MultiTenantAuthService>(
      builder: (context, authService, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // Responsive form width - more consistent across devices
            final isTablet = constraints.maxWidth > 600;
            final isLargeTablet = constraints.maxWidth > 800;
            
            final formWidth = isLargeTablet 
                ? 600.0  // Fixed width for large tablets
                : isTablet 
                    ? constraints.maxWidth * 0.8  // 80% width for tablets
                    : constraints.maxWidth - 48;  // Full width minus padding for phones
            
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                vertical: isLargeTablet ? 32 : isTablet ? 28 : 24, 
                horizontal: isLargeTablet ? 32 : isTablet ? 28 : 24
              ),
              child: Center(
                child: SizedBox(
                  width: formWidth,
                  child: Form(
                    key: _registrationFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Register Your Restaurant',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: isLargeTablet ? 28 : isTablet ? 24 : 20,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isLargeTablet ? 32 : isTablet ? 28 : 24),

                        // Restaurant Name
                        _buildTextField(
                          controller: _regNameController,
                          label: 'Restaurant Name',
                          icon: Icons.restaurant,
                          onChanged: (value) => _validateRegistrationForm(),
                          validator: (value) => _getValidationError('name'),
                        ),
                        const SizedBox(height: 16),

                        // Business Type Dropdown
                        _buildBusinessTypeDropdown(),
                        const SizedBox(height: 16),
                        const SizedBox(height: 16),

                        // Address
                        _buildTextField(
                          controller: _regAddressController,
                          label: 'Address',
                          icon: Icons.location_on,
                          maxLines: 2,
                          onChanged: (value) => _validateRegistrationForm(),
                          validator: (value) => _getValidationError('address'),
                        ),
                        const SizedBox(height: 16),

                        // Country Code and Phone
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildCountryCodeDropdown(),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: _buildTextField(
                                controller: _regPhoneController,
                                label: 'Phone Number',
                                icon: Icons.phone,
                                keyboardType: TextInputType.phone,
                                onChanged: (value) => _validateRegistrationForm(),
                                validator: (value) => _getValidationError('phone'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Email
                        _buildTextField(
                          controller: _regEmailController,
                          label: 'Email Address',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (value) => _validateRegistrationForm(),
                          validator: (value) => _getValidationError('email'),
                        ),
                        const SizedBox(height: 24),

                        Text(
                          'Admin User Setup',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade700,
                              ),
                        ),
                        const SizedBox(height: 16),

                        // Admin Username
                        _buildTextField(
                          controller: _regAdminUserController,
                          label: 'Admin Username',
                          icon: Icons.admin_panel_settings,
                          onChanged: (value) => _validateRegistrationForm(),
                          validator: (value) => _getValidationError('adminUserId'),
                        ),
                        const SizedBox(height: 16),

                        // Admin Password
                        _buildTextField(
                          controller: _regAdminPasswordController,
                          label: 'Admin Password',
                          icon: Icons.lock,
                          obscureText: _obscureRegPassword,
                          onChanged: (value) {
                            _onPasswordChanged(value);
                            _validateRegistrationForm();
                          },
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureRegPassword ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureRegPassword = !_obscureRegPassword;
                              });
                            },
                          ),
                          validator: (value) => _getValidationError('adminPassword'),
                        ),
                        _buildPasswordStrengthIndicator(),
                        const SizedBox(height: 32),

                        // Error message
                        if (authService.lastError != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              authService.lastError!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),

                        // Register Button
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF667eea).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: authService.isLoading ? null : _handleRegistration,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: authService.isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Register Restaurant',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLoginTab() {
    return Consumer<MultiTenantAuthService>(
      builder: (context, authService, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            // Responsive form width - more consistent across devices
            final isTablet = constraints.maxWidth > 600;
            final isLargeTablet = constraints.maxWidth > 800;
            
            final formWidth = isLargeTablet 
                ? 500.0  // Fixed width for large tablets
                : isTablet 
                    ? constraints.maxWidth * 0.7  // 70% width for tablets
                    : constraints.maxWidth - 48;  // Full width minus padding for phones
            
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                vertical: isLargeTablet ? 32 : isTablet ? 28 : 24, 
                horizontal: isLargeTablet ? 32 : isTablet ? 28 : 24
              ),
              child: Center(
                child: SizedBox(
                  width: formWidth,
                  child: Form(
                    key: _loginFormKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Restaurant Login',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: Colors.grey.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: isLargeTablet ? 28 : isTablet ? 24 : 20,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: isLargeTablet ? 32 : isTablet ? 28 : 24),

                        // Restaurant Email
                        _buildTextField(
                          controller: _loginEmailController,
                          label: 'Restaurant Email',
                          icon: Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value?.trim().isEmpty ?? true) {
                              return 'Restaurant email is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Admin Password
                        _buildTextField(
                          controller: _loginPasswordController,
                          label: 'Admin Password',
                          icon: Icons.lock,
                          obscureText: _obscureLoginPassword,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureLoginPassword ? Icons.visibility : Icons.visibility_off,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureLoginPassword = !_obscureLoginPassword;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value?.trim().isEmpty ?? true) {
                              return 'Admin password is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                        // Error message
                        if (authService.lastError != null)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Text(
                              authService.lastError!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),

                        // Login Button
                        Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF667eea).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: authService.isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: authService.isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Login',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Help text
                        Text(
                          'New restaurant? Switch to the Register tab to create your account.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.grey.shade600,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        
                        // Registered Restaurants Info
                        if (authService.registeredRestaurants.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                          Text(
                            'Registered Restaurants',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade700,
                                ),
                          ),
                          const SizedBox(height: 12),
                          ...authService.registeredRestaurants.map((restaurant) => 
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.restaurant, color: Colors.grey.shade600),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          restaurant.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        Text(
                                          restaurant.email,
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      _loginEmailController.text = restaurant.email;
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Use',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    int maxLines = 1,
    void Function(String)? onChanged,
    bool enabled = true, // Add enabled parameter with default true
  }) {
    final isTablet = TabletResponsive.isTablet(context);
    final isLargeTablet = TabletResponsive.isLargeTablet(context);
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      enabled: enabled, // Use the enabled parameter
      style: TextStyle(
        fontSize: TabletResponsive.getResponsiveFontSize(context, mobile: 16, tablet: 18, largeTablet: 20),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.grey.shade600, 
          fontSize: TabletResponsive.getResponsiveFontSize(context, mobile: 14, tablet: 16, largeTablet: 18),
        ),
        prefixIcon: Icon(
          icon, 
          color: Colors.grey.shade600, 
          size: TabletResponsive.getResponsiveIconSize(context, mobile: 20, tablet: 24, largeTablet: 28),
        ),
        suffixIcon: suffixIcon,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isLargeTablet ? 24 : isTablet ? 20 : 16, 
          vertical: isLargeTablet ? 20 : isTablet ? 18 : 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: enabled ? Colors.grey.shade50 : Colors.grey.shade100, // Adjust fill color based on enabled state
        // Add subtle elevation effect
        isDense: true,
      ),
    );
  }

  Future<void> _handleRegistration() async {
    // Validate form first
    _validateRegistrationForm();
    
    if (!_isRegistrationFormValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fix the validation errors before proceeding.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_registrationFormKey.currentState!.validate()) return;

    final authService = Provider.of<MultiTenantAuthService>(context, listen: false);

    final success = await authService.registerRestaurant(
      name: _regNameController.text.trim(),
      businessType: _selectedBusinessType,
      address: _regAddressController.text.trim(),
      phone: _regPhoneController.text.trim(),
      email: _regEmailController.text.trim(),
      adminUserId: _regAdminUserController.text.trim(),
      adminPassword: _regAdminPasswordController.text.trim(),
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Restaurant registered successfully! You can now login.'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Switch to login tab
      _tabController.animateTo(1);
      
      // Pre-fill login form with email only
      _loginEmailController.text = _regEmailController.text.trim();
    }
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    final authService = Provider.of<MultiTenantAuthService>(context, listen: false);

    final success = await authService.login(
      restaurantEmail: _loginEmailController.text.trim(),
      userId: 'admin', // Default to admin user
      password: _loginPasswordController.text.trim(),
    );

    if (success && mounted) {
      // Navigate to POS dashboard
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const OrderTypeSelectionScreen(),
        ),
      );
    }
  }
} 