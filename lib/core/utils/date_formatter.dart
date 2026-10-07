import 'package:intl/intl.dart';

/// Small collection of date helpers used across the UI so formatting stays
/// consistent (e.g. request dates, "last donated" text, notification
/// timestamps).
class DateFormatter {
  DateFormatter._();

  static final DateFormat _shortDate = DateFormat('MMM d, yyyy');
  static final DateFormat _shortDateTime = DateFormat('MMM d, yyyy • h:mm a');

  static String toShortDate(DateTime? date) {
    if (date == null) return '—';
    return _shortDate.format(date);
  }

  static String toShortDateTime(DateTime? date) {
    if (date == null) return '—';
    return _shortDateTime.format(date);
  }

  /// Renders a relative "time ago" string (e.g. "3h ago", "2d ago") for
  /// notification feeds.
  static String timeAgo(DateTime? date) {
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return _shortDate.format(date);
  }

  /// Number of whole days since [lastDonation], or null if the donor has
  /// never donated.
  static int? daysSince(DateTime? lastDonation) {
    if (lastDonation == null) return null;
    return DateTime.now().difference(lastDonation).inDays;
  }
}
