import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;

import '../models.dart';
import '../theme.dart';

/// The map uses Google Maps everywhere.
///
/// * **Android / iOS** — the native Google Maps SDK. The key is injected at
///   build time by `mobile/build_apks.ps1 -GoogleMaps`
///   (`--dart-define=GOOGLE_MAPS_API_KEY=...`); it is never committed.
/// * **Web** — the Maps JavaScript API. `web/index.html` loads it before
///   Flutter starts, using the key the backend returns from `GET /geo/config`
///   (a browser key, restricted by HTTP referrer). Nothing is baked into the
///   committed web bundle.
const String _googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
const String _mapsProvider = String.fromEnvironment('MAPS_PROVIDER', defaultValue: 'google');

bool get _googleMapsSupported =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// Web always has the JS API loaded by `index.html`; native platforms need the
/// build-time key.
bool get _useGoogleMaps => _googleMapsSupported && _mapsProvider == 'google' && (kIsWeb || _googleMapsApiKey.isNotEmpty);

/// A Google Maps widget with our pins, tap-to-pick, zoom buttons and the
/// optional collector "radar" sweep on top.
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
  static const _defaultCenter = LatLng(21.1702, 72.8311); // Surat

  late final AnimationController _radar;
  gmaps.GoogleMapController? _googleController;

  @override
  void initState() {
    super.initState();
    _radar = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  }

  @override
  void didUpdateWidget(covariant OilMap old) {
    super.didUpdateWidget(old);
    final c = widget.center;
    if (c != null && (c.lat != old.center?.lat || c.lng != old.center?.lng)) {
      _googleController?.animateCamera(gmaps.CameraUpdate.newLatLng(gmaps.LatLng(c.lat, c.lng)));
    }
    if (widget.showRadar && !old.showRadar) _radar.repeat();
    if (!widget.showRadar && old.showRadar) _radar.stop();
  }

  @override
  void dispose() {
    _googleController = null;
    _radar.dispose();
    super.dispose();
  }

  LatLng get _center =>
      widget.center ?? (widget.pins.isNotEmpty ? LatLng(widget.pins.first.lat, widget.pins.first.lng) : _defaultCenter);

  void _googleZoom(int delta) {
    final c = _googleController;
    if (c == null) return;
    c.animateCamera(delta > 0 ? gmaps.CameraUpdate.zoomIn() : gmaps.CameraUpdate.zoomOut());
  }

  @override
  Widget build(BuildContext context) {
    if (!_useGoogleMaps) return _buildUnavailable();
    return _buildGoogle();
  }

  Widget _buildGoogle() {
    final center = _center;
    final markers = <gmaps.Marker>{
      for (var i = 0; i < widget.pins.length; i++)
        gmaps.Marker(
          markerId: gmaps.MarkerId('pin-$i'),
          position: gmaps.LatLng(widget.pins[i].lat, widget.pins[i].lng),
          infoWindow: gmaps.InfoWindow(title: widget.pins[i].label),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            widget.pins[i].highlight ? gmaps.BitmapDescriptor.hueOrange : gmaps.BitmapDescriptor.hueGreen,
          ),
          onTap: widget.onPinTap == null ? null : () => widget.onPinTap!(widget.pins[i]),
        ),
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.cornerRadius),
      child: SizedBox(
        height: widget.height,
        child: Stack(children: [
          gmaps.GoogleMap(
            initialCameraPosition: gmaps.CameraPosition(
              target: gmaps.LatLng(center.lat, center.lng),
              zoom: widget.zoom.toDouble(),
            ),
            onMapCreated: (c) => _googleController = c,
            markers: markers,
            onTap: widget.interactive && widget.onTap != null
                ? (p) => widget.onTap!(LatLng(p.latitude, p.longitude))
                : null,
            minMaxZoomPreference: const gmaps.MinMaxZoomPreference(3, 19),
            zoomControlsEnabled: false,
            zoomGesturesEnabled: widget.interactive,
            scrollGesturesEnabled: widget.interactive,
            rotateGesturesEnabled: widget.interactive,
            tiltGesturesEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            padding: const EdgeInsets.only(bottom: 28),
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
          if (widget.showZoom)
            Positioned(
              right: 10,
              top: 10,
              child: Column(children: [
                _MapButton(icon: Icons.add_rounded, onTap: () => _googleZoom(1)),
                const SizedBox(height: 6),
                _MapButton(icon: Icons.remove_rounded, onTap: () => _googleZoom(-1)),
              ]),
            ),
        ]),
      ),
    );
  }

  /// Shown only when the app was built without a Google Maps key (e.g. a plain
  /// `flutter run` on Android before `build_apks.ps1`).
  Widget _buildUnavailable() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.cornerRadius),
      child: SizedBox(
        height: widget.height,
        child: Container(
          color: const Color(0xFFE9EEDF),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(16),
          child: const Text(
            'Google Maps key missing in this build.\nUse mobile\\build_apks.ps1 -GoogleMaps.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted),
          ),
        ),
      ),
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
