import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models/shell_template.dart';

/// 长截图合成器
///
/// 原理（与效果图一致）：
/// 1. 画布宽 = 壳宽 / shellRatio（默认 80%）
/// 2. 内容按屏幕孔宽等比缩放，加屏幕圆角遮罩
/// 3. 壳在「中段边框恒宽、靠下」的位置切开：
///    · 顶部壳 = 0 .. cut
///    · 缺口 = 内容高 - 屏幕高，用「cut 那一横」拉伸补满
///    · 底部壳 = cut .. 壳底（含底部圆角）
/// 4. 背景：纯色，或背景图按画布宽缩放后竖向平铺；
///    bgMirror = true 时交替上下翻转（镜像复制），接缝无痕
class LongshotComposer {
  /// 加载图片为 ui.Image
  static Future<ui.Image> _load(String path) async {
    final bytes = await File(path).readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// 计算布局参数（预览与导出共用）
  static LongshotLayout layout({
    required ShellTemplate template,
    required int contentWidth,
    required int contentHeight,
    double shellRatio = 0.8,
    double topMargin = 90,
    double bottomMargin = 90,
  }) {
    final W = template.caseWidth.toDouble();
    final H = template.caseHeight.toDouble();
    final canvasW = (W / shellRatio).roundToDouble();
    final s = canvasW / W; // 壳绘制缩放
    final screenW = template.screenW * s;
    final screenH = template.screenH * s;
    final contentH = contentHeight * screenW / contentWidth;
    // 切点：中段边框恒宽、靠下（0.84 处，已验证小米14 上下边框同宽）
    final cut = (template.screenY + template.screenH * 0.84) * s;
    final gap = math.max(0.0, contentH - screenH);
    final phoneH = H * s + gap;
    final canvasH = topMargin + phoneH + bottomMargin;
    return LongshotLayout(
      canvasW: canvasW,
      canvasH: canvasH,
      shellScale: s,
      topMargin: topMargin,
      cut: cut,
      gap: gap,
      screenX: template.screenX * s,
      screenY: template.screenY * s,
      screenW: screenW,
      screenH: screenH,
      contentH: contentH,
      cornerR: template.cornerR * s,
      caseW: W,
      caseH: H,
    );
  }

  /// 合成并返回 PNG 字节
  static Future<Uint8List> compose({
    required ShellTemplate template,
    required String contentPath,
    String? bgImagePath,
    int bgColor = 0xFFFFFFFF,
    bool bgMirror = true,
    double shellRatio = 0.8,
    double topMargin = 90,
    double bottomMargin = 90,
  }) async {
    final shell = await _load(template.casePath);
    final content = await _load(contentPath);
    ui.Image? bgImg;
    if (bgImagePath != null && await File(bgImagePath).exists()) {
      bgImg = await _load(bgImagePath);
    }

    final L = layout(
      template: template,
      contentWidth: content.width,
      contentHeight: content.height,
      shellRatio: shellRatio,
      topMargin: topMargin,
      bottomMargin: bottomMargin,
    );

    final w = L.canvasW.ceil();
    final h = L.canvasH.ceil();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // ── ① 背景 ──
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      ui.Paint()..color = ui.Color(bgColor),
    );
    if (bgImg != null) {
      final bw = L.canvasW;
      final bh = bw * bgImg.height / bgImg.width;
      var y = 0.0;
      var i = 0;
      while (y < h) {
        canvas.save();
        if (bgMirror && i.isOdd) {
          // 上下翻转（镜像复制）
          canvas.translate(0, y + bh);
          canvas.scale(1, -1);
          canvas.drawImageRect(
            bgImg,
            ui.Rect.fromLTWH(
                0, 0, bgImg.width.toDouble(), bgImg.height.toDouble()),
            ui.Rect.fromLTWH(0, 0, bw, bh),
            ui.Paint()..filterQuality = ui.FilterQuality.high,
          );
        } else {
          canvas.drawImageRect(
            bgImg,
            ui.Rect.fromLTWH(
                0, 0, bgImg.width.toDouble(), bgImg.height.toDouble()),
            ui.Rect.fromLTWH(0, y, bw, bh),
            ui.Paint()..filterQuality = ui.FilterQuality.high,
          );
        }
        canvas.restore();
        y += bh;
        i++;
      }
    }

    // ── ② 内容（屏幕孔 + 圆角遮罩）──
    final dst = ui.Rect.fromLTWH(
      L.screenX,
      L.topMargin + L.screenY,
      L.screenW,
      L.contentH,
    );
    canvas.save();
    canvas.clipRRect(ui.RRect.fromRectAndRadius(
      dst,
      ui.Radius.circular(L.cornerR),
    ));
    canvas.drawImageRect(
      content,
      ui.Rect.fromLTWH(
          0, 0, content.width.toDouble(), content.height.toDouble()),
      dst,
      ui.Paint()..filterQuality = ui.FilterQuality.high,
    );
    canvas.restore();

    // ── ③ 壳（顶部 / 缺口拉伸 / 底部）──
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.high;
    // 顶部：0 .. cut
    canvas.drawImageRect(
      shell,
      ui.Rect.fromLTWH(0, 0, L.caseW, L.cut / L.shellScale),
      ui.Rect.fromLTWH(0, L.topMargin, L.canvasW, L.cut),
      paint,
    );
    // 缺口：cut 那一横竖向拉伸
    if (L.gap > 0) {
      final bandY = L.cut / L.shellScale;
      canvas.drawImageRect(
        shell,
        ui.Rect.fromLTWH(0, bandY, L.caseW, 1),
        ui.Rect.fromLTWH(0, L.topMargin + L.cut, L.canvasW, L.gap),
        paint,
      );
    }
    // 底部：cut .. 壳底
    canvas.drawImageRect(
      shell,
      ui.Rect.fromLTWH(0, L.cut / L.shellScale, L.caseW,
          L.caseH - L.cut / L.shellScale),
      ui.Rect.fromLTWH(0, L.topMargin + L.cut + L.gap, L.canvasW,
          L.caseH * L.shellScale - L.cut),
      paint,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    picture.dispose();
    image.dispose();
    return data!.buffer.asUint8List();
  }
}

/// 长截图布局参数
class LongshotLayout {
  final double canvasW;
  final double canvasH;
  final double shellScale;
  final double topMargin;
  final double cut;
  final double gap;
  final double screenX;
  final double screenY;
  final double screenW;
  final double screenH;
  final double contentH;
  final double cornerR;
  final double caseW;
  final double caseH;

  const LongshotLayout({
    required this.canvasW,
    required this.canvasH,
    required this.shellScale,
    required this.topMargin,
    required this.cut,
    required this.gap,
    required this.screenX,
    required this.screenY,
    required this.screenW,
    required this.screenH,
    required this.contentH,
    required this.cornerR,
    required this.caseW,
    required this.caseH,
  });
}
