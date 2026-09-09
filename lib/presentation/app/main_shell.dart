import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../bills/bills_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../reports/reports_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/transactions_screen.dart';

/// Main app shell — bottom navigation across the 5 top-level destinations.
class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          DashboardScreen(),
          TransactionsScreen(),
          BillsScreen(),
          ReportsScreen(),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(LucideIcons.layoutGrid),
            selectedIcon: const Icon(LucideIcons.layoutGrid),
            label: l.navHome,
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.receipt),
            selectedIcon: const Icon(LucideIcons.receipt),
            label: l.navTransactions,
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.calendarClock),
            selectedIcon: const Icon(LucideIcons.calendarClock),
            label: l.navBills,
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.barChart3),
            selectedIcon: const Icon(LucideIcons.barChart3),
            label: l.navReports,
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.settings),
            selectedIcon: const Icon(LucideIcons.settings),
            label: l.navSettings,
          ),
        ],
      ),
    );
  }
}
