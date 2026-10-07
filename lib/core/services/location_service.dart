import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../models/location_model.dart';

/// Loads and caches `assets/data/locations.json` — the single source of
/// truth for every division/district/sub-district picker and filter in
/// the app (registration, profile editing, request creation, donor
/// search, and the request feed).
///
/// The data never changes at runtime, so it's parsed once and cached for
/// the lifetime of the app.
class LocationService {
  LocationService._internal();
  static final LocationService instance = LocationService._internal();

  List<DivisionModel>? _divisions;
  Future<List<DivisionModel>>? _loadingFuture;

  /// Returns the cached divisions, loading and parsing the asset on first
  /// call. Safe to call repeatedly and concurrently.
  Future<List<DivisionModel>> loadDivisions() {
    if (_divisions != null) {
      return Future.value(_divisions);
    }
    _loadingFuture ??= _load();
    return _loadingFuture!;
  }

  Future<List<DivisionModel>> _load() async {
    final raw = await rootBundle.loadString('assets/data/locations.json');
    final list = jsonDecode(raw) as List<dynamic>;
    _divisions = list
        .map((e) => DivisionModel.fromJson(e as Map<String, dynamic>))
        .toList();
    return _divisions!;
  }

  /// Synchronous access once [loadDivisions] has resolved at least once
  /// elsewhere in the widget tree; returns an empty list if not yet
  /// loaded.
  List<DivisionModel> get cachedDivisions => _divisions ?? const [];

  List<String> districtNamesFor(String? divisionName) {
    if (divisionName == null || divisionName.isEmpty) return const [];
    final division = cachedDivisions.where((d) => d.division == divisionName);
    if (division.isEmpty) return const [];
    return division.first.districts.map((d) => d.district).toList();
  }

  List<String> upazilaNamesFor(String? divisionName, String? districtName) {
    if (divisionName == null ||
        divisionName.isEmpty ||
        districtName == null ||
        districtName.isEmpty) {
      return const [];
    }
    final division = cachedDivisions.where((d) => d.division == divisionName);
    if (division.isEmpty) return const [];
    final district =
        division.first.districts.where((d) => d.district == districtName);
    if (district.isEmpty) return const [];
    return district.first.upazilas;
  }

  /// Finds which division a given district belongs to. Useful when only a
  /// district name is known (e.g. restoring a saved profile) and the
  /// division dropdown needs to be pre-selected.
  String? divisionForDistrict(String? districtName) {
    if (districtName == null || districtName.isEmpty) return null;
    for (final division in cachedDivisions) {
      if (division.districts.any((d) => d.district == districtName)) {
        return division.division;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------
  // Fuzzy matching — used to map free-text location names from an
  // external source (Nominatim reverse-geocoding results) onto our known
  // division/district/upazila names, since spelling/casing/administrative
  // boundaries rarely line up exactly with a third-party gazetteer.
  // ---------------------------------------------------------------------

  static String _normalize(String value) =>
      value.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Returns the known division name that best matches [raw], or null if
  /// nothing looks close enough. Tries every candidate string in [raw] in
  /// order (callers pass several possible Nominatim fields since which
  /// field holds the division varies by area).
  String? matchDivision(Iterable<String?> candidates) {
    for (final candidate in candidates) {
      if (candidate == null || candidate.isEmpty) continue;
      final normalizedCandidate = _normalize(candidate);
      for (final division in cachedDivisions) {
        final normalizedName = _normalize(division.division);
        if (normalizedCandidate == normalizedName ||
            normalizedCandidate.contains(normalizedName) ||
            normalizedName.contains(normalizedCandidate)) {
          return division.division;
        }
      }
    }
    return null;
  }

  /// Returns the known district name that best matches [raw], optionally
  /// restricted to [divisionHint]'s districts first (falls back to
  /// searching every district if nothing matches within the hint).
  String? matchDistrict(Iterable<String?> candidates, {String? divisionHint}) {
    final searchSpace = <DistrictModel>[];
    if (divisionHint != null) {
      final division =
          cachedDivisions.where((d) => d.division == divisionHint);
      if (division.isNotEmpty) searchSpace.addAll(division.first.districts);
    }
    if (searchSpace.isEmpty) {
      for (final division in cachedDivisions) {
        searchSpace.addAll(division.districts);
      }
    }

    for (final candidate in candidates) {
      if (candidate == null || candidate.isEmpty) continue;
      final normalizedCandidate = _normalize(candidate);
      for (final district in searchSpace) {
        final normalizedName = _normalize(district.district);
        if (normalizedCandidate == normalizedName ||
            normalizedCandidate.contains(normalizedName) ||
            normalizedName.contains(normalizedCandidate)) {
          return district.district;
        }
      }
    }
    return null;
  }

  /// Returns the known upazila (sub-district) name that best matches
  /// [raw], restricted to [districtName]'s upazilas.
  String? matchSubDistrict(Iterable<String?> candidates, String? districtName) {
    if (districtName == null || districtName.isEmpty) return null;
    final upazilas = <String>[];
    for (final division in cachedDivisions) {
      final district =
          division.districts.where((d) => d.district == districtName);
      if (district.isNotEmpty) {
        upazilas.addAll(district.first.upazilas);
        break;
      }
    }

    for (final candidate in candidates) {
      if (candidate == null || candidate.isEmpty) continue;
      final normalizedCandidate = _normalize(candidate);
      for (final upazila in upazilas) {
        final normalizedName = _normalize(upazila);
        if (normalizedCandidate == normalizedName ||
            normalizedCandidate.contains(normalizedName) ||
            normalizedName.contains(normalizedCandidate)) {
          return upazila;
        }
      }
    }
    return null;
  }
}
