import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/book_lookup.dart';

/// Scannt den EAN-13-Barcode auf der Buchrückseite und gibt die ISBN zurück.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _fertig = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _erkannt(BarcodeCapture capture) {
    if (_fertig) return;
    for (final code in capture.barcodes) {
      final raw = code.rawValue;
      // Nur Buch-Barcodes (978/979) mit gültiger Prüfziffer übernehmen.
      if (raw != null &&
          (raw.startsWith('978') || raw.startsWith('979')) &&
          isValidIsbn(raw)) {
        _fertig = true;
        Navigator.pop(context, raw);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ISBN scannen'),
        actions: [
          // Taschenlampe für Barcodes im Dunkeln; ohne Blitz ausgeblendet.
          ValueListenableBuilder(
            valueListenable: _controller,
            builder: (context, state, _) {
              final torch = state.torchState;
              if (torch == TorchState.unavailable) {
                return const SizedBox.shrink();
              }
              final an = torch == TorchState.on;
              return IconButton(
                tooltip: an ? 'Taschenlampe aus' : 'Taschenlampe an',
                icon: Icon(an ? Icons.flashlight_on : Icons.flashlight_off),
                onPressed: _controller.toggleTorch,
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _erkannt,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Kamera nicht verfügbar (${error.errorCode.name}). Du kannst die ISBN auch eintippen.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Barcode auf der Buchrückseite ins Bild halten',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
