import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../core/services/storage_service.dart';
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
  bool isLoadingMoreDonors = false;
  bool hasMoreDonors = false;
  bool isUsingOfflineCache = false;
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
  int _donorPage = 0;
  int _donorLoadGeneration = 0;

  String get _donorCacheKey => [
        'bloodlink_donor_cache',
        divisionFilter,
        districtFilter,
        subDistrictFilter,
        bloodGroupFilter,
      ].join(':');

  List<UserModel> _filterDonors(Iterable<UserModel> users) => users.where((u) {
        if (u.status != 'Available') return false;
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

  Future<void> loadDonors() async {
    final generation = ++_donorLoadGeneration;
    final cacheKey = _donorCacheKey;
    isLoading = true;
    hasMoreDonors = false;
    isUsingOfflineCache = false;
    appError = null;
    notifyListeners();
    try {
      final result = await _userService.getDonorPage(
        page: 1,
        division: divisionFilter,
        district: districtFilter,
        subDistrict: subDistrictFilter,
        bloodGroup: bloodGroupFilter,
      );
      if (generation != _donorLoadGeneration) return;
      donors = _filterDonors(result.items);
      _donorPage = result.page;
      hasMoreDonors = result.hasMore;
      try {
        await StorageService.instance.saveCachedJsonList(
          cacheKey,
          donors.map((donor) => donor.toPublicCacheJson()).toList(),
        );
      } catch (cacheError) {
        debugPrint('Could not cache donor results: $cacheError');
      }
    } catch (e) {
      if (generation != _donorLoadGeneration) return;
      try {
        final cached =
            await StorageService.instance.getCachedJsonList(cacheKey);
        if (cached != null) {
          donors = _filterDonors(cached.map(UserModel.fromJson));
          hasMoreDonors = false;
          isUsingOfflineCache = true;
          appError = null;
        } else {
          appError = mapError(e);
        }
      } catch (cacheError) {
        appError = mapError(e);
        debugPrint('Could not read cached donor results: $cacheError');
      }
    } finally {
      if (generation == _donorLoadGeneration) {
        isLoading = false;
        isLoadingMoreDonors = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreDonors() async {
    if (isLoading || isLoadingMoreDonors || !hasMoreDonors) return;
    final generation = _donorLoadGeneration;
    isLoadingMoreDonors = true;
    notifyListeners();
    try {
      final result = await _userService.getDonorPage(
        page: _donorPage + 1,
        division: divisionFilter,
        district: districtFilter,
        subDistrict: subDistrictFilter,
        bloodGroup: bloodGroupFilter,
      );
      if (generation != _donorLoadGeneration) return;
      final existingIds = donors.map((donor) => donor.id).toSet();
      donors = [
        ...donors,
        ..._filterDonors(result.items)
            .where((donor) => existingIds.add(donor.id)),
      ];
      _donorPage = result.page;
      hasMoreDonors = result.hasMore;
      try {
        await StorageService.instance.saveCachedJsonList(
          _donorCacheKey,
          donors.map((donor) => donor.toPublicCacheJson()).toList(),
        );
      } catch (cacheError) {
        debugPrint('Could not update donor cache: $cacheError');
      }
    } catch (e) {
      if (generation == _donorLoadGeneration) appError = mapError(e);
    } finally {
      if (generation == _donorLoadGeneration) {
        isLoadingMoreDonors = false;
        notifyListeners();
      }
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

  Future<UserModel?> uploadProfilePhoto(XFile photo) async {
    appError = null;
    try {
      return await _userService.uploadProfilePhoto(photo);
    } catch (e) {
      appError = mapError(e);
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
