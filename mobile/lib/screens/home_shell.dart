import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';
import 'impact_screen.dart';
import 'listing_form_screen.dart';
import 'listings_screen.dart';
import 'profile_screen.dart';
import 'supplier_home.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
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

  Future<void> _listOil() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const ListingFormScreen()));
    if (saved == true) _changed();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      SupplierHome(
        key: ValueKey('home$_version'),
        onList: _listOil,
        onSeeAll: () => setState(() => _tab = 1),
        onProfile: () => setState(() => _tab = 3),
      ),
      ListingsScreen(key: ValueKey('mine$_version'), onChanged: _changed, onList: _listOil),
      ImpactScreen(key: ValueKey('impact$_version')),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: _listOil,
              backgroundColor: AppColors.ink,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('List oil', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.water_drop_outlined), selectedIcon: Icon(Icons.water_drop_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.oil_barrel_outlined), selectedIcon: Icon(Icons.oil_barrel_rounded), label: 'My oil'),
          NavigationDestination(icon: Icon(Icons.eco_outlined), selectedIcon: Icon(Icons.eco_rounded), label: 'Impact'),
          NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'Profile'),
        ],
      ),
    );
  }
}
