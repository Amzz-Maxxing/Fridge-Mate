// Animated loading screen (canvas "Animation 1 · Build-up"): the tile pops
// in and gives a little rattle, the shelves draw, food drops onto the
// shelf, the sprout grows, sparkles rise — then the leaves sway gently
// until the app is ready. Matches the native launch screen (forest green
// with the icon), so the hand-off is seamless.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// How long the intro animation takes. Startup waits at least this long so
/// the animation is seen in full.
const Duration splashIntro = Duration(milliseconds: 2200);

class BrandSplash extends StatefulWidget {
  /// False shows the finished icon straight away (still swaying), e.g. for
  /// a second loading step right after the first.
  final bool playIntro;

  /// The intro waits (on plain forest green) until this is true. Startup
  /// sets it once Firebase and the font are ready, so the animation isn't
  /// cut short by the stutter of app launch.
  final bool start;

  /// Called once the intro has finished playing.
  final VoidCallback? onFinished;

  const BrandSplash({
    super.key,
    this.playIntro = true,
    this.start = true,
    this.onFinished,
  });

  @override
  State<BrandSplash> createState() => _BrandSplashState();
}

class _BrandSplashState extends State<BrandSplash>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: splashIntro,
    value: widget.playIntro ? 0 : 1,
  )..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onFinished?.call();
    });
  late final AnimationController _sway = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();

  @override
  void initState() {
    super.initState();
    if (widget.start) _begin();
  }

  @override
  void didUpdateWidget(BrandSplash old) {
    super.didUpdateWidget(old);
    if (widget.start && !old.start) _begin();
  }

  /// Plays the intro after the next frame, so it starts on a smooth frame.
  void _begin() {
    if (!widget.playIntro) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // With reduce-motion on, skip straight to the finished logo.
      if (MediaQuery.of(context).disableAnimations) {
        _intro.value = 1;
        widget.onFinished?.call();
      } else {
        _intro.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _sway.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return Scaffold(
      backgroundColor: brandForest,
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_intro, _sway]),
          builder: (context, _) {
            final t = reduceMotion ? 1.0 : _intro.value;
            final sway = reduceMotion
                ? 0.0
                : math.sin(_sway.value * 2 * math.pi) * seg(t, 0.84, 1.0);
            final textIn = seg(t, 0.55, 0.85);
            final byIn = seg(t, 0.68, 0.95);
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: 'Fridge Mate',
                  image: true,
                  child: CustomPaint(
                    size: const Size.square(128),
                    painter: FreshShelfPainter(
                      progress: t,
                      sway: sway,
                      sparkles: !reduceMotion,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Opacity(
                  opacity: textIn,
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - textIn)),
                    child: Text(
                      'Fridge Mate',
                      style: appFont(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Opacity(
                  opacity: byIn,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'by',
                        style: appFont(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: forestLight,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const ShelfLifeLogo(height: 32),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// [t] mapped into the [from]..[to] window as 0..1, with a curve.
double seg(double t, double from, double to, [Curve curve = Curves.easeOut]) =>
    curve.transform(((t - from) / (to - from)).clamp(0.0, 1.0));

/// Draws the "Fresh Shelf" icon (Fridge Mate logo concept 3) in its
/// 100×100 design units. [progress] 0..1 builds it up; [sway] -1..1 tilts
/// the leaves; [sparkles] shows the rising sparkles near the end.
class FreshShelfPainter extends CustomPainter {
  final double progress;
  final double sway;
  final bool sparkles;
  const FreshShelfPainter({
    required this.progress,
    this.sway = 0,
    this.sparkles = true,
  });

  // Timeline (fractions of the intro):
  //   0.00–0.18 tile pops in      0.18–0.30 rattle
  //   0.30–0.52 shelves draw      0.46–0.72 food drops
  //   0.56–0.70 stem grows        0.66–0.84 leaves unfurl
  //   0.82–1.00 sparkles rise

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress;
    canvas.save();
    canvas.scale(size.width / 100, size.height / 100);

    // Rattle: a quick, fading wiggle around the bottom centre (±3°).
    final r = ((t - 0.18) / 0.12).clamp(0.0, 1.0);
    if (r > 0 && r < 1) {
      final angle = 3 * math.pi / 180 * math.sin(r * 3 * math.pi) * (1 - r);
      canvas.translate(50, 100);
      canvas.rotate(-angle);
      canvas.translate(-50, -100);
    }

    // 1) Tile + fridge body pop in (slight overshoot).
    final pop = seg(t, 0.0, 0.18, Curves.easeOutBack);
    if (pop > 0) {
      canvas.save();
      canvas.translate(50, 50);
      canvas.scale(0.6 + 0.4 * pop);
      canvas.translate(-50, -50);
      final alpha = seg(t, 0.0, 0.12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(0, 0, 100, 100),
          const Radius.circular(24),
        ),
        Paint()..color = brandLeaf.withValues(alpha: alpha),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(22, 16, 56, 70),
          const Radius.circular(10),
        ),
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
      canvas.restore();
    }

    final ink = Paint()
      ..color = brandForest
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // 2) Shelves draw left to right.
    final s1 = seg(t, 0.30, 0.46);
    final s2 = seg(t, 0.36, 0.52);
    ink.strokeWidth = 5;
    if (s1 > 0) {
      canvas.drawLine(const Offset(30, 46), Offset(30 + 40 * s1, 46), ink);
    }
    if (s2 > 0) {
      canvas.drawLine(const Offset(30, 66), Offset(30 + 40 * s2, 66), ink);
    }

    // 3) Food drops onto the lower shelf, one after another.
    void drop(double from, Offset anchor, void Function() draw) {
      final v = seg(t, from, from + 0.16, Curves.elasticOut);
      if (v <= 0) return;
      canvas.save();
      canvas.translate(anchor.dx, anchor.dy);
      canvas.scale(v);
      canvas.translate(-anchor.dx, -anchor.dy);
      draw();
      canvas.restore();
    }

    drop(0.46, const Offset(37, 63), () {
      canvas.drawCircle(
        const Offset(37, 58),
        5,
        Paint()..color = const Color(0xFFFF8A7A),
      );
    });
    drop(0.51, const Offset(51, 63), () {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(47, 51, 8, 12),
          const Radius.circular(2),
        ),
        Paint()..color = const Color(0xFFF2B544),
      );
    });
    drop(0.56, const Offset(63, 63), () {
      canvas.drawCircle(
        const Offset(63, 59),
        4,
        Paint()..color = const Color(0xFF9BD8AE),
      );
    });

    // 4) Sprout: the stem grows, then the leaves unfurl and sway.
    final stem = seg(t, 0.56, 0.70);
    if (stem > 0) {
      ink.strokeWidth = 4;
      canvas.drawLine(const Offset(50, 46), Offset(50, 46 - 13 * stem), ink);
    }
    final leaves = seg(t, 0.66, 0.84, Curves.easeOutBack);
    if (leaves > 0) {
      void leaf(Path path, Color color, Offset base, double tilt) {
        canvas.save();
        canvas.translate(base.dx, base.dy);
        canvas.rotate(tilt);
        canvas.scale(leaves);
        canvas.translate(-base.dx, -base.dy);
        canvas.drawPath(path, Paint()..color = color);
        canvas.restore();
      }

      const deg = math.pi / 180;
      leaf(
        Path()
          ..moveTo(50, 36)
          ..cubicTo(43, 36, 39, 31, 39, 25)
          ..cubicTo(46, 25, 50, 30, 50, 36)
          ..close(),
        brandForest,
        const Offset(50, 36),
        -6 * deg * sway,
      );
      leaf(
        Path()
          ..moveTo(50, 32)
          ..cubicTo(57, 32, 61, 27, 61, 21)
          ..cubicTo(54, 21, 50, 26, 50, 32)
          ..close(),
        const Color(0xFF2E9E5B),
        const Offset(50, 32),
        6 * deg * sway,
      );
    }

    // 5) Sparkles rise above the sprout and fade (from "Sprout Bloom").
    if (sparkles) {
      void spark(double from, Offset at, double radius) {
        final u = ((t - from) / 0.16).clamp(0.0, 1.0);
        if (u <= 0 || u >= 1) return;
        // Fade in over the first 40%, out over the rest; rise 16 units.
        final opacity = u < 0.4 ? u / 0.4 : (1 - u) / 0.6;
        final scale = u < 0.4
            ? 0.4 + 0.6 * (u / 0.4)
            : 1 - 0.4 * ((u - 0.4) / 0.6);
        canvas.drawCircle(
          at.translate(0, -16 * Curves.easeOut.transform(u)),
          radius * scale,
          Paint()..color = Colors.white.withValues(alpha: opacity.clamp(0, 1)),
        );
      }

      spark(0.82, const Offset(34, 22), 1.8);
      spark(0.84, const Offset(66, 18), 1.5);
      spark(0.86, const Offset(58, 12), 1.2);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(FreshShelfPainter old) =>
      old.progress != progress || old.sway != sway || old.sparkles != sparkles;
}
