import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/error_state_view.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/request_provider.dart';
import '../direct_request/direct_requests_screen.dart';
import '../donor/search_donor_screen.dart';
import '../nearby/nearby_donors_screen.dart';
import '../notification/notifications_screen.dart';
import '../request/create_request_screen.dart';
import '../request/request_details_screen.dart';
import '../shared/location_selector.dart';
import 'widgets/app_drawer.dart';
import 'widgets/request_card.dart';

/// Main authenticated shell. A single persistent Scaffold owns:
/// - a left-side [AppDrawer] (hamburger menu) with profile / admin / sign-out
/// - a top app bar with a notification bell (badge) that opens the full
///   notifications list
/// - a 4-item bottom nav for the request feed, donor search, nearby donor
///   detection, and direct requests
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _tabs;

  final List<String> _titles = const [
    'Blood Requests',
    'Search Donors',
    'Find Nearby',
    'Direct Requests',
  ];

  @override
  void initState() {
    super.initState();
    _tabs = [
      _RequestFeedTab(onSelectTab: _selectTab),
      const SearchDonorScreen(),
      const NearbyDonorsScreen(),
      const DirectRequestsScreen(),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  void _selectTab(int index) {
    setState(() => _currentIndex = index);
  }

  void _openNotifications() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: AppDrawer(
        currentIndex: _currentIndex,
        onSelectTab: (index) => setState(() => _currentIndex = index),
      ),
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 8,
        title: _currentIndex == 0
            ? Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.bloodtype_rounded,
                      color: AppColors.primary,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'BloodLink',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                ],
              )
            : Text(
                _titles[_currentIndex],
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) => Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                tooltip: 'Notifications',
                onPressed: _openNotifications,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                  fixedSize: const Size(44, 44),
                ),
                icon: Badge(
                  isLabelVisible: provider.unreadCount > 0,
                  label: Text('${provider.unreadCount}'),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.surface,
        elevation: 8,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.bloodtype_outlined),
            selectedIcon: Icon(Icons.bloodtype),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Donors',
          ),
          NavigationDestination(
            icon: Icon(Icons.near_me_outlined),
            selectedIcon: Icon(Icons.near_me),
            label: 'Nearby',
          ),
          NavigationDestination(
            icon: Icon(Icons.send_outlined),
            selectedIcon: Icon(Icons.send),
            label: 'Direct',
          ),
        ],
      ),
    );
  }
}

/// Tab 0: the open blood-request feed with district/blood-group filters.
class _RequestFeedTab extends StatefulWidget {
  const _RequestFeedTab({required this.onSelectTab});

  final ValueChanged<int> onSelectTab;

  @override
  State<_RequestFeedTab> createState() => _RequestFeedTabState();
}

class _RequestFeedTabState extends State<_RequestFeedTab> {
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RequestProvider>().loadRequests();
    });
  }

  static const List<String> _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();
    final user = context.watch<AuthProvider>().currentUser;
    final hasLocationFilter = provider.divisionFilter.isNotEmpty ||
        provider.districtFilter.isNotEmpty;

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => context.read<RequestProvider>().loadRequests(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _greeting(),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user?.name.split(' ').first ?? 'there',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 27,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _EmergencyHero(
                      openRequestCount: provider.requests
                          .where((request) => request.isOpen)
                          .length,
                      onCreateRequest: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CreateRequestScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.manage_search_rounded,
                            label: 'Find donors',
                            caption: 'Search by blood type',
                            color: const Color(0xFFEAF2FF),
                            iconColor: const Color(0xFF3469C8),
                            onTap: () => widget.onSelectTab(1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickActionCard(
                            icon: Icons.near_me_rounded,
                            label: 'Nearby',
                            caption: 'Donors around you',
                            color: const Color(0xFFE9F6F1),
                            iconColor: const Color(0xFF23856B),
                            onTap: () => widget.onSelectTab(2),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Community requests',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        Text(
                          '${provider.requests.length} found',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _LocationFilter(
                      label: hasLocationFilter
                          ? [
                              provider.divisionFilter,
                              provider.districtFilter,
                            ].where((value) => value.isNotEmpty).join(' · ')
                          : 'Everywhere',
                      isExpanded: _filtersExpanded,
                      onTap: () => setState(
                        () => _filtersExpanded = !_filtersExpanded,
                      ),
                    ),
                    if (_filtersExpanded)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: LocationSelector(
                          division: provider.divisionFilter.isEmpty
                              ? null
                              : provider.divisionFilter,
                          district: provider.districtFilter.isEmpty
                              ? null
                              : provider.districtFilter,
                          showSubDistrict: false,
                          allowClear: true,
                          onDivisionChanged: (value) => context
                              .read<RequestProvider>()
                              .setDivisionFilter(value ?? ''),
                          onDistrictChanged: (value) => context
                              .read<RequestProvider>()
                              .setDistrictFilter(value ?? ''),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _Chip(
                            label: 'All groups',
                            selected: provider.bloodGroupFilter.isEmpty,
                            onTap: () => context
                                .read<RequestProvider>()
                                .setBloodGroupFilter(''),
                          ),
                          ..._bloodGroups.map(
                            (group) => _Chip(
                              label: group,
                              selected: provider.bloodGroupFilter == group,
                              onTap: () => context
                                  .read<RequestProvider>()
                                  .setBloodGroupFilter(group),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ..._requestSlivers(provider),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  List<Widget> _requestSlivers(RequestProvider provider) {
    if (provider.isLoading && provider.requests.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (provider.appError != null && provider.requests.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: ErrorStateViewFromAppError(
            appError: provider.appError!,
            onRetry: () => context.read<RequestProvider>().loadRequests(),
          ),
        ),
      ];
    }
    if (provider.requests.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: _EmptyRequestsState(),
        ),
      ];
    }
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final request = provider.requests[index];
            return RequestCard(
              request: request,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RequestDetailsScreen(requestId: request.id),
                ),
              ),
            );
          },
          childCount: provider.requests.length,
        ),
      ),
    ];
  }
}

class _EmergencyHero extends StatelessWidget {
  const _EmergencyHero({
    required this.openRequestCount,
    required this.onCreateRequest,
  });

  final int openRequestCount;
  final VoidCallback onCreateRequest;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFB92835), Color(0xFF791D2D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF9C2432).withValues(alpha: 0.2),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -26,
            top: -34,
            child: Container(
              width: 156,
              height: 156,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1), width: 26),
              ),
            ),
          ),
          Positioned(
            right: 47,
            bottom: -72,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 9),
                    const Text(
                      'BE SOMEONE’S HERO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFFFD58A),
                      size: 19,
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                const Text(
                  'A little help can\nsave a life.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    height: 1.12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  openRequestCount == 0
                      ? 'Be ready to answer the next call.'
                      : '$openRequestCount people are waiting for a donor.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 17),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: onCreateRequest,
                    borderRadius: BorderRadius.circular(14),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            color: Color(0xFF9C2432),
                            size: 18,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Create a request',
                            style: TextStyle(
                              color: Color(0xFF86212E),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.caption,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String caption;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios_rounded, size: 12, color: iconColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationFilter extends StatelessWidget {
  const _LocationFilter({
    required this.label,
    required this.isExpanded,
    required this.onTap,
  });

  final String label;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppColors.primary,
                size: 19,
              ),
              const SizedBox(width: 9),
              const Text(
                'Location',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(
                isExpanded ? Icons.expand_less_rounded : Icons.tune_rounded,
                color: AppColors.textSecondary,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyRequestsState extends StatelessWidget {
  const _EmptyRequestsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 24, 30, 40),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.volunteer_activism_rounded,
              color: AppColors.primary,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'All quiet for now',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'No blood requests match these filters. Check back soon or help someone by creating a request.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.label, required this.selected, required this.onTap});
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
