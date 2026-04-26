// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:floating_video_player/floating_video_player.dart';

void main() {
  testWidgets('FloatingViewProvider smoke test', (WidgetTester tester) async {
    final controller = FloatingViewController();
    await tester.pumpWidget(
      FloatingViewProvider(
        controller: controller,
        child: const MaterialApp(home: Scaffold(body: Text('test'))),
      ),
    );

    expect(find.text('test'), findsOneWidget);
    expect(controller.floatingState.value, FloatingState.closed);
  });
}
