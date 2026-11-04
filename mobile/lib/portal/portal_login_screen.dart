import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/server_dialog.dart';
import 'portal_shell.dart';

/// Executive Sign In for myOilMitra â€” Super Admin / Owner Portal.
class PortalLoginScreen extends StatefulWidget {
  const PortalLoginScreen({super.key});

  @override
  State<PortalLoginScreen> createState() => _PortalLoginScreenState();
}

class _PortalLoginScreenState extends State<PortalLoginScreen> with SingleTickerProviderStateMixin {
  bool _busy = false;
  bool _obscure = true;
  late final AnimationController _pulse;

  final _username = TextEditingController();
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);
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
    final u = _username.text.trim();
    final p = _password.text;
    if (u.isEmpty || p.isEmpty) {
      _snack('Enter your myOilMitra administrator credentials');
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.instance.login(u, p);
      final user = Api.instance.user;
      if (user == null || !user.isAdmin) {
        await Api.instance.logout();
        _snack('Access restricted: Only verified OilMitra administrators can enter.');
        return;
      }
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PortalShell()),
        (_) => false,
      );
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
      backgroundColor: const Color(0xFF0C100E),
      body: Stack(
        children: [
          Positioned(
            top: -160,
            left: -120,
            child: _Glow(color: const Color(0xFF2E6F40).withValues(alpha: 0.35), size: 450),
          ),
          Positioned(
            bottom: -180,
            right: -130,
            child: _Glow(color: const Color(0xFFD49B24).withValues(alpha: 0.25), size: 480),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: _serverSettings,
                    icon: const Icon(Icons.tune_rounded, color: Colors.white70),
                    tooltip: 'Server address',
                  ),
                ),
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AnimatedBuilder(
                              animation: _pulse,
                              builder: (_, _) => Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.06),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.gold.withValues(alpha: 0.4 + 0.3 * _pulse.value),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: const DropMark(size: 42),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'myOilMitra',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 26,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -1,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.gold.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
                                            ),
                                            child: const Text(
                                              'CONTROL',
                                              style: TextStyle(
                                                color: AppColors.gold,
                                                fontSize: 9,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: 1.4,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'Super Admin & Operations Portal',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.65),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 36),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF161C19),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 30,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Executive Login',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Manage the entire OilMitra network, rates, operators & loads.',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 13),
                                  ),
                                  const SizedBox(height: 24),
                                  TextField(
                                    controller: _username,
                                    style: const TextStyle(color: Colors.white),
                                    textInputAction: TextInputAction.next,
                                    decoration: InputDecoration(
                                      hintText: 'Admin username',
                                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                                      prefixIcon: const Icon(Icons.person_outline_rounded, color: AppColors.gold),
                                      filled: true,
                                      fillColor: Colors.white.withValues(alpha: 0.05),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  TextField(
                                    controller: _password,
                                    style: const TextStyle(color: Colors.white),
                                    obscureText: _obscure,
                                    onSubmitted: (_) => _submit(),
                                    decoration: InputDecoration(
                                      hintText: 'Password',
                                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.gold),
                                      filled: true,
                                      fillColor: Colors.white.withValues(alpha: 0.05),
                                      suffixIcon: IconButton(
                                        onPressed: () => setState(() => _obscure = !_obscure),
                                        icon: Icon(
                                          _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                          color: Colors.white54,
                                        ),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  FilledButton(
                                    onPressed: _busy ? null : _submit,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.gold,
                                      foregroundColor: Colors.black,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                    child: _busy
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.black),
                                          )
                                        : const Text(
                                            'Enter myOilMitra',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Center(
                              child: Text(
                                'ðŸ”’ Restricted executive portal for OilMitra platform owners.\nUse your database admin credentials to log in.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 11.5,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
