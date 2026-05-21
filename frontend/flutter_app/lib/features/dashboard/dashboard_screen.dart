// lib/features/dashboard/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/dashboard_provider.dart';
import '../../core/providers/cases_provider.dart';
import '../../shared/widgets/loading_shimmer.dart';
import '../../shared/widgets/error_state.dart';
import '../../core/utils/status_helpers.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _activeDonutIndex = -1;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    await Provider.of<DashboardProvider>(context, listen: false).fetchSummary();
  }

  @override
  Widget build(BuildContext context) {
    final dashboardProvider = Provider.of<DashboardProvider>(context);

    if (dashboardProvider.isLoading && dashboardProvider.summary == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: LoadingShimmer.detail(),
      );
    }

    if (dashboardProvider.errorMessage != null && dashboardProvider.summary == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: ErrorState(
          errorMessage: dashboardProvider.errorMessage!,
          onRetry: _refreshData,
        ),
      );
    }

    final summary = dashboardProvider.summary!;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: AppColors.primaryAccent,
        backgroundColor: AppColors.surfaceElevated,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. KPI Grid Card Section
              _buildKpiGrid(summary),
              const SizedBox(height: 24),

              // 2. Severity Distribution Donut Chart & 7-Day Activity Bar Chart
              Text(
                'Triage Analytics',
                style: AppTextStyles.heading3(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              _buildSeverityDonutChart(summary),
              const SizedBox(height: 16),
              _buildSevenDayDispatchActivity(),
              const SizedBox(height: 24),

              // 3. Crisis Breakdown & Time Sensitivity
              Text(
                'Distribution & Urgency',
                style: AppTextStyles.heading3(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              _buildCrisisBreakdown(summary),
              const SizedBox(height: 16),
              _buildTimeSensitivityRings(summary),
              const SizedBox(height: 24),

              // 4. Recent Activity Feed
              Text(
                'Recent Operational Dispatch',
                style: AppTextStyles.heading3(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              _buildRecentActivitySection(),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  // KPI Grid Card Layout
  Widget _buildKpiGrid(dynamic summary) {
    final overview = summary.casesOverview;
    final total = overview.totalAssigned;
    final dispatched = overview.dispatched;
    final pending = overview.pending;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildKpiCard('Total Cases', total.toString(), Icons.folder_shared_outlined, AppColors.secondary, false),
        _buildKpiCard('Critical Cases', summary.severityBreakdown.critical.toString(), Icons.gpp_maybe, AppColors.critical, true),
        _buildKpiCard('Dispatched', dispatched.toString(), Icons.check_circle_outline, AppColors.primaryAccent, false),
        _buildKpiCard('Pending Triage', pending.toString(), Icons.pending_actions_outlined, AppColors.warning, false),
      ],
    );
  }

  Widget _buildKpiCard(String label, String value, IconData icon, Color color, bool pulsing) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pulsing ? AppColors.critical.withValues(alpha: 0.8) : AppColors.border,
          width: pulsing ? 1.5 : 1,
        ),
        boxShadow: pulsing
            ? [
                BoxShadow(
                  color: AppColors.critical.withValues(alpha: 0.15),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ]
            : [],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTextStyles.labelSmall(color: AppColors.textMuted),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          Text(
            value,
            style: AppTextStyles.heading2(color: AppColors.textPrimary).copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // Severity Distribution Donut Chart
  Widget _buildSeverityDonutChart(dynamic summary) {
    final breakdown = summary.severityBreakdown;
    final total = (breakdown.critical + breakdown.high + breakdown.medium + breakdown.low).toDouble();
    if (total == 0) return const SizedBox();

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
            'Severity Level Distribution',
            style: AppTextStyles.heading4(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 5,
                child: SizedBox(
                  height: 160,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (FlTouchEvent event, pieTouchResponse) {
                          setState(() {
                            if (!event.isInterestedForInteractions ||
                                pieTouchResponse == null ||
                                pieTouchResponse.touchedSection == null) {
                              _activeDonutIndex = -1;
                              return;
                            }
                            _activeDonutIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 4,
                      centerSpaceRadius: 50,
                      sections: [
                        _buildPieSection(0, breakdown.critical.toDouble(), total, AppColors.critical, 'Critical'),
                        _buildPieSection(1, breakdown.high.toDouble(), total, const Color(0xFFF97316), 'High'),
                        _buildPieSection(2, breakdown.medium.toDouble(), total, AppColors.warning, 'Medium'),
                        _buildPieSection(3, breakdown.low.toDouble(), total, AppColors.secondary, 'Low'),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLegendItem('Critical', breakdown.critical, AppColors.critical),
                    _buildLegendItem('High', breakdown.high, const Color(0xFFF97316)),
                    _buildLegendItem('Medium', breakdown.medium, AppColors.warning),
                    _buildLegendItem('Low', breakdown.low, AppColors.secondary),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  PieChartSectionData _buildPieSection(int index, double value, double total, Color color, String title) {
    final isTouched = index == _activeDonutIndex;
    final radius = isTouched ? 28.0 : 20.0;
    final percentage = (value / total * 100).toStringAsFixed(0);

    return PieChartSectionData(
      color: color,
      value: value,
      title: isTouched ? '$percentage%' : '',
      radius: radius,
      titleStyle: AppTextStyles.labelMedium(color: Colors.white, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildLegendItem(String label, int value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.bodySmall(color: AppColors.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            value.toString(),
            style: AppTextStyles.labelMedium(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  // 7-Day Dispatch Activity (Bar Chart)
  Widget _buildSevenDayDispatchActivity() {
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
            '7-Day Dispatch Volume',
            style: AppTextStyles.heading4(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 20,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        const style = TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600);
                        Widget text;
                        switch (value.toInt()) {
                          case 0: text = const Text('Mon', style: style); break;
                          case 1: text = const Text('Tue', style: style); break;
                          case 2: text = const Text('Wed', style: style); break;
                          case 3: text = const Text('Thu', style: style); break;
                          case 4: text = const Text('Fri', style: style); break;
                          case 5: text = const Text('Sat', style: style); break;
                          case 6: text = const Text('Sun', style: style); break;
                          default: text = const Text('', style: style); break;
                        }
                        return SideTitleWidget(axisSide: meta.axisSide, child: text);
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 5,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(color: AppColors.textMuted, fontSize: 9),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  horizontalInterval: 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: AppColors.border.withValues(alpha: 0.5), strokeWidth: 1);
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _buildBarGroup(0, 12),
                  _buildBarGroup(1, 15),
                  _buildBarGroup(2, 8),
                  _buildBarGroup(3, 17),
                  _buildBarGroup(4, 11),
                  _buildBarGroup(5, 5),
                  _buildBarGroup(6, 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: AppColors.primaryAccent,
          width: 14,
          borderRadius: BorderRadius.circular(4),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 20,
            color: AppColors.border.withValues(alpha: 0.3),
          ),
        ),
      ],
    );
  }

  // Crisis Type Breakdown
  Widget _buildCrisisBreakdown(dynamic summary) {
    final trends = summary.emergencyTrends;
    int maxVal = 1;
    trends.forEach((k, v) {
      if (v > maxVal) maxVal = v;
    });

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
            'Breakdown by Crisis Type',
            style: AppTextStyles.heading4(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          _buildCrisisRow('Food Assistance', trends['food'] ?? 0, maxVal, AppColors.primaryAccent),
          _buildCrisisRow('Medical Emergency', trends['medical'] ?? 0, maxVal, AppColors.critical),
          _buildCrisisRow('Education Support', trends['education'] ?? 0, maxVal, AppColors.secondary),
          _buildCrisisRow('Emergency Cash', trends['emergency_cash'] ?? 0, maxVal, AppColors.warning),
          _buildCrisisRow('Flood Relief', trends['flood_relief'] ?? 0, maxVal, const Color(0xFFA855F7)),
        ],
      ),
    );
  }

  Widget _buildCrisisRow(String label, int val, int maxVal, Color color) {
    final percent = val / maxVal;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppTextStyles.bodyMedium(color: AppColors.textPrimary)),
              Text(val.toString(), style: AppTextStyles.labelMedium(color: color)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }

  // Time Sensitivity rings/pies
  Widget _buildTimeSensitivityRings(dynamic summary) {
    final today = summary.timeMetrics.todayCases;
    final weekly = summary.timeMetrics.weeklyCases;
    final monthly = summary.timeMetrics.monthlyCases;

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
            'Urgency Level Shares',
            style: AppTextStyles.heading4(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildUrgencyIndicator('Immediate', today.toString(), AppColors.critical),
              _buildUrgencyIndicator('Today', weekly.toString(), AppColors.warning),
              _buildUrgencyIndicator('This Week', monthly.toString(), AppColors.secondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUrgencyIndicator(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.2), width: 6),
          ),
          alignment: Alignment.center,
          child: Text(
            value,
            style: AppTextStyles.heading3(color: color),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTextStyles.bodySmall(color: AppColors.textMuted),
        ),
      ],
    );
  }

  // Recent Activity Feed
  Widget _buildRecentActivitySection() {
    final casesProvider = Provider.of<CasesProvider>(context);
    final recentDispatches = casesProvider.cases
        .where((c) => c.dispatchStatus.toUpperCase() == 'DISPATCHED')
        .take(3)
        .toList();

    if (recentDispatches.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            const Icon(Icons.verified_outlined, color: AppColors.textMuted, size: 36),
            const SizedBox(height: 8),
            Text(
              'No recently dispatched cases',
              style: AppTextStyles.bodyMedium(color: AppColors.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentDispatches.length,
      itemBuilder: (context, index) {
        final caseItem = recentDispatches[index];
        final urgencyColor = AppColors.severityColor(caseItem.severityLevel);

        return Card(
          color: AppColors.surfaceElevated,
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: urgencyColor.withValues(alpha: 0.3), width: 1),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.crisisTypeColor(caseItem.crisisType).withValues(alpha: 0.15),
              child: Icon(
                StatusHelpers.getCrisisTypeIcon(caseItem.crisisType),
                color: AppColors.crisisTypeColor(caseItem.crisisType),
              ),
            ),
            title: Text(
              caseItem.applicantName ?? 'Anonymous Applicant',
              style: AppTextStyles.labelMedium(color: AppColors.textPrimary),
            ),
            subtitle: Text(
              '${caseItem.locationNormalized ?? "Unknown location"} • ID: ${caseItem.ticketId ?? "N/A"}',
              style: AppTextStyles.bodySmall(color: AppColors.textMuted),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'DISPATCHED',
                style: AppTextStyles.labelSmall(color: AppColors.primaryAccent),
              ),
            ),
          ),
        );
      },
    );
  }
}
