import 'package:flutter/material.dart';

/// App-wide color palette. Keep every hard-coded color out of widgets and
/// reference this class instead, so the theme stays consistent and easy
/// to tweak in one place.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFB3263D);
  static const Color primaryDark = Color(0xFF861B2D);
  static const Color primaryLight = Color(0xFFF7E2E6);

  static const Color accent = Color(0xFF187C70);
  static const Color accentLight = Color(0xFF55A99B);

  static const Color background = Color(0xFFF5F6F8);
  static const Color surface = Colors.white;

  static const Color textPrimary = Color(0xFF222934);
  static const Color textSecondary = Color(0xFF68717F);
  static const Color divider = Color(0xFFE5E8ED);

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
    switch (status.toLowerCase()) {
      case 'pending':
      case 'active':
        return statusPending;
      case 'accepted':
        return statusAccepted;
      case 'completed':
      case 'fulfilled':
        return statusCompleted;
      case 'cancelled':
        return statusCancelled;
      case 'rejected':
        return statusRejected;
      case 'declined':
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
