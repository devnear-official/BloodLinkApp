import 'package:flutter/foundation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/socket_service.dart';
import '../core/utils/error_mapper.dart';
import '../models/direct_request_model.dart';
import '../services/direct_request_service.dart';

/// Drives the Direct Requests screen's Received / Sent tabs, with realtime
/// updates via Socket.IO.
class DirectRequestProvider extends ChangeNotifier {
  DirectRequestProvider({DirectRequestService? service})
      : _service = service ?? DirectRequestService() {
    _registerSocketListeners();
  }

  final DirectRequestService _service;

  List<DirectRequestModel> received = [];
  List<DirectRequestModel> sent = [];
  bool isLoading = false;
  AppError? appError;
  String? get errorMessage => appError?.message;

  void _registerSocketListeners() {
    SocketService.instance.on(ApiEndpoints.eventDirectRequestNew, (data) {
      if (data is Map<String, dynamic>) {
        final incoming = DirectRequestModel.fromJson(data);
        if (!received.any((r) => r.id == incoming.id)) {
          received = [incoming, ...received];
          notifyListeners();
        }
      }
    });

    SocketService.instance.on(ApiEndpoints.eventDirectRequestUpdated, (data) {
      if (data is Map<String, dynamic>) {
        final updated = DirectRequestModel.fromJson(data);
        received = received
            .map((r) => r.id == updated.id ? updated : r)
            .toList();
        sent = sent.map((r) => r.id == updated.id ? updated : r).toList();
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    SocketService.instance.off(ApiEndpoints.eventDirectRequestNew);
    SocketService.instance.off(ApiEndpoints.eventDirectRequestUpdated);
    super.dispose();
  }

  Future<void> loadAll() async {
    isLoading = true;
    appError = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _service.getDirectRequests('received'),
        _service.getDirectRequests('sent'),
      ]);
      received = results[0];
      sent = results[1];
    } catch (e) {
      appError = mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> sendDirectRequest(
    DirectRequestModel request, {
    required String toUserId,
  }) async {
    try {
      final created = await _service.createDirectRequest(
        request,
        toUserId: toUserId,
      );
      sent = [created, ...sent];
      notifyListeners();
      return true;
    } catch (e) {
      appError = mapError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> respond(String id, String status) async {
    try {
      final updated = await _service.updateStatus(id: id, status: status);
      received = received.map((r) => r.id == id ? updated : r).toList();
      notifyListeners();
      return true;
    } catch (e) {
      appError = mapError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancel(String id) async {
    try {
      await _service.cancel(id);
      sent = sent.where((r) => r.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      appError = mapError(e);
      notifyListeners();
      return false;
    }
  }
}
