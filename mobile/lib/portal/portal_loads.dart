import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../screens/listing_detail_screen.dart';
import '../theme.dart';
import '../widgets/listing_card.dart';

class PortalLoadsTab extends StatefulWidget {
  const PortalLoadsTab({super.key});

  @override
  State<PortalLoadsTab> createState() => _PortalLoadsTabState();
}

class _PortalLoadsTabState extends State<PortalLoadsTab> {
  List<OilListing> _items = [];
  bool _loading = true;
  String? _error;
  String _selectedStatus = 'all'; // all | open | claimed | collected | cancelled | expired
  final _searchCtrl = TextEditingController();

  final List<String> _statuses = ['all', 'open', 'claimed', 'collected', 'cancelled', 'expired'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final q = _searchCtrl.text.trim();
      final statusParam = _selectedStatus == 'all' ? null : _selectedStatus;
      final res = await Api.instance.listings(
        scope: 'all',
        status: statusParam,
        q: q.isEmpty ? null : q,
      );
      if (mounted) setState(() => _items = res);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top search and status filter bar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          color: const Color(0xFF121714),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _load(),
                      decoration: InputDecoration(
                        hintText: 'Search loads by title, supplier, address, city...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gold, size: 20),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _load();
                                },
                                icon: const Icon(Icons.clear_rounded, color: Colors.white38, size: 18),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                    tooltip: 'Refresh loads',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _statuses.map((st) {
                    final isSel = _selectedStatus == st;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSel,
                        label: Text(
                          st.toUpperCase(),
                          style: TextStyle(
                            color: isSel ? Colors.black : Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        selectedColor: AppColors.gold,
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        checkmarkColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                        onSelected: (val) {
                          if (val) {
                            setState(() => _selectedStatus = st);
                            _load();
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // List body
        Expanded(
          child: _loading && _items.isEmpty
              ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
              : _error != null && _items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.white38, size: 40),
                          const SizedBox(height: 10),
                          Text(_error!, style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 12),
                          FilledButton(onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : _items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inventory_2_outlined, color: Colors.white24, size: 54),
                              const SizedBox(height: 12),
                              Text(
                                'No loads matching "${_selectedStatus.toUpperCase()}"',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          color: AppColors.gold,
                          backgroundColor: const Color(0xFF1E2622),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              return ListingCard(
                                listing: item,
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ListingDetailScreen(listingId: item.id),
                                    ),
                                  );
                                  _load();
                                },
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}
