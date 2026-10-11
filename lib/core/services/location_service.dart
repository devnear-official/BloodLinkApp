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

  static String _normalize(String value) {
    var normalized = value.toLowerCase().trim();
    const aliases = {
      'cumilla': 'comilla',
      'chittagong': 'chattogram',
      'barisal': 'barishal',
      'jessore': 'jashore',
      'bogra': 'bogura',
    };
    for (final alias in aliases.entries) {
      normalized = normalized.replaceAll(alias.key, alias.value);
    }
    return normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  String? _matchName(Iterable<String?> candidates, Iterable<String> names) {
    final candidateNames = candidates
        .whereType<String>()
        .map((candidate) => _normalize(candidate))
        .where((candidate) => candidate.isNotEmpty)
        .toList();
    final knownNames = names.toList();

    for (final candidate in candidateNames) {
      for (final name in knownNames) {
        if (candidate == _normalize(name)) return name;
      }
    }

    for (final candidate in candidateNames) {
      for (final name in knownNames) {
        final normalizedName = _normalize(name);
        if (candidate.length >= 4 &&
            (candidate.contains(normalizedName) ||
                normalizedName.contains(candidate))) {
          return name;
        }
      }
    }
    return null;
  }

  /// Returns the known division name that best matches [raw], or null if
  /// nothing looks close enough. Tries every candidate string in [raw] in
  /// order (callers pass several possible Nominatim fields since which
  /// field holds the division varies by area).
  String? matchDivision(Iterable<String?> candidates) {
    return _matchName(
      candidates,
      cachedDivisions.map((division) => division.division),
    );
  }

  /// Returns the known district name that best matches [raw], optionally
  /// restricted to [divisionHint]'s districts first (falls back to
  /// searching every district if nothing matches within the hint).
  String? matchDistrict(Iterable<String?> candidates, {String? divisionHint}) {
    final searchSpace = <DistrictModel>[];
    if (divisionHint != null) {
      final division = cachedDivisions.where((d) => d.division == divisionHint);
      if (division.isNotEmpty) searchSpace.addAll(division.first.districts);
    }
    if (searchSpace.isEmpty) {
      for (final division in cachedDivisions) {
        searchSpace.addAll(division.districts);
      }
    }

    return _matchName(
      candidates,
      searchSpace.map((district) => district.district),
    );
  }

  /// Returns the known upazila (sub-district) name that best matches
  /// [raw], restricted to [districtName]'s upazilas.
  String? matchSubDistrict(Iterable<String?> candidates, String? districtName) {
    final upazilas = <String>[];
    if (districtName != null && districtName.isNotEmpty) {
      for (final division in cachedDivisions) {
        final district =
            division.districts.where((d) => d.district == districtName);
        if (district.isNotEmpty) {
          upazilas.addAll(district.first.upazilas);
          break;
        }
      }
    }

    final districtMatch =
        upazilas.isEmpty ? null : _matchName(candidates, upazilas);
    if (districtMatch != null) return districtMatch;

    return _matchName(
      candidates,
      cachedDivisions.expand(
        (division) =>
            division.districts.expand((district) => district.upazilas),
      ),
    );
  }

  String? districtForSubDistrict(
    String? subDistrict, {
    String? divisionHint,
  }) {
    if (subDistrict == null || subDistrict.isEmpty) return null;
    final divisions = cachedDivisions.toList();
    if (divisionHint != null) {
      divisions.sort((a, b) {
        if (a.division == divisionHint) return -1;
        if (b.division == divisionHint) return 1;
        return 0;
      });
    }
    for (final division in divisions) {
      for (final district in division.districts) {
        if (district.upazilas.any(
          (upazila) => _normalize(upazila) == _normalize(subDistrict),
        )) {
          return district.district;
        }
      }
    }
    return null;
  }
}
