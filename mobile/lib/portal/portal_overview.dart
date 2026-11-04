import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';

class PortalOverviewTab extends StatefulWidget {
  const PortalOverviewTab({super.key, required this.onNavigateTab});
  final void Function(int index) onNavigateTab;

  @override
  State<PortalOverviewTab> createState() => _PortalOverviewTabState();
}

class _PortalOverviewTabState extends State<PortalOverviewTab> {
  Dashboard? _data;
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
      final res = await Api.instance.dashboard();
      if (mounted) setState(() => _data = res);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _data == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }
    if (_error != null && _data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.white38),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    final d = _data!;
    final impact = d.impact;

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
                      'Executive Control Hub',
                      style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Network Analytics',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                tooltip: 'Refresh analytics',
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Primary metric cards
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _MetricCard(
                label: 'TOTAL OIL DIVERTED',
                value: litres(impact.liters),
                subtitle: 'Across the entire pickup network',
                icon: Icons.water_drop_rounded,
                accentColor: AppColors.gold,
              ),
              _MetricCard(
                label: 'MONEY PAID TO SUPPLIERS',
                value: money(d.moneyTotal),
                subtitle: 'Direct financial return recorded',
                icon: Icons.currency_rupee_rounded,
                accentColor: const Color(0xFF52C41A),
              ),
              _MetricCard(
                label: 'OPEN OIL LOADS READY',
                value: '${d.openCount}',
                subtitle: 'Awaiting operator claiming',
                icon: Icons.radar_rounded,
                accentColor: const Color(0xFF1890FF),
                onTap: () => widget.onNavigateTab(1),
              ),
              _MetricCard(
                label: 'COMPLETED PICKUPS',
                value: '${impact.pickups}',
                subtitle: 'Successfully recycled batches',
                icon: Icons.check_circle_rounded,
                accentColor: const Color(0xFF722ED1),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Environmental Impact Banner
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B3B26), Color(0xFF102417)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF2E6F40).withValues(alpha: 0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.eco_rounded, color: Color(0xFF73D13D), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Environmental Impact & Biofuel Equivalent',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${impact.co2Kg.toStringAsFixed(1)} kg',
                            style: const TextStyle(color: Color(0xFF95DE64), fontSize: 24, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'CO₂e avoided from drain dumping',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.15)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${impact.biodieselL.toStringAsFixed(1)} L',
                            style: const TextStyle(color: AppColors.gold, fontSize: 24, fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Biodiesel yield potential',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Quick Management Actions
          const Text(
            'Control Center Shortcuts',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  title: 'Rate Board',
                  desc: 'Update buying rates',
                  icon: Icons.price_change_rounded,
                  color: AppColors.gold,
                  onTap: () => widget.onNavigateTab(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  title: 'All Loads',
                  desc: 'Manage & inspect listings',
                  icon: Icons.inventory_2_rounded,
                  color: const Color(0xFF1890FF),
                  onTap: () => widget.onNavigateTab(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionCard(
                  title: 'Operators Hub',
                  desc: 'Create & manage staff',
                  icon: Icons.badge_rounded,
                  color: const Color(0xFF52C41A),
                  onTap: () => widget.onNavigateTab(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionCard(
                  title: 'Suppliers',
                  desc: 'Leaderboard & providers',
                  icon: Icons.storefront_rounded,
                  color: const Color(0xFFFA8C16),
                  onTap: () => widget.onNavigateTab(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    this.onTap,
  });

  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth > 500 ? (constraints.maxWidth - 14) / 2 : constraints.maxWidth;
        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: w,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF161C19),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Icon(icon, color: accentColor, size: 20),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.desc,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String desc;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF161C19),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 11.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.3), size: 20),
          ],
        ),
      ),
    );
  }
}
