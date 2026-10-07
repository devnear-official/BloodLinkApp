import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/geolocation_service.dart';
import '../../core/widgets/error_state_view.dart';
import '../../core/widgets/near_me_button.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../auth/register_screen.dart' show kBloodGroups;
import '../direct_request/send_direct_request_screen.dart';
import '../shared/location_selector.dart';
import 'widgets/donor_card.dart';

/// Donor search tab content. This is embedded inside [HomeScreen]'s
/// bottom-nav body, so it deliberately has no Scaffold/AppBar of its own —
/// the shell provides those (including the drawer and notification bell).
class SearchDonorScreen extends StatefulWidget {
  const SearchDonorScreen({super.key});

  @override
  State<SearchDonorScreen> createState() => _SearchDonorScreenState();
}

class _SearchDonorScreenState extends State<SearchDonorScreen> {
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadDonors();
    });
  }

  void _openSendRequest(UserModel donor) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SendDirectRequestScreen(donor: donor),
      ),
    );
  }

  void _onLocationDetected(DetectedLocation location) {
    context.read<UserProvider>().applyDetectedLocation(
          division: location.division ?? '',
          district: location.district ?? '',
          subDistrict: location.subDistrict ?? '',
          label: [location.subDistrict, location.district, location.division]
              .where((s) => s != null && s.isNotEmpty)
              .join(', '),
        );
    setState(() => _filtersExpanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final userProvider = context.watch<UserProvider>();
    final hasLocationFilter = userProvider.divisionFilter.isNotEmpty ||
        userProvider.districtFilter.isNotEmpty ||
        userProvider.subDistrictFilter.isNotEmpty;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                if (userProvider.nearMeLabel != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.near_me_rounded,
                            size: 16, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Showing donors near ${userProvider.nearMeLabel}',
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
                          onTap: () => context.read<UserProvider>().clearNearMe(),
                          child: const Icon(Icons.close,
                              size: 16, color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: NearMeButton(onDetected: _onLocationDetected),
                ),
                const SizedBox(height: 10),
                InkWell(
                  onTap: () =>
                      setState(() => _filtersExpanded = !_filtersExpanded),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            hasLocationFilter
                                ? [
                                    userProvider.divisionFilter,
                                    userProvider.districtFilter,
                                    userProvider.subDistrictFilter,
                                  ].where((s) => s.isNotEmpty).join(' • ')
                                : 'Filter by location',
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          _filtersExpanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_filtersExpanded)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: LocationSelector(
                      division: userProvider.divisionFilter.isEmpty
                          ? null
                          : userProvider.divisionFilter,
                      district: userProvider.districtFilter.isEmpty
                          ? null
                          : userProvider.districtFilter,
                      subDistrict: userProvider.subDistrictFilter.isEmpty
                          ? null
                          : userProvider.subDistrictFilter,
                      allowClear: true,
                      onDivisionChanged: (value) => context
                          .read<UserProvider>()
                          .setDivisionFilter(value ?? ''),
                      onDistrictChanged: (value) => context
                          .read<UserProvider>()
                          .setDistrictFilter(value ?? ''),
                      onSubDistrictChanged: (value) => context
                          .read<UserProvider>()
                          .setSubDistrictFilter(value ?? ''),
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'All groups',
                        selected: userProvider.bloodGroupFilter.isEmpty,
                        onTap: () => context
                            .read<UserProvider>()
                            .setBloodGroupFilter(''),
                      ),
                      ...kBloodGroups.map(
                        (bg) => _FilterChip(
                          label: bg,
                          selected: userProvider.bloodGroupFilter == bg,
                          onTap: () => context
                              .read<UserProvider>()
                              .setBloodGroupFilter(bg),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<UserProvider>().loadDonors(),
              child: _buildBody(userProvider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(UserProvider userProvider) {
    if (userProvider.isLoading && userProvider.donors.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (userProvider.appError != null && userProvider.donors.isEmpty) {
      return ListView(
        children: [
          ErrorStateViewFromAppError(
            appError: userProvider.appError!,
            onRetry: () => context.read<UserProvider>().loadDonors(),
          ),
        ],
      );
    }
    if (userProvider.donors.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Icon(Icons.people_outline, size: 56, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Center(child: Text('No available donors found')),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: userProvider.donors.length,
      itemBuilder: (context, index) {
        final donor = userProvider.donors[index];
        return DonorCard(
          donor: donor,
          onSendRequest: () => _openSendRequest(donor),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: AppColors.surface,
      ),
    );
  }
}
