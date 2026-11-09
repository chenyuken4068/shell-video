import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 屏幕洞裁剪器：把「竖屏屏幕框」绕自身中心旋转 [angle] 弧度后作为裁剪路径。
///
/// 为什么需要它：预览里外壳会随方向旋转，但**内容不跟着转**（和导出一致：
/// 壳转、内容不转，横屏时横视频按横屏比例裁切填满屏幕）。内容层画在卡框坐标系里
/// 保持正立，用这个裁剪器把它裁成当前角度下的屏幕形状。
///
/// 圆角补偿：与导出用的 CornerMask 完全一致 —— 直边贴合屏幕边缘，
/// **四角圆弧的圆心向外扩 [outset]**（默认 5px 对应的像素值），
/// R 值算偏小时少裁一点、防止白边；溢出部分由外壳最后绘制盖住。
class ScreenHoleClipper extends CustomClipper<Path> {
  const ScreenHoleClipper({
    required this.width,
    required this.height,
    required this.angle,
    required this.radius,
    this.outset = 0,
  });

  /// 洞宽（卡框坐标系，未旋转时）
  final double width;

  /// 洞高（卡框坐标系，未旋转时）
  final double height;

  /// 旋转角（与 Transform.rotate 同一约定：正数 = 顺时针）
  final double angle;

  /// 圆角半径
  final double radius;

  /// 圆角向外扩的像素（与 CornerMask 的 o=5 对应，按预览缩放换算后传入）
  final double outset;

  @override
  Path getClip(Size size) {
    final w = width;
    final h = height;
    final r = math.max(0.0, radius);
    final o = math.max(0.0, outset);
    // ⚠️ 裁剪路径必须是「左上角 (0,0)」坐标系（CustomClipper 约定），
    // 路径整体以框中心为基准构建后再旋转到卡框中心
    final cx = size.width / 2;
    final cy = size.height / 2;
    final l = cx - w / 2;
    final t = cy - h / 2;

    // ① 直边：贴合屏幕边缘（竖条 + 横条）
    final path = Path()
      ..addRect(Rect.fromLTWH(l + r, t, w - 2 * r, h))
      ..addRect(Rect.fromLTWH(l, t + r, w, h - 2 * r));

    // ② 四角：圆弧圆心向外扩 o（半径不变）—— 与 CornerMask 一致
    if (r > 0) {
      path
        ..addOval(Rect.fromCircle(
            center: Offset(l + r - o, t + r - o), radius: r))
        ..addOval(Rect.fromCircle(
            center: Offset(l + w - r + o, t + r - o), radius: r))
        ..addOval(Rect.fromCircle(
            center: Offset(l + r - o, t + h - r + o), radius: r))
        ..addOval(Rect.fromCircle(
            center: Offset(l + w - r + o, t + h - r + o), radius: r));
    }

    final center = Offset(size.width / 2, size.height / 2);
    final c = math.cos(angle);
    final s = math.sin(angle);
    // Path.transform 是「绕原点」旋转：先平移到框中心、旋转、再平移回来
    return path.transform(Float64List.fromList(<double>[
      c, s, 0, 0, //
      -s, c, 0, 0, //
      0, 0, 1, 0, //
      center.dx - c * center.dx + s * center.dy, //
      center.dy - s * center.dx - c * center.dy, //
      0, 1, //
    ]));
  }

  @override
  bool shouldReclip(ScreenHoleClipper old) =>
      old.width != width ||
      old.height != height ||
      old.angle != angle ||
      old.radius != radius ||
      old.outset != outset;
}
