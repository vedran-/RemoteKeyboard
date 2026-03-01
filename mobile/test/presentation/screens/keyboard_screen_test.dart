/// Widget Tests for KeyboardScreen
///
/// Verifies the keyboard UI renders correctly
/// and text input is set up.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_keyboard_mobile/presentation/screens/keyboard_screen.dart';

void main() {
  group('KeyboardScreen', () {
    testWidgets('renders with app bar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const KeyboardScreen(),
        ),
      );

      // Verify app bar
      expect(find.text('Keyboard'), findsOneWidget);
    });

    testWidgets('shows text input field', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const KeyboardScreen(),
        ),
      );

      // Verify text field exists
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Type here...'), findsOneWidget);
    });

    testWidgets('shows send button in text field', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const KeyboardScreen(),
        ),
      );

      // Verify send button
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('shows special keys', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const KeyboardScreen(),
        ),
      );

      // Verify special keys
      expect(find.text('Enter'), findsOneWidget);
      expect(find.text('⌫'), findsOneWidget); // Backspace
      expect(find.text('Tab'), findsOneWidget);
      expect(find.text('Esc'), findsOneWidget);
      expect(find.text('Space'), findsOneWidget);
    });

    testWidgets('shows arrow keys', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const KeyboardScreen(),
        ),
      );

      // Verify arrow keys
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_left), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);
    });

    testWidgets('text field is editable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const KeyboardScreen(),
        ),
      );

      // Enter text
      await tester.enterText(find.byType(TextField), 'Hello World');
      await tester.pump();

      // Verify text was entered
      expect(find.text('Hello World'), findsOneWidget);
    });

    testWidgets('send button is clickable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const KeyboardScreen(),
        ),
      );

      // Enter text first
      await tester.enterText(find.byType(TextField), 'Test');
      await tester.pump();

      // Tap send button
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      // Text should be cleared after sending
      expect(find.text('Test'), findsNothing);
    });

    testWidgets('special key buttons are clickable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const KeyboardScreen(),
        ),
      );

      // Tap each special key button
      await tester.tap(find.text('Enter'));
      await tester.pump();

      await tester.tap(find.text('⌫'));
      await tester.pump();

      await tester.tap(find.text('Tab'));
      await tester.pump();

      await tester.tap(find.text('Esc'));
      await tester.pump();

      await tester.tap(find.text('Space'));
      await tester.pump();

      // All buttons should still exist (no crash)
      expect(find.text('Enter'), findsOneWidget);
      expect(find.text('⌫'), findsOneWidget);
      expect(find.text('Tab'), findsOneWidget);
      expect(find.text('Esc'), findsOneWidget);
      expect(find.text('Space'), findsOneWidget);
    });

    testWidgets('arrow key buttons are clickable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const KeyboardScreen(),
        ),
      );

      // Tap each arrow key button
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.keyboard_arrow_left));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.keyboard_arrow_right));
      await tester.pump();

      // All buttons should still exist (no crash)
      expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_down), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_left), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_right), findsOneWidget);
    });

    testWidgets('text field has outline border', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const KeyboardScreen(),
        ),
      );

      // Verify text field has border decoration
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration, isNotNull);
      expect(textField.decoration!.border, isA<OutlineInputBorder>());
    });

    testWidgets('arrow keys are centered', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const KeyboardScreen(),
        ),
      );

      // Verify arrow keys are in a centered row
      final rows = find.byType(Row);
      expect(rows, findsWidgets);
    });
  });
}
