import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';

/// A tiny offline-friendly slippy map.
///
/// It draws OpenStreetMap tiles (free, no API key) in a `Stack`, supports drag
/// and pinch/plus-minus zoom, and places our own pins on top. If tiles can't be
/// loaded (no internet) the map falls back to a calm olive grid — pins still work.
/// Also has an optional "radar" sweep for the collector home screen.
class OilMap extends StatefulWidget {
  const OilMap({
    super.key,
    this.pins = const [],
    this.center,
    this.zoom = 12,
    this.height = 260,
    this.showRadar = false,
    this.showZoom = true,
    this.interactive = true,
    this.myLocation = false,
    this.onTap,
    this.onPinTap,
    this.cornerRadius = 24,
  });

  final List<MapPin> pins;
  final LatLng? center;
  final int zoom;
  final double height;
  final bool showRadar;
  final bool showZoom;
  final bool interactive;
  final bool myLocation;
  final ValueChanged<LatLng>? onTap;
  final ValueChanged<MapPin>? onPinTap;
  final double cornerRadius;

  @override
  State<OilMap> createState() => _OilMapState();
}

class _OilMapState extends State<OilMap> with SingleTickerProviderStateMixin {
  static const _tile = 256.0;
  static const _defaultCenter = LatLng(21.1702, 72.8311); // Surat

  late double _lat;
  late double _lng;
  late int _zoom;
  late final AnimationController _radar;
  Size _size = Size.zero;

  @override
  void initState() {
    super.initState();
    final c = widget.center ?? (widget.pins.isNotEmpty ? LatLng(widget.pins.first.lat, widget.pins.first.lng) : _defaultCenter);
    _lat = c.lat;
    _lng = c.lng;
    _zoom = widget.zoom;
    _radar = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void didUpdateWidget(covariant OilMap old) {
    super.didUpdateWidget(old);
    if (widget.center != null && (widget.center!.lat != old.center?.lat || widget.center!.lng != old.center?.lng)) {
      _lat = widget.center!.lat;
      _lng = widget.center!.lng;
    }
    if (widget.showRadar && !old.showRadar) _radar.repeat();
    if (!widget.showRadar && old.showRadar) _radar.stop();
  }

  @override
  void dispose() {
    _radar.dispose();
    super.dispose();
  }

  double get _world => _tile * math.pow(2, _zoom);

  double _x(double lng) => (lng + 180) / 360 * _world;

  double _y(double lat) {
    final s = math.sin(lat.clamp(-85.0, 85.0) * math.pi / 180);
    return (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * _world;
  }

  LatLng _fromWorld(double x, double y) {
    final lng = x / _world * 360 - 180;
    final n = math.pi - 2 * math.pi * y / _world;
    final lat = 180 / math.pi * math.atan((math.exp(n) - math.exp(-n)) / 2);
    return LatLng(lat.clamp(-85.0, 85.0), lng.clamp(-180.0, 180.0));
  }

  void _pan(Offset delta) {
    final x = _x(_lng) - delta.dx;
    final y = _y(_lat) - delta.dy;
    final p = _fromWorld(x, y);
    setState(() {
      _lat = p.lat;
      _lng = p.lng;
    });
  }

  void _zoomBy(int d) {
    final next = (_zoom + d).clamp(3, 17);
    if (next != _zoom) setState(() => _zoom = next);
  }

  void _tap(Offset local) {
    if (!widget.interactive || widget.onTap == null) return;
    final originX = _x(_lng) - _size.width / 2;
    final originY = _y(_lat) - _size.height / 2;
    widget.onTap!(_fromWorld(originX + local.dx, originY + local.dy));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.cornerRadius),
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = widget.height;
          _size = Size(w, h);
          final cx = _x(_lng), cy = _y(_lat);
          final originX = cx - w / 2, originY = cy - h / 2;
          final n = 1 << _zoom;
          final firstX = (originX / _tile).floor(), lastX = ((originX + w) / _tile).floor();
          final firstY = (originY / _tile).floor(), lastY = ((originY + h) / _tile).floor();

          return Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                _zoomBy(event.scrollDelta.dy > 0 ? -1 : 1);
              }
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _tap(d.localPosition),
              onPanUpdate: widget.interactive ? (d) => _pan(d.delta) : null,
              child: Stack(children: [
                Container(color: const Color(0xFFE9EEDF)),
                // Tiles
                for (var ty = firstY; ty <= lastY; ty++)
                  if (ty >= 0 && ty < n)
                    for (var tx = firstX; tx <= lastX; tx++)
                      Positioned(
                        left: tx * _tile - originX,
                        top: ty * _tile - originY,
                        width: _tile,
                        height: _tile,
                        child: Image.network(
                          'https://tile.openstreetmap.org/$_zoom/${tx % n}/$ty.png',
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFE9EEDF)),
                        ),
                      ),
                // Faint grid + warm wash so it feels designed even without tiles
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _MapWashPainter()),
                  ),
                ),
                if (widget.showRadar)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedBuilder(
                        animation: _radar,
                        builder: (_, _) => CustomPaint(painter: _RadarPainter(_radar.value)),
                      ),
                    ),
                  ),
                if (widget.myLocation) Center(child: _YouDot(pulse: _radar)),
                // Pins
                for (final pin in widget.pins)
                  Positioned(
                    left: _x(pin.lng) - originX - 62,
                    top: _y(pin.lat) - originY - 16,
                    width: 124,
                    child: _Pin(
                      pin: pin,
                      onTap: widget.onPinTap == null ? null : () => widget.onPinTap!(pin),
                    ),
                  ),
                // Controls
                if (widget.showZoom)
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Column(children: [
                      _MapButton(icon: Icons.add_rounded, onTap: () => _zoomBy(1)),
                      const SizedBox(height: 6),
                      _MapButton(icon: Icons.remove_rounded, onTap: () => _zoomBy(-1)),
                    ]),
                  ),
                Positioned(
                  left: 8,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.78), borderRadius: BorderRadius.circular(6)),
                    child: const Text('© OpenStreetMap',
                        style: TextStyle(fontSize: 8, color: AppColors.muted, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ),
          );
        }),
      ),
    );
  }
}

class _Pin extends StatelessWidget {
  const _Pin({required this.pin, this.onTap});
  final MapPin pin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = pin.highlight ? AppColors.amberDeep : AppColors.ink;
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 16),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 6)],
          ),
          child: Text(pin.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: AppColors.ink)),
        ),
      ]),
    );
  }
}

class _MapButton extends StatelessWidget {
  const _MapButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 8)],
        ),
        child: Icon(icon, size: 19, color: AppColors.ink),
      ),
    );
  }
}

class _YouDot extends StatelessWidget {
  const _YouDot({required this.pulse});
  final Animation<double> pulse;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, _) => Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: AppColors.teal,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(color: AppColors.teal.withValues(alpha: 0.35), blurRadius: 6 + 14 * pulse.value, spreadRadius: 2 + 8 * pulse.value),
          ],
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = math.min(size.width, size.height) * 0.62;
    for (var i = 0; i < 2; i++) {
      final p = (t + i * 0.5) % 1.0;
      canvas.drawCircle(
        center,
        maxR * p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = AppColors.amber.withValues(alpha: 0.55 * (1 - p)),
      );
    }
    final sweep = Rect.fromCircle(center: center, radius: maxR);
    canvas.drawArc(
      sweep,
      -math.pi / 2 + t * math.pi * 2,
      math.pi / 3,
      true,
      Paint()
        ..shader = SweepGradient(
          startAngle: 0,
          endAngle: math.pi / 3,
          colors: [AppColors.amber.withValues(alpha: 0.0), AppColors.amber.withValues(alpha: 0.22)],
          transform: GradientRotation(-math.pi / 2 + t * math.pi * 2),
        ).createShader(sweep),
    );
  }

  @override
  bool shouldRepaint(covariant _RadarPainter old) => old.t != t;
}

class _MapWashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // A soft warm glow in the top-left keeps the map from looking like a raw tile dump.
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x0FFFF3D6), Color(0x00000000), Color(0x0F1E3A1A)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
