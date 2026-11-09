import '../theme/app_theme.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/bg_presets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import '../models/shell_template.dart';
import '../services/template_store.dart';
import '../widgets/calibrate_view.dart';
import 'package:image/image.dart' as img;

/// 导入新壳图并标定屏幕区域
class CalibrateScreen extends StatefulWidget {
  final String imagePath;
  final int imageWidth;
  final int imageHeight;
  final ShellTemplate? existing; // 编辑已有模板
  /// true = 保存后 pop 返回 ShellTemplate（透明图流程直接进合成台）
  final bool returnTemplateOnSave;
  /// true = 进入页面后自动触发一次识别（透明图会跳过抠图直接标定）
  final bool autoDetect;
  /// true = 全透明模板（屏幕区域已透明，无需抠图；标定用 透明-黑-透明 逻辑；保存标记 isTransparent）
  final bool transparentMode;

  const CalibrateScreen({
    super.key,
    required this.imagePath,
    required this.imageWidth,
    required this.imageHeight,
    this.existing,
    this.returnTemplateOnSave = false,
    this.autoDetect = false,
    this.transparentMode = false,
  });

  @override
  State<CalibrateScreen> createState() => _CalibrateScreenState();
}

class _CalibrateScreenState extends State<CalibrateScreen> {
  final _store = TemplateStore();
  late CalibrateRect _rect;
  late double _cornerR;
  late final TextEditingController _nameCtrl;
  String? _chromaPath;
  bool _cutting = false; // 抠图进行中
  double _cutProgress = 0; // 抠图进度 0..1
  String? _bgImagePath; // 透明模板可选背景图（保存时融合进模板）

  static const double _minW = 50; // 最小框宽（壳图像素）
  static const double _minH = 100; // 最小框高（壳图像素）

  @override
  void initState() {
    super.initState();
    // 新导入：名字留空，让用户自己命名；编辑已有模板：沿用原名
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    final iw = widget.imageWidth.toDouble();
    final ih = widget.imageHeight.toDouble();
    if (widget.existing != null) {
      final t = widget.existing!;
      _rect = CalibrateRect(
        x: t.screenX.toDouble(),
        y: t.screenY.toDouble(),
        w: t.screenW.toDouble(),
        h: t.screenH.toDouble(),
      );
      _cornerR = t.cornerR.toDouble();
    } else {
      // 初始蓝框：显示约 100×200（壳图像素比例 42.4% × 39.7%），居中
      var w = iw * 0.424;
      var h = ih * 0.397;
      if (h > ih * 0.9) {
        h = ih * 0.9;
        w = h / (ih / iw);
      }
      _rect = CalibrateRect(x: (iw - w) / 2, y: (ih - h) / 2, w: w, h: h);
      _cornerR = w * 0.10;
    }
    // 透明图流程：进入后自动识别（屏幕透明 → 跳过抠图直接标定）
    if (widget.autoDetect) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _autoDetect());
    }
  }

  double get _iw => widget.imageWidth.toDouble();
  double get _ih => widget.imageHeight.toDouble();
  double get _x1 => _rect.x;
  double get _y1 => _rect.y;
  double get _x2 => _rect.x + _rect.w;
  double get _y2 => _rect.y + _rect.h;

  void _setRect({double? x1, double? y1, double? x2, double? y2}) {
    var nx1 = x1 ?? _x1, ny1 = y1 ?? _y1;
    var nx2 = x2 ?? _x2, ny2 = y2 ?? _y2;
    // 约束：宽/高不小于最小值、不出界
    if (nx2 - nx1 < _minW) nx2 = nx1 + _minW;
    if (ny2 - ny1 < _minH) ny2 = ny1 + _minH;
    if (nx1 < 0) { nx2 += -nx1; nx1 = 0; }
    if (ny1 < 0) { ny2 += -ny1; ny1 = 0; }
    if (nx2 > _iw) nx1 -= (nx2 - _iw);
    if (ny2 > _ih) ny1 -= (ny2 - _ih);
    nx1 = nx1.clamp(0, _iw);
    ny1 = ny1.clamp(0, _ih);
    nx2 = nx2.clamp(nx1 + _minW, _iw);
    ny2 = ny2.clamp(ny1 + _minH, _ih);
    setState(() {
      _rect = CalibrateRect(x: nx1, y: ny1, w: nx2 - nx1, h: ny2 - ny1);
    });
  }

  void _setCornerR(double v) {
    setState(() => _cornerR = v.clamp(0, math.min(_iw, _ih) * 0.3));
  }

  OverlayEntry? _tipEntry;

  /// 悬浮提示：白底圆角小卡，自动消失
  void _showFloatingTip(String msg, {bool error = false}) {
    _tipEntry?.remove();
    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 78,
        left: 0,
        right: 0,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .12),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    error ? Icons.error_outline : Icons.check_circle_outline,
                    size: 16,
                    color: error ? const Color(0xFFFF3B30) : const Color(0xFF34C759),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      msg,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    _tipEntry = entry;
    Overlay.of(context).insert(entry);
    Future.delayed(const Duration(seconds: 2), () {
      entry.remove();
      if (_tipEntry == entry) _tipEntry = null;
    });
  }

  /// 抠图阶段进度上报（让出事件循环刷新 UI）
  Future<void> _tickCut(double p) async {
    if (!mounted) return;
    setState(() => _cutProgress = p);
    await Future.delayed(const Duration(milliseconds: 60));
  }

  /// 自动识别：黑框连通域建模 + 摄像头圈识别 + 5点采样颜色抠图 + 标定
  Future<void> _autoDetect() async {
    try {
      if (mounted) {
        setState(() {
          _cutting = true;
          _cutProgress = 0;
        });
      }
      var bytes = await File(widget.imagePath).readAsBytes();
      var raw = img.decodeImage(bytes);
      if (raw == null) {
        if (mounted) setState(() => _cutting = false);
        return;
      }
      final w = raw.width, h = raw.height;
      await _tickCut(0.08);

      // 灰黑判据（仅标定用）：RGB均<60 且 色差<25（深灰黑边也能识别）
      bool isBlack(int x, int y) {
        final p = raw.getPixel(x, y);
        return p.a > 128 && p.r < 60 && p.g < 60 && p.b < 60 &&
            (p.r - p.g).abs() < 25 && (p.g - p.b).abs() < 25;
      }

      // ── 抠图：100% 复刻 cut_screen.py（PS 魔棒/魔术橡皮擦原理）──
      // 只抠「与种子点连通的同色块」：容差45(cheb) + flood + 外扩1px + 羽化0.6
      // 工具：局部中位色 / 局部色差std / cheb距离 / 4邻接连通块
      int sampleColorOf(img.Image im, int x, int y, int r) {
        final xs0 = math.max(0, x - r), xs1 = math.min(im.width, x + r + 1);
        final ys0 = math.max(0, y - r), ys1 = math.min(im.height, y + r + 1);
        final rs = <int>[], gs = <int>[], bs = <int>[];
        for (var yy = ys0; yy < ys1; yy++) {
          for (var xx = xs0; xx < xs1; xx++) {
            final p = im.getPixel(xx, yy);
            rs.add(p.r.toInt()); gs.add(p.g.toInt()); bs.add(p.b.toInt());
          }
        }
        rs.sort(); gs.sort(); bs.sort();
        final mid = rs.length ~/ 2;
        return (rs[mid] << 16) | (gs[mid] << 8) | bs[mid];
      }
      double patchStdOf(img.Image im, int x, int y, int r) {
        final xs0 = math.max(0, x - r), xs1 = math.min(im.width, x + r + 1);
        final ys0 = math.max(0, y - r), ys1 = math.min(im.height, y + r + 1);
        final rs = <int>[], gs = <int>[], bs = <int>[];
        for (var yy = ys0; yy < ys1; yy++) {
          for (var xx = xs0; xx < xs1; xx++) {
            final p = im.getPixel(xx, yy);
            rs.add(p.r.toInt()); gs.add(p.g.toInt()); bs.add(p.b.toInt());
          }
        }
        double sd(List<int> v) {
          if (v.length < 2) return 0.0;
          final m = v.reduce((a, b) => a + b) / v.length;
          var s = 0.0;
          for (final e in v) {
            final d = e - m;
            s += d * d;
          }
          return math.sqrt(s / v.length);
        }
        return math.max(sd(rs), math.max(sd(gs), sd(bs)));
      }
      double chebOf(dynamic p, int rr, int gg, int bb) {
        final dr = (p.r - rr).abs();
        final dg = (p.g - gg).abs();
        final db = (p.b - bb).abs();
        return math.max(dr, math.max(dg, db)).toDouble();
      }
      List<bool> componentAt4(
          img.Image im, List<bool> m, int w2, int h2, int sx, int sy) {
        final out = List<bool>.filled(w2 * h2, false);
        if (!m[sy * w2 + sx]) return out;
        final qx = <int>[], qy = <int>[];
        qx.add(sx); qy.add(sy);
        out[sy * w2 + sx] = true;
        var qi = 0;
        while (qi < qx.length) {
          final cx = qx[qi], cy = qy[qi];
          qi++;
          if (cx > 0 && m[cy * w2 + cx - 1] && !out[cy * w2 + cx - 1]) {
            out[cy * w2 + cx - 1] = true;
            qx.add(cx - 1); qy.add(cy);
          }
          if (cx < w2 - 1 && m[cy * w2 + cx + 1] && !out[cy * w2 + cx + 1]) {
            out[cy * w2 + cx + 1] = true;
            qx.add(cx + 1); qy.add(cy);
          }
          if (cy > 0 && m[(cy - 1) * w2 + cx] && !out[(cy - 1) * w2 + cx]) {
            out[(cy - 1) * w2 + cx] = true;
            qx.add(cx); qy.add(cy - 1);
          }
          if (cy < h2 - 1 && m[(cy + 1) * w2 + cx] && !out[(cy + 1) * w2 + cx]) {
            out[(cy + 1) * w2 + cx] = true;
            qx.add(cx); qy.add(cy + 1);
          }
        }
        return out;
      }

      // ── 屏幕区域透明检测：屏幕已抠成透明（alpha<128 占比≥60%）→ 跳过抠图直接标定 ──
      var trCnt = 0, trTot = 0;
      final trY0 = h ~/ 4, trY1 = h * 3 ~/ 4, trX0 = w ~/ 4, trX1 = w * 3 ~/ 4;
      final trStepY = math.max(1, (trY1 - trY0) ~/ 60);
      final trStepX = math.max(1, (trX1 - trX0) ~/ 60);
      for (var yy = trY0; yy < trY1; yy += trStepY) {
        for (var xx = trX0; xx < trX1; xx += trStepX) {
          if (raw.getPixel(xx, yy).a < 128) trCnt++;
          trTot++;
        }
      }
      final screenTransparent = trTot > 0 && trCnt / trTot >= 0.6;

      const tolC = 45.0;
      if (screenTransparent) {
        await _tickCut(0.5);
        _showFloatingTip('检测到屏幕区域已透明，跳过抠图，直接标定');
      } else {
      // ① 自动找屏幕种子点 + 屏幕色（复刻 find_screen_seed：缩略图网格搜索）
      var sx = w ~/ 2, sy = h ~/ 2;
      var seedRef = sampleColorOf(raw, sx, sy, 8);
      {
        img.Image small = raw;
        var scale = 1.0;
        if (math.max(w, h) > 1200) {
          scale = 1200.0 / math.max(w, h);
          small = img.copyResize(raw,
              width: math.max(1, (w * scale).round()),
              height: math.max(1, (h * scale).round()));
        }
        final sw2 = small.width, sh2 = small.height;
        final minArea = sh2 * sw2 * 0.004;
        final step = math.max(6, math.min(sh2, sw2) ~/ 24);
        final cx4 = sw2 ~/ 2, cy4 = sh2 ~/ 2;
        final cands = <(int, int, double)>[];
        void addCand(int x, int y) {
          final dx = x - cx4, dy = y - cy4;
          cands.add((x, y, (dx * dx + dy * dy).toDouble()));
        }
        addCand(cx4, cy4);
        final yLo = (sh2 * 0.12).round(), yHi = (sh2 * 0.88).round();
        final xLo = (sw2 * 0.12).round(), xHi = (sw2 * 0.88).round();
        for (var y = yLo; y <= yHi; y += step) {
          for (var x = xLo; x <= xHi; x += step) {
            addCand(x, y);
          }
        }
        cands.sort((a, b) => a.$3.compareTo(b.$3));
        var bestScore = -1.0;
        var bestX = cx4, bestY = cy4;
        for (final c in cands) {
          if (patchStdOf(small, c.$1, c.$2, 5) > 12) continue;
          final rref = sampleColorOf(small, c.$1, c.$2, 6);
          final rrefR = (rref >> 16) & 0xFF, rrefG = (rref >> 8) & 0xFF,
              rrefB = rref & 0xFF;
          final smallMask = List<bool>.filled(sw2 * sh2, false);
          for (var yy = 0; yy < sh2; yy++) {
            for (var xx = 0; xx < sw2; xx++) {
              final pp = small.getPixel(xx, yy);
              if (chebOf(pp, rrefR, rrefG, rrefB) <= tolC) {
                smallMask[yy * sw2 + xx] = true;
              }
            }
          }
          if (!smallMask[c.$2 * sw2 + c.$1]) continue;
          final comp = componentAt4(small, smallMask, sw2, sh2, c.$1, c.$2);
          var area = 0, mnx = c.$1, mxx = c.$1, mny = c.$2, mxy = c.$2;
          for (var yy = 0; yy < sh2; yy++) {
            for (var xx = 0; xx < sw2; xx++) {
              if (comp[yy * sw2 + xx]) {
                area++;
                if (xx < mnx) mnx = xx;
                if (xx > mxx) mxx = xx;
                if (yy < mny) mny = yy;
                if (yy > mxy) mxy = yy;
              }
            }
          }
          if (area < minArea) continue;
          final bh = mxy - mny + 1, bw = mxx - mnx + 1;
          final fill = area / (bh * bw);
          final score = fill * math.min(1.0, area / (sh2 * sw2 * 0.25));
          if (bestScore < 0 || score > bestScore) {
            bestScore = score;
            bestX = c.$1;
            bestY = c.$2;
          }
          if (fill > 0.72 && area > sh2 * sw2 * 0.05) break;
        }
        sx = math.min(w - 1, math.max(0, (bestX / scale).round()));
        sy = math.min(h - 1, math.max(0, (bestY / scale).round()));
        seedRef = sampleColorOf(raw, sx, sy, 8);
      }
      final wr2 = (seedRef >> 16) & 0xFF, wg2 = (seedRef >> 8) & 0xFF,
          wb2 = seedRef & 0xFF;
      await _tickCut(0.3);

      // ② 颜色容差选区（cheb≤45）+ flood 连通块（只抠与种子连通的部分）
      final maskFull = List<bool>.filled(w * h, false);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          if (chebOf(raw.getPixel(x, y), wr2, wg2, wb2) <= tolC) {
            maskFull[y * w + x] = true;
          }
        }
      }
      await _tickCut(0.45);
      var regionMask = componentAt4(raw, maskFull, w, h, sx, sy);
      await _tickCut(0.6);
      var count = 0;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          if (regionMask[y * w + x]) count++;
        }
      }

      // ③ 外扩 grow=1（3x3 max 膨胀，吃掉抗锯齿彩边）
      if (count > 0) {
        final grown = List<bool>.filled(w * h, false);
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            if (!regionMask[y * w + x]) continue;
            for (var dy = -1; dy <= 1; dy++) {
              for (var dx = -1; dx <= 1; dx++) {
                final nx = x + dx, ny = y + dy;
                if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
                grown[ny * w + nx] = true;
              }
            }
          }
        }
        regionMask = grown;
        await _tickCut(0.7);
        // ④ 抠除写入 alpha（羽化：高斯模糊 radius 0.6，同 cut_screen feather=0.6）
        final alphaBytes = Uint8List(w * h);
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            alphaBytes[y * w + x] = regionMask[y * w + x] ? 0 : 255;
          }
        }
        final alphaImg = img.Image.fromBytes(
            width: w,
            height: h,
            bytes: alphaBytes.buffer,
            numChannels: 1);
        final blurred = img.gaussianBlur(alphaImg, radius: 1);
        final blurredBytes = Uint8List.view(blurred.getBytes().buffer);
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            final a = blurredBytes[y * w + x];
            if (a < 255) {
              final p = raw.getPixel(x, y);
              raw.setPixelRgba(x, y, p.r, p.g, p.b, a);
            }
          }
        }
        count = 0;
        for (var y = 0; y < h; y++) {
          for (var x = 0; x < w; x++) {
            if (regionMask[y * w + x]) count++;
          }
        }
      }

      await _tickCut(0.85);
      if (count > 0) {
        final outDir = await getTemporaryDirectory();
        final outPath = '${outDir.path}/chroma_${DateTime.now().millisecondsSinceEpoch}.png';
        await File(outPath).writeAsBytes(img.encodePng(raw));
        if (!mounted) return;
        setState(() => _chromaPath = outPath);
        _showFloatingTip('已抠除 $count 像素');
      }

      }
      // ── 标定：屏幕边界 ──
      bool tr(int x, int y) => raw.getPixel(x, y).a < 128;
      final yMid = h ~/ 2;
      final xMid = w ~/ 2;
      int x1 = 0, x2 = w - 1, y1 = 0, y2 = h - 1;
      // 依赖屏幕透明检测：检测到屏幕已透明 → 透明-黑-透明投票；
      // 非透明（如微信保存丢失 alpha 的图）→ 普通抠图后黑边标定
      var voteOk = false;
      if (screenTransparent) {
        final b = _transparentBox(raw, w, h, isBlack);
        if (b.$1 >= 0 && b.$2 >= 0 && b.$3 >= 0 && b.$4 >= 0) {
          x1 = b.$1;
          y1 = b.$2;
          x2 = b.$3;
          y2 = b.$4;
          voteOk = true;
        }
      }
      if (!voteOk) {
      var foundBlack = false;
      for (var x = 0; x < w; x++) {
        if (!foundBlack) {
          if (isBlack(x, yMid)) foundBlack = true;
        } else if (tr(x, yMid)) {
          x1 = x; break;
        }
      }
      foundBlack = false;
      for (var x = w - 1; x >= 0; x--) {
        if (!foundBlack) {
          if (isBlack(x, yMid)) foundBlack = true;
        } else if (tr(x, yMid)) {
          x2 = x; break;
        }
      }
      foundBlack = false;
      for (var y = 0; y < h; y++) {
        if (!foundBlack) {
          if (isBlack(xMid, y)) foundBlack = true;
        } else if (tr(xMid, y)) {
          y1 = y; break;
        }
      }
      foundBlack = false;
      for (var y = h - 1; y >= 0; y--) {
        if (!foundBlack) {
          if (isBlack(xMid, y)) foundBlack = true;
        } else if (tr(xMid, y)) {
          y2 = y; break;
        }
      }
      if (y1 == 0) {
        for (var y = h ~/ 2; y >= 0; y--) {
          if (!tr(xMid, y)) { y1 = y + 1; break; }
        }
      }
      if (y2 == h - 1) {
        for (var y = h ~/ 2; y < h; y++) {
          if (!tr(xMid, y)) { y2 = y - 1; break; }
        }
      }
      if (x1 == 0) {
        for (var x = w ~/ 2; x >= 0; x--) {
          if (!tr(x, yMid)) { x1 = x + 1; break; }
        }
      }
      if (x2 == w - 1) {
        for (var x = w ~/ 2; x < w; x++) {
          if (!tr(x, yMid)) { x2 = x - 1; break; }
        }
      }
      } // 普通标定（voteOk=false 时）

      // R = 25采样点双向拟合（行+列）
      final rList = <double>[];
      for (var i = 0; i < 25; i++) {
        final dy = i * 5;
        final y = y1 + dy;
        if (y >= y2) break;
        var foundBlack = false;
        for (var dx = 0; dx < 300; dx++) {
          final x = x1 + dx;
          if (x >= w) break;
          if (!foundBlack) {
            if (isBlack(x, y)) foundBlack = true;
          } else {
            if (tr(x, y)) {
              final r = dy == 0 ? dx.toDouble()
                  : (dx + dy) + math.sqrt(2 * dx * dy);
              rList.add(r);
              break;
            }
          }
        }
      }
      for (var i = 0; i < 25; i++) {
        final dx = i * 5;
        final x = x1 + dx;
        if (x >= x2) break;
        var foundBlack = false;
        for (var dy = 0; dy < 300; dy++) {
          final y = y1 + dy;
          if (y >= h) break;
          if (!foundBlack) {
            if (isBlack(x, y)) foundBlack = true;
          } else {
            if (tr(x, y)) {
              final r = dx == 0 ? dy.toDouble()
                  : (dx + dy) + math.sqrt(2 * dx * dy);
              rList.add(r);
              break;
            }
          }
        }
      }
      var rGuess = 0;
      if (rList.isNotEmpty) {
        rGuess = (rList.reduce((a, b) => a + b) / rList.length).round();
      }
      if (rGuess < 10) rGuess = ((x2 - x1) * 0.14).round();
      final r = rGuess.clamp(0, 9999);

      if (!mounted) return;
      setState(() {
        _rect = CalibrateRect(
          x: x1.toDouble(),
          y: y1.toDouble(),
          w: (x2 - x1 + 1).toDouble(),
          h: (y2 - y1 + 1).toDouble(),
        );
        _cornerR = r.toDouble();
      });
      if (mounted) {
        setState(() {
          _cutting = false;
          _cutProgress = 1;
        });
      }
      await _tickCut(1);
      _showFloatingTip('屏幕识别成功: x=$x1 y=$y1 w=${x2 - x1 + 1} h=${y2 - y1 + 1} R=$r');
    } catch (e) {
      if (!mounted) return;
      setState(() => _cutting = false);
      _showFloatingTip('识别失败: $e', error: true);
    }
  }

  /// 透明模板标定：逐行/逐列扫描"黑段(≥2px)后第一个透明"= 屏幕边界，多线中位数投票。
  /// 结构假设：壳外透明 → 黑边框 → 屏幕透明（透明-黑-透明，屏幕是最后一段透明）。
  /// 若壳外不透明（普通抠图模板）同样适用（黑段后第一个透明）。
  (int, int, int, int) _transparentBox(
      img.Image raw, int w, int h, bool Function(int, int) isBlack) {
    bool tr(int x, int y) => raw.getPixel(x, y).a < 128;
    // 深灰容忍：黑框反光 / 银边 / 抗锯齿
    bool blackish(int x, int y) {
      final p = raw.getPixel(x, y);
      if (p.a < 200) return false;
      final r = p.r, g = p.g, b = p.b;
      final gray = (r + g + b) / 3;
      return gray < 85 && (r - g).abs() < 40 && (g - b).abs() < 40;
    }

    final minW = w ~/ 4;
    final minH = h ~/ 4;

    int scanLeft(int y) {
      var black = 0;
      for (var x = 0; x < w; x++) {
        if (tr(x, y)) {
          if (black >= 2) return x;
        } else if (isBlack(x, y) || blackish(x, y)) {
          black++;
        } else {
          black = 0;
        }
      }
      return -1;
    }

    int scanRight(int y) {
      var black = 0;
      for (var x = w - 1; x >= 0; x--) {
        if (tr(x, y)) {
          if (black >= 2) return x;
        } else if (isBlack(x, y) || blackish(x, y)) {
          black++;
        } else {
          black = 0;
        }
      }
      return -1;
    }

    int scanTop(int x) {
      var black = 0;
      for (var y = 0; y < h; y++) {
        if (tr(x, y)) {
          if (black >= 2) return y;
        } else if (isBlack(x, y) || blackish(x, y)) {
          black++;
        } else {
          black = 0;
        }
      }
      return -1;
    }

    int scanBottom(int x) {
      var black = 0;
      for (var y = h - 1; y >= 0; y--) {
        if (tr(x, y)) {
          if (black >= 2) return y;
        } else if (isBlack(x, y) || blackish(x, y)) {
          black++;
        } else {
          black = 0;
        }
      }
      return -1;
    }

    int med(List<int> v) {
      if (v.isEmpty) return -1;
      v.sort();
      return v[v.length ~/ 2];
    }

    final xs = <int>[], xe = <int>[], ys = <int>[], ye = <int>[];
    for (var y = h ~/ 8; y < h * 7 ~/ 8; y += 4) {
      final a = scanLeft(y), b = scanRight(y);
      if (a >= 0 && b > a && b - a >= minW) {
        xs.add(a);
        xe.add(b);
      }
    }
    for (var x = w ~/ 8; x < w * 7 ~/ 8; x += 4) {
      final a = scanTop(x), b = scanBottom(x);
      if (a >= 0 && b > a && b - a >= minH) {
        ys.add(a);
        ye.add(b);
      }
    }
    // 全部方向都没有有效投票 → 返回 (-1,-1,-1,-1)，调用方回退普通标定
    if (xs.isEmpty && xe.isEmpty && ys.isEmpty && ye.isEmpty) {
      return (-1, -1, -1, -1);
    }
    var rx1 = med(xs), rx2 = med(xe), ry1 = med(ys), ry2 = med(ye);
    if (rx1 < 0) rx1 = 0;
    if (rx2 < 0) rx2 = w - 1;
    if (ry1 < 0) ry1 = 0;
    if (ry2 < 0) ry2 = h - 1;
    // 兜底尺寸约束
    if (rx2 - rx1 < minW) {
      rx1 = (w - minW) ~/ 2;
      rx2 = rx1 + minW;
    }
    if (ry2 - ry1 < minH) {
      ry1 = (h - minH) ~/ 2;
      ry2 = ry1 + minH;
    }
    rx1 = rx1.clamp(0, w - 1);
    rx2 = rx2.clamp(0, w - 1);
    ry1 = ry1.clamp(0, h - 1);
    ry2 = ry2.clamp(0, h - 1);
    if (rx1 > rx2) {
      final t = rx1;
      rx1 = rx2;
      rx2 = t;
    }
    if (ry1 > ry2) {
      final t = ry1;
      ry1 = ry2;
      ry2 = t;
    }
    return (rx1, ry1, rx2, ry2);
  }



  @override
  Widget build(BuildContext context) {
    final rx1 = _x1.round(), ry1 = _y1.round();
    final rx2 = _x2.round(), ry2 = _y2.round();
    final rr = _cornerR.round();
    final rMax = math.min(_iw, _ih) * 0.3;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          widget.existing != null ? '编辑模板' : '导入并标定',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
          // 预览区（白底 iOS 风格，壳图居中卡片化）
          Expanded(
            child: Container(
              color: AppColors.bg,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.isDark
                          ? Colors.white.withValues(alpha: .10)
                          : const Color(0xFFE4E7EC),
                    ),
                    boxShadow: AppColors.isDark
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: .30),
                              blurRadius: 26,
                              offset: const Offset(0, 10),
                            ),
                          ]
                        : null,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      // 背景图铺满预览卡（在壳图下面）：壳的透明屏幕区与壳外都会透出背景
                      if (_bgImagePath != null)
                        Positioned.fill(
                          child: Image.file(
                            File(_bgImagePath!),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, _, _) => const SizedBox.shrink(),
                          ),
                        ),
                      CalibrateView(
                        imagePath: _chromaPath ?? widget.imagePath,
                        imageWidth: _iw,
                        imageHeight: _ih,
                        rect: _rect,
                        cornerR: _cornerR,
                        onChanged: (r) => setState(() => _rect = r),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // 参数面板（紧凑）
          Container(
            padding: EdgeInsets.fromLTRB(
                16, 8, 16, 10 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(
                  color: AppColors.isDark
                      ? Colors.white.withValues(alpha: .10)
                      : const Color(0xFFE4E7EC),
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '参数设置',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text),
                ),

                // 模板名字卡（左）+ 识别按钮（右）

                Row(

                  children: [

                    Expanded(

                      child: Container(

                        height: 46,

                        padding: const EdgeInsets.symmetric(horizontal: 12),

                        decoration: BoxDecoration(

                          color: AppColors.isDark

                              ? Colors.white.withValues(alpha: .06)

                              : const Color(0xFFF7F8FA),

                          borderRadius: BorderRadius.circular(16),

                          border: Border.all(

                            color: AppColors.isDark

                                ? Colors.white.withValues(alpha: .12)

                                : const Color(0xFFE9ECF1),

                          ),

                        ),

                        child: Row(

                          children: [

                            Icon(Icons.edit_outlined, size: 17, color: AppColors.textSub),

                            const SizedBox(width: 8),

                            Expanded(

                              child: TextField(

                                controller: _nameCtrl,

                                maxLength: 12,

                                style: TextStyle(

                                    fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.text),

                                decoration: InputDecoration(

                                  isDense: true,

                                  counterText: '',

                                  border: InputBorder.none,

                                  hintText: '点击命名模板',

                                  hintStyle: TextStyle(

                                      fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.textFaint),

                                ),

                              ),

                            ),

                          ],

                        ),

                      ),

                    ),

                    const SizedBox(width: 10),

                    // 识别（缩小版）

                    GestureDetector(

                      onTap: _autoDetect,

                      behavior: HitTestBehavior.opaque,

                      child: Container(

                        width: 78,

                        height: 46,

                        decoration: BoxDecoration(

                          borderRadius: BorderRadius.circular(16),

                          gradient: LinearGradient(

                            begin: Alignment.topCenter,

                            end: Alignment.bottomCenter,

                            colors: AppColors.isDark

                                ? [Colors.white.withValues(alpha: .16), Colors.white.withValues(alpha: .08)]

                                : [Colors.white.withValues(alpha: .96), Colors.white.withValues(alpha: .64)],

                          ),

                          border: Border.all(

                            color: Colors.white.withValues(alpha: AppColors.isDark ? .5 : .98),

                            width: 1.5,

                          ),

                          boxShadow: AppColors.isDark

                              ? null

                              : [

                                  BoxShadow(

                                    color: Colors.black.withValues(alpha: .08),

                                    blurRadius: 16,

                                    offset: const Offset(0, 6),

                                  ),

                                ],

                        ),

                        child: Row(

                          mainAxisAlignment: MainAxisAlignment.center,

                          children: [

                            Icon(Icons.auto_fix_high, size: 16, color: AppColors.text),

                            const SizedBox(width: 5),

                            Text('识别',

                                style: TextStyle(

                                    fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text)),

                          ],

                        ),

                      ),

                    ),

                  ],

                ),

                // 透明模板：可选背景图（存进模板预设，下次自动带出；不再烘焙进 PNG）
                if (widget.transparentMode && widget.existing == null) ...[
                  const SizedBox(height: 6),
                  _bgFuseRow(),
                ],
                const SizedBox(height: 4),
                _paramRow(
                  '左上角X', rx1,
                  0, math.max((_x2 - _minW).clamp(0, _iw), 0),
                  (v) => _setRect(x1: v),
                  () => _setRect(x1: _x1 - 1),
                  () => _setRect(x1: _x1 + 1),
                ),
                _paramRow(
                  '左上角Y', ry1,
                  0, math.max((_y2 - _minH).clamp(0, _ih), 0),
                  (v) => _setRect(y1: v),
                  () => _setRect(y1: _y1 - 1),
                  () => _setRect(y1: _y1 + 1),
                ),
                _paramRow(
                  '右下角X', rx2,
                  math.min((_x1 + _minW).clamp(0, _iw), _iw), _iw,
                  (v) => _setRect(x2: v),
                  () => _setRect(x2: _x2 - 1),
                  () => _setRect(x2: _x2 + 1),
                ),
                _paramRow(
                  '右下角Y', ry2,
                  math.min((_y1 + _minH).clamp(0, _ih), _ih), _ih,
                  (v) => _setRect(y2: v),
                  () => _setRect(y2: _y2 - 1),
                  () => _setRect(y2: _y2 + 1),
                ),
                _paramRow(
                  '圆角半径R', rr,
                  0, math.max(rMax, 0),
                  _setCornerR,
                  () => _setCornerR(_cornerR - 1),
                  () => _setCornerR(_cornerR + 1),
                ),
                const SizedBox(height: 8),
                // 模板名称
                Text(
                  '模板名称',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSub),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    hintText: '给这个壳模板起个名字',
                    hintStyle: TextStyle(fontSize: 13, color: AppColors.textFaint),
                    filled: true,
                    fillColor: AppColors.fillSoft,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context, false),
                        child: Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.fillSoft,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text('取消', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSub)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: GestureDetector(
                        onTap: _save,
                        child: Container(
                          height: 50,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.accent, Color(0xFF3FA2FF)],
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: .3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text('保存模板', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
          // 悬浮抠图进度卡（风格同视频合成台圆环）
          if (_cutting)
            Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Center(child: _CutProgressCard(progress: _cutProgress)),
            ),
        ],
      ),
    );
  }

  Widget _paramRow(
    String label, int value,
    double min, double max,
    ValueChanged<double> onSlider,
    VoidCallback onDec, VoidCallback onInc,
  ) {
    var lo = min, hi = max;
    if (hi - lo < 1) hi = lo + 1; // Slider 要求 min<max
    final dark = AppColors.isDark;
    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.text),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 8,
              activeTrackColor: dark ? Colors.white.withValues(alpha: .85) : Colors.white,
              inactiveTrackColor: dark ? Colors.white.withValues(alpha: .14) : const Color(0x14000000),
              thumbColor: Colors.white,
              overlayColor: AppColors.accent.withValues(alpha: .12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            ),
            child: Slider(
              value: value.toDouble().clamp(lo, hi),
              min: lo,
              max: hi,
              onChanged: onSlider,
            ),
          ),
        ),
        const SizedBox(width: 4),
        _stepBtn('-', onDec),
        SizedBox(
          width: 50,
          child: Center(
            child: Text(
              '$value',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.text),
            ),
          ),
        ),
        _stepBtn('+', onInc),
      ],
    );
  }

  /// 透明模板：选择背景图（保存时与外壳融合成模板，屏幕区域保持透明）
  Widget _bgFuseRow() {
    final has = _bgImagePath != null;
    return GestureDetector(
      onTap: () async {
        try {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
            allowMultiple: false,
          );
          if (result == null || result.files.isEmpty) return;
          final path = result.files.single.path;
          if (path == null) return;
          if (!mounted) return;
          setState(() => _bgImagePath = path);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('读取背景图失败: $e')),
          );
        }
      },
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: has ? const Color(0xFFEAF3FF) : AppColors.fillSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: has ? AppColors.accent : Colors.transparent),
        ),
        child: Row(
          children: [
            if (has) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.file(
                  File(_bgImagePath!),
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  // 失败时给可见提示，别静默留白（否则看起来像"没预览"）
                  errorBuilder: (_, _, _) => Container(
                    width: 36,
                    height: 36,
                    color: const Color(0xFFFFE5E5),
                    child: const Icon(Icons.broken_image_outlined,
                        size: 18, color: Color(0xFFFF3B30)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ] else ...[
              Icon(Icons.wallpaper_outlined,
                  size: 17, color: AppColors.textSub),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                has
                    ? p.basename(_bgImagePath!)
                    : '可选：选背景图（存进模板，下次自动带出）',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: has ? AppColors.accent : AppColors.textSub,
                ),
              ),
            ),
            if (has)
              GestureDetector(
                onTap: () => setState(() => _bgImagePath = null),
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: AppColors.textSub),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _stepBtn(String label, VoidCallback onTap) {    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 30,
        decoration: BoxDecoration(
          color: AppColors.fillSoft,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.accent),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final rw = _rect.w.round();
    final rh = _rect.h.round();
    if (rw < 50 || rh < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('屏幕区域过小，请重新框选')),
      );
      return;
    }
    // 名字留空 → 自动用「模板_月日_时分」命名（不再拦截保存）
    var name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      final n = DateTime.now();
      final mm = n.month.toString().padLeft(2, '0');
      final dd = n.day.toString().padLeft(2, '0');
      final hh = n.hour.toString().padLeft(2, '0');
      final mi = n.minute.toString().padLeft(2, '0');
      name = '模板_$mm${dd}_$hh$mi';
    }

    if (widget.existing != null) {
      final t = widget.existing!.copyWith(
        name: name,
        screenX: _rect.x.round(),
        screenY: _rect.y.round(),
        screenW: rw,
        screenH: rh,
        cornerR: _cornerR.round(),
      );
      await _store.updateParams(t);
      if (!mounted) return;
      Navigator.pop(context, widget.returnTemplateOnSave ? t : true);
    } else {
      // 背景不再烘焙进模板 PNG（会把屏幕区域的透明填掉，合成时内容被盖住），
      // 改成写进"背景预设"，下次打开这个模板时合成台自动带出
      final srcImage = _chromaPath ?? widget.imagePath;
      final t = await _store.save(
        name: name,
        srcImage: srcImage,
        caseWidth: widget.imageWidth,
        caseHeight: widget.imageHeight,
        screenX: _rect.x.round(),
        screenY: _rect.y.round(),
        screenW: rw,
        screenH: rh,
        cornerR: _cornerR.round(),
        isTransparent: widget.transparentMode,
      );
      if (widget.transparentMode && _bgImagePath != null) {
        await BgPresetStore.put(t.id, BgPreset(imagePath: _bgImagePath));
      }
      if (!mounted) return;
      Navigator.pop(context, widget.returnTemplateOnSave ? t : true);
    }
  }

}

// ---------- 抠图悬浮进度卡（风格同视频合成台） ----------
class _CutProgressCard extends StatelessWidget {
  final double progress;
  const _CutProgressCard({required this.progress});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CalRing(progress: progress, size: 46, color: AppColors.accent),
          const SizedBox(width: 14),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '正在自动识别屏幕区域',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.text),
              ),
              const SizedBox(height: 3),
              Text(
                '${(progress.clamp(0, 1) * 100).toStringAsFixed(0)}%',
                style: TextStyle(fontSize: 11.5, color: AppColors.textSub),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CalRing extends StatelessWidget {
  final double progress;
  final double size;
  final Color color;

  const _CalRing({required this.progress, required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _CalRingPainter(progress: progress.clamp(0, 1), color: color),
      ),
    );
  }
}

class _CalRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _CalRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..color = AppColors.fill;
    canvas.drawCircle(center, radius, track);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      3.14159 * 2 * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_CalRingPainter old) => old.progress != progress;
}
