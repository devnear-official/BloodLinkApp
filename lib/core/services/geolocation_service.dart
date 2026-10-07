import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';

import 'location_service.dart';

/// Thrown when location detection can't proceed for a reason the UI should
/// explain to the person (permission denied, services off, etc.) rather
/// than treating as a generic network failure.
class LocationPermissionException implements Exception {
  LocationPermissionException(this.message, {this.canOpenSettings = false});
  final String message;

  /// Whether [Geolocator.openAppSettings] is a meaningful next step (i.e.
  /// permission was denied rather than the whole location service being
  /// off at the OS level).
  final bool canOpenSettings;

  @override
  String toString() => message;
}

/// The result of detecting the person's current location: the raw GPS
/// coordinates, Nominatim's human-readable place name, and — best-effort —
/// which of our known division/district/upazila it falls within.
class DetectedLocation {
  const DetectedLocation({
    required this.latitude,
    required this.longitude,
    required this.displayName,
    this.division,
    this.district,
    this.subDistrict,
  });

  final double latitude;
  final double longitude;

  /// Nominatim's full "display_name" for the point, shown to the person
  /// as a friendly confirmation of what was detected.
  final String displayName;

  /// Best-effort matches against our known location list — any of these
  /// can be null if Nominatim's address didn't contain anything we could
  /// confidently match (rural areas in particular often lack a clean
  /// district-level field).
  final String? division;
  final String? district;
  final String? subDistrict;

  bool get matchedAnything =>
      division != null || district != null || subDistrict != null;
}

/// Detects the person's current GPS position and reverse-geocodes it into
/// a division/district/upazila, powering the "Nearby Donor Detection"
/// feature from the project proposal.
///
/// Uses a plain [Dio] instance (not [ApiClient]) since
/// nominatim.openstreetmap.org is a third-party public API unrelated to
/// the app's own backend — no auth header, different base URL, different
/// failure modes.
class GeolocationService {
  GeolocationService._internal();
  static final GeolocationService instance = GeolocationService._internal();

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        // Nominatim's usage policy requires a descriptive User-Agent
        // identifying the application — requests without one are
        // frequently rate-limited or blocked outright.
        'User-Agent': 'BloodLinkApp/1.0 (contact: support@bloodlink.app)',
      },
    ),
  );

  /// Requests location permission (if needed), reads the current GPS
  /// position, and reverse-geocodes it via Nominatim. Throws
  /// [LocationPermissionException] for permission/service problems the UI
  /// should explain specifically, or the raw [DioException] for network
  /// failures (let the caller run it through `mapError` as usual).
  Future<DetectedLocation> detectCurrentLocation() async {
    await _ensurePermission();

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 20),
      ),
    );

    return _reverseGeocode(position.latitude, position.longitude);
  }

  Future<void> _ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationPermissionException(
        'Location services are turned off. Please enable location/GPS and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationPermissionException(
          'Location permission was denied. BloodLink needs it to find donors near you.',
        );
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationPermissionException(
        'Location permission is permanently denied. Please enable it from app settings.',
        canOpenSettings: true,
      );
    }
  }

  Future<DetectedLocation> _reverseGeocode(double lat, double lon) async {
    // Make sure the location dataset is loaded before we try to match
    // against it — the caller may not have rendered a LocationSelector
    // yet, which is what normally triggers this load.
    await LocationService.instance.loadDivisions();

    final response = await _dio.get<Map<String, dynamic>>(
      'https://nominatim.openstreetmap.org/reverse',
      queryParameters: {
        'format': 'json',
        'lat': lat,
        'lon': lon,
        'zoom': 10,
        'addressdetails': 1,
      },
    );

    final data = response.data ?? const {};
    final address = (data['address'] as Map<String, dynamic>?) ?? const {};
    final displayName = (data['display_name'] as String?) ?? 'Unknown location';

    // Nominatim's field names for Bangladesh's admin levels vary by area
    // (rural vs. municipal vs. metro), so try every plausible candidate
    // field for each administrative level rather than a single fixed key.
    final divisionCandidates = [
      address['state'],
      address['region'],
    ].map((e) => e?.toString());

    final districtCandidates = [
      address['state_district'],
      address['county'],
      address['city'],
      address['district'],
    ].map((e) => e?.toString());

    final subDistrictCandidates = [
      address['city_district'],
      address['municipality'],
      address['town'],
      address['suburb'],
      address['village'],
    ].map((e) => e?.toString());

    final location = LocationService.instance;
    final division = location.matchDivision(divisionCandidates);
    final district = location.matchDistrict(
      districtCandidates,
      divisionHint: division,
    );
    final subDistrict = district != null
        ? location.matchSubDistrict(subDistrictCandidates, district)
        : null;

    return DetectedLocation(
      latitude: lat,
      longitude: lon,
      displayName: displayName,
      division: division,
      district: district,
      subDistrict: subDistrict,
    );
  }
}
