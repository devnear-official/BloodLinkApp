import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/date_formatter.dart';
import '../../models/blood_request_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/request_provider.dart';
import '../../core/widgets/error_state_view.dart';
import '../../core/widgets/responsive_content.dart';
import 'create_request_screen.dart' show kPriorities;

/// Shows full details of a single blood request, including the list of
/// donor responses. This is the "responder goes back to the requester"
/// loop: donors respond here, and the request's creator accepts/rejects
/// each response from this same screen.
class RequestDetailsScreen extends StatefulWidget {
  const RequestDetailsScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<RequestDetailsScreen> createState() => _RequestDetailsScreenState();
}

class _RequestDetailsScreenState extends State<RequestDetailsScreen> {
  bool _loadingRequest = true;
  bool _requestNotFound = false;

  @override
  void initState() {
    super.initState();
    // Handles the case where this screen is opened directly (e.g. from a
    // notification) before the request feed has ever been loaded.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadRequest());
  }

  Future<void> _loadRequest() async {
    final found =
        await context.read<RequestProvider>().ensureLoaded(widget.requestId);
    if (!mounted) return;
    setState(() {
      _loadingRequest = false;
      _requestNotFound = !found;
    });
  }

  @override
  Widget build(BuildContext context) {
    final requestProvider = context.watch<RequestProvider>();
    final currentUser = context.watch<AuthProvider>().currentUser;
    final colors = Theme.of(context).colorScheme;
    final requestId = widget.requestId;

    final found = requestProvider.requests.any((r) => r.id == requestId);
    if (!found && _loadingRequest) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!found && requestProvider.appError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request Details')),
        body: SafeArea(
          child: ErrorStateViewFromAppError(
            appError: requestProvider.appError!,
            onRetry: () {
              setState(() {
                _loadingRequest = true;
                _requestNotFound = false;
              });
              _loadRequest();
            },
          ),
        ),
      );
    }
    if (!found && _requestNotFound) {
      return Scaffold(
        appBar: AppBar(title: const Text('Request Details')),
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'This blood request is no longer available.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    final request = requestProvider.requests.firstWhere(
      (r) => r.id == requestId,
      orElse: () => BloodRequestModel(
        id: requestId,
        patientName: 'Unknown',
        bloodGroup: '',
        hospitalName: '',
        contactNumber: '',
        division: '',
        district: '',
      ),
    );

    final isOwner = currentUser != null &&
        request.createdBy != null &&
        request.createdBy!.id == currentUser.id;

    final alreadyResponded = currentUser != null &&
        request.responses.any((r) => r.donor.id == currentUser.id);

    final canRespond = currentUser != null &&
        !isOwner &&
        !alreadyResponded &&
        request.isOpen &&
        currentUser.isEligibleToDonate;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Request Details'),
        actions: [
          if (isOwner)
            PopupMenuButton<String>(
              onSelected: (value) async {
                final provider = context.read<RequestProvider>();
                if (value == 'delete') {
                  final confirmed = await _confirmDelete(context);
                  if (!mounted || confirmed != true) return;
                  final ok = await provider.deleteRequest(request.id);
                  if (mounted && ok) Navigator.of(this.context).pop();
                } else if (value == 'complete') {
                  provider.updateStatus(
                    request.id,
                    'Completed',
                  );
                } else if (value == 'cancel') {
                  provider.updateStatus(
                    request.id,
                    'Cancelled',
                  );
                } else if (kPriorities.contains(value)) {
                  provider.updatePriority(
                    request.id,
                    value,
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'complete',
                  child: Text('Mark as Completed'),
                ),
                const PopupMenuItem(
                  value: 'cancel',
                  child: Text('Cancel Request'),
                ),
                const PopupMenuDivider(),
                ...kPriorities.map(
                  (p) => PopupMenuItem(value: p, child: Text('Priority: $p')),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    'Delete Request',
                    style: TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContent(
          maxWidth: 900,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _buildHeader(request),
              const SizedBox(height: 20),
              _buildInfoCard(request),
              const SizedBox(height: 20),
              if (canRespond) _buildRespondButton(context, request),
              if (alreadyResponded && !isOwner)
                _InfoBanner(
                  icon: Icons.check_circle_outline,
                  text: "You've already responded to this request.",
                  color: colors.secondary,
                ),
              if (currentUser != null &&
                  !isOwner &&
                  !currentUser.isEligibleToDonate &&
                  request.isOpen)
                _InfoBanner(
                  icon: Icons.access_time,
                  text: currentUser.lastDonation == null
                      ? "You're currently marked unavailable to donate."
                      : "You'll be eligible to donate again in ${currentUser.daysUntilEligible} days.",
                  color: AppColors.warning,
                ),
              const SizedBox(height: 24),
              if (isOwner &&
                  !request.isOpen &&
                  request.responses.any((r) => r.status == 'Accepted'))
                _InfoBanner(
                  icon: Icons.lock_outline,
                  text:
                      'This request is locked — a donor has already been accepted, '
                      'and any other pending offers were automatically declined.',
                  color: colors.secondary,
                ),
              Text(
                'Donor Responses (${request.responses.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              if (request.responses.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No donors have responded yet',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ...request.responses.map(
                  (response) => _ResponseTile(
                    response: response,
                    isOwner: isOwner,
                    requestLocked: !request.isOpen,
                    onAccept: () =>
                        context.read<RequestProvider>().acceptDonorResponse(
                              requestId: request.id,
                              donorId: response.donor.id,
                            ),
                    onReject: () =>
                        context.read<RequestProvider>().setResponseStatus(
                              requestId: request.id,
                              donorId: response.donor.id,
                              status: 'Rejected',
                            ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Request?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child:
                const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BloodRequestModel request) {
    return Row(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.primary,
          child: Text(
            request.bloodGroup,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                request.patientName,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                children: [
                  _StatusChip(
                    label: request.status,
                    color: AppColors.statusColor(request.status),
                  ),
                  _StatusChip(
                    label: request.priority,
                    color: AppColors.priorityColor(request.priority),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(BloodRequestModel request) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _InfoRow(
                icon: Icons.local_hospital_outlined,
                label: 'Hospital',
                value: request.hospitalName),
            _InfoRow(
                icon: Icons.phone_outlined,
                label: 'Contact',
                value: request.contactNumber),
            _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: '${request.district}, ${request.division}'),
            _InfoRow(
                icon: Icons.event_outlined,
                label: 'Needed by',
                value: DateFormatter.toShortDate(request.requiredDate)),
            if (request.createdBy != null)
              _InfoRow(
                  icon: Icons.person_outline,
                  label: 'Posted by',
                  value: request.createdBy!.name),
            if (request.message != null && request.message!.isNotEmpty)
              _InfoRow(
                  icon: Icons.message_outlined,
                  label: 'Message',
                  value: request.message!),
          ],
        ),
      ),
    );
  }

  Widget _buildRespondButton(BuildContext context, BloodRequestModel request) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: const Icon(Icons.volunteer_activism),
        label: const Text("I Can Donate"),
        onPressed: () async {
          final provider = context.read<RequestProvider>();
          final success = await provider.respondToRequest(request.id);
          if (!context.mounted) return;
          final error = provider.errorMessage;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? 'Response sent to the requester'
                    : (error ?? 'Failed to respond'),
              ),
              backgroundColor: success ? AppColors.success : AppColors.error,
            ),
          );
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: colors.onSurfaceVariant),
          const SizedBox(width: 10),
          SizedBox(
            width: 90,
            child: Text(label,
                style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner(
      {required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
              child: Text(text, style: TextStyle(color: color, fontSize: 13))),
        ],
      ),
    );
  }
}

class _ResponseTile extends StatelessWidget {
  const _ResponseTile({
    required this.response,
    required this.isOwner,
    required this.requestLocked,
    required this.onAccept,
    required this.onReject,
  });

  final DonorResponse response;
  final bool isOwner;
  final bool requestLocked;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: colors.primaryContainer,
                  child: Text(
                    response.donor.bloodGroup ?? '?',
                    style: TextStyle(
                        color: colors.onPrimaryContainer, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(response.donor.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        DateFormatter.timeAgo(response.respondedAt),
                        style: TextStyle(
                            fontSize: 11, color: colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                _StatusChip(
                  label: response.status,
                  color: AppColors.statusColor(response.status),
                ),
              ],
            ),
            if (isOwner && !requestLocked && response.status == 'Pending') ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onReject,
                      style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onAccept,
                      child: const Text('Accept'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
