// lib/features/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/dashboard_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoggingOut = false;

  void _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        title: Text(
          'Confirm Logout',
          style: AppTextStyles.heading4(color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to log out of RaahAI?',
          style: AppTextStyles.bodyMedium(color: AppColors.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.critical,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isLoggingOut = true);
      await authProvider.logout();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final dashboardProvider = Provider.of<DashboardProvider>(context);
    
    final ngo = authProvider.ngo;
    final ngoName = ngo?.name ?? 'NGO Partner';
    final email = ngo?.email ?? 'partner@raahai.org';
    
    // Use metrics from dashboard if available
    final totalAssigned = dashboardProvider.summary?.casesOverview.totalAssigned ?? 0;
    final dispatched = dashboardProvider.summary?.casesOverview.dispatched ?? 0;
    final active = dashboardProvider.summary?.casesOverview.active ?? 0;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoggingOut
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryAccent),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // NGO Identity Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceElevated,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryAccent.withValues(alpha: 0.02),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppColors.primaryAccent.withValues(alpha: 0.15),
                          child: Text(
                            ngoName.isNotEmpty ? ngoName[0].toUpperCase() : 'N',
                            style: AppTextStyles.heading1(color: AppColors.primaryAccent),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          ngoName,
                          style: AppTextStyles.heading3(color: AppColors.textPrimary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          email,
                          style: AppTextStyles.bodyMedium(color: AppColors.textMuted),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Operations Stats Grid
                  Text(
                    'Operational Impact',
                    style: AppTextStyles.heading4(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem('Total Managed', totalAssigned.toString(), AppColors.secondary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatItem('Dispatched', dispatched.toString(), AppColors.primaryAccent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatItem('Active Triage', active.toString(), AppColors.warning),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Focus Crisis Areas
                  Text(
                    'Focus Relief Categories',
                    style: AppTextStyles.heading4(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  ngo?.crisisTypes != null && ngo!.crisisTypes.isNotEmpty
                      ? Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ngo.crisisTypes.map((type) => _buildChip(type, AppColors.primaryAccent)).toList(),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildChip('Food Assistance', AppColors.primaryAccent),
                            _buildChip('Medical Assistance', AppColors.primaryAccent),
                            _buildChip('Disaster Relief', AppColors.primaryAccent),
                          ],
                        ),
                  const SizedBox(height: 24),

                  // Coverage Areas
                  Text(
                    'Coverage Locations',
                    style: AppTextStyles.heading4(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  ngo?.locations != null && ngo!.locations.isNotEmpty
                      ? Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ngo.locations.map((loc) => _buildChip(loc, AppColors.secondary)).toList(),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildChip('Karachi', AppColors.secondary),
                            _buildChip('Lahore', AppColors.secondary),
                            _buildChip('Sindh', AppColors.secondary),
                          ],
                        ),
                  const SizedBox(height: 32),

                  // Actions Section
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _handleLogout,
                      icon: const Icon(Icons.logout, size: 20),
                      label: const Text('Log Out Account'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.critical.withValues(alpha: 0.1),
                        foregroundColor: AppColors.critical,
                        elevation: 0,
                        side: const BorderSide(color: AppColors.critical, width: 1.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                ],
              ),
            ),
    );
  }

  Widget _buildStatItem(String label, String val, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            val,
            style: AppTextStyles.heading2(color: accentColor),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.labelSmall(color: AppColors.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildChip(String label, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelMedium(color: accentColor),
      ),
    );
  }
}
