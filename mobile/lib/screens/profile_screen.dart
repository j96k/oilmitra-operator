import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../models.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/server_dialog.dart';
import 'login_screen.dart';

/// Profile, money and the rate board. Small account edits live here so a
/// supplier never has to leave the app to correct a phone number.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.loginBuilder});
  final WidgetBuilder? loginBuilder;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();
  Dashboard? _data;
  List<OilRate> _rates = [];
  bool _loading = true;
  String? _error;
  bool _uploading = false;

  AppUser? get _user => Api.instance.user;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _data == null;
      _error = null;
    });
    try {
      final results = await Future.wait([
        Api.instance.dashboard(),
        Api.instance.rates(),
        Api.instance.refreshMe(),
      ]);
      if (!mounted) return;
      setState(() {
        _data = results[0] as Dashboard;
        _rates = results[1] as List<OilRate>;
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
        _error = 'Could not load your profile.';
        _loading = false;
      });
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // ---------------- account ----------------

  Future<void> _changePhoto() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 900, imageQuality: 85);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() => _uploading = true);
      await Api.instance.uploadAvatar(bytes, file.name);
      if (!mounted) return;
      setState(() => _uploading = false);
      _snack('Profile photo updated.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _uploading = false);
      _snack(e.message);
    } catch (_) {
      if (mounted) setState(() => _uploading = false);
      _snack('Could not open photos.');
    }
  }

  Future<void> _editProfile() async {
    final u = _user;
    if (u == null) return;
    final name = TextEditingController(text: u.name);
    final phone = TextEditingController(text: u.phone ?? '');
    final city = TextEditingController(text: u.city ?? '');
    var orgType = u.orgType;
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        return AlertDialog(
          title: const Text('Edit details', style: TextStyle(fontWeight: FontWeight.w800)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextField(
                controller: name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Business / name'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: orgType,
                decoration: const InputDecoration(labelText: 'Type'),
                items: orgTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text('${orgIcon(t)}  ${orgLabel(t)}')))
                    .toList(),
                onChanged: (v) => setS(() => orgType = v ?? 'other'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.call_outlined, size: 20)),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: city,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'City', prefixIcon: Icon(Icons.location_city_rounded, size: 20)),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        );
      }),
    );
    if (save != true) return;
    if (name.text.trim().length < 2) return _snack('Name is too short.');
    try {
      await Api.instance.updateProfile(
        name: name.text.trim(),
        orgType: orgType,
        phone: phone.text.trim(),
        city: city.text.trim(),
      );
      await _load();
      _snack('Details saved.');
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _serverSettings() async {
    final ok = await ServerAddressDialog.show(context);
    if (ok) {
      _snack('Connected to ${Api.instance.baseUrl}');
      _load();
    }
  }

  Future<void> _editRate(OilRate r) async {
    final ctrl = TextEditingController(text: r.price.toStringAsFixed(r.price % 1 == 0 ? 0 : 2));
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${oilLabel(r.oilType)} rate', style: const TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          decoration: const InputDecoration(labelText: 'Price per litre', prefixText: '₹ '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    if (save != true) return;
    final price = double.tryParse(ctrl.text);
    if (price == null || price <= 0) return _snack('Enter a valid price.');
    try {
      await Api.instance.setRate(r.oilType, price);
      await _load();
      _snack('${oilLabel(r.oilType)} rate updated.');
    } on ApiException catch (e) {
      _snack(e.message);
    }
  }

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Your listings and pickups stay safe on the server.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44), backgroundColor: AppColors.cancelled),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await Api.instance.logout();
    if (!mounted) return;
    final login = widget.loginBuilder ?? (_) => const LoginScreen();
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: login), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _user == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.amberDeep));
    }
    final u = _user;
    if (u == null) {
      return EmptyState(
        icon: Icons.person_off_rounded,
        title: 'Not signed in',
        subtitle: _error,
        action: FilledButton(onPressed: _load, child: const Text('Try again')),
      );
    }
    final d = _data;
    return RefreshIndicator(
      color: AppColors.amberDeep,
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              child: Row(children: [
                const Expanded(
                  child: Text('Profile',
                      style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -0.9)),
                ),
                IconButton(
                  onPressed: _load,
                  style: IconButton.styleFrom(backgroundColor: Colors.white, side: const BorderSide(color: AppColors.line)),
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.ink,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [BoxShadow(color: AppColors.ink.withValues(alpha: 0.22), blurRadius: 28, offset: const Offset(0, 12))],
              ),
              child: Stack(clipBehavior: Clip.none, children: [
                Positioned(
                  right: -26,
                  bottom: -36,
                  child: Opacity(opacity: 0.08, child: DropMark(size: 150, color: AppColors.gold)),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    GestureDetector(
                      onTap: _uploading ? null : _changePhoto,
                      child: Stack(clipBehavior: Clip.none, children: [
                        Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.gold, width: 2),
                          ),
                          child: Avatar(name: u.name, url: u.avatarUrl, size: 62),
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: const BoxDecoration(color: AppColors.amber, shape: BoxShape.circle),
                            child: _uploading
                                ? const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
                                  )
                                : const Icon(Icons.camera_alt_rounded, size: 12, color: AppColors.ink),
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Flexible(
                            child: Text(u.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                          ),
                          if (u.isAdmin) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.gold, borderRadius: BorderRadius.circular(8)),
                              child: const Text('ADMIN',
                                  style: TextStyle(color: AppColors.ink, fontSize: 7.5, fontWeight: FontWeight.w900, letterSpacing: 0.7)),
                            ),
                          ],
                        ]),
                        const SizedBox(height: 2),
                        Text('@${u.username}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11.5, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 7),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          _DarkChip(
                            icon: Icons.soup_kitchen_rounded,
                            text: orgLabel(u.orgType),
                          ),
                          if (u.city != null && u.city!.trim().isNotEmpty)
                            _DarkChip(icon: Icons.location_on_rounded, text: u.city!),
                        ]),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  Container(height: 1, color: Colors.white.withValues(alpha: 0.12)),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(
                      child: HeroStat(label: 'Litres saved', value: (d?.impact.liters ?? 0).toStringAsFixed(0), unit: 'L', color: AppColors.gold),
                    ),
                    Expanded(
                      child: HeroStat(label: 'Pickups', value: '${d?.impact.pickups ?? 0}'),
                    ),
                    Expanded(
                      child: HeroStat(
                        label: (u.isAdmin) ? 'Paid out' : 'Earned',
                        value: money(d?.moneyTotal ?? 0),
                      ),
                    ),
                  ]),
                ]),
              ]),
            ),
          ),
          const SectionHead('Account'),
          _Card(children: [
            _RowTile(
              icon: Icons.edit_outlined,
              title: 'Edit details',
              subtitle: 'Name, phone and city',
              onTap: _editProfile,
            ),
            _RowTile(
              icon: Icons.photo_camera_outlined,
              title: 'Change profile photo',
              subtitle: 'Shown on your listings and pickups',
              onTap: _uploading ? null : _changePhoto,
            ),
            _RowTile(
              icon: Icons.dns_outlined,
              title: 'Server address',
              subtitle: Api.instance.baseUrl,
              onTap: _serverSettings,
              last: true,
            ),
          ]),
          SectionHead('Rate board', action: u.isAdmin ? 'Admin · tap to edit' : null),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(children: [
                for (var n = 0; n < _rates.length; n++)
                  InkWell(
                    onTap: u.isAdmin ? () => _editRate(_rates[n]) : null,
                    borderRadius: n == 0
                        ? const BorderRadius.vertical(top: Radius.circular(22))
                        : (n == _rates.length - 1 ? const BorderRadius.vertical(bottom: Radius.circular(22)) : BorderRadius.zero),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: n == _rates.length - 1 ? null : const Border(bottom: BorderSide(color: AppColors.line)),
                      ),
                      child: Row(children: [
                        Text(oilEmoji(_rates[n].oilType), style: const TextStyle(fontSize: 17)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text('${oilLabel(_rates[n].oilType)} oil',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                        Text('${money(_rates[n].price)}/L',
                            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
                        if (u.isAdmin) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.edit_rounded, size: 13, color: AppColors.muted),
                        ],
                      ]),
                    ),
                  ),
                if (_rates.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(18),
                    child: Text('Rates will appear when connected.', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                  ),
              ]),
            ),
          ),
          const SectionHead('About'),
          _Card(children: [
            const _RowTile(
              icon: Icons.info_outline_rounded,
              title: 'OilMitra 1.0.0',
              subtitle: 'Used oil. Real value. Picked up.',
            ),
            _RowTile(
              icon: Icons.receipt_long_outlined,
              title: 'How receipts work',
              subtitle: 'Every completed pickup gets a shareable receipt link.',
              last: true,
              onTap: () => showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Pickup receipts', style: TextStyle(fontWeight: FontWeight.w800)),
                  content: const Text(
                    'When a pickup is recorded, OilMitra creates a receipt with a private link. '
                    'The supplier and the OilMitra team can open it, share it on WhatsApp, or keep it for accounts.\n\n'
                    'Money changes hands offline — the app only records the agreed amount.',
                    style: TextStyle(height: 1.5, fontSize: 13),
                  ),
                  actions: [
                    FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: OutlinedButton.icon(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.cancelled,
                side: BorderSide(color: AppColors.cancelled.withValues(alpha: 0.4)),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Log out'),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(children: children),
      ),
    );
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.last = false,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: last ? const BorderRadius.vertical(bottom: Radius.circular(22)) : BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          border: last ? null : const Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: AppColors.cream, shape: BoxShape.circle),
            child: Icon(icon, size: 17, color: AppColors.inkSoft),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              if (subtitle != null)
                Text(subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
            ]),
          ),
          if (onTap != null) const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.muted),
        ]),
      ),
    );
  }
}

class _DarkChip extends StatelessWidget {
  const _DarkChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: AppColors.gold),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 10, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
