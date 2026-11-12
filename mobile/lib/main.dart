import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/api_client.dart';
import 'l10n/app_localizations.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/language_service.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.instance.init();
  await LanguageService.instance.load();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));

  // If the login token expires, send the user back to the login screen.
  Api.instance.onUnauthorized = () => navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );

  runApp(const OilMitraApp());
}

/// Rebuilds the whole app whenever the selected language changes.
class _LocaleListener extends StatefulWidget {
  final Widget child;
  const _LocaleListener({required this.child});

  @override
  State<_LocaleListener> createState() => _LocaleListenerState();
}

class _LocaleListenerState extends State<_LocaleListener> {
  @override
  void initState() {
    super.initState();
    LanguageService.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    LanguageService.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) => widget.child;

  // Rebuild when the widget is re-inserted after a language change triggers
  // setState on this state.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Force a rebuild so MaterialApp picks up the new locale strings.
  }
}

class OilMitraApp extends StatelessWidget {
  const OilMitraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return _LocaleListener(
      child: MaterialApp(
        title: AppLocalizations.of(context)?.t('app.title') ?? 'OilMitra',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: buildTheme(),
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3)),
            child: child!,
          );
        },
        home: Api.instance.isLoggedIn ? const HomeShell() : const LoginScreen(),
      ),
    );
  }
}
