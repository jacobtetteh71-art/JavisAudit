// ============================================================
// providers/vat_provider.dart  –  VAT Threshold Tracker
// ============================================================
// This provider is the brain of JavisAudit's most important
// feature: monitoring annual turnover against the GRA's
// GHS 750,000 VAT registration threshold.
//
// It is called after EVERY income insert so the progress bar
// and notification logic stay up to date in real time.
// ============================================================

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../database/database_helper.dart';
import '../main.dart'; // to access the global notification plugin

class VatProvider extends ChangeNotifier {
  // ── State variables ────────────────────────────────────────
  double _annualTurnover = 0.0;  // Total income for the current year
  bool _isLoading = false;

  // ── Constants from the document spec ──────────────────────
  // GRA VAT registration threshold (Act 1151, 2023)
  static const double vatThreshold = 750000.0;

  // Alert thresholds as percentages
  static const double warn70  = 0.70; // 70% = GHS 525,000
  static const double warn90  = 0.90; // 90% = GHS 675,000
  static const double warn100 = 1.00; // 100% = GHS 750,000

  // ── Public getters ─────────────────────────────────────────
  double get annualTurnover => _annualTurnover;
  bool   get isLoading      => _isLoading;

  // What percentage of the threshold has been reached?
  // Capped at 1.0 (100%) so the progress bar doesn't overflow
  double get percentageReached =>
      (_annualTurnover / vatThreshold).clamp(0.0, 1.0);

  // Human-readable percentage string e.g. "65.3%"
  String get percentageString =>
      '${(percentageReached * 100).toStringAsFixed(1)}%';

  // What alert level are we at?
  // Returns: 'safe', 'warning', 'critical', 'exceeded'
  String get alertLevel {
    if (_annualTurnover >= vatThreshold) return 'exceeded';
    if (_annualTurnover >= vatThreshold * warn90) return 'critical';
    if (_annualTurnover >= vatThreshold * warn70) return 'warning';
    return 'safe';
  }

  // ── loadTurnover ───────────────────────────────────────────
  // Called on screen init and after every income insert.
  // Reads from SQLite and checks if a notification should fire.
  Future<void> loadTurnover() async {
    _isLoading = true;
    notifyListeners(); // Tell the UI "I'm loading"

    final int currentYear = DateTime.now().year;

    // Query the database for the sum of all income this year
    _annualTurnover = await DatabaseHelper.instance.getAnnualTurnover(currentYear);

    _isLoading = false;
    notifyListeners(); // Tell the UI "I'm done, refresh!"

    // After updating the turnover, check if we need to send
    // a local push notification
    await _checkAndNotify();
  }

  // ── _checkAndNotify ────────────────────────────────────────
  // Checks if the turnover has crossed 70%, 90%, or 100% and
  // fires a local notification if it hasn't been sent yet
  // this calendar year (stored in Hive).
  Future<void> _checkAndNotify() async {
    final box = Hive.box('settings');

    // ── Check 70% threshold ──────────────────────────────────
    if (_annualTurnover >= vatThreshold * warn70) {
      // Only send if we haven't sent this year yet
      final bool alreadySent = box.get('notif_sent_70', defaultValue: false);
      if (!alreadySent) {
        await _sendNotification(
          id: 70, // Unique ID for this notification
          title: '⚠️ VAT Warning – 70% Reached',
          body:
              'You have reached GH₵ ${_formatAmount(_annualTurnover)} '
              '(${percentageString} of the GHS 750,000 VAT threshold). '
              'Start preparing your records.',
        );
        // Mark as sent so it doesn't fire again this year
        await box.put('notif_sent_70', true);
      }
    }

    // ── Check 90% threshold ──────────────────────────────────
    if (_annualTurnover >= vatThreshold * warn90) {
      final bool alreadySent = box.get('notif_sent_90', defaultValue: false);
      if (!alreadySent) {
        await _sendNotification(
          id: 90,
          title: '🚨 VAT Critical – 90% Reached',
          body:
              'You are at ${percentageString} of the GRA VAT threshold. '
              'Contact the Ghana Revenue Authority now: 0800-900-110.',
        );
        await box.put('notif_sent_90', true);
      }
    }

    // ── Check 100% threshold ─────────────────────────────────
    if (_annualTurnover >= vatThreshold) {
      final bool alreadySent = box.get('notif_sent_100', defaultValue: false);
      if (!alreadySent) {
        await _sendNotification(
          id: 100,
          title: '🔴 VAT Registration Required!',
          body:
              'You have crossed GH₵ 750,000. You MUST register for VAT '
              'with the GRA within 30 days or face penalties.',
        );
        await box.put('notif_sent_100', true);
      }
    }
  }

  // ── _sendNotification ──────────────────────────────────────
  // Sends a local Android push notification.
  // 'id' must be unique per notification type so Android can
  // update/dismiss them individually.
  Future<void> _sendNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    // Android-specific notification channel settings
    // 'high' importance = the notification makes a sound and
    // appears as a heads-up banner
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'vat_channel',       // Channel ID (must be unique per app)
      'VAT Alerts',        // Channel name shown in Android settings
      channelDescription:  'Alerts for GRA VAT threshold progress',
      importance:          Importance.high,
      priority:            Priority.high,
      color:               Color(0xFF0F4C2A), // Green notification icon tint
    );

    const NotificationDetails details =
        NotificationDetails(android: androidDetails);

    // Show the notification using the global plugin from main.dart
    await flutterLocalNotificationsPlugin.show(id, title, body, details);
  }

  // Simple number formatter: 525000.0 → "525,000.00"
  String _formatAmount(double amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    // Add commas every 3 digits to the integer part
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    return '$intPart.${parts[1]}';
  }
}
