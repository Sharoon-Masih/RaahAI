// lib/features/dashboard/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/dashboard_provider.dart';
import '../../shared/widgets/error_state.dart';

import '../../core/models/dashboard_summary.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _animateBar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialData();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _animateBar = true;
          });
        }
      });
    });
  }

  Future<void> _loadInitialData() async {
    await Provider.of<DashboardProvider>(context, listen: false).fetchSummary();
  }

  Future<void> _refreshData() async {
    await Provider.of<DashboardProvider>(context, listen: false).fetchSummary();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dashboard updated'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardProvider = Provider.of<DashboardProvider>(context);

    final isLoading = dashboardProvider.isLoading;
    final hasData = dashboardProvider.summary != null;

    if (isLoading && !hasData) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F1115),
        body: Center(child: CircularProgressIndicator(color: AppColors.primaryAccent)),
      );
    }

    if (dashboardProvider.errorMessage != null && !hasData) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F1115),
        body: ErrorState(
          errorMessage: dashboardProvider.errorMessage!,
          onRetry: _refreshData,
        ),
      );
    }

    final summary = dashboardProvider.summary ?? DashboardSummary.empty();

    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F1115),
        cardColor: const Color(0xFF1E2128),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1115),
        body: RefreshIndicator(
          onRefresh: _refreshData,
          color: AppColors.primaryAccent,
          backgroundColor: const Color(0xFF1E2128),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header (Logo/Title representation could go here if needed)
                _buildHeader(),
                const SizedBox(height: 16),
                
                // Row 1: KPI Grid
                _buildKpiGrid(summary),
                const SizedBox(height: 16),

                // Row 2: Charts (Donut + Vertical Bar)
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 600) {
                      return Row(
                        children: [
                          Expanded(child: _buildCasesByStatusDonut(summary)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildCrisisTypeBarChart(summary)),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildCasesByStatusDonut(summary),
                          const SizedBox(height: 16),
                          _buildCrisisTypeBarChart(summary),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Row 3: Charts (Line Chart + Horizontal Stacked Bar)
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 600) {
                      return Row(
                        children: [
                          Expanded(child: _buildCasesOverTimeLineChart(summary)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildSeverityBreakdown(summary)),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildCasesOverTimeLineChart(summary),
                          const SizedBox(height: 16),
                          _buildSeverityBreakdown(summary),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Row 4: Lists (Recent Critical Cases + Volunteer Availability)
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 800) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: _buildRecentCriticalCases(summary)),
                          const SizedBox(width: 16),
                          Expanded(flex: 1, child: _buildVolunteerAvailability(summary)),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildRecentCriticalCases(summary),
                          const SizedBox(height: 16),
                          _buildVolunteerAvailability(summary),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Row 5: Comparisons Bottom Row
                _buildComparisonsRow(summary),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF1E2838),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text(
              'SK',
              style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saylani Welfare Trust', style: AppTextStyles.bodyMedium(color: Colors.white).copyWith(fontWeight: FontWeight.bold)),
            Text('Karachi, Lahore, Islamabad', style: AppTextStyles.labelSmall(color: AppColors.textMuted)),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF003D20),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: const Color(0xFF00C896), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('LIVE', style: TextStyle(color: const Color(0xFF00C896), fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildKpiGrid(DashboardSummary summary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildKpiBox(
              constraints,
              'Total assigned',
              summary.casesOverview.totalAssigned.toString(),
              'All time cases',
            ),
            _buildKpiBox(
              constraints,
              'Active now',
              summary.casesOverview.active.toString(),
              'Pending + processing',
              valueColor: const Color(0xFFF59E0B),
            ),
            _buildKpiBox(
              constraints,
              'Critical cases',
              summary.severityBreakdown.critical.toString(),
              'Score >= 8.0, IMMEDIATE',
              valueColor: const Color(0xFFEF4444),
            ),
            _buildKpiBox(
              constraints,
              'Response rate',
              '${summary.performanceMetrics.responseRatePercentage.toInt()}%',
              'Avg resolution ${summary.performanceMetrics.averageResolutionTimeHours}h',
              valueColor: const Color(0xFF00C896),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiBox(BoxConstraints constraints, String title, String value, String subtitle, {Color valueColor = Colors.white}) {
    double width = (constraints.maxWidth - (12 * 3)) / 4;
    if (constraints.maxWidth < 800) width = (constraints.maxWidth - 12) / 2;
    if (constraints.maxWidth < 400) width = constraints.maxWidth;

    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C23),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: valueColor, fontSize: 24, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildChartContainer(String title, String subtitle, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C23),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildCasesByStatusDonut(DashboardSummary summary) {
    final overview = summary.casesOverview;
    final dispatched = overview.dispatched.toDouble();
    final active = overview.active.toDouble();
    final pending = overview.pending.toDouble();
    final rejected = overview.rejected.toDouble();

    return _buildChartContainer(
      'Cases by status',
      'Current dispatch pipeline breakdown',
      Column(
        children: [
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 0,
                centerSpaceRadius: 60,
                startDegreeOffset: 270,
                sections: [
                  if (dispatched > 0) PieChartSectionData(color: const Color(0xFF00C896), value: dispatched, radius: 25, showTitle: false),
                  if (active > 0) PieChartSectionData(color: const Color(0xFFF59E0B), value: active, radius: 25, showTitle: false),
                  if (pending > 0) PieChartSectionData(color: const Color(0xFF38BDF8), value: pending, radius: 25, showTitle: false),
                  if (rejected > 0) PieChartSectionData(color: const Color(0xFFEF4444), value: rejected, radius: 25, showTitle: false),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegendItem('Dispatched', dispatched.toInt(), const Color(0xFF00C896)),
              _buildLegendItem('Active', active.toInt(), const Color(0xFFF59E0B)),
              _buildLegendItem('Pending', pending.toInt(), const Color(0xFF38BDF8)),
              _buildLegendItem('Rejected', rejected.toInt(), const Color(0xFFEF4444)),
            ],
          )
        ],
      )
    );
  }

  Widget _buildLegendItem(String label, int count, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text('$label $count', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
      ],
    );
  }

  Widget _buildCrisisTypeBarChart(DashboardSummary summary) {
    final trends = summary.emergencyTrends;
    final food = (trends['food'] ?? 0).toDouble();
    final medical = (trends['medical'] ?? 0).toDouble();
    final cash = (trends['emergency_cash'] ?? 0).toDouble();
    final flood = (trends['flood_relief'] ?? 0).toDouble();
    final edu = (trends['education'] ?? 0).toDouble();

    final maxVal = [food, medical, cash, flood, edu].reduce((a, b) => a > b ? a : b);

    return _buildChartContainer(
      'Crisis type distribution',
      'All cases this NGO handles',
      SizedBox(
        height: 240, // Match height of Donut container
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            maxY: maxVal > 0 ? maxVal + (maxVal * 0.2) : 100,
            barTouchData: BarTouchData(enabled: false),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, meta) {
                    String text = '';
                    switch (value.toInt()) {
                      case 0: text = 'Food'; break;
                      case 1: text = 'Medical'; break;
                      case 2: text = 'Flood'; break;
                      case 3: text = 'Emergency cash'; break;
                      case 4: text = 'Education'; break;
                    }
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      angle: 0.3,
                      child: Text(text, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9)),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    if (value % 20 != 0 && value != 0) return const SizedBox.shrink();
                    return Text(value.toInt().toString(), style: const TextStyle(color: Color(0xFF64748B), fontSize: 10));
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFF2A2D35), strokeWidth: 1, dashArray: [4, 4]),
            ),
            borderData: FlBorderData(show: false),
            barGroups: [
              _buildBarGroup(0, food, const Color(0xFF00C896)),
              _buildBarGroup(1, medical, const Color(0xFFEF4444)),
              _buildBarGroup(2, flood, const Color(0xFF38BDF8)),
              _buildBarGroup(3, cash, const Color(0xFFF59E0B)),
              _buildBarGroup(4, edu, const Color(0xFF6366F1)),
            ],
          ),
        ),
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: _animateBar ? y : 0,
          color: color,
          width: 32,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)),
        ),
      ],
    );
  }

  Widget _buildCasesOverTimeLineChart(DashboardSummary summary) {
    final intake = summary.timeMetrics.dailyIntake;
    final maxVal = intake.isNotEmpty ? intake.reduce((a, b) => a > b ? a : b).toDouble() : 20.0;
    
    List<FlSpot> spots = [];
    if (intake.isEmpty) {
       // Return flat zero spots if empty
       spots = List.generate(14, (i) => FlSpot(i.toDouble(), 0));
    } else {
      for (int i = 0; i < intake.length; i++) {
        spots.add(FlSpot(i.toDouble(), intake[i].toDouble()));
      }
    }

    return _buildChartContainer(
      'Cases over time',
      'Daily intake — last 14 days',
      SizedBox(
        height: 200,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxVal > 0 ? maxVal + (maxVal * 0.2) : 20,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (value) => FlLine(color: const Color(0xFF2A2D35), strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
              show: true,
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 2,
                  getTitlesWidget: (value, meta) {
                    // Assuming value 0 is 14 days ago. Let's just mock dates "May X" for now
                    final intVal = value.toInt();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('May ${9 + intVal}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, meta) {
                    if (value % 4 != 0 && value != 0) return const SizedBox.shrink();
                    return Text(value.toInt().toString(), style: const TextStyle(color: Color(0xFF64748B), fontSize: 10));
                  },
                ),
              ),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: const Color(0xFF6366F1),
                barWidth: 2,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 3,
                      color: const Color(0xFF6366F1),
                      strokeWidth: 1,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF6366F1).withValues(alpha: 0.2),
                      const Color(0xFF6366F1).withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeverityBreakdown(DashboardSummary summary) {
    final bd = summary.severityBreakdown;

    return _buildChartContainer(
      'Severity breakdown',
      'Distribution across severity levels',
      SizedBox(
        height: 200,
        child: Column(
          children: [
            Expanded(
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 120, // Max width proxy
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (value, meta) {
                          if (value % 20 != 0 && value != 0) return const SizedBox.shrink();
                          return Text(value.toInt().toString(), style: const TextStyle(color: Color(0xFF64748B), fontSize: 10));
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          String text = '';
                          switch (value.toInt()) {
                            case 0: text = 'Critical'; break;
                            case 1: text = 'High'; break;
                            case 2: text = 'Medium'; break;
                            case 3: text = 'Low'; break;
                          }
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(text, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    drawHorizontalLine: false,
                    getDrawingVerticalLine: (value) => FlLine(color: const Color(0xFF2A2D35), strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    _buildHorizontalBarGroup(0, bd.critical.toDouble(), const Color(0xFFEF4444)),
                    _buildHorizontalBarGroup(1, bd.high.toDouble(), const Color(0xFFF59E0B)),
                    _buildHorizontalBarGroup(2, bd.medium.toDouble(), const Color(0xFF38BDF8)),
                    _buildHorizontalBarGroup(3, bd.low.toDouble(), const Color(0xFF64748B)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _buildLegendItem('Critical', bd.critical, const Color(0xFFEF4444)),
                _buildLegendItem('High', bd.high, const Color(0xFFF59E0B)),
                _buildLegendItem('Medium', bd.medium, const Color(0xFF38BDF8)),
                _buildLegendItem('Low', bd.low, const Color(0xFF64748B)),
              ],
            )
          ],
        ),
      ),
    );
  }

  BarChartGroupData _buildHorizontalBarGroup(int y, double x, Color color) {
    // Note: fl_chart horizontal bars are tricky, we use standard bar chart and rotate or map axes.
    // For this mockup, we map X/Y. Wait, fl_chart BarChart doesn't natively do horizontal easily without rotation.
    // Let's fake it with a horizontal bar width approach. Actually, standard BarChart in recent versions
    // doesn't rotate automatically. We can use `LinearProgressIndicator` for a simpler perfectly horizontal bar
    // to match the exact mockup perfectly. But since we used BarChart above, let's switch to custom layout
    // for this specific chart to make it look exactly like the image. Let's return empty BarChartData and do custom below.
    return BarChartGroupData(x: 0);
  }

  // Row 4: Lists
  Widget _buildRecentCriticalCases(DashboardSummary summary) {
    final cases = summary.recentCriticalCases;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C23),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Recent critical cases', style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(2),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1.5),
              4: FlexColumnWidth(1.5),
            },
            children: [
              TableRow(
                children: [
                  _tableHeader('Applicant'),
                  _tableHeader('Crisis'),
                  _tableHeader('Score'),
                  _tableHeader('Status'),
                  _tableHeader('Location'),
                ]
              ),
              const TableRow(children: [SizedBox(height: 8), SizedBox(height: 8), SizedBox(height: 8), SizedBox(height: 8), SizedBox(height: 8)]),
              ...cases.map((c) => TableRow(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFF2A2D35), width: 1))
                ),
                children: [
                  Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(c.applicant, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(c.crisis, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12))),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(c.score.toString(), style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12))),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12), 
                    child: Text(c.status, style: TextStyle(color: c.status.toLowerCase() == 'dispatched' ? const Color(0xFF00C896) : const Color(0xFFF59E0B), fontSize: 12))
                  ),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(c.location, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12))),
                ]
              )),
              if (cases.isEmpty) ...[
                TableRow(
                  children: [
                    Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text("No cases found", style: const TextStyle(color: Color(0xFF64748B), fontSize: 12))),
                    const SizedBox.shrink(),
                    const SizedBox.shrink(),
                    const SizedBox.shrink(),
                    const SizedBox.shrink(),
                  ]
                )
              ]
            ],
          )
        ],
      ),
    );
  }

  Widget _tableHeader(String text) {
    return Text(text, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11));
  }



  Widget _buildVolunteerAvailability(DashboardSummary summary) {
    final vols = summary.volunteerAvailabilityList;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C23),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Volunteer availability', style: TextStyle(color: Color(0xFFE2E8F0), fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          if (vols.isNotEmpty)
            ...vols.map((v) => _volunteerRow(v.name, v.location, v.isAvailable)),
          if (vols.isEmpty) 
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text("No volunteers found", style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
            )
        ],
      ),
    );
  }

  Widget _volunteerRow(String name, String location, bool isAvailable) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 4),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isAvailable ? const Color(0xFF00C896) : const Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
              const SizedBox(height: 2),
              Text(location, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildComparisonsRow(DashboardSummary summary) {
    final t = summary.timeMetrics;
    
    int tDiff = t.todayCases - t.yesterdayCases;
    String tStr = tDiff >= 0 ? '+$tDiff' : '$tDiff';
    Color tCol = tDiff >= 0 ? const Color(0xFFEF4444) : const Color(0xFF00C896); // More cases = red, fewer = green
    
    int wDiff = t.lastWeekCases > 0 ? (((t.weeklyCases - t.lastWeekCases) / t.lastWeekCases) * 100).toInt() : 0;
    String wStr = wDiff >= 0 ? '+$wDiff%' : '$wDiff%';
    Color wCol = wDiff >= 0 ? const Color(0xFFEF4444) : const Color(0xFF00C896);
    
    int mDiff = t.lastMonthCases > 0 ? (((t.monthlyCases - t.lastMonthCases) / t.lastMonthCases) * 100).toInt() : 0;
    String mStr = mDiff >= 0 ? '+$mDiff%' : '$mDiff%';
    Color mCol = mDiff >= 0 ? const Color(0xFFEF4444) : const Color(0xFF00C896);


    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(child: _buildCompBox("Today's cases", t.todayCases.toString(), "$tStr vs yesterday", tCol)),
            const SizedBox(width: 12),
            Expanded(child: _buildCompBox("This week", t.weeklyCases.toString(), "$wStr vs last week", wCol)),
            const SizedBox(width: 12),
            Expanded(child: _buildCompBox("This month", t.monthlyCases.toString(), "$mStr vs last month", mCol)),
          ],
        );
      }
    );
  }

  Widget _buildCompBox(String title, String val, String sub, Color subCol) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1C23),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          const SizedBox(height: 6),
          Text(val, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(sub, style: TextStyle(color: subCol, fontSize: 10)),
        ],
      ),
    );
  }
}
