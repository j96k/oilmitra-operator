import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../screens/listing_detail_screen.dart';

/// The operator's pickup list: every load claimed in the admin app, with the
/// supplier's address, phone, receipt, and status.
class AdminPickupsScreen extends StatefulWidget {
  const AdminPickupsScreen({super.key, this.onChanged});
  final VoidCallback? onChanged;

  @override
  State<AdminPickupsScreen> createState() => _AdminPickupsScreenState();
}

class _AdminPickupsScreenState extends State<AdminPickupsScreen> {
  List<Pickup> _items = [];
  bool _loading = true;
  String? _error;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _items.isEmpty;
      _error = null;
    });
    try {
      final rows = await Api.instance.pickups(status: _filter == 'all' ? null : _filter);
      if (!mounted) return;
      setState(() {
        _items = rows;
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

  Future<void> _open(Pickup p) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ListingDetailScreen(listingId: p.listingId)));
    await _load();
    widget.onChanged?.call();
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _openLink(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _snack('No app found to open that link.');
    } catch (_) {
      _snack('No app found to open that link.');
    }
  }

  Future<void> _call(String? phone) async {
    if (phone == null || phone.trim().isEmpty) return _snack('No phone number added.');
    await _openLink(Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}'));
  }

  Future<void> _whatsapp(Pickup p) async {
    final n = waNumber(p.supplierPhone);
    if (n.isEmpty) return _snack('No phone number added.');
    final text = 'Hi ${p.supplierName}, I am coming for the ${oilLabel(p.oilType)} oil pickup (${p.listingTitle}).';
    await _openLink(Uri.parse('https://wa.me/$n?text=${Uri.encodeComponent(text)}'));
  }

  Future<void> _receipt(Pickup p) async {
    if (p.receiptPath == null) return _snack('Receipt is not ready yet.');
    await _openLink(Uri.parse('${Api.instance.baseUrl}${p.receiptPath}'));
  }

  Future<void> _shareReceipt(Pickup p) async {
    if (p.receiptPath == null) return _snack('Receipt is not ready yet.');
    final url = '${Api.instance.baseUrl}${p.receiptPath}';
    await _openLink(Uri.parse('https://wa.me/?text=${Uri.encodeComponent(
      'OilMitra pickup receipt — ${p.actualLiters ?? 0} L ${oilLabel(p.oilType)} for ${money(p.amount ?? 0)}.\n$url',
    )}'));
  }

  @override
  Widget build(BuildContext context) {
    final scheduled = _items.where((p) => p.status == 'scheduled').length;
    return Scaffold(
      body: RefreshIndicator(
        color: AppColors.amberDeep,
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('YOUR ROUTE',
                          style: TextStyle(
                              fontSize: 9.5, letterSpacing: 1.5, fontWeight: FontWeight.w800, color: AppColors.amberDeep)),
                      const Text('Pickups',
                          style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -0.9)),
                      Text(
                        scheduled == 0 ? 'No van trips booked yet' : '$scheduled on the road · tap one for the address',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                      ),
                    ]),
                  ),
                  IconButton(
                    onPressed: _load,
                    style: IconButton.styleFrom(backgroundColor: Colors.white, side: const BorderSide(color: AppColors.line)),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final f in const ['all', 'scheduled', 'completed', 'cancelled'])
                    Padding(
                      padding: const EdgeInsets.only(right: 7),
                      child: ChoiceChip(
                        label: Text(f == 'all' ? 'All' : statusLabel(f)),
                        selected: _filter == f,
                        showCheckmark: false,
                        onSelected: (_) {
                          setState(() => _filter = f);
                          _load();
                        },
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator(color: AppColors.amberDeep)),
              )
            else if (_error != null)
              EmptyState(
                icon: Icons.wifi_off_rounded,
                title: 'Could not load pickups',
                subtitle: _error,
                action: FilledButton(onPressed: _load, child: const Text('Try again')),
              )
            else if (_items.isEmpty)
              EmptyState(
                icon: Icons.local_shipping_outlined,
                title: _filter == 'all' ? 'No pickups yet' : 'Nothing here',
                subtitle: _filter == 'all'
                    ? 'Claim a load on the radar and it will show up here with the shop address.'
                    : 'Try another filter — or pull down to refresh.',
              )
            else
              ..._items.map((p) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _PickupTile(
                      pickup: p,
                      onTap: () => _open(p),
                      onCall: () => _call(p.supplierPhone),
                      onWhatsApp: () => _whatsapp(p),
                      onReceipt: p.receiptPath == null ? null : () => _receipt(p),
                      onShare: p.receiptPath == null ? null : () => _shareReceipt(p),
                    ),
                  )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _PickupTile extends StatelessWidget {
  const _PickupTile({
    required this.pickup,
    required this.onTap,
    required this.onCall,
    required this.onWhatsApp,
    this.onReceipt,
    this.onShare,
  });

  final Pickup pickup;
  final VoidCallback onTap;
  final VoidCallback onCall;
  final VoidCallback onWhatsApp;
  final VoidCallback? onReceipt;
  final VoidCallback? onShare;

  @override
  Widget build(BuildContext context) {
    final p = pickup;
    final done = p.status == 'completed';
    final cancelled = p.status == 'cancelled';
    final accent = AppColors.forStatus(p.status);
    final who = p.supplierName;
    final role = '${orgIcon(p.supplierOrgType)} ${orgLabel(p.supplierOrgType)}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
          boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 7))],
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: accent.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(AppColors.iconFor(p.status), size: 19, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.listingTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, letterSpacing: -0.2)),
                const SizedBox(height: 1),
                Text('${oilEmoji(p.oilType)} ${oilLabel(p.oilType)} · $who',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600)),
              ]),
            ),
            const SizedBox(width: 6),
            StatusPill(p.status, dense: true),
          ]),
          const SizedBox(height: 11),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(color: AppColors.cream, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Expanded(
                child: _MiniInfo(
                  label: done ? 'Collected' : (cancelled ? 'Created' : 'Scheduled'),
                  value: done
                      ? dayMonthTime(p.collectedAt ?? p.createdAt)
                      : (cancelled
                          ? dayMonthTime(p.createdAt)
                          : dayMonthTime(p.scheduledAt ?? p.createdAt)),
                ),
              ),
              if (p.actualLiters != null) ...[
                const SizedBox(width: 8),
                _MiniInfo(label: 'Litres', value: litres(p.actualLiters!)),
              ],
              if (p.amount != null) ...[
                const SizedBox(width: 8),
                _MiniInfo(label: 'Amount', value: money(p.amount!), align: CrossAxisAlignment.end),
              ],
            ]),
          ),
          const SizedBox(height: 9),
          Row(children: [
            Icon(Icons.storefront_rounded, size: 13, color: AppColors.olive),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                role,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w600),
              ),
            ),
            if (p.rating != null) ...[
              for (var i = 1; i <= 5; i++)
                Icon(i <= p.rating! ? Icons.star_rounded : Icons.star_border_rounded, size: 13, color: AppColors.amberDeep),
            ] else
              const Text('Open details', style: TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w600)),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.muted),
          ]),
          if (p.review != null && p.review!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('“${p.review!}”',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10.5, fontStyle: FontStyle.italic, color: AppColors.muted.withValues(alpha: 0.95))),
          ],
          if (!cancelled) ...[
            const SizedBox(height: 11),
            Row(children: [
              _RoundAction(icon: Icons.call_rounded, label: 'Call', onTap: onCall),
              const SizedBox(width: 7),
              _RoundAction(icon: Icons.chat_rounded, label: 'Chat', onTap: onWhatsApp, filled: true),
              const Spacer(),
              if (onReceipt != null) ...[
                const SizedBox(width: 7),
                _RoundAction(icon: Icons.receipt_long_rounded, label: 'Receipt', onTap: onReceipt!),
                const SizedBox(width: 7),
                _RoundAction(icon: Icons.share_rounded, label: 'Share', onTap: onShare!),
              ],
            ]),
          ],
        ]),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? Colors.white : AppColors.ink;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: filled ? AppColors.ink : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: filled ? AppColors.ink : AppColors.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg)),
        ]),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  const _MiniInfo({required this.label, required this.value, this.align = CrossAxisAlignment.start});
  final String label;
  final String value;
  final CrossAxisAlignment align;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: align, mainAxisSize: MainAxisSize.min, children: [
      Text(label.toUpperCase(),
          style: const TextStyle(fontSize: 8, letterSpacing: 0.9, fontWeight: FontWeight.w800, color: AppColors.muted)),
      const SizedBox(height: 2),
      Text(value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
    ]);
  }
}
