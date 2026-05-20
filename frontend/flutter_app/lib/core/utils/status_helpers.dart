// lib/core/utils/status_helpers.dart

import 'package:flutter/material.dart';

class StatusHelpers {
  // Map dispatch_status to Icon
  static IconData getStatusIcon(String? status) {
    if (status == null) return Icons.help_outline;
    switch (status.toUpperCase()) {
      case 'DISPATCHED':
        return Icons.check_circle_outline;
      case 'PROCESSING':
        return Icons.sync_outlined;
      case 'PENDING':
      case 'PENDING_MANUAL':
        return Icons.hourglass_empty_outlined;
      case 'FAILED':
      case 'INVALID':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline;
    }
  }

  // Map dispatch_status to Display Label
  static String getStatusLabel(String? status) {
    if (status == null) return 'Unknown';
    switch (status.toUpperCase()) {
      case 'DISPATCHED':
        return 'Dispatched';
      case 'PROCESSING':
        return 'Processing';
      case 'PENDING':
        return 'Pending';
      case 'PENDING_MANUAL':
        return 'Pending Manual';
      case 'FAILED':
        return 'Failed';
      case 'INVALID':
        return 'Invalid';
      default:
        return status;
    }
  }

  // Map severity_level to Icon
  static IconData getSeverityIcon(String? level) {
    if (level == null) return Icons.info_outline;
    switch (level.toUpperCase()) {
      case 'CRITICAL':
        return Icons.gpp_maybe;
      case 'HIGH':
        return Icons.warning_amber;
      case 'MEDIUM':
        return Icons.report_problem_outlined;
      case 'LOW':
        return Icons.info_outline;
      default:
        return Icons.info_outline;
    }
  }

  // Map severity_level to Display Label
  static String getSeverityLabel(String? level) {
    if (level == null) return 'Unknown';
    switch (level.toUpperCase()) {
      case 'CRITICAL':
        return 'Critical Emergency';
      case 'HIGH':
        return 'High Urgency';
      case 'MEDIUM':
        return 'Medium Urgency';
      case 'LOW':
        return 'Low Urgency';
      default:
        return level;
    }
  }

  // Map crisis_type to Icon
  static IconData getCrisisTypeIcon(String? type) {
    if (type == null) return Icons.local_hospital_outlined;
    switch (type.toLowerCase()) {
      case 'food':
        return Icons.restaurant_outlined;
      case 'medical':
        return Icons.medical_services_outlined;
      case 'education':
        return Icons.school_outlined;
      case 'emergency_cash':
        return Icons.payments_outlined;
      case 'flood_relief':
        return Icons.water_damage_outlined;
      default:
        return Icons.help_outline;
    }
  }

  // Map crisis_type to Display Label
  static String getCrisisTypeLabel(String? type) {
    if (type == null) return 'General';
    switch (type.toLowerCase()) {
      case 'food':
        return 'Food Assistance';
      case 'medical':
        return 'Medical Emergency';
      case 'education':
        return 'Education Support';
      case 'emergency_cash':
        return 'Emergency Cash';
      case 'flood_relief':
        return 'Flood Relief';
      default:
        return type[0].toUpperCase() + type.substring(1);
    }
  }
}
