import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin/admin_login_screen.dart';
import 'admin/admin_shell.dart';
import 'api/api_client.dart';
import 'theme.dart';

final adminNavigatorKey = GlobalKey<NavigatorState>();

/// Entry point for the OilMitra operator app, served at /admin/.
/// Supplier accounts keep using the main app at /app/.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.instance.init();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));

  Api.instance.onUnauthorized = () => adminNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
        (_) => false,
      );

  runApp(const OilMitraAdminApp());
}

class OilMitraAdminApp extends StatelessWidget {
  const OilMitraAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    final signedInOperator = Api.instance.isLoggedIn && (Api.instance.user?.isAdmin ?? false);
    return MaterialApp(
      title: 'OilMitra Operator',
      debugShowCheckedModeBanner: false,
      navigatorKey: adminNavigatorKey,
      theme: buildTheme(),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3)),
          child: child!,
        );
      },
      home: signedInOperator ? const AdminShell() : const AdminLoginScreen(),
    );
  }
}
