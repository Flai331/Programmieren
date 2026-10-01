import 'package:flutter/material.dart';

// Strichfigur in einem 100×100-Raster (Seitenansicht, Blick nach rechts).
// Jede Übung hat eine Start- und Endpose, dazwischen wird hin und her animiert.

Offset o(double x, double y) => Offset(x, y);

Map<String, Offset> pose({
  required Offset head,
  required Offset neck,
  required Offset hip,
  required Offset elbow,
  required Offset hand,
  required Offset knee,
  required Offset ankle,
  required Offset toe,
  Offset? elbowB,
  Offset? handB,
  Offset? kneeB,
  Offset? ankleB,
  Offset? toeB,
  Offset? bar,
}) {
  const d = Offset(-1.5, 0); // hintere Körperseite leicht versetzt
  return {
    'head': head,
    'neck': neck,
    'hip': hip,
    'elbowA': elbow,
    'handA': hand,
    'kneeA': knee,
    'ankleA': ankle,
    'toeA': toe,
    'elbowB': elbowB ?? elbow + d,
    'handB': handB ?? hand + d,
    'kneeB': kneeB ?? knee + d,
    'ankleB': ankleB ?? ankle + d,
    'toeB': toeB ?? toe + d,
    if (bar != null) 'bar': bar,
  };
}

class Prop {
  final Rect? rect;
  final Offset? p1, p2;
  Prop.rect(this.rect)
      : p1 = null,
        p2 = null;
  Prop.line(this.p1, this.p2) : rect = null;
}

class ExerciseAnim {
  final Map<String, Offset> start, end;
  final List<Prop> props;
  final bool plate, dumbbells, band, frontView;
  final String cue;
  ExerciseAnim(
    this.start,
    this.end, {
    required this.cue,
    this.props = const [],
    this.plate = false,
    this.dumbbells = false,
    this.band = false,
    this.frontView = false,
  });
}

final _pullBar = Prop.line(o(28, 10), o(72, 10));

final Map<String, ExerciseAnim> exerciseAnims = {
  'Kniebeuge (Langhantel)': ExerciseAnim(
    pose(head: o(50, 18), neck: o(50, 27), hip: o(50, 55), elbow: o(43, 33), hand: o(47, 26),
        knee: o(51, 74), ankle: o(50, 93), toe: o(57, 93), bar: o(48, 26)),
    pose(head: o(56, 37), neck: o(52, 45), hip: o(38, 72), elbow: o(45, 51), hand: o(49, 44),
        knee: o(56, 74), ankle: o(50, 93), toe: o(57, 93), bar: o(50, 44)),
    plate: true,
    cue: 'Brust aufrecht, Knie Richtung Zehen, kontrolliert tief.',
  ),
  'Rumänisches Kreuzheben': ExerciseAnim(
    pose(head: o(50, 18), neck: o(50, 27), hip: o(50, 55), elbow: o(51, 41), hand: o(52, 54),
        knee: o(52, 74), ankle: o(50, 93), toe: o(57, 93), bar: o(52, 55)),
    pose(head: o(73, 62), neck: o(66, 59), hip: o(40, 52), elbow: o(65, 69), hand: o(64, 79),
        knee: o(48, 73), ankle: o(50, 93), toe: o(57, 93), bar: o(64, 80)),
    plate: true,
    cue: 'Hüfte nach hinten schieben, Rücken gerade, Stange nah an den Beinen.',
  ),
  'Bulgarian Split Squat': ExerciseAnim(
    pose(head: o(48, 14), neck: o(48, 23), hip: o(48, 50), elbow: o(48, 36), hand: o(48, 48),
        knee: o(56, 70), ankle: o(60, 93), toe: o(66, 93),
        kneeB: o(40, 67), ankleB: o(27, 75), toeB: o(23, 76)),
    pose(head: o(46, 28), neck: o(46, 37), hip: o(44, 64), elbow: o(46, 50), hand: o(46, 62),
        knee: o(60, 74), ankle: o(60, 93), toe: o(66, 93),
        kneeB: o(40, 86), ankleB: o(27, 75), toeB: o(23, 76)),
    props: [Prop.rect(const Rect.fromLTWH(12, 76, 20, 19))],
    dumbbells: true,
    cue: 'Gewicht auf dem vorderen Bein, hinteres Knie Richtung Boden.',
  ),
  'Wadenheben einbeinig halten': ExerciseAnim(
    pose(head: o(50, 18), neck: o(50, 27), hip: o(50, 55), elbow: o(60, 37), hand: o(70, 34),
        knee: o(50, 74), ankle: o(50, 93), toe: o(57, 93),
        elbowB: o(50, 41), handB: o(52, 53), kneeB: o(49, 74), ankleB: o(40, 83), toeB: o(37, 86)),
    pose(head: o(50, 11), neck: o(50, 20), hip: o(50, 48), elbow: o(60, 31), hand: o(70, 32),
        knee: o(50, 67), ankle: o(51, 86), toe: o(57, 93),
        elbowB: o(50, 34), handB: o(52, 46), kneeB: o(49, 67), ankleB: o(40, 76), toeB: o(37, 79)),
    props: [Prop.line(o(72, 5), o(72, 95))],
    cue: 'Langsam hoch, oben halten, Ferse kontrolliert runter.',
  ),
  'Copenhagen Plank': ExerciseAnim(
    pose(head: o(14, 74), neck: o(22, 78), hip: o(48, 88), elbow: o(22, 93), hand: o(34, 93),
        knee: o(64, 82), ankle: o(80, 72), toe: o(86, 70),
        elbowB: o(36, 80), handB: o(46, 84), kneeB: o(62, 88), ankleB: o(72, 92), toeB: o(76, 93)),
    pose(head: o(14, 72), neck: o(22, 77), hip: o(50, 75), elbow: o(22, 93), hand: o(34, 93),
        knee: o(66, 74), ankle: o(80, 72), toe: o(86, 70),
        elbowB: o(36, 72), handB: o(48, 72), kneeB: o(65, 80), ankleB: o(74, 88), toeB: o(78, 92)),
    props: [Prop.rect(const Rect.fromLTWH(72, 75, 22, 20))],
    cue: 'Hüfte hoch, gerade Linie von Schulter bis Fuß.',
  ),
  'Hip Thrust': ExerciseAnim(
    pose(head: o(18, 64), neck: o(24, 68), hip: o(44, 84), elbow: o(33, 79), hand: o(43, 81),
        knee: o(62, 72), ankle: o(68, 93), toe: o(75, 93), bar: o(44, 80)),
    pose(head: o(18, 64), neck: o(24, 68), hip: o(50, 66), elbow: o(37, 72), hand: o(49, 63),
        knee: o(66, 70), ankle: o(68, 93), toe: o(75, 93), bar: o(50, 62)),
    props: [Prop.rect(const Rect.fromLTWH(4, 70, 20, 25))],
    plate: true,
    cue: 'Kinn zur Brust, oben 1 Sek. das Gesäß fest anspannen.',
  ),
  'Einbeiniges Kreuzheben (KH)': ExerciseAnim(
    pose(head: o(50, 18), neck: o(50, 27), hip: o(50, 55), elbow: o(51, 41), hand: o(52, 54),
        knee: o(51, 74), ankle: o(50, 93), toe: o(57, 93),
        kneeB: o(48, 74), ankleB: o(46, 90), toeB: o(51, 92)),
    pose(head: o(81, 58), neck: o(74, 58), hip: o(48, 55), elbow: o(73, 67), hand: o(72, 76),
        knee: o(51, 74), ankle: o(50, 93), toe: o(57, 93),
        elbowB: o(72, 67), handB: o(71, 76), kneeB: o(30, 54), ankleB: o(12, 53), toeB: o(11, 59)),
    dumbbells: true,
    cue: 'Hüfte bleibt gerade, Oberkörper und hinteres Bein bilden eine Linie.',
  ),
  'Monster Walks mit Band': ExerciseAnim(
    pose(head: o(50, 24), neck: o(50, 33), hip: o(50, 58), elbow: o(38, 46), hand: o(44, 57),
        knee: o(40, 74), ankle: o(38, 93), toe: o(33, 93),
        elbowB: o(62, 46), handB: o(56, 57), kneeB: o(60, 74), ankleB: o(62, 93), toeB: o(67, 93)),
    pose(head: o(56, 24), neck: o(56, 33), hip: o(56, 58), elbow: o(44, 46), hand: o(50, 57),
        knee: o(43, 74), ankle: o(38, 93), toe: o(33, 93),
        elbowB: o(68, 46), handB: o(62, 57), kneeB: o(70, 73), ankleB: o(76, 93), toeB: o(81, 93)),
    band: true,
    frontView: true,
    cue: 'Leicht in die Knie, Knie aktiv nach außen drücken, kleine Schritte.',
  ),
  'Tibialis Raises': ExerciseAnim(
    pose(head: o(32, 16), neck: o(33, 25), hip: o(36, 52), elbow: o(34, 38), hand: o(37, 50),
        knee: o(45, 72), ankle: o(54, 92), toe: o(61, 93)),
    pose(head: o(32, 16), neck: o(33, 25), hip: o(36, 52), elbow: o(34, 38), hand: o(37, 50),
        knee: o(45, 72), ankle: o(54, 92), toe: o(59, 85)),
    props: [Prop.line(o(28, 5), o(28, 95))],
    cue: 'Rücken an die Wand, Fersen bleiben unten, Zehen hochziehen.',
  ),
  'Dips EMOM': ExerciseAnim(
    pose(head: o(50, 19), neck: o(50, 28), hip: o(48, 56), elbow: o(51, 37), hand: o(51, 46),
        knee: o(52, 72), ankle: o(40, 80), toe: o(38, 84)),
    pose(head: o(55, 33), neck: o(53, 41), hip: o(47, 68), elbow: o(41, 45), hand: o(51, 46),
        knee: o(51, 84), ankle: o(39, 90), toe: o(37, 93)),
    props: [
      Prop.line(o(30, 46), o(70, 46)),
      Prop.line(o(34, 46), o(34, 95)),
      Prop.line(o(66, 46), o(66, 95)),
    ],
    cue: 'Leicht nach vorne lehnen, runter bis die Oberarme waagerecht sind.',
  ),
  'Klimmzüge EMOM': ExerciseAnim(
    pose(head: o(51, 23), neck: o(50, 32), hip: o(49, 60), elbow: o(52, 21), hand: o(54, 10),
        knee: o(52, 77), ankle: o(46, 90), toe: o(44, 93)),
    pose(head: o(53, 5), neck: o(50, 14), hip: o(49, 42), elbow: o(44, 16), hand: o(54, 10),
        knee: o(52, 59), ankle: o(46, 72), toe: o(44, 75)),
    props: [_pullBar],
    cue: 'Ohne Schwung, Kinn über die Stange, kontrolliert runter.',
  ),
  'Toes to Bar': ExerciseAnim(
    pose(head: o(51, 23), neck: o(50, 32), hip: o(49, 60), elbow: o(52, 21), hand: o(54, 10),
        knee: o(49, 76), ankle: o(49, 91), toe: o(53, 93)),
    pose(head: o(47, 24), neck: o(50, 30), hip: o(40, 55), elbow: o(52, 20), hand: o(54, 10),
        knee: o(50, 36), ankle: o(56, 14), toe: o(59, 11)),
    props: [_pullBar],
    cue: 'Aus dem Bauch heraus, Füße zur Stange, langsam absenken.',
  ),
  'Liegestütze': ExerciseAnim(
    pose(head: o(23, 70), neck: o(30, 74), hip: o(58, 80), elbow: o(30, 83), hand: o(30, 93),
        knee: o(72, 86), ankle: o(86, 91), toe: o(88, 93)),
    pose(head: o(23, 84), neck: o(30, 87), hip: o(58, 89), elbow: o(39, 83), hand: o(30, 93),
        knee: o(72, 91), ankle: o(86, 92), toe: o(88, 93)),
    cue: 'Körper gerade wie ein Brett, Brust fast bis zum Boden.',
  ),
};

class ExerciseAnimation extends StatefulWidget {
  final ExerciseAnim anim;
  final double? size; // null = füllt den verfügbaren Platz
  const ExerciseAnimation({super.key, required this.anim, this.size});

  @override
  State<ExerciseAnimation> createState() => _ExerciseAnimationState();
}

class _ExerciseAnimationState extends State<ExerciseAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);
  late final Animation<double> curve = CurvedAnimation(parent: c, curve: Curves.easeInOut);

  @override
  void dispose() {
    c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final paint = AnimatedBuilder(
      animation: curve,
      builder: (_, __) => CustomPaint(
        painter: FigurePainter(
          anim: widget.anim,
          t: curve.value,
          color: cs.primary,
          propColor: cs.outline,
          accent: cs.tertiary,
        ),
      ),
    );
    if (widget.size == null) return SizedBox.expand(child: paint);
    return SizedBox(width: widget.size, height: widget.size, child: paint);
  }
}

class FigurePainter extends CustomPainter {
  final ExerciseAnim anim;
  final double t;
  final Color color, propColor, accent;
  FigurePainter({
    required this.anim,
    required this.t,
    required this.color,
    required this.propColor,
    required this.accent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100;
    canvas.save();
    canvas.translate((size.width - 100 * s) / 2, (size.height - 100 * s) / 2);
    canvas.scale(s);

    final p = {
      for (final k in anim.start.keys)
        k: Offset.lerp(anim.start[k], anim.end[k] ?? anim.start[k], t)!,
    };

    final propStroke = Paint()
      ..color = propColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final propFill = Paint()..color = propColor.withOpacity(0.3);

    canvas.drawLine(o(2, 95), o(98, 95), propStroke);
    for (final prop in anim.props) {
      if (prop.rect != null) {
        final r = RRect.fromRectAndRadius(prop.rect!, const Radius.circular(2));
        canvas.drawRRect(r, propFill);
        canvas.drawRRect(r, propStroke);
      } else {
        canvas.drawLine(prop.p1!, prop.p2!, propStroke);
      }
    }

    Paint limbPaint(Color c) => Paint()
      ..color = c
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final near = limbPaint(color);
    final far = limbPaint(anim.frontView ? color : color.withOpacity(0.4));

    void limb(Paint paint, List<String> keys) {
      final path = Path()..moveTo(p[keys.first]!.dx, p[keys.first]!.dy);
      for (final k in keys.skip(1)) {
        path.lineTo(p[k]!.dx, p[k]!.dy);
      }
      canvas.drawPath(path, paint);
    }

    // hintere Seite zuerst
    limb(far, ['hip', 'kneeB', 'ankleB', 'toeB']);
    limb(far, ['neck', 'elbowB', 'handB']);
    // Rumpf, vordere Seite
    limb(near, ['neck', 'hip']);
    limb(near, ['hip', 'kneeA', 'ankleA', 'toeA']);
    limb(near, ['neck', 'elbowA', 'handA']);
    canvas.drawCircle(p['head']!, 5.5, Paint()..color = color);

    final accentFill = Paint()..color = accent;
    if (anim.band) {
      canvas.drawLine(
          p['kneeA']!,
          p['kneeB']!,
          Paint()
            ..color = accent
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round);
    }
    if (anim.plate && p['bar'] != null) {
      canvas.drawCircle(p['bar']!, 7.5, accentFill);
      canvas.drawCircle(p['bar']!, 2, Paint()..color = propColor);
    }
    if (anim.dumbbells) {
      canvas.drawCircle(p['handB']!, 3.5, Paint()..color = accent.withOpacity(0.5));
      canvas.drawCircle(p['handA']!, 3.5, accentFill);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(FigurePainter old) => old.t != t || old.color != color;
}
