import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api/api_client.dart';
import 'portal/portal_login_screen.dart';
import 'portal/portal_shell.dart';
import 'theme.dart';

final portalNavigatorKey = GlobalKey<NavigatorState>();

/// Entry point for myOilMitra — the Super Admin / Owner Portal.
/// Handles both OilMitra (suppliers) and OilMitra Operators (pickups).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.instance.init();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));

  Api.instance.onUnauthorized = () => portalNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const PortalLoginScreen()),
        (_) => false,
      );

  runApp(const MyOilMitraApp());
}

class MyOilMitraApp extends StatelessWidget {
  const MyOilMitraApp({super.key});

  @override
  Widget build(BuildContext context) {
    final signedInAdmin = Api.instance.isLoggedIn && (Api.instance.user?.isAdmin ?? false);
    return MaterialApp(
      title: 'myOilMitra — Executive Portal',
      debugShowCheckedModeBanner: false,
      navigatorKey: portalNavigatorKey,
      theme: buildTheme(),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3)),
          child: child!,
        );
      },
      home: signedInAdmin ? const PortalShell() : const PortalLoginScreen(),
    );
  }
}
