// lib/features/home/home_shell.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/cases_provider.dart';
import '../../core/providers/dashboard_provider.dart';
import '../dashboard/dashboard_screen.dart';
import '../applications/applications_screen.dart';
import '../submit/submit_screen.dart';
import '../profile/profile_screen.dart';
import '../../shared/widgets/raahdo_app_bar.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  // The 4 Screens matching our tabs
  final List<Widget> _screens = [
    const DashboardScreen(),
    const ApplicationsScreen(),
    const SubmitScreen(),
    const ProfileScreen(),
  ];

  // Helper to get screen title for AppBar
  String _getScreenTitle(int index) {
    switch (index) {
      case 0:
        return 'Overview';
      case 1:
        return 'Applications';
      case 3:
        return 'NGO Profile';
      default:
        return '';
    }
  }

  @override
  void initState() {
    super.initState();
    // Prefetch data when entering HomeShell
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DashboardProvider>(context, listen: false).fetchSummary();
      Provider.of<CasesProvider>(context, listen: false).fetchCases(refresh: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final showAppBar = _currentIndex != 2; // Hide AppBar on Submit Screen (Tab index 2)
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    final casesProvider = Provider.of<CasesProvider>(context);

    // Get pending count: try from Cases list first, fallback to Dashboard summary pending stats
    int pendingCount = casesProvider.cases.where((c) => c.dispatchStatus.toUpperCase() == 'PENDING').length;
    if (pendingCount == 0) {
      pendingCount = dashboardProvider.summary?.casesOverview.pending ?? 0;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: showAppBar
          ? RaahDoAppBar(
              title: _getScreenTitle(_currentIndex),
            )
          : null,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(
            top: BorderSide(color: AppColors.border, width: 1.5),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.analytics_outlined, 'Dashboard'),
                _buildNavItem(1, Icons.assignment_outlined, 'Applications', badgeCount: pendingCount),
                _buildSubmitNavItem(),
                _buildNavItem(3, Icons.corporate_fare_outlined, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, {int badgeCount = 0}) {
    final isSelected = _currentIndex == index;
    final accentColor = index == 3 ? AppColors.secondary : AppColors.primaryAccent;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.15 : 1.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  child: Icon(
                    icon,
                    color: isSelected ? accentColor : AppColors.textMuted,
                    size: 24,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.critical,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : badgeCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.labelSmall(
                color: isSelected ? accentColor : AppColors.textMuted,
              ).copyWith(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitNavItem() {
    const index = 2;
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primaryAccent : AppColors.surfaceElevated,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.transparent : AppColors.border,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected 
                      ? AppColors.primaryAccent.withValues(alpha: 0.35) 
                      : AppColors.primaryAccent.withValues(alpha: 0.05),
                  blurRadius: isSelected ? 12 : 6,
                  spreadRadius: isSelected ? 2 : 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.add_box,
              color: isSelected ? AppColors.background : AppColors.primaryAccent,
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Submit Case',
            style: AppTextStyles.labelSmall(
              color: isSelected ? AppColors.primaryAccent : AppColors.textMuted,
            ).copyWith(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
