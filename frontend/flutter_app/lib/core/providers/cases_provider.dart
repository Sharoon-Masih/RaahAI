// lib/core/providers/cases_provider.dart

import 'package:flutter/material.dart';
import '../models/case_model.dart';
import '../services/case_service.dart';

class CasesProvider extends ChangeNotifier {
  final CaseService _caseService;

  CasesProvider({CaseService? caseService}) : _caseService = caseService ?? CaseService();

  // State Variables
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isActionLoading = false;
  bool get isActionLoading => _isActionLoading;

  List<CaseObject> _cases = [];
  List<CaseObject> get cases => _cases;

  CaseObject? _selectedCase;
  CaseObject? get selectedCase => _selectedCase;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // Pagination State
  int _currentPage = 1;
  int get currentPage => _currentPage;
  
  int _totalPages = 1;
  int get totalPages => _totalPages;

  int _totalRecords = 0;
  int get totalRecords => _totalRecords;

  bool _hasNext = false;
  bool get hasNext => _hasNext;

  bool _hasPrev = false;
  bool get hasPrev => _hasPrev;

  // Filter parameters
  String? _statusFilter;
  String? get statusFilter => _statusFilter;

  String? _severityFilter;
  String? get severityFilter => _severityFilter;

  String? _locationFilter;
  String? get locationFilter => _locationFilter;

  String? _crisisTypeFilter;
  String? get crisisTypeFilter => _crisisTypeFilter;

  String? _searchQuery;
  String? get searchQuery => _searchQuery;

  String _sortBy = 'latest';
  String get sortBy => _sortBy;

  // Set sorting
  void setSortBy(String sort) {
    if (_sortBy != sort) {
      _sortBy = sort;
      fetchCases(refresh: true);
    }
  }

  // Set multiple filters at once and reload
  void setFilters({
    String? status,
    String? severity,
    String? location,
    String? crisisType,
    String? search,
  }) {
    _statusFilter = status;
    _severityFilter = severity;
    _locationFilter = location;
    _crisisTypeFilter = crisisType;
    _searchQuery = search;
    fetchCases(refresh: true);
  }

  // Clear filters
  void clearFilters() {
    _statusFilter = null;
    _severityFilter = null;
    _locationFilter = null;
    _crisisTypeFilter = null;
    _searchQuery = null;
    _sortBy = 'latest';
    fetchCases(refresh: true);
  }

  // Load cases
  Future<void> fetchCases({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _caseService.listApplications(
        status: _statusFilter,
        severity: _severityFilter,
        location: _locationFilter,
        crisisType: _crisisTypeFilter,
        searchApplicant: _searchQuery, // We can mapping searchQuery here
        page: _currentPage,
        sortBy: _sortBy,
      );

      final List<CaseObject> fetchedCases = result['cases'];
      final pagination = result['pagination'] ?? {};

      if (refresh) {
        _cases = fetchedCases;
      } else {
        // Remove duplicates and append
        final existingIds = _cases.map((c) => c.caseId).toSet();
        final newCases = fetchedCases.where((c) => !existingIds.contains(c.caseId)).toList();
        _cases.addAll(newCases);
      }

      _currentPage = pagination['page'] ?? _currentPage;
      _totalPages = pagination['total_pages'] ?? _totalPages;
      _totalRecords = pagination['total_records'] ?? _totalRecords;
      _hasNext = pagination['has_next'] ?? false;
      _hasPrev = pagination['has_prev'] ?? false;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load next page
  Future<void> fetchNextPage() async {
    if (_hasNext && !_isLoading) {
      _currentPage++;
      await fetchCases();
    }
  }

  // Fetch detailed case details
  Future<CaseObject?> fetchCaseDetails(String caseId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final caseObj = await _caseService.getCaseDetails(caseId);
      _selectedCase = caseObj;
      
      // Update in cases list if present
      final index = _cases.indexWhere((c) => c.caseId == caseId);
      if (index != -1) {
        _cases[index] = caseObj;
      }
      
      return caseObj;
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Submit manual raw case
  Future<CaseObject?> submitRawCase(String rawInput) async {
    _isActionLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _caseService.submitRawCase(rawInput: rawInput);
      if (result['success'] == true && result['case'] != null) {
        final caseObj = CaseObject.fromJson(Map<String, dynamic>.from(result['case']));
        
        // Add to the top of list
        _cases.insert(0, caseObj);
        return caseObj;
      } else {
        throw Exception(result['message'] ?? 'Failed to submit case.');
      }
    } catch (e) {
      _errorMessage = e.toString();
      return null;
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }

  // Submit spreadsheet and stream raw events to UI
  Stream<Map<String, dynamic>> submitSpreadsheet({
    required List<int> fileBytes,
    required String filename,
  }) {
    return _caseService.submitSpreadsheet(fileBytes: fileBytes, filename: filename);
  }


  // Update case status (re-dispatch or transition status)
  Future<bool> updateCaseStatus(String caseId, String dispatchStatus, String pipelineStage, {Map<String, dynamic>? extra}) async {
    _isActionLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _caseService.updateCaseStatus(
        caseId: caseId,
        dispatchStatus: dispatchStatus,
        pipelineStage: pipelineStage,
        extraFields: extra,
      );

      if (result['success'] == true) {
        // Reload details for this case
        await fetchCaseDetails(caseId);
        return true;
      } else {
        throw Exception(result['detail'] ?? 'Failed to update status.');
      }
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isActionLoading = false;
      notifyListeners();
    }
  }
}
