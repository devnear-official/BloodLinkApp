import 'package:flutter/material.dart';

import '../../core/services/location_service.dart';
import '../../models/location_model.dart';

/// A controlled, cascading Division → District → Sub-district picker
/// backed by `assets/data/locations.json` via [LocationService].
///
/// This is the single widget every location field/filter in the app uses
/// — registration, profile editing, request creation, donor search, and
/// the request feed — so the dataset only has to be wired up once.
///
/// The widget owns no state itself: the parent holds [division]/
/// [district]/[subDistrict] and receives changes through the `on...`
/// callbacks. When a higher-level selection changes, this widget also
/// fires the lower-level callbacks with `null` so the parent clears any
/// now-invalid child selection (e.g. picking a new division clears the
/// previously-selected district).
class LocationSelector extends StatelessWidget {
  const LocationSelector({
    super.key,
    required this.division,
    required this.district,
    required this.onDivisionChanged,
    required this.onDistrictChanged,
    this.subDistrict,
    this.onSubDistrictChanged,
    this.showSubDistrict = true,
    this.allowClear = false,
    this.requiredFields = true,
  });

  final String? division;
  final String? district;
  final String? subDistrict;

  final ValueChanged<String?> onDivisionChanged;
  final ValueChanged<String?> onDistrictChanged;
  final ValueChanged<String?>? onSubDistrictChanged;

  /// Whether to render the third (sub-district) dropdown at all.
  final bool showSubDistrict;

  /// When true, each dropdown gets a leading "All ..." option (value `''`)
  /// so it can represent "no filter selected" — used in search/filter UI.
  /// When false (the default), the dropdown is a plain required field —
  /// used in registration/profile/request forms.
  final bool allowClear;

  /// Adds a "required" form validator to each visible dropdown. Ignored
  /// when [allowClear] is true, since a filter is never truly "required".
  final bool requiredFields;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DivisionModel>>(
      future: LocationService.instance.loadDivisions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final divisionNames = snapshot.data!.map((d) => d.division).toList();
        final districtNames =
            LocationService.instance.districtNamesFor(division);
        final upazilaNames = showSubDistrict
            ? LocationService.instance.upazilaNamesFor(division, district)
            : const <String>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDropdown(
              context: context,
              label: 'Division',
              allLabel: 'All Divisions',
              icon: Icons.map_outlined,
              value: division,
              items: divisionNames,
              enabled: true,
              onChanged: (value) {
                onDivisionChanged(value);
                onDistrictChanged(null);
                onSubDistrictChanged?.call(null);
              },
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              context: context,
              label: 'District',
              allLabel: 'All Districts',
              icon: Icons.location_city_outlined,
              value: district,
              items: districtNames,
              enabled: division != null && division!.isNotEmpty,
              onChanged: (value) {
                onDistrictChanged(value);
                onSubDistrictChanged?.call(null);
              },
            ),
            if (showSubDistrict) ...[
              const SizedBox(height: 16),
              _buildDropdown(
                context: context,
                label: 'Sub-district',
                allLabel: 'All Sub-districts',
                icon: Icons.pin_drop_outlined,
                value: subDistrict,
                items: upazilaNames,
                enabled: district != null && district!.isNotEmpty,
                onChanged: (value) => onSubDistrictChanged?.call(value),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildDropdown({
    required BuildContext context,
    required String label,
    required String allLabel,
    required IconData icon,
    required String? value,
    required List<String> items,
    required bool enabled,
    required ValueChanged<String?> onChanged,
  }) {
    // Guard against a value that no longer belongs to the current item
    // list (e.g. mid-cascade-reset) — Dropdown throws if `value` isn't
    // exactly one of its items.
    final safeValue = (value != null && items.contains(value)) ? value : null;

    final dropdownItems = <DropdownMenuItem<String>>[
      if (allowClear) DropdownMenuItem(value: '', child: Text(allLabel)),
      ...items.map((e) => DropdownMenuItem(value: e, child: Text(e))),
    ];

    return DropdownButtonFormField<String>(
      initialValue: allowClear ? (safeValue ?? '') : safeValue,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        hintText: enabled ? 'Select $label' : 'Select $label above first',
      ),
      items: enabled ? dropdownItems : const [],
      onChanged:
          enabled ? (value) => onChanged(value == '' ? null : value) : null,
      validator: (!allowClear && requiredFields)
          ? (value) =>
              (value == null || value.isEmpty) ? '$label is required' : null
          : null,
      disabledHint: Text(
        'Select $label above first',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      isExpanded: true,
    );
  }
}
