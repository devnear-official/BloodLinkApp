import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/localization/app_strings.dart';
import '../../core/services/geolocation_service.dart';
import '../../core/widgets/error_state_view.dart';
import '../../core/widgets/near_me_button.dart';
import '../../models/user_model.dart';
import '../../providers/user_provider.dart';
import '../../providers/favorites_provider.dart';
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
  bool _favoritesOnly = false;
  final _donorsScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _donorsScrollController.addListener(_loadMoreWhenNearEnd);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserProvider>().loadDonors();
    });
  }

  @override
  void dispose() {
    _donorsScrollController.dispose();
    super.dispose();
  }

  void _loadMoreWhenNearEnd() {
    if (!_donorsScrollController.hasClients || _favoritesOnly) return;
    if (_donorsScrollController.position.extentAfter < 320) {
      context.read<UserProvider>().loadMoreDonors();
    }
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
    final colors = Theme.of(context).colorScheme;
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: colors.secondary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.near_me_rounded,
                            size: 16, color: colors.secondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Showing donors near ${userProvider.nearMeLabel}',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        InkWell(
                          onTap: () =>
                              context.read<UserProvider>().clearNearMe(),
                          child: Icon(Icons.close,
                              size: 16, color: colors.secondary),
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
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 18, color: colors.onSurfaceVariant),
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
                          color: colors.onSurfaceVariant,
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
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilterChip(
                    avatar: Icon(
                        _favoritesOnly
                            ? Icons.favorite
                            : Icons.favorite_outline,
                        size: 16),
                    label: Text(
                        _favoritesOnly ? 'Saved donors' : 'Show saved donors'),
                    selected: _favoritesOnly,
                    onSelected: (selected) =>
                        setState(() => _favoritesOnly = selected),
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
    final favorites = context.watch<FavoritesProvider>();
    final strings = AppStrings.of(context);
    final colors = Theme.of(context).colorScheme;
    final donors = _favoritesOnly
        ? userProvider.donors.where((d) => favorites.isFavorite(d.id)).toList()
        : userProvider.donors;
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
    if (donors.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 100),
          Icon(
            _favoritesOnly ? Icons.favorite_border : Icons.people_outline,
            size: 56,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _favoritesOnly
                    ? 'No saved donors yet. Tap the heart on a donor to save them here.'
                    : 'No donors match these filters. Try changing the blood group or location.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      );
    }
    final offlineBannerCount = userProvider.isUsingOfflineCache ? 1 : 0;
    final showFooter = !_favoritesOnly &&
        (userProvider.hasMoreDonors ||
            userProvider.isLoadingMoreDonors ||
            userProvider.appError != null);
    return ListView.builder(
      controller: _donorsScrollController,
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: offlineBannerCount + donors.length + (showFooter ? 1 : 0),
      itemBuilder: (context, index) {
        if (offlineBannerCount == 1 && index == 0) {
          return Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              strings.text('offlineMode'),
              style: TextStyle(
                fontSize: 12,
                color: colors.onSurfaceVariant,
              ),
            ),
          );
        }
        final donorIndex = index - offlineBannerCount;
        if (donorIndex == donors.length) {
          if (userProvider.isLoadingMoreDonors) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (userProvider.appError != null) {
            return TextButton(
              onPressed: userProvider.loadMoreDonors,
              child: const Text('Could not load more donors. Tap to retry.'),
            );
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _loadMoreWhenNearEnd();
          });
          return const SizedBox(height: 1);
        }
        final donor = donors[donorIndex];
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
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: colors.primary,
        labelStyle: TextStyle(
          color: selected ? colors.onPrimary : colors.onSurface,
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: colors.surface,
      ),
    );
  }
}
