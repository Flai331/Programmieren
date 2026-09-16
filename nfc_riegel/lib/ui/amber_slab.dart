import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Die Bernsteinkachel — das größte Element der App.
///
/// Gesperrt: warme Fläche, die den halben Schirm nimmt, Countdown in Mono.
/// Offen: eine ruhige dunkle Fläche derselben Form, deutlich niedriger.
/// Der Wechsel ist animiert, nicht geschnitten: die Höhe fährt, die Farbe
/// mischt durch. Das ist der Zustandswechsel, den die App zu erzählen hat.
class AmberSlab extends StatelessWidget {
  const AmberSlab({
    super.key,
    required this.locked,
    required this.title,
    required this.subtitle,
    this.countdown,
    this.progress,
    this.footnote,
    this.trailing,
  });

  final bool locked;

  /// „Anker gesetzt" / „Anker gelichtet".
  final String title;
  final String subtitle;

  /// Restzeit, bereits formatiert (hh:mm:ss). Null bei Chipsperren ohne Ende.
  final String? countdown;

  /// 0..1 — Anteil der abgelaufenen Sperre. Null lässt den Balken weg.
  final double? progress;
  final String? footnote;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final ink = locked ? RiegelColors.fgOnLocked : RiegelColors.fg1;
    final inkSoft = locked ? RiegelColors.fgOnLocked.withValues(alpha: 0.72) : RiegelColors.fg2;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      // Die Polsterung sitzt bewusst NICHT hier, sondern innen um den Inhalt:
      // der Stack fuellt sonst nur das gepolsterte Innere, und die Lichtkante
      // wird als sichtbares Kaestchen mitten in der Flaeche gezeichnet statt
      // an ihrer Aussenkante.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RiegelRadii.xxl),
        gradient: locked
            ? const RadialGradient(
                center: Alignment(-0.6, -1),
                radius: 1.3,
                colors: [
                  RiegelColors.lockedBright,
                  RiegelColors.locked,
                  Color(0xFFE8735B),
                ],
                stops: [0, 0.46, 1],
              )
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [RiegelColors.bgElev1, RiegelColors.bgCanvas],
              ),
        boxShadow: locked
            ? [
                // Getönter Abwurf: die Kachel liegt auf der Fläche, sie ist
                // nicht hineingemalt.
                const BoxShadow(
                  color: Color(0x4DE8735B),
                  blurRadius: 56,
                  offset: Offset(0, 26),
                ),
              ]
            : const [
                BoxShadow(color: Color(0x80000000), blurRadius: 44, offset: Offset(0, 18)),
              ],
      ),
      child: Stack(
        children: [
          // Lichtkante: die eine Linie, die eine Fläche zu einem Körper macht.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _InnerEdgePainter(
                  radius: RiegelRadii.xxl,
                  top: locked
                      ? Colors.white.withValues(alpha: 0.6)
                      : Colors.white.withValues(alpha: 0.06),
                  bottom: locked ? Colors.black.withValues(alpha: 0.18) : Colors.transparent,
                ),
              ),
            ),
          ),
          if (locked)
            Positioned.fill(
              child: const IgnorePointer(child: RepaintBoundary(child: GrainOverlay())),
            ),
          Padding(
            padding: const EdgeInsets.all(RiegelSpacing.s5 + 2),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(RiegelRadii.md + 2),
                      color: locked
                          ? RiegelColors.fgOnLocked.withValues(alpha: 0.15)
                          : RiegelColors.accentTint,
                    ),
                    child: Icon(
                      locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                      size: 18,
                      color: locked ? RiegelColors.fgOnLocked : RiegelColors.accent,
                    ),
                  ),
                  const SizedBox(width: RiegelSpacing.s3 - 1),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: ink,
                          ),
                        ),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              if (countdown != null) ...[
                const SizedBox(height: RiegelSpacing.s5),
                Text(
                  countdown!,
                  style: TextStyle(
                    fontFamily: kMonoFamily,
                    fontSize: 52,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -2,
                    height: 1,
                    color: ink,
                  ),
                ),
              ],
              if (progress != null) ...[
                const SizedBox(height: RiegelSpacing.s3 + 2),
                // Verlängert man die Sperre, springt der Balken nicht.
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: progress!.clamp(0.0, 1.0)),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => LinearProgressIndicator(
                      value: value,
                      minHeight: 6,
                      backgroundColor: ink.withValues(alpha: 0.2),
                      valueColor: AlwaysStoppedAnimation(ink),
                    ),
                  ),
                ),
              ],
              if (footnote != null) ...[
                const SizedBox(height: RiegelSpacing.s2 + 1),
                Text(
                  footnote!,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: inkSoft),
                ),
              ],
            ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Feines Rauschen auf der Bernsteinfläche — nimmt dem Verlauf das Digitale.
/// Einmal gezeichnet und gecacht; deshalb ein fester Seed.
class GrainOverlay extends StatelessWidget {
  const GrainOverlay({super.key, this.opacity = 0.055, this.density = 1400});

  final double opacity;
  final int density;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _GrainPainter(opacity: opacity, density: density));
}

class _GrainPainter extends CustomPainter {
  _GrainPainter({required this.opacity, required this.density});

  final double opacity;
  final int density;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(7);
    final dark = Paint()..color = Colors.black.withValues(alpha: opacity);
    final light = Paint()..color = Colors.white.withValues(alpha: opacity);
    for (var i = 0; i < density; i++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      canvas.drawRect(Rect.fromLTWH(x, y, 1.2, 1.2), rnd.nextBool() ? dark : light);
    }
  }

  @override
  bool shouldRepaint(_GrainPainter old) => old.opacity != opacity;
}

/// Innenkante: helle Linie oben, dunkle unten. 1,5 px, nie mehr.
class _InnerEdgePainter extends CustomPainter {
  const _InnerEdgePainter({required this.radius, required this.top, required this.bottom});

  final double radius;
  final Color top;
  final Color bottom;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.75, 0.75, size.width - 1.5, size.height - 1.5),
      Radius.circular(radius),
    );
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.5));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = top
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.restore();
    if (bottom.a == 0) return;
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, size.height * 0.5, size.width, size.height * 0.5));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = bottom
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InnerEdgePainter old) => old.top != top || old.bottom != bottom;
}
