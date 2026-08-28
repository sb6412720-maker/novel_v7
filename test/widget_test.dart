import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:novel_mobile_app/main.dart';

void main() {
  testWidgets('starts the application shell while loading', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const InkittCloneApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
