// lib/core/models/dashboard_summary.dart

class DashboardSummary {
  final CasesOverview casesOverview;
  final SeverityBreakdown severityBreakdown;
  final VolunteerMetrics volunteerMetrics;
  final PerformanceMetrics performanceMetrics;
  final TimeMetrics timeMetrics;
  final Map<String, int> emergencyTrends;
  final List<RecentCase> recentCriticalCases;
  final List<DashboardVolunteer> volunteerAvailabilityList;

  DashboardSummary({
    required this.casesOverview,
    required this.severityBreakdown,
    required this.volunteerMetrics,
    required this.performanceMetrics,
    required this.timeMetrics,
    required this.emergencyTrends,
    required this.recentCriticalCases,
    required this.volunteerAvailabilityList,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    Map<String, int> parseTrends(dynamic val) {
      if (val == null || val is! Map) return {};
      return val.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    }

    List<RecentCase> parseCases(dynamic val) {
      if (val == null || val is! List) return [];
      return val.map((e) => RecentCase.fromJson(e)).toList();
    }
    
    List<DashboardVolunteer> parseVols(dynamic val) {
      if (val == null || val is! List) return [];
      return val.map((e) => DashboardVolunteer.fromJson(e)).toList();
    }

    return DashboardSummary(
      casesOverview: CasesOverview.fromJson(json['cases_overview'] ?? {}),
      severityBreakdown: SeverityBreakdown.fromJson(json['severity_breakdown'] ?? {}),
      volunteerMetrics: VolunteerMetrics.fromJson(json['volunteer_metrics'] ?? {}),
      performanceMetrics: PerformanceMetrics.fromJson(json['performance_metrics'] ?? {}),
      timeMetrics: TimeMetrics.fromJson(json['time_metrics'] ?? {}),
      emergencyTrends: parseTrends(json['emergency_trends'] ?? json['crisis_type_counts']),
      recentCriticalCases: parseCases(json['recent_critical_cases']),
      volunteerAvailabilityList: parseVols(json['volunteer_availability_list']),
    );
  }

  factory DashboardSummary.empty() {
    return DashboardSummary(
      casesOverview: CasesOverview(totalAssigned: 0, active: 0, dispatched: 0, pending: 0, resolved: 0, rejected: 0),
      severityBreakdown: SeverityBreakdown(critical: 0, high: 0, medium: 0, low: 0),
      volunteerMetrics: VolunteerMetrics(totalVolunteers: 0, available: 0, busy: 0),
      performanceMetrics: PerformanceMetrics(responseRatePercentage: 0.0, averageResolutionTimeHours: 0.0),
      timeMetrics: TimeMetrics(todayCases: 0, yesterdayCases: 0, weeklyCases: 0, lastWeekCases: 0, monthlyCases: 0, lastMonthCases: 0, dailyIntake: []),
      emergencyTrends: {},
      recentCriticalCases: [],
      volunteerAvailabilityList: [],
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
  final int yesterdayCases;
  final int weeklyCases;
  final int lastWeekCases;
  final int monthlyCases;
  final int lastMonthCases;
  final List<int> dailyIntake;

  TimeMetrics({
    required this.todayCases,
    required this.yesterdayCases,
    required this.weeklyCases,
    required this.lastWeekCases,
    required this.monthlyCases,
    required this.lastMonthCases,
    required this.dailyIntake,
  });

  factory TimeMetrics.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic v) => (v is num) ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0;
    
    List<int> parseIntList(dynamic val) {
      if (val == null || val is! List) return [];
      return val.map((e) => parseInt(e)).toList();
    }

    return TimeMetrics(
      todayCases: parseInt(json['today_cases']),
      yesterdayCases: parseInt(json['yesterday_cases']),
      weeklyCases: parseInt(json['weekly_cases']),
      lastWeekCases: parseInt(json['last_week_cases']),
      monthlyCases: parseInt(json['monthly_cases']),
      lastMonthCases: parseInt(json['last_month_cases']),
      dailyIntake: parseIntList(json['daily_intake']),
    );
  }
}

class RecentCase {
  final String applicant;
  final String crisis;
  final double score;
  final String status;
  final String location;

  RecentCase({
    required this.applicant,
    required this.crisis,
    required this.score,
    required this.status,
    required this.location,
  });

  factory RecentCase.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic v) => (v is num) ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
    return RecentCase(
      applicant: json['applicant']?.toString() ?? 'Unknown',
      crisis: json['crisis']?.toString() ?? 'Unknown',
      score: parseDouble(json['score']),
      status: json['status']?.toString() ?? 'Unknown',
      location: json['location']?.toString() ?? 'Unknown',
    );
  }
}

class DashboardVolunteer {
  final String name;
  final String location;
  final bool isAvailable;

  DashboardVolunteer({
    required this.name,
    required this.location,
    required this.isAvailable,
  });

  factory DashboardVolunteer.fromJson(Map<String, dynamic> json) {
    return DashboardVolunteer(
      name: json['name']?.toString() ?? 'Unknown',
      location: json['location']?.toString() ?? 'Unknown',
      isAvailable: json['is_available'] == true,
    );
  }
}
