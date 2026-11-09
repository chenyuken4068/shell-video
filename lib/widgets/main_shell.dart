import '../theme/app_theme.dart';
import 'dart:io';

import 'package:flutter/material.dart';

import 'sdf_glass_nav.dart';
import 'package:flutter_liquid_glass_kit/flutter_liquid_glass_kit.dart';
import 'package:path_provider/path_provider.dart';

import '../screens/home_screen.dart';
import '../screens/library_screen.dart';
import '../screens/me_screen.dart';

/// 全局当前 Tab（合成完成"打开图库"等跨页跳转用）
final ValueNotifier<int> gTab = ValueNotifier<int>(0);

/// 主框架：创作 / 图库 / 我的 三 Tab + 液态玻璃悬浮底栏（flutter_liquid_glass_kit）
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

/// 底栏玻璃效果（设置页可切换，即时生效）：matte = 柔光玻璃 / liquid = 液态玻璃
final ValueNotifier<String> gNavGlass = ValueNotifier<String>('matte');

/// 液态玻璃通透度（越小越透，0.02 ~ 0.30），设置页可调，即时生效
final ValueNotifier<double> gNavGlassOpacity = ValueNotifier<double>(0.11);

/// 模板库分组顺序（空 = 内置默认顺序）
final ValueNotifier<List<String>> gTplGroups =
    ValueNotifier<List<String>>(const []);

/// 模板库被隐藏的分组
final ValueNotifier<List<String>> gTplHidden =
    ValueNotifier<List<String>>(const []);

/// 主题模式：浅色 / 深色 / 跟随系统（设置页可切换，即时生效）
final ValueNotifier<ThemeMode> gThemeMode = ValueNotifier<ThemeMode>(ThemeMode.light);

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    gTab.addListener(_onGlobalTab);
    _checkFirstLaunch();
  }

  /// 首次启动（或升级后）弹一次更新日志
  Future<void> _checkFirstLaunch() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final mark = File('${docs.path}/shell_video_app/changelog_3.2.0.txt');
      if (await mark.exists()) return;
      await mark.create(recursive: true);
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('新版本 3.2.0'),
          content: const SingleChildScrollView(
            child: Text(
              '【3.0.0 新功能】\n'
              '· 预览区固定：下方控件（方向按钮等）随滚动上滑，预览不再被操作区遮挡\n'
              '· 新增透明模板标定体系\n'
              '· 新增背景系统：透明模板可叠加背景导出，也可单独导出背景\n'
              '· 新增背景画布比例：9:16、3:4、1:√2 等尺寸\n'
              '· 新增生成屏占比：可调节手机壳图尺寸大小\n'
              '· 新增导出帧率：24/30/48/60/90/120 可选\n\n'
              '【3.1.0 优化】\n'
              '· 优化 App 稳定性，提升流畅度\n'
              '· 优化 Tab 栏玻璃效果，新增柔光玻璃和液态玻璃效果，可在我的页面切换\n'
              '· 模型库合入更多机型模板（该服务由坐忘流年支持）\n\n'
              '【致谢】\n'
              '感谢酷安大佬「坐忘流年」的 Bug 反馈与创意支持！',
              style: TextStyle(fontSize: 13.5, height: 1.5),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了')),
          ],
        ),
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    gTab.removeListener(_onGlobalTab);
    super.dispose();
  }

  void _onGlobalTab() {
    if (mounted && gTab.value != _tab) {
      setState(() => _tab = gTab.value);
    }
  }

  void _switchTo(int i) {
    gTab.value = i;
    if (mounted) setState(() => _tab = i);
  }

  static const _tabs = [
    (label: '创作', icon: Icons.add_box_outlined, iconOn: Icons.add_box),
    (label: '图库', icon: Icons.video_library_outlined, iconOn: Icons.video_library),
    (label: '我的', icon: Icons.person_outline, iconOn: Icons.person),
  ];

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: Listenable.merge(
            <Listenable>[gNavGlass, gNavGlassOpacity, gThemeMode]),
        builder: (context, _) => _build(context),
      );

  Widget _build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // 页面内容（IndexedStack 保留各页状态）
          IndexedStack(
            index: _tab,
            // 按主题模式带 key：切深浅色时强制重建这三页，
            // 否则 AppColors 是静态色板、widget 又完全相同，Flutter 会跳过重建 → 卡片/标题保持旧色
            children: [
              HomeScreen(key: ValueKey('home-${gThemeMode.value.name}')),
              LibraryScreen(key: ValueKey('lib-${gThemeMode.value.name}')),
              MeScreen(key: ValueKey('me-${gThemeMode.value.name}')),
            ],
          ),
          // 液态玻璃悬浮底栏（flutter_liquid_glass_kit 组件：
          // Android 使用 matte-glass 渲染 = 磨砂模糊 + 高光边框 + 半透明染色 + 分层阴影）
          if (gNavGlass.value == 'liquid')
            Positioned(
              left: 20,
              right: 20,
              bottom: 16 + MediaQuery.paddingOf(context).bottom,
              child: SdfGlassNavBar(
                opacity: gNavGlassOpacity.value,
                currentIndex: _tab,
                onTap: _switchTo,
                items: const [
                  SdfNavItem(
                      icon: Icons.add_box_outlined,
                      activeIcon: Icons.add_box,
                      label: '创作'),
                  SdfNavItem(
                      icon: Icons.video_library_outlined,
                      activeIcon: Icons.video_library,
                      label: '图库'),
                  SdfNavItem(
                      icon: Icons.person_outline,
                      activeIcon: Icons.person,
                      label: '我的'),
                ],
              ),
            )
          else
            LiquidGlassFloatingNavBar(
            child: LiquidGlassNavBar(
              // 底色：纯白 + 模糊（原来走包的自适应 tint = 近白偏灰 0xFFF8F8FA）
              // 柔光玻璃：透明度（通透 ↔ 实）+ 外圈高光描边
              settings: (AppColors.isDark
                      ? LiquidGlassSettings.matteDark
                      : LiquidGlassSettings.matteLight)
                  .copyWith(
                tintOpacity: 0.03 + gNavGlassOpacity.value * 0.85, // 通透 0.03 → 实 0.28
                blurSigma: 8 + gNavGlassOpacity.value * 45,
                borderOpacity: 0.55, // 高光描边
                borderWidth: 1.5,
              ),
              currentIndex: _tab,
              onTap: _switchTo,
              // Android 指示器动画：弹性缩放跟随
              androidAnimationStyle: LiquidGlassNavBarAnimationStyle.elastic,
              // 配色：选中 = 墨黑，未选中 = 灰黑（纯黑白，不带主题蓝）
              activeColor: AppColors.navIcon,
              inactiveColor: AppColors.navIconDim,
              items: [
                LiquidGlassNavItem(
                  icon: Icon(Icons.add_box_outlined, color: AppColors.navIconDim),
                  activeIcon: Icon(Icons.add_box, color: AppColors.navIcon),
                  label: '创作',
                ),
                LiquidGlassNavItem(
                  icon: Icon(Icons.video_library_outlined, color: AppColors.navIconDim),
                  activeIcon: Icon(Icons.video_library, color: AppColors.navIcon),
                  label: '图库',
                ),
                LiquidGlassNavItem(
                  icon: Icon(Icons.person_outline, color: AppColors.navIconDim),
                  activeIcon: Icon(Icons.person, color: AppColors.navIcon),
                  label: '我的',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
