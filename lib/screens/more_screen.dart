// ============================================================
// screens/more_screen.dart  –  Hub Menu (Tab 5)
// ============================================================
// A simple menu screen that links out to the secondary screens:
// Reports, VAT Tracker, Year-End Audit, Backup/Restore, Settings.
// Keeping these off the main bottom nav keeps it to 5 clean tabs.
// ============================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/providers.dart';
import '../utils/utils.dart';
import 'vat_tracker_screen.dart';
import 'reports_screen.dart';
import 'analytics_screen.dart';
import 'audit_report_screen.dart';
import 'backup_screen.dart';
import 'settings_screen.dart';
import 'lock_screen.dart';
import 'customer_ledger_screen.dart';
import 'inventory_screen.dart';
import 'global_search_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    final hasPicture =
        profile?.profileImagePath != null && File(profile!.profileImagePath!).existsSync();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Profile summary card ─────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primaryDark,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white.withOpacity(0.15),
                  backgroundImage: hasPicture
                      ? FileImage(File(profile!.profileImagePath!))
                      : null,
                  child: hasPicture
                      ? null
                      : Text(
                          (profile?.businessName.isNotEmpty == true)
                              ? profile!.businessName[0].toUpperCase()
                              : 'J',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile?.businessName ?? 'Your Business',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        profile?.businessType ?? '',
                        style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          _menuTile(
            context,
            icon: Icons.search,
            iconColor: AppColors.primary,
            title: 'Search Everything',
            subtitle: 'Find any income, expense, or sale record',
            screen: const GlobalSearchScreen(),
          ),
          _menuTile(
            context,
            icon: Icons.people_alt_outlined,
            iconColor: AppColors.expense,
            title: 'Customer Ledger',
            subtitle: 'Who owes you money, at a glance',
            screen: const CustomerLedgerScreen(),
          ),
          _menuTile(
            context,
            icon: Icons.inventory_2_outlined,
            iconColor: AppColors.gold,
            title: 'Inventory',
            subtitle: 'Stock counts, linked to your sales',
            screen: const InventoryScreen(),
          ),
          _menuTile(
            context,
            icon: Icons.bar_chart,
            iconColor: AppColors.info,
            title: 'Financial Reports',
            subtitle: 'Weekly, monthly, and category breakdowns',
            screen: const ReportsScreen(),
          ),
          _menuTile(
            context,
            icon: Icons.insights_outlined,
            iconColor: AppColors.income,
            title: 'Analytics',
            subtitle: 'Compare income, expenses, and profit year over year',
            screen: const AnalyticsScreen(),
          ),
          _menuTile(
            context,
            icon: Icons.gpp_maybe_outlined,
            iconColor: AppColors.gold,
            title: 'VAT Tracker',
            subtitle: 'Monitor your GHS 750,000 threshold',
            screen: const VatTrackerScreen(),
          ),
          _menuTile(
            context,
            icon: Icons.picture_as_pdf_outlined,
            iconColor: AppColors.expense,
            title: 'Year-End Financial Report',
            subtitle: 'Generate a formal PDF for GRA or your bank',
            screen: const AuditReportScreen(),
          ),
          _menuTile(
            context,
            icon: Icons.backup_outlined,
            iconColor: AppColors.primary,
            title: 'Backup & Restore',
            subtitle: 'Protect your data with a JSON export',
            screen: const BackupScreen(),
          ),
          _menuTile(
            context,
            icon: Icons.settings_outlined,
            iconColor: AppColors.textMuted,
            title: 'Settings',
            subtitle: 'Edit your business profile',
            screen: const SettingsScreen(),
          ),

          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.expense,
                side: const BorderSide(color: AppColors.expense),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _confirmLogout(context),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ),

          const SizedBox(height: 20),
          Center(
            child: Text(
              'JavisAudit v1.1.0',
              style: TextStyle(color: AppColors.textLight, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // ── _confirmLogout: locks the app, no data is touched ─────
  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You will need your PIN (or backup password) to open the app again. '
          'Your data stays safely on this device.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout', style: TextStyle(color: AppColors.expense)),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    context.read<AuthProvider>().logout();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LockScreen()),
      (route) => false, // clear the whole navigation stack
    );
  }

  // ── _menuTile: reusable navigation row ─────────────────────
  Widget _menuTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget screen,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        trailing: const Icon(Icons.chevron_right, color: AppColors.textLight),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => screen),
          );
        },
      ),
    );
  }
}
