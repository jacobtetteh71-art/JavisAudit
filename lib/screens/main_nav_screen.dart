// ============================================================
// screens/main_nav_screen.dart  –  Bottom Navigation Shell
// ============================================================
// This is the persistent shell that holds all five main tabs.
// Switching tabs does NOT rebuild the screen content that was
// already loaded — IndexedStack keeps all tabs alive in memory
// so the user's scroll position is preserved.
// ============================================================

import 'package:flutter/material.dart';

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
  // Tracks which tab is currently selected (0 = Dashboard)
  int _currentIndex = 0;

  // The five main screens of the app
  // These are created once and kept alive by IndexedStack
  final List<Widget> _screens = const [
    DashboardScreen(),  // Tab 0: Home / Dashboard
    IncomeScreen(),     // Tab 1: Record Income
    ExpenseScreen(),    // Tab 2: Record Expenses
    SalesScreen(),      // Tab 3: Record Sales
    MoreScreen(),       // Tab 4: Reports, VAT, Audit, Backup, Settings
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ── IndexedStack ──────────────────────────────────────
      // Unlike PageView, IndexedStack keeps all pages in the
      // widget tree. Only the active one is visible, but all
      // retain their state (scroll position, loaded data, etc.)
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      // ── Bottom Navigation Bar ─────────────────────────────
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        // onTap is called when the user taps a tab icon
        onTap: (index) => setState(() => _currentIndex = index),

        // 'fixed' keeps all labels visible (not just selected)
        type: BottomNavigationBarType.fixed,

        // Colours matching our brand palette
        selectedItemColor:   AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        backgroundColor:     Colors.white,

        // Font size for labels
        selectedFontSize:   11,
        unselectedFontSize: 11,

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'Income',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.remove_circle_outline),
            activeIcon: Icon(Icons.remove_circle),
            label: 'Expenses',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale_outlined),
            activeIcon: Icon(Icons.point_of_sale),
            label: 'Sales',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view),
            label: 'More',
          ),
        ],
      ),
    );
  }
}
