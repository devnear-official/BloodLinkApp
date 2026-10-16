import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/services/push_notification_service.dart';
import '../../core/widgets/responsive_content.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.text('settings'))),
      body: ResponsiveContent(
        maxWidth: 680,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.notifications_active_outlined,
                  color: AppColors.accent,
                ),
                title: Text(strings.text('pushNotifications')),
                subtitle: Text(
                  PushNotificationService.isAvailable
                      ? strings.text('pushDescription')
                      : strings.text('pushNotConfigured'),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  if (!PushNotificationService.isAvailable) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(strings.text('configureOneSignal'))),
                    );
                    return;
                  }
                  try {
                    final enabled =
                        await PushNotificationService.requestPermission();
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          enabled
                              ? strings.text('pushEnabled')
                              : strings.text('permissionNotGranted'),
                        ),
                      ),
                    );
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Could not enable notifications: $error'),
                      ),
                    );
                  }
                },
              ),
            ),
            Card(
              child: SwitchListTile.adaptive(
                value: settings.isDarkMode,
                onChanged: settings.setDarkMode,
                secondary: const Icon(Icons.dark_mode_outlined,
                    color: AppColors.primary),
                title: Text(strings.text('darkMode')),
                subtitle: Text(strings.text('darkModeDescription')),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.language_outlined,
                    color: AppColors.accent),
                title: Text(strings.text('language')),
                subtitle: Text(
                  strings.text(
                    settings.languageCode == 'bn' ? 'bangla' : 'english',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(strings.text('language')),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          title: Text(strings.text('english')),
                          onTap: () async {
                            await settings.setLanguage('en');
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          },
                        ),
                        ListTile(
                          title: Text(strings.text('bangla')),
                          onTap: () async {
                            await settings.setLanguage('bn');
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.favorite_outline,
                    color: AppColors.primary),
                title: Text(strings.text('aboutBloodLink')),
                subtitle: Text(strings.text('aboutDescription')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
