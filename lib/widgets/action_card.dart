import 'package:flutter/material.dart';

/// A reusable widget that displays an action card with icon, title, and color.
/// 
/// This widget is used for navigation actions in the main menu.
class ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isEnabled;
  final String? subtitle;
  final Widget? trailing;

  const ActionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isEnabled = true,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isEnabled ? 4 : 1,
      color: isEnabled ? null : Colors.grey.shade200,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: isEnabled ? color : Colors.grey.shade400,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isEnabled ? null : Colors.grey.shade600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isEnabled ? Colors.grey.shade600 : Colors.grey.shade500,
                  ),
                ),
              ],
              if (trailing != null) ...[
                const SizedBox(height: 8),
                trailing!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A specialized action card for navigation items.
class NavigationActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isEnabled;
  final String? subtitle;

  const NavigationActionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isEnabled = true,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ActionCard(
      title: title,
      icon: icon,
      color: color,
      onTap: onTap,
      isEnabled: isEnabled,
      subtitle: subtitle,
      trailing: isEnabled
          ? Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            )
          : null,
    );
  }
} 