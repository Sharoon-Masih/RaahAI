// lib/features/applications/applications_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/cases_provider.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/error_state.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../core/utils/status_helpers.dart';
import 'application_detail_screen.dart';

class ApplicationsScreen extends StatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _showFilters = false;

  // Selected filters
  String? _selectedStatus;
  String? _selectedSeverity;
  String? _selectedCrisis;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Initial fetch of applications on load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CasesProvider>(context, listen: false).fetchCases(refresh: true);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final casesProvider = Provider.of<CasesProvider>(context, listen: false);
      if (casesProvider.hasNext && !casesProvider.isLoading) {
        casesProvider.fetchNextPage();
      }
    }
  }

  // Debounced search trigger
  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final casesProvider = Provider.of<CasesProvider>(context, listen: false);
      casesProvider.setFilters(
        search: query.isEmpty ? null : query,
        status: _selectedStatus,
        severity: _selectedSeverity,
        crisisType: _selectedCrisis,
      );
    });
  }

  void _applyFilters() {
    final casesProvider = Provider.of<CasesProvider>(context, listen: false);
    casesProvider.setFilters(
      search: _searchController.text.isEmpty ? null : _searchController.text,
      status: _selectedStatus,
      severity: _selectedSeverity,
      crisisType: _selectedCrisis,
    );
    setState(() => _showFilters = false);
  }

  void _resetFilters() {
    setState(() {
      _selectedStatus = null;
      _selectedSeverity = null;
      _selectedCrisis = null;
      _searchController.clear();
    });
    final casesProvider = Provider.of<CasesProvider>(context, listen: false);
    casesProvider.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final casesProvider = Provider.of<CasesProvider>(context);
    final cases = casesProvider.cases;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Search & Filter Toggle Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    style: AppTextStyles.bodyMedium(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search applicant, phone or ticket...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: AppColors.textMuted),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _showFilters ? Icons.filter_list_off : Icons.filter_list,
                    color: _showFilters ? AppColors.primaryAccent : AppColors.textPrimary,
                  ),
                  style: IconButton.styleFrom(
                    backgroundColor: AppColors.surfaceElevated,
                    padding: const EdgeInsets.all(14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.border),
                    ),
                  ),
                  onPressed: () {
                    setState(() => _showFilters = !_showFilters);
                  },
                ),
              ],
            ),
          ),

          // Sliding filter box
          AnimatedCrossFade(
            firstChild: _buildFilterPanel(),
            secondChild: const SizedBox.shrink(),
            crossFadeState: _showFilters ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            duration: const Duration(milliseconds: 250),
          ),

          // Sorting Toggle bar
          _buildSortingBar(casesProvider),

          // Core List View / Grid Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => casesProvider.fetchCases(refresh: true),
              color: AppColors.primaryAccent,
              backgroundColor: AppColors.surfaceElevated,
              child: casesProvider.isLoading && cases.isEmpty
                  ? LoadingShimmer.list()
                  : casesProvider.errorMessage != null && cases.isEmpty
                      ? ErrorState(
                          errorMessage: casesProvider.errorMessage!,
                          onRetry: () => casesProvider.fetchCases(refresh: true),
                        )
                      : cases.isEmpty
                          ? const EmptyState(
                              title: 'No Applications Found',
                              message: 'Try clearing your filters or search keywords to view aid cases.',
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: cases.length + (casesProvider.hasNext ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index == cases.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 24),
                                    child: Center(
                                      child: CircularProgressIndicator(
                                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryAccent),
                                      ),
                                    ),
                                  );
                                }

                                final caseItem = cases[index];
                                return _buildCaseCard(caseItem);
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Filter Applications', style: AppTextStyles.heading4(color: AppColors.textPrimary)),
          const SizedBox(height: 12),

          // Status Filter Row
          _buildFilterLabel('Case Status'),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Status', 'PENDING', _selectedStatus == 'PENDING', (s) => setState(() => _selectedStatus = s)),
                _buildFilterChip('Status', 'PROCESSING', _selectedStatus == 'PROCESSING', (s) => setState(() => _selectedStatus = s)),
                _buildFilterChip('Status', 'DISPATCHED', _selectedStatus == 'DISPATCHED', (s) => setState(() => _selectedStatus = s)),
                _buildFilterChip('Status', 'FAILED', _selectedStatus == 'FAILED', (s) => setState(() => _selectedStatus = s)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Severity Filter Row
          _buildFilterLabel('Severity Urgency'),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Severity', 'CRITICAL', _selectedSeverity == 'CRITICAL', (s) => setState(() => _selectedSeverity = s)),
                _buildFilterChip('Severity', 'HIGH', _selectedSeverity == 'HIGH', (s) => setState(() => _selectedSeverity = s)),
                _buildFilterChip('Severity', 'MEDIUM', _selectedSeverity == 'MEDIUM', (s) => setState(() => _selectedSeverity = s)),
                _buildFilterChip('Severity', 'LOW', _selectedSeverity == 'LOW', (s) => setState(() => _selectedSeverity = s)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Crisis Type Filter Row
          _buildFilterLabel('Crisis Type'),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Crisis', 'food', _selectedCrisis == 'food', (s) => setState(() => _selectedCrisis = s)),
                _buildFilterChip('Crisis', 'medical', _selectedCrisis == 'medical', (s) => setState(() => _selectedCrisis = s)),
                _buildFilterChip('Crisis', 'education', _selectedCrisis == 'education', (s) => setState(() => _selectedCrisis = s)),
                _buildFilterChip('Crisis', 'emergency_cash', _selectedCrisis == 'emergency_cash', (s) => setState(() => _selectedCrisis = s)),
                _buildFilterChip('Crisis', 'flood_relief', _selectedCrisis == 'flood_relief', (s) => setState(() => _selectedCrisis = s)),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _resetFilters,
                child: Text('Reset', style: TextStyle(color: AppColors.critical)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _applyFilters,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                ),
                child: const Text('Apply Filters'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterLabel(String text) {
    return Text(text, style: AppTextStyles.labelSmall(color: AppColors.textMuted));
  }

  Widget _buildFilterChip(String type, String value, bool isSelected, Function(String?) onSelected) {
    final chipColor = type == 'Severity' 
        ? AppColors.severityColor(value) 
        : (type == 'Crisis' ? AppColors.crisisTypeColor(value) : AppColors.statusColor(value));
        
    return Padding(
      padding: const EdgeInsets.only(right: 6.0),
      child: ChoiceChip(
        label: Text(
          type == 'Crisis' ? StatusHelpers.getCrisisTypeLabel(value) : StatusHelpers.getSeverityLabel(value),
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textPrimary,
            fontSize: 11,
          ),
        ),
        selected: isSelected,
        onSelected: (selected) {
          onSelected(selected ? value : null);
        },
        selectedColor: chipColor,
        backgroundColor: AppColors.surface,
        checkmarkColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: isSelected ? Colors.transparent : AppColors.border,
          ),
        ),
      ),
    );
  }

  Widget _buildSortingBar(CasesProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '${provider.totalRecords} Applications',
            style: AppTextStyles.labelSmall(color: AppColors.textMuted),
          ),
          DropdownButton<String>(
            value: provider.sortBy,
            dropdownColor: AppColors.surfaceElevated,
            underline: const SizedBox.shrink(),
            icon: const Icon(Icons.sort, size: 16, color: AppColors.primaryAccent),
            style: AppTextStyles.labelMedium(color: AppColors.primaryAccent),
            items: const [
              DropdownMenuItem(value: 'latest', child: Text('Latest')),
              DropdownMenuItem(value: 'oldest', child: Text('Oldest')),
              DropdownMenuItem(value: 'severity', child: Text('Severity')),
            ],
            onChanged: (val) {
              if (val != null) {
                provider.setSortBy(val);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCaseCard(dynamic caseItem) {
    final severityColor = AppColors.severityColor(caseItem.severityLevel);
    final crisisColor = AppColors.crisisTypeColor(caseItem.crisisType);
    final statusColor = AppColors.statusColor(caseItem.dispatchStatus);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: severityColor, width: 4),
          top: const BorderSide(color: AppColors.border, width: 1),
          right: const BorderSide(color: AppColors.border, width: 1),
          bottom: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ApplicationDetailScreen(caseId: caseItem.caseId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ticket ID + Time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    caseItem.ticketId ?? 'TICKET-PENDING',
                    style: AppTextStyles.monospace(color: AppColors.secondary, fontSize: 12),
                  ),
                  Text(
                    '10 mins ago', // Simple formatting fallback or custom parser
                    style: AppTextStyles.bodySmall(color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Name + Location
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          caseItem.applicantName ?? 'Anonymous Applicant',
                          style: AppTextStyles.heading4(color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textMuted),
                            const SizedBox(width: 4),
                            Text(
                              caseItem.locationNormalized ?? 'Pakistan',
                              style: AppTextStyles.bodySmall(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  CircleAvatar(
                    backgroundColor: crisisColor.withValues(alpha: 0.12),
                    child: Icon(
                      StatusHelpers.getCrisisTypeIcon(caseItem.crisisType),
                      color: crisisColor,
                      size: 20,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Badges row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Severity Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: severityColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: severityColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(StatusHelpers.getSeverityIcon(caseItem.severityLevel), color: severityColor, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          caseItem.severityLevel ?? 'LOW',
                          style: AppTextStyles.labelSmall(color: severityColor),
                        ),
                      ],
                    ),
                  ),

                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      caseItem.dispatchStatus.toUpperCase(),
                      style: AppTextStyles.labelSmall(color: statusColor).copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
