import 'package:flutter/material.dart';

/// App-wide color palette. Keep every hard-coded color out of widgets and
/// reference this class instead, so the theme stays consistent and easy
/// to tweak in one place.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFE53935); // Crimson / Blood red
  static const Color primaryDark = Color(0xFFB71C1C);
  static const Color primaryLight = Color(0xFFFFCDD2);

  static const Color accent = Color(0xFF00695C); // Dark teal
  static const Color accentLight = Color(0xFF4DB6AC);

  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Colors.white;

  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE5E7EB);

  // Status colors
  static const Color statusPending = Color(0xFFF59E0B);
  static const Color statusAccepted = Color(0xFF2563EB);
  static const Color statusCompleted = Color(0xFF16A34A);
  static const Color statusCancelled = Color(0xFF6B7280);
  static const Color statusRejected = Color(0xFFDC2626);
  static const Color statusDeclined = Color(0xFFDC2626);

  // Priority colors
  static const Color priorityLow = Color(0xFF16A34A);
  static const Color priorityMedium = Color(0xFFF59E0B);
  static const Color priorityHigh = Color(0xFFEA580C);
  static const Color priorityCritical = Color(0xFFDC2626);

  static const Color success = Color(0xFF16A34A);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFF59E0B);

  static Color statusColor(String status) {
    switch (status) {
      case 'Pending':
        return statusPending;
      case 'Accepted':
        return statusAccepted;
      case 'Completed':
        return statusCompleted;
      case 'Cancelled':
        return statusCancelled;
      case 'Rejected':
        return statusRejected;
      case 'Declined':
        return statusDeclined;
      default:
        return textSecondary;
    }
  }

  static Color priorityColor(String priority) {
    switch (priority) {
      case 'Low':
        return priorityLow;
      case 'Medium':
        return priorityMedium;
      case 'High':
        return priorityHigh;
      case 'Critical':
        return priorityCritical;
      default:
        return textSecondary;
    }
  }
}
