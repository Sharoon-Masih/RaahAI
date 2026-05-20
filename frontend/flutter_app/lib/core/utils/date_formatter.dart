// lib/core/utils/date_formatter.dart

import 'package:intl/intl.dart';

class DateFormatter {
  // Format ISO-8601 string to a clean readable date-time representation
  static String formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'N/A';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      return DateFormat('MMM dd, yyyy - hh:mm a').format(dateTime);
    } catch (_) {
      return isoString;
    }
  }

  // Format ISO-8601 to date only
  static String formatDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'N/A';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      return DateFormat('dd MMM yyyy').format(dateTime);
    } catch (_) {
      return isoString;
    }
  }

  // Convert an ISO-8601 string to a "time ago" string (e.g. "3 mins ago", "Yesterday")
  static String formatTimeAgo(String? isoString) {
    if (isoString == null || isoString.isEmpty) return 'Just now';
    try {
      final dateTime = DateTime.parse(isoString).toLocal();
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inSeconds < 60) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        final count = difference.inMinutes;
        return '$count ${count == 1 ? 'min' : 'mins'} ago';
      } else if (difference.inHours < 24) {
        final count = difference.inHours;
        return '$count ${count == 1 ? 'hr' : 'hrs'} ago';
      } else if (difference.inDays < 7) {
        final count = difference.inDays;
        return '$count ${count == 1 ? 'day' : 'days'} ago';
      } else {
        return DateFormat('dd MMM').format(dateTime);
      }
    } catch (_) {
      return 'N/A';
    }
  }
}
