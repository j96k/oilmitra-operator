import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/listing_card.dart';
import 'listing_detail_screen.dart';

class SupplierHome extends StatefulWidget {
  const SupplierHome({super.key, required this.onList, required this.onSeeAll, this.onProfile});
  final VoidCallback onList;
  final VoidCallback onSeeAll;
  final VoidCallback? onProfile;

  @override
  State<SupplierHome> createState() => _SupplierHomeState();
}

class _SupplierHomeState extends State<SupplierHome> {
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
        _error = 'Could not load your dashboard.';
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
    return RefreshIndicator(
      color: AppColors.amberDeep,
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Header(user: user, onProfile: widget.onProfile),
          RateTicker(rates: d.rates),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _WalletCard(d: d, onList: widget.onList),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              Expanded(child: _MiniStat(label: 'Open loads', value: '${d.openCount}', icon: Icons.bolt_rounded, color: AppColors.open)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat(label: 'Scheduled', value: '${d.scheduledCount}', icon: Icons.event_available_rounded, color: AppColors.claimed)),
              const SizedBox(width: 8),
              Expanded(child: _MiniStat(label: 'Pickups', value: '${d.impact.pickups}', icon: Icons.verified_rounded, color: AppColors.olive)),
            ]),
          ),
          if (d.rates.isNotEmpty) ...[
            const SectionHead('Today\'s rate board', action: 'Benchmark'),
            SizedBox(
              height: 74,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: d.rates.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final r = d.rates[i];
                  return Container(
                    width: 112,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${oilEmoji(r.oilType)} ${oilLabel(r.oilType)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(money(r.price),
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.7)),
                      const Text('/ litre', style: TextStyle(fontSize: 9, color: AppColors.muted)),
                    ]),
                  );
                },
              ),
            ),
          ],
          SectionHead('Your oil', action: 'See all', onAction: widget.onSeeAll),
          if (d.myListings.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _EmptyListings(onList: widget.onList),
            )
          else
            ...d.myListings.map((l) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: ListingCard(listing: l, onTap: () => _open(l)),
                )),
          if (d.recent.isNotEmpty) ...[
            const SectionHead('Recent pickups'),
            ...d.recent.map((p) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: _PickupRow(pickup: p, onTap: () => _openById(p.listingId)),
                )),
          ],
          const SizedBox(height: 4),
          _ImpactTeaser(impact: d.impact, onTap: widget.onSeeAll),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Future<void> _openById(int id) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: id)));
    _load();
  }
}

class _Header extends StatelessWidget {
  const _Header({this.user, this.onProfile});
  final AppUser? user;
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 10),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(13)),
            child: const DropMark(size: 20, color: AppColors.gold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${greeting()},',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
              Text(user?.name ?? 'Your kitchen',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            ]),
          ),
          GestureDetector(
            onTap: onProfile,
            child: Row(children: [
              if (user?.city != null) ...[
                const Icon(Icons.location_on_rounded, size: 13, color: AppColors.muted),
                const SizedBox(width: 2),
                Text(user!.city!, style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
              ],
              Avatar(name: user?.name ?? '?', url: user?.avatarUrl, size: 40),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.d, required this.onList});
  final Dashboard d;
  final VoidCallback onList;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.ink, Color(0xFF2C3A23)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.22), blurRadius: 30, offset: const Offset(0, 14))],
      ),
      padding: const EdgeInsets.all(20),
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          right: -18,
          top: -34,
          child: Opacity(opacity: 0.1, child: DropMark(size: 130, color: AppColors.gold)),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('OIL WALLET',
                style: TextStyle(color: AppColors.gold, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('THIS MONTH', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            Text(money(d.moneyThisMonth),
                style: const TextStyle(color: Colors.white, fontSize: 44, height: 1, fontWeight: FontWeight.w800, letterSpacing: -2)),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('earned', style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ]),
          const SizedBox(height: 4),
          Text('${litres(d.litersThisMonth)} collected from your kitchen',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11.5)),
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.12)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: HeroStat(label: 'Total litres', value: litres(d.impact.liters).replaceAll(' L', ''), unit: 'L')),
            Expanded(child: HeroStat(label: 'CO₂ avoided', value: d.impact.co2Kg.toStringAsFixed(0), unit: 'kg')),
            Expanded(child: HeroStat(label: 'Pickups', value: '${d.impact.pickups}')),
          ]),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onList,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: AppColors.ink,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('List oil available'),
          ),
        ]),
      ]),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
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
        Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 9.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _EmptyListings extends StatelessWidget {
  const _EmptyListings({required this.onList});
  final VoidCallback onList;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.amberSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        const DropMark(size: 34),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Oil ready after service?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            SizedBox(height: 2),
            Text('List it once — our pickup team arranges collection.',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.35)),
          ]),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: onList,
          style: IconButton.styleFrom(backgroundColor: AppColors.ink, foregroundColor: Colors.white),
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
        ),
      ]),
    );
  }
}

class _PickupRow extends StatelessWidget {
  const _PickupRow({required this.pickup, this.onTap});
  final Pickup pickup;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: AppColors.forStatus(pickup.status).withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(AppColors.iconFor(pickup.status), size: 17, color: AppColors.forStatus(pickup.status)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pickup.status == 'scheduled' ? 'Pickup scheduled' : 'Pickup completed',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              Text(
                pickup.status == 'scheduled'
                    ? '${pickup.collectorName} · ${pickup.scheduledAt == null ? 'soon' : dayMonthTime(pickup.scheduledAt!)}'
                    : '${pickup.actualLiters ?? 0} L · ${pickup.collectorName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ]),
          ),
          if (pickup.amount != null)
            Text(money(pickup.amount!), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.muted),
        ]),
      ),
    );
  }
}

class _ImpactTeaser extends StatelessWidget {
  const _ImpactTeaser({required this.impact, required this.onTap});
  final Impact impact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.tealSoft, Color(0xFFF3F7E8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.teal.withValues(alpha: 0.18)),
        ),
        child: Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
            child: const Icon(Icons.eco_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${impact.co2Kg.toStringAsFixed(0)} kg CO₂e kept out of the drain',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, letterSpacing: -0.2)),
              const SizedBox(height: 3),
              Text('That\'s ${impact.biodieselL.toStringAsFixed(0)} L of biodiesel waiting to happen.',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted, height: 1.35)),
            ]),
          ),
          const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.teal),
        ]),
      ),
    );
  }
}
