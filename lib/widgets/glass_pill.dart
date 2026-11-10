import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 柔光玻璃胶囊（与主界面底部悬浮栏**完全一致**的质感）
///
/// 材质配方：
///   · 背景：白色 86%（深色：白 10%）
///   · 模糊：BackdropFilter blur 22
///   · 描边：1.5px 白色 96%
///   · 投影：0 10 30 / 黑 10%
///   · 圆角：默认 32（胶囊）
///
/// 用途：图库批量操作条、模板库分组底栏、导入浮层等所有悬浮栏，
/// 保证全 App 悬浮元素质感统一。
class GlassPill extends StatelessWidget {
  final Widget child;

  /// 圆角（默认 32 = 胶囊）
  final double radius;

  /// 高度（为 null 时由 child 决定）
  final double? height;

  /// 外边距
  final EdgeInsetsGeometry? margin;

  /// 内边距
  final EdgeInsetsGeometry? padding;

  /// 是否启用模糊（部分场景可关掉以省性能）
  final bool blur;

  const GlassPill({
    super.key,
    required this.child,
    this.radius = 32,
    this.height,
    this.margin,
    this.padding,
    this.blur = true,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    final bg = dark
        ? const Color(0xFF12131A).withValues(alpha: .78)
        : Colors.white.withValues(alpha: .86);
    final border = dark
        ? Colors.white.withValues(alpha: .16)
        : Colors.white.withValues(alpha: .96);

    Widget inner = Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? .34 : .10),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );

    if (blur) {
      inner = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: inner,
        ),
      );
    }

    if (margin != null) {
      inner = Padding(padding: margin!, child: inner);
    }
    return inner;
  }
}
