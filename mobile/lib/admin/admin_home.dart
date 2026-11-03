import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/listing_card.dart';
import '../widgets/oil_map.dart';
import '../screens/listing_detail_screen.dart';

class AdminHome extends StatefulWidget {
  const AdminHome({super.key, required this.onSeeAll, this.onProfile});
  final VoidCallback onSeeAll;
  final VoidCallback? onProfile;

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  Dashboard? _data;
  String? _error;
  bool _loading = true;
  LatLng? _center;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      final user = Api.instance.user;
      _center ??= await Api.instance.areaCenter(user?.city);
      final d = await Api.instance.dashboard(lat: _center?.lat, lng: _center?.lng);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the oil radar.';
        _loading = false;
      });
    }
  }

  Future<void> _open(OilListing l) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: l.id)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.amberDeep));
    }
    if (_data == null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No connection',
        subtitle: _error,
        action: FilledButton(onPressed: _load, child: const Text('Try again')),
      );
    }
    final d = _data!;
    final user = Api.instance.user;
    final pins = d.nearby.where((l) => l.hasLocation).map((l) => MapPin(
          lat: l.lat!,
          lng: l.lng!,
          label: '${litres(l.approxLiters).replaceAll(' L', '')}L · ${money(l.estValue)}',
          id: l.id,
          highlight: true,
        )).toList();

    return RefreshIndicator(
      color: AppColors.amberDeep,
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: AppColors.amberSoft, borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.radar_rounded, size: 21, color: AppColors.amberDeep),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('OIL RADAR',
                        style: TextStyle(fontSize: 9.5, letterSpacing: 1.5, fontWeight: FontWeight.w800, color: AppColors.amberDeep)),
                    Text(user?.city == null ? 'Nearby loads' : 'Nearby loads · ${user!.city}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  ]),
                ),
                Avatar(name: user?.name ?? '?', url: user?.avatarUrl, size: 40),
              ]),
            ),
          ),
          RateTicker(rates: d.rates),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Stack(children: [
              OilMap(
                height: 268,
                pins: pins,
                center: _center,
                showRadar: true,
                myLocation: true,
                onPinTap: (p) {
                  final l = d.nearby.firstWhere((x) => x.id == p.id, orElse: () => d.nearby.first);
                  _open(l);
                },
              ),
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.ink.withValues(alpha: 0.88),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(children: [
                    const Icon(Icons.water_drop_rounded, size: 13, color: AppColors.gold),
                    const SizedBox(width: 5),
                    Text('${d.openCount} loads live',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: GestureDetector(
                  onTap: widget.onSeeAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30), boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10),
                    ]),
                    child: const Row(children: [
                      Icon(Icons.view_list_rounded, size: 14, color: AppColors.ink),
                      SizedBox(width: 5),
                      Text('List view', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Expanded(child: _RadarStat(label: 'Live loads', value: '${d.openCount}', icon: Icons.bolt_rounded, color: AppColors.open)),
              const SizedBox(width: 8),
              Expanded(child: _RadarStat(label: 'Scheduled', value: '${d.scheduledCount}', icon: Icons.event_available_rounded, color: AppColors.claimed)),
              const SizedBox(width: 8),
              Expanded(child: _RadarStat(label: 'Collected', value: d.impact.liters.toStringAsFixed(0), unit: 'L', icon: Icons.verified_rounded, color: AppColors.olive)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(20)),
              child: Row(children: [
                const Icon(Icons.route_rounded, size: 18, color: AppColors.gold),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    d.scheduledCount == 0
                        ? 'Claim a load to start today\'s route. Suppliers are waiting.'
                        : '${d.scheduledCount} pickup${d.scheduledCount == 1 ? '' : 's'} on your route. Tap a load for directions and contact.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 11.5, height: 1.4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(d.moneyTotal > 0 ? money(d.moneyTotal) : '—',
                    style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 13)),
              ]),
            ),
          ),
          SectionHead('Closest to you', action: 'See all', onAction: widget.onSeeAll),
          if (d.nearby.isEmpty)
            const EmptyState(
              icon: Icons.radar_rounded,
              title: 'No open loads yet',
              subtitle: 'New oil is listed every day. Pull down to refresh the radar.',
            )
          else
            ...d.nearby.map((l) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: ListingCard(listing: l, onTap: () => _open(l)),
                )),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _RadarStat extends StatelessWidget {
  const _RadarStat({required this.label, required this.value, required this.icon, required this.color, this.unit});
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
          Flexible(
            child: Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
          ),
          if (unit != null) ...[
            const SizedBox(width: 2),
            Text(unit!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.muted)),
          ],
        ]),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
