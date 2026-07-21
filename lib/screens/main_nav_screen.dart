// ============================================================
// screens/main_nav_screen.dart  –  Slide Drawer Navigation Shell
// ============================================================
// This is the persistent shell that holds all five main tabs.
// Switching tabs does NOT rebuild the screen content that was
// already loaded — IndexedStack keeps all tabs alive in memory
// so the user's scroll position is preserved.
//
// Navigation is a slide-out Drawer (rather than a bottom tab bar).
// Each tab screen gets a menu button wired to open this Drawer via
// a GlobalKey<ScaffoldState>, since they're nested inside their own
// Scaffolds and can't reach this one through Scaffold.of(context).
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/providers.dart';
import '../utils/utils.dart';
import 'dashboard_screen.dart';
import 'income_screen.dart';
import 'expense_screen.dart';
import 'sales_screen.dart';
import 'more_screen.dart';

class MainNavScreen extends StatefulWidget {
  const MainNavScreen({super.key});

  @override
  State<MainNavScreen> createState() => _MainNavScreenState();
}

class _MainNavScreenState extends State<MainNavScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Tracks which tab is currently selected (0 = Dashboard)
  int _currentIndex = 0;

  static const _labels = ['Home', 'Record Income', 'Record Expenses', 'Record Sales', 'More'];
  static const _icons = [
    Icons.dashboard_outlined,
    Icons.add_circle_outline,
    Icons.remove_circle_outline,
    Icons.point_of_sale_outlined,
    Icons.grid_view_outlined,
  ];
  static const _activeIcons = [
    Icons.dashboard,
    Icons.add_circle,
    Icons.remove_circle,
    Icons.point_of_sale,
    Icons.grid_view,
  ];

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  void _selectTab(int index) {
    setState(() => _currentIndex = index);
    Navigator.pop(context); // close the drawer
  }

  // The five main screens of the app. Built fresh each time (not
  // const) since each now needs the _openDrawer callback wired in.
  List<Widget> get _screens => [
        DashboardScreen(onMenuTap: _openDrawer),
        IncomeScreen(onMenuTap: _openDrawer),
        ExpenseScreen(onMenuTap: _openDrawer),
        SalesScreen(onMenuTap: _openDrawer),
        MoreScreen(onMenuTap: _openDrawer),
      ];

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;

    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(color: AppColors.primary),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CircleAvatar(
                      radius: 26,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.business, color: Colors.white),
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
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _labels.length,
                  itemBuilder: (_, index) {
                    final isSelected = index == _currentIndex;
                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: AppColors.primaryLight,
                      leading: Icon(
                        isSelected ? _activeIcons[index] : _icons[index],
                        color: isSelected ? AppColors.primary : AppColors.textMuted,
                      ),
                      title: Text(
                        _labels[index],
                        style: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      onTap: () => _selectTab(index),
                    );
                  },
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
}
