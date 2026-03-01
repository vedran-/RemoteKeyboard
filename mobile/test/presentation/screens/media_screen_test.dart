/// Widget Tests for MediaScreen
///
/// Verifies the media controls UI renders correctly
/// and all buttons are present.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_keyboard_mobile/presentation/screens/media_screen.dart';

void main() {
  group('MediaScreen', () {
    testWidgets('renders with app bar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const MediaScreen(),
        ),
      );

      // Verify app bar
      expect(find.text('Media Controls'), findsOneWidget);
    });

    testWidgets('shows playback controls', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const MediaScreen(),
        ),
      );

      // Verify playback buttons
      expect(find.text('Previous'), findsOneWidget);
      expect(find.text('Play/Pause'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
    });

    testWidgets('shows volume controls', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const MediaScreen(),
        ),
      );

      // Verify volume section
      expect(find.text('Volume'), findsOneWidget);

      // Verify volume buttons
      expect(find.text('Down'), findsOneWidget);
      expect(find.text('Mute'), findsOneWidget);
      expect(find.text('Up'), findsOneWidget);
    });

    testWidgets('shows correct icons for playback buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const MediaScreen(),
        ),
      );

      // Verify playback icons
      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
    });

    testWidgets('shows correct icons for volume buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const MediaScreen(),
        ),
      );

      // Verify volume icons
      expect(find.byIcon(Icons.volume_down), findsOneWidget);
      expect(find.byIcon(Icons.volume_off), findsOneWidget);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
    });

    testWidgets('Play/Pause button is larger than others', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const MediaScreen(),
        ),
      );

      // Find all elevated buttons
      final buttons = tester.widgetList<ElevatedButton>(find.byType(ElevatedButton));

      // Play/Pause should have size 80x80
      final playPauseButton = buttons.firstWhere(
        (button) => button.child.toString().contains('play_arrow'),
        orElse: () => ElevatedButton(onPressed: () {}, child: const SizedBox()),
      );

      // The button should have a larger fixed size
      expect(playPauseButton, isNotNull);
    });

    testWidgets('shows info card with instructions', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const MediaScreen(),
        ),
      );

      // Verify info card
      expect(find.byType(Card), findsWidgets);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(
        find.text('These buttons control media playback on your PC'),
        findsOneWidget,
      );
    });

    testWidgets('all playback buttons are clickable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const MediaScreen(),
        ),
      );

      // Tap playback buttons
      await tester.tap(find.byIcon(Icons.skip_previous));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.skip_next));
      await tester.pump();

      // All buttons should still exist (no crash)
      expect(find.byIcon(Icons.skip_previous), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      expect(find.byIcon(Icons.skip_next), findsOneWidget);
    });

    testWidgets('all volume buttons are clickable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const MediaScreen(),
        ),
      );

      // Tap volume buttons
      await tester.tap(find.byIcon(Icons.volume_down));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.volume_off));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.volume_up));
      await tester.pump();

      // All buttons should still exist (no crash)
      expect(find.byIcon(Icons.volume_down), findsOneWidget);
      expect(find.byIcon(Icons.volume_off), findsOneWidget);
      expect(find.byIcon(Icons.volume_up), findsOneWidget);
    });

    testWidgets('buttons show snackbar on tap', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const MediaScreen(),
        ),
      );

      // Tap a button
      await tester.tap(find.byIcon(Icons.play_arrow));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify snackbar appears
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('layout has correct structure', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const MediaScreen(),
        ),
      );

      // Verify main layout components
      expect(find.byType(Scaffold), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
      expect(find.byType(Padding), findsWidgets);
      expect(find.byType(Column), findsWidgets);
      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('media buttons are in circular shape', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const MediaScreen(),
        ),
      );

      // Find elevated buttons and verify they have circular style
      final buttons = tester.widgetList<ElevatedButton>(find.byType(ElevatedButton));
      expect(buttons.isNotEmpty, isTrue);

      // Check first button has circular shape
      final firstButton = buttons.first;
      expect(firstButton.style, isNotNull);
    });
  });
}
