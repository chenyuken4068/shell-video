import '../services/app_settings.dart';
import '../theme/app_theme.dart';

import 'package:file_picker/file_picker.dart';

import 'dart:io';

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';



import '../services/export_store.dart';

import '../services/image_utils.dart';

import '../widgets/main_shell.dart' show gTab;

import 'bg_library_screen.dart';

import 'calibrate_screen.dart';

import 'library_screen.dart';

import 'tpl_library_screen.dart';
import '../widgets/live_badge.dart';



/// 创作页：顶栏（标题+分隔线）+ 操作卡

class HomeScreen extends StatefulWidget {

  const HomeScreen({super.key});



  @override

  State<HomeScreen> createState() => _HomeScreenState();

}



class _HomeScreenState extends State<HomeScreen> {

  final _recentStore = ExportStore();
  List<ExportItem> _recent = [];

  @override
  void initState() {
    gHomeOrder.addListener(_onHomeSortChanged);
    gHomeHidden.addListener(_onHomeSortChanged);
    super.initState();
    gTab.addListener(_onTab);
    _loadRecent();
  }

  @override
  void dispose() {
    gHomeOrder.removeListener(_onHomeSortChanged);
    gHomeHidden.removeListener(_onHomeSortChanged);
    gTab.removeListener(_onTab);
    super.dispose();
  }

  // 切回「创作」时刷新最近作品（IndexedStack 会保活，需要手动刷新）
  void _onTab() {
    if (gTab.value == 0) _loadRecent();
  }


  /// 动图测试：把内置的 Motion Photo 样本存进相册（验证「动态照片」角标）


  Future<void> _loadRecent() async {
    final list = await _recentStore.load();
    if (!mounted) return;
    setState(() => _recent = list.take(6).toList());
  }






  /// 最近作品缩略图：同名 .jpg 存在就用图，否则用渐变占位；点击去图库
  Widget _recentThumb(ExportItem item) {
    final thumb = File(item.path.replaceAll(RegExp(r'\.mp4$'), '.jpg'));
    return GestureDetector(
      onTap: () {
        if (item.type == 'image') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ImageViewerScreen(path: item.path, name: item.name),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(path: item.path, name: item.name),
            ),
          );
        }
      },
      behavior: HitTestBehavior.opaque,
      child: AspectRatio(
        aspectRatio: 1.35,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumb.existsSync())
                Image.file(thumb, fit: BoxFit.cover, gaplessPlayback: true)
              else
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF3A4250), Color(0xFF23272F)],
                    ),
                  ),
                ),
              if (item.durLabel.isNotEmpty)
                Positioned(
                  right: 5,
                  bottom: 5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .45),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      item.durLabel,
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 柔光玻璃卡片（固定观感，不跟随设置透明度）
  Widget _homeCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: AppColors.isDark
              ? [Colors.white.withValues(alpha: .10), Colors.white.withValues(alpha: .05)]
              : [Colors.white.withValues(alpha: .95), Colors.white.withValues(alpha: .78)],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: AppColors.isDark ? .34 : .9),
          width: 1.4,
        ),
        // 浅色主题不要阴影（避免卡片下出现灰底）
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
      child: child,
    );
  }

  Widget _cardTitle(String text, {String? action, VoidCallback? onAction}) {
    return Row(
      children: [
        Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        const Spacer(),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSub),
            ),
          ),
      ],
    );
  }

  Widget _bigTile({
    IconData? icon,
    Widget? iconWidget,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 94,
        decoration: BoxDecoration(
          color: AppColors.isDark ? Colors.white.withValues(alpha: .05) : Colors.black.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withValues(alpha: AppColors.isDark ? .13 : .7),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget ??
                Icon(icon, size: 22, color: AppColors.text.withValues(alpha: .85)),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _linkRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool big = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: big ? 52 : 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.isDark ? Colors.white.withValues(alpha: .05) : Colors.black.withValues(alpha: .04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: AppColors.isDark ? .12 : .7),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: big ? 24 : 18, color: AppColors.text.withValues(alpha: .82)),
            SizedBox(width: big ? 12 : 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: big ? 15 : 13.5, fontWeight: big ? FontWeight.w800 : FontWeight.w700),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }

  Future<void> _addTemplate() async {

    try {

      final result = await FilePicker.platform.pickFiles(

        type: FileType.custom,

        allowedExtensions: ['png', 'jpg', 'jpeg'],

        allowMultiple: false,

      );

      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;

      if (path == null) return;

      final (w, h) = await imageSize(path);

      if (!mounted) return;

      final saved = await Navigator.push<bool>(

        context,

        MaterialPageRoute(

          builder: (_) => CalibrateScreen(

            imagePath: path,

            imageWidth: w,

            imageHeight: h,

          ),

        ),

      );

      if (saved == true && mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('新壳模板已添加')),

        );

      }

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text('导入失败: $e')),

      );

    }

  }



  void _openLibrary([String? brand, bool imageMode = false, bool liveMode = false]) {

    Navigator.push(

      context,

      MaterialPageRoute(

        builder: (_) => TplLibraryScreen(
            initialBrand: brand,
            imageMode: imageMode,
            liveMode: liveMode,
          ),

      ),

    );

  }



  /// 添加新壳 · 透明：选透明 PNG → 透明模式标定（自动识别 透明-黑-透明，可带背景图融合）

  Future<void> _addTransparentTemplate() async {

    try {

      final result = await FilePicker.platform.pickFiles(

        type: FileType.custom,

        allowedExtensions: ['png', 'jpg', 'jpeg'],

        allowMultiple: false,

      );

      if (result == null || result.files.isEmpty) return;

      final path = result.files.single.path;

      if (path == null) return;

      final (w, h) = await imageSize(path);

      if (!mounted) return;

      final saved = await Navigator.push<bool>(

        context,

        MaterialPageRoute(

          builder: (_) => CalibrateScreen(

            imagePath: path,

            imageWidth: w,

            imageHeight: h,

            transparentMode: true,

            autoDetect: true,

          ),

        ),

      );

      if (saved == true && mounted) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(content: Text('透明模板已添加')),

        );

      }

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text('导入失败: $e')),

      );

    }

  }



  /// 模板库管理：打开模板库（全部模板，自制可长按删除）

  void _openTemplateManager() {

    Navigator.push(

      context,

      MaterialPageRoute(

        builder: (_) => const TplLibraryScreen(manageMode: true),

      ),

    );

  }



  @override


  Widget _card_create() {
    return _homeCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _cardTitle('开始创作'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _bigTile(
                                  icon: Icons.movie_outlined,
                                  label: '视频创作',
                                  onTap: () => _openLibrary(null, false),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _bigTile(
                                  icon: Icons.image_outlined,
                                  label: '图片创作',
                                  onTap: () => _openLibrary(null, true),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _bigTile(
                                  iconWidget: LiveBadge(
                                    size: 22,
                                    color: AppColors.text
                                        .withValues(alpha: .85),
                                  ),
                                  label: '实况创作',
                                  onTap: () => _openLibrary(null, false, true),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
  }

  Widget _card_newShell() {
    return _homeCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _cardTitle('添加新壳'),
                          const SizedBox(height: 12),
                          _linkRow(
                            icon: Icons.add_box_outlined,
                            label: '导入抠图模板',
                            onTap: _addTemplate,
                          ),
                          const SizedBox(height: 10),
                          _linkRow(
                            icon: Icons.layers_clear_outlined,
                            label: '导入透明模板',
                            onTap: _addTransparentTemplate,
                          ),
                        ],
                      ),
                    );
  }

  Widget _card_tplLib() {
    return _homeCard(
                      child: _linkRow(
                        icon: Icons.grid_view_outlined,
                        label: '模板库',
                        big: true,
                        onTap: _openTemplateManager,
                      ),
                    );
  }

  Widget _card_bgLib() {
    return _homeCard(
                        child: _linkRow(
                          icon: Icons.wallpaper_outlined,
                          label: '背景库',
                          big: true,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const BgLibraryScreen()),
                          ),
                        ),
                      );
  }

  Widget _card_recent() {
    return _homeCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _cardTitle('最近作品', action: '全部 ›', onAction: () => gTab.value = 1),
                          const SizedBox(height: 10),
                          if (_recent.isEmpty)
                            Text(
                              '还没有作品',
                              style: TextStyle(fontSize: 12, color: AppColors.textFaint),
                            )
                          else
                            GridView.count(
                              crossAxisCount: 3,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 1.3,
                              children: [
                                for (final it in _recent) _recentThumb(it),
                              ],
                            ),
                        ],
                      ),
                    );
  }

  /// 按「创作页排序」设置渲染卡片（隐藏的不渲染，自动补 14px 间距）
  void _onHomeSortChanged() {
    if (mounted) setState(() {});
  }

  List<Widget> _homeCards() {
    final order = gHomeOrder.value.isEmpty ? kDefaultHomeOrder : gHomeOrder.value;
    final hidden = gHomeHidden.value;
    final map = <String, Widget>{
      'create': _card_create(),
      'newShell': _card_newShell(),
      'tplLib': _card_tplLib(),
      'bgLib': _card_bgLib(),
      'recent': _card_recent(),
    };
    final out = <Widget>[];
    for (final k in order) {
      if (hidden.contains(k) || map[k] == null) continue;
      if (out.isNotEmpty) out.add(const SizedBox(height: 14));
      out.add(map[k]!);
    }
    return out;
  }

  Widget build(BuildContext context) {

    return Stack(
      children: [

        // 操作卡（可滚动）

        Positioned(

          top: 0,

          left: 14,

          right: 14,

          bottom: 0,

          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, 100, 0, 140),

            child: Column(

              children: [
                // 卡 A：开始创作（视频 / 图片）
                                ..._homeCards(),

                const SizedBox(height: 14),
                
              ],

            ),

          ),

        ),
// 标题（顶栏统一 y=40）

        // 顶栏渐变模糊（只影响视觉，不拦点击）
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 100,
          child: IgnorePointer(
            child: ClipRect(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black,
                    Colors.black,
                    Color(0x8C000000),
                    Color(0x00000000),
                  ],
                  stops: [0.0, 0.70, 0.88, 1.0],
                ).createShader(rect),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.bg.withValues(alpha: .98),
                          AppColors.bg.withValues(alpha: .92),
                          AppColors.bg.withValues(alpha: .55),
                          AppColors.bg.withValues(alpha: 0),
                        ],
                        stops: const [0.0, 0.62, 0.84, 1.0],
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
        Positioned(

          top: 40,

          left: 20,

          child: Text(

            '创作',

            style: TextStyle(

              fontSize: 26,

              fontWeight: FontWeight.w800,

              color: AppColors.text,

            ),

          ),

        ),

      ],

    );

  }

}






/// 操作行卡：全宽横条，图标圆钮 + 标题 + 副标题 + 箭头


