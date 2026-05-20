// lib/core/services/case_service.dart

import 'dart:convert';
import '../models/case_model.dart';
import '../models/volunteer_model.dart';
import 'api_service.dart';
import '../constants/api_constants.dart';

class CaseService {
  final ApiService _apiService;

  CaseService({ApiService? apiService}) : _apiService = apiService ?? ApiService();

  // List applications (paginated and filterable)
  Future<Map<String, dynamic>> listApplications({
    String? status,
    String? severity,
    String? location,
    String? crisisType,
    bool? hasVolunteer,
    String? searchApplicant,
    String? searchTicket,
    String? searchPhone,
    int page = 1,
    int limit = 20,
    String sortBy = 'latest',
  }) async {
    final Map<String, String> queryParams = {
      'page': page.toString(),
      'limit': limit.toString(),
      'sort_by': sortBy,
    };

    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (severity != null && severity.isNotEmpty) queryParams['severity'] = severity;
    if (location != null && location.isNotEmpty) queryParams['location'] = location;
    if (crisisType != null && crisisType.isNotEmpty) queryParams['crisis_type'] = crisisType;
    if (hasVolunteer != null) queryParams['has_volunteer'] = hasVolunteer.toString();
    if (searchApplicant != null && searchApplicant.isNotEmpty) queryParams['search_applicant'] = searchApplicant;
    if (searchTicket != null && searchTicket.isNotEmpty) queryParams['search_ticket'] = searchTicket;
    if (searchPhone != null && searchPhone.isNotEmpty) queryParams['search_phone'] = searchPhone;

    final response = await _apiService.get(
      ApiConstants.applications,
      queryParameters: queryParams,
    );

    final Map<String, dynamic> data = jsonDecode(response.body);
    final List<dynamic> casesJson = data['data'] ?? [];
    final List<CaseObject> cases = casesJson.map((c) => CaseObject.fromJson(Map<String, dynamic>.from(c))).toList();

    return {
      'cases': cases,
      'pagination': data['pagination'] ?? {},
    };
  }

  // Get single case details
  Future<CaseObject> getCaseDetails(String caseId) async {
    final response = await _apiService.get(
      '${ApiConstants.firebaseCaseDetail}$caseId',
    );
    final data = jsonDecode(response.body);
    return CaseObject.fromJson(data);
  }

  // Submit manual case (raw text)
  Future<Map<String, dynamic>> submitRawCase({
    required String rawInput,
    String submissionSource = 'flutter_app',
  }) async {
    final response = await _apiService.post(
      ApiConstants.submitRaw,
      body: {
        'raw_input': rawInput,
        'submission_source': submissionSource,
      },
    );
    return jsonDecode(response.body);
  }

  // Get available volunteers
  Future<List<VolunteerModel>> getAvailableVolunteers() async {
    final response = await _apiService.get(
      ApiConstants.firebaseVolunteers,
      queryParameters: {'available': 'true'},
    );
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((v) => VolunteerModel.fromJson(Map<String, dynamic>.from(v))).toList();
  }

  // Update case status (e.g. manual dispatch or processing)
  Future<Map<String, dynamic>> updateCaseStatus({
    required String caseId,
    required String dispatchStatus,
    required String pipelineStage,
    Map<String, dynamic>? extraFields,
  }) async {
    final response = await _apiService.post(
      ApiConstants.firebaseUpdateStatus,
      body: {
        'case_id': caseId,
        'dispatch_status': dispatchStatus,
        'pipeline_stage': pipelineStage,
        'extra_fields': ?extraFields,
      },
    );
    return jsonDecode(response.body);
  }

  // Fetch general stats (alternative to dashboard summary)
  Future<Map<String, dynamic>> getStats() async {
    final response = await _apiService.get(ApiConstants.firebaseStats);
    return jsonDecode(response.body);
  }

  // Fetch dashboard summary
  Future<Map<String, dynamic>> getDashboardSummary() async {
    final response = await _apiService.get(ApiConstants.dashboardSummary);
    return jsonDecode(response.body);
  }
}
