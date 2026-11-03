import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/oil_map.dart';
import 'listing_form_screen.dart';

class ListingDetailScreen extends StatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});
  final int listingId;

  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  OilListing? _listing;
  String? _error;
  bool _busy = false;
  LatLng? _center;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _center ??= await Api.instance.areaCenter(Api.instance.user?.city);
      final l = await Api.instance.listing(widget.listingId, lat: _center?.lat, lng: _center?.lng);
      if (!mounted) return;
      setState(() {
        _listing = l;
        _error = null;
        _busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _busy = false;
      });
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _open(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _snack('No app found to open that link.');
    } catch (_) {
      _snack('No app found to open that link.');
    }
  }

  Uri get _mapsUri {
    final l = _listing!;
    if (l.hasLocation) {
      return Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${l.lat},${l.lng}');
    }
    return Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(l.address)}');
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return _snack('No phone number added.');
    await _open(Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}'));
  }

  Future<void> _whatsapp(String? phone, String text) async {
    final n = waNumber(phone);
    if (n.isEmpty) return _snack('No phone number added.');
    await _open(Uri.parse('https://wa.me/$n?text=${Uri.encodeComponent(text)}'));
  }

  Future<void> _shareReceipt(Pickup p) async {
    final url = '${Api.instance.baseUrl}${p.receiptPath}';
    await _open(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(
      'OilMitra pickup receipt — ${p.actualLiters} L ${oilLabel(p.oilType)} for ${money(p.amount ?? 0)}.\n$url',
    )}'));
  }

  // ---------------- actions ----------------

  Future<void> _claim() async {
    final l = _listing!;
    DateTime when = l.availableFrom;
    final note = TextEditingController();
    final go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final options = <String, DateTime>{
          'In the window': l.availableFrom,
          'Today evening': DateTime.now().add(const Duration(hours: 4)),
          'Tomorrow morning': DateTime(DateTime.now().add(const Duration(days: 1)).year,
              DateTime.now().add(const Duration(days: 1)).month, DateTime.now().add(const Duration(days: 1)).day, 9),
        };
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Claim this pickup', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text('${litres(l.approxLiters)} · ${l.title}',
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 16),
            const Text('WHEN WILL YOU REACH?',
                style: TextStyle(fontSize: 9.5, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: AppColors.muted)),
            const SizedBox(height: 8),
            Wrap(spacing: 7, runSpacing: 7, children: [
              for (final e in options.entries)
                ChoiceChip(
                  label: Text(e.key),
                  selected: when == e.value,
                  showCheckmark: false,
                  onSelected: (_) => setS(() => when = e.value),
                ),
            ]),
            const SizedBox(height: 6),
            Text(dayMonthTime(when), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.olive)),
            const SizedBox(height: 14),
            TextField(
              controller: note,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Anything the supplier should know? (optional)'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.check_rounded, size: 19),
              label: const Text('Claim pickup'),
            ),
            const SizedBox(height: 6),
            const Text('The load is held for you. Call or WhatsApp the supplier before you go.',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 10, color: AppColors.muted)),
          ]),
        );
      }),
    );
    if (go != true) return;
    setState(() => _busy = true);
    try {
      await Api.instance.claim(l.id, scheduledAt: when, note: note.text);
      await _load();
      _snack('Pickup claimed. The load is held for you.');
    } on ApiException catch (e) {
      _snack(e.message);
      setState(() => _busy = false);
    }
  }

  Future<void> _collect() async {
    final l = _listing!;
    final liters = TextEditingController(text: l.approxLiters.toStringAsFixed(l.approxLiters % 1 == 0 ? 0 : 1));
    final rate = TextEditingController(text: l.ratePerLiter.toStringAsFixed(l.ratePerLiter % 1 == 0 ? 0 : 2));
    final notes = TextEditingController();
    double amount = l.approxLiters * l.ratePerLiter;
    final go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        void recalc() {
          final a = double.tryParse(liters.text) ?? 0;
          final b = double.tryParse(rate.text) ?? 0;
          setS(() => amount = a * b);
        }

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, MediaQuery.viewInsetsOf(ctx).bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Record pickup', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            const SizedBox(height: 4),
            Text('${l.supplierName} · ${l.title}', style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: liters,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => recalc(),
                  decoration: const InputDecoration(labelText: 'Actual litres', suffixText: 'L'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: rate,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => recalc(),
                  decoration: const InputDecoration(labelText: 'Rate', prefixText: '₹ ', suffixText: '/L'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.amberSoft, borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                const Text('Pay the supplier', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(money(amount), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
              ]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notes,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Notes / payment reference (optional)'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.verified_rounded, size: 19),
              label: const Text('Confirm pickup'),
            ),
            const SizedBox(height: 6),
            const Center(
              child: Text('A receipt is created and shared with the supplier.',
                  style: TextStyle(fontSize: 10, color: AppColors.muted)),
            ),
          ]),
        );
      }),
    );
    if (go != true) return;
    setState(() => _busy = true);
    try {
      final p = await Api.instance.collect(
        l.id,
        liters: double.tryParse(liters.text) ?? l.approxLiters,
        rate: double.tryParse(rate.text) ?? l.ratePerLiter,
        notes: notes.text,
      );
      await _load();
      if (!mounted) return;
      await _successSheet(p);
    } on ApiException catch (e) {
      _snack(e.message);
      setState(() => _busy = false);
    }
  }

  Future<void> _successSheet(Pickup p) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(24, 8, 24, MediaQuery.paddingOf(ctx).bottom + 22),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(color: AppColors.tealSoft, shape: BoxShape.circle),
            child: const Icon(Icons.verified_rounded, size: 40, color: AppColors.teal),
          ),
          const SizedBox(height: 14),
          const Text('Pickup recorded', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text('${p.actualLiters ?? 0} L · ${money(p.amount ?? 0)} paid to ${p.supplierName}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => _open(Uri.parse('${Api.instance.baseUrl}${p.receiptPath}')),
            icon: const Icon(Icons.receipt_long_rounded, size: 19),
            label: const Text('Open receipt'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _shareReceipt(p),
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Send on WhatsApp'),
          ),
        ]),
      ),
    );
  }

  Future<void> _release() async {
    final ok = await _confirm('Release this pickup?', 'The load goes back to the open list.');
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await Api.instance.release(_listing!.id);
      await _load();
      _snack('Pickup released.');
    } on ApiException catch (e) {
      _snack(e.message);
      setState(() => _busy = false);
    }
  }

  Future<void> _cancelListing() async {
    final ok = await _confirm('Cancel this listing?', 'It will no longer be visible to the OilMitra team.');
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await Api.instance.cancelListing(_listing!.id);
      await _load();
      _snack('Listing cancelled.');
    } on ApiException catch (e) {
      _snack(e.message);
      setState(() => _busy = false);
    }
  }

  Future<void> _deleteListing() async {
    final ok = await _confirm('Delete this listing?', 'This cannot be undone.');
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await Api.instance.deleteListing(_listing!.id);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      _snack(e.message);
      setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44), backgroundColor: AppColors.cancelled),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, continue'),
          ),
        ],
      ),
    );
    return r ?? false;
  }

  Future<void> _edit() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ListingFormScreen(existing: _listing)),
    );
    if (saved == true) _load();
  }

  Future<void> _review(Pickup p) async {
    int stars = 5;
    final comment = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: const Text('Rate the pickup team', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setS(() => stars = i),
                  icon: Icon(i <= stars ? Icons.star_rounded : Icons.star_border_rounded,
                      color: AppColors.amberDeep, size: 30),
                ),
            ]),
            const SizedBox(height: 6),
            TextField(controller: comment, maxLines: 2, decoration: const InputDecoration(hintText: 'A short note (optional)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Later')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send'),
            ),
          ],
        );
      }),
    );
    if (send != true) return;
    try {
      await Api.instance.reviewPickup(p.id, stars, comment.text);
      await _load();
      _snack('Thanks for the feedback.');
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_listing == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _error == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.amberDeep))
            : EmptyState(
                icon: Icons.wifi_off_rounded,
                title: 'Could not open this load',
                subtitle: _error,
                action: FilledButton(onPressed: _load, child: const Text('Try again')),
              ),
      );
    }
    final l = _listing!;
    final pickup = l.activePickup;
    final admin = Api.instance.user?.isAdmin ?? false;
    final canManage = admin
        ? (l.status == 'open' || l.status == 'claimed' || l.status == 'expired')
        : (l.isMine && (l.status == 'open' || l.status == 'claimed'));
    final bottom = _bottomBar(l, pickup);
    return Scaffold(
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 268,
          backgroundColor: AppColors.cream,
          surfaceTintColor: Colors.transparent,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: Material(
              color: Colors.white.withValues(alpha: 0.92),
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.arrow_back_rounded, size: 20, color: AppColors.ink),
              ),
            ),
          ),
          actions: [
            if (canManage)
              PopupMenuButton<String>(
                color: Colors.white,
                icon: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), shape: BoxShape.circle),
                  child: const Icon(Icons.more_horiz_rounded, size: 20, color: AppColors.ink),
                ),
                onSelected: (v) {
                  if (v == 'edit') _edit();
                  if (v == 'cancel') _cancelListing();
                  if (v == 'delete') _deleteListing();
                },
                itemBuilder: (_) => [
                  if (l.isMine && (l.status == 'open' || l.status == 'claimed'))
                    const PopupMenuItem(value: 'edit', child: Text('Edit listing')),
                  const PopupMenuItem(value: 'cancel', child: Text('Cancel listing')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            const SizedBox(width: 4),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(fit: StackFit.expand, children: [
              OilPhoto(l.photoUrl, height: 300, radius: 0, iconSize: 60),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x33000000), Color(0x00000000), Color(0x66000000)],
                    stops: [0, 0.4, 1],
                  ),
                ),
              ),
              Positioned(
                left: 16,
                bottom: 16,
                child: Row(children: [
                  StatusPill(l.status, light: true),
                  if (l.distanceKm != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(30)),
                      child: Text(
                        l.distanceKm! < 1 ? '${(l.distanceKm! * 1000).round()} m away' : '${l.distanceKm!.toStringAsFixed(1)} km away',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ]),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l.title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.2)),
                const SizedBox(height: 8),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(money(l.estValue),
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1.3)),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text('est. ${litres(l.approxLiters)} × ${money(l.ratePerLiter)}/L',
                        style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 14),
                _WindowCard(listing: l),
                const SizedBox(height: 14),
                _SectionRow(
                  icon: Icons.storefront_rounded,
                  title: l.supplierName,
                  subtitle: '${orgLabel(l.supplierOrgType)}${l.city == null ? '' : ' · ${l.city}'}',
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    _CircleAction(icon: Icons.call_rounded, onTap: () => _call(l.phone ?? l.supplierPhone)),
                    const SizedBox(width: 8),
                    _CircleAction(
                      icon: Icons.chat_rounded,
                      filled: true,
                      onTap: () => _whatsapp(
                        l.phone ?? l.supplierPhone,
                        'Hi ${l.supplierName}, I saw your ${l.oilType} oil listing (${litres(l.approxLiters)}) on OilMitra. Is it still available for pickup?',
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.line)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.place_rounded, size: 17, color: AppColors.olive),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          [l.address, l.area, l.city, l.pincode].where((x) => x != null && x.trim().isNotEmpty).join(', '),
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.45),
                        ),
                      ),
                    ]),
                    if (l.hasLocation) ...[
                      const SizedBox(height: 12),
                      OilMap(
                        height: 165,
                        center: LatLng(l.lat!, l.lng!),
                        zoom: 15,
                        pins: [MapPin(lat: l.lat!, lng: l.lng!, label: litres(l.approxLiters), highlight: true)],
                      ),
                    ],
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => _open(_mapsUri),
                      icon: const Icon(Icons.navigation_rounded, size: 17),
                      label: const Text('Directions in Google Maps'),
                    ),
                  ]),
                ),
                if (l.notes != null && l.notes!.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.oliveSoft.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.sticky_note_2_outlined, size: 17, color: AppColors.olive),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(l.notes!, style: const TextStyle(fontSize: 12.5, height: 1.45, color: AppColors.inkSoft)),
                      ),
                    ]),
                  ),
                ],
                if (pickup != null) ...[
                  const SizedBox(height: 18),
                  _PickupCard(
                    pickup: pickup,
                    isSupplier: l.isMine,
                    onReceipt: pickup.receiptPath == null
                        ? null
                        : () => _open(Uri.parse('${Api.instance.baseUrl}${pickup.receiptPath}')),
                    onShare: pickup.receiptPath == null ? null : () => _shareReceipt(pickup),
                    onReview: l.isMine && pickup.status == 'completed' && pickup.rating == null ? () => _review(pickup) : null,
                  ),
                ],
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: AppColors.tealSoft, borderRadius: BorderRadius.circular(18)),
                  child: Row(children: [
                    const Icon(Icons.eco_rounded, size: 18, color: AppColors.teal),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'About ${(l.approxLiters * 0.92).toStringAsFixed(1)} L of biodiesel and '
                        '${(l.approxLiters * 2.8).toStringAsFixed(0)} kg CO₂e saved when this load is collected.',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.teal, height: 1.4, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  const Icon(Icons.schedule_rounded, size: 12, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text('Listed ${timeAgo(l.createdAt)}', style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                ]),
              ]),
            ),
          ),
        ),
      ]),
      bottomNavigationBar: bottom,
    );
  }

  Widget? _bottomBar(OilListing l, Pickup? pickup) {
    Widget child;
    if (l.canClaim) {
      child = FilledButton.icon(
        onPressed: _busy ? null : _claim,
        style: FilledButton.styleFrom(backgroundColor: AppColors.amber, foregroundColor: AppColors.ink),
        icon: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
            : const Icon(Icons.local_shipping_rounded, size: 20),
        label: const Text('Claim this pickup'),
      );
    } else if (l.canCollect) {
      child = FilledButton.icon(
        onPressed: _busy ? null : _collect,
        style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
        icon: const Icon(Icons.scale_rounded, size: 20),
        label: const Text('Record pickup'),
      );
    } else if (!l.isMine && l.status == 'claimed' && pickup?.collectorId == Api.instance.user?.id) {
      child = OutlinedButton.icon(
        onPressed: _busy ? null : _release,
        icon: const Icon(Icons.undo_rounded, size: 18),
        label: const Text('Release this pickup'),
      );
    } else if (l.isMine && (l.status == 'open' || l.status == 'claimed')) {
      child = Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _busy ? null : _edit,
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Edit'),
          ),
        ),
        if (l.status == 'claimed') ...[
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _call(pickup?.collectorPhone),
              icon: const Icon(Icons.call_rounded, size: 18),
              label: const Text('Call OilMitra team'),
            ),
          ),
        ],
      ]);
    } else {
      return null;
    }
    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, MediaQuery.paddingOf(context).bottom + 10),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: child,
    );
  }
}

class _WindowCard extends StatelessWidget {
  const _WindowCard({required this.listing});
  final OilListing listing;

  @override
  Widget build(BuildContext context) {
    final expired = listing.status == 'expired';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: expired ? const Color(0xFFF7EFE0) : AppColors.amberSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: expired ? AppColors.expired.withValues(alpha: 0.3) : AppColors.amber.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(expired ? Icons.hourglass_bottom_rounded : Icons.event_available_rounded,
            size: 20, color: expired ? AppColors.expired : AppColors.amberDeep),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(expired ? 'PICKUP WINDOW CLOSED' : 'PICKUP WINDOW',
                style: TextStyle(
                  fontSize: 8.5,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                  color: expired ? AppColors.expired : AppColors.amberDeep,
                )),
            const SizedBox(height: 2),
            Text(windowLabel(listing.availableFrom, listing.availableTo),
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35)),
          ]),
        ),
      ]),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.icon, required this.title, this.subtitle, this.trailing});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.line)),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(color: AppColors.oliveSoft, shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: AppColors.olive),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
            if (subtitle != null)
              Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ]),
        ),
        ?trailing,
      ]),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap, this.filled = false});
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: filled ? AppColors.ink : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: filled ? AppColors.ink : AppColors.line),
        ),
        child: Icon(icon, size: 17, color: filled ? Colors.white : AppColors.ink),
      ),
    );
  }
}

class _PickupCard extends StatelessWidget {
  const _PickupCard({
    required this.pickup,
    required this.isSupplier,
    this.onReceipt,
    this.onShare,
    this.onReview,
  });
  final Pickup pickup;
  final bool isSupplier;
  final VoidCallback? onReceipt;
  final VoidCallback? onShare;
  final VoidCallback? onReview;

  @override
  Widget build(BuildContext context) {
    final done = pickup.status == 'completed';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(done ? Icons.verified_rounded : Icons.local_shipping_rounded,
              size: 18, color: done ? AppColors.teal : AppColors.claimed),
          const SizedBox(width: 7),
          Text(done ? 'Collected' : 'Pickup scheduled',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          const Spacer(),
          Text(isSupplier ? 'with ${pickup.collectorName}' : 'you',
              style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _MiniInfo(label: done ? 'Collected' : 'Scheduled',
              value: done ? dayMonthTime(pickup.collectedAt ?? pickup.createdAt) : dayMonthTime(pickup.scheduledAt ?? pickup.createdAt)),
          if (pickup.actualLiters != null) ...[
            const SizedBox(width: 18),
            _MiniInfo(label: 'Litres', value: '${pickup.actualLiters} L'),
          ],
          if (pickup.amount != null) ...[
            const SizedBox(width: 18),
            _MiniInfo(label: 'Amount', value: money(pickup.amount!)),
          ],
        ]),
        if (done && pickup.rating != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            for (var i = 1; i <= 5; i++)
              Icon(i <= pickup.rating! ? Icons.star_rounded : Icons.star_border_rounded, size: 14, color: AppColors.amberDeep),
            if (pickup.review != null) ...[
              const SizedBox(width: 6),
              Expanded(
                child: Text(pickup.review!, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
              ),
            ],
          ]),
        ],
        if ((onReceipt != null || onReview != null)) ...[
          const SizedBox(height: 12),
          Row(children: [
            if (onReceipt != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReceipt,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                  label: const Text('Receipt'),
                ),
              ),
            if (onReceipt != null && onReview != null) const SizedBox(width: 8),
            if (onReview != null)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReview,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 42)),
                  icon: const Icon(Icons.star_border_rounded, size: 17),
                  label: const Text('Rate'),
                ),
              ),
          ]),
        ],
      ]),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
          style: const TextStyle(fontSize: 8, letterSpacing: 1, fontWeight: FontWeight.w800, color: AppColors.muted)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
    ]);
  }
}
