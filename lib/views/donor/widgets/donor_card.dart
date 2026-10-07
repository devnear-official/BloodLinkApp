import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../models/user_model.dart';

/// Compact card summarizing a donor for the search results list, with a
/// "Send Direct Request" action.
class DonorCard extends StatelessWidget {
  const DonorCard({
    super.key,
    required this.donor,
    required this.onSendRequest,
  });

  final UserModel donor;
  final VoidCallback onSendRequest;

  @override
  Widget build(BuildContext context) {
    final eligible = donor.isEligibleToDonate;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primaryLight,
              backgroundImage:
                  donor.photoUrl != null ? NetworkImage(donor.photoUrl!) : null,
              child: donor.photoUrl == null
                  ? Text(
                      donor.bloodGroup ?? '?',
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    donor.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${donor.district ?? "—"}, ${donor.division ?? "—"}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        eligible ? Icons.check_circle : Icons.access_time,
                        size: 14,
                        color: eligible ? AppColors.success : AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          eligible
                              ? 'Ready to donate'
                              : donor.lastDonation == null
                                  ? 'Unavailable'
                                  : 'Eligible in ${donor.daysUntilEligible} days',
                          style: TextStyle(
                            fontSize: 12,
                            color: eligible
                                ? AppColors.success
                                : AppColors.warning,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (donor.lastDonation != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        'Last donated ${DateFormatter.toShortDate(donor.lastDonation)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    donor.bloodGroup ?? '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                IconButton(
                  tooltip: 'Send Direct Request',
                  onPressed: onSendRequest,
                  icon: const Icon(Icons.send_outlined),
                  color: AppColors.accent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
