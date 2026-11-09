import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 实况创作图标（Apple / HyperOS 风格）：外环虚线 + 中环实线 + 中心实心点
///
/// - 外环虚线 = 「持续 / 循环」的动感 ✓
/// - 中环 + 实心点 = 实况照片（Live Photo）经典靶心 ✓
/// 用 CustomPainter 绘制，任意尺寸无损、跟随主题色。
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, this.size = 22, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LiveBadgePainter(color)),
    );
  }
}

class _LiveBadgePainter extends CustomPainter {
  _LiveBadgePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final s = size.shortestSide;
    final stroke = s * 0.085;

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;

    // ① 外环：虚线（12 段）
    final rOuter = s * 0.44;
    const seg = 0.30; // 每段弧度
    const gap = 0.19; // 间隔弧度
    var a = -math.pi / 2; // 从正上方起笔
    final end = a + 2 * math.pi - gap;
    while (a < end) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: rOuter),
        a,
        seg,
        false,
        ring,
      );
      a += seg + gap;
    }

    // ② 中环：实线
    canvas.drawCircle(c, s * 0.255, ring);

    // ③ 中心实心点
    canvas.drawCircle(c, s * 0.105, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _LiveBadgePainter oldDelegate) =>
      oldDelegate.color != color;
}
