// lib/core/constants/app_text_styles.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Heading styles (Syne font)
  static TextStyle heading1({Color color = AppColors.textPrimary}) => GoogleFonts.syne(
        textStyle: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      );

  static TextStyle heading2({Color color = AppColors.textPrimary}) => GoogleFonts.syne(
        textStyle: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      );

  static TextStyle heading3({Color color = AppColors.textPrimary}) => GoogleFonts.syne(
        textStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      );

  static TextStyle heading4({Color color = AppColors.textPrimary}) => GoogleFonts.syne(
        textStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      );

  // Body styles (IBM Plex Sans)
  static TextStyle bodyLarge({Color color = AppColors.textPrimary}) => GoogleFonts.ibmPlexSans(
        textStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: color,
        ),
      );

  static TextStyle bodyMedium({Color color = AppColors.textPrimary}) => GoogleFonts.ibmPlexSans(
        textStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: color,
        ),
      );

  static TextStyle bodySmall({Color color = AppColors.textMuted}) => GoogleFonts.ibmPlexSans(
        textStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: color,
        ),
      );

  // Label styles
  static TextStyle labelMedium({Color color = AppColors.textPrimary, FontWeight fontWeight = FontWeight.w600}) => GoogleFonts.ibmPlexSans(
        textStyle: TextStyle(
          fontSize: 12,
          fontWeight: fontWeight,
          color: color,
        ),
      );

  static TextStyle labelSmall({Color color = AppColors.textMuted}) => GoogleFonts.ibmPlexSans(
        textStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      );

  // Monospace style for Ticket IDs (IBM Plex Mono)
  static TextStyle monospace({Color color = AppColors.secondary, double fontSize = 14, FontWeight fontWeight = FontWeight.w500}) => GoogleFonts.ibmPlexMono(
        textStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
        ),
      );
}
