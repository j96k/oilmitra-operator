import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../utils.dart';
import '../widgets/common.dart';
import '../widgets/server_dialog.dart';
import 'home_shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  bool _register = false;
  bool _busy = false;
  String _orgType = 'restaurant';
  bool _obscure = true;
  late final AnimationController _float;

  final _username = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();

  @override
  void initState() {
    super.initState();
    _float = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _float.dispose();
    _username.dispose();
    _password.dispose();
    _name.dispose();
    _phone.dispose();
    _city.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_username.text.trim().isEmpty || _password.text.isEmpty) {
      _snack('Enter your username and password');
      return;
    }
    if (_register && _name.text.trim().length < 2) {
      _snack('Enter your shop or business name');
      return;
    }
    setState(() => _busy = true);
    try {
      if (_register) {
        await Api.instance.register(
          username: _username.text.trim(),
          password: _password.text,
          name: _name.text.trim(),
          role: 'supplier',
          orgType: _orgType,
          phone: _phone.text.trim(),
          city: _city.text.trim(),
        );
      } else {
        await Api.instance.login(_username.text.trim(), _password.text);
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeShell()), (_) => false);
    } on ApiException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('Could not connect. Check Settings (top right).');
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
        // Warm atmosphere
        Positioned(top: -120, right: -80, child: _Glow(color: AppColors.amber.withValues(alpha: 0.28), size: 340)),
        Positioned(top: 120, left: -140, child: _Glow(color: AppColors.olive.withValues(alpha: 0.35), size: 320)),
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
                    animation: _float,
                    builder: (_, _) => Transform.translate(
                      offset: Offset(0, -6 * _float.value),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                          ),
                          child: const DropMark(size: 42),
                        ),
                        const SizedBox(width: 14),
                        const Text('OilMitra',
                            style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1.4)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text('Used oil.\nReal value.',
                      style: TextStyle(color: Colors.white, fontSize: 40, height: 1.02, fontWeight: FontWeight.w800, letterSpacing: -1.8)),
                  const SizedBox(height: 12),
                  Text('Hotels, restaurants, marriage halls and homes — list your used cooking oil. Our pickup team collects it, and you get paid on the spot.',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.68), fontSize: 14, height: 1.55)),
                  const SizedBox(height: 22),
                  Wrap(spacing: 8, runSpacing: 8, children: const [
                    _HeroChip(icon: Icons.bolt_rounded, text: 'Direct pickup'),
                    _HeroChip(icon: Icons.payments_outlined, text: 'Paid per litre'),
                    _HeroChip(icon: Icons.eco_rounded, text: 'Not down the drain'),
                  ]),
                  const SizedBox(height: 26),
                ]),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 40, offset: const Offset(0, -8))],
              ),
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: SingleChildScrollView(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(
                      child: _ModeTab(label: 'Log in', active: !_register, onTap: () => setState(() => _register = false)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ModeTab(label: 'Create account', active: _register, onTap: () => setState(() => _register = true)),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  if (_register) ...[
                    _field(_name, 'Shop, hotel or home name', Icons.storefront_rounded),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: _orgType,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.category_outlined, size: 20)),
                      items: orgTypes
                          .map((t) => DropdownMenuItem(value: t, child: Text('${orgIcon(t)}  ${orgLabel(t)}')))
                          .toList(),
                      onChanged: (v) => setState(() => _orgType = v ?? 'other'),
                    ),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _field(_city, 'City', Icons.location_city_rounded)),
                      const SizedBox(width: 10),
                      Expanded(child: _field(_phone, 'Phone', Icons.call_outlined, keyboard: TextInputType.phone)),
                    ]),
                    const SizedBox(height: 10),
                  ],
                  _field(_username, 'Username', Icons.person_outline_rounded),
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
                        : Text(_register ? 'Create account' : 'Log in'),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(
                      _register ? 'Your oil, your rate, your pickup.' : 'Welcome back — checking today\'s loads.',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
                    ),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon, {TextInputType? keyboard}) => TextField(
        controller: c,
        keyboardType: keyboard,
        decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, size: 20)),
      );
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.ink : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? AppColors.ink : AppColors.line),
        ),
        child: Text(label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              color: active ? Colors.white : AppColors.muted,
            )),
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
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
