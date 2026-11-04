import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';

class PortalRatesTab extends StatefulWidget {
  const PortalRatesTab({super.key});

  @override
  State<PortalRatesTab> createState() => _PortalRatesTabState();
}

class _PortalRatesTabState extends State<PortalRatesTab> {
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
      _loading = true;
      _error = null;
    });
    try {
      final res = await Api.instance.rates();
      if (mounted) setState(() => _rates = res);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editRate(OilRate rate) async {
    final ctrl = TextEditingController(text: rate.price.toStringAsFixed(rate.price.truncateToDouble() == rate.price ? 0 : 2));
    final newPrice = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2622),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            const Icon(Icons.edit_note_rounded, color: AppColors.gold, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Update Rate: ${oilLabel(rate.oilType)}',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set the network buying price per litre for ${oilLabel(rate.oilType)}. Suppliers and operators will immediately see this updated rate.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                prefixText: 'â‚¹ ',
                prefixStyle: const TextStyle(color: AppColors.gold, fontSize: 18, fontWeight: FontWeight.w800),
                suffixText: '/ L',
                suffixStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                hintText: '0.00',
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(ctrl.text.trim());
              if (parsed == null || parsed < 0) return;
              Navigator.of(ctx).pop(parsed);
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
            child: const Text('Save Rate', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (newPrice != null && mounted) {
      try {
        await Api.instance.setRate(rate.oilType, newPrice);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated ${oilLabel(rate.oilType)} to ₹$newPrice / L')),
        );
        _load();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update rate: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _rates.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.gold));
    }
    if (_error != null && _rates.isEmpty) {
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
                      'Price Master Control',
                      style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Live Rate Board',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                tooltip: 'Refresh rates',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tap any oil card to modify the official buying price per litre across all platform users.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),

          ..._rates.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _editRate(r),
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161C19),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.water_drop_rounded, color: AppColors.gold, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                oilLabel(r.oilType),
                                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Code: ${r.oilType}',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              money(r.price),
                              style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              'per litre',
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.edit_rounded, color: Colors.white70, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
