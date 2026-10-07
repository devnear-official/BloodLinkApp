import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/geolocation_service.dart';
import '../../core/utils/error_mapper.dart';
import '../../core/widgets/error_state_view.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/user_service.dart';
import '../direct_request/send_direct_request_screen.dart';
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
  const NearbyDonorsScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _detectAndLoad());
  }

  Future<void> _detectAndLoad() async {
    setState(() {
      _status = _NearbyStatus.detecting;
      _permissionError = null;
      _appError = null;
    });

    try {
      final location = await GeolocationService.instance.detectCurrentLocation();
      if (!mounted) return;

      if (!location.matchedAnything) {
        setState(() {
          _location = location;
          _status = _NearbyStatus.error;
          _appError = const AppError(
            message:
                "Found your location, but couldn't match it to a known area. "
                "Try the Donors tab and filter manually instead.",
            type: AppErrorType.unknown,
          );
        });
        return;
      }

      setState(() {
        _location = location;
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

  Future<void> _loadDonors(DetectedLocation location) async {
    try {
      final currentUserId = context.read<AuthProvider>().currentUser?.id;
      final users = await _userService.getUsers(
        division: location.division,
        district: location.district,
        subDistrict: location.subDistrict,
      );
      if (!mounted) return;
      setState(() {
        _donors = users.where((u) {
          if (u.status != 'Available') return false;
          if (u.id == currentUserId) return false;
          // Enforce client-side too, same reasoning as everywhere else in
          // the app — some backends ignore query params they don't know.
          if (location.district != null &&
              (u.district ?? '').trim().toLowerCase() !=
                  location.district!.trim().toLowerCase()) {
            return false;
          }
          return true;
        }).toList();
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
    switch (_status) {
      case _NearbyStatus.detecting:
        return ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: CircularProgressIndicator()),
            SizedBox(height: 16),
            Center(
              child: Text(
                'Detecting your location…',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        );

      case _NearbyStatus.loadingDonors:
        return ListView(
          children: [
            _locationBanner(),
            const SizedBox(height: 60),
            const Center(child: CircularProgressIndicator()),
          ],
        );

      case _NearbyStatus.permissionError:
        return ListView(
          children: [
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_off_outlined,
                        size: 34, color: AppColors.primary),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Location Needed',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _permissionError?.message ?? 'Location permission is required.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: _detectAndLoad,
                        child: const Text('Try Again'),
                      ),
                      if (_permissionError?.canOpenSettings ?? false) ...[
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => Geolocator.openAppSettings(),
                          child: const Text('Open Settings'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        );

      case _NearbyStatus.error:
        return ListView(
          children: [
            ErrorStateViewFromAppError(
              appError: _appError!,
              onRetry: _detectAndLoad,
            ),
          ],
        );

      case _NearbyStatus.loaded:
        if (_donors.isEmpty) {
          return ListView(
            children: [
              _locationBanner(),
              const SizedBox(height: 60),
              const Icon(Icons.people_outline,
                  size: 56, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              const Center(
                child: Text('No available donors found near you'),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  'Try the Donors tab to search a wider area',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 90, top: 4),
          itemCount: _donors.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) return _locationBanner();
            final donor = _donors[index - 1];
            return DonorCard(
              donor: donor,
              onSendRequest: () => _openSendRequest(donor),
            );
          },
        );
    }
  }

  Widget _locationBanner() {
    final label = [
      _location?.subDistrict,
      _location?.district,
      _location?.division,
    ].where((s) => s != null && s.isNotEmpty).join(', ');

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.near_me_rounded, size: 16, color: AppColors.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label.isEmpty ? 'Your current location' : 'Near $label',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.accent,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: _detectAndLoad,
            child: const Icon(Icons.refresh_rounded, size: 18, color: AppColors.accent),
          ),
        ],
      ),
    );
  }
}
