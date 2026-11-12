import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_localizations.dart';
import '../services/language_service.dart';
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
    // Rebuild when the user switches language.
    LanguageService.instance.addListener(_onLangChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Api.instance.refreshMe().then((_) {
        if (mounted) setState(() {});
      }).catchError((_) {});
    });
  }

  @override
  void dispose() {
    LanguageService.instance.removeListener(_onLangChanged);
    super.dispose();
  }

  void _onLangChanged() => setState(() {});

  Future<void> _listOil() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const ListingFormScreen()));
    if (saved == true) _changed();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
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

    final navLabels = [
      loc.t('nav.home'),
      loc.t('nav.my_oil'),
      loc.t('nav.impact'),
      loc.t('nav.profile'),
    ];

    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      floatingActionButton: _tab == 0
          ? FloatingActionButton.extended(
              onPressed: _listOil,
              backgroundColor: AppColors.ink,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text(loc.t('home.list_oil'), style: const TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.water_drop_outlined),
            selectedIcon: const Icon(Icons.water_drop_rounded),
            label: navLabels[0],
          ),
          NavigationDestination(
            icon: const Icon(Icons.oil_barrel_outlined),
            selectedIcon: const Icon(Icons.oil_barrel_rounded),
            label: navLabels[1],
          ),
          NavigationDestination(
            icon: const Icon(Icons.eco_outlined),
            selectedIcon: const Icon(Icons.eco_rounded),
            label: navLabels[2],
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded),
            label: navLabels[3],
          ),
        ],
      ),
    );
  }
}
