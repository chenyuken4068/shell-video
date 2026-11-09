import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

/// 在 isolate 里扫壳图 alpha 可见区域的包围盒（长边先缩到 400px 再扫，够快）
/// 返回 [x0, y0, x1, y1]（原图像素坐标）；解码失败/全透明时返回整图。
List<double> alphaBBoxOf(Uint8List bytes) {
  try {
    final im = img.decodeImage(bytes);
    if (im == null) return <double>[0, 0, 1, 1];
    final small = im.width >= im.height
        ? img.copyResize(im, width: math.min(400, im.width))
        : img.copyResize(im, height: math.min(400, im.height));
    var x0 = small.width, y0 = small.height, x1 = -1, y1 = -1;
    for (var y = 0; y < small.height; y++) {
      for (var x = 0; x < small.width; x++) {
        if (small.getPixel(x, y).a > 24) {
          if (x < x0) x0 = x;
          if (x > x1) x1 = x;
          if (y < y0) y0 = y;
          if (y > y1) y1 = y;
        }
      }
    }
    if (x1 < 0 || y1 < 0) return <double>[0, 0, 1, 1];
    final kx = im.width / small.width;
    final ky = im.height / small.height;
    return <double>[x0 * kx, y0 * ky, (x1 + 1) * kx, (y1 + 1) * ky];
  } catch (_) {
    return <double>[0, 0, 1, 1];
  }
}

/// 读图片宽高（isolate 里解码，避免卡 UI）：返回 [w, h]，失败 [0, 0]
List<int> imageSizeOf(Uint8List bytes) {
  try {
    final im = img.decodeImage(bytes);
    if (im == null) return <int>[0, 0];
    return <int>[im.width, im.height];
  } catch (_) {
    return <int>[0, 0];
  }
}

Future<List<int>> imageSizeOfFile(String path) async {
  try {
    final bytes = await File(path).readAsBytes();
    return await compute(imageSizeOf, bytes);
  } catch (_) {
    return <int>[0, 0];
  }
}

/// 屏占比上限（B 方案）—— 上限是"可见外壳在原始壳图里的占比"：
///   1) 外壳可见区（alpha 包围盒）占整图比例：用户说的“手机壳占原图 68%”
///   2) 但不允许画布小于“屏幕 / 可见外壳”，否则外壳会被裁掉
/// 取两者较小值，并限制在 (0, 1]；解码失败时退回旧算法（屏幕 / 整图）。
Future<double> visibleRatioMax({
  required String casePath,
  required int caseWidth,
  required int caseHeight,
  required int screenW,
  required int screenH,
}) async {
  final fallback = math.min(
    1.0,
    math.min(screenW / caseWidth, screenH / caseHeight),
  );
  try {
    final bytes = await File(casePath).readAsBytes();
    final bbox = await compute(alphaBBoxOf, bytes);
    final bw = bbox[2] - bbox[0];
    final bh = bbox[3] - bbox[1];
    if (bw <= 1 || bh <= 1) return fallback;
    final bodyShare = math.min(bw / caseWidth, bh / caseHeight);
    final screenShare = math.min(screenW / bw, screenH / bh);
    final v = math.min(bodyShare, screenShare);
    if (!v.isFinite || v <= 0.05) return fallback;
    return math.min(1.0, v);
  } catch (_) {
    return fallback;
  }
}
