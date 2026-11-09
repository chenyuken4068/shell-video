import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// 「液态玻璃」悬浮底栏
///
/// 主体是**片元着色器**（assets/shaders/liquid_glass.frag）：
///   逐像素 SDF → 边缘弧面法线 → **只在弧面带内**把背板往里折射（水滴放在桌面上的观感）
///   + 弧面高光；通透（frost=0）时**完全不模糊**，只有极淡染色。
/// 尺寸对齐「柔光玻璃」：底栏 64 / 胶囊常态 56 / 切换时弹到 70（盖过底栏）后再缩回。
/// 着色器不可用时自动退回"通透 + 边缘高光"版本。
class SdfGlassNavBar extends StatefulWidget {
  const SdfGlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.height = 64,
    this.radius = 32,
    this.opacity = 0.02,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<SdfNavItem> items;
  final double height;
  final double radius;

  /// 通透 ↔ 实：0.02 = 通透（无模糊）/ 0.30 = 实（毛玻璃）
  final double opacity;

  @override
  State<SdfGlassNavBar> createState() => _SdfGlassNavBarState();
}

class SdfNavItem {
  const SdfNavItem({required this.icon, required this.activeIcon, required this.label});
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _Pill {
  const _Pill(this.left, this.width, this.height);
  final double left, width, height;

  _Pill lerpTo(_Pill other, double t) => _Pill(
        left + (other.left - left) * t,
        width + (other.width - width) * t,
        height + (other.height - height) * t,
      );
}

class _PillTween extends Tween<_Pill> {
  _PillTween({super.begin, super.end});

  @override
  _Pill lerp(double t) => begin!.lerpTo(end!, t);
}

class _SdfGlassNavBarState extends State<SdfGlassNavBar>
    with SingleTickerProviderStateMixin {
  Offset? _touch;
  double? _dragLeft;
  double _stretch = 0;
  double _vStretch = 0;
  double _lastDx = 0;
  int _lastTickIndex = -1;
  int _pressed = -1;
  /// 着色器折射版暂不启用（坐标问题待真机调试）；false = 稳定的高光环版
  static const bool _useShader = false;
  ui.FragmentShader? _shader;
  final GlobalKey _barKey = GlobalKey();
  Offset? _originPx; // 底栏左上角在屏幕上的物理像素位置

  late final AnimationController _ripple = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  /// 胶囊切换时弹高：56 → 70（柔光玻璃的 +14），落位后缩回
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),        // 同柔光玻璃 _holdDuration
    reverseDuration: const Duration(milliseconds: 140), // 同包的回落时长
  );

  static const double _pad = 4; // 底栏 64 - 胶囊 56 => 上下各 4
  static const double _popK = 70 / 56 - 1; // 弹高比例
  static const Duration _settle = Duration(milliseconds: 550);
  static const double _maxStretch = 18;

  @override
  @override
  void initState() {
    super.initState();
    if (_useShader) _loadShader();
  }

  Future<void> _loadShader() async {
    try {
      final program =
          await ui.FragmentProgram.fromAsset('assets/shaders/liquid_glass.frag');
      final shader = program.fragmentShader();
      if (!mounted) return;
      setState(() => _shader = shader);
    } catch (e) {
      debugPrint('液态玻璃着色器加载失败，退回高光版: $e');
    }
  }

  @override
  void dispose() {
    _ripple.dispose();
    _pop.dispose();
    super.dispose();
  }

  void _popPill() {
    _pop.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 640), () {
      if (mounted) _pop.reverse();
    });
  }


  void _updateOrigin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _barKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) return;
      final dpr = View.of(context).devicePixelRatio;
      final g = box.localToGlobal(Offset.zero);
      final px = Offset(g.dx * dpr, g.dy * dpr);
      if (_originPx == null || (_originPx! - px).distance > 0.5) {
        setState(() => _originPx = px);
      }
    });
  }

  void _releasePress() {
    Future.delayed(const Duration(milliseconds: 130), () {
      if (mounted) setState(() => _pressed = -1);
    });
  }

  void _setUniforms(Size size,
      double pillLeft, double pillTop, double pillW, double pillH) {
    final s = _shader;
    if (s == null) return;
    final dpr = View.of(context).devicePixelRatio;
    final frost = ((widget.opacity - 0.02) / 0.28).clamp(0.0, 1.0);
    final tint = 0.04 + 0.10 * frost;
    final o = _originPx ?? Offset.zero;
    final screen = MediaQuery.sizeOf(context);
    s
      ..setFloat(0, widget.radius * dpr)
      ..setFloat(1, pillLeft * dpr)
      ..setFloat(2, pillTop * dpr)
      ..setFloat(3, pillW * dpr)
      ..setFloat(4, pillH * dpr)
      ..setFloat(5, pillH / 2 * dpr)
      ..setFloat(6, 18.0 * dpr)
      ..setFloat(7, 1.6)
      ..setFloat(8, frost)
      ..setFloat(9, tint)
      ..setFloat(10, AppColors.isDark ? 1.0 : 0.0)
      ..setFloat(11, 1.8 * dpr)
      ..setFloat(12, 0.55)
      ..setFloat(13, size.width * dpr)
      ..setFloat(14, size.height * dpr)
      ..setFloat(15, o.dx)
      ..setFloat(16, o.dy)
      ..setFloat(17, screen.width * dpr)
      ..setFloat(18, screen.height * dpr);
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.items.length;
    final dark = AppColors.isDark;
    _updateOrigin();
    return LayoutBuilder(builder: (context, cons) {
      final w = cons.maxWidth;
      final iw = (w - _pad * 2) / n;
      final baseW = iw;
      final maxLeft = _pad + (n - 1) * iw;
      final targetLeft = _pad + widget.currentIndex * iw;
      double clampLeft(double x) => x.clamp(_pad, maxLeft);

      final dragging = _dragLeft != null;
      final pillLeft0 = (_dragLeft ?? targetLeft) - _stretch / 2;
      final pillW0 = baseW + _stretch;
      final baseH = widget.height - _pad * 2;
      final geom = _Pill(pillLeft0, pillW0, baseH + _vStretch);

      return SizedBox(
        key: _barKey,
        height: widget.height,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) {
            final i = ((d.localPosition.dx - _pad) / iw).floor().clamp(0, n - 1);
            HapticFeedback.selectionClick();
            _ripple.forward(from: 0);
            setState(() {
              _pressed = i;
              _touch = d.localPosition;
            });
          },
          onTapUp: (d) {
            final i = ((d.localPosition.dx - _pad) / iw).floor().clamp(0, n - 1);
            widget.onTap(i);
            _popPill();
            _releasePress();
          },
          onTapCancel: () => setState(() => _pressed = -1),
          onHorizontalDragStart: (d) {
            HapticFeedback.selectionClick();
            _lastTickIndex = widget.currentIndex;
            _lastDx = d.localPosition.dx;
            setState(() {
              _pressed = -1;
              _dragLeft = clampLeft(d.localPosition.dx - baseW / 2);
              _stretch = 0;
              _vStretch = 0;
              _touch = d.localPosition;
            });
          },
          onHorizontalDragUpdate: (d) {
            final next = ((d.localPosition.dx - _pad) / iw).round().clamp(0, n - 1);
            if (next != _lastTickIndex) {
              _lastTickIndex = next;
              HapticFeedback.selectionClick();
            }
            final v = d.localPosition.dx - _lastDx;
            _lastDx = d.localPosition.dx;
            final stretch = (_stretch + v * 0.85).clamp(-_maxStretch, _maxStretch);
            final vStretch = (v.abs() * 1.6).clamp(0.0, _maxStretch);
            setState(() {
              _dragLeft = clampLeft(d.localPosition.dx - baseW / 2);
              _stretch = stretch;
              _vStretch = vStretch;
              _touch = d.localPosition;
            });
          },
          onHorizontalDragEnd: (_) {
            final left = (_dragLeft ?? targetLeft) + _stretch / 2;
            final i = ((left - _pad) / iw).round().clamp(0, n - 1);
            _lastTickIndex = -1;
            HapticFeedback.selectionClick();
            setState(() {
              _dragLeft = null;
              _stretch = 0;
              _vStretch = 0;
            });
            if (i != widget.currentIndex) widget.onTap(i);
            _popPill();
          },
          onHorizontalDragCancel: () => setState(() {
            _dragLeft = null;
            _stretch = 0;
            _vStretch = 0;
            _lastTickIndex = -1;
          }),
          child: TweenAnimationBuilder<_Pill>(
            tween: _PillTween(begin: geom, end: geom),
            duration: dragging ? Duration.zero : _settle,
            curve: dragging ? Curves.linear : Curves.easeOutBack,
            builder: (context, animated, _) {
              return AnimatedBuilder(
                animation: Listenable.merge(<Listenable>[_ripple, _pop]),
                builder: (context, _) {
                  // 弹高：高度放大、上下居中（只变高，不变宽）
                  final popK = 1 + _popK * Curves.easeOutBack.transform(_pop.value);
                  final ph = baseH * popK;
                  final pt = _pad + baseH / 2 - ph / 2;
                  final size = Size(w, widget.height);
                  _setUniforms(size, animated.left, pt, animated.width, ph);

                  return Stack(children: [
                    // ① 着色器玻璃（折射+高光）；失败则退回通透+高光
                    if (_useShader && _shader != null)
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(widget.radius),
                          child: BackdropFilter(
                            filter: ui.ImageFilter.shader(_shader!),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      )
                    else
                      // 稳定版：完全通透，不模糊、不染色（背景原样透出）
                      const SizedBox.shrink(),
                    // ② 兜底/点击涟漪层（着色器生效时只画涟漪）
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _SdfGlassPainter(
                          radius: widget.radius,
                          pillLeft: animated.left,
                          pillTop: pt,
                          pillW: animated.width,
                          pillH: ph,
                          pillRadius: ph / 2,
                          dark: dark,
                          touch: _touch,
                          ripple: _ripple.value,
                          drawGlass: _shader == null,
                        ),
                      ),
                    ),
                    // ③ 图标 + 文字
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: _pad),
                        child: Row(
                          children: [
                            for (var i = 0; i < n; i++)
                              Expanded(
                                child: AnimatedScale(
                                  scale: i == _pressed ? 0.92 : 1.0,
                                  duration: const Duration(milliseconds: 130),
                                  curve: Curves.easeOut,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        i == widget.currentIndex
                                            ? widget.items[i].activeIcon
                                            : widget.items[i].icon,
                                        size: 22,
                                        color: i == widget.currentIndex
                                            ? AppColors.navIcon
                                            : AppColors.navIconDim,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        widget.items[i].label,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: i == widget.currentIndex
                                              ? FontWeight.w800
                                              : FontWeight.w500,
                                          color: i == widget.currentIndex
                                              ? AppColors.navIcon
                                              : AppColors.navIconDim,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ]);
                },
              );
            },
          ),
        ),
      );
    });
  }
}

class _SdfGlassPainter extends CustomPainter {
  _SdfGlassPainter({
    required this.radius,
    required this.pillLeft,
    required this.pillTop,
    required this.pillW,
    required this.pillH,
    required this.pillRadius,
    required this.dark,
    required this.touch,
    required this.ripple,
    required this.drawGlass,
  });

  final double radius;
  final double pillLeft, pillTop, pillW, pillH, pillRadius;
  final bool dark;
  final Offset? touch;
  final double ripple;

  /// 是否绘制玻璃本体（着色器生效时由着色器画，这里只画点击涟漪）
  final bool drawGlass;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final barRR = RRect.fromRectAndRadius(
      Rect.fromLTWH(1.0, 1.0, w - 2.0, h - 2.0),
      Radius.circular(radius - 1.0),
    );

    // ① 外圈一圈高光：外侧柔光 + 内侧细亮线（左上更亮，全周都有）
    canvas.drawRRect(
      barRR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..color = Colors.white.withValues(alpha: dark ? 0.10 : 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0),
    );
    final ringRect = Rect.fromLTWH(1.0, 1.0, w - 2.0, h - 2.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(ringRect, Radius.circular(radius - 1.0)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: dark ? 0.62 : 0.85),
            Colors.white.withValues(alpha: dark ? 0.20 : 0.32),
            Colors.white.withValues(alpha: dark ? 0.38 : 0.55),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(ringRect),
    );

    // ② 胶囊：淡填充 + 自己的一圈高光描边
    final pillRect = Rect.fromLTWH(pillLeft, pillTop, pillW, pillH);
    final pillRR = RRect.fromRectAndRadius(pillRect, Radius.circular(pillRadius));
    canvas.drawRRect(
      pillRR,
      Paint()..color = Colors.white.withValues(alpha: dark ? 0.055 : 0.16),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pillRect.deflate(0.8), Radius.circular(pillRadius - 0.8)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: dark ? 0.55 : 0.80),
            Colors.white.withValues(alpha: dark ? 0.18 : 0.30),
          ],
        ).createShader(pillRect),
    );

    // ③ 点击涟漪（保持原样）
    final to = touch;
    if (to != null && ripple > 0 && ripple < 1) {
      final fade = 1 - ripple;
      canvas.drawCircle(
        to,
        26,
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.white.withValues(alpha: 0.12 * fade),
            Colors.white.withValues(alpha: 0.0),
          ]).createShader(Rect.fromCircle(center: to, radius: 26)),
      );
      final rad = 22 + 26 * ripple;
      canvas.drawCircle(
        to,
        rad,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = Colors.white.withValues(alpha: 0.16 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  @override
  bool shouldRepaint(_SdfGlassPainter old) =>
      old.pillLeft != pillLeft ||
      old.pillW != pillW ||
      old.pillH != pillH ||
      old.dark != dark ||
      old.touch != touch ||
      old.ripple != ripple ||
      old.drawGlass != drawGlass;
}
