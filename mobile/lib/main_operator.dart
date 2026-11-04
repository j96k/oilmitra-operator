import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'admin/admin_login_screen.dart';
import 'admin/admin_shell.dart';
import 'api/api_client.dart';
import 'theme.dart';

final operatorNavigatorKey = GlobalKey<NavigatorState>();

/// Entry point for OilMitra Operators app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.instance.init();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));

  Api.instance.onUnauthorized = () => operatorNavigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
        (_) => false,
      );

  runApp(const OilMitraOperatorApp());
}

class OilMitraOperatorApp extends StatelessWidget {
  const OilMitraOperatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    final signedInOperator = Api.instance.isLoggedIn && (Api.instance.user?.isAdmin ?? false);
    return MaterialApp(
      title: 'OilMitra Operators',
      debugShowCheckedModeBanner: false,
      navigatorKey: operatorNavigatorKey,
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
