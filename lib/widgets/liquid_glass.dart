import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// 液态玻璃（Liquid Glass）面板
///
/// 和普通毛玻璃（BackdropFilter + 半透明白底）的区别，就在这 4 层：
///  1. 背景模糊 + 提饱和/微提亮：ColorFiltered 只包住玻璃体，不吃到上层图标文字
///  2. 玻璃体染色渐变：上亮下深，做出“厚度”
///  3. 边缘折光：外圈高光描边 + 内侧柔光 + 底部内侧暗环（模拟倒角折光）
///  4. 斜向镜面高光带（左上打光）
///
/// 用法：
/// ```dart
/// LiquidGlass(borderRadius: 26, child: ...)
/// ```
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    this.borderRadius = 26,
    this.blur = 24,
    this.backdrop = true,
    this.saturation = 1.25,
    this.brightness = 6,
    this.tint = const [Color(0x6BFFFFFF), Color(0x38FFFFFF)],
    this.rim = 1.0,
    this.shadow = true,
    this.glow,
    this.squircle = false,
    this.child,
  });

  /// 圆角半径
  final double borderRadius;

  /// 背景模糊强度
  final double blur;

  /// 是否模糊背后内容。叠在玻璃上的“轻玻璃”（如选中药丸）可以调小 blur，
  /// 两层大模糊叠在一起会发灰、发糊
  final bool backdrop;

  /// 背景提饱和倍数（1 = 不变）
  final double saturation;

  /// 背景提亮偏移（0~255）
  final double brightness;

  /// 玻璃体染色渐变（从上到下）
  final List<Color> tint;

  /// 边缘高光强度（0~1）
  final double rim;

  /// 是否画外阴影
  final bool shadow;

  /// 外发光色（如主题蓝），null 则不发光
  final Color? glow;

  /// true = 苹果式连续圆角（ContinuousRectangleBorder）；false = 普通圆角矩形（默认）。
  /// 注意：Flutter 的 ContinuousRectangleBorder 把贝塞尔控制点压在角点上，
  /// 同样半径视觉上会比圆角矩形“方”很多（药丸会看起来像小方框），所以默认用普通圆角。
  final bool squircle;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(borderRadius);
    final ShapeBorder shape = squircle
        ? ContinuousRectangleBorder(borderRadius: br)
        : RoundedRectangleBorder(borderRadius: br);

    final shadows = <BoxShadow>[
      if (glow != null)
        BoxShadow(
          color: glow!.withValues(alpha: .16),
          blurRadius: 16,
          offset: const Offset(0, 5),
        ),
      if (shadow) ...[
        BoxShadow(
          color: const Color(0xFF0B1220).withValues(alpha: .10),
          blurRadius: 26,
          offset: const Offset(0, 10),
        ),
        BoxShadow(
          color: const Color(0xFF0B1220).withValues(alpha: .06),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ];

    return Stack(
      children: [
        // 阴影只画在玻璃形状之外：否则半透明玻璃会把背后的阴影透出来，看着发灰发脏
        if (shadows.isNotEmpty)
          Positioned.fill(
            child: CustomPaint(
              painter: _GlassShadowPainter(shape: shape, shadows: shadows),
            ),
          ),
        Positioned.fill(
          child: ClipPath(
            clipper: ShapeBorderClipper(shape: shape),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1) 模糊 + 提饱和 + 微提亮
                if (backdrop)
                  ColorFiltered(
                    colorFilter: ColorFilter.matrix(
                      _saturateMatrix(saturation, brightness),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                      child: const ColoredBox(color: Color(0x00000000)),
                    ),
                  ),
                // 2) 玻璃体染色
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: tint,
                    ),
                  ),
                ),
                // 3) + 4) 高光与折光边缘
                CustomPaint(
                  painter: _LiquidGlassPainter(shape: shape, rim: rim),
                ),
              ],
            ),
          ),
        ),
        if (child != null) Positioned.fill(child: child!),
      ],
    );
  }
}

/// 提饱和 + 提亮的颜色矩阵
List<double> _saturateMatrix(double s, double b) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final inv = 1 - s;
  return <double>[
    lr * inv + s, lg * inv, lb * inv, 0, b, //
    lr * inv, lg * inv + s, lb * inv, 0, b, //
    lr * inv, lg * inv, lb * inv + s, 0, b, //
    0, 0, 0, 1, 0, //
  ];
}

/// 只画形状外部的阴影（避免透过半透明玻璃看到阴影而发灰）
class _GlassShadowPainter extends CustomPainter {
  const _GlassShadowPainter({required this.shape, required this.shadows});

  final ShapeBorder shape;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final path = shape.getOuterPath(rect);
    // 形状之外的一大片区域（要允许阴影画到组件之外，外层别 clip）
    final outside = Path.combine(
      PathOperation.difference,
      Path()..addRect(rect.inflate(size.height * 2)),
      path,
    );
    canvas.save();
    canvas.clipPath(outside, doAntiAlias: true);
    for (final s in shadows) {
      final shifted = Path()..addPath(path, Offset(s.offset.dx, s.offset.dy));
      canvas.drawPath(
        shifted,
        Paint()
          ..color = s.color
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            s.blurRadius * 0.57735 + 0.5, // 与 BoxShadow 的模糊半径换算一致
          ),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GlassShadowPainter old) =>
      old.shadows != shadows || old.shape != shape;
}

class _LiquidGlassPainter extends CustomPainter {
  const _LiquidGlassPainter({required this.shape, required this.rim});

  final ShapeBorder shape;
  final double rim;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final path = shape.getOuterPath(rect);
    final r = rim.clamp(0.0, 1.0);

    canvas.save();
    canvas.clipPath(path);

    // (a) 顶部整体高光：上亮下无，做出厚度
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [
            Colors.white.withValues(alpha: .26 * r),
            Colors.white.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );

    // (b) 斜向镜面高光带（左上打光）
    canvas.save();
    canvas.translate(size.width * .34, -size.height * .85);
    canvas.rotate(-.38);
    final band =
        Rect.fromLTWH(-size.width, 0, size.width * 2.6, size.height * 1.5);
    canvas.drawRect(
      band,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: .30 * r),
            Colors.white.withValues(alpha: .10 * r),
            Colors.white.withValues(alpha: 0),
          ],
          stops: const [0, .38, 1],
        ).createShader(band),
    );
    canvas.restore();

    // (c) 内侧柔光 = 玻璃倒角的折光
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * .34
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7)
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .34 * r),
            Colors.white.withValues(alpha: .05 * r),
            Colors.white.withValues(alpha: .18 * r),
          ],
          stops: const [0, .55, 1],
        ).createShader(rect),
    );

    // (d) 底部内侧暗环：背光侧的厚度感（很淡，太浓在浅色背景上会发脏）
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * .24
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5)
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, const Color(0x120B1220)],
          stops: const [.55, 1],
        ).createShader(rect),
    );

    canvas.restore();

    // (e) 外圈高光描边：左上最亮 → 右下淡
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: .95 * r),
            Colors.white.withValues(alpha: .46 * r),
            Colors.white.withValues(alpha: .26 * r),
          ],
          stops: const [0, .45, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_LiquidGlassPainter old) =>
      old.rim != rim || old.shape != shape;
}
