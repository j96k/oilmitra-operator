import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';

/// A photo with a warm placeholder, used for listings, shops and avatars.
class OilPhoto extends StatelessWidget {
  const OilPhoto(this.path, {super.key, this.height = 160, this.radius = 22, this.iconSize = 40, this.fit = BoxFit.cover})
      : _avatar = false;

  const OilPhoto.avatar(this.path, {super.key, this.height = 48, this.iconSize = 22, this.radius = 999})
      : fit = BoxFit.cover,
        _avatar = true;

  final String? path;
  final double height;
  final double radius;
  final double iconSize;
  final BoxFit fit;
  final bool _avatar;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      height: _avatar ? height : null,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.amberSoft, Color(0xFFF3EBCF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(child: Icon(Icons.water_drop_rounded, size: iconSize, color: AppColors.amberDeep)),
    );
    final image = (path == null || path!.isEmpty)
        ? placeholder
        : Image.network(
            Api.instance.imageUrl(path),
            height: _avatar ? height : null,
            fit: fit,
            errorBuilder: (_, _, _) => placeholder,
            loadingBuilder: (c, child, p) => p == null ? child : placeholder,
          );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: _avatar ? SizedBox(width: height, height: height, child: image) : image,
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.dense = false, this.light = false});
  final String status;
  final bool dense;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final c = light ? Colors.white : AppColors.forStatus(status);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 11, vertical: dense ? 4 : 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: light ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(30),
        border: light ? Border.all(color: Colors.white24) : null,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(AppColors.iconFor(status), size: dense ? 12 : 14, color: c),
        const SizedBox(width: 4),
        Text(statusLabel(status),
            style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: dense ? 10.5 : 12)),
      ]),
    );
  }
}

class SectionHead extends StatelessWidget {
  const SectionHead(this.title, {super.key, this.action, this.onAction, this.padding = const EdgeInsets.fromLTRB(20, 26, 20, 12)});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(children: [
        Expanded(
          child: Text(title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.olive,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 34),
              textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            child: Text(action!),
          ),
      ]),
    );
  }
}

class Metric extends StatelessWidget {
  const Metric({super.key, required this.label, required this.value, this.unit, this.color = AppColors.ink, this.icon});
  final String label;
  final String value;
  final String? unit;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        if (icon != null) ...[Icon(icon, size: 13, color: color.withValues(alpha: 0.7)), const SizedBox(width: 4)],
        Text(label.toUpperCase(),
            style: TextStyle(fontSize: 9.5, letterSpacing: 1.1, fontWeight: FontWeight.w800, color: color.withValues(alpha: 0.6))),
      ]),
      const SizedBox(height: 5),
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Flexible(
          child: Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.8)),
        ),
        if (unit != null) ...[
          const SizedBox(width: 3),
          Text(unit!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color.withValues(alpha: 0.65))),
        ],
      ]),
    ]);
  }
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, this.url, this.size = 44});
  final String name;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return OilPhoto.avatar(url, height: size, iconSize: size * 0.4);
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.olive, Color(0xFF83A24F)], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      child: Text(initials(name),
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.34, letterSpacing: 1)),
    );
  }
}

/// The OilMitra mark: one amber drop with a highlight.
class DropMark extends StatelessWidget {
  const DropMark({super.key, this.size = 40, this.color = AppColors.amber});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _DropPainter(color)),
    );
  }
}

class _DropPainter extends CustomPainter {
  _DropPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.5, h * 0.02)
      ..cubicTo(w * 0.82, h * 0.30, w * 0.98, h * 0.50, w * 0.98, h * 0.66)
      ..arcToPoint(Offset(w * 0.02, h * 0.66), radius: Radius.circular(w * 0.48), clockwise: false)
      ..cubicTo(w * 0.02, h * 0.50, w * 0.18, h * 0.30, w * 0.5, h * 0.02)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [color, AppColors.amberDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );
    canvas.drawCircle(Offset(w * 0.36, h * 0.60), w * 0.10, Paint()..color = Colors.white.withValues(alpha: 0.32));
  }

  @override
  bool shouldRepaint(covariant _DropPainter old) => old.color != color;
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.subtitle, this.action});
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: AppColors.amberSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: AppColors.amberDeep),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.muted, height: 1.4)),
          ],
          if (action != null) ...[const SizedBox(height: 18), action!],
        ]),
      ),
    );
  }
}

class InfoDot extends StatelessWidget {
  const InfoDot({super.key, this.color = AppColors.teal});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

/// A small marquee-style rate ticker header strip.
class RateTicker extends StatelessWidget {
  const RateTicker({super.key, required this.rates});
  final List<OilRate> rates;

  @override
  Widget build(BuildContext context) {
    if (rates.isEmpty) return const SizedBox.shrink();
    final text = rates.map((r) => '${oilLabel(r.oilType)} ${money(r.price)}/L').join('   •   ');
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(colors: [AppColors.ink, Color(0xFF35452A)], begin: Alignment.centerLeft, end: Alignment.centerRight),
      ),
      child: Row(children: [
        const DropMark(size: 16, color: AppColors.gold),
        const SizedBox(width: 8),
        const Text('TODAY',
            style: TextStyle(color: AppColors.gold, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.4)),
        const SizedBox(width: 10),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(text,
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }
}

/// Rounded stat block used inside dark hero cards.
class HeroStat extends StatelessWidget {
  const HeroStat({super.key, required this.label, required this.value, this.unit, this.color = Colors.white});
  final String label;
  final String value;
  final String? unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(label.toUpperCase(),
          style: TextStyle(fontSize: 9, letterSpacing: 1.2, fontWeight: FontWeight.w800, color: color.withValues(alpha: 0.55))),
      const SizedBox(height: 4),
      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
        Flexible(
          child: Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.7)),
        ),
        if (unit != null) ...[
          const SizedBox(width: 3),
          Text(unit!, style: TextStyle(color: color.withValues(alpha: 0.55), fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ]),
    ]);
  }
}

/// Tiny hand-drawn sparkline for the last N days (no package).
class MiniBars extends StatelessWidget {
  const MiniBars({super.key, required this.values, this.color = AppColors.olive, this.height = 34});
  final List<double> values;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return SizedBox(height: height);
    final maxV = values.reduce(math.max);
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final v in values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Container(
                  height: maxV <= 0 ? 3 : (height * (v / maxV)).clamp(3.0, height),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: v <= 0 ? 0.15 : 0.75),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
