import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/error_state_view.dart';
import '../../models/notification_model.dart';
import '../../providers/notification_provider.dart';
import '../request/request_details_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  /// Marks [n] as read and, if it points at a specific request, navigates
  /// there — this is the "specific notification click takes you to it"
  /// behavior.
  void _openNotification(NotificationModel n) {
    context.read<NotificationProvider>().markAsRead(n.id);
    if (n.relatedRequestId != null && n.relatedRequestId!.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RequestDetailsScreen(requestId: n.relatedRequestId!),
        ),
      );
    }
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'request':
        return Icons.bloodtype_outlined;
      case 'direct_request':
        return Icons.send_outlined;
      case 'response':
        return Icons.how_to_reg_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'Send test push',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () async {
              final success =
                  await context.read<NotificationProvider>().sendTestPush();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success ? 'Test push sent' : 'Failed to send test push',
                  ),
                  backgroundColor: success ? AppColors.success : AppColors.error,
                ),
              );
            },
          ),
          if (provider.unreadCount > 0)
            TextButton(
              onPressed: () =>
                  context.read<NotificationProvider>().markAllAsRead(),
              child: const Text(
                'Mark all read',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => provider.loadNotifications(),
        child: _buildBody(provider),
      ),
    );
  }

  Widget _buildBody(NotificationProvider provider) {
    if (provider.isLoading && provider.notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.appError != null && provider.notifications.isEmpty) {
      return ListView(
        children: [
          ErrorStateViewFromAppError(
            appError: provider.appError!,
            onRetry: () =>
                context.read<NotificationProvider>().loadNotifications(),
          ),
        ],
      );
    }
    if (provider.notifications.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Icon(Icons.notifications_none,
              size: 56, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Center(child: Text('You\'re all caught up')),
        ],
      );
    }
    return ListView.separated(
      itemCount: provider.notifications.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final NotificationModel n = provider.notifications[index];
        return ListTile(
          onTap: () => _openNotification(n),
          tileColor: n.isRead ? null : AppColors.primaryLight.withOpacity(0.3),
          leading: CircleAvatar(
            backgroundColor:
                n.isRead ? AppColors.divider : AppColors.primaryLight,
            child: Icon(
              _iconFor(n.type),
              color: n.isRead ? AppColors.textSecondary : AppColors.primaryDark,
              size: 20,
            ),
          ),
          title: Text(
            n.title,
            style: TextStyle(
              fontWeight: n.isRead ? FontWeight.normal : FontWeight.w700,
            ),
          ),
          subtitle: Text(n.message, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: Text(
            DateFormatter.timeAgo(n.createdAt),
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        );
      },
    );
  }
}
