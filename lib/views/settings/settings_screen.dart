import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile.adaptive(
              value: settings.isDarkMode,
              onChanged: settings.setDarkMode,
              secondary: const Icon(Icons.dark_mode_outlined,
                  color: AppColors.primary),
              title: const Text('Dark mode'),
              subtitle: const Text('Use a darker appearance throughout the app'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: const ListTile(
              leading: Icon(Icons.language_outlined, color: AppColors.accent),
              title: Text('Language'),
              subtitle: Text('English'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: const ListTile(
              leading: Icon(Icons.favorite_outline, color: AppColors.primary),
              title: Text('About BloodLink'),
              subtitle: Text('Connecting donors with people who need them.'),
            ),
          ),
        ],
      ),
    );
  }
}
