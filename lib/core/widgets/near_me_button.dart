import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../constants/app_colors.dart';
import '../services/geolocation_service.dart';
import '../utils/error_mapper.dart';

/// A button that runs the "Nearby Donor Detection" flow from the project
/// proposal: request location permission, read the device's current GPS
/// position, reverse-geocode it via Nominatim, and hand the result back
/// to [onDetected] so the caller can apply it as a location filter.
///
/// Handles every failure mode with a friendly message instead of letting
/// a permission dialog or network error surface as a raw exception:
/// location services off, permission denied (with an "Open Settings"
/// action when it's permanently denied), and ordinary network failures
/// (routed through [mapError] like everywhere else in the app).
class NearMeButton extends StatefulWidget {
  const NearMeButton({super.key, required this.onDetected});

  final void Function(DetectedLocation location) onDetected;

  @override
  State<NearMeButton> createState() => _NearMeButtonState();
}

class _NearMeButtonState extends State<NearMeButton> {
  bool _detecting = false;

  Future<void> _detect() async {
    setState(() => _detecting = true);
    try {
      final location = await GeolocationService.instance.detectCurrentLocation();
      if (!mounted) return;
      setState(() => _detecting = false);

      if (!location.matchedAnything) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Found your location, but couldn't match it to a known area. "
              "Try the filters below instead.",
            ),
          ),
        );
        return;
      }
      widget.onDetected(location);
    } on LocationPermissionException catch (e) {
      if (!mounted) return;
      setState(() => _detecting = false);
      _showPermissionDialog(e);
    } catch (e) {
      if (!mounted) return;
      setState(() => _detecting = false);
      final mapped = mapError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mapped.message)),
      );
    }
  }

  void _showPermissionDialog(LocationPermissionException e) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Needed'),
        content: Text(e.message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          if (e.canOpenSettings)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Geolocator.openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _detecting ? null : _detect,
      icon: _detecting
          ? const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.my_location_rounded, size: 18),
      label: Text(_detecting ? 'Finding you…' : 'Find Donors Near Me'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.accent,
        side: const BorderSide(color: AppColors.accent),
      ),
    );
  }
}
