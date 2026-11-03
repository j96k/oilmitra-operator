import 'dart:async';

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/oil_map.dart';

class PickedPlace {
  PickedPlace({required this.lat, required this.lng, required this.label, this.area, this.city, this.pincode});
  final double lat;
  final double lng;
  final String label;
  final String? area;
  final String? city;
  final String? pincode;
}

/// Tap the map (or search) to place the shop. No API key, no GPS permission.
class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, this.initial, this.initialZoom = 13});
  final PickedPlace? initial;
  final int initialZoom;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  late LatLng _center;
  LatLng? _pin;
  String? _label;
  String? _area;
  String? _city;
  String? _pincode;
  bool _busy = false;

  final _search = TextEditingController();
  Timer? _debounce;
  List<GeoPlace> _results = [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _center = i == null ? const LatLng(21.1702, 72.8311) : LatLng(i.lat, i.lng);
    if (i != null) {
      _pin = LatLng(i.lat, i.lng);
      _label = i.label;
      _area = i.area;
      _city = i.city;
      _pincode = i.pincode;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  Future<void> _tapMap(LatLng p) async {
    setState(() {
      _pin = p;
      _busy = true;
      _results = [];
      _label = null;
    });
    try {
      final r = await Api.instance.geoReverse(p.lat, p.lng);
      if (!mounted) return;
      setState(() {
        _label = r['label'] as String? ?? '${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)}';
        _area = r['area'] as String? ?? r['road'] as String?;
        _city = r['city'] as String?;
        _pincode = r['pincode'] as String?;
        _busy = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _label = '${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)}';
        _busy = false;
      });
    }
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    if (q.trim().length < 3) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      setState(() => _searching = true);
      try {
        final r = await Api.instance.geoSearch(q.trim());
        if (!mounted) return;
        setState(() {
          _results = r;
          _searching = false;
        });
      } catch (_) {
        if (mounted) setState(() => _searching = false);
      }
    });
  }

  Future<void> _pickResult(GeoPlace place) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _center = LatLng(place.lat, place.lng);
      _results = [];
      _search.text = place.label;
    });
    await _tapMap(LatLng(place.lat, place.lng));
  }

  Future<void> _pasteLink() async {
    final ctrl = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste Google Maps link', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('In Google Maps: long-press your shop → Share → Copy link. Paste it here.',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.4)),
          const SizedBox(height: 12),
          TextField(controller: ctrl, maxLines: 2, decoration: const InputDecoration(hintText: 'https://maps.app.goo.gl/…')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Use link'),
          ),
        ],
      ),
    );
    if (text == null) return;
    final coords = _extractCoords(text);
    if (coords == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No coordinates found. Open the link once, then copy the long maps.google.com/…@lat,lng link.'),
      ));
      return;
    }
    setState(() => _center = coords);
    await _tapMap(coords);
  }

  LatLng? _extractCoords(String text) {
    final patterns = [
      RegExp(r'@(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)'),
      RegExp(r'[?&]q=(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)'),
      RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)'),
      RegExp(r'^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$'),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(text.trim());
      if (m != null) {
        final lat = double.tryParse(m.group(1)!);
        final lng = double.tryParse(m.group(2)!);
        if (lat != null && lng != null && lat.abs() <= 90 && lng.abs() <= 180) return LatLng(lat, lng);
      }
    }
    return null;
  }

  void _done() {
    if (_pin == null) return;
    Navigator.pop(
      context,
      PickedPlace(
        lat: _pin!.lat,
        lng: _pin!.lng,
        label: _label ?? '${_pin!.lat.toStringAsFixed(5)}, ${_pin!.lng.toStringAsFixed(5)}',
        area: _area,
        city: _city,
        pincode: _pincode,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pin your location'),
        actions: [
          TextButton.icon(
            onPressed: _pasteLink,
            icon: const Icon(Icons.link_rounded, size: 18),
            label: const Text('Maps link'),
          ),
        ],
      ),
      body: Stack(children: [
        Column(children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, cons) => OilMap(
                key: ValueKey('${_center.lat},${_center.lng}'),
                center: _center,
                zoom: widget.initialZoom,
                height: cons.maxHeight,
                cornerRadius: 0,
                showZoom: true,
                myLocation: false,
                pins: _pin == null
                    ? const []
                    : [MapPin(lat: _pin!.lat, lng: _pin!.lng, label: 'Your shop', highlight: true)],
                onTap: _tapMap,
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.fromLTRB(18, 14, 18, MediaQuery.paddingOf(context).bottom + 14),
            decoration: const BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 24)],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_pin == null)
                const Row(children: [
                  Icon(Icons.touch_app_rounded, size: 18, color: AppColors.amberDeep),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Tap the map where the shop is, or search above.',
                        style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                  ),
                ])
              else ...[
                Row(children: [
                  const Icon(Icons.location_on_rounded, size: 18, color: AppColors.olive),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _busy ? 'Finding the address…' : (_label ?? 'Pinned location'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.35),
                    ),
                  ),
                  if (_busy) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                ]),
                const SizedBox(height: 4),
                Text('${_pin!.lat.toStringAsFixed(5)}, ${_pin!.lng.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _busy ? null : _done,
                  icon: const Icon(Icons.check_rounded, size: 19),
                  label: const Text('Use this location'),
                ),
              ],
            ]),
          ),
        ]),
        Positioned(
          left: 14,
          right: 14,
          top: 10,
          child: Column(children: [
            Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(18),
              color: Colors.white,
              child: TextField(
                controller: _search,
                onChanged: _onSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search shop, area or city',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _searching
                      ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                      : null,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  fillColor: Colors.white,
                ),
              ),
            ),
            if (_results.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 6),
                constraints: const BoxConstraints(maxHeight: 240),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16)],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: _results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = _results[i];
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.location_on_outlined, size: 18, color: AppColors.olive),
                      title: Text(r.label, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                      onTap: () => _pickResult(r),
                    );
                  },
                ),
              ),
          ]),
        ),
      ]),
    );
  }
}
