import 'package:flutter/material.dart';

/// 主题色板：深浅两套。
///
/// 用**静态读取**（不需要 context），这样逐页替换硬编码颜色时最省事：
///   `const Color(0xFFF4F5F7)` → `AppColors.bg`
///   `Colors.white`（卡片底色）→ `AppColors.card`
///   `const Color(0xFF8E8E93)`（次要文字）→ `AppColors.textSub`
/// 注意：替换后这些构造就不能再是 `const` 了（分析器会报，删掉 const 即可）。
class AppColors {
  const AppColors._();

  /// 当前是否深色：由设置里的模式（AppTheme.current）驱动；
  /// 「跟随系统」时直接读系统亮度。
  static bool get isDark {
    switch (AppTheme.current) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    }
  }

  // ── 面 ──
  static Color get bg => isDark ? const Color(0xFF0F1115) : const Color(0xFFF4F5F7);
  static Color get card => isDark ? const Color(0xFF1B1E24) : Colors.white;
  static Color get fill => isDark ? const Color(0xFF262A31) : const Color(0xFFECEFF3);
  static Color get fillSoft => isDark ? const Color(0xFF22262C) : const Color(0xFFF2F3F5);

  // ── 文字 ──
  static Color get text => isDark ? const Color(0xFFF2F3F5) : const Color(0xFF1C1D22);
  static Color get textSub => isDark ? const Color(0xFF9AA0A8) : const Color(0xFF8E8E93);
  static Color get textFaint => isDark ? const Color(0xFF6E747C) : const Color(0xFFB0B3B8);

  // ── 线 ──
  static Color get divider => isDark ? const Color(0xFF2A2E35) : const Color(0xFFE5E5EA);
  static Color get dividerSoft => isDark ? const Color(0xFF23272E) : const Color(0xFFEDEEF1);

  // ── 主色（深浅一致）──
  static const Color accent = Color(0xFF0A84FF);
  static const Color onAccent = Colors.white;

  // ── 底栏 ──
  static Color get glassTint => isDark ? const Color(0xFF1C1F26) : Colors.white;
  static Color get navIcon => isDark ? const Color(0xFFF2F3F5) : const Color(0xFF111318);
  static Color get navIconDim => isDark ? const Color(0xFF9AA0A8) : const Color(0xFF70757F);
  static Color get chipOn => isDark ? const Color(0xFF1B1E24) : Colors.white;
}

/// 主题装配：浅色 / 深色两套 + 模式解析
class AppTheme {
  AppTheme._();

  /// 当前模式（main.dart 里由 gThemeMode 驱动写入，供 AppColors 静态读取）
  static ThemeMode current = ThemeMode.light;

  static ThemeMode parse(String s) {
    switch (s) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  static String name(ThemeMode m) {
    switch (m) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.light:
        return 'light';
    }
  }

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness b) {
    final dark = b == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent, brightness: b),
      scaffoldBackgroundColor: dark ? const Color(0xFF0F1115) : const Color(0xFFF4F5F7),
      cardColor: dark ? const Color(0xFF1B1E24) : Colors.white,
      dividerColor: dark ? const Color(0xFF2A2E35) : const Color(0xFFE5E5EA),
      fontFamilyFallback: const ['PingFang SC', 'Microsoft YaHei'],
      // 开关统一主色蓝（原 M3 默认是紫色）
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.accent
                : (dark ? const Color(0xFF3A3F47) : const Color(0xFFE5E5EA))),
        thumbColor: const WidgetStatePropertyAll(Colors.white),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.accent,
        inactiveTrackColor: dark ? const Color(0xFF3A3F47) : const Color(0xFFE5E5EA),
        thumbColor: Colors.white,
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.accent),
    );
  }
}

/// 柔光玻璃卡渐变（跟随深浅色主题）
LinearGradient glassCardGradient() => LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: AppColors.isDark
          ? const [Color(0xFF23272F), Color(0xFF1B1F26)]
          : const [Color(0xFFFFFFFF), Color(0xFFF7F9FD)],
    );

/// 玻璃卡高光边（跟随深浅色主题）
Color glassCardBorder() =>
    AppColors.isDark ? const Color(0x24FFFFFF) : const Color(0xFFFFFFFF);
