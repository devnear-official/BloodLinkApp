import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/widgets/error_state_view.dart';
import '../../models/blood_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/request_service.dart';
import '../request/request_details_screen.dart';

/// "Track Donation History" from the project proposal — every request
/// where the current user's response was accepted, i.e. every time they
/// actually went on to donate.
///
/// This fetches the full, unfiltered request list directly (rather than
/// reusing [RequestProvider], which usually holds a filtered feed) so
/// history isn't affected by whatever filters happen to be active on the
/// main feed tab.
class DonationHistoryScreen extends StatefulWidget {
  const DonationHistoryScreen({super.key});

  @override
  State<DonationHistoryScreen> createState() => _DonationHistoryScreenState();
}

class _DonationHistoryScreenState extends State<DonationHistoryScreen> {
  final _service = RequestService();
  bool _loading = true;
  Object? _error;
  List<BloodRequestModel> _history = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    try {
      final all = await _service.getRequests();
      _history = all.where((request) {
        return request.responses.any(
          (r) => r.donor.id == currentUserId && r.status == 'Accepted',
        );
      }).toList()
        ..sort((a, b) {
          final aDate = a.requiredDate ?? DateTime(2000);
          final bDate = b.requiredDate ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });
    } catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Donation History')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        children: [
          ErrorStateView(error: _error!, onRetry: _load),
        ],
      );
    }
    if (_history.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          Icon(Icons.volunteer_activism_outlined,
              size: 56, color: AppColors.textSecondary),
          SizedBox(height: 12),
          Center(
            child: Text(
              "You haven't donated through BloodLink yet.\n"
              "Accepted donations will show up here.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final request = _history[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RequestDetailsScreen(requestId: request.id),
              ),
            ),
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryLight,
              child: Text(
                request.bloodGroup,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            title: Text(
              request.patientName,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${request.hospitalName} • ${DateFormatter.toShortDate(request.requiredDate)}',
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.statusColor(request.status).withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                request.status,
                style: TextStyle(
                  color: AppColors.statusColor(request.status),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
