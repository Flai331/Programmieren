import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../scan/wlan_receiver.dart';

/// Scannt den QR-Code, den der Scan-Trenner am PC unter „Per WLAN ans
/// Handy“ zeigt. Liefert die geprüfte Basis-Adresse zurück (oder `null`).
class WlanScanScreen extends StatefulWidget {
  const WlanScanScreen({super.key});

  @override
  State<WlanScanScreen> createState() => _WlanScanScreenState();
}

class _WlanScanScreenState extends State<WlanScanScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _done = false;
  String? _hint;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final code in capture.barcodes) {
      final raw = code.rawValue;
      if (raw == null) continue;
      final link = parseWlanLink(raw);
      if (link != null) {
        _done = true;
        Navigator.of(context).pop(link);
        return;
      }
      setState(() => _hint = 'Das ist kein DokuBox-Code vom PC.');
    }
  }

  Future<void> _enterManually() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Link eingeben'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            hintText: 'http://192.168.…/dokubox/…/',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (text == null || !mounted) return;
    final link = parseWlanLink(text);
    if (link == null) {
      setState(() => _hint = 'Link nicht erkannt – bitte genau abtippen.');
      return;
    }
    _done = true;
    Navigator.of(context).pop(link);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vom PC empfangen'),
        actions: [
          IconButton(
            tooltip: 'Link eintippen',
            icon: const Icon(Icons.keyboard),
            onPressed: _enterManually,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Kamera nicht verfügbar (${error.errorCode.name}).\n'
                    'Den Link kannst du oben rechts auch eintippen.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(16),
            child: Text(
              _hint ??
                  'Am PC im Scan-Trenner „📶 Per WLAN ans Handy…“ wählen und '
                      'den QR-Code scannen. Handy und PC müssen im selben WLAN '
                      'sein.',
              textAlign: TextAlign.center,
              style: _hint == null
                  ? null
                  : TextStyle(color: theme.colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
