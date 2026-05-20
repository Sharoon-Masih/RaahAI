// lib/core/models/case_model.dart

class CaseObject {
  final String caseId;
  final String? applicantName;
  final String? phone;
  final String? locationNormalized;
  final String? crisisType;
  final int familySize;
  final int incomeMonthly;

  // Inferred flags
  final bool hasChildren;
  final bool medicalEmergency;
  final String? languageDetected;
  final String descriptionEn;
  final String descriptionOriginal;

  // Validation
  final String? validationStatus;
  final List<String> validationReasons;
  final List<String> fraudSignals;

  // Severity & Impact
  final double? severityScore;
  final String? severityLevel;
  final String? keyInsight;
  final Map<String, dynamic>? scoringBreakdown;
  final bool compoundCrisisDetected;
  final String? timeSensitivity;
  final String? delayConsequence;
  final String? locationRiskFactor;

  // Action Generation
  final String? actionPlan;
  final String? resourceRequest;
  final String? volunteerProfileRequest;

  // Dispatch
  final String? volunteerAssigned;
  final String? assignedNgoId;
  final String? ticketId;
  final String? smsDraft;
  final String dispatchStatus;

  // Pipeline Metadata
  final String pipelineStage;
  final String? submissionSource;
  final List<TraceObject> agentTrace;

  CaseObject({
    required this.caseId,
    this.applicantName,
    this.phone,
    this.locationNormalized,
    this.crisisType,
    this.familySize = 1,
    this.incomeMonthly = 0,
    this.hasChildren = false,
    this.medicalEmergency = false,
    this.languageDetected,
    this.descriptionEn = '',
    this.descriptionOriginal = '',
    this.validationStatus,
    this.validationReasons = const [],
    this.fraudSignals = const [],
    this.severityScore,
    this.severityLevel,
    this.keyInsight,
    this.scoringBreakdown,
    this.compoundCrisisDetected = false,
    this.timeSensitivity,
    this.delayConsequence,
    this.locationRiskFactor,
    this.actionPlan,
    this.resourceRequest,
    this.volunteerProfileRequest,
    this.volunteerAssigned,
    this.assignedNgoId,
    this.ticketId,
    this.smsDraft,
    this.dispatchStatus = 'PENDING',
    this.pipelineStage = 'raw',
    this.submissionSource,
    this.agentTrace = const [],
  });

  factory CaseObject.fromJson(Map<String, dynamic> json) {
    // Parse TraceObject list
    var traceList = json['agent_trace'] as List?;
    List<TraceObject> parsedTraces = traceList != null
        ? traceList.map((t) => TraceObject.fromJson(Map<String, dynamic>.from(t))).toList()
        : [];

    // Parse list of strings safely
    List<String> parseList(dynamic val) {
      if (val == null) return [];
      if (val is List) return val.map((e) => e.toString()).toList();
      return [];
    }

    // Parse double safely (since it might come as an int or float in JSON)
    double? parseDouble(dynamic val) {
      if (val == null) return null;
      if (val is num) return val.toDouble();
      return double.tryParse(val.toString());
    }

    // Parse int safely
    int parseInt(dynamic val, int fallback) {
      if (val == null) return fallback;
      if (val is num) return val.toInt();
      return int.tryParse(val.toString()) ?? fallback;
    }

    // Parse bool safely
    bool parseBool(dynamic val, bool fallback) {
      if (val == null) return fallback;
      if (val is bool) return val;
      if (val == 1 || val.toString().toLowerCase() == 'true') return true;
      return false;
    }

    return CaseObject(
      caseId: json['case_id']?.toString() ?? '',
      applicantName: json['applicant_name']?.toString(),
      phone: json['phone']?.toString(),
      locationNormalized: json['location_normalized']?.toString(),
      crisisType: json['crisis_type']?.toString(),
      familySize: parseInt(json['family_size'], 1),
      incomeMonthly: parseInt(json['income_monthly'], 0),
      hasChildren: parseBool(json['has_children'], false),
      medicalEmergency: parseBool(json['medical_emergency'], false),
      languageDetected: json['language_detected']?.toString(),
      descriptionEn: json['description_en']?.toString() ?? '',
      descriptionOriginal: json['description_original']?.toString() ?? '',
      validationStatus: json['validation_status']?.toString(),
      validationReasons: parseList(json['validation_reasons']),
      fraudSignals: parseList(json['fraud_signals']),
      severityScore: parseDouble(json['severity_score']),
      severityLevel: json['severity_level']?.toString(),
      keyInsight: json['key_insight']?.toString(),
      scoringBreakdown: json['scoring_breakdown'] != null
          ? Map<String, dynamic>.from(json['scoring_breakdown'] as Map)
          : null,
      compoundCrisisDetected: parseBool(json['compound_crisis_detected'], false),
      timeSensitivity: json['time_sensitivity']?.toString(),
      delayConsequence: json['delay_consequence']?.toString(),
      locationRiskFactor: json['location_risk_factor']?.toString(),
      actionPlan: json['action_plan']?.toString(),
      resourceRequest: json['resource_request']?.toString(),
      volunteerProfileRequest: json['volunteer_profile_request']?.toString(),
      volunteerAssigned: json['volunteer_assigned']?.toString(),
      assignedNgoId: json['assigned_ngo_id']?.toString(),
      ticketId: json['ticket_id']?.toString(),
      smsDraft: json['sms_draft']?.toString(),
      dispatchStatus: json['dispatch_status']?.toString() ?? 'PENDING',
      pipelineStage: json['pipeline_stage']?.toString() ?? 'raw',
      submissionSource: json['submission_source']?.toString(),
      agentTrace: parsedTraces,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'case_id': caseId,
      'applicant_name': applicantName,
      'phone': phone,
      'location_normalized': locationNormalized,
      'crisis_type': crisisType,
      'family_size': familySize,
      'income_monthly': incomeMonthly,
      'has_children': hasChildren,
      'medical_emergency': medicalEmergency,
      'language_detected': languageDetected,
      'description_en': descriptionEn,
      'description_original': descriptionOriginal,
      'validation_status': validationStatus,
      'validation_reasons': validationReasons,
      'fraud_signals': fraudSignals,
      'severity_score': severityScore,
      'severity_level': severityLevel,
      'key_insight': keyInsight,
      'scoring_breakdown': scoringBreakdown,
      'compound_crisis_detected': compoundCrisisDetected,
      'time_sensitivity': timeSensitivity,
      'delay_consequence': delayConsequence,
      'location_risk_factor': locationRiskFactor,
      'action_plan': actionPlan,
      'resource_request': resourceRequest,
      'volunteer_profile_request': volunteerProfileRequest,
      'volunteer_assigned': volunteerAssigned,
      'assigned_ngo_id': assignedNgoId,
      'ticket_id': ticketId,
      'sms_draft': smsDraft,
      'dispatch_status': dispatchStatus,
      'pipeline_stage': pipelineStage,
      'submission_source': submissionSource,
      'agent_trace': agentTrace.map((t) => t.toJson()).toList(),
    };
  }
}

class TraceObject {
  final String agent;
  final String timestamp;
  final String action;
  final String reasoning;
  final List<String> toolCalls;
  final String outputSummary;

  TraceObject({
    required this.agent,
    required this.timestamp,
    required this.action,
    required this.reasoning,
    this.toolCalls = const [],
    required this.outputSummary,
  });

  factory TraceObject.fromJson(Map<String, dynamic> json) {
    List<String> parseList(dynamic val) {
      if (val == null) return [];
      if (val is List) return val.map((e) => e.toString()).toList();
      return [];
    }

    return TraceObject(
      agent: json['agent']?.toString() ?? 'UnknownAgent',
      timestamp: json['timestamp']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      reasoning: json['reasoning']?.toString() ?? '',
      toolCalls: parseList(json['tool_calls']),
      outputSummary: json['output_summary']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'agent': agent,
      'timestamp': timestamp,
      'action': action,
      'reasoning': reasoning,
      'tool_calls': toolCalls,
      'output_summary': outputSummary,
    };
  }
}
