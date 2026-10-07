import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/widgets/error_state_view.dart';
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

  final List<Widget> _tabs = const [
    _RequestFeedTab(),
    SearchDonorScreen(),
    NearbyDonorsScreen(),
    DirectRequestsScreen(),
  ];

  final List<String> _titles = const [
    'Blood Requests',
    'Search Donors',
    'Find Nearby',
    'Direct Requests',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
    });
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
        title: Text(_titles[_currentIndex]),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) => IconButton(
              tooltip: 'Notifications',
              onPressed: _openNotifications,
              icon: Badge(
                isLabelVisible: provider.unreadCount > 0,
                label: Text('${provider.unreadCount}'),
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: IndexedStack(index: _currentIndex, children: _tabs),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateRequestScreen()),
                );
              },
              icon: const Icon(Icons.add),
              label: const Text('New Request'),
              backgroundColor: AppColors.primary,
            )
          : null,
      bottomNavigationBar: NavigationBar(
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
  const _RequestFeedTab();

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
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-',
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RequestProvider>();
    final hasLocationFilter = provider.divisionFilter.isNotEmpty ||
        provider.districtFilter.isNotEmpty;

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
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
                                    provider.divisionFilter,
                                    provider.districtFilter,
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
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _Chip(
                        label: 'All groups',
                        selected: provider.bloodGroupFilter.isEmpty,
                        onTap: () =>
                            context.read<RequestProvider>().setBloodGroupFilter(''),
                      ),
                      ..._bloodGroups.map(
                        (bg) => _Chip(
                          label: bg,
                          selected: provider.bloodGroupFilter == bg,
                          onTap: () => context
                              .read<RequestProvider>()
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
              onRefresh: () => context.read<RequestProvider>().loadRequests(),
              child: _buildList(provider),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(RequestProvider provider) {
    if (provider.isLoading && provider.requests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.appError != null && provider.requests.isEmpty) {
      return ListView(
        children: [
          ErrorStateViewFromAppError(
            appError: provider.appError!,
            onRetry: () => context.read<RequestProvider>().loadRequests(),
          ),
        ],
      );
    }
    if (provider.requests.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Icon(Icons.bloodtype_outlined, size: 56, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Center(child: Text('No blood requests right now')),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 90),
      itemCount: provider.requests.length,
      itemBuilder: (context, index) {
        final request = provider.requests[index];
        return RequestCard(
          request: request,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RequestDetailsScreen(requestId: request.id),
              ),
            );
          },
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
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
