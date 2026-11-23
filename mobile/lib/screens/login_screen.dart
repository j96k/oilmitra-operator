import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../l10n/app_localizations.dart';
import '../services/firebase_auth_service.dart';
import '../services/language_service.dart';
import '../theme.dart';
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
  bool _showPhoneLogin = true; // Phone OTP shown by default
  late final AnimationController _float;

  final _username = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  final _otpPhone = TextEditingController();
  final _otpCode = TextEditingController();
  String _verificationId = '';
  bool _otpSent = false;
  bool _otpBusy = false;

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
    _otpPhone.dispose();
    _otpCode.dispose();
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

  // ---- Phone OTP login section (primary) ----

  Widget _buildPhoneLoginSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Login with phone',
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 12),
        if (!_otpSent) ...[
          Row(children: [
            Expanded(
              child: TextField(
                controller: _otpPhone,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(
                  hintText: '98765 43210',
                  prefixText: '+91 ',
                  prefixIcon: Icon(Icons.phone_rounded, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _otpBusy ? null : _sendOtp,
              child: _otpBusy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Send OTP'),
            ),
          ]),
        ] else ...[
          TextField(
            controller: _otpCode,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              hintText: '123456',
              prefixIcon: Icon(Icons.lock_rounded, size: 18),
              labelText: '6-digit OTP',
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _otpBusy ? null : _verifyOtpAndLogin,
            child: _otpBusy
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Verify & Login'),
          ),
          TextButton(
            onPressed: _otpBusy ? null : _sendOtp,
            child: const Text('Resend OTP'),
          ),
        ],
      ]),
    );
  }

  // ---- Username/Password login section (secondary) ----

  Widget _buildUsernamePasswordSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Login with username & password',
            style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 12),
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
              : const Text('Log in'),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'Welcome back — checking today\'s loads.',
            style: const TextStyle(fontSize: 11.5, color: AppColors.muted),
          ),
        ),
      ]),
    );
  }

  Future<void> _sendOtp() async {
    final phone = _otpPhone.text.trim();
    if (phone.length < 10) return _snack('Enter a valid 10-digit phone number');
    setState(() => _otpBusy = true);
    try {
      await FirebaseAuthService.sendOtp(
        phoneNumber: '+91$phone',
        onCodeSent: (id, token) {
          setState(() {
            _verificationId = id;
            _otpSent = true;
            _otpBusy = false;
          });
          _snack('OTP sent to +91$phone');
        },
        onFailed: (e) {
          setState(() => _otpBusy = false);
          _snack('OTP failed: ${e.message}');
        },
        onAutoRetrieved: (cred) async {
          await _verifyOtpCredential(cred);
        },
        onCodeRetrieved: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (_) {
      setState(() => _otpBusy = false);
      _snack('Could not send OTP.');
    }
  }

  Future<void> _verifyOtpAndLogin() async {
    final code = _otpCode.text.trim();
    if (code.length != 6) return _snack('Enter 6-digit OTP');
    setState(() => _otpBusy = true);
    try {
      await FirebaseAuthService.verifyOtp(
        smsCode: code,
        verificationId: _verificationId,
      );
      final idToken = await FirebaseAuthService.getIdToken();
      if (idToken == null) return _snack('Login failed.');

      final res = await Api.instance.post('/auth/firebase-login', {
        'firebase_token': idToken,
      });
      if (!mounted) return;
      final token = res['access_token'];
      Api.instance.token = token;
      await Api.instance.init();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (_) => false,
      );
    } catch (e) {
      setState(() => _otpBusy = false);
      _snack('OTP verification failed.');
    }
  }

  Future<void> _verifyOtpCredential(PhoneAuthCredential credential) async {
    setState(() => _otpBusy = true);
    try {
      await FirebaseAuthService.signInWithCredential(credential);
      final idToken = await FirebaseAuthService.getIdToken();
      if (idToken == null) return _snack('Login failed.');

      final res = await Api.instance.post('/auth/firebase-login', {
        'firebase_token': idToken,
      });
      if (!mounted) return;
      final token = res['access_token'];
      Api.instance.token = token;
      await Api.instance.init();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeShell()),
        (_) => false,
      );
    } catch (e) {
      setState(() => _otpBusy = false);
      _snack('Auto OTP verification failed.');
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
                  _LanguageSelector(),
                  const SizedBox(height: 18),

                  // Primary: Phone OTP login
                  if (_showPhoneLogin)
                    _buildPhoneLoginSection(),

                  if (!_showPhoneLogin)
                    _buildUsernamePasswordSection(),

                  const SizedBox(height: 14),

                  // Toggle between phone and username/password
                  if (_showPhoneLogin)
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() => _showPhoneLogin = false),
                        child: const Text(
                          'Login with username & password instead',
                          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                      ),
                    )
                  else
                    Center(
                      child: TextButton(
                        onPressed: () => setState(() => _showPhoneLogin = true),
                        child: const Text(
                          'Login with phone OTP instead',
                          style: TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700, fontSize: 12.5),
                        ),
                      ),
                    ),

                  const SizedBox(height: 10),
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

/// Language picker shown at the top of the login card. Choosing a language
/// saves it and rebuilds the whole supplier app immediately.
class _LanguageSelector extends StatefulWidget {
  const _LanguageSelector();

  @override
  State<_LanguageSelector> createState() => _LanguageSelectorState();
}

class _LanguageSelectorState extends State<_LanguageSelector> {
  late String _value;

  @override
  void initState() {
    super.initState();
    _value = LanguageService.instance.locale;
    LanguageService.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    LanguageService.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() => _value = LanguageService.instance.locale);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.language_rounded, size: 18, color: AppColors.muted),
        const SizedBox(width: 8),
        Text(loc.t('login.language'),
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.muted)),
      ]),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: _value,
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          filled: true,
          fillColor: Colors.white,
        ),
        items: languageOptions.entries.map((e) {
          return DropdownMenuItem(
            value: e.key,
            child: Row(children: [
              Text(e.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          );
        }).toList(),
        onChanged: (v) async {
          if (v == null) return;
          await LanguageService.instance.set(v);
          if (!mounted) return;
          setState(() => _value = v);
        },
      ),
    ]);
  }
}

