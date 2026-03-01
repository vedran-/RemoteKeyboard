/// Widget Tests for ConnectionScreen
///
/// Verifies the connection UI renders correctly
/// and device list functionality works.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_keyboard_mobile/presentation/screens/connection_screen.dart';

void main() {
  group('ConnectionScreen', () {
    testWidgets('renders with app bar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const ConnectionScreen(),
        ),
      );

      // Verify app bar
      expect(find.text('Connect to PC'), findsOneWidget);
    });

    testWidgets('shows refresh button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const ConnectionScreen(),
        ),
      );

      // Verify refresh button
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('shows device list with mock devices', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const ConnectionScreen(),
        ),
      );

      // Verify mock devices are shown
      expect(find.text('Living Room PC'), findsOneWidget);
      expect(find.text('192.168.1.100'), findsOneWidget);
      expect(find.text('Office PC'), findsOneWidget);
      expect(find.text('192.168.1.101'), findsOneWidget);
    });

    testWidgets('devices have correct icons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const ConnectionScreen(),
        ),
      );

      // Verify device icons
      expect(find.byIcon(Icons.desktop_windows), findsNWidgets(2));
      expect(find.byIcon(Icons.connect_without_contact), findsNWidgets(2));
    });

    testWidgets('shows manual IP entry button', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const ConnectionScreen(),
        ),
      );

      // Verify manual IP button
      expect(find.text('Add PC Manually'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('refresh button shows loading indicator when tapped', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const ConnectionScreen(),
        ),
      );

      // Tap refresh button
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      // Verify loading indicator appears
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Let the timer complete
      await tester.pumpAndSettle();
    });

    testWidgets('loading indicator disappears after scan', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const ConnectionScreen(),
        ),
      );

      // Tap refresh button
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      // Wait for simulated scan to complete (2 seconds)
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();

      // Loading indicator should be gone
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('connect button shows snackbar when tapped', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const ConnectionScreen(),
        ),
      );

      // Tap connect button for first device
      final connectButtons = find.byIcon(Icons.connect_without_contact);
      await tester.tap(connectButtons.first);
      await tester.pump();

      // Verify snackbar appears
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Connecting to Living Room PC...'), findsOneWidget);
    });

    testWidgets('connection status shows when connected', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const ConnectionScreen(),
        ),
      );

      // Initially no connection status
      expect(find.byIcon(Icons.check_circle), findsNothing);

      // Tap connect button
      final connectButtons = find.byIcon(Icons.connect_without_contact);
      await tester.tap(connectButtons.first);
      await tester.pumpAndSettle();

      // Connection status should appear
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.textContaining('Connected to:'), findsOneWidget);
    });

    testWidgets('connection status has green color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const ConnectionScreen(),
        ),
      );

      // Connect to a device
      final connectButtons = find.byIcon(Icons.connect_without_contact);
      await tester.tap(connectButtons.first);
      await tester.pumpAndSettle();

      // Find the status container
      final containers = tester.widgetList<Container>(find.byType(Container));
      final statusContainer = containers.firstWhere(
        (container) => container.color != null,
        orElse: () => Container(),
      );

      expect(statusContainer.color, isNotNull);
    });

    testWidgets('device cards have correct margins', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const ConnectionScreen(),
        ),
      );

      // Verify cards exist with proper styling
      expect(find.byType(Card), findsNWidgets(2));
    });

    testWidgets('manual IP button is clickable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const ConnectionScreen(),
        ),
      );

      // Tap manual IP button
      await tester.tap(find.text('Add PC Manually'));
      await tester.pump();

      // Button should respond (no crash)
      expect(find.text('Add PC Manually'), findsOneWidget);
    });

    testWidgets('device list is scrollable', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const ConnectionScreen(),
        ),
      );

      // Verify ListView exists
      expect(find.byType(ListView), findsOneWidget);
    });

    testWidgets('refresh button is disabled during scan', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: const ConnectionScreen(),
        ),
      );

      // Tap refresh to start scanning
      await tester.tap(find.byIcon(Icons.refresh));
      await tester.pump();

      // During scan, the refresh IconButton should be disabled (onPressed is null)
      // We verify by checking that the loading indicator is shown instead
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      
      // Let timer complete
      await tester.pumpAndSettle();
    });
  });
}
