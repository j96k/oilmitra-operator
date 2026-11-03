import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../screens/impact_screen.dart';
import '../screens/listings_screen.dart';
import '../screens/profile_screen.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'admin_home.dart';
import 'admin_login_screen.dart';
import 'admin_pickups_screen.dart';

/// The operator's console. On phones it behaves like a focused field app; on a
/// laptop or desktop browser it switches to a rail so the radar and lists get
/// the whole width of the screen.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;
  int _version = 0;

  void _changed() => setState(() => _version++);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Api.instance.refreshMe().then((_) {
        if (mounted) setState(() {});
      }).catchError((_) {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      AdminHome(
        key: ValueKey('admin-radar$_version'),
        onSeeAll: () => setState(() => _tab = 1),
        onProfile: () => setState(() => _tab = 4),
      ),
      ListingsScreen(key: ValueKey('admin-loads$_version'), mode: ListingsMode.admin, onChanged: _changed),
      AdminPickupsScreen(key: ValueKey('admin-pickups$_version'), onChanged: _changed),
      ImpactScreen(key: ValueKey('admin-impact$_version')),
      ProfileScreen(loginBuilder: (_) => const AdminLoginScreen()),
    ];

    const destinations = [
      _Destination(icon: Icons.radar_rounded, label: 'Radar'),
      _Destination(icon: Icons.inventory_2_outlined, selectedIcon: Icons.inventory_2_rounded, label: 'Loads'),
      _Destination(icon: Icons.local_shipping_outlined, selectedIcon: Icons.local_shipping_rounded, label: 'Pickups'),
      _Destination(icon: Icons.eco_outlined, selectedIcon: Icons.eco_rounded, label: 'Impact'),
      _Destination(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Profile'),
    ];

    final width = MediaQuery.sizeOf(context).width;
    final body = IndexedStack(index: _tab, children: pages);

    if (width >= 900) {
      return Scaffold(
        body: Row(children: [
          SafeArea(
            right: false,
            child: NavigationRail(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              extended: width >= 1180,
              backgroundColor: Colors.white,
              indicatorColor: AppColors.amberSoft,
              selectedIconTheme: const IconThemeData(color: AppColors.ink),
              unselectedIconTheme: const IconThemeData(color: AppColors.muted),
              selectedLabelTextStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.ink),
              unselectedLabelTextStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: AppColors.muted),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(13)),
                  child: const Center(child: DropMark(size: 22)),
                ),
              ),
              destinations: [
                for (final d in destinations)
                  NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon ?? d.icon),
                    label: Text(d.label),
                  ),
              ],
            ),
          ),
          const VerticalDivider(width: 1, color: AppColors.line),
          Expanded(child: body),
        ]),
      );
    }

    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon ?? d.icon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _Destination {
  const _Destination({required this.icon, required this.label, this.selectedIcon});
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
}
