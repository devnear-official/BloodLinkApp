import 'package:flutter/foundation.dart';

import '../core/utils/error_mapper.dart';
import '../models/user_model.dart';
import '../services/user_service.dart';

/// Drives donor search, profile editing, and the admin user-management
/// screen. Kept separate from [AuthProvider], which only owns the
/// currently logged-in session.
class UserProvider extends ChangeNotifier {
  UserProvider({UserService? userService})
      : _userService = userService ?? UserService();

  final UserService _userService;

  List<UserModel> donors = [];
  List<UserModel> allUsers = []; // used by the admin panel
  bool isLoading = false;
  AppError? appError;
  String? get errorMessage => appError?.message;

  String divisionFilter = '';
  String districtFilter = '';
  String subDistrictFilter = '';
  String bloodGroupFilter = '';

  /// Set when the current filters came from "Find Donors Near Me" rather
  /// than manual dropdown selection, so the UI can show a "near you"
  /// banner with the detected place name and a way to clear it.
  String? nearMeLabel;

  Future<void> loadDonors() async {
    isLoading = true;
    appError = null;
    notifyListeners();
    try {
      final users = await _userService.getUsers(
        division: divisionFilter,
        district: districtFilter,
        subDistrict: subDistrictFilter,
        bloodGroup: bloodGroupFilter,
      );
      donors = users.where((u) {
        if (u.status != 'Available') return false;
        // Always enforce every active filter client-side too — some
        // backends silently ignore query params they don't recognize, so
        // relying on the server alone can make filters look broken even
        // though the request succeeded.
        if (divisionFilter.isNotEmpty &&
            (u.division ?? '').trim().toLowerCase() !=
                divisionFilter.trim().toLowerCase()) {
          return false;
        }
        if (districtFilter.isNotEmpty &&
            (u.district ?? '').trim().toLowerCase() !=
                districtFilter.trim().toLowerCase()) {
          return false;
        }
        if (subDistrictFilter.isNotEmpty &&
            (u.subDistrict ?? '').trim().toLowerCase() !=
                subDistrictFilter.trim().toLowerCase()) {
          return false;
        }
        if (bloodGroupFilter.isNotEmpty &&
            (u.bloodGroup ?? '').trim().toUpperCase() !=
                bloodGroupFilter.trim().toUpperCase()) {
          return false;
        }
        return true;
      }).toList();
    } catch (e) {
      appError = mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void setDivisionFilter(String value) {
    divisionFilter = value;
    districtFilter = '';
    subDistrictFilter = '';
    nearMeLabel = null;
    loadDonors();
  }

  void setDistrictFilter(String value) {
    districtFilter = value;
    subDistrictFilter = '';
    nearMeLabel = null;
    loadDonors();
  }

  void setSubDistrictFilter(String value) {
    subDistrictFilter = value;
    nearMeLabel = null;
    loadDonors();
  }

  void setBloodGroupFilter(String value) {
    bloodGroupFilter = value;
    loadDonors();
  }

  /// Applies a division/district/sub-district all at once (e.g. from
  /// "Find Donors Near Me") in a single reload, and records [label] for
  /// the "near you" banner. Pass an empty string for any level that
  /// couldn't be confidently detected — it's simply left unfiltered.
  void applyDetectedLocation({
    required String division,
    required String district,
    required String subDistrict,
    required String label,
  }) {
    divisionFilter = division;
    districtFilter = district;
    subDistrictFilter = subDistrict;
    nearMeLabel = label;
    loadDonors();
  }

  /// Clears a "near me" filter set, returning to the manual dropdown
  /// filters (all empty, i.e. every available donor).
  void clearNearMe() {
    divisionFilter = '';
    districtFilter = '';
    subDistrictFilter = '';
    nearMeLabel = null;
    loadDonors();
  }

  Future<UserModel?> updateProfile(Map<String, dynamic> updates) async {
    isLoading = true;
    appError = null;
    notifyListeners();
    try {
      final updated = await _userService.updateMe(updates);
      isLoading = false;
      notifyListeners();
      return updated;
    } catch (e) {
      appError = mapError(e);
      isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // --- Admin -----------------------------------------------------------

  Future<void> loadAllUsers() async {
    isLoading = true;
    appError = null;
    notifyListeners();
    try {
      allUsers = await _userService.getUsers();
    } catch (e) {
      appError = mapError(e);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> setUserStatus(String userId, String status) async {
    try {
      await _userService.updateUserStatus(userId, status);
      await loadAllUsers();
      return true;
    } catch (e) {
      appError = mapError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> setUserRole(String userId, String role) async {
    try {
      await _userService.updateUserRole(userId, role);
      await loadAllUsers();
      return true;
    } catch (e) {
      appError = mapError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteUser(String userId) async {
    try {
      await _userService.deleteUser(userId);
      allUsers.removeWhere((u) => u.id == userId);
      notifyListeners();
      return true;
    } catch (e) {
      appError = mapError(e);
      notifyListeners();
      return false;
    }
  }
}
