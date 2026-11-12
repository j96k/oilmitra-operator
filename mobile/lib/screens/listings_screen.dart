import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/listing_card.dart';
import 'listing_detail_screen.dart';
import 'listing_form_screen.dart';

enum ListingsMode { nearby, mine, admin }

class ListingsScreen extends StatefulWidget {
  const ListingsScreen({super.key, this.mode = ListingsMode.mine, this.onChanged, this.onList});
  final ListingsMode mode;
  final VoidCallback? onChanged;
  final VoidCallback? onList;

  @override
  State<ListingsScreen> createState() => _ListingsScreenState();
}

class _ListingsScreenState extends State<ListingsScreen> {
  final _search = TextEditingController();
  List<OilListing> _items = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';
  LatLng? _center;

  @override
  void initState() {
    super.initState();
    _load();
    _search.addListener(() => _load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final user = Api.instance.user;
      if (widget.mode == ListingsMode.nearby) {
        _center ??= await Api.instance.areaCenter(user?.city);
      }
      final items = await Api.instance.listings(
        q: _search.text.trim(),
        mine: widget.mode == ListingsMode.mine,
        scope: widget.mode == ListingsMode.admin ? 'all' : null,
        status: widget.mode != ListingsMode.nearby && _filter != 'all' ? _filter : null,
        lat: _center?.lat,
        lng: _center?.lng,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _open(OilListing l) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: l.id)));
    _load();
    widget.onChanged?.call();
  }

  Future<void> _add() async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const ListingFormScreen()));
    if (saved == true) {
      _load();
      widget.onChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final mine = widget.mode == ListingsMode.mine;
    final manage = widget.mode == ListingsMode.admin;
    final statuses = manage
        ? const ['all', 'open', 'claimed', 'collected', 'expired', 'cancelled']
        : const ['all', 'open', 'claimed', 'collected', 'expired'];
    return Scaffold(
      appBar: AppBar(
        title: Text(manage ? loc.t('listings.all_loads') : mine ? loc.t('nav.my_oil') : loc.t('listings.oil_radar')),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          if (mine)
            IconButton(onPressed: _add, icon: const Icon(Icons.add_circle_outline_rounded)),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: TextField(
            controller: _search,
            decoration: InputDecoration(
              hintText: manage
                  ? loc.t('listings.search_all')
                  : mine
                      ? loc.t('listings.search_my')
                      : loc.t('listings.search_nearby'),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _search.clear();
                        _load();
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
            ),
          ),
        ),
        if (mine || manage)
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in statuses)
                  Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: ChoiceChip(
                      label: Text(f == 'all' ? loc.t('listings.status_all') : statusLabel(f)),
                      selected: _filter == f,
                      onSelected: (_) {
                        setState(() => _filter = f);
                        _load();
                      },
                      showCheckmark: false,
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.amberDeep))
              : _error != null
                  ? EmptyState(
                      icon: Icons.wifi_off_rounded,
                      title: 'Could not load',
                      subtitle: _error,
                      action: FilledButton(onPressed: _load, child: const Text('Try again')),
                    )
                  : _items.isEmpty
                      ? EmptyState(
                          icon: mine
                              ? Icons.oil_barrel_rounded
                              : manage
                                  ? Icons.inventory_2_outlined
                                  : Icons.radar_rounded,
                          title: mine
                              ? loc.t('listings.no_loads')
                              : manage
                                  ? loc.t('listings.no_loads_found')
                                  : loc.t('listings.radar_clear'),
                          subtitle: mine
                              ? loc.t('listings.list_your_oil')
                              : manage
                                  ? loc.t('listings.try_another')
                                  : loc.t('listings.no_open_matches'),
                          action: mine
                              ? FilledButton.icon(
                                  onPressed: _add,
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('List oil available'),
                                )
                              : null,
                        )
                      : RefreshIndicator(
                          color: AppColors.amberDeep,
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                            itemCount: _items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => ListingCard(listing: _items[i], onTap: () => _open(_items[i])),
                          ),
                        ),
        ),
      ]),
    );
  }
}
