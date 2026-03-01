/// Widget Tests for HomeScreen
///
/// Verifies the main navigation screen renders correctly
/// and tab switching works.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_keyboard_mobile/presentation/screens/home_screen.dart';

void main() {
  group('HomeScreen', () {
    testWidgets('renders with bottom navigation bar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const HomeScreen(),
        ),
      );

      // Verify bottom navigation bar exists
      expect(find.byType(NavigationBar), findsOneWidget);

      // Verify all navigation destinations exist
      expect(find.text('Connect'), findsOneWidget);
      expect(find.text('Touchpad'), findsOneWidget);
      expect(find.text('Keyboard'), findsOneWidget);
      expect(find.text('Media'), findsOneWidget);
    });

    testWidgets('shows ConnectionScreen by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const HomeScreen(),
        ),
      );

      // Connection screen should be visible initially
      expect(find.text('Connect to PC'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('switches to TouchpadScreen when tapped', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const HomeScreen(),
        ),
      );

      // Tap on Touchpad navigation destination
      final touchpadDestination = find.text('Touchpad').first;
      await tester.tap(touchpadDestination);
      await tester.pumpAndSettle();

      // Verify TouchpadScreen is now visible (check for unique content)
      expect(find.text('Touch and drag to move cursor'), findsOneWidget);
    });

    testWidgets('switches to KeyboardScreen when tapped', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const HomeScreen(),
        ),
      );

      // Tap on Keyboard navigation destination
      final keyboardDestination = find.text('Keyboard').first;
      await tester.tap(keyboardDestination);
      await tester.pumpAndSettle();

      // Verify KeyboardScreen is now visible (check for unique content)
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('switches to MediaScreen when tapped', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const HomeScreen(),
        ),
      );

      // Tap on Media navigation item
      final mediaItem = find.text('Media');
      await tester.tap(mediaItem);
      await tester.pumpAndSettle();

      // Verify MediaScreen is now visible
      expect(find.text('Media Controls'), findsOneWidget);
      expect(find.text('Previous'), findsOneWidget);
      expect(find.text('Play/Pause'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('switches back to Connect screen when tapped', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const HomeScreen(),
        ),
      );

      // Switch to Touchpad first
      await tester.tap(find.text('Touchpad'));
      await tester.pumpAndSettle();

      // Switch back to Connect
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();

      // Verify ConnectionScreen is visible again
      expect(find.text('Connect to PC'), findsOneWidget);
    });

    testWidgets('has correct icons for navigation items', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const HomeScreen(),
        ),
      );

      // Verify icons exist
      expect(find.byIcon(Icons.wifi), findsOneWidget);
      expect(find.byIcon(Icons.touch_app), findsOneWidget);
      expect(find.byIcon(Icons.keyboard), findsOneWidget);
      expect(find.byIcon(Icons.music_note), findsOneWidget);
    });

    testWidgets('updates navigation selection indicator', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const HomeScreen(),
        ),
      );

      // Initially Connect should be selected (index 0)
      final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(navBar.selectedIndex, 0);

      // Tap Touchpad
      await tester.tap(find.text('Touchpad'));
      await tester.pumpAndSettle();

      // Touchpad should now be selected (index 1)
      final updatedNavBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(updatedNavBar.selectedIndex, 1);
    });
  });
}
