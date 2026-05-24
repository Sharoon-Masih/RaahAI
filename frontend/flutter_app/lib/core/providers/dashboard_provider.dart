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
      
      // Do not load mock data, let the error show so we see real errors
      // _loadMockSummary(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
