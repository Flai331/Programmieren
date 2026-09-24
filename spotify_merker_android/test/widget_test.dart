import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:spotify_merker/main.dart';

void main() {
  testWidgets('App shows setup screen when permission not granted', (
    WidgetTester tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('spotify_merker/native'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'isPermissionGranted') {
              return false;
            }
            return null;
          },
        );

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Benachrichtigungszugriff erforderlich'), findsWidgets);
    expect(find.text('Benachrichtigungszugriff erlauben'), findsOneWidget);
  });

  testWidgets('App shows main UI when permission granted', (
    WidgetTester tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('spotify_merker/native'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'isPermissionGranted') {
              return true;
            }
            if (methodCall.method == 'drainEvents') {
              return [];
            }
            if (methodCall.method == 'getCurrent') {
              return null;
            }
            return null;
          },
        );

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Spotify-Merker'), findsWidgets);
    expect(find.byIcon(Icons.play_circle), findsOneWidget);
    expect(find.byIcon(Icons.history), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('Resume banner shows when candidate exists', (
    WidgetTester tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('spotify_merker/native'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'isPermissionGranted') {
              return true;
            }
            if (methodCall.method == 'drainEvents') {
              return [];
            }
            if (methodCall.method == 'getCurrent') {
              return {
                'title': 'Current Song',
                'artist': 'Current Artist',
                'album': 'Current Album',
                'durationMs': 180000,
                'positionMs': 60000,
                'state': 'PLAYING',
                'mediaId': '',
                'mediaUri': '',
                'artUri': '',
              };
            }
            return null;
          },
        );

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // App should show and have the current playback displayed
    expect(find.text('Jetzt läuft:'), findsWidgets);
  });
}
