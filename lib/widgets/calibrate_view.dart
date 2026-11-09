import 'dart:io';

import 'package:flutter/material.dart';

/// 标定结果（单位：图片像素坐标）
class CalibrateRect {
  double x, y, w, h; // 左上角 x/y、宽/高（图片像素）
  CalibrateRect({required this.x, required this.y, required this.w, required this.h});
}

/// 壳图上的可拖拽屏幕区域矩形（拖四角缩放、框内移动）
class CalibrateView extends StatefulWidget {
  final String imagePath; // 壳图文件路径
  final double imageWidth; // 图片像素宽
  final double imageHeight; // 图片像素高
  final CalibrateRect rect;
  final double cornerR; // 圆角半径（图片像素）
  final ValueChanged<CalibrateRect> onChanged;
  final Color rectColor;

  const CalibrateView({
    super.key,
    required this.imagePath,
    required this.imageWidth,
    required this.imageHeight,
    required this.rect,
    required this.onChanged,
    this.cornerR = 0,
    this.rectColor = const Color(0xFF2962FF),
  });

  @override
  State<CalibrateView> createState() => _CalibrateViewState();
}

class _CalibrateViewState extends State<CalibrateView> {
  static const _handleSize = 18.0;
  _HitRegion _hit = _HitRegion.none;
  Offset _dragStart = Offset.zero;
  CalibrateRect _startRect = CalibrateRect(x: 0, y: 0, w: 1, h: 1);
  double _scale = 1.0; // 显示缩放 = 显示宽 / 图片像素宽

  @override
  Widget build(BuildContext context) {
    final aspect = widget.imageWidth / widget.imageHeight;
    return LayoutBuilder(builder: (context, constraints) {
      final maxW = constraints.maxWidth;
      final maxH = constraints.maxHeight;
      // 按图片比例适配显示区域
      var dw = maxW;
      var dh = dw / aspect;
      if (dh > maxH) {
        dh = maxH;
        dw = dh * aspect;
      }
      _scale = dw / widget.imageWidth;

      return Center(
        child: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: (_) => _hit = _HitRegion.none,
          child: SizedBox(
            width: dw,
            height: dh,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.file(
                    File(widget.imagePath),
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: _RectPainter(
                      rect: widget.rect,
                      scale: _scale,
                      cornerR: widget.cornerR,
                      color: widget.rectColor,
                      handleSize: _handleSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  void _onPanStart(DragStartDetails d) {
    final rect = widget.rect;
    final x = d.localPosition.dx / _scale;
    final y = d.localPosition.dy / _scale;
    _dragStart = Offset(x, y);
    _startRect = CalibrateRect(x: rect.x, y: rect.y, w: rect.w, h: rect.h);
    _hit = _hitTest(x, y);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_hit == _HitRegion.none) return;
    final dx = d.localPosition.dx / _scale - _dragStart.dx;
    final dy = d.localPosition.dy / _scale - _dragStart.dy;
    final r = _startRect;
    var x = r.x, y = r.y, w = r.w, h = r.h;
    final iw = widget.imageWidth;
    final ih = widget.imageHeight;
    const minW = 50.0;
    const minH = 100.0;

    switch (_hit) {
      case _HitRegion.move:
        x = (r.x + dx).clamp(0.0, iw - r.w);
        y = (r.y + dy).clamp(0.0, ih - r.h);
        break;
      case _HitRegion.tl:
        x = (r.x + dx).clamp(0.0, r.x + r.w - minW);
        y = (r.y + dy).clamp(0.0, r.y + r.h - minH);
        w = r.w + (r.x - x);
        h = r.h + (r.y - y);
        break;
      case _HitRegion.tr:
        x = r.x;
        y = (r.y + dy).clamp(0.0, r.y + r.h - minH);
        w = (r.w + dx).clamp(minW, iw - r.x);
        h = r.h + (r.y - y);
        break;
      case _HitRegion.bl:
        x = (r.x + dx).clamp(0.0, r.x + r.w - minW);
        y = r.y;
        w = r.w + (r.x - x);
        h = (r.h + dy).clamp(minH, ih - r.y);
        break;
      case _HitRegion.br:
        x = r.x;
        y = r.y;
        w = (r.w + dx).clamp(minW, iw - r.x);
        h = (r.h + dy).clamp(minH, ih - r.y);
        break;
      case _HitRegion.left:
        x = (r.x + dx).clamp(0.0, r.x + r.w - minW);
        w = r.w + (r.x - x);
        break;
      case _HitRegion.right:
        x = r.x;
        w = (r.w + dx).clamp(minW, iw - r.x);
        break;
      case _HitRegion.top:
        y = (r.y + dy).clamp(0.0, r.y + r.h - minH);
        h = r.h + (r.y - y);
        break;
      case _HitRegion.bottom:
        y = r.y;
        h = (r.h + dy).clamp(minH, ih - r.y);
        break;
      case _HitRegion.none:
        return;
    }

    widget.onChanged(CalibrateRect(x: x, y: y, w: w, h: h));
  }

  _HitRegion _hitTest(double x, double y) {
    final r = widget.rect;
    const tol = 24.0; // 手柄命中容差（图片坐标）
    final nearTL = (x - r.x).abs() < tol && (y - r.y).abs() < tol;
    final nearTR = (x - (r.x + r.w)).abs() < tol && (y - r.y).abs() < tol;
    final nearBL = (x - r.x).abs() < tol && (y - (r.y + r.h)).abs() < tol;
    final nearBR = (x - (r.x + r.w)).abs() < tol && (y - (r.y + r.h)).abs() < tol;
    if (nearTL) return _HitRegion.tl;
    if (nearTR) return _HitRegion.tr;
    if (nearBL) return _HitRegion.bl;
    if (nearBR) return _HitRegion.br;
    if ((x - r.x).abs() < tol && y > r.y && y < r.y + r.h) return _HitRegion.left;
    if ((x - (r.x + r.w)).abs() < tol && y > r.y && y < r.y + r.h) return _HitRegion.right;
    if ((y - r.y).abs() < tol && x > r.x && x < r.x + r.w) return _HitRegion.top;
    if ((y - (r.y + r.h)).abs() < tol && x > r.x && x < r.x + r.w) return _HitRegion.bottom;
    if (x > r.x && x < r.x + r.w && y > r.y && y < r.y + r.h) return _HitRegion.move;
    return _HitRegion.none;
  }
}

enum _HitRegion { none, move, tl, tr, bl, br, left, right, top, bottom }

class _RectPainter extends CustomPainter {
  final CalibrateRect rect;
  final double scale; // 像素 → 显示
  final double cornerR;
  final Color color;
  final double handleSize;

  _RectPainter({
    required this.rect,
    required this.scale,
    required this.cornerR,
    required this.color,
    required this.handleSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(
      rect.x * scale,
      rect.y * scale,
      rect.w * scale,
      rect.h * scale,
    );
    final rrect = RRect.fromRectAndRadius(r, Radius.circular(cornerR * scale));

    // 外圈遮罩（屏幕外压暗）
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.35));

    // 屏幕边框
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    canvas.drawRRect(rrect, border);

    // 框内中心十字
    final cx = r.center.dx, cy = r.center.dy;
    final cross = Paint()
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.55);
    canvas.drawLine(Offset(r.left, cy), Offset(r.right, cy), cross);
    canvas.drawLine(Offset(cx, r.top), Offset(cx, r.bottom), cross);

    // 高亮描边
    final hl = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.8);
    canvas.drawRRect(rrect, hl);
  }

  @override
  bool shouldRepaint(covariant _RectPainter old) =>
      old.rect.x != rect.x || old.rect.y != rect.y ||
      old.rect.w != rect.w || old.rect.h != rect.h ||
      old.scale != scale || old.cornerR != cornerR;
}
