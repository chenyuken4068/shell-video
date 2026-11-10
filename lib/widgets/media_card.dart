import 'live_badge.dart';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/export_store.dart';
import '../theme/app_theme.dart';

/// 图库媒体卡（两列网格用）
/// · 只显示画面（不显示文件名 / 时间 / 分辨率）
/// · 右下角一个下载按钮：点一下 → 转圈 → 绿勾（勾有描边绘制动画）→ 恢复
/// · 底部浮出「已保存到相册」玻璃胶囊
class MediaCard extends StatefulWidget {
  final ExportItem item;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Future<bool> Function() onSave;

  /// 批量选择模式（长按进入）：显示右上角勾选圈
  final bool selectMode;

  /// 当前是否被选中（selectMode 时生效）
  final bool selected;

  const MediaCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onLongPress,
    required this.onSave,
    this.selectMode = false,
    this.selected = false,
  });

  @override
  State<MediaCard> createState() => _MediaCardState();
}

class _MediaCardState extends State<MediaCard> {
  static const _idle = 0;
  static const _loading = 1;
  static const _done = 2;
  static const _error = 3;

  int _state = _idle;
  bool _toastShowing = false;

  Future<void> _save() async {
    if (_state == _loading) return;
    HapticFeedback.selectionClick();
    setState(() => _state = _loading);
    var ok = false;
    try {
      ok = await widget.onSave();
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() => _state = ok ? _done : _error);
    if (ok) HapticFeedback.lightImpact();
    _showToast(ok);
    await Future<void>.delayed(Duration(milliseconds: ok ? 1300 : 1000));
    if (!mounted) return;
    setState(() => _state = _idle);
  }

  void _showToast(bool ok) {
    if (_toastShowing) return;
    _toastShowing = true;
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => SaveToast(
        ok: ok,
        onDone: () {
          entry.remove();
          _toastShowing = false;
        },
      ),
    );
    overlay.insert(entry);
  }

  Widget _thumb() {
    final thumbPath = widget.item.path.replaceAll(RegExp(r'\.mp4$'), '.jpg');
    final f = File(thumbPath);
    if (f.existsSync()) {
      return Image.file(f, fit: BoxFit.cover, gaplessPlayback: true);
    }
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3A4250), Color(0xFF23272F)],
        ),
      ),
      child: const Icon(Icons.video_library_outlined, size: 22, color: Colors.white70),
    );
  }

  /// 左下角类型徽标：与右下保存钮同款 30px 圆卡，图标对应用「开始创作」里的类型图标
  /// 图片 = image_outlined（图片创作）· 视频 = movie_outlined（视频创作）· 实况 = 外环虚线 LiveBadge
  Widget _typeBadge() {
    final dark = AppColors.isDark;
    final ty = widget.item.type;
    final pth = widget.item.path.toLowerCase();
    // 优先按文件扩展名判定（最可靠）：
    //   *_live.jpg / *.live.jpg = 实况照片（动态照片）
    //   .mp4 / .mov / .m4v      = 视频
    //   其余                    = 图片（含长截图）
    final isMotion = pth.endsWith('_live.jpg') ||
        pth.endsWith('.live.jpg') ||
        ty == 'motion' ||
        ty == 'live';
    final isVideo = !isMotion &&
        (pth.endsWith('.mp4') ||
            pth.endsWith('.mov') ||
            pth.endsWith('.m4v') ||
            pth.endsWith('.gif') ||
            ty == 'video');
    final isImg = !isMotion && !isVideo;
    final bg = dark
        ? Colors.white.withValues(alpha: .16)
        : Colors.white.withValues(alpha: .88);
    final fg = dark ? Colors.white : const Color(0xFF5A6478);
    return IgnorePointer(
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: bg,
          border: Border.all(
            color: dark
                ? Colors.white.withValues(alpha: .22)
                : const Color(0x11000000),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .14),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isMotion
            ? LiveBadge(size: 16, color: fg)
            : Icon(
                isImg ? Icons.image_outlined : Icons.movie_outlined,
                size: 16,
                color: fg,
              ),
      ),
    );
  }

  Widget _saveButton() {
    final dark = AppColors.isDark;
    final idleBg = dark ? Colors.white.withValues(alpha: .18) : Colors.white.withValues(alpha: .92);
    final idleFg = dark ? Colors.white : const Color(0xFF1F2328);

    return GestureDetector(
      onTap: _save,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _state == _done
              ? const Color(0xFF22A06B)
              : _state == _error
                  ? const Color(0xFFE5484D)
                  : idleBg,
          border: Border.all(
            color: dark ? Colors.white.withValues(alpha: .22) : const Color(0x11000000),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .14),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: _state == _loading
            ? SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.8,
                  valueColor: AlwaysStoppedAnimation(dark ? Colors.white : const Color(0xFF7A828D)),
                ),
              )
            : _state == _done
                ? TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 420),
                    curve: Curves.easeOutCubic,
                    builder: (_, t, _) => CustomPaint(
                      size: const Size(16, 16),
                      painter: _CheckPainter(t),
                    ),
                  )
                : _state == _error
                    ? const Icon(Icons.priority_high_rounded, size: 16, color: Colors.white)
                    : Icon(Icons.download_rounded, size: 16, color: idleFg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.item.type != 'image';
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: AppColors.isDark ? Colors.white.withValues(alpha: .08) : const Color(0xFFE2E5EA),
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _thumb(),
              // （批量选择只保留右上角打勾，不再画蓝色外圈）
              // 左下角：类型徽标（与右下保存钮同款圆卡）
              Positioned(left: 8, bottom: 8, child: _typeBadge()),
              // 批量模式：右上角勾选圈（选中=蓝底白勾 / 未选=半透明灰圈）
              if (widget.selectMode)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.selected
                          ? AppColors.accent
                          : Colors.black.withValues(alpha: .26),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: widget.selected
                        ? const Icon(Icons.check,
                            size: 14, color: Colors.white)
                        : null,
                  ),
                ),
              if (!widget.selectMode)
                Positioned(right: 8, bottom: 8, child: _saveButton()),
            ],
          ),
        ),
      ),
    );
  }
}

/// 勾的描边绘制动画
class _CheckPainter extends CustomPainter {
  final double t;

  _CheckPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w * 0.22, h * 0.53)
      ..lineTo(w * 0.42, h * 0.72)
      ..lineTo(w * 0.78, h * 0.30);
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * t), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CheckPainter oldDelegate) => oldDelegate.t != t;
}

/// 保存成功/失败的浮动提示（玻璃胶囊，2 秒自动消失）
class SaveToast extends StatefulWidget {
  final bool ok;
  final VoidCallback onDone;

  const SaveToast({super.key, required this.ok, required this.onDone});

  @override
  State<SaveToast> createState() => _SaveToastState();
}

class _SaveToastState extends State<SaveToast> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final okColor = const Color(0xFF22A06B);
    final dark = AppColors.isDark;
    return Positioned(
      left: 0,
      right: 0,
      bottom: bottom + 96,
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            builder: (_, t, child) => Opacity(
              opacity: t.clamp(0.0, 1.0),
              child: Transform.translate(offset: Offset(0, (1 - t) * 10), child: child),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: dark ? const Color(0xE61B1E24) : const Color(0xF2FFFFFF),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: dark ? Colors.white.withValues(alpha: .12) : const Color(0x12000000),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: dark ? .35 : .12),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: widget.ok ? okColor : const Color(0xFFE5484D),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            widget.ok ? Icons.check_rounded : Icons.close_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.ok ? '已保存到相册' : '保存失败，请检查相册权限',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
