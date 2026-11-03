import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:oil_mitra/admin/admin_login_screen.dart';
import 'package:oil_mitra/theme.dart';
import 'package:oil_mitra/widgets/common.dart';

void main() {
  testWidgets('OilMitra brand mark renders', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(),
        home: const Scaffold(body: Center(child: DropMark(size: 64))),
      ),
    );

    expect(find.byType(DropMark), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('operator console shows sign-in and provisioning', (WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildTheme(), home: const AdminLoginScreen()));
    await tester.pump(const Duration(milliseconds: 120));

    expect(find.text('Operator console'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create operator'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
