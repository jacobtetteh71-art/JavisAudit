// ============================================================
// screens/main_nav_screen.dart  –  Slide Drawer Navigation Shell
// ============================================================
// This is the persistent shell that holds the four everyday
// screens. Switching between them does NOT rebuild content that
// was already loaded — IndexedStack keeps all of them alive in
// memory so the user's scroll position is preserved.
//
// The Drawer is the single, standard place every screen in the
// app lives — grouped the way most business/accounting apps
// organize a side menu: an Overview section, the everyday Record
// screens, Inventory & Customers, Reports & Insights, Tools, and
// Account actions at the bottom. This replaces the old pattern of
// a flat 5-tab list where the 5th tab ("More") just opened yet
// another full scrolling menu screen — everything is one level
// deep now.
//
// Each tab screen gets a menu button wired to open this Drawer via
// a GlobalKey<ScaffoldState>, since they're nested inside their own
// Scaffolds and can't reach this one through Scaffold.of(context).
// ============================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/providers.dart';
import '../utils/utils.dart';
import 'analytics_screen.dart';
import 'audit_report_screen.dart';
import 'backup_screen.dart';
import 'customer_ledger_screen.dart';
import 'dashboard_screen.dart';
import 'expense_screen.dart';
import 'global_search_screen.dart';
import 'income_screen.dart';
import 'inventory_screen.dart';
import 'lock_screen.dart';
import 'reports_screen.dart';
import 'sales_performance_screen.dart';
import 'sales_screen.dart';
import 'invoices_screen.dart';
import 'settings_screen.dart';
import 'sync_screen.dart';
import 'vat_tracker_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Tracks which of the four everyday screens is currently selected
  // (0 = Dashboard). Everything else in the drawer is a normal push.
  int _currentIndex = 0;

  static const _labels = ['Dashboard', 'Income', 'Expenses', 'Sales'];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.add_circle_outline,
    Icons.remove_circle_outline,
    Icons.point_of_sale_outlined,
  ];
  static const _activeIcons = [
    Icons.dashboard,
    Icons.add_circle,
    Icons.remove_circle,
    Icons.point_of_sale,
  ];

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  void _selectTab(int index) {
    setState(() => _currentIndex = index);
    Navigator.pop(context); // close the drawer
  }

  void _pushScreen(Widget screen) {
    Navigator.pop(context); // close the drawer first
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  // The four everyday screens. Built fresh each time (not const)
  // since each needs the _openDrawer callback wired in.
  List<Widget> get _screens => [
        DashboardScreen(onMenuTap: _openDrawer),
        IncomeScreen(onMenuTap: _openDrawer),
        ExpenseScreen(onMenuTap: _openDrawer),
        SalesScreen(onMenuTap: _openDrawer),
      ];

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    final hasPicture =
        profile?.profileImagePath != null && File(profile!.profileImagePath!).existsSync();

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Profile header ──────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: AppColors.primary),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white24,
                      backgroundImage: hasPicture ? FileImage(File(profile!.profileImagePath!)) : null,
                      child: hasPicture ? null : const Icon(Icons.business, color: Colors.white),
                    ),
                    const SizedBox(height: 10),
                    Text(profile?.businessName ?? 'JavisAudit',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    if (profile?.ownerName != null)
                      Text(profile!.ownerName,
                          style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: [
                    _sectionHeader('OVERVIEW'),
                    ..._tabTiles(0, 1),

                    _sectionHeader('RECORD'),
                    ..._tabTiles(1, 4),
                    _navTile(
                      icon: Icons.receipt_long_outlined,
                      label: 'Invoices',
                      onTap: () => _pushScreen(const InvoicesScreen()),
                    ),

                    _sectionHeader('INVENTORY & CUSTOMERS'),
                    _navTile(
                      icon: Icons.inventory_2_outlined,
                      label: 'Inventory',
                      onTap: () => _pushScreen(const InventoryScreen()),
                    ),
                    _navTile(
                      icon: Icons.people_alt_outlined,
                      label: 'Customer Ledger',
                      onTap: () => _pushScreen(const CustomerLedgerScreen()),
                    ),

                    _sectionHeader('REPORTS & INSIGHTS'),
                    _navTile(
                      icon: Icons.bar_chart,
                      label: 'Financial Reports',
                      onTap: () => _pushScreen(const ReportsScreen()),
                    ),
                    _navTile(
                      icon: Icons.insights_outlined,
                      label: 'Analytics',
                      onTap: () => _pushScreen(const AnalyticsScreen()),
                    ),
                    _navTile(
                      icon: Icons.insert_chart_outlined,
                      label: 'Sales Performance',
                      onTap: () => _pushScreen(const SalesPerformanceScreen()),
                    ),
                    _navTile(
                      icon: Icons.gpp_maybe_outlined,
                      label: 'VAT Tracker',
                      onTap: () => _pushScreen(const VatTrackerScreen()),
                    ),
                    _navTile(
                      icon: Icons.picture_as_pdf_outlined,
                      label: 'Year-End Financial Report',
                      onTap: () => _pushScreen(const AuditReportScreen()),
                    ),

                    _sectionHeader('TOOLS'),
                    _navTile(
                      icon: Icons.search,
                      label: 'Search Everything',
                      onTap: () => _pushScreen(const GlobalSearchScreen()),
                    ),
                    _navTile(
                      icon: Icons.cloud_sync_outlined,
                      label: 'Cloud Sync',
                      onTap: () => _pushScreen(const SyncScreen()),
                    ),
                    _navTile(
                      icon: Icons.backup_outlined,
                      label: 'Backup & Restore',
                      onTap: () => _pushScreen(const BackupScreen()),
                    ),

                    _sectionHeader('ACCOUNT'),
                    _navTile(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onTap: () => _pushScreen(const SettingsScreen()),
                    ),
                    _navTile(
                      icon: Icons.logout,
                      label: 'Logout',
                      iconColor: AppColors.expense,
                      labelColor: AppColors.expense,
                      onTap: () => _confirmLogout(context),
                    ),

                    const SizedBox(height: 12),
                    Center(
                      child: Text('JavisAudit v1.1.0', style: TextStyle(color: AppColors.textLight, fontSize: 11)),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // ── IndexedStack ──────────────────────────────────────
      // Unlike PageView, IndexedStack keeps all pages in the
      // widget tree. Only the active one is visible, but all
      // retain their state (scroll position, loaded data, etc.)
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
    );
  }

  // ── _confirmLogout: locks the app, no data is touched ─────
  Future<void> _confirmLogout(BuildContext context) async {
    Navigator.pop(context); // close the drawer first

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

  // Builds the tab tiles for a contiguous slice of _labels/_icons —
  // e.g. _tabTiles(0, 1) is just Dashboard; _tabTiles(1, 4) is
  // Income through Sales. endExclusive is exclusive, same as any
  // Dart range — _tabTiles(1, 3) would stop BEFORE index 3 (Sales)
  // and silently leave it out of whichever section calls it.
  List<Widget> _tabTiles(int start, int endExclusive) {
    return [
      for (int i = start; i < endExclusive; i++)
        _navTile(
          icon: _currentIndex == i ? _activeIcons[i] : _icons[i],
          label: _labels[i],
          selected: _currentIndex == i,
          onTap: () => _selectTab(i),
        ),
    ];
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textLight, letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
    Color? iconColor,
    Color? labelColor,
  }) {
    return ListTile(
      dense: true,
      selected: selected,
      selectedTileColor: AppColors.primaryLight,
      leading: Icon(icon, color: iconColor ?? (selected ? AppColors.primary : AppColors.textMuted), size: 22),
      title: Text(
        label,
        style: TextStyle(
          color: labelColor ?? (selected ? AppColors.primary : AppColors.textPrimary),
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          fontSize: 13.5,
        ),
      ),
      onTap: onTap,
    );
  }
}
