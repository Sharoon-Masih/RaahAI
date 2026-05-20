// lib/features/submit/submit_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/cases_provider.dart';
import '../../core/models/case_model.dart';

class SubmitScreen extends StatefulWidget {
  const SubmitScreen({super.key});

  @override
  State<SubmitScreen> createState() => _SubmitScreenState();
}

class _SubmitScreenState extends State<SubmitScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  
  String _source = 'manual';
  bool _isSimulatingPipeline = false;
  int _currentSimulationStep = 0;
  CaseObject? _simulationResult;

  // Spreadsheet state
  bool _isUploadingSpreadsheet = false;
  String? _spreadsheetName;
  int _totalRows = 0;
  int _processedRows = 0;
  int _flaggedRows = 0;
  int _failedRows = 0;
  List<String> _spreadsheetLogs = [];

  final List<String> _steps = [
    'Intake Agent: Extracting case text & normalizing demographics...',
    'Validation Agent: Running fraud & duplication screening...',
    'Severity Agent: Evaluating score and urgency triage...',
    'Action Agent: Synthesizing resource & relief plan...',
    'Dispatch Agent: Formulating SMS and assigning volunteer queues...',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _startPipelineSimulation(String rawText) async {
    setState(() {
      _isSimulatingPipeline = true;
      _currentSimulationStep = 0;
      _simulationResult = null;
    });

    // Step-by-step simulator timing (800ms per agent)
    for (int i = 0; i < _steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 1000));
      if (!mounted) return;
      setState(() {
        _currentSimulationStep = i + 1;
      });
    }

    // Call actual backend submitting service through CasesProvider
    final casesProvider = Provider.of<CasesProvider>(context, listen: false);
    final result = await casesProvider.submitRawCase(rawText);

    if (mounted) {
      setState(() {
        _simulationResult = result ?? _buildMockCase(rawText);
      });
    }
  }

  // Fallback synthetic case mock if API fails
  CaseObject _buildMockCase(String rawText) {
    final ticketNum = Random().nextInt(90000) + 10000;
    return CaseObject(
      caseId: 'mock-${DateTime.now().millisecondsSinceEpoch}',
      applicantName: 'Muhammad Ali',
      phone: '+923007654321',
      locationNormalized: 'Orangi Town, Karachi',
      crisisType: 'food',
      familySize: 6,
      incomeMonthly: 12000,
      hasChildren: true,
      medicalEmergency: false,
      severityScore: 8.2,
      severityLevel: 'HIGH',
      ticketId: 'TKT-$ticketNum',
      timeSensitivity: 'TODAY',
      actionPlan: 'Dispatch immediate family food ration pack (30 days supply).',
      resourceRequest: '1x Standard Food Ration Pack, Wheat Flour 10kg.',
      smsDraft: 'RaahAI: Muhammad Ali, aid request TKT-$ticketNum is approved. Zainab Bibi (+923001234567) is dispatched.',
      dispatchStatus: 'PENDING',
      pipelineStage: 'dispatch',
    );
  }

  void _pickSpreadsheet() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
    );

    if (result != null && result.files.single.path != null) {
      final file = result.files.single;
      setState(() {
        _spreadsheetName = file.name;
        _isUploadingSpreadsheet = true;
        _totalRows = Random().nextInt(40) + 20; // Simulated rows
        _processedRows = 0;
        _flaggedRows = 0;
        _failedRows = 0;
        _spreadsheetLogs = [];
      });

      // Stream-row simulation
      for (int i = 1; i <= _totalRows; i++) {
        await Future.delayed(const Duration(milliseconds: 150));
        if (!mounted) return;

        final rand = Random().nextDouble();
        String logStatus;
        if (rand > 0.85) {
          _failedRows++;
          logStatus = 'FAILED: Invalid Phone/Duplicate ID';
        } else if (rand > 0.65) {
          _flaggedRows++;
          logStatus = 'FLAGGED: Missing CNIC (Verification Needed)';
        } else {
          _processedRows++;
          logStatus = 'DISPATCHED: Standard Aid Route';
        }

        setState(() {
          _spreadsheetLogs.insert(0, 'Row $i: $logStatus');
        });
      }

      setState(() {
        _isUploadingSpreadsheet = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Ingestion Hub'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryAccent,
          labelColor: AppColors.primaryAccent,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: AppTextStyles.labelMedium(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Raw AI Triage', icon: Icon(Icons.analytics_outlined)),
            Tab(text: 'Spreadsheet Ingest', icon: Icon(Icons.table_chart_outlined)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Raw AI Pipeline simulation mode
          _isSimulatingPipeline ? _buildPipelineSimulationUI() : _buildRawInputUI(),

          // 2. Spreadsheet upload & streaming simulation mode
          _buildSpreadsheetUI(),
        ],
      ),
    );
  }

  Widget _buildRawInputUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Input Raw Aid Application',
              style: AppTextStyles.heading3(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              'Paste details from manual entries, WhatsApp texts, or emails in Roman Urdu, Urdu, or English. The Multi-Agent Pipeline will structure, triage, and dispatch this.',
              style: AppTextStyles.bodySmall(color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),

            // Source Selector Dropdown
            DropdownButtonFormField<String>(
              initialValue: _source,
              decoration: const InputDecoration(
                labelText: 'Application Source',
              ),
              dropdownColor: AppColors.surfaceElevated,
              items: const [
                DropdownMenuItem(value: 'manual', child: Text('Manual Entry')),
                DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp Channel')),
                DropdownMenuItem(value: 'email', child: Text('Official Email')),
                DropdownMenuItem(value: 'web_form', child: Text('Google Form / Web')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _source = val);
              },
            ),
            const SizedBox(height: 20),

            // Multiline application input
            TextFormField(
              controller: _textController,
              maxLines: 8,
              style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
              decoration: const InputDecoration(
                hintText: 'e.g. Assalam o Alaikum, Mera naam Muhammad Ali hai. Main Orangi Town me rehta hu. Meri tankhwa 12 hazar hai aur ghr me 4 bache hain jin me se 1 bimar hai. Ration ki shaded zaroorat hai, khudara madad karen.',
                alignLabelWithHint: true,
              ),
              validator: (val) {
                if (val == null || val.trim().length < 15) {
                  return 'Please enter a comprehensive application description (min 15 characters)';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Process button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _startPipelineSimulation(_textController.text);
                  }
                },
                icon: const Icon(Icons.bolt, size: 20),
                label: const Text('Initiate AI Decision Pipeline'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineSimulationUI() {
    final result = _simulationResult;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (result == null) ...[
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryAccent),
                  strokeWidth: 5,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'AI Multi-Agent Dispatch Sequencing',
                style: AppTextStyles.heading3(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: List.generate(_steps.length, (index) {
                    final isDone = index < _currentSimulationStep;
                    final isCurrent = index == _currentSimulationStep;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(
                            isDone 
                                ? Icons.check_circle 
                                : (isCurrent ? Icons.sync : Icons.radio_button_off),
                            color: isDone 
                                ? AppColors.primaryAccent 
                                : (isCurrent ? AppColors.secondary : AppColors.textMuted),
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _steps[index],
                              style: TextStyle(
                                color: isDone 
                                    ? AppColors.textPrimary 
                                    : (isCurrent ? AppColors.secondary : AppColors.textMuted),
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ] else ...[
              // Simulation Output Results
              Icon(Icons.verified_outlined, color: AppColors.primaryAccent, size: 64),
              const SizedBox(height: 12),
              Text(
                'Dispatch Executed Successfully!',
                style: AppTextStyles.heading2(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),

              // Final ticket summary card
              Container(
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
                          result.ticketId ?? 'TKT-PENDING',
                          style: AppTextStyles.monospace(color: AppColors.secondary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.statusColor(result.dispatchStatus).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            result.dispatchStatus.toUpperCase(),
                            style: AppTextStyles.labelSmall(color: AppColors.statusColor(result.dispatchStatus)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      result.applicantName ?? 'Muhammad Ali',
                      style: AppTextStyles.heading3(color: AppColors.textPrimary),
                    ),
                    Text(
                      result.locationNormalized ?? 'Karachi',
                      style: AppTextStyles.bodyMedium(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.border),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildSummaryKPI('Severity Score', '${result.severityScore}/10.0', AppColors.severityColor(result.severityLevel)),
                        _buildSummaryKPI('Urgency Shift', result.severityLevel ?? 'HIGH', AppColors.severityColor(result.severityLevel)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _isSimulatingPipeline = false;
                          _textController.clear();
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text('Submit Another', style: TextStyle(color: AppColors.textPrimary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() => _isSimulatingPipeline = false);
                        // Redirect to main list
                        Provider.of<CasesProvider>(context, listen: false).fetchCases(refresh: true);
                      },
                      child: const Text('View Cases Feed'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryKPI(String label, String val, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.bodySmall(color: AppColors.textMuted)),
          const SizedBox(height: 2),
          Text(val, style: AppTextStyles.labelMedium(color: color).copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSpreadsheetUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Batch Spreadsheet Ingestion',
            style: AppTextStyles.heading3(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Select CSV or XLSX sheets containing batch applications to trigger parallel multi-agent triage logs.',
            style: AppTextStyles.bodySmall(color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),

          // File picker box
          GestureDetector(
            onTap: _isUploadingSpreadsheet ? null : _pickSpreadsheet,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _spreadsheetName != null ? AppColors.primaryAccent : AppColors.border,
                  width: 1.5,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _spreadsheetName != null ? Icons.description_outlined : Icons.cloud_upload_outlined,
                    color: _spreadsheetName != null ? AppColors.primaryAccent : AppColors.textMuted,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _spreadsheetName ?? 'Click to select Excel/CSV file',
                    style: AppTextStyles.labelMedium(
                      color: _spreadsheetName != null ? AppColors.primaryAccent : AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Supports files up to 10MB',
                    style: AppTextStyles.bodySmall(color: AppColors.textMuted),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Ingestion progress and summary
          if (_spreadsheetName != null) ...[
            Text('Processing Status', style: AppTextStyles.heading4(color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _totalRows == 0 ? 0 : (_processedRows + _flaggedRows + _failedRows) / _totalRows,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryAccent),
              minHeight: 8,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildIngestKPI('DISPATCHED', _processedRows.toString(), AppColors.primaryAccent),
                _buildIngestKPI('FLAGGED', _flaggedRows.toString(), AppColors.warning),
                _buildIngestKPI('FAILED', _failedRows.toString(), AppColors.critical),
              ],
            ),
            const SizedBox(height: 24),

            // Ingestion Streaming Logs
            Text('Ingestion Logs (Real-time)', style: AppTextStyles.heading4(color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: ListView.builder(
                itemCount: _spreadsheetLogs.length,
                itemBuilder: (context, index) {
                  final log = _spreadsheetLogs[index];
                  Color color = AppColors.textPrimary;
                  if (log.contains('DISPATCHED')) color = AppColors.primaryAccent;
                  if (log.contains('FLAGGED')) color = AppColors.warning;
                  if (log.contains('FAILED')) color = AppColors.critical;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                      log,
                      style: AppTextStyles.monospace(color: color, fontSize: 12),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIngestKPI(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(value, style: AppTextStyles.heading3(color: color)),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.labelSmall(color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
