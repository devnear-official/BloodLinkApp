import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_strings.dart';
import '../../core/services/geolocation_service.dart';
import '../../core/utils/error_mapper.dart';
import '../../core/widgets/error_state_view.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favorites_provider.dart';
import '../../services/user_service.dart';
import '../direct_request/send_direct_request_screen.dart';
import '../shared/location_selector.dart';
import '../donor/widgets/donor_card.dart';

/// "Find Nearby" bottom-nav tab: automatically detects the person's
/// current GPS location on open (no button press needed) and shows
/// available donors matching the detected division/district/upazila —
/// the flagship "Nearby Donor Detection" feature from the project
/// proposal, always-on rather than tucked behind a manual filter.
///
/// Deliberately keeps its own state rather than mutating
/// [UserProvider]'s shared filters, so switching to this tab never
/// silently changes what the "Donors" tab's manual search shows.
class NearbyDonorsScreen extends StatefulWidget {
  const NearbyDonorsScreen({super.key, required this.isActive});

  final bool isActive;

  @override
  State<NearbyDonorsScreen> createState() => _NearbyDonorsScreenState();
}

enum _NearbyStatus { detecting, loadingDonors, loaded, permissionError, error }

class _NearbyDonorsScreenState extends State<NearbyDonorsScreen> {
  final _userService = UserService();

  _NearbyStatus _status = _NearbyStatus.detecting;
  DetectedLocation? _location;
  List<UserModel> _donors = [];
  LocationPermissionException? _permissionError;
  AppError? _appError;
  bool _needsManualArea = false;
  bool _usingGpsRadius = false;
  bool _usingAreaFallback = false;
  double _radiusKm = 25;
  String? _manualDivision;
  String? _manualDistrict;
  bool _hasStartedInitialDetection = false;

  @override
  void initState() {
    super.initState();
    _startDetectionWhenActive();
  }

  @override
  void didUpdateWidget(covariant NearbyDonorsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) _startDetectionWhenActive();
  }

  void _startDetectionWhenActive() {
    if (!widget.isActive || _hasStartedInitialDetection) return;
    _hasStartedInitialDetection = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.isActive) _detectAndLoad();
    });
  }

  Future<void> _detectAndLoad() async {
    setState(() {
      _status = _NearbyStatus.detecting;
      _permissionError = null;
      _appError = null;
    });

    try {
      final location =
          await GeolocationService.instance.detectCurrentLocation();
      if (!mounted) return;

      if (!location.matchedAnything) {
        setState(() {
          _location = location;
          _needsManualArea = true;
          _manualDivision = null;
          _manualDistrict = null;
          _status = _NearbyStatus.loadingDonors;
        });
        await _loadDonors(location);
        return;
      }

      setState(() {
        _location = location;
        _needsManualArea = false;
        _status = _NearbyStatus.loadingDonors;
      });
      await _loadDonors(location);
    } on LocationPermissionException catch (e) {
      if (!mounted) return;
      setState(() {
        _permissionError = e;
        _status = _NearbyStatus.permissionError;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _appError = mapError(e);
        _status = _NearbyStatus.error;
      });
    }
  }

  Future<void> _loadDonors(DetectedLocation? location) async {
    try {
      final currentUserId = context.read<AuthProvider>().currentUser?.id;
      final division = _needsManualArea ? _manualDivision : location?.division;
      final district = _needsManualArea ? _manualDistrict : location?.district;
      final subDistrict = _needsManualArea ? null : location?.subDistrict;
      final canSearchByGps = location != null &&
          (!_needsManualArea ||
              (_manualDivision == null && _manualDistrict == null));
      var usedGpsRadius = false;
      var users = <UserModel>[];
      if (canSearchByGps) {
        users = await _userService.getNearbyUsers(
          latitude: location.latitude,
          longitude: location.longitude,
          radiusKm: _radiusKm,
        );
        usedGpsRadius = users.isNotEmpty;
      }
      if (users.isEmpty) {
        users = await _userService.getUsers(
          division: division,
          district: district,
          subDistrict: subDistrict,
          availableOnly: true,
        );
      }
      final usingAreaFallback = canSearchByGps && !usedGpsRadius;
      if (!mounted) return;
      setState(() {
        _donors = users.where((u) {
          if (u.status != 'Available') return false;
          if (u.id == currentUserId) return false;
          // Enforce client-side too, same reasoning as everywhere else in
          // the app — some backends ignore query params they don't know.
          if (!usedGpsRadius &&
              district != null &&
              !_sameArea(u.district, district)) {
            return false;
          }
          if (!usedGpsRadius &&
              division != null &&
              !_sameArea(u.division, division)) {
            return false;
          }
          if (!usedGpsRadius &&
              subDistrict != null &&
              !_sameArea(u.subDistrict, subDistrict)) {
            return false;
          }
          return true;
        }).toList();
        _usingGpsRadius = usedGpsRadius;
        _usingAreaFallback = usingAreaFallback;
        _status = _NearbyStatus.loaded;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _appError = mapError(e);
        _status = _NearbyStatus.error;
      });
    }
  }

  bool _sameArea(String? actual, String expected) =>
      (actual ?? '').trim().toLowerCase() == expected.trim().toLowerCase();

  void _searchByArea() {
    setState(() {
      _needsManualArea = true;
      _manualDivision = null;
      _manualDistrict = null;
      _status = _NearbyStatus.loadingDonors;
    });
    _loadDonors(_location);
  }

  void _openSendRequest(UserModel donor) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SendDirectRequestScreen(donor: donor)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _detectAndLoad,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    final favorites = context.watch<FavoritesProvider>();
    final strings = AppStrings.of(context);
    final colors = Theme.of(context).colorScheme;

    switch (_status) {
      case _NearbyStatus.detecting:
        return ListView(
          children: [
            const SizedBox(height: 120),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
            Center(
              child: Text(
                strings.text('detectingLocation'),
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
            ),
          ],
        );

      case _NearbyStatus.loadingDonors:
        return ListView(
          children: [
            _locationBanner(),
            if (_needsManualArea) ...[
              _manualAreaPicker(),
              if (_manualDistrict == null && _manualDivision == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                  child: Text(
                    'Showing available donors across all areas. Choose your area to narrow the results.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 60),
            const Center(child: CircularProgressIndicator()),
          ],
        );

      case _NearbyStatus.permissionError:
        return ListView(
          children: [
            _locationBanner(),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.location_off_outlined,
                        size: 34, color: colors.primary),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    strings.text('locationNeeded'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _permissionError?.message ??
                        'Location permission is required.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: colors.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _detectAndLoad,
                        child: Text(strings.text('tryAgain')),
                      ),
                      if (_permissionError?.canOpenSettings ?? false) ...[
                        ElevatedButton(
                          onPressed: () => Geolocator.openAppSettings(),
                          child: const Text('Open Settings'),
                        ),
                      ],
                      if (_permissionError?.canOpenLocationSettings ??
                          false) ...[
                        ElevatedButton(
                          onPressed: () => Geolocator.openLocationSettings(),
                          child: const Text('Enable Location'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            _manualAreaPicker(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: OutlinedButton.icon(
                onPressed: _searchByArea,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Find donors by area instead'),
              ),
            ),
          ],
        );

      case _NearbyStatus.error:
        return ListView(
          children: [
            _locationBanner(),
            ErrorStateViewFromAppError(
              appError: _appError!,
              onRetry: _detectAndLoad,
            ),
            _manualAreaPicker(),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
              child: OutlinedButton.icon(
                onPressed: _searchByArea,
                icon: const Icon(Icons.search_rounded),
                label: const Text('Find donors by area instead'),
              ),
            ),
          ],
        );

      case _NearbyStatus.loaded:
        if (_donors.isEmpty) {
          return ListView(
            children: [
              _locationBanner(),
              if (_needsManualArea) _manualAreaPicker(),
              const SizedBox(height: 60),
              Icon(Icons.people_outline,
                  size: 56, color: colors.onSurfaceVariant),
              const SizedBox(height: 12),
              Center(
                child: Text(strings.text('noNearbyDonors')),
              ),
              const SizedBox(height: 4),
              Center(
                child: Text(
                  strings.text('widerSearch'),
                  style:
                      TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                ),
              ),
            ],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 90),
          itemCount: _donors.length + (_needsManualArea ? 2 : 1),
          itemBuilder: (context, index) {
            if (index == 0) return _locationBanner();
            if (_needsManualArea && index == 1) return _manualAreaPicker();
            final donor = _donors[index - (_needsManualArea ? 2 : 1)];
            return DonorCard(
              donor: donor,
              onSendRequest: () => _openSendRequest(donor),
              isFavorite: favorites.isFavorite(donor.id),
              onToggleFavorite: () => favorites.toggle(donor.id),
            );
          },
        );
    }
  }

  Widget _locationBanner() {
    final strings = AppStrings.of(context);
    final colors = Theme.of(context).colorScheme;
    final label = [
      _location?.subDistrict,
      _location?.district,
      _location?.division,
    ].where((s) => s != null && s.isNotEmpty).join(', ');

    final locationLabel = _needsManualArea
        ? label.isNotEmpty
            ? 'Confirm your search area'
            : 'Choose an area to find donors'
        : _status == _NearbyStatus.permissionError ||
                _status == _NearbyStatus.error
            ? 'Location could not be detected'
            : label.isEmpty
                ? 'Your current location'
                : 'Near $label';

    final locationDescription = _needsManualArea
        ? _location?.displayName ?? 'GPS unavailable · select an area below'
        : _status == _NearbyStatus.permissionError
            ? _permissionError?.message ??
                'Check location access and try again.'
            : _status == _NearbyStatus.error
                ? _appError?.message ?? 'Check your connection and try again.'
                : _usingGpsRadius
                    ? strings
                        .text('donorsWithinRadius')
                        .replaceAll('{radius}', _radiusKm.toInt().toString())
                    : _usingAreaFallback
                        ? 'No GPS-shared donors within ${_radiusKm.toInt()} km · showing area results'
                        : 'Available donors near your area';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.secondary.withValues(alpha: 0.12),
            colors.secondary.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.secondary.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colors.secondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.location_searching_rounded,
              color: colors.secondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locationLabel,
                  style: TextStyle(
                    fontSize: 14,
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  locationDescription,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: colors.onSurfaceVariant,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupMenuButton<double>(
                tooltip: 'Search radius',
                onSelected: (radius) {
                  setState(() {
                    _radiusKm = radius;
                    _status = _NearbyStatus.loadingDonors;
                  });
                  _loadDonors(_location);
                },
                itemBuilder: (context) => [5, 10, 25, 50, 100]
                    .map(
                      (radius) => PopupMenuItem<double>(
                        value: radius.toDouble(),
                        child: Text('$radius km radius'),
                      ),
                    )
                    .toList(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '${_radiusKm.toInt()} km',
                    style: TextStyle(
                      color: colors.secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              IconButton.filledTonal(
                tooltip: AppStrings.of(context).text('refreshLocation'),
                onPressed: _detectAndLoad,
                icon: const Icon(Icons.my_location_rounded, size: 19),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _manualAreaPicker() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.of(context).text('chooseArea'),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _location == null
                ? 'Location is unavailable right now. Select your area to find available donors.'
                : 'We found your position but could not identify its district. Select your area to narrow the results.',
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          LocationSelector(
            division: _manualDivision,
            district: _manualDistrict,
            showSubDistrict: false,
            allowClear: true,
            onDivisionChanged: (value) {
              setState(() {
                _needsManualArea = true;
                _manualDivision = value;
                _manualDistrict = null;
                _status = _NearbyStatus.loadingDonors;
              });
              _loadDonors(_location);
            },
            onDistrictChanged: (value) {
              setState(() {
                _needsManualArea = true;
                _manualDistrict = value;
                _status = _NearbyStatus.loadingDonors;
              });
              _loadDonors(_location);
            },
          ),
        ],
      ),
    );
  }
}
