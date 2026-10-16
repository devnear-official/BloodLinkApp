import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/responsive_content.dart';
import '../../providers/auth_provider.dart';
import '../admin/admin_users_screen.dart';
import '../auth/login_screen.dart';
import 'donation_history_screen.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('You will need to sign in again to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sign Out',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<AuthProvider>().logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final colors = Theme.of(context).colorScheme;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: ResponsiveContent(
          maxWidth: 680,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: colors.primaryContainer,
                  backgroundImage: user.photoUrl != null
                      ? NetworkImage(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null
                      ? Text(
                          user.bloodGroup ??
                              user.name.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: colors.onPrimaryContainer,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  user.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
              Center(
                child: Text(
                  user.email,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 24),
              Card(
                child: Column(
                  children: [
                    _ProfileRow(
                        icon: Icons.bloodtype_outlined,
                        label: 'Blood Group',
                        value: user.bloodGroup ?? 'Not set'),
                    const Divider(height: 1),
                    _ProfileRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone',
                        value: user.phone ?? 'Not set'),
                    const Divider(height: 1),
                    _ProfileRow(
                        icon: Icons.map_outlined,
                        label: 'Division',
                        value: user.division ?? 'Not set'),
                    const Divider(height: 1),
                    _ProfileRow(
                        icon: Icons.location_city_outlined,
                        label: 'District',
                        value: user.district ?? 'Not set'),
                    const Divider(height: 1),
                    _ProfileRow(
                        icon: Icons.map_outlined,
                        label: 'Sub-district',
                        value: user.subDistrict ?? 'Not set'),
                    const Divider(height: 1),
                    _ProfileRow(
                      icon: Icons.event_available_outlined,
                      label: 'Last Donation',
                      value: DateFormatter.toShortDate(user.lastDonation),
                    ),
                    const Divider(height: 1),
                    _ProfileRow(
                      icon: user.status == 'Available'
                          ? Icons.check_circle_outline
                          : Icons.pause_circle_outline,
                      label: 'Status',
                      value: user.status,
                      valueColor: user.status == 'Available'
                          ? AppColors.success
                          : colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                tileColor: colors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading:
                    const Icon(Icons.edit_outlined, color: AppColors.accent),
                title: const Text('Edit Profile'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const EditProfileScreen()),
                  );
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                tileColor: colors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.volunteer_activism_outlined,
                    color: AppColors.primary),
                title: const Text('Donation History'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const DonationHistoryScreen()),
                  );
                },
              ),
              if (user.isAdmin) ...[
                const SizedBox(height: 10),
                ListTile(
                  tileColor: colors.surface,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(Icons.admin_panel_settings_outlined,
                      color: AppColors.primary),
                  title: const Text('Admin Panel'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const AdminUsersScreen()),
                    );
                  },
                ),
              ],
              const SizedBox(height: 10),
              ListTile(
                tileColor: colors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.logout, color: AppColors.error),
                title: const Text('Sign Out',
                    style: TextStyle(color: AppColors.error)),
                onTap: () => _confirmLogout(context),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: colors.onSurfaceVariant),
      title: Text(
        label,
        style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: valueColor ?? colors.onSurface,
        ),
      ),
    );
  }
}
