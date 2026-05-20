// lib/core/models/dashboard_summary.dart

class DashboardSummary {
  final CasesOverview casesOverview;
  final SeverityBreakdown severityBreakdown;
  final VolunteerMetrics volunteerMetrics;
  final PerformanceMetrics performanceMetrics;
  final TimeMetrics timeMetrics;
  final Map<String, int> emergencyTrends;

  DashboardSummary({
    required this.casesOverview,
    required this.severityBreakdown,
    required this.volunteerMetrics,
    required this.performanceMetrics,
    required this.timeMetrics,
    required this.emergencyTrends,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    Map<String, int> parseTrends(dynamic val) {
      if (val == null || val is! Map) return {};
      return val.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    }

    return DashboardSummary(
      casesOverview: CasesOverview.fromJson(json['cases_overview'] ?? {}),
      severityBreakdown: SeverityBreakdown.fromJson(json['severity_breakdown'] ?? {}),
      volunteerMetrics: VolunteerMetrics.fromJson(json['volunteer_metrics'] ?? {}),
      performanceMetrics: PerformanceMetrics.fromJson(json['performance_metrics'] ?? {}),
      timeMetrics: TimeMetrics.fromJson(json['time_metrics'] ?? {}),
      emergencyTrends: parseTrends(json['emergency_trends']),
    );
  }

  factory DashboardSummary.empty() {
    return DashboardSummary(
      casesOverview: CasesOverview(totalAssigned: 0, active: 0, dispatched: 0, pending: 0, resolved: 0, rejected: 0),
      severityBreakdown: SeverityBreakdown(critical: 0, high: 0, medium: 0, low: 0),
      volunteerMetrics: VolunteerMetrics(totalVolunteers: 0, available: 0, busy: 0),
      performanceMetrics: PerformanceMetrics(responseRatePercentage: 0.0, averageResolutionTimeHours: 0.0),
      timeMetrics: TimeMetrics(todayCases: 0, weeklyCases: 0, monthlyCases: 0),
      emergencyTrends: {},
    );
  }
}

class CasesOverview {
  final int totalAssigned;
  final int active;
  final int dispatched;
  final int pending;
  final int resolved;
  final int rejected;

  CasesOverview({
    required this.totalAssigned,
    required this.active,
    required this.dispatched,
    required this.pending,
    required this.resolved,
    required this.rejected,
  });

  factory CasesOverview.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) => (v is num) ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    return CasesOverview(
      totalAssigned: parseInt(json['total_assigned']),
      active: parseInt(json['active']),
      dispatched: parseInt(json['dispatched']),
      pending: parseInt(json['pending']),
      resolved: parseInt(json['resolved']),
      rejected: parseInt(json['rejected']),
    );
  }
}

class SeverityBreakdown {
  final int critical;
  final int high;
  final int medium;
  final int low;

  SeverityBreakdown({
    required this.critical,
    required this.high,
    required this.medium,
    required this.low,
  });

  factory SeverityBreakdown.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) => (v is num) ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    return SeverityBreakdown(
      critical: parseInt(json['critical']),
      high: parseInt(json['high']),
      medium: parseInt(json['medium']),
      low: parseInt(json['low']),
    );
  }
}

class VolunteerMetrics {
  final int totalVolunteers;
  final int available;
  final int busy;

  VolunteerMetrics({
    required this.totalVolunteers,
    required this.available,
    required this.busy,
  });

  factory VolunteerMetrics.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) => (v is num) ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    return VolunteerMetrics(
      totalVolunteers: parseInt(json['total_volunteers']),
      available: parseInt(json['available']),
      busy: parseInt(json['busy']),
    );
  }
}

class PerformanceMetrics {
  final double responseRatePercentage;
  final double averageResolutionTimeHours;

  PerformanceMetrics({
    required this.responseRatePercentage,
    required this.averageResolutionTimeHours,
  });

  factory PerformanceMetrics.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic v) => (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
    return PerformanceMetrics(
      responseRatePercentage: parseDouble(json['response_rate_percentage']),
      averageResolutionTimeHours: parseDouble(json['average_resolution_time_hours']),
    );
  }
}

class TimeMetrics {
  final int todayCases;
  final int weeklyCases;
  final int monthlyCases;

  TimeMetrics({
    required this.todayCases,
    required this.weeklyCases,
    required this.monthlyCases,
  });

  factory TimeMetrics.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) => (v is num) ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    return TimeMetrics(
      todayCases: parseInt(json['today_cases']),
      weeklyCases: parseInt(json['weekly_cases']),
      monthlyCases: parseInt(json['monthly_cases']),
    );
  }
}
