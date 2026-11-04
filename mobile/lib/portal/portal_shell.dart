import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/server_dialog.dart';
import 'portal_loads.dart';
import 'portal_login_screen.dart';
import 'portal_operators.dart';
import 'portal_overview.dart';
import 'portal_rates.dart';
import 'portal_suppliers.dart';

class PortalShell extends StatefulWidget {
  const PortalShell({super.key});

  @override
  State<PortalShell> createState() => _PortalShellState();
}

class _PortalShellState extends State<PortalShell> {
  int _tab = 0;

  void _switchTab(int idx) {
    setState(() => _tab = idx);
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2622),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign out of myOilMitra?', style: TextStyle(color: Colors.white)),
        content: Text(
          'You are currently signed in as executive administrator "${Api.instance.user?.name ?? ''}".',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await Api.instance.logout();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PortalLoginScreen()),
        (_) => false,
      );
    }
  }

  Future<void> _serverSettings() async {
    final ok = await ServerAddressDialog.show(context);
    if (ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connected to ${Api.instance.baseUrl}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 900;

    final user = Api.instance.user;

    final screens = [
      PortalOverviewTab(onNavigateTab: _switchTab),
      const PortalLoadsTab(),
      const PortalRatesTab(),
      const PortalOperatorsTab(),
      const PortalSuppliersTab(),
    ];

    final destinations = const [
      NavigationRailDestination(
        icon: Icon(Icons.analytics_outlined),
        selectedIcon: Icon(Icons.analytics_rounded, color: AppColors.gold),
        label: Text('Overview'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(Icons.inventory_2_rounded, color: AppColors.gold),
        label: Text('All Loads'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.price_change_outlined),
        selectedIcon: Icon(Icons.price_change_rounded, color: AppColors.gold),
        label: Text('Rates'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.badge_outlined),
        selectedIcon: Icon(Icons.badge_rounded, color: AppColors.gold),
        label: Text('Operators'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.leaderboard_outlined),
        selectedIcon: Icon(Icons.leaderboard_rounded, color: AppColors.gold),
        label: Text('Suppliers'),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F1411),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131915),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
              ),
              child: const DropMark(size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'myOilMitra',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
              ),
              child: const Text(
                'SUPER ADMIN',
                style: TextStyle(color: AppColors.gold, fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 1),
              ),
            ),
          ],
        ),
        actions: [
          if (user != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: Text(
                  user.name,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          IconButton(
            onPressed: _serverSettings,
            icon: const Icon(Icons.tune_rounded, color: Colors.white70, size: 20),
            tooltip: 'Server Settings',
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
            tooltip: 'Sign Out',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          if (isDesktop)
            NavigationRail(
              selectedIndex: _tab,
              onDestinationSelected: _switchTab,
              backgroundColor: const Color(0xFF131915),
              labelType: NavigationRailLabelType.all,
              destinations: destinations,
              selectedLabelTextStyle: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 11),
              unselectedLabelTextStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11),
            ),
          Expanded(child: screens[_tab]),
        ],
      ),
      bottomNavigationBar: isDesktop
          ? null
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: _switchTab,
              backgroundColor: const Color(0xFF131915),
              indicatorColor: AppColors.gold.withValues(alpha: 0.2),
              destinations: const [
                NavigationDestination(icon: Icon(Icons.analytics_outlined), selectedIcon: Icon(Icons.analytics_rounded, color: AppColors.gold), label: 'Overview'),
                NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded, color: AppColors.gold), label: 'Loads'),
                NavigationDestination(icon: Icon(Icons.price_change_outlined), selectedIcon: Icon(Icons.price_change_rounded, color: AppColors.gold), label: 'Rates'),
                NavigationDestination(icon: Icon(Icons.badge_outlined), selectedIcon: Icon(Icons.badge_rounded, color: AppColors.gold), label: 'Operators'),
                NavigationDestination(icon: Icon(Icons.leaderboard_outlined), selectedIcon: Icon(Icons.leaderboard_rounded, color: AppColors.gold), label: 'Suppliers'),
              ],
            ),
    );
  }
}
