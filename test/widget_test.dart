// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bloodlink/main.dart';
import 'package:bloodlink/core/theme/app_theme.dart';
import 'package:bloodlink/core/widgets/responsive_content.dart';

void main() {
  testWidgets('app builds and mounts MaterialApp', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('responsive content stays readable on wide and narrow screens',
      (WidgetTester tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    final content = find.byKey(const ValueKey('responsive-content'));

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(
      const MaterialApp(
        home: ResponsiveContent(
          maxWidth: 720,
          child: SizedBox(
            key: ValueKey('responsive-content'),
            width: double.infinity,
            height: 24,
          ),
        ),
      ),
    );
    expect(tester.getSize(content).width, 720);

    tester.view.physicalSize = const Size(320, 800);
    await tester.pump();
    expect(tester.getSize(content).width, 320);
  });

  test('light and dark themes expose distinct, legible surfaces', () {
    final light = AppTheme.light();
    final dark = AppTheme.dark();

    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.colorScheme.primary, isNot(light.colorScheme.surface));
    expect(dark.colorScheme.primary, isNot(dark.colorScheme.surface));
    expect(light.cardTheme.elevation, 0);
    expect(dark.cardTheme.elevation, 0);
  });
}
