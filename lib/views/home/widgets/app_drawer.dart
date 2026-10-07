import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../providers/auth_provider.dart';
import '../../admin/admin_users_screen.dart';
import '../../auth/login_screen.dart';
import '../../notification/notifications_screen.dart';
import '../../profile/profile_screen.dart';

/// Left-side navigation drawer for the authenticated shell. Shows the
/// current user at the top, quick links to each bottom-nav destination
/// (so the drawer stays useful even if bottom-nav tabs change later),
/// plus Profile, Admin Panel (admins only), and Sign Out.
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.currentIndex,
    required this.onSelectTab,
  });

  /// Currently selected bottom-nav tab index, so the matching drawer item
  /// can be highlighted.
  final int currentIndex;

  /// Called with a tab index when the person taps one of the tab
  /// shortcuts in the drawer.
  final void Function(int index) onSelectTab;

  Future<void> _confirmLogout(BuildContext context) async {
    Navigator.of(context).pop(); // close the drawer first
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
            child:
                const Text('Sign Out', style: TextStyle(color: AppColors.error)),
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

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              color: AppColors.primary,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    backgroundImage: user?.photoUrl != null
                        ? NetworkImage(user!.photoUrl!)
                        : null,
                    child: user?.photoUrl == null
                        ? Text(
                            (user?.name.isNotEmpty ?? false)
                                ? user!.name.substring(0, 1).toUpperCase()
                                : '?',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Guest',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? '',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (user?.bloodGroup != null) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              user!.bloodGroup!,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _DrawerTile(
              icon: Icons.bloodtype_outlined,
              label: 'Blood Requests',
              selected: currentIndex == 0,
              onTap: () {
                Navigator.of(context).pop();
                onSelectTab(0);
              },
            ),
            _DrawerTile(
              icon: Icons.search_outlined,
              label: 'Search Donors',
              selected: currentIndex == 1,
              onTap: () {
                Navigator.of(context).pop();
                onSelectTab(1);
              },
            ),
            _DrawerTile(
              icon: Icons.near_me_outlined,
              label: 'Find Nearby',
              selected: currentIndex == 2,
              onTap: () {
                Navigator.of(context).pop();
                onSelectTab(2);
              },
            ),
            _DrawerTile(
              icon: Icons.send_outlined,
              label: 'Direct Requests',
              selected: currentIndex == 3,
              onTap: () {
                Navigator.of(context).pop();
                onSelectTab(3);
              },
            ),
            _DrawerTile(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              selected: false,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
              },
            ),
            const Divider(height: 24),
            _DrawerTile(
              icon: Icons.person_outline,
              label: 'Profile',
              selected: false,
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                );
              },
            ),
            if (user?.isAdmin ?? false)
              _DrawerTile(
                icon: Icons.admin_panel_settings_outlined,
                label: 'Admin Panel',
                selected: false,
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
                  );
                },
              ),
            const Spacer(),
            const Divider(height: 1),
            _DrawerTile(
              icon: Icons.logout,
              label: 'Sign Out',
              selected: false,
              iconColor: AppColors.error,
              textColor: AppColors.error,
              onTap: () => _confirmLogout(context),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.iconColor,
    this.textColor,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      selectedTileColor: AppColors.primaryLight.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Icon(icon, color: iconColor ?? AppColors.textSecondary),
      title: Text(
        label,
        style: TextStyle(
          color: textColor ?? AppColors.textPrimary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}
