import 'package:flutter/material.dart';
import '../app_colors.dart';

// ═══════════════════════════════════════════════════════════════
//  INTERAKTIVES TUTORIAL OVERLAY
//
//  Zeigt nacheinander Schritte an, bei denen der Nutzer
//  GENAU auf das hervorgehobene Element tippen MUSS.
// ═══════════════════════════════════════════════════════════════

class TutorialStep {
  final GlobalKey key;
  final String emoji;
  final String title;
  final String description;
  final String tapHint;

  const TutorialStep({
    required this.key,
    required this.emoji,
    required this.title,
    required this.description,
    required this.tapHint,
  });
}

class TutorialOverlay extends StatefulWidget {
  final List<TutorialStep> steps;
  final VoidCallback onComplete;

  const TutorialOverlay({
    super.key,
    required this.steps,
    required this.onComplete,
  });

  @override
  State<TutorialOverlay> createState() => _TutorialOverlayState();
}

class _TutorialOverlayState extends State<TutorialOverlay>
    with SingleTickerProviderStateMixin {
  int _step = 0;
  late AnimationController _pulse;
  late Animation<double> _pulseAnim;
  bool _shakeHint = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < widget.steps.length - 1) {
      setState(() => _step++);
    } else {
      widget.onComplete();
    }
  }

  void _wrongTap() {
    setState(() => _shakeHint = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) setState(() => _shakeHint = false);
    });
  }

  Rect _getTargetRect(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx == null) return Rect.zero;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return Rect.zero;
    // ancestor = Overlay-RenderBox → Koordinaten relativ zur Overlay-Fläche,
    // nicht zum physischen Bildschirm. Verhindert Versatz bei Transforms/Padding.
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    final pos = box.localToGlobal(Offset.zero, ancestor: overlayBox);
    return pos & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_step];
    final targetRect = _getTargetRect(step.key);
    final inflated = targetRect.inflate(6);
    final screenSize = MediaQuery.of(context).size;

    // Callout erscheint unterhalb des Elements wenn es in der oberen Hälfte ist,
    // sonst darüber (z.B. bei Bottom-NavBar-Items)
    final calloutBelow = targetRect.center.dy < screenSize.height * 0.55;

    // Vertikale Position der Callout-Box
    final calloutTop = calloutBelow ? inflated.bottom + 16 : null;
    // "bottom" = Abstand vom unteren Bildschirmrand
    final calloutBottom =
        calloutBelow ? null : screenSize.height - inflated.top + 16;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // ── 1. Dunkle Overlay-Maske mit Aussparung ─────────────
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => IgnorePointer(
              child: CustomPaint(
                size: screenSize,
                painter: _OverlayPainter(
                  highlight: inflated,
                  pulse: _pulseAnim.value,
                ),
              ),
            ),
          ),

          // ── 2. Alles außerhalb blockieren ───────────────────────
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _wrongTap,
            child: const SizedBox.expand(),
          ),

          // ── 3. Tap-Ziel (MUSS getippt werden) ──────────────────
          Positioned(
            left: inflated.left,
            top: inflated.top,
            width: inflated.width,
            height: inflated.height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _next,
              child: const SizedBox.expand(),
            ),
          ),

          // ── 4. Callout-Box (inkl. Dots + Überspringen) ─────────
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            left: 16,
            right: 16,
            top: calloutTop,
            bottom: calloutBottom,
            child: _buildCallout(step),
          ),

          // ── 5. "Daneben getippt"-Hinweis ────────────────────────
          if (_shakeHint)
            Positioned(
              top: screenSize.height / 2 - 30,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Text(
                    'Tippe auf das markierte Element!',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCallout(TutorialStep step) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(step.emoji, style: const TextStyle(fontSize: 34)),
          const SizedBox(height: 6),
          Text(
            step.title,
            style: const TextStyle(
                color: AppColors.gold,
                fontSize: 18,
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            step.description,
            style: const TextStyle(color: AppColors.text2, height: 1.5, fontSize: 13),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          // Pulsierender Tap-Hinweis
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Opacity(
              opacity: 0.5 + _pulseAnim.value * 0.5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.touch_app,
                      color: AppColors.gold, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    step.tapHint,
                    style: const TextStyle(
                        color: AppColors.gold,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 4),
          // Überspringen + Dots in einer Reihe innerhalb der Callout-Box
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: widget.onComplete,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Überspringen',
                    style:
                        TextStyle(color: Colors.white54, fontSize: 12)),
              ),
              _buildDots(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.steps.length, (i) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == _step ? 18 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: i == _step ? AppColors.gold : Colors.white30,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ── CustomPainter: dunkle Maske mit leuchtender Aussparung ──────

class _OverlayPainter extends CustomPainter {
  final Rect highlight;
  final double pulse;

  _OverlayPainter({required this.highlight, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final inner = Path()
      ..addRRect(
          RRect.fromRectAndRadius(highlight, const Radius.circular(12)));
    final mask = Path.combine(PathOperation.difference, outer, inner);

    canvas.drawPath(
      mask,
      Paint()..color = const Color(0xCC000000),
    );

    // Pulsierender Leuchtrahmen
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          highlight.inflate(pulse * 4), const Radius.circular(14)),
      Paint()
        ..color = AppColors.gold.withValues(alpha: 0.15 + pulse * 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + pulse * 2,
    );
    // Fester innerer Rahmen
    canvas.drawRRect(
      RRect.fromRectAndRadius(highlight, const Radius.circular(12)),
      Paint()
        ..color = AppColors.gold.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      old.pulse != pulse || old.highlight != highlight;
}
