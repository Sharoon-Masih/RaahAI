// lib/features/applications/application_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/cases_provider.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/error_state.dart';

import '../../core/models/volunteer_model.dart';
import '../../core/services/case_service.dart';

class ApplicationDetailScreen extends StatefulWidget {
  final String caseId;
  const ApplicationDetailScreen({super.key, required this.caseId});

  @override
  State<ApplicationDetailScreen> createState() => _ApplicationDetailScreenState();
}

class _ApplicationDetailScreenState extends State<ApplicationDetailScreen> {
  List<VolunteerModel> _volunteers = [];
  bool _isLoadingVolunteers = false;
  String? _selectedVolunteer;
  bool _isExpandedTrace = false;
  int _activeTraceIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadDetails();
    _loadVolunteers();
  }

  Future<void> _loadDetails() async {
    await Provider.of<CasesProvider>(context, listen: false).fetchCaseDetails(widget.caseId);
  }

  Future<void> _loadVolunteers() async {
    setState(() => _isLoadingVolunteers = true);
    try {
      final vols = await CaseService().getAvailableVolunteers();
      setState(() => _volunteers = vols);
    } catch (e) {
      // Mock fallback if API is not active
      setState(() {
        _volunteers = [
          VolunteerModel(volunteerId: 'v1', name: 'Zainab Bibi', phone: '+923001234567', city: 'Karachi', available: true, skills: const ['food', 'medical']),
          VolunteerModel(volunteerId: 'v2', name: 'Haris Khan', phone: '+923219876543', city: 'Karachi', available: true, skills: const ['flood_relief']),
          VolunteerModel(volunteerId: 'v3', name: 'Ayesha Raza', phone: '+923334567890', city: 'Karachi', available: true, skills: const ['education', 'emergency_cash']),
        ];
      });
    } finally {
      setState(() => _isLoadingVolunteers = false);
    }
  }

  void _dispatchCase(String volunteerName) async {
    final provider = Provider.of<CasesProvider>(context, listen: false);
    final caseObj = provider.selectedCase;
    if (caseObj == null) return;

    final success = await provider.updateCaseStatus(
      widget.caseId,
      'DISPATCHED',
      'dispatch',
      extra: {
        'volunteer_assigned': volunteerName,
        'ticket_id': caseObj.ticketId ?? 'TKT-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      },
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success ? 'Case Dispatched Successfully!' : 'Failed to dispatch case.',
            style: AppTextStyles.bodyMedium(color: AppColors.background),
          ),
          backgroundColor: success ? AppColors.primaryAccent : AppColors.critical,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final casesProvider = Provider.of<CasesProvider>(context);
    final caseObj = casesProvider.selectedCase;

    if (casesProvider.isLoading && caseObj == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Loading Details...')),
        body: LoadingShimmer.detail(),
      );
    }

    if (casesProvider.errorMessage != null && caseObj == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Error')),
        body: ErrorState(
          errorMessage: casesProvider.errorMessage!,
          onRetry: _loadDetails,
        ),
      );
    }

    if (caseObj == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Detail')),
        body: const Center(child: Text('Application not found')),
      );
    }

    final severityColor = AppColors.severityColor(caseObj.severityLevel);
    final statusColor = AppColors.statusColor(caseObj.dispatchStatus);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(caseObj.ticketId ?? 'Triage Review'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDetails,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Premium Header Applicant Card
            _buildHeaderCard(caseObj, statusColor),
            const SizedBox(height: 16),

            // 2. Severity Visualization Gauge
            _buildSeverityGauge(caseObj, severityColor),
            const SizedBox(height: 16),

            // 3. Metadata Grid Section
            _buildMetadataGrid(caseObj),
            const SizedBox(height: 24),

            // 4. Action Plan & Resource Request
            _buildPlanCard(caseObj),
            const SizedBox(height: 24),

            // 5. Expandable Agent Trace Timeline
            _buildTraceTimeline(caseObj),
            const SizedBox(height: 24),

            // 6. Volunteer Assignment Dropdown Control
            if (caseObj.dispatchStatus.toUpperCase() != 'DISPATCHED')
              _buildVolunteerAssignmentControl()
            else
              _buildAssignedVolunteerCard(caseObj),
            const SizedBox(height: 24),

            // 7. SMS Preview Card
            if (caseObj.smsDraft != null && caseObj.smsDraft!.isNotEmpty)
              _buildSmsPreviewCard(caseObj.smsDraft!),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(dynamic caseObj, Color statusColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  caseObj.dispatchStatus.toUpperCase(),
                  style: AppTextStyles.labelSmall(color: statusColor).copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16, color: AppColors.textMuted),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: caseObj.ticketId ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ticket ID copied to clipboard!')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            caseObj.applicantName ?? 'Anonymous Applicant',
            style: AppTextStyles.heading2(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.phone_outlined, size: 14, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                caseObj.phone ?? 'No phone contact provided',
                style: AppTextStyles.bodyMedium(color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Visual Gauge representing severity
  Widget _buildSeverityGauge(dynamic caseObj, Color severityColor) {
    final score = caseObj.severityScore ?? 0.0;
    final percent = score / 10.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AI Urgency Assessment',
                style: AppTextStyles.heading4(color: AppColors.textPrimary),
              ),
              Text(
                '${score.toStringAsFixed(1)} / 10.0',
                style: AppTextStyles.heading3(color: severityColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 12,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(severityColor),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            caseObj.keyInsight ?? 'No specific dispatch insights compiled by AI Severity & Impact Agent.',
            style: AppTextStyles.bodyMedium(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // Grid Section showing case metrics
  Widget _buildMetadataGrid(dynamic caseObj) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Demographics & Signals',
            style: AppTextStyles.heading4(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.2,
            children: [
              _buildMetaItem('Family Size', caseObj.familySize.toString(), Icons.people_outline),
              _buildMetaItem('Monthly Income', 'Rs. ${caseObj.incomeMonthly}', Icons.payments_outlined),
              _buildMetaItem('Has Children', caseObj.hasChildren ? 'Yes' : 'No', Icons.child_care_outlined),
              _buildMetaItem('Medical Need', caseObj.medicalEmergency ? 'Yes' : 'No', Icons.medical_services_outlined),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetaItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Text(label, style: AppTextStyles.bodySmall(color: AppColors.textMuted)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: AppTextStyles.labelMedium(color: AppColors.textPrimary)),
      ],
    );
  }

  // Action Plan and resources Card
  Widget _buildPlanCard(dynamic caseObj) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NGO Action Plan',
            style: AppTextStyles.heading4(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Text(
            caseObj.actionPlan ?? 'No action plan generated.',
            style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.border),
          const SizedBox(height: 12),
          Text(
            'Requested Relief Resources',
            style: AppTextStyles.heading4(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            caseObj.resourceRequest ?? 'No resource requests listed.',
            style: AppTextStyles.bodyMedium(color: AppColors.secondary),
          ),
        ],
      ),
    );
  }

  // Interactive Timeline tracking 5 NGO agents
  Widget _buildTraceTimeline(dynamic caseObj) {
    final traces = caseObj.agentTrace;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AI Agent Trace Timeline',
                style: AppTextStyles.heading4(color: AppColors.textPrimary),
              ),
              IconButton(
                icon: Icon(
                  _isExpandedTrace ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.primaryAccent,
                ),
                onPressed: () => setState(() => _isExpandedTrace = !_isExpandedTrace),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (traces.isEmpty)
            Text('No agent decision trace available.', style: AppTextStyles.bodyMedium(color: AppColors.textMuted))
          else
            AnimatedCrossFade(
              firstChild: _buildVerticalTimeline(traces),
              secondChild: _buildMiniTimeline(traces),
              crossFadeState: _isExpandedTrace ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 250),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniTimeline(List<dynamic> traces) {
    return Row(
      children: traces.map((t) {
        return Expanded(
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(color: AppColors.primaryAccent, shape: BoxShape.circle),
              ),
              Expanded(
                child: Container(
                  height: 2,
                  color: AppColors.border,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVerticalTimeline(List<dynamic> traces) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: traces.length,
      itemBuilder: (context, index) {
        final t = traces[index];
        final isLast = index == traces.length - 1;
        final isActive = index == _activeTraceIndex;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppColors.primaryAccent,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: isActive ? 120 : 60,
                    color: AppColors.primaryAccent.withValues(alpha: 0.5),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _activeTraceIndex = isActive ? -1 : index;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isActive ? AppColors.primaryAccent : AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(t.agent, style: AppTextStyles.labelMedium(color: AppColors.primaryAccent)),
                          Text(t.timestamp.toString().split('T').first, style: AppTextStyles.bodySmall(color: AppColors.textMuted)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(t.action, style: AppTextStyles.bodyMedium(color: AppColors.textPrimary)),
                      if (isActive) ...[
                        const SizedBox(height: 8),
                        const Divider(color: AppColors.border),
                        const SizedBox(height: 6),
                        Text('Reasoning Logs:', style: AppTextStyles.labelSmall(color: AppColors.textMuted)),
                        const SizedBox(height: 4),
                        Text(t.reasoning, style: AppTextStyles.bodySmall(color: AppColors.textMuted)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Active Volunteer SelectorDropdown
  Widget _buildVolunteerAssignmentControl() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dispatches Center',
            style: AppTextStyles.heading4(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            'Assign a localized volunteer to dispatch this case.',
            style: AppTextStyles.bodySmall(color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          _isLoadingVolunteers
              ? const Center(child: CircularProgressIndicator())
              : DropdownButtonFormField<String>(
                  initialValue: _selectedVolunteer,
                  hint: Text('Select Available Volunteer', style: TextStyle(color: AppColors.textMuted)),
                  dropdownColor: AppColors.surfaceElevated,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  items: _volunteers.map((v) {
                    return DropdownMenuItem<String>(
                      value: v.name,
                      child: Text('${v.name} (${v.city ?? "Karachi"} • Skills: ${v.skills.join(", ")})', style: const TextStyle(fontSize: 13)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() => _selectedVolunteer = val);
                  },
                ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _selectedVolunteer != null ? () => _dispatchCase(_selectedVolunteer!) : null,
              icon: const Icon(Icons.send_rounded, size: 20),
              label: const Text('Assign and Dispatch Case'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryAccent,
                foregroundColor: AppColors.background,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedVolunteerCard(dynamic caseObj) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primaryAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primaryAccent.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person, color: AppColors.primaryAccent, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Volunteer Assigned',
                  style: AppTextStyles.bodySmall(color: AppColors.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  caseObj.volunteerAssigned ?? 'Unknown Volunteer',
                  style: AppTextStyles.heading4(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Case dispatched to the ground volunteer successfully.',
                  style: AppTextStyles.bodySmall(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Formatting SMS Preview Card
  Widget _buildSmsPreviewCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Dispatch SMS Draft',
                style: AppTextStyles.heading4(color: AppColors.textPrimary),
              ),
              IconButton(
                icon: const Icon(Icons.copy, size: 16, color: AppColors.textMuted),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: text));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('SMS Draft copied!')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              text,
              style: AppTextStyles.monospace(color: AppColors.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
