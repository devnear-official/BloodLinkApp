import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/error_state_view.dart';
import '../../models/direct_request_model.dart';
import '../../providers/direct_request_provider.dart';

/// Direct requests tab content (Received / Sent). Embedded inside
/// [HomeScreen]'s bottom-nav body, so it has no Scaffold/AppBar of its
/// own — only its internal Received/Sent TabBar.
class DirectRequestsScreen extends StatefulWidget {
  const DirectRequestsScreen({super.key});

  @override
  State<DirectRequestsScreen> createState() => _DirectRequestsScreenState();
}

class _DirectRequestsScreenState extends State<DirectRequestsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DirectRequestProvider>().loadAll();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _respond(String id, String status) async {
    final success = await context.read<DirectRequestProvider>().respond(id, status);
    if (!mounted) return;
    if (!success) {
      final error = context.read<DirectRequestProvider>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Action failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _cancel(String id) async {
    final success = await context.read<DirectRequestProvider>().cancel(id);
    if (!mounted) return;
    if (!success) {
      final error = context.read<DirectRequestProvider>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Action failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DirectRequestProvider>();

    return SafeArea(
      child: Column(
        children: [
          Material(
            color: AppColors.surface,
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              tabs: const [
                Tab(text: 'Received'),
                Tab(text: 'Sent'),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => provider.loadAll(),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildList(
                    provider,
                    provider.received,
                    isReceived: true,
                    emptyText: 'No requests received yet',
                  ),
                  _buildList(
                    provider,
                    provider.sent,
                    isReceived: false,
                    emptyText: 'You haven\'t sent any requests yet',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    DirectRequestProvider provider,
    List<DirectRequestModel> items, {
    required bool isReceived,
    required String emptyText,
  }) {
    if (provider.isLoading && items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.appError != null && items.isEmpty) {
      return ListView(
        children: [
          ErrorStateViewFromAppError(
            appError: provider.appError!,
            onRetry: () => context.read<DirectRequestProvider>().loadAll(),
          ),
        ],
      );
    }
    if (items.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          const Icon(Icons.inbox_outlined,
              size: 56, color: AppColors.textSecondary),
          const SizedBox(height: 12),
          Center(child: Text(emptyText)),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 90),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final person = isReceived ? item.fromUser : item.toUser;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        item.bloodGroup,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isReceived ? 'From ${person.name}' : 'To ${person.name}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            item.hospitalName,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.statusColor(item.status)
                            .withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        item.status,
                        style: TextStyle(
                          color: AppColors.statusColor(item.status),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Needed by ${DateFormatter.toShortDate(item.requiredDate)} • ${item.contactNumber}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                if (item.message != null && item.message!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(item.message!, style: const TextStyle(fontSize: 13)),
                ],
                if (isReceived && item.status == 'Pending') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _respond(item.id, 'Declined'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                          ),
                          child: const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _respond(item.id, 'Accepted'),
                          child: const Text('Accept'),
                        ),
                      ),
                    ],
                  ),
                ],
                if (!isReceived && item.status == 'Pending') ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => _cancel(item.id),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                      ),
                      child: const Text('Cancel Request'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
