// ============================================================
// utils/app_colors.dart  –  Brand Colour Constants
// ============================================================
// Defining colours here (once) means if we ever rebrand,
// we change one file instead of searching the entire codebase.
// ============================================================

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppColors {
  // ── Primary brand colours (GRA-inspired green) ────────────
  static const Color primaryDark   = Color(0xFF0F4C2A); // Deep forest green
  static const Color primary       = Color(0xFF1A7A4A); // Mid green
  static const Color primaryLight  = Color(0xFFE8F5EE); // Very light green bg

  // ── Accent colours ────────────────────────────────────────
  static const Color gold          = Color(0xFFC97A00); // GHS gold/amber
  static const Color goldLight     = Color(0xFFFFF8E6); // Light amber bg

  // ── Semantic colours ──────────────────────────────────────
  static const Color income        = Color(0xFF1A7A4A); // Green = money in
  static const Color expense       = Color(0xFFB91C1C); // Red = money out
  static const Color expenseLight  = Color(0xFFFEF2F2); // Light red bg
  static const Color warning       = Color(0xFFC97A00); // Amber = caution
  static const Color info          = Color(0xFF1D4ED8); // Blue = info
  static const Color infoLight     = Color(0xFFEFF6FF); // Light blue bg

  // ── Neutral colours ───────────────────────────────────────
  static const Color surface       = Color(0xFFFFFFFF); // Card backgrounds
  static const Color background    = Color(0xFFF0F4F8); // Page background
  static const Color border        = Color(0xFFDDE3EC); // Dividers/borders
  static const Color textPrimary   = Color(0xFF1A2332); // Main body text
  static const Color textMuted     = Color(0xFF64748B); // Subtitle/hint text
  static const Color textLight     = Color(0xFF94A3B8); // Very faint text
}

// ============================================================
// utils/formatters.dart  –  Date & Currency Formatters
// ============================================================

class AppFormat {
  // Format a GHS amount: 1250.5 → "GH₵ 1,250.50"
  static String currency(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return 'GH₵ ${formatter.format(amount)}';
  }

  // Short currency without symbol: 1250.5 → "1,250.50"
  static String amount(double amount) {
    final formatter = NumberFormat('#,##0.00', 'en_US');
    return formatter.format(amount);
  }

  // Format a date string 'YYYY-MM-DD' → '15 Jun 2026'
  static String displayDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return DateFormat('d MMM yyyy').format(dt);
    } catch (_) {
      return isoDate; // return as-is if parsing fails
    }
  }

  // Today as 'YYYY-MM-DD' string — the format stored in SQLite
  static String today() {
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  // Format a DateTime to 'YYYY-MM-DD'
  static String dateToString(DateTime dt) {
    return DateFormat('yyyy-MM-dd').format(dt);
  }

  // Month name from number: '06' → 'June'
  static String monthName(String twoDigitMonth) {
    final months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final idx = int.tryParse(twoDigitMonth) ?? 0;
    return idx >= 1 && idx <= 12 ? months[idx] : twoDigitMonth;
  }

  // Short month: '06' → 'Jun'
  static String shortMonthName(String twoDigitMonth) {
    final months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final idx = int.tryParse(twoDigitMonth) ?? 0;
    return idx >= 1 && idx <= 12 ? months[idx] : twoDigitMonth;
  }
}
