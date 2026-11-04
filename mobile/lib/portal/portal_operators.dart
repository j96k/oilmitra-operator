import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';

class PortalOperatorsTab extends StatefulWidget {
  const PortalOperatorsTab({super.key});

  @override
  State<PortalOperatorsTab> createState() => _PortalOperatorsTabState();
}

class _PortalOperatorsTabState extends State<PortalOperatorsTab> {
  List<OperatorAccount> _operators = [];
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
      final res = await Api.instance.operators();
      if (mounted) setState(() => _operators = res);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateDialog() async {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    bool obscure = true;

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E2622),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.gold, size: 22),
              ),
              const SizedBox(width: 12),
              const Text(
                'Add Operator Account',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Provision credentials for a field pickup agent or driver. They will log in using the OilMitra Operators app.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: userCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Operator Username',
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    hintText: 'e.g. driver_ajay',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Full Name / Route Title',
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    hintText: 'e.g. Ajay Sharma (North Route)',
                    hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: obscure,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Password (min 6 characters)',
                    labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.white54, size: 20),
                      onPressed: () => setDlgState(() => obscure = !obscure),
                    ),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            FilledButton(
              onPressed: () async {
                final u = userCtrl.text.trim();
                final p = passCtrl.text;
                final n = nameCtrl.text.trim();
                if (u.isEmpty || p.length < 6 || n.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter valid username, name, and 6+ char password')),
                  );
                  return;
                }
                try {
                  await Api.instance.createOperator(username: u, password: p, name: n);
                  Navigator.of(ctx).pop(true);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
              child: const Text('Create Operator', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );

    if (created == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Operator successfully created!')),
      );
      _load();
    }
  }

  Future<void> _deleteOperator(OperatorAccount op) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2622),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Revoke Operator Access?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Remove operator "${op.username}" (${op.name})? They will no longer be able to sign in or claim loads.',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Revoke Access'),
          ),
        ],
      ),
    );

    if (ok == true && mounted) {
      try {
        await Api.instance.deleteOperator(op.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Operator ${op.username} removed.')),
        );
        _load();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        backgroundColor: AppColors.gold,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('New Operator', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.gold,
        backgroundColor: const Color(0xFF1E2622),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Team & Field Staff',
                        style: TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Operators Hub',
                        style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: -0.8),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                  tooltip: 'Refresh operators',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Manage field operators authorized to claim and collect used cooking oil via the OilMitra Operators app.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),

            if (_loading && _operators.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: AppColors.gold)),
              )
            else if (_error != null && _operators.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.cloud_off_rounded, color: Colors.white38, size: 40),
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                ),
              )
            else if (_operators.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.group_off_rounded, color: Colors.white24, size: 54),
                      const SizedBox(height: 12),
                      Text(
                        'No operators provisioned yet',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 15),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _openCreateDialog,
                        icon: const Icon(Icons.person_add_rounded),
                        label: const Text('Create First Operator'),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._operators.map((op) {
                final isCurrent = op.username == Api.instance.user?.username;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF161C19),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isCurrent ? AppColors.gold.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08),
                        width: isCurrent ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.badge_rounded, color: AppColors.gold, size: 22),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    op.name,
                                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                                  ),
                                  if (isCurrent) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.gold.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'YOU',
                                        style: TextStyle(color: AppColors.gold, fontSize: 9, fontWeight: FontWeight.w800),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '@${op.username}',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13, fontFamily: 'monospace'),
                              ),
                              if (op.createdAt != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Created ${dayMonthTime(op.createdAt!)}',
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!isCurrent)
                          IconButton(
                            onPressed: () => _deleteOperator(op),
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 22),
                            tooltip: 'Revoke operator',
                          ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
