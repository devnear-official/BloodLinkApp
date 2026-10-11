import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/error_state_view.dart';
import '../../models/blood_request_model.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../services/request_service.dart';

/// Admin-only screen with two tabs: user management (toggle availability,
/// promote/demote roles, delete accounts) and a lightweight analytics
/// dashboard (user/donor/request counts and distributions) — the "Admin
/// Dashboard & Analytics" feature from the project proposal. Gated behind
/// `currentUser.role == 'admin'` by [ProfileScreen], which is the only
/// entry point into this screen.
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadAllUsers();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(UserModel user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User?'),
        content: Text('This will permanently remove ${user.name}\'s account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final success = await context.read<UserProvider>().deleteUser(user.id);
      if (!mounted) return;
      if (!success) {
        final error = context.read<UserProvider>().errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error ?? 'Failed to delete user')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Panel'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Users'),
            Tab(text: 'Analytics'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          RefreshIndicator(
            onRefresh: () => provider.loadAllUsers(),
            child: _buildUsersBody(provider),
          ),
          const _AnalyticsTab(),
        ],
      ),
    );
  }

  Widget _buildUsersBody(UserProvider provider) {
    if (provider.isLoading && provider.allUsers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.appError != null && provider.allUsers.isEmpty) {
      return ListView(
        children: [
          ErrorStateViewFromAppError(
            appError: provider.appError!,
            onRetry: () => context.read<UserProvider>().loadAllUsers(),
          ),
        ],
      );
    }
    if (provider.allUsers.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Center(child: Text('No users found')),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: provider.allUsers.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final user = provider.allUsers[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppColors.primaryLight,
            child: Text(
              user.bloodGroup ?? user.name.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: AppColors.primaryDark, fontSize: 12),
            ),
          ),
          title: Text(user.name),
          subtitle: Text('${user.email} • ${user.role}'),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'toggle_status') {
                context.read<UserProvider>().setUserStatus(
                      user.id,
                      user.status == 'Available' ? 'Unavailable' : 'Available',
                    );
              } else if (value == 'toggle_role') {
                context.read<UserProvider>().setUserRole(
                      user.id,
                      user.role == 'admin' ? 'user' : 'admin',
                    );
              } else if (value == 'delete') {
                _confirmDelete(user);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'toggle_status',
                child: Text(
                  user.status == 'Available'
                      ? 'Mark Unavailable'
                      : 'Mark Available',
                ),
              ),
              PopupMenuItem(
                value: 'toggle_role',
                child: Text(
                  user.role == 'admin' ? 'Demote to User' : 'Promote to Admin',
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete User', style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Simple, dependency-free analytics dashboard: user/donor counts, blood
/// group distribution, and request status breakdown — each rendered as a
/// plain proportional bar row rather than pulling in a charting package.
class _AnalyticsTab extends StatefulWidget {
  const _AnalyticsTab();

  @override
  State<_AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends State<_AnalyticsTab> {
  final _requestService = RequestService();
  bool _loading = true;
  Object? _error;
  List<BloodRequestModel> _requests = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _requests = await _requestService.getRequests();
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = context.watch<UserProvider>().allUsers;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [ErrorStateView(error: _error!, onRetry: _load)],
      );
    }

    final totalUsers = users.length;
    final availableDonors = users.where((u) => u.status == 'Available').length;
    final admins = users.where((u) => u.isAdmin).length;

    final bloodGroupCounts = <String, int>{};
    for (final u in users) {
      final bg = u.bloodGroup;
      if (bg != null && bg.isNotEmpty) {
        bloodGroupCounts[bg] = (bloodGroupCounts[bg] ?? 0) + 1;
      }
    }

    final statusCounts = <String, int>{
      'Active': 0,
      'Pending': 0,
      'Accepted': 0,
      'Completed': 0,
      'Cancelled': 0,
    };
    for (final r in _requests) {
      final status = r.status.toLowerCase() == 'active' ? 'Active' : r.status;
      statusCounts[status] = (statusCounts[status] ?? 0) + 1;
    }

    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          context.read<UserProvider>().loadAllUsers(),
          _load(),
        ]);
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Total Users',
                  value: '$totalUsers',
                  icon: Icons.people_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Available Donors',
                  value: '$availableDonors',
                  icon: Icons.volunteer_activism_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Total Requests',
                  value: '${_requests.length}',
                  icon: Icons.bloodtype_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Admins',
                  value: '$admins',
                  icon: Icons.admin_panel_settings_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Donors by Blood Group',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          if (bloodGroupCounts.isEmpty)
            const Text('No donor blood group data yet.',
                style: TextStyle(color: AppColors.textSecondary))
          else
            _BarList(counts: bloodGroupCounts, color: AppColors.primary),
          const SizedBox(height: 24),
          const Text(
            'Requests by Status',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 12),
          if (_requests.isEmpty)
            const Text('No blood requests yet.',
                style: TextStyle(color: AppColors.textSecondary))
          else
            _BarList(counts: statusCounts, color: AppColors.accent),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A simple proportional horizontal-bar breakdown for a `label -> count`
/// map — no charting dependency, just Containers sized relative to the
/// largest count.
class _BarList extends StatelessWidget {
  const _BarList({required this.counts, required this.color});

  final Map<String, int> counts;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final maxCount = counts.values.isEmpty
        ? 1
        : counts.values.reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: entries.map((entry) {
        final fraction = entry.value / maxCount;
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(
                  entry.key,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.divider,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: fraction.clamp(0.0, 1.0),
                      child: Container(
                        height: 18,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 24,
                child: Text(
                  '${entry.value}',
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
