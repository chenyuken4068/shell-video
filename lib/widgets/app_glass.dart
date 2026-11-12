import 'package:flutter/material.dart';
import 'package:flutter_liquid_glass_kit/flutter_liquid_glass_kit.dart';

import '../theme/app_theme.dart';
import 'main_shell.dart' show gNavGlassOpacity;

/// 全 App 统一的「柔光玻璃」容器 —— 与主界面底部悬浮栏**同一个方法**：
///
/// 主界面底栏是 `LiquidGlassNavBar(settings: matteLight/matteDark.copyWith(...))`
/// 本组件让它内部的 `LiquidGlassCard` 用**完全相同的 settings**，
/// 因此材质、高光、描边、阴影、折射都和主底栏一模一样（不再是手写模拟）。
///
/// 用于：模板库分组底栏 / 模板库导入按钮 / 模板库「其他」弹卡 /
///      图库批量操作条 / 图库预览操作栏 等所有悬浮元素。
class AppGlass extends StatelessWidget {
  final Widget child;

  /// 圆角（底栏用 32，卡片用 20~24）
  final double radius;

  /// 固定高度（null = 由 child 决定）
  final double? height;

  /// 固定宽度
  final double? width;

  /// 内边距
  final EdgeInsetsGeometry padding;

  /// 外边距
  final EdgeInsetsGeometry margin;

  const AppGlass({
    super.key,
    required this.child,
    this.radius = 32,
    this.height,
    this.width,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
  });

  /// 与主界面底栏完全一致的玻璃参数
  static LiquidGlassSettings settingsFor(bool dark) {
    final base = dark
        ? LiquidGlassSettings.matteDark
        : LiquidGlassSettings.matteLight;
    return base.copyWith(
      tintOpacity: 0.03 + gNavGlassOpacity.value * 0.85,
      blurSigma: 8 + gNavGlassOpacity.value * 45,
      borderOpacity: 0.55,
      borderWidth: 1.5,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppColors.isDark;
    return LiquidGlassCard(
      settings: settingsFor(dark),
      borderRadius: BorderRadius.circular(radius),
      width: width,
      height: height,
      padding: padding,
      margin: margin,
      child: child,
    );
  }
}
