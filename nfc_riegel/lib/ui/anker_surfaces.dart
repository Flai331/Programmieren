import 'package:flutter/material.dart';

import '../theme.dart';

/// Abschnittsüberschrift: klein, Versalien, weites Tracking. Ersetzt die
/// fetten 18-px-Zeilen, die den Prototyp nach Einstellungsliste aussehen
/// ließen.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RiegelSpacing.s2 + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: RiegelColors.fg3,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Die Standardfläche der App: Verlauf von elev1 nach dunkler, Hairline-Rahmen,
/// Lichtkante oben. Nicht flach, aber auch kein Material-Schatten — auf
/// nachtblauen Flächen wirkt Schatten wie Schmutz.
BoxDecoration ankerSurface({double radius = RiegelRadii.lg, Color? border}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: border ?? RiegelColors.borderDefault),
    gradient: const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF151C27), Color(0xFF111721)],
    ),
    boxShadow: const [
      BoxShadow(color: Color(0x66000000), blurRadius: 26, offset: Offset(0, 10)),
    ],
  );
}

/// Fläche in Bernstein-Tönung — für die Zeile des laufenden Profils.
BoxDecoration ankerSurfaceLocked({double radius = RiegelRadii.lg}) {
  return BoxDecoration(
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: RiegelColors.locked.withValues(alpha: 0.3)),
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        RiegelColors.locked.withValues(alpha: 0.1),
        RiegelColors.locked.withValues(alpha: 0.04),
      ],
    ),
  );
}

/// Statuspille im AppBar-Rand: „AKTIV" mit glühendem Punkt.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.locked});

  final String label;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final c = locked ? RiegelColors.locked : RiegelColors.accent;
    final fg = locked ? RiegelColors.lockedBright : RiegelColors.accentBright;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RiegelRadii.pill),
        border: Border.all(color: c.withValues(alpha: 0.32)),
        color: c.withValues(alpha: 0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c,
              boxShadow: [BoxShadow(color: c, blurRadius: 8)],
            ),
          ),
          const SizedBox(width: RiegelSpacing.s2 - 1),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tagesband: 24 Stunden als Schiene, Sperrfenster in Bernstein, „jetzt" als
/// helle Nadel. Sagt auf einen Blick, was eine Liste von Uhrzeiten nicht sagt.
class DayBand extends StatelessWidget {
  const DayBand({super.key, required this.windows, required this.now});

  /// Sperrfenster als Anteile des Tages: (Start 0..1, Ende 0..1, läuft gerade).
  final List<({double start, double end, bool active})> windows;

  /// Aktuelle Uhrzeit als Anteil des Tages.
  final double now;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(RiegelRadii.md),
          child: Container(
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF101620),
              border: Border.all(color: RiegelColors.borderSubtle),
              borderRadius: BorderRadius.circular(RiegelRadii.md),
            ),
            child: LayoutBuilder(
              builder: (context, c) => Stack(
                children: [
                  for (final w in windows)
                    Positioned(
                      left: w.start * c.maxWidth,
                      width: (w.end - w.start).clamp(0.004, 1) * c.maxWidth,
                      top: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: w.active
                                ? const [RiegelColors.locked, Color(0xFFE8735B)]
                                : [
                                    RiegelColors.locked.withValues(alpha: 0.55),
                                    const Color(0xFFE8735B).withValues(alpha: 0.42),
                                  ],
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: now * c.maxWidth,
                    top: 0,
                    bottom: 0,
                    width: 2,
                    child: const ColoredBox(color: RiegelColors.fg1),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: RiegelSpacing.s1),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _Tick('00'),
            _Tick('06'),
            _Tick('12'),
            _Tick('18'),
            _Tick('24'),
          ],
        ),
      ],
    );
  }
}

class _Tick extends StatelessWidget {
  const _Tick(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: const TextStyle(fontFamily: kMonoFamily, fontSize: 10, color: RiegelColors.fg4),
  );
}

/// Wochenbalken der Screenzeit. Der Tag mit der längsten Sperre steht in
/// Bernstein, heute bleibt eisblau, kommende Tage sind nur angedeutet.
class WeekBars extends StatelessWidget {
  const WeekBars({super.key, required this.values, required this.labels, this.highlight});

  /// 0..1 je Tag.
  final List<double> values;
  final List<String> labels;

  /// Index des Bernstein-Tages, oder null.
  final int? highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 56,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++) ...[
                if (i > 0) const SizedBox(width: 7),
                Expanded(
                  child: FractionallySizedBox(
                    heightFactor: values[i].clamp(0.04, 1),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                          bottom: Radius.circular(2),
                        ),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: i == highlight
                              ? const [RiegelColors.locked, Color(0xFFE8735B)]
                              : values[i] <= 0.05
                              ? [
                                  Colors.white.withValues(alpha: 0.12),
                                  Colors.white.withValues(alpha: 0.12),
                                ]
                              : const [RiegelColors.accent, RiegelColors.accentDim],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: RiegelSpacing.s2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [for (final l in labels) _Tick(l)],
        ),
      ],
    );
  }
}

/// Eine App-Zeile der Screenzeit: Name, Balken, Zeit in Mono.
class UsageRow extends StatelessWidget {
  const UsageRow({super.key, required this.app, required this.fraction, required this.time});

  final String app;
  final double fraction;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RiegelSpacing.s1 + 1),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Text(
              app,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: RiegelColors.fg2),
            ),
          ),
          const SizedBox(width: RiegelSpacing.s3),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Container(
                height: 8,
                color: const Color(0xFF101620),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: fraction.clamp(0.01, 1),
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [RiegelColors.accent, RiegelColors.accentDim],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: RiegelSpacing.s3),
          SizedBox(
            width: 52,
            child: Text(
              time,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: kMonoFamily,
                fontSize: 12,
                color: RiegelColors.fg1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Der pulsierende NFC-Ring — Chips anlernen, „Chip bereit", Scan-Dialog.
class NfcPulse extends StatefulWidget {
  const NfcPulse({super.key, this.size = 56, this.color = RiegelColors.accent});

  final double size;
  final Color color;

  @override
  State<NfcPulse> createState() => _NfcPulseState();
}

class _NfcPulseState extends State<NfcPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = Curves.easeOut.transform(_c.value);
              return Transform.scale(
                scale: 0.85 + t * 0.5,
                child: Opacity(
                  opacity: (1 - t / 0.7).clamp(0.0, 1.0) * 0.55,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: widget.color, width: 2),
                    ),
                  ),
                ),
              );
            },
          ),
          Icon(Icons.wifi_tethering_rounded, size: widget.size * 0.5, color: widget.color),
        ],
      ),
    );
  }
}
