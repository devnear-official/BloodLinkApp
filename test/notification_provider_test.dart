import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:bloodlink/models/notification_model.dart';
import 'package:bloodlink/providers/notification_provider.dart';
import 'package:bloodlink/services/notification_service.dart';

void main() {
  test('clears notifications and ignores old account loads on account switch',
      () async {
    final service = _FakeNotificationService();
    final provider = NotificationProvider(service: service);
    addTearDown(provider.dispose);

    final oldAccountLoad = Completer<List<NotificationModel>>();
    service.pendingLoads.add(oldAccountLoad);
    provider.setUserId('user-a');
    final oldLoad = provider.loadNotifications();

    provider.setUserId('user-b');
    expect(provider.notifications, isEmpty);

    final newNotification = _notification('notification-b');
    service.pendingLoads
        .add(Completer<List<NotificationModel>>()..complete([newNotification]));
    await provider.loadNotifications();
    oldAccountLoad.complete([_notification('notification-a')]);
    await oldLoad;

    expect(provider.notifications.map((item) => item.id), ['notification-b']);
    expect(provider.unreadCount, 1);
  });

  test('adds the returned test notification to the current list', () async {
    final service = _FakeNotificationService()
      ..testNotification = _notification('test-notification');
    final provider = NotificationProvider(service: service);
    addTearDown(provider.dispose);
    provider.setUserId('user-a');

    expect(await provider.sendTestPush(), isTrue);
    expect(provider.notifications.single.id, 'test-notification');
    expect(provider.unreadCount, 1);
  });
}

NotificationModel _notification(String id) => NotificationModel(
      id: id,
      title: 'Test',
      message: 'Test notification',
      type: 'test',
    );

class _FakeNotificationService extends NotificationService {
  final List<Completer<List<NotificationModel>>> pendingLoads = [];
  NotificationModel? testNotification;

  @override
  Future<List<NotificationModel>> getNotifications() {
    return pendingLoads.removeAt(0).future;
  }

  @override
  Future<NotificationModel> sendTestPush() async => testNotification!;
}
