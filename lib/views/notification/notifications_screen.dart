import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/error_state_view.dart';
import '../../core/widgets/responsive_content.dart';
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
  Future<void> _openNotification(NotificationModel n) async {
    final provider = context.read<NotificationProvider>();
    final markedAsRead = await provider.markAsRead(n.id);
    if (!mounted) return;
    if (n.relatedRequestId != null && n.relatedRequestId!.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RequestDetailsScreen(requestId: n.relatedRequestId!),
        ),
      );
    }
    if (!mounted || markedAsRead) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(provider.errorMessage ?? 'Could not mark as read'),
      ),
    );
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
    final strings = AppStrings.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(strings.text('notifications')),
        actions: [
          IconButton(
            tooltip: 'Add test notification',
            icon: const Icon(Icons.notifications_active_outlined),
            onPressed: () async {
              final notifications = context.read<NotificationProvider>();
              final success = await notifications.sendTestPush();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Test notification added'
                        : notifications.errorMessage ??
                            'Could not add test notification',
                  ),
                  backgroundColor:
                      success ? AppColors.success : AppColors.error,
                ),
              );
            },
          ),
          if (provider.unreadCount > 0)
            TextButton(
              onPressed: () async {
                final notifications = context.read<NotificationProvider>();
                final success = await notifications.markAllAsRead();
                if (!context.mounted || success) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      notifications.errorMessage ??
                          'Could not mark notifications as read',
                    ),
                  ),
                );
              },
              child: Text(
                'Mark all read',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
      body: ResponsiveContent(
        maxWidth: 900,
        child: RefreshIndicator(
          onRefresh: () => provider.loadNotifications(),
          child: _buildBody(provider),
        ),
      ),
    );
  }

  Widget _buildBody(NotificationProvider provider) {
    final colors = Theme.of(context).colorScheme;
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
        children: [
          const SizedBox(height: 100),
          Icon(Icons.notifications_none,
              size: 56, color: colors.onSurfaceVariant),
          const SizedBox(height: 12),
          const Center(child: Text('You\'re all caught up')),
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
          tileColor:
              n.isRead ? null : colors.primaryContainer.withValues(alpha: 0.45),
          leading: CircleAvatar(
            backgroundColor: n.isRead
                ? colors.surfaceContainerHighest
                : colors.primaryContainer,
            child: Icon(
              _iconFor(n.type),
              color: n.isRead
                  ? colors.onSurfaceVariant
                  : colors.onPrimaryContainer,
              size: 20,
            ),
          ),
          title: Text(
            n.title,
            style: TextStyle(
              fontWeight: n.isRead ? FontWeight.normal : FontWeight.w700,
            ),
          ),
          subtitle:
              Text(n.message, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: Text(
            DateFormatter.timeAgo(n.createdAt),
            style: TextStyle(
              fontSize: 11,
              color: colors.onSurfaceVariant,
            ),
          ),
        );
      },
    );
  }
}
