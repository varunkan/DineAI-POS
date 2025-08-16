import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../services/settings_service.dart';
import '../utils/theme_utils.dart';
import '../widgets/back_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:flutter/services.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late AppSettings _settings;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final settingsService = Provider.of<SettingsService>(context, listen: false);
    _settings = settingsService.settings;
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    final settingsService = Provider.of<SettingsService>(context, listen: false);
    await settingsService.saveSettings(_settings);
    setState(() => _isLoading = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          const SizedBox(width: 8),
          const CustomBackButton(),
          const SizedBox(width: 16),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildBusinessInfoSection(),
          const SizedBox(height: 24),
          _buildThemeSection(),
          const SizedBox(height: 24),
          _buildTaxAndCurrencySection(),
          const SizedBox(height: 24),
          _buildFeatureSettingsSection(),
          const SizedBox(height: 24),
          _buildOrderSettingsSection(),
          const SizedBox(height: 24),
          _buildReceiptSettingsSection(),
          const SizedBox(height: 24),
          _buildGeneralSettingsSection(),
          const SizedBox(height: 24),
          _buildAdminPanelSection(),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : _saveSettings,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Save Settings'),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Clear All Data'),
                  content: const Text('Are you sure you want to clear all app data? This cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Clear'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                // Optionally, restart the app
                if (Platform.isIOS || Platform.isAndroid) {
                  SystemNavigator.pop();
                } else {
                  exit(0);
                }
              }
            },
            child: const Text('Clear All Data'),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessInfoSection() {
    return _buildSection(
      title: 'Business Information',
      icon: Icons.business,
      children: [
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Business Name',
            hintText: 'Enter your business name',
          ),
          initialValue: _settings.businessName,
          onChanged: (value) => _settings = _settings.copyWith(businessName: value),
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Business Address',
            hintText: 'Enter your business address',
          ),
          initialValue: _settings.businessAddress,
          onChanged: (value) => _settings = _settings.copyWith(businessAddress: value),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Business Phone',
            hintText: 'Enter your business phone',
          ),
          initialValue: _settings.businessPhone,
          onChanged: (value) => _settings = _settings.copyWith(businessPhone: value),
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Business Email',
            hintText: 'Enter your business email',
          ),
          initialValue: _settings.businessEmail,
          onChanged: (value) => _settings = _settings.copyWith(businessEmail: value),
        ),
      ],
    );
  }

  Widget _buildThemeSection() {
    return _buildSection(
      title: 'Theme & Appearance',
      icon: Icons.palette,
      children: [
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Theme Mode'),
          value: _settings.themeMode,
          items: const [
            DropdownMenuItem(value: 'system', child: Text('System')),
            DropdownMenuItem(value: 'light', child: Text('Light')),
            DropdownMenuItem(value: 'dark', child: Text('Dark')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _settings = _settings.copyWith(themeMode: value));
            }
          },
        ),
        const SizedBox(height: 16),
        const Text('Primary Color'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ThemeUtils.getPredefinedColors().map((color) {
            return GestureDetector(
              onTap: () => setState(() => _settings = _settings.copyWith(primaryColor: color)),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ThemeUtils.hexToColor(color),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _settings.primaryColor == color ? Colors.black : Colors.grey,
                    width: _settings.primaryColor == color ? 3 : 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        const Text('Accent Color'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ThemeUtils.getPredefinedAccentColors().map((color) {
            return GestureDetector(
              onTap: () => setState(() => _settings = _settings.copyWith(accentColor: color)),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: ThemeUtils.hexToColor(color),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _settings.accentColor == color ? Colors.black : Colors.grey,
                    width: _settings.accentColor == color ? 3 : 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTaxAndCurrencySection() {
    return _buildSection(
      title: 'Tax & Currency',
      icon: Icons.attach_money,
      children: [
        SwitchListTile(
          title: const Text('Enable Tax'),
          subtitle: const Text('Apply tax to orders'),
          value: _settings.enableTax,
          onChanged: (value) => setState(() => _settings = _settings.copyWith(enableTax: value)),
        ),
        if (_settings.enableTax) ...[
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Tax Rate (%)',
              hintText: 'Enter tax rate',
            ),
            initialValue: _settings.taxRate.toString(),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final rate = double.tryParse(value);
              if (rate != null) {
                setState(() => _settings = _settings.copyWith(taxRate: rate));
              }
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Tax Name',
              hintText: 'e.g., HST, GST, VAT',
            ),
            initialValue: _settings.taxName,
            onChanged: (value) => setState(() => _settings = _settings.copyWith(taxName: value)),
          ),
        ],
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Currency',
            hintText: 'e.g., USD, EUR, CAD',
          ),
          initialValue: _settings.currency,
          onChanged: (value) => setState(() => _settings = _settings.copyWith(currency: value)),
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: InputDecoration(
            labelText: 'Currency Symbol',
            hintText: r'e.g., $, €, £',
          ),
          initialValue: _settings.currencySymbol,
          onChanged: (value) => setState(() => _settings = _settings.copyWith(currencySymbol: value)),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Enable Tips'),
          subtitle: const Text('Allow tip calculation'),
          value: _settings.enableTips,
          onChanged: (value) => setState(() => _settings = _settings.copyWith(enableTips: value)),
        ),
      ],
    );
  }

  Widget _buildFeatureSettingsSection() {
    return _buildSection(
      title: 'Feature Settings',
      icon: Icons.settings,
      children: [
        SwitchListTile(
          title: const Text('User Management'),
          subtitle: const Text('Enable user management features'),
          value: _settings.enableUserManagement,
          onChanged: (value) => setState(() => _settings = _settings.copyWith(enableUserManagement: value)),
        ),
        SwitchListTile(
          title: const Text('Category Management'),
          subtitle: const Text('Enable category management features'),
          value: _settings.enableCategoryManagement,
          onChanged: (value) => setState(() => _settings = _settings.copyWith(enableCategoryManagement: value)),
        ),
        SwitchListTile(
          title: const Text('Menu Item Management'),
          subtitle: const Text('Enable menu item management features'),
          value: _settings.enableMenuItemManagement,
          onChanged: (value) => setState(() => _settings = _settings.copyWith(enableMenuItemManagement: value)),
        ),
        SwitchListTile(
          title: const Text('Kitchen Printing'),
          subtitle: const Text('Enable kitchen ticket printing'),
          value: _settings.enableKitchenPrinting,
          onChanged: (value) => setState(() => _settings = _settings.copyWith(enableKitchenPrinting: value)),
        ),
        SwitchListTile(
          title: const Text('Customer Receipt'),
          subtitle: const Text('Enable customer receipt printing'),
          value: _settings.enableCustomerReceipt,
          onChanged: (value) => setState(() => _settings = _settings.copyWith(enableCustomerReceipt: value)),
        ),
      ],
    );
  }

  Widget _buildOrderSettingsSection() {
    return _buildSection(
      title: 'Order Settings',
      icon: Icons.receipt,
      children: [
        SwitchListTile(
          title: const Text('Auto Save Orders'),
          subtitle: const Text('Automatically save orders'),
          value: _settings.autoSaveOrders,
          onChanged: (value) => setState(() => _settings = _settings.copyWith(autoSaveOrders: value)),
        ),
        if (_settings.autoSaveOrders) ...[
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Auto Save Interval (minutes)',
              hintText: 'Enter interval in minutes',
            ),
            initialValue: _settings.autoSaveInterval.toString(),
            keyboardType: TextInputType.number,
            onChanged: (value) {
              final interval = int.tryParse(value);
              if (interval != null) {
                setState(() => _settings = _settings.copyWith(autoSaveInterval: interval));
              }
            },
          ),
        ],
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Order Numbering'),
          subtitle: const Text('Enable automatic order numbering'),
          value: _settings.enableOrderNumbering,
          onChanged: (value) => setState(() => _settings = _settings.copyWith(enableOrderNumbering: value)),
        ),
        if (_settings.enableOrderNumbering) ...[
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Order Number Prefix',
              hintText: 'e.g., ORD',
            ),
            initialValue: _settings.orderNumberPrefix,
            onChanged: (value) => setState(() => _settings = _settings.copyWith(orderNumberPrefix: value)),
          ),
        ],
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Table Numbering'),
          subtitle: const Text('Enable automatic table numbering'),
          value: _settings.enableTableNumbering,
          onChanged: (value) => setState(() => _settings = _settings.copyWith(enableTableNumbering: value)),
        ),
        if (_settings.enableTableNumbering) ...[
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Table Number Prefix',
              hintText: 'e.g., TBL',
            ),
            initialValue: _settings.tableNumberPrefix,
            onChanged: (value) => setState(() => _settings = _settings.copyWith(tableNumberPrefix: value)),
          ),
        ],
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Max Tables Per User',
            hintText: 'Enter maximum tables per user',
          ),
          initialValue: _settings.maxTablesPerUser.toString(),
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final maxTables = int.tryParse(value);
            if (maxTables != null) {
              setState(() => _settings = _settings.copyWith(maxTablesPerUser: maxTables));
            }
          },
        ),
      ],
    );
  }

  Widget _buildReceiptSettingsSection() {
    return _buildSection(
      title: 'Receipt Settings',
      icon: Icons.print,
      children: [
        SwitchListTile(
          title: const Text('Receipt Header'),
          subtitle: const Text('Show header on receipts'),
          value: _settings.enableReceiptHeader,
          onChanged: (value) => setState(() => _settings = _settings.copyWith(enableReceiptHeader: value)),
        ),
        if (_settings.enableReceiptHeader) ...[
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Receipt Header Text',
              hintText: 'Enter header text for receipts',
            ),
            initialValue: _settings.receiptHeaderText,
            onChanged: (value) => setState(() => _settings = _settings.copyWith(receiptHeaderText: value)),
            maxLines: 2,
          ),
        ],
        const SizedBox(height: 16),
        SwitchListTile(
          title: const Text('Receipt Footer'),
          subtitle: const Text('Show footer on receipts'),
          value: _settings.enableReceiptFooter,
          onChanged: (value) => setState(() => _settings = _settings.copyWith(enableReceiptFooter: value)),
        ),
        if (_settings.enableReceiptFooter) ...[
          const SizedBox(height: 16),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Receipt Footer Text',
              hintText: 'Enter footer text for receipts',
            ),
            initialValue: _settings.receiptFooterText,
            onChanged: (value) => setState(() => _settings = _settings.copyWith(receiptFooterText: value)),
            maxLines: 2,
          ),
        ],
      ],
    );
  }

  Widget _buildGeneralSettingsSection() {
    return _buildSection(
      title: 'General Settings',
      icon: Icons.tune,
      children: [
        SwitchListTile(
          title: const Text('Sound Effects'),
          subtitle: const Text('Enable sound effects'),
          value: _settings.enableSoundEffects,
          onChanged: (value) => setState(() => _settings = _settings.copyWith(enableSoundEffects: value)),
        ),
        SwitchListTile(
          title: const Text('Notifications'),
          subtitle: const Text('Enable notifications'),
          value: _settings.enableNotifications,
          onChanged: (value) => setState(() => _settings = _settings.copyWith(enableNotifications: value)),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Language'),
          value: _settings.language,
          items: const [
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(value: 'es', child: Text('Spanish')),
            DropdownMenuItem(value: 'fr', child: Text('French')),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _settings = _settings.copyWith(language: value));
            }
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Date Format',
            hintText: 'e.g., MM/dd/yyyy',
          ),
          initialValue: _settings.dateFormat,
          onChanged: (value) => setState(() => _settings = _settings.copyWith(dateFormat: value)),
        ),
        const SizedBox(height: 16),
        TextFormField(
          decoration: const InputDecoration(
            labelText: 'Time Format',
            hintText: 'e.g., hh:mm a',
          ),
          initialValue: _settings.timeFormat,
          onChanged: (value) => setState(() => _settings = _settings.copyWith(timeFormat: value)),
        ),
      ],
    );
  }

  Widget _buildAdminPanelSection() {
    return _buildSection(
      title: 'Admin Panel',
      icon: Icons.admin_panel_settings,
      children: [
        const Text(
          'Manage your restaurant\'s categories and menu items',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/admin-panel');
                },
                icon: const Icon(Icons.admin_panel_settings),
                label: const Text('Admin Panel'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/manage-categories');
                },
                icon: const Icon(Icons.category),
                label: const Text('Manage Categories'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(context, '/manage-menu-items');
                },
                icon: const Icon(Icons.restaurant_menu),
                label: const Text('Manage Menu Items'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
} 