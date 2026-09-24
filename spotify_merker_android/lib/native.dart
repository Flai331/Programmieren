import 'dart:convert';

import 'package:flutter/services.dart';

import 'logic.dart';

class Native {
  static const platform = MethodChannel('spotify_merker/native');

  static Future<bool> isPermissionGranted() async {
    try {
      final result = await platform.invokeMethod<bool>('isPermissionGranted');
      return result ?? false;
    } catch (e) {
      // ignore: avoid_print
      print('Error checking permission: $e');
      return false;
    }
  }

  static Future<void> openPermissionSettings() async {
    try {
      await platform.invokeMethod('openPermissionSettings');
    } catch (e) {
      // ignore: avoid_print
      print('Error opening permission settings: $e');
    }
  }

  static Future<void> openAppDetails() async {
    try {
      await platform.invokeMethod('openAppDetails');
    } catch (_) {}
  }

  static Future<List<RawEvent>> drainEvents() async {
    try {
      final result = await platform.invokeMethod<List>('drainEvents');
      if (result == null) return [];

      return result
          .cast<String>()
          .map((eventStr) {
            final json = _parseJson(eventStr);
            return json != null ? RawEvent.fromJson(json) : null;
          })
          .whereType<RawEvent>()
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error draining events: $e');
      return [];
    }
  }

  static Future<Current?> getCurrent() async {
    try {
      final result = await platform.invokeMethod<Map>('getCurrent');
      if (result == null) return null;
      return Current.fromJson(Map<String, dynamic>.from(result));
    } catch (e) {
      // ignore: avoid_print
      print('Error getting current: $e');
      return null;
    }
  }

  static Future<bool> isSpotifyInstalled() async {
    try {
      final result = await platform.invokeMethod<bool>('isSpotifyInstalled');
      return result ?? false;
    } catch (e) {
      // ignore: avoid_print
      print('Error checking Spotify: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>> resume({
    required String title,
    required String artist,
    required String album,
    required String? spotifyUri,
    String? mediaId,
    required int positionMs,
  }) async {
    try {
      final result = await platform.invokeMethod<Map>('resume', {
        'title': title,
        'artist': artist,
        'album': album,
        'spotifyUri': spotifyUri,
        'mediaId': mediaId,
        'positionMs': positionMs,
      });
      return result != null
          ? Map<String, dynamic>.from(result)
          : {'started': false};
    } catch (e) {
      // ignore: avoid_print
      print('Error calling resume: $e');
      return {'started': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getDiagnostics() async {
    try {
      final result = await platform.invokeMethod<Map>('getDiagnostics');
      return result != null ? Map<String, dynamic>.from(result) : {};
    } catch (e) {
      // ignore: avoid_print
      print('Error getting diagnostics: $e');
      return {'error': e.toString()};
    }
  }

  static Map<String, dynamic>? _parseJson(String jsonStr) {
    try {
      final decoded = jsonDecode(jsonStr);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
