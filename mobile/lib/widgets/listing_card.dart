import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import 'common.dart';

/// One oil load, used on the radar list, "my oil" and search results.
class ListingCard extends StatelessWidget {
  const ListingCard({super.key, required this.listing, this.onTap, this.compact = false});
  final OilListing listing;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final distance = listing.distanceKm;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
          boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.04), blurRadius: 18, offset: const Offset(0, 8))],
        ),
        padding: const EdgeInsets.all(10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: compact ? 76 : 92,
            height: compact ? 76 : 92,
            child: Stack(fit: StackFit.expand, children: [
              OilPhoto(listing.photoUrl, height: compact ? 76 : 92, radius: 16, iconSize: 28),
              Positioned(
                left: 6,
                bottom: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.62), borderRadius: BorderRadius.circular(7)),
                  child: Text(litres(listing.approxLiters),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(listing.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, letterSpacing: -0.2)),
                ),
                const SizedBox(width: 6),
                if (listing.status != 'open') StatusPill(listing.status, dense: true),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Text(oilEmoji(listing.oilType), style: const TextStyle(fontSize: 11)),
                const SizedBox(width: 3),
                Text(oilLabel(listing.oilType),
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                if (distance != null) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.near_me_rounded, size: 11, color: AppColors.olive),
                  const SizedBox(width: 2),
                  Text(_dist(distance),
                      style: const TextStyle(fontSize: 11.5, color: AppColors.olive, fontWeight: FontWeight.w800)),
                ],
              ]),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(money(listing.estValue),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: -0.5)),
                const SizedBox(width: 4),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('${money(listing.ratePerLiter)}/L',
                      style: const TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    listing.isMine ? 'Your listing' : listing.supplierName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 10.5, color: AppColors.muted, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
              const SizedBox(height: 5),
              Row(children: [
                const Icon(Icons.schedule_rounded, size: 11, color: AppColors.muted),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(windowLabel(listing.availableFrom, listing.availableTo),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

String _dist(double km) => km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(km < 10 ? 1 : 0)} km';
