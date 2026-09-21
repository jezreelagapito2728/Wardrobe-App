import 'dart:math' as math;

import 'package:flutter/material.dart';

enum SkyCondition { clear, partlyCloudy, overcast, fog, rain, snow, storm }

SkyCondition skyConditionFromCode(int code) {
  if (code == 0 || code == 1) return SkyCondition.clear;
  if (code == 2) return SkyCondition.partlyCloudy;
  if (code == 3) return SkyCondition.overcast;
  if (code == 45 || code == 48) return SkyCondition.fog;
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
    return SkyCondition.rain;
  }
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
    return SkyCondition.snow;
  }
  if (code >= 95) return SkyCondition.storm;
  return SkyCondition.clear;
}

/// Animated sky: gradient, sun / moon, stars, drifting clouds, rain, snow,
/// fog and lightning. Draws everything with a CustomPainter, so no image
/// assets are needed.
class WeatherBackground extends StatefulWidget {
  const WeatherBackground({
    super.key,
    required this.weatherCode,
    required this.isDay,
    required this.child,
  });

  final int weatherCode;
  final bool isDay;
  final Widget child;

  @override
  State<WeatherBackground> createState() => _WeatherBackgroundState();
}

class _WeatherBackgroundState extends State<WeatherBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late _Scene _scene;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 90))
          ..repeat();
    _scene = _Scene.build(skyConditionFromCode(widget.weatherCode), widget.isDay);
  }

  @override
  void didUpdateWidget(covariant WeatherBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weatherCode != widget.weatherCode ||
        oldWidget.isDay != widget.isDay) {
      setState(() {
        _scene =
            _Scene.build(skyConditionFromCode(widget.weatherCode), widget.isDay);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: CustomPaint(
            painter: _SkyPainter(_controller, _scene),
            size: Size.infinite,
          ),
        ),
        widget.child,
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Scene data (generated once per condition, deterministic)
// -----------------------------------------------------------------------------
class _Cloud {
  final double y; // 0..1 of height
  final double scale; // cloud width as fraction of screen width
  final double phase; // 0..1
  final int speed; // integer -> seamless loop
  final double alpha;
  const _Cloud(this.y, this.scale, this.phase, this.speed, this.alpha);
}

class _Drop {
  final double x, phase, len, width, alpha;
  final int cycles;
  const _Drop(this.x, this.phase, this.len, this.width, this.alpha, this.cycles);
}

class _Flake {
  final double x, phase, r, alpha;
  final int cycles, sway;
  const _Flake(this.x, this.phase, this.r, this.alpha, this.cycles, this.sway);
}

class _Star {
  final double x, y, r, phase;
  final int cycles;
  const _Star(this.x, this.y, this.r, this.phase, this.cycles);
}

class _Scene {
  final SkyCondition condition;
  final bool isDay;
  final List<Color> sky;
  final Color cloudColor;
  final List<_Cloud> clouds;
  final List<_Drop> drops;
  final List<_Flake> flakes;
  final List<_Star> stars;

  const _Scene({
    required this.condition,
    required this.isDay,
    required this.sky,
    required this.cloudColor,
    required this.clouds,
    required this.drops,
    required this.flakes,
    required this.stars,
  });

  bool get showSun =>
      isDay &&
      (condition == SkyCondition.clear || condition == SkyCondition.partlyCloudy);
  bool get showMoon =>
      !isDay &&
      (condition == SkyCondition.clear || condition == SkyCondition.partlyCloudy);
  bool get showStars => showMoon;

  static _Scene build(SkyCondition c, bool isDay) {
    final rnd = math.Random(c.index * 31 + (isDay ? 1 : 0));

    // ---- sky gradient
    List<Color> sky;
    switch (c) {
      case SkyCondition.clear:
        sky = isDay
            ? const [Color(0xFF0E5CBA), Color(0xFF2F86DB), Color(0xFF6DB2EE)]
            : const [Color(0xFF070B1E), Color(0xFF14204A), Color(0xFF2A3A75)];
        break;
      case SkyCondition.partlyCloudy:
        sky = isDay
            ? const [Color(0xFF1C6CC2), Color(0xFF4C98DF), Color(0xFF8BC1ED)]
            : const [Color(0xFF0B1128), Color(0xFF1A2650), Color(0xFF33437A)];
        break;
      case SkyCondition.overcast:
        sky = isDay
            ? const [Color(0xFF53606D), Color(0xFF74818E), Color(0xFF98A4B0)]
            : const [Color(0xFF151B29), Color(0xFF252E44), Color(0xFF3A4562)];
        break;
      case SkyCondition.fog:
        sky = isDay
            ? const [Color(0xFF74818B), Color(0xFF909BA4), Color(0xFFAEB7BE)]
            : const [Color(0xFF1B212B), Color(0xFF2C3440), Color(0xFF444D5A)];
        break;
      case SkyCondition.rain:
        sky = isDay
            ? const [Color(0xFF465160), Color(0xFF66727F), Color(0xFF8D99A6)]
            : const [Color(0xFF0C1018), Color(0xFF1A202C), Color(0xFF2A3342)];
        break;
      case SkyCondition.storm:
        sky = isDay
            ? const [Color(0xFF2E3644), Color(0xFF465061), Color(0xFF69768A)]
            : const [Color(0xFF07090F), Color(0xFF131824), Color(0xFF232B3B)];
        break;
      case SkyCondition.snow:
        sky = isDay
            ? const [Color(0xFF5E7690), Color(0xFF8298AF), Color(0xFFAFBFCF)]
            : const [Color(0xFF1B2333), Color(0xFF2E3A52), Color(0xFF4A5874)];
        break;
    }

    // ---- cloud colour
    Color cloudColor;
    if (isDay) {
      if (c == SkyCondition.clear || c == SkyCondition.partlyCloudy) {
        cloudColor = Colors.white;
      } else if (c == SkyCondition.rain || c == SkyCondition.storm) {
        cloudColor = const Color(0xFFA7B0BB);
      } else {
        cloudColor = const Color(0xFFEEF1F4);
      }
    } else {
      if (c == SkyCondition.clear || c == SkyCondition.partlyCloudy) {
        cloudColor = const Color(0xFF6E7BA0);
      } else if (c == SkyCondition.rain || c == SkyCondition.storm) {
        cloudColor = const Color(0xFF394155);
      } else {
        cloudColor = const Color(0xFF515B78);
      }
    }

    // ---- clouds
    int count;
    double baseAlpha;
    double maxY;
    switch (c) {
      case SkyCondition.clear:
        count = 3;
        baseAlpha = 0.7;
        maxY = 0.35;
        break;
      case SkyCondition.partlyCloudy:
        count = 6;
        baseAlpha = 0.9;
        maxY = 0.45;
        break;
      case SkyCondition.overcast:
        count = 10;
        baseAlpha = 0.95;
        maxY = 0.55;
        break;
      case SkyCondition.fog:
        count = 5;
        baseAlpha = 0.7;
        maxY = 0.5;
        break;
      case SkyCondition.rain:
      case SkyCondition.storm:
        count = 11;
        baseAlpha = 0.95;
        maxY = 0.5;
        break;
      case SkyCondition.snow:
        count = 8;
        baseAlpha = 0.9;
        maxY = 0.5;
        break;
    }

    final heavy = c == SkyCondition.overcast ||
        c == SkyCondition.rain ||
        c == SkyCondition.storm;

    final clouds = <_Cloud>[];
    for (var i = 0; i < count; i++) {
      final near = i.isOdd;
      final scale = (near ? 0.55 : 0.35) +
          rnd.nextDouble() * 0.3 +
          (heavy ? 0.15 : 0.0);
      clouds.add(_Cloud(
        0.04 + rnd.nextDouble() * maxY,
        scale,
        rnd.nextDouble(),
        near ? 2 : 1,
        near ? baseAlpha : baseAlpha * 0.7,
      ));
    }
    // far (small, slow) first so near clouds paint on top
    clouds.sort((a, b) => a.speed.compareTo(b.speed));

    // ---- rain
    final drops = <_Drop>[];
    if (c == SkyCondition.rain || c == SkyCondition.storm) {
      final n = c == SkyCondition.storm ? 220 : 140;
      for (var i = 0; i < n; i++) {
        drops.add(_Drop(
          rnd.nextDouble(),
          rnd.nextDouble(),
          12 + rnd.nextDouble() * 16,
          0.8 + rnd.nextDouble() * 1.0,
          0.25 + rnd.nextDouble() * 0.35,
          90 + rnd.nextInt(70),
        ));
      }
    }

    // ---- snow
    final flakes = <_Flake>[];
    if (c == SkyCondition.snow) {
      for (var i = 0; i < 110; i++) {
        flakes.add(_Flake(
          rnd.nextDouble(),
          rnd.nextDouble(),
          1.2 + rnd.nextDouble() * 2.6,
          0.5 + rnd.nextDouble() * 0.5,
          8 + rnd.nextInt(8),
          4 + rnd.nextInt(5),
        ));
      }
    }

    // ---- stars
    final stars = <_Star>[];
    if (!isDay &&
        (c == SkyCondition.clear || c == SkyCondition.partlyCloudy)) {
      for (var i = 0; i < 80; i++) {
        stars.add(_Star(
          rnd.nextDouble(),
          rnd.nextDouble() * 0.6,
          0.6 + rnd.nextDouble() * 1.2,
          rnd.nextDouble(),
          20 + rnd.nextInt(40),
        ));
      }
    }

    return _Scene(
      condition: c,
      isDay: isDay,
      sky: sky,
      cloudColor: cloudColor,
      clouds: clouds,
      drops: drops,
      flakes: flakes,
      stars: stars,
    );
  }
}

// -----------------------------------------------------------------------------
// Painter
// -----------------------------------------------------------------------------
class _SkyPainter extends CustomPainter {
  _SkyPainter(this.anim, this.scene) : super(repaint: anim);

  final Animation<double> anim;
  final _Scene scene;

  static const _twoPi = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value; // 0..1 over 90 seconds, loops seamlessly
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    // Sky
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: scene.sky,
        ).createShader(rect),
    );

    // Stars
    if (scene.showStars) {
      final p = Paint();
      for (final s in scene.stars) {
        final tw = 0.5 + 0.5 * math.sin(_twoPi * (t * s.cycles + s.phase));
        p.color = Colors.white.withValues(alpha: 0.25 + 0.65 * tw);
        canvas.drawCircle(Offset(s.x * w, s.y * h), s.r, p);
      }
    }

    // Sun / Moon
    if (scene.showSun) _drawSun(canvas, size, t);
    if (scene.showMoon) _drawMoon(canvas, size);

    // Fog haze (behind the front clouds)
    if (scene.condition == SkyCondition.fog) {
      canvas.drawRect(
        rect,
        Paint()..color = Colors.white.withValues(alpha: scene.isDay ? 0.18 : 0.06),
      );
    }

    // Clouds
    for (final c in scene.clouds) {
      final x = ((c.phase + t * c.speed) % 1.0) * (w * 1.5) - w * 0.25;
      _drawCloud(canvas, Offset(x, c.y * h), c.scale * w, scene.cloudColor, c.alpha);
    }

    // Fog bands
    if (scene.condition == SkyCondition.fog) {
      final p = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40)
        ..color = Colors.white.withValues(alpha: scene.isDay ? 0.30 : 0.10);
      for (var i = 0; i < 4; i++) {
        final x = (((i * 0.27) + t * (i.isEven ? 1 : 2)) % 1.0) * (w * 1.6) - w * 0.3;
        final y = h * (0.30 + i * 0.15);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(x, y), width: w * 0.9, height: h * 0.12),
          p,
        );
      }
    }

    // Rain
    if (scene.drops.isNotEmpty) {
      final p = Paint()..strokeCap = StrokeCap.round;
      for (final d in scene.drops) {
        final y = ((d.phase + t * d.cycles) % 1.0) * (h + d.len) - d.len;
        final x = d.x * (w + h * 0.15) - y * 0.15;
        p
          ..strokeWidth = d.width
          ..color = Colors.white.withValues(alpha: d.alpha);
        canvas.drawLine(Offset(x, y), Offset(x - d.len * 0.15, y + d.len), p);
      }
    }

    // Snow
    if (scene.flakes.isNotEmpty) {
      final p = Paint();
      for (final f in scene.flakes) {
        final y = ((f.phase + t * f.cycles) % 1.0) * (h + 10) - 5;
        final x = f.x * w + math.sin(_twoPi * (t * f.sway + f.phase)) * 14;
        p.color = Colors.white.withValues(alpha: f.alpha);
        canvas.drawCircle(Offset(x, y), f.r, p);
      }
    }

    // Lightning
    if (scene.condition == SkyCondition.storm) {
      final cycle = (t * 18) % 1.0; // a flash about every 5 seconds
      double flash = 0;
      if (cycle < 0.05) {
        flash = 1 - cycle / 0.05;
      } else if (cycle > 0.08 && cycle < 0.10) {
        flash = 0.5 * (1 - (cycle - 0.08) / 0.02);
      }
      if (flash > 0) {
        canvas.drawRect(
          rect,
          Paint()..color = Colors.white.withValues(alpha: flash * 0.45),
        );
      }
    }

    // Soft dark gradient at the bottom so white text stays readable
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.40)],
          stops: const [0.35, 1.0],
        ).createShader(rect),
    );
  }

  void _drawSun(Canvas canvas, Size size, double t) {
    final w = size.width;
    final h = size.height;
    final c = Offset(w * 0.78, h * 0.17);
    final pulse = 1 + 0.04 * math.sin(_twoPi * t * 9);
    final r = w * 0.45 * pulse;

    final glow = RadialGradient(
      colors: [
        const Color(0xFFFFF6C2).withValues(alpha: 0.95),
        const Color(0xFFFFE27A).withValues(alpha: 0.35),
        const Color(0xFFFFE27A).withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.25, 1.0],
    ).createShader(Rect.fromCircle(center: c, radius: r));
    canvas.drawCircle(c, r, Paint()..shader = glow);

    // Slowly rotating soft rays
    final ray = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    for (var i = 0; i < 12; i++) {
      final a = _twoPi * (i / 12 + t);
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * (w * 0.10), c + dir * (w * 0.34), ray);
    }

    canvas.drawCircle(c, w * 0.055, Paint()..color = const Color(0xFFFFFBE0));
  }

  void _drawMoon(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = Offset(w * 0.78, h * 0.16);

    final glow = RadialGradient(
      colors: [
        const Color(0xFFDCE6FF).withValues(alpha: 0.35),
        const Color(0xFFDCE6FF).withValues(alpha: 0.0),
      ],
    ).createShader(Rect.fromCircle(center: c, radius: w * 0.25));
    canvas.drawCircle(c, w * 0.25, Paint()..shader = glow);

    final r = w * 0.05;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFF4F1DE));
    final crater = Paint()..color = const Color(0xFFDAD6BC);
    canvas.drawCircle(c + Offset(-r * 0.3, -r * 0.2), r * 0.22, crater);
    canvas.drawCircle(c + Offset(r * 0.35, r * 0.25), r * 0.16, crater);
    canvas.drawCircle(c + Offset(-r * 0.05, r * 0.5), r * 0.12, crater);
  }

  void _drawCloud(
      Canvas canvas, Offset c, double w, Color color, double alpha) {
    // (dx, dy, radius) relative to cloud width
    const puffs = <List<double>>[
      [-0.32, 0.04, 0.16],
      [-0.16, -0.05, 0.22],
      [0.02, -0.11, 0.26],
      [0.20, -0.03, 0.22],
      [0.34, 0.05, 0.16],
      [0.00, 0.05, 0.24],
    ];

    final blur = const MaskFilter.blur(BlurStyle.normal, 14);

    void draw(Paint p, Offset shift) {
      for (final q in puffs) {
        canvas.drawCircle(
          c + shift + Offset(q[0] * w, q[1] * w),
          q[2] * w,
          p,
        );
      }
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: c + shift + Offset(0, w * 0.10),
            width: w * 0.85,
            height: w * 0.16,
          ),
          Radius.circular(w * 0.08),
        ),
        p,
      );
    }

    // Shaded underside
    draw(
      Paint()
        ..color = Color.lerp(color, Colors.black, 0.18)!.withValues(alpha: alpha)
        ..maskFilter = blur,
      Offset(0, w * 0.035),
    );
    // Main body
    draw(
      Paint()
        ..color = color.withValues(alpha: alpha)
        ..maskFilter = blur,
      Offset.zero,
    );
  }

  @override
  bool shouldRepaint(covariant _SkyPainter old) => old.scene != scene;
}