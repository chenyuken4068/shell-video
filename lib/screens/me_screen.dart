import 'update_screen.dart';
import '../services/export_store.dart';

import '../services/app_log.dart';

import '../theme/app_theme.dart';

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import 'package:package_info_plus/package_info_plus.dart';



import '../services/app_settings.dart';

import '../services/composer.dart';

import '../services/template_store.dart';

import '../widgets/glass_preview_tile.dart';

import '../widgets/main_shell.dart'
    show gTplHidden, gTab, gNavGlass, gNavGlassOpacity, gThemeMode;

import 'tpl_library_screen.dart';



/// 我的页：资料卡 + 设置列表

class MeScreen extends StatefulWidget {

  const MeScreen({super.key});



  @override

  State<MeScreen> createState() => _MeScreenState();

}



class _MeScreenState extends State<MeScreen> {

  AppSettings _settings = AppSettings();

  String _version = '--'; // 真实安装包版本（随 app 更新）

  int _tplCount = 0; // 已导入模板数（真实数量）

  int _tplTransparent = 0; // 其中透明模板数

  int _workCount = 0; // 作品数（图库）

  Future<void> _loadWorkCount() async {
    final list = await ExportStore().load();
    if (!mounted) return;
    setState(() => _workCount = list.length);
  }




  @override

  void initState() {

    super.initState();
    _loadWorkCount();

    SettingsStore().load().then((s) {

      if (mounted) setState(() => _settings = s);

    });

    PackageInfo.fromPlatform().then((pi) {

      if (mounted) setState(() => _version = pi.version);

    });

    _loadTplCount();

    // 「我的」页在 IndexedStack 里不会重建，切回来时刷新模板数量

    gTab.addListener(_onTabChanged);

  }



  @override

  void dispose() {

    gTab.removeListener(_onTabChanged);

    super.dispose();

  }



  void _onTabChanged() {

    if (gTab.value == 2) _loadTplCount(); // 2 = 我的

  }



  Future<void> _loadTplCount() async {

    try {

      final list = await TemplateStore().load();

      if (!mounted) return;

      setState(() {

        _tplCount = list.length;

        _tplTransparent = list.where((t) => t.isTransparent).length;

      });

    } catch (_) {/* 读不到就保持 0 */}

  }



  Future<void> _editSettings() async {

    final result = await showModalBottomSheet<AppSettings>(

      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (_) => _SettingsSheet(initial: _settings),

    );

    if (result == null) return;

    await SettingsStore().save(result);

    if (!mounted) return;

    setState(() => _settings = result);

  }



  /// 通用设置：底栏玻璃效果（含通透度 + 玻璃参考块）/ 背景模式

  /// 打开「设置」二级页面
  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _SettingsScreen(initial: _settings),
      ),
    ).then((v) async {
      if (v is AppSettings && mounted) {
        setState(() => _settings = v);
      }
    });
  }

  Future<void> _editGeneral() async {

    final result = await showModalBottomSheet<AppSettings>(

      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (_) => _GeneralSheet(initial: _settings),

    );

    if (result == null) return;

    // 即时生效

    gNavGlass.value = result.navGlass;

    gNavGlassOpacity.value = result.navGlassOpacity;
    gThemeMode.value = AppTheme.parse(result.themeMode);

    await SettingsStore().save(result);

    if (!mounted) return;

    setState(() => _settings = result);

  }



  void _showChangelog() {

    showDialog(

      context: context,

      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFCFDFF),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

        title: Text('版本更新 · $_version'),

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

          TextButton(onPressed: () => Navigator.pop(context), child: const Text('好的')),

        ],

      ),

    );

  }



  void _showHelp() {

    showDialog(

      context: context,

      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFFCFDFF),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),

        title: const Text('帮助与说明'),

        content: const SingleChildScrollView(

          child: Text(

            '壳映用于给视频套上手机壳边框：\n\n'

            '1. 在「创作」页选择模板或导入新壳图；\n'

            '2. 选择本地视频，自动识别分辨率（4K/1080P/720P）；\n'

            '3. 实时预览合成效果，导出带壳视频或截图；\n'

            '4. 导出文件自动保存到本地存储，可在「图库」查看。\n\n'

            '支持最长 30 分钟视频，硬件加速优先、失败自动回退软件编码。',

            style: TextStyle(fontSize: 13.5, height: 1.5),

          ),

        ),

        actions: [

          TextButton(onPressed: () => Navigator.pop(context), child: const Text('好的')),

        ],

      ),

    );

  }



  /// 创作者卡片：头像左 + 名字/职责右（两位创作者）
  Widget _creatorCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('创作者',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          _creatorRow(
            asset: 'assets/creators/dev.png',
            name: '酷安@真不叫地主',
            role: '开发者',
          ),
          Divider(height: 1, color: AppColors.divider),
          _creatorRow(
            asset: 'assets/creators/tpl.png',
            name: '酷安@SOCMTK9300',
            role: '模板库提供',
          ),
        ],
      ),
    );
  }

  Widget _creatorRow({
    required String asset,
    required String name,
    required String role,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          // 头像
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.divider),
              image: DecorationImage(
                image: AssetImage(asset),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 14),
          // 名字 + 职责
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(role,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSub)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10.5, color: AppColors.textSub)),
        ],
      ),
    );
  }

  @override

  Widget build(BuildContext context) {

    return Stack(
      children: [
        

        Positioned(

          top: 0,

          left: 14,

          right: 14,

          bottom: 96,

          child: ListView(

            padding: const EdgeInsets.only(top: 98),

            physics: const AlwaysScrollableScrollPhysics(),

            children: [

              // 资料卡

              Container(

                padding: const EdgeInsets.all(16),

                decoration: BoxDecoration(

                  color: AppColors.card,

                  borderRadius: BorderRadius.circular(18),

                  boxShadow: [

                    BoxShadow(

                      color: Colors.black.withValues(alpha: .04),

                      blurRadius: 12,

                      offset: const Offset(0, 4),

                    ),

                  ],

                ),

                child: Column(

                  children: [

                    Row(

                  children: [

                    Container(

                      width: 46,

                      height: 46,

                      decoration: BoxDecoration(

                        gradient: const LinearGradient(

                          begin: Alignment.topLeft,

                          end: Alignment.bottomRight,

                          colors: [AppColors.accent, Color(0xFF3FA2FF)],

                        ),

                        borderRadius: BorderRadius.circular(14),

                      ),

                      child: const Icon(Icons.smartphone, color: Colors.white, size: 24),

                    ),

                    const SizedBox(width: 14),

                    Column(

                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        const Text(

                          '壳映',

                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),

                        ),

                      ],

                    ),

                  ],

                ),

                    const SizedBox(height: 16),

                    Container(

                      padding: const EdgeInsets.only(top: 14),

                      decoration: BoxDecoration(

                        border: Border(

                          top: BorderSide(color: AppColors.divider, width: 1),

                        ),

                      ),

                      child: Row(

                        children: [

                          _statTile('$_workCount', '作品'),

                          _statTile('${_tplCount - _tplTransparent}', '抠图模板'),

                          _statTile('$_tplTransparent', '透明模板'),

                        ],

                      ),

                    ),

                  ],

                ),

              ),

              const SizedBox(height: 16),

              // ── 创作者卡片（第一张卡与分组列表之间）──
              _creatorCard(),
              const SizedBox(height: 16),

              // iOS 分组列表

              Container(

                decoration: BoxDecoration(

                  color: AppColors.card,

                  borderRadius: BorderRadius.circular(18),

                  boxShadow: [

                    BoxShadow(

                      color: Colors.black.withValues(alpha: .04),

                      blurRadius: 12,

                      offset: const Offset(0, 4),

                    ),

                  ],

                ),

                child: Column(

                  children: [

                    _ListRow(

                      icon: Icons.grid_view_outlined,

                      title: '模板管理',

                      subtitle: _tplCount == 0

                          ? '暂无模板，去创作页添加'

                          : '$_tplCount 款模板 · 透明 $_tplTransparent',

                      onTap: () => Navigator.push(

                        context,

                        MaterialPageRoute(builder: (_) => const TplLibraryScreen()),

                      ),

                    ),

                    _divider(),


                    _ListRow(

                      icon: Icons.settings_outlined,

                      title: '设置',

                      subtitle: '导出 · 排序 · 外观',

                      onTap: _openSettings,

                    ),


                    _divider(),


                    _ListRow(

                      icon: Icons.help_outline,

                      title: '帮助与说明',

                      subtitle: '',

                      onTap: _showHelp,

                    ),

                    _divider(),

                    _ListRow(
                      icon: Icons.bug_report_outlined,
                      title: '日志抓取',
                      subtitle: '导出运行日志 txt',
                      onTap: () => AppLog.exportAndShare(context),
                    ),

                    _divider(),

                    _ListRow(

                      icon: Icons.update_outlined,

                      title: '版本更新',

                      subtitle: _version,

                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const UpdateScreen()),
                      ),

                    ),

                  ],

                ),

              ),

            ],

          ),

        ),
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

            '我的',

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



  Widget _divider() => Divider(

        height: 1,

        indent: 52,

        endIndent: 0,

        color: AppColors.dividerSoft,

      );

}



class _ListRow extends StatelessWidget {

  final IconData icon;

  final String title;

  final String subtitle;

  final VoidCallback onTap;



  const _ListRow({

    required this.icon,

    required this.title,

    required this.subtitle,

    required this.onTap,

  });



  @override

  Widget build(BuildContext context) {

    return InkWell(

      onTap: onTap,

      child: Padding(

        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),

        child: Row(

          children: [

            Container(

              width: 30,

              height: 30,

              decoration: BoxDecoration(

                color: AppColors.accent.withValues(alpha: .1),

                borderRadius: BorderRadius.circular(8),

              ),

              child: Icon(icon, size: 17, color: AppColors.accent),

            ),

            const SizedBox(width: 12),

            Expanded(

              child: Text(

                title,

                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),

              ),

            ),

            Text(

              subtitle,

              style: TextStyle(fontSize: 12, color: AppColors.textSub),

            ),

            const SizedBox(width: 4),

            Icon(Icons.chevron_right, size: 18, color: AppColors.textSub),

          ],

        ),

      ),

    );

  }

}



/// 默认导出设置弹层

class _SettingsSheet extends StatefulWidget {

  final AppSettings initial;



  const _SettingsSheet({required this.initial});



  @override

  State<_SettingsSheet> createState() => _SettingsSheetState();

}



class _SettingsSheetState extends State<_SettingsSheet> {

  late Quality _quality = widget.initial.quality;

  late bool _hardware = widget.initial.hardware;

  late int _fps = widget.initial.fps;

  late bool _autoSaveBg = widget.initial.autoSaveBg;

  /// 改动即生效 + 立刻写盘（已去掉取消/保存按钮）
  Future<void> _apply() async {
    await SettingsStore().save(AppSettings(
      background: widget.initial.background,
      quality: _quality,
      hardware: _hardware,
      fps: _fps,
      autoSaveBg: _autoSaveBg,
      navGlass: widget.initial.navGlass,
      navGlassOpacity: widget.initial.navGlassOpacity,
      themeMode: widget.initial.themeMode,
    ));
  }



  @override

  Widget build(BuildContext context) {

    return Container(

      margin: const EdgeInsets.fromLTRB(14, 14, 14, 96),

      padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: glassCardGradient(),
        border: Border.all(color: glassCardBorder(), width: 1.5),
      ),

      child: Column(

        mainAxisSize: MainAxisSize.min,

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          const Text(

            '默认导出设置',

            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),

          ),

          const SizedBox(height: 16),

          const Text('输出画质', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),

          const SizedBox(height: 8),

          Row(

            children: [

              _seg('原画质', _quality == Quality.original, () => setState(() => _quality = Quality.original)),

              const SizedBox(width: 10),

              _seg('1080P', _quality == Quality.p1080, () => setState(() => _quality = Quality.p1080)),

              const SizedBox(width: 10),

              _seg('720P', _quality == Quality.p720, () => setState(() => _quality = Quality.p720)),

            ],

          ),

          const SizedBox(height: 16),

          const Text('导出帧率', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),

          const SizedBox(height: 8),

          Row(

            children: [

              _seg('原帧率', _fps <= 0, () => setState(() => _fps = 0)),

              const SizedBox(width: 10),

              _seg('24', _fps == 24, () => setState(() => _fps = 24)),

              const SizedBox(width: 10),

              _seg('30', _fps == 30, () => setState(() => _fps = 30)),

              const SizedBox(width: 10),

              _seg('48', _fps == 48, () => setState(() => _fps = 48)),

            ],

          ),

          const SizedBox(height: 8),

          Row(

            children: [

              _seg('60', _fps == 60, () => setState(() => _fps = 60)),

              const SizedBox(width: 10),

              _seg('90', _fps == 90, () => setState(() => _fps = 90)),

              const SizedBox(width: 10),

              _seg('120', _fps == 120, () => setState(() => _fps = 120)),

              const Spacer(),

            ],

          ),

          const SizedBox(height: 16),

          Row(

            children: [

              const Expanded(

                child: Text('硬件加速编码', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),

              ),

              Switch(

                value: _hardware,

                onChanged: (v) {
                    setState(() => _hardware = v);
                    _apply();
                  },

              ),

            ],

          ),

          const SizedBox(height: 16),

          Row(

            children: [

              const Expanded(

                child: Text('自动留存模板背景',

                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),

              ),

              Switch(

                value: _autoSaveBg,

                onChanged: (v) {
                    setState(() => _autoSaveBg = v);
                    _apply();
                  },

              ),

            ],

          ),

        ],

      ),

    );

  }



  Widget _seg(String label, bool active, VoidCallback onTap) {

    return Expanded(

      child: GestureDetector(

        onTap: () {
          onTap();
          _apply();
        },

        child: Container(

          alignment: Alignment.center,

          padding: const EdgeInsets.symmetric(vertical: 12),

          decoration: BoxDecoration(
            color: active ? const Color(0xFFEAF2FF) : const Color(0xFFF2F4F8),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: active
                  ? AppColors.accent.withValues(alpha: .42)
                  : Colors.transparent,
              width: active ? 0.5 : 0,
            ),
          ),

          child: Text(

            label,

            style: TextStyle(

              fontSize: 13,

              fontWeight: FontWeight.w600,

              color: active ? AppColors.accent : AppColors.textSub,

            ),

          ),

        ),

      ),

    );

  }

}





/// 通用设置弹层：底栏玻璃效果（含通透度 + 玻璃参考块）/ 背景模式

class _GeneralSheet extends StatefulWidget {

  final AppSettings initial;



  const _GeneralSheet({required this.initial});



  @override

  State<_GeneralSheet> createState() => _GeneralSheetState();

}



class _GeneralSheetState extends State<_GeneralSheet> {

  /// 改动即生效 + 立刻写盘（已去掉取消/保存按钮）
  void _apply() {
    final s = AppSettings(
      background: widget.initial.background,
      quality: widget.initial.quality,
      hardware: widget.initial.hardware,
      fps: widget.initial.fps,
      autoSaveBg: widget.initial.autoSaveBg,
      autoPickBg: _autoPick,
      navGlass: _glass,
      navGlassOpacity: _opacity,
      themeMode: _mode,
    );
    gNavGlass.value = _glass;
    gNavGlassOpacity.value = _opacity;
    gThemeMode.value = AppTheme.parse(_mode);
    SettingsStore().save(s);
  }


  late String _glass = 'matte'; // 只保留柔光玻璃

  late double _opacity = widget.initial.navGlassOpacity;

  late String _mode = widget.initial.themeMode;
  late bool _autoPick = widget.initial.autoPickBg;



  static const double _min = 0.02, _max = 0.30;



  Widget _seg(String label, bool selected, VoidCallback onTap) {

    return Expanded(

      child: GestureDetector(

        onTap: onTap,

        child: Container(

          height: 38,

          alignment: Alignment.center,

          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF2FF) : const Color(0xFFF2F4F8),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: selected
                  ? AppColors.accent.withValues(alpha: .42)
                  : Colors.transparent,
              width: selected ? 0.5 : 0,
            ),
          ),

          child: Text(

            label,

            style: TextStyle(

              fontSize: 12.5,

              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,

              color: selected ? Colors.white : AppColors.text,

            ),

          ),

        ),

      ),

    );

  }



  @override

  Widget build(BuildContext context) {

    final liquid = _glass == 'liquid';

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: Container(

      margin: const EdgeInsets.fromLTRB(14, 14, 14, 96),

      padding: const EdgeInsets.fromLTRB(18, 20, 18, 26),

      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: glassCardGradient(),
        border: Border.all(color: glassCardBorder(), width: 1.5),
      ),

      child: SingleChildScrollView(

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const Text('通用设置',

                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),

            const SizedBox(height: 18),

            // ── 自动取色：把素材首帧当背景（放大 + 高斯模糊）──
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('自动取色',
                          style: TextStyle(
                              fontSize: 13.5, fontWeight: FontWeight.w700)),
                      SizedBox(height: 3),
                      Text('把导入图片/视频首帧当作背景（略微放大 + 高斯模糊）',
                          style: TextStyle(fontSize: 11, height: 1.35)),
                    ],
                  ),
                ),
                Transform.scale(
                  scale: 0.85,
                  child: Switch.adaptive(
                    value: _autoPick,
                    activeColor: Colors.white,
                    activeTrackColor: AppColors.accent,
                    onChanged: (v) {
                      setState(() => _autoPick = v);
                      gAutoPickBg.value = v;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text('底栏玻璃效果',

                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),

            const SizedBox(height: 8),

            Row(children: [

              _seg('柔光玻璃', !liquid, () => setState(() {
                    _glass = 'matte';
                    _apply();
                  })),

              const SizedBox(width: 10),

              const SizedBox.shrink(),

            ]),

            ...[

              const SizedBox(height: 18),

              const Text('通透度',

                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),

              SliderTheme(

                data: SliderTheme.of(context).copyWith(

                  trackHeight: 3,

                  activeTrackColor: AppColors.accent,

                  inactiveTrackColor: AppColors.divider,

                  thumbColor: Colors.white,

                  overlayShape:

                      const RoundSliderOverlayShape(overlayRadius: 14),

                  thumbShape: RoundSliderThumbShape(

                      enabledThumbRadius: 9, elevation: 2),

                ),

                child: Slider(

                  value: _opacity.clamp(_min, _max),

                  min: _min,

                  max: _max,

                  onChanged: (v) {

                    setState(() => _opacity = v);

                    gNavGlassOpacity.value = v; // 即时生效

                  },

                ),

              ),

              Row(

                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [

                  Text('通透',

                      style: TextStyle(fontSize: 11.5, color: AppColors.textSub)),

                  Text('实',

                      style: TextStyle(fontSize: 11.5, color: AppColors.textSub)),

                ],

              ),

              const SizedBox(height: 12),

              GlassPreviewTile(opacity: _opacity),

            ],

            const SizedBox(height: 20),

            const Text('背景模式',

                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),

            const SizedBox(height: 8),

            Row(children: [

              _seg('白色', _mode == 'light', () => setState(() {
                    _mode = 'light';
                    _apply();
                  })),

              const SizedBox(width: 10),

              _seg('黑色', _mode == 'dark', () => setState(() {
                    _mode = 'dark';
                    _apply();
                  })),

              const SizedBox(width: 10),

              _seg('跟随系统', _mode == 'system',

                  () => setState(() => _mode = 'system')),

            ]),

            const SizedBox(height: 6),

            Text('黑色 / 跟随系统选项会保存，页面配色将在主题适配完成后生效',

                style: TextStyle(fontSize: 11, color: AppColors.textSub)),


          ],

        ),

      ),

    ));

  }

}

/// 创作页排序：拖动 + 眼睛隐藏 + 恢复默认（即时保存）
Future<void> showHomeSortSheet(BuildContext context) async {
  final s = await SettingsStore().load();
  final order = s.homeOrder.isEmpty
      ? List<String>.from(kDefaultHomeOrder)
      : List<String>.from(s.homeOrder);
  for (final k in kDefaultHomeOrder) {
    if (!order.contains(k)) order.add(k);
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _HomeSortSheet(
      order: order,
      hidden: List<String>.from(s.homeHidden),
      onChanged: (o, h) async {
        final cur = await SettingsStore().load();
        await SettingsStore().save(AppSettings(
          background: cur.background,
          quality: cur.quality,
          hardware: cur.hardware,
          fps: cur.fps,
          autoSaveBg: cur.autoSaveBg,
          navGlass: cur.navGlass,
          navGlassOpacity: cur.navGlassOpacity,
          themeMode: cur.themeMode,
          tplGroups: cur.tplGroups,
          tplHidden: cur.tplHidden,
          homeOrder: o,
          homeHidden: h,
        ));
        gHomeOrder.value = List<String>.from(o);
        gHomeHidden.value = List<String>.from(h);
      },
    ),
  );
}

class _HomeSortSheet extends StatefulWidget {
  final List<String> order;
  final List<String> hidden;
  final Future<void> Function(List<String>, List<String>) onChanged;
  const _HomeSortSheet({
    required this.order,
    required this.hidden,
    required this.onChanged,
  });
  @override
  State<_HomeSortSheet> createState() => _HomeSortSheetState();
}

class _HomeSortSheetState extends State<_HomeSortSheet> {
  late List<String> _order = List<String>.from(widget.order);
  late Set<String> _hidden = widget.hidden.toSet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 96),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: glassCardGradient(),
          border: Border.all(color: glassCardBorder(), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('创作页排序',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 4),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('拖动调整顺序 · 点眼睛隐藏卡片',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8A93A6))),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: _order.length * 46.0,
              child: ReorderableListView.builder(
                buildDefaultDragHandles: false,
                itemCount: _order.length,
                onReorder: (o, n) {
                  setState(() {
                    if (n > o) n -= 1;
                    _order.insert(n, _order.removeAt(o));
                  });
                  widget.onChanged(_order, _hidden.toList());
                },
                itemBuilder: (context, i) {
                  final key = _order[i];
                  final off = _hidden.contains(key);
                  return SizedBox(
                    key: ValueKey(key),
                    height: 46,
                    child: Row(
                      children: [
                        ReorderableDragStartListener(
                          index: i,
                          child: const Padding(
                            padding: EdgeInsets.only(right: 10),
                            child: Icon(Icons.drag_handle,
                                size: 20, color: Color(0xFFB9C2D6)),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            kHomeCardNames[key] ?? key,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: off
                                  ? const Color(0xFFB6BECD)
                                  : const Color(0xFF12162A),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (off) {
                                _hidden.remove(key);
                              } else {
                                _hidden.add(key);
                              }
                            });
                            widget.onChanged(_order, _hidden.toList());
                          },
                          child: Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: off
                                  ? const Color(0xFFF2F4F8)
                                  : const Color(0xFFEAF2FF),
                            ),
                            child: Icon(
                              off ? Icons.visibility_off : Icons.visibility,
                              size: 15,
                              color: off
                                  ? const Color(0xFFB6BECD)
                                  : AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  );
                },
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _order = List<String>.from(kDefaultHomeOrder);
                  _hidden = <String>{};
                });
                widget.onChanged(_order, _hidden.toList());
                Navigator.pop(context);
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.restart_alt, size: 16, color: AppColors.accent),
                    SizedBox(width: 4),
                    Text('恢复默认顺序',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════
// 设置（二级页面）+ 三级页面
// 设计语言：柔光玻璃卡片 + Material 线性图标 + 主色 #2F6BFF（与全 App 一致）
// ══════════════════════════════════════════════════════════════

/// 二级/三级页共用的玻璃顶栏（同模板库：40px 圆返回钮 + 22px w800 标题）
class _SettingsHeader extends StatelessWidget {
  final String title;
  const _SettingsHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        height: 56,
        padding: const EdgeInsets.only(left: 12, right: 14),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.fill,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chevron_left,
                    size: 22, color: AppColors.text),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 二级页面：设置（分组列表）
class _SettingsScreen extends StatelessWidget {
  final AppSettings initial;
  const _SettingsScreen({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          const _SettingsHeader(title: '设置'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
              children: [
                _setGroupTitle('创作与导出'),
                _setCard([
                  _setRow(Icons.ios_share_outlined, '导出默认设置',
                      '${initial.qualityLabel} · ${initial.hardwareLabel}', () {
                    _pushAndSave(
                      context,
                      _ExportSettingsPage(initial: initial),
                    );
                  }),
                  _setRow(Icons.sort_outlined, '模板库排序', '拖动调整顺序 / 隐藏分组',
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const _TplSortPage()),
                    );
                  }),
                  _setRow(Icons.view_week_outlined, '创作页排序', '拖动调整顺序 / 隐藏卡片',
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const _HomeSortPage()),
                    );
                  }),
                ]),
                _setGroupTitle('界面'),
                _setCard([
                  _setRow(Icons.auto_awesome_outlined, '界面与外观',
                      '底栏玻璃 · 背景模式 · 自动取色', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _GeneralPage(initial: initial),
                      ),
                    );
                  }),
                ]),
                _setGroupTitle('关于'),
                _setCard([
                  _setRow(Icons.info_outline, '版本', '3.3.0', null),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _setGroupTitle(String s) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Text(s,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textSub,
                letterSpacing: .3)),
      );

  Widget _setCard(List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: glassCardGradient(),
          border: Border.all(color: glassCardBorder(), width: 1.5),
        ),
        child: Column(children: children),
      );

  Widget _setRow(IconData icon, String label, String? value, VoidCallback? onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            if (value != null)
              Flexible(
                child: Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSub)),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right,
                  size: 20, color: AppColors.textFaint),
            ],
          ],
        ),
      ),
    );
  }

  /// push 三级页并把返回的 AppSettings 保存
  static Future<void> _pushAndSave(BuildContext context, Widget page) async {
    final r = await Navigator.push<AppSettings>(
      context,
      MaterialPageRoute(builder: (_) => page),
    );
    if (r == null) return;
    await SettingsStore().save(r);
    gNavGlass.value = r.navGlass;
    gNavGlassOpacity.value = r.navGlassOpacity;
    gThemeMode.value = AppTheme.parse(r.themeMode);
    gAutoPickBg.value = r.autoPickBg;
  }
}

/// 三级页：导出默认设置（原弹卡内容）
class _ExportSettingsPage extends StatelessWidget {
  final AppSettings initial;
  const _ExportSettingsPage({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          const _SettingsHeader(title: '导出默认设置'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
              child: _SettingsSheet(initial: initial),
            ),
          ),
        ],
      ),
    );
  }
}

/// 三级页：模板库排序（原弹卡内容）
class _TplSortPage extends StatelessWidget {
  const _TplSortPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          const _SettingsHeader(title: '模板库排序'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
              child: GroupSortSheet(
                order: tplGroupOrder(),
                hidden: gTplHidden.value,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 三级页：创作页排序（原弹卡内容）
class _HomeSortPage extends StatelessWidget {
  const _HomeSortPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          const _SettingsHeader(title: '创作页排序'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
              child: _HomeSortSheet(
                order: gHomeOrder.value.isEmpty
                    ? List<String>.from(kDefaultHomeOrder)
                    : gHomeOrder.value,
                hidden: gHomeHidden.value,
                onChanged: (order, hidden) async {
                  gHomeOrder.value = order;
                  gHomeHidden.value = hidden;
                  final s = await SettingsStore().load();
                  await SettingsStore().save(AppSettings(
                    background: s.background,
                    quality: s.quality,
                    hardware: s.hardware,
                    fps: s.fps,
                    autoSaveBg: s.autoSaveBg,
                    autoPickBg: s.autoPickBg,
                    navGlass: s.navGlass,
                    navGlassOpacity: s.navGlassOpacity,
                    themeMode: s.themeMode,
                    tplGroups: s.tplGroups,
                    tplHidden: s.tplHidden,
                    homeOrder: order,
                    homeHidden: hidden,
                  ));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 三级页：界面与外观（原通用设置内容）
class _GeneralPage extends StatelessWidget {
  final AppSettings initial;
  const _GeneralPage({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          const _SettingsHeader(title: '界面与外观'),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
              child: _GeneralSheet(initial: initial),
            ),
          ),
        ],
      ),
    );
  }
}
