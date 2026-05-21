// lib/shared/widgets/error_state.dart

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ErrorState extends StatelessWidget {
  final String title;
  final String errorMessage;
  final VoidCallback onRetry;
  final IconData icon;

  const ErrorState({
    super.key,
    this.title = 'An Error Occurred',
    required this.errorMessage,
    required this.onRetry,
    this.icon = Icons.gpp_bad_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Container(
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.critical.withValues(alpha: 0.3),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.critical.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppColors.critical.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: AppColors.critical,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: AppTextStyles.heading4(color: AppColors.textPrimary),
                textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage,
              style: AppTextStyles.bodyMedium(color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 20),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.critical,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
