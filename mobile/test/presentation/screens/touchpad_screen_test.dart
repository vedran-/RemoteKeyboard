/// Widget Tests for TouchpadScreen
///
/// Verifies the touchpad UI renders correctly
/// and gesture handling is set up.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_keyboard_mobile/presentation/screens/touchpad_screen.dart';

void main() {
  group('TouchpadScreen', () {
    testWidgets('renders with app bar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const TouchpadScreen(),
        ),
      );

      // Verify app bar
      expect(find.text('Touchpad'), findsOneWidget);
    });

    testWidgets('shows sensitivity menu button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const TouchpadScreen(),
        ),
      );

      // Verify sensitivity menu exists (three dot icon)
      expect(find.byIcon(Icons.more_vert), findsOneWidget);
    });

    testWidgets('shows touchpad area', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const TouchpadScreen(),
        ),
      );

      // Verify touchpad area exists (check for the instruction text that's inside the touchpad)
      expect(find.text('Touch and drag to move cursor'), findsOneWidget);
      expect(find.byIcon(Icons.touch_app), findsOneWidget);
    });

    testWidgets('shows instruction text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const TouchpadScreen(),
        ),
      );

      // Verify instruction text
      expect(find.text('Touch and drag to move cursor'), findsOneWidget);
      expect(
        find.text('Tap = Left Click | Two-finger tap = Right Click'),
        findsOneWidget,
      );
    });

    testWidgets('shows left and right click buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const TouchpadScreen(),
        ),
      );

      // Verify mouse buttons
      expect(find.text('Left Click'), findsOneWidget);
      expect(find.text('Right Click'), findsOneWidget);
      expect(find.byIcon(Icons.mouse), findsNWidgets(2));
    });

    testWidgets('sensitivity menu has all options', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const TouchpadScreen(),
        ),
      );

      // Open sensitivity menu
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      // Verify menu options
      expect(find.text('Low'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('High'), findsOneWidget);
      expect(find.text('Very High'), findsOneWidget);
    });

    testWidgets('touchpad area has correct styling', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const TouchpadScreen(),
        ),
      );

      // Find the container with touchpad styling
      final containers = tester.widgetList<Container>(find.byType(Container));
      final touchpadContainer = containers.firstWhere(
        (container) => container.decoration is BoxDecoration,
        orElse: () => Container(),
      );

      expect(touchpadContainer.decoration, isNotNull);
    });

    testWidgets('left click button is clickable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const TouchpadScreen(),
        ),
      );

      // Tap left click button
      final leftClickButton = find.text('Left Click');
      expect(leftClickButton, findsOneWidget);
      await tester.tap(leftClickButton);
      await tester.pump();

      // Button should respond (no crash)
      expect(leftClickButton, findsOneWidget);
    });

    testWidgets('right click button is clickable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const TouchpadScreen(),
        ),
      );

      // Tap right click button
      final rightClickButton = find.text('Right Click');
      expect(rightClickButton, findsOneWidget);
      await tester.tap(rightClickButton);
      await tester.pump();

      // Button should respond (no crash)
      expect(rightClickButton, findsOneWidget);
    });

    testWidgets('gesture detector covers touchpad area', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const TouchpadScreen(),
        ),
      );

      // Verify GestureDetector exists (we just check it's present, not exact count)
      expect(find.byType(GestureDetector), findsWidgets);
    });
  });
}
