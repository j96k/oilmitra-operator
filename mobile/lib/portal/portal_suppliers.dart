import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';

class PortalSuppliersTab extends StatefulWidget {
  const PortalSuppliersTab({super.key});

  @override
  State<PortalSuppliersTab> createState() => _PortalSuppliersTabState();
}

class _PortalSuppliersTabState extends State<PortalSuppliersTab> {
  List<LeaderRow> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await Api.instance.leaderboard();
      if (mounted) setState(() => _rows = res);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _rows.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }
    if (_error != null && _rows.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white38, size: 40),
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.gold,
      backgroundColor: const Color(0xFF1E2622),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Volume Leaderboard',
                      style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Top Oil Suppliers',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                tooltip: 'Refresh suppliers',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Hotels, restaurants, marriage halls, and kitchens contributing the highest litres of used oil to the network.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),

          if (_rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text('No completed supplier pickups yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
              ),
            )
          else
            ..._rows.map((row) {
              final isTop3 = row.rank <= 3;
              final rankColor = row.rank == 1
                  ? const Color(0xFFFFD700)
                  : row.rank == 2
                      ? const Color(0xFFC0C0C0)
                      : row.rank == 3
                          ? const Color(0xFFCD7F32)
                          : Colors.white38;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161C19),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isTop3 ? rankColor.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: rankColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '#${row.rank}',
                          style: TextStyle(
                            color: rankColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              row.name,
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${row.orgType.replaceAll('_', ' ').toUpperCase()}${row.city != null ? ' Â· ${row.city}' : ''}',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            litres(row.liters),
                            style: const TextStyle(color: AppColors.gold, fontSize: 16, fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'recycled',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
