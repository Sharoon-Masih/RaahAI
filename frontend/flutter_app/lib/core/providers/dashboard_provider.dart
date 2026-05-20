// lib/core/providers/dashboard_provider.dart

import 'package:flutter/material.dart';
import '../models/dashboard_summary.dart';
import '../services/case_service.dart';

class DashboardProvider extends ChangeNotifier {
  final CaseService _caseService;

  DashboardProvider({CaseService? caseService}) : _caseService = caseService ?? CaseService();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  DashboardSummary? _summary;
  DashboardSummary? get summary => _summary;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Fetch summary from API
  Future<void> fetchSummary() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await _caseService.getDashboardSummary();
      _summary = DashboardSummary.fromJson(data);
    } catch (e) {
      _errorMessage = e.toString();
      
      // Load mock dashboard data as a fallback to allow frontend-first evaluation
      _loadMockSummary(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fallback helper to populate mock data for demonstrations
  void _loadMockSummary(String errorDetails) {
    _summary = DashboardSummary(
      casesOverview: CasesOverview(
        totalAssigned: 120,
        active: 32,
        dispatched: 78,
        pending: 10,
        resolved: 78,
        rejected: 10,
      ),
      severityBreakdown: SeverityBreakdown(
        critical: 15,
        high: 35,
        medium: 50,
        low: 20,
      ),
      volunteerMetrics: VolunteerMetrics(
        totalVolunteers: 45,
        available: 12,
        busy: 33,
      ),
      performanceMetrics: PerformanceMetrics(
        responseRatePercentage: 91.67,
        averageResolutionTimeHours: 4.8,
      ),
      timeMetrics: TimeMetrics(
        todayCases: 5,
        weeklyCases: 28,
        monthlyCases: 120,
      ),
      emergencyTrends: {
        'food': 45,
        'medical': 32,
        'education': 15,
        'emergency_cash': 20,
        'flood_relief': 8,
      },
    );
  }
}
