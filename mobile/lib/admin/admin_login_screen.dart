import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/server_dialog.dart';
import 'admin_shell.dart';

/// Operator-only sign in. Supplier accounts are rejected here — they belong in
/// the main OilMitra app, where oil owners list their loads.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> with SingleTickerProviderStateMixin {
  bool _busy = false;
  bool _obscure = true;
  late final AnimationController _pulse;

  final _username = TextEditingController();
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      _snack('Enter your operator username and password');
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.instance.login(_username.text.trim(), _password.text);
      final user = Api.instance.user;
      if (user == null || !user.isAdmin) {
        await Api.instance.logout();
        _snack('This account is not an OilMitra operator. Use the supplier app instead.');
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const AdminShell()), (_) => false);
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not connect. Check the server address (top right).');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _serverSettings() async {
    final ok = await ServerAddressDialog.show(context);
    if (ok) _snack('Connected to ${Api.instance.baseUrl}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ink,
      body: Stack(children: [
        Positioned(top: -140, left: -100, child: _Glow(color: AppColors.olive.withValues(alpha: 0.42), size: 380)),
        Positioned(bottom: -170, right: -120, child: _Glow(color: AppColors.amber.withValues(alpha: 0.24), size: 420)),
        SafeArea(
          child: Column(children: [
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                onPressed: _serverSettings,
                icon: const Icon(Icons.tune_rounded, color: Colors.white70),
                tooltip: 'Server address',
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, _) => Row(children: [
                      Container(
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.45 + 0.25 * _pulse.value)),
                        ),
                        child: const DropMark(size: 38),
                      ),
                      const SizedBox(width: 14),
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Text('OILMITRA',
                            style: TextStyle(
                                color: AppColors.gold,
                                fontSize: 10,
                                letterSpacing: 3.2,
                                fontWeight: FontWeight.w800)),
                        const Text('Operator console',
                            style: TextStyle(
                                color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.9)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 30),
                  const Text('Run the\npickup network.',
                      style: TextStyle(
                          color: Colors.white, fontSize: 42, height: 1.0, fontWeight: FontWeight.w800, letterSpacing: -2)),
                  const SizedBox(height: 14),
                  Text(
                    'Claim open loads, plan the van route, record what you collect and keep every supplier paid and informed.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.66), fontSize: 14, height: 1.55),
                  ),
                  const SizedBox(height: 22),
                  Wrap(spacing: 8, runSpacing: 8, children: const [
                    _OperatorChip(icon: Icons.radar_rounded, text: 'Live oil radar'),
                    _OperatorChip(icon: Icons.route_rounded, text: 'Pickup route'),
                    _OperatorChip(icon: Icons.receipt_long_rounded, text: 'Receipts'),
                  ]),
                  const SizedBox(height: 26),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.shield_outlined, size: 20, color: AppColors.gold),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          'Operator access only. Supplier accounts sign in through the OilMitra app.',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.62), fontSize: 11.5, height: 1.45),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 40, offset: const Offset(0, -8))],
              ),
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.terminal_rounded, size: 18, color: AppColors.gold),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('SECURE SIGN IN',
                          style: TextStyle(fontSize: 9.5, letterSpacing: 1.5, fontWeight: FontWeight.w800, color: AppColors.amberDeep)),
                      Text('Operator account',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),
                TextField(
                  controller: _username,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(hintText: 'Operator username', prefixIcon: Icon(Icons.person_outline_rounded, size: 20)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _password,
                  obscureText: _obscure,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 19),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                      : const Text('Enter console'),
                ),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Operator accounts are created by OilMitra in the database.\nSupplier accounts sign in through the OilMitra app.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.45),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _OperatorChip extends StatelessWidget {
  const _OperatorChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.22)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: AppColors.gold),
        const SizedBox(width: 5),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}
