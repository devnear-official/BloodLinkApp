import 'package:flutter/foundation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/socket_service.dart';
import '../core/utils/error_mapper.dart';
import '../models/blood_request_model.dart';
import '../services/request_service.dart';

/// Drives the open blood-request feed and its details screen. Subscribes
/// to Socket.IO so new/updated/deleted requests reflect live without
/// polling.
class RequestProvider extends ChangeNotifier {
  RequestProvider({RequestService? requestService})
      : _requestService = requestService ?? RequestService() {
    _registerSocketListeners();
  }

  final RequestService _requestService;

  List<BloodRequestModel> requests = [];
  bool isLoading = false;
  bool isLoadingMoreRequests = false;
  bool hasMoreRequests = false;
  int totalRequests = 0;
  AppError? appError;
  String? get errorMessage => appError?.message;

  String divisionFilter = '';
  String districtFilter = '';
  String bloodGroupFilter = '';
  int _requestsPage = 0;
  int _requestLoadGeneration = 0;

  void _registerSocketListeners() {
    SocketService.instance.on(ApiEndpoints.eventRequestCreated, (data) {
      if (data is Map<String, dynamic>) {
        final incoming = BloodRequestModel.fromJson(data);
        if (!requests.any((r) => r.id == incoming.id) &&
            _matchesActiveFilters(incoming)) {
          requests = [incoming, ...requests];
          notifyListeners();
        }
      }
    });

    SocketService.instance.on(ApiEndpoints.eventRequestUpdated, (data) {
      if (data is Map<String, dynamic>) {
        final updated = BloodRequestModel.fromJson(data);
        if (_matchesActiveFilters(updated)) {
          requests =
              requests.map((r) => r.id == updated.id ? updated : r).toList();
        } else {
          // No longer matches the active filter (e.g. its district was
          // edited) — drop it from the filtered view instead of leaving a
          // stale/mismatched entry in the list.
          requests = requests.where((r) => r.id != updated.id).toList();
        }
        notifyListeners();
      }
    });

    SocketService.instance.on(ApiEndpoints.eventRequestDeleted, (data) {
      final id = data is Map ? data['id']?.toString() : data?.toString();
      if (id != null) {
        requests = requests.where((r) => r.id != id).toList();
        notifyListeners();
      }
    });
  }

  /// Whether [request] matches every currently active filter — used both
  /// after a fetch and when a realtime socket event brings in a request
  /// that never went through [loadRequests]'s filtering.
  bool _matchesActiveFilters(BloodRequestModel request) {
    if (divisionFilter.isNotEmpty &&
        request.division.trim().toLowerCase() !=
            divisionFilter.trim().toLowerCase()) {
      return false;
    }
    if (districtFilter.isNotEmpty &&
        request.district.trim().toLowerCase() !=
            districtFilter.trim().toLowerCase()) {
      return false;
    }
    if (bloodGroupFilter.isNotEmpty &&
        request.bloodGroup.trim().toUpperCase() !=
            bloodGroupFilter.trim().toUpperCase()) {
      return false;
    }
    return true;
  }

  @override
  void dispose() {
    SocketService.instance.off(ApiEndpoints.eventRequestCreated);
    SocketService.instance.off(ApiEndpoints.eventRequestUpdated);
    SocketService.instance.off(ApiEndpoints.eventRequestDeleted);
    super.dispose();
  }

  /// Ensures [id] is present in [requests], fetching it directly if it
  /// isn't yet (e.g. when the person jumps straight to a request from a
  /// notification before the feed tab has ever been opened). Deliberately
  /// bypasses the active division/district/blood-group filters and merges
  /// the result in, so opening a request from outside the current filter
  /// doesn't get silently dropped by [_matchesActiveFilters].
  Future<bool> ensureLoaded(String id) async {
    if (requests.any((r) => r.id == id)) return true;
    appError = null;
    try {
      final unfiltered = await _requestService.getRequests();
      final match = unfiltered.where((r) => r.id == id);
      if (match.isNotEmpty) {
        requests = [match.first, ...requests];
        notifyListeners();
        return true;
      }
      return false;
    } catch (error) {
      appError = mapError(error);
      notifyListeners();
      return false;
    }
  }

  Future<void> loadRequests() async {
    final generation = ++_requestLoadGeneration;
    isLoading = true;
    hasMoreRequests = false;
    appError = null;
    notifyListeners();
    try {
      final result = await _requestService.getRequestPage(
        page: 1,
        division: divisionFilter,
        district: districtFilter,
        bloodGroup: bloodGroupFilter,
      );
      if (generation != _requestLoadGeneration) return;
      requests = result.items.where(_matchesActiveFilters).toList();
      _requestsPage = result.page;
      totalRequests = result.total;
      hasMoreRequests = result.hasMore;
    } catch (e) {
      if (generation != _requestLoadGeneration) return;
      appError = mapError(e);
    } finally {
      if (generation == _requestLoadGeneration) {
        isLoading = false;
        isLoadingMoreRequests = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreRequests() async {
    if (isLoading || isLoadingMoreRequests || !hasMoreRequests) return;
    final generation = _requestLoadGeneration;
    isLoadingMoreRequests = true;
    notifyListeners();
    try {
      final result = await _requestService.getRequestPage(
        page: _requestsPage + 1,
        division: divisionFilter,
        district: districtFilter,
        bloodGroup: bloodGroupFilter,
      );
      if (generation != _requestLoadGeneration) return;
      final existingIds = requests.map((request) => request.id).toSet();
      requests = [
        ...requests,
        ...result.items
            .where(_matchesActiveFilters)
            .where((request) => existingIds.add(request.id)),
      ];
      _requestsPage = result.page;
      totalRequests = result.total;
      hasMoreRequests = result.hasMore;
    } catch (e) {
      if (generation == _requestLoadGeneration) appError = mapError(e);
    } finally {
      if (generation == _requestLoadGeneration) {
        isLoadingMoreRequests = false;
        notifyListeners();
      }
    }
  }

  void setDivisionFilter(String value) {
    divisionFilter = value;
    districtFilter = '';
    loadRequests();
  }

  void setDistrictFilter(String value) {
    districtFilter = value;
    loadRequests();
  }

  void setBloodGroupFilter(String value) {
    bloodGroupFilter = value;
    loadRequests();
  }

  Future<bool> createRequest(BloodRequestModel request) async {
    try {
      final created = await _requestService.createRequest(request);
      requests = [created, ...requests];
      notifyListeners();
      return true;
    } catch (e) {
      appError = mapError(e);
      notifyListeners();
      return false;
    }
  }

  /// Donor responds to [requestId]; backend re-validates 90-day
  /// eligibility regardless of the client-side check already shown in UI.
  Future<bool> respondToRequest(String requestId) async {
    try {
      final updated = await _requestService.respondToRequest(requestId);
      _replace(updated);
      return true;
    } catch (e) {
      appError = mapError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> setResponseStatus({
    required String requestId,
    required String donorId,
    required String status,
  }) async {
    try {
      final updated = await _requestService.setResponseStatus(
        requestId: requestId,
        donorId: donorId,
        status: status,
      );
      _replace(updated);
      return true;
    } catch (e) {
      appError = mapError(e);
      notifyListeners();
      return false;
    }
  }

  /// "Auto Lock Request" from the project proposal's use-case diagram:
  /// accepting a donor's response also locks the whole request (moves it
  /// to `Accepted` status) so it stops accepting new offers, and every
  /// other still-`Pending` response is auto-rejected in the same action —
  /// the requester picks exactly one donor, not several in parallel.
  Future<bool> acceptDonorResponse({
    required String requestId,
    required String donorId,
  }) async {
    try {
      var updated = await _requestService.setResponseStatus(
        requestId: requestId,
        donorId: donorId,
        status: 'Accepted',
      );
      updated = await _requestService.updateRequestStatus(
        requestId: requestId,
        status: 'Accepted',
      );

      // Auto-reject every other donor who was still waiting, so the
      // requester doesn't have to clean those up by hand.
      final stillPending = updated.responses.where(
        (r) => r.donor.id != donorId && r.status == 'Pending',
      );
      for (final response in stillPending) {
        updated = await _requestService.setResponseStatus(
          requestId: requestId,
          donorId: response.donor.id,
          status: 'Rejected',
        );
      }

      _replace(updated);
      return true;
    } catch (e) {
      appError = mapError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateStatus(String requestId, String status) async {
    try {
      final updated = await _requestService.updateRequestStatus(
        requestId: requestId,
        status: status,
      );
      _replace(updated);
      return true;
    } catch (e) {
      appError = mapError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updatePriority(String requestId, String priority) async {
    try {
      final updated = await _requestService.updateRequestPriority(
        requestId: requestId,
        priority: priority,
      );
      _replace(updated);
      return true;
    } catch (e) {
      appError = mapError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRequest(String requestId) async {
    try {
      await _requestService.deleteRequest(requestId);
      requests = requests.where((r) => r.id != requestId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      appError = mapError(e);
      notifyListeners();
      return false;
    }
  }

  void _replace(BloodRequestModel updated) {
    requests = requests.map((r) => r.id == updated.id ? updated : r).toList();
    notifyListeners();
  }
}
