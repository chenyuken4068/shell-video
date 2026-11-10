import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../theme/app_theme.dart';

/// 启动动画：进入 App 时按当前主题（浅色=白底 / 深色=黑底）显示合成台原理图。
/// 关键：底色从**第一帧起就不透明**（否则前几帧会漏出创作页），
/// 只有图片本身淡入+轻微放大；停留一会儿后整层淡出，露出主界面。
class BootSplash extends StatefulWidget {
  const BootSplash({super.key, required this.child});

  final Widget child;

  @override
  State<BootSplash> createState() => _BootSplashState();
}

class _BootSplashState extends State<BootSplash>
    with SingleTickerProviderStateMixin {
  static const Duration _total = Duration(milliseconds: 2800);

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _total,
  )..forward();

  bool _done = false;
  bool _enabled = true;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => _done = true);
    });
    // 设置里「开屏动画」关闭 → 直接跳过动画
    SettingsStore().load().then((s) {
      if (!mounted) return;
      if (!s.bootAnim) {
        setState(() {
          _enabled = false;
          _done = true;
        });
      }
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    final bg = dark ? Colors.black : const Color(0xFFF4F5F7);
    return Stack(
      children: [
        widget.child,
        if (!_done && _enabled)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final t = _c.value;
                  // 0 → 0.34：图片淡入；0.34 → 0.76：停留；0.76 → 1：整层淡出
                  final inT = (t / 0.34).clamp(0.0, 1.0);
                  final outT = ((t - 0.76) / 0.24).clamp(0.0, 1.0);
                  final scale = 0.94 + 0.06 * Curves.easeOutCubic.transform(inT);
                  return Opacity(
                    // 只有这一层淡出；底色始终不透明（第一帧就不漏界面）
                    opacity: (1 - outT).clamp(0.0, 1.0),
                    child: ColoredBox(
                      color: bg,
                      child: Center(
                        child: Opacity(
                          opacity: Curves.easeOut.transform(inT),
                          child: Transform.scale(
                            scale: scale,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 22),
                              child: Image.asset(
                                dark
                                    ? 'assets/splash/dark.png'
                                    : 'assets/splash/light.png',
                                fit: BoxFit.contain,
                                filterQuality: FilterQuality.medium,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
