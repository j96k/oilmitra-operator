import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';

/// The "why this matters" screen: personal litres, the CO₂ kept out of drains,
/// the biodiesel that replaces diesel, and the kitchens leading the board.
class ImpactScreen extends StatefulWidget {
  const ImpactScreen({super.key});

  @override
  State<ImpactScreen> createState() => _ImpactScreenState();
}

class _ImpactScreenState extends State<ImpactScreen> {
  Impact? _impact;
  List<LeaderRow> _leaders = [];
  List<OilRate> _rates = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _impact == null;
      _error = null;
    });
    try {
      final results = await Future.wait([
        Api.instance.impact(),
        Api.instance.leaderboard(),
        Api.instance.rates(),
      ]);
      if (!mounted) return;
      setState(() {
        _impact = results[0] as Impact;
        _leaders = results[1] as List<LeaderRow>;
        _rates = results[2] as List<OilRate>;
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
        _error = 'Could not load your impact.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _impact == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.amberDeep));
    }
    if (_impact == null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No connection',
        subtitle: _error,
        action: FilledButton(onPressed: _load, child: const Text('Try again')),
      );
    }
    final i = _impact!;
    final isOperator = Api.instance.user?.isAdmin ?? false;
    return RefreshIndicator(
      color: AppColors.amberDeep,
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 2),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('CLEANER KITCHENS',
                        style: TextStyle(
                            fontSize: 9.5, letterSpacing: 1.5, fontWeight: FontWeight.w800, color: AppColors.teal)),
                    const Text('Your impact',
                        style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -0.9)),
                    Text(isOperator ? 'Every litre you move keeps a drain clean.' : 'Every litre you save keeps a drain clean.',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted, fontWeight: FontWeight.w600)),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: const BoxDecoration(color: AppColors.tealSoft, shape: BoxShape.circle),
                  child: const Icon(Icons.eco_rounded, size: 22, color: AppColors.teal),
                ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _ImpactHero(impact: i),
          ),
          const SectionHead('What that means'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(children: [
              _Equivalence(
                icon: Icons.forest_rounded,
                value: '${(i.co2Kg / 21).toStringAsFixed(i.co2Kg < 210 ? 1 : 0)} trees',
                label: 'A mature tree absorbs about 21 kg of CO₂ a year.',
                color: AppColors.olive,
              ),
              const SizedBox(height: 8),
              _Equivalence(
                icon: Icons.local_gas_station_rounded,
                value: '${i.biodieselL.toStringAsFixed(1)} L biodiesel',
                label: 'Ready to blend into diesel — roughly ${i.carKm.toStringAsFixed(0)} km of clean driving.',
                color: AppColors.amberDeep,
              ),
              const SizedBox(height: 8),
              _Equivalence(
                icon: Icons.water_rounded,
                value: '${i.liters.toStringAsFixed(1)} L out of drains',
                label: 'One litre of used oil can foul a thousand litres of water.',
                color: AppColors.teal,
              ),
            ]),
          ),
          if (_rates.isNotEmpty) ...[
            const SectionHead('Today\'s rate board'),
            SizedBox(
              height: 82,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _rates.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, n) {
                  final r = _rates[n];
                  return Container(
                    width: 116,
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
                      Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                        Text(money(r.price),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.7)),
                        const SizedBox(width: 2),
                        const Text('/L', style: TextStyle(fontSize: 9, color: AppColors.muted, fontWeight: FontWeight.w600)),
                      ]),
                    ]),
                  );
                },
              ),
            ),
          ],
          SectionHead('Top kitchens', action: 'All time'),
          if (_leaders.isEmpty)
            const EmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'The board is waiting',
              subtitle: 'The first completed pickup puts a kitchen on the leaderboard.',
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.line),
                ),
                child: Column(
                  children: [
                    for (var n = 0; n < _leaders.length; n++) ...[
                      _LeaderRowCard(
                        row: _leaders[n],
                        isMe: _isMe(_leaders[n]),
                        last: n == _leaders.length - 1,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.oliveSoft, Color(0xFFF7F0DC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.olive.withValues(alpha: 0.2)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.olive),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Impact is calculated from completed pickups only. '
                    'CO₂e uses 2.8 kg per litre of used oil and biodiesel a 0.92 L yield — '
                    'the same numbers the receipt shows.',
                    style: TextStyle(fontSize: 11, height: 1.45, color: AppColors.ink.withValues(alpha: 0.72)),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  bool _isMe(LeaderRow r) {
    final u = Api.instance.user;
    if (u == null || u.name != r.name) return false;
    return true;
  }
}

class _ImpactHero extends StatelessWidget {
  const _ImpactHero({required this.impact});
  final Impact impact;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.ink, Color(0xFF243325)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.22), blurRadius: 30, offset: const Offset(0, 14))],
      ),
      padding: const EdgeInsets.all(20),
      child: Stack(clipBehavior: Clip.none, children: [
        Positioned(
          right: -22,
          top: -38,
          child: Opacity(opacity: 0.09, child: DropMark(size: 150, color: AppColors.gold)),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Text('TOTAL DIVERTED',
                style: TextStyle(color: AppColors.gold, fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 1.6)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: Text('${impact.pickups} PICKUP${impact.pickups == 1 ? '' : 'S'}',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72), fontSize: 8.5, fontWeight: FontWeight.w800, letterSpacing: 1)),
            ),
          ]),
          const SizedBox(height: 8),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: impact.liters),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
              Text(v.toStringAsFixed(1),
                  style: const TextStyle(
                      color: Colors.white, fontSize: 46, height: 1, fontWeight: FontWeight.w800, letterSpacing: -2.2)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('litres', style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.12)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: HeroStat(
                label: 'CO₂e avoided',
                value: impact.co2Kg.toStringAsFixed(impact.co2Kg < 100 ? 1 : 0),
                unit: 'kg',
                color: AppColors.gold,
              ),
            ),
            Expanded(
              child: HeroStat(
                label: 'Biodiesel',
                value: impact.biodieselL.toStringAsFixed(1),
                unit: 'L',
                color: Colors.white,
              ),
            ),
            Expanded(
              child: HeroStat(
                label: 'Clean km',
                value: impact.carKm.toStringAsFixed(0),
                unit: 'km',
                color: Colors.white,
              ),
            ),
          ]),
        ]),
      ]),
    );
  }
}

class _Equivalence extends StatelessWidget {
  const _Equivalence({required this.icon, required this.value, required this.label, required this.color});
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(13)),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
            const SizedBox(height: 1),
            Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.muted, height: 1.35)),
          ]),
        ),
      ]),
    );
  }
}

class _LeaderRowCard extends StatelessWidget {
  const _LeaderRowCard({required this.row, required this.isMe, required this.last});
  final LeaderRow row;
  final bool isMe;
  final bool last;

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    final medal = row.rank <= 3 ? _medals[row.rank - 1] : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 14, 11),
      decoration: BoxDecoration(
        color: isMe ? AppColors.amberSoft.withValues(alpha: 0.55) : Colors.transparent,
        border: last ? null : const Border(bottom: BorderSide(color: AppColors.line)),
        borderRadius: isMe
            ? BorderRadius.circular(24)
            : (row.rank == 1 ? const BorderRadius.vertical(top: Radius.circular(24)) : null),
      ),
      child: Row(children: [
        SizedBox(
          width: 30,
          child: medal != null
              ? Text(medal, style: const TextStyle(fontSize: 18))
              : Text('${row.rank}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.muted)),
        ),
        const SizedBox(width: 8),
        Avatar(name: row.name, url: row.avatarUrl, size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(
                child: Text(row.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              ),
              if (isMe) ...[
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(8)),
                  child: const Text('YOU', style: TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                ),
              ],
            ]),
            Text('${orgIcon(row.orgType)} ${orgLabel(row.orgType)}${row.city == null ? '' : ' · ${row.city}'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10, color: AppColors.muted, fontWeight: FontWeight.w600)),
          ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(litres(row.liters).replaceAll(' L', ''),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
          const Text('litres', style: TextStyle(fontSize: 8.5, color: AppColors.muted, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}
