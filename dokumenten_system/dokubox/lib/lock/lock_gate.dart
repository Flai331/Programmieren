import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Einstellung: App-Sperre aktiv?
class AppLockSettings {
  static const _key = 'app_lock_enabled';

  static Future<bool> isEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_key) ?? false;

  static Future<void> setEnabled(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_key, value);
}

/// Koordiniert die automatische Sperre mit absichtlichen Ausflügen in andere
/// Apps/Activities (Scanner, Datei-Auswahl, Teilen). Ohne diese Unterdrückung
/// würde die Sperre beim Öffnen des Scanners zuschnappen und den gerade
/// laufenden Scan-Vorgang verwerfen.
class LockController {
  LockController._();

  /// Wird gesetzt, solange wir bewusst eine andere Activity gestartet haben.
  static bool suppressAutoLock = false;
}

/// Legt bei aktiver Sperre ein Vollbild-Overlay ÜBER die gesamte App (inkl.
/// gerade geöffneter Bildschirme), statt den Inhalt zu ersetzen — so geht kein
/// laufender Vorgang verloren. Entsperrt per Biometrie/Geräte-PIN
/// (Systemdialog, kein eigener PIN-Speicher).
class LockGate extends StatefulWidget {
  final Widget child;

  const LockGate({super.key, required this.child});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  final _auth = LocalAuthentication();
  bool _locked = false;
  bool _authInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lockIfEnabled();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Beim Wegwechseln sperren, damit die Dokumente in der App-Übersicht
      // des Systems nicht offen liegen — aber NICHT, wenn wir selbst gerade
      // eine andere Activity gestartet haben (Scanner/Datei-Auswahl/Teilen),
      // sonst ginge der laufende Vorgang verloren.
      if (!_authInProgress && !LockController.suppressAutoLock) {
        _lockIfEnabled();
      }
    } else if (state == AppLifecycleState.resumed) {
      // Der einmalige Ausflug ist vorbei; ab jetzt wieder normal sperren.
      LockController.suppressAutoLock = false;
    }
  }

  Future<void> _lockIfEnabled() async {
    if (await AppLockSettings.isEnabled()) {
      if (mounted) setState(() => _locked = true);
    }
  }

  Future<void> _unlock() async {
    if (_authInProgress) return;
    _authInProgress = true;
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'DokuBox entsperren',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (ok && mounted) setState(() => _locked = false);
    } finally {
      _authInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        // Vollbild-Overlay über allem, wenn gesperrt. Der Inhalt darunter
        // bleibt erhalten (kein Verlust laufender Vorgänge).
        if (_locked)
          Positioned.fill(
            child: Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 64),
                    const SizedBox(height: 16),
                    const Text('DokuBox ist gesperrt'),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _unlock,
                      icon: const Icon(Icons.fingerprint),
                      label: const Text('Entsperren'),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
