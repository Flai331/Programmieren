import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Das Zeichen „Siegelring": ein offener Bogen in Eisblau, den ein
/// Bernstein-Bolzen schließt. Der Bogen ist zugleich NFC-Welle und Ring.
///
/// Gezeichnet, nicht als Asset geladen — so färbt es sich mit dem Zustand
/// (Eisblau offen, Bernstein gesperrt) und bleibt in jeder Größe scharf.
class AnkerMark extends StatelessWidget {
  const AnkerMark({
    super.key,
    this.size = 24,
    this.arcColor = RiegelColors.accent,
    this.boltColor = RiegelColors.locked,
  });

  final double size;
  final Color arcColor;
  final Color boltColor;

  /// Monochrome Variante — für Sperrschirm-Kopf und Benachrichtigungen.
  const AnkerMark.mono({super.key, this.size = 24, Color color = RiegelColors.fg1})
    : arcColor = color,
      boltColor = color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _MarkPainter(arcColor, boltColor)),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter(this.arc, this.bolt);

  final Color arc;
  final Color bolt;

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 96;
    final center = Offset(48 * k, 48 * k);

    // Offener Bogen: 300° im Uhrzeigersinn, Lücke rechts unten, wo der
    // Bolzen ansetzt.
    final stroke = 8.5 * k;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 28 * k),
      -math.pi / 2,
      math.pi * 2 * 0.82,
      false,
      Paint()
        ..color = arc
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );

    // Der Bolzen schiebt von rechts in den Ring: das „zu".
    final boltRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(56 * k, 41 * k, 30 * k, 13 * k),
      Radius.circular(6.5 * k),
    );
    canvas.drawRRect(boltRect, Paint()..color = bolt);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.arc != arc || old.bolt != bolt;
}

/// Wortmarke: Versalien, weites Tracking. Nie kursiv, nie mit Punkt.
class AnkerWordmark extends StatelessWidget {
  const AnkerWordmark({super.key, this.fontSize = 17, this.color = RiegelColors.fg1});

  final double fontSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      'ANKER',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        letterSpacing: fontSize * 0.2,
        color: color,
      ),
    );
  }
}

/// Zeichen + Wortmarke. Steht im AppBar-Titel des Hauptschirms.
class AnkerLockup extends StatelessWidget {
  const AnkerLockup({super.key, this.locked = false});

  /// Im gesperrten Zustand steht der Bolzen in Bernstein — das Zeichen
  /// erzählt denselben Zustand wie die Kachel darunter.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnkerMark(
          size: 22,
          boltColor: locked ? RiegelColors.locked : RiegelColors.accentDim,
        ),
        const SizedBox(width: RiegelSpacing.s2 + 1),
        const AnkerWordmark(fontSize: 15),
      ],
    );
  }
}
