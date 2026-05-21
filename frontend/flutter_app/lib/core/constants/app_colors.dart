// lib/core/constants/app_colors.dart

import 'package:flutter/material.dart';

class AppColors {
  // Theme Background & Surface Colors
  static const Color background = Color(0xFF0A0F1E);       // Deep navy bg
  static const Color surface = Color(0xFF111827);          // Dark grey surface
  static const Color surfaceElevated = Color(0xFF1A2235);  // Elevated container surface
  static const Color border = Color(0xFF1E2D45);           // Card/input border

  // Accent & Action Colors
  static const Color primaryAccent = Color(0xFF00C896);    // Action/success green
  static const Color secondary = Color(0xFF38BDF8);        // Info/blue
  static const Color warning = Color(0xFFF59E0B);          // Alert/amber
  static const Color critical = Color(0xFFEF4444);         // Severity critical red

  // Text Colors
  static const Color textPrimary = Color(0xFFF1F5F9);      // Off-white primary text
  static const Color textMuted = Color(0xFF64748B);        // Slate grey muted text

  // Chart Gradient Colors
  static const List<Color> severityGradient = [
    Color(0xFF38BDF8),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
  ];

  // Helper method to map dispatch_status to color
  static Color statusColor(String? status) {
    if (status == null) return textMuted;
    switch (status.toUpperCase()) {
      case 'DISPATCHED':
        return primaryAccent;
      case 'PROCESSING':
        return secondary;
      case 'PENDING':
      case 'PENDING_MANUAL':
        return warning;
      case 'FAILED':
      case 'INVALID':
        return critical;
      default:
        return textMuted;
    }
  }

  // Helper method to map severity_level to color
  static Color severityColor(String? level) {
    if (level == null) return textMuted;
    switch (level.toUpperCase()) {
      case 'CRITICAL':
        return critical;
      case 'HIGH':
        return const Color(0xFFF97316); // High: Deep orange
      case 'MEDIUM':
        return warning;
      case 'LOW':
        return secondary;
      default:
        return textMuted;
    }
  }

  // Helper method to map crisis_type to color
  static Color crisisTypeColor(String? type) {
    if (type == null) return textMuted;
    switch (type.toLowerCase()) {
      case 'food':
        return primaryAccent;
      case 'medical':
        return critical;
      case 'education':
        return secondary;
      case 'emergency_cash':
        return warning;
      case 'flood_relief':
        return const Color(0xFFA855F7); // Purple for flood relief
      default:
        return textMuted;
    }
  }
}
