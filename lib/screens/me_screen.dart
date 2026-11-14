import 'update_screen.dart';
import '../services/export_store.dart';

import '../services/app_log.dart';

import '../theme/app_theme.dart';

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:package_info_plus/package_info_plus.dart';



import '../services/app_settings.dart';

import '../services/composer.dart';

import '../services/template_store.dart';

import '../widgets/glass_preview_tile.dart';

import '../widgets/main_shell.dart'
    show gTplGroups, gTplHidden, gTab, gNavGlass, gNavGlassOpacity, gThemeMode;

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
            role: '模板提供',
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

  /// 改动即生效 + 立刻写盘（**只改本页字段**，其它设置保留）
  Future<void> _apply() async {
    final cur = await SettingsStore().load();
    await SettingsStore().save(cur.copyWith(
      quality: _quality,
      hardware: _hardware,
      fps: _fps,
      autoSaveBg: _autoSaveBg,
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
    gNavGlass.value = _glass;
    gNavGlassOpacity.value = _opacity;
    gThemeMode.value = AppTheme.parse(_mode);
    SettingsStore().load().then((cur) => SettingsStore().save(cur.copyWith(
          autoPickBg: _autoPick,
          navGlass: _glass,
          navGlassOpacity: _opacity,
          themeMode: _mode,
        )));
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
        await SettingsStore().save(cur.copyWith(homeOrder: o, homeHidden: h));
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
class _SettingsScreen extends StatefulWidget {
  final AppSettings initial;
  const _SettingsScreen({required this.initial});

  @override
  State<_SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<_SettingsScreen> {
  late AppSettings _s = widget.initial;

  AppSettings _copy({
    bool? autoPickBg,
    bool? autoSaveBg,
    bool? bootAnim,
    String? themeMode,
  }) =>
      AppSettings(
        background: _s.background,
        quality: _s.quality,
        hardware: _s.hardware,
        fps: _s.fps,
        autoSaveBg: autoSaveBg ?? _s.autoSaveBg,
        autoPickBg: autoPickBg ?? _s.autoPickBg,
        bootAnim: bootAnim ?? _s.bootAnim,
        navGlass: _s.navGlass,
        navGlassOpacity: _s.navGlassOpacity,
        themeMode: themeMode ?? _s.themeMode,
        tplGroups: _s.tplGroups,
        tplHidden: _s.tplHidden,
        homeOrder: _s.homeOrder,
        homeHidden: _s.homeHidden,
      );

  Future<void> _save() async {
    await SettingsStore().save(_s);
    gAutoPickBg.value = _s.autoPickBg;
    gThemeMode.value = AppTheme.parse(_s.themeMode);
  }

  Future<void> _pickThemeMode() async {
    final r = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => _ThemeModePage(initial: _s.themeMode),
      ),
    );
    if (r == null || !mounted) return;
    setState(() => _s = _copy(themeMode: r));
    await _save();
  }

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
                _groupTitle('创作与导出'),
                _card([
                  _row(Icons.ios_share_outlined, '导出默认设置',
                      '${_s.qualityLabel} · ${_s.hardwareLabel}', () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => _ExportSettingsPage(initial: _s),
                      ),
                    ).then((r) async {
                      if (r is AppSettings && mounted) {
                        setState(() => _s = r);
                        await _save();
                      }
                    });
                  }),
                  _row(Icons.sort_outlined, '模板库排序', null, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const _TplSortPage()),
                    );
                  }),
                  _row(Icons.view_week_outlined, '创作页排序', null, () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const _HomeSortPage()),
                    );
                  }),
                ]),
                _groupTitle('界面'),
                _card([
                  _switchRow(
                    Icons.brush_outlined,
                    '自动取色',
                    _s.autoPickBg,
                    (v) async {
                      setState(() => _s = _copy(autoPickBg: v));
                      await _save();
                    },
                  ),
                  _row(Icons.brightness_6_outlined, '背景模式', _s.themeModeLabel,
                      _pickThemeMode),
                ]),
                _groupTitle('数据'),
                _card([
                  _switchRow(
                    Icons.play_circle_outline,
                    '开屏动画',
                    _s.bootAnim,
                    (v) async {
                      setState(() => _s = _copy(bootAnim: v));
                      await _save();
                    },
                  ),
                  _switchRow(
                    Icons.save_outlined,
                    '自动留存模板背景',
                    _s.autoSaveBg,
                    (v) async {
                      setState(() => _s = _copy(autoSaveBg: v));
                      await _save();
                    },
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupTitle(String s) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Text(s,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textSub,
                letterSpacing: .3)),
      );

  Widget _card(List<Widget> children) => Container(
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: glassCardGradient(),
          border: Border.all(color: glassCardBorder(), width: 1.5),
        ),
        // stretch：让每行铺满卡片宽度，右侧 › 才能与其它行对齐
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      );

  Widget _row(IconData icon, String label, String? value, VoidCallback? onTap) {
    // 右侧统一结构：值（定宽右对齐）+ 箭头位（无箭头也占位）→ 所有行箭头严格对齐
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
              flex: 1,
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            if (value != null)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 160),
                child: Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: 12, color: AppColors.textSub)),
              ),
            // 箭头：固定 20px + 左间距 6；无箭头时用等宽留白占位
            const SizedBox(width: 6),
            SizedBox(
              width: 20,
              child: onTap != null
                  ? Icon(Icons.chevron_right,
                      size: 20, color: AppColors.textFaint)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchRow(
      IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
          Transform.scale(
            scale: 0.85,
            child: Switch.adaptive(
              value: value,
              activeColor: Colors.white,
              activeTrackColor: AppColors.accent,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

/// 三级页：背景模式（白色 / 黑色 / 跟随系统）
class _ThemeModePage extends StatefulWidget {
  final String initial;
  const _ThemeModePage({required this.initial});

  @override
  State<_ThemeModePage> createState() => _ThemeModePageState();
}

class _ThemeModePageState extends State<_ThemeModePage> {
  late String _mode = widget.initial;

  static const _options = [
    ('light', '白色', Icons.light_mode_outlined),
    ('dark', '黑色', Icons.dark_mode_outlined),
    ('system', '跟随系统', Icons.brightness_auto_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          const _SettingsHeader(title: '背景模式'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: glassCardGradient(),
                    border: Border.all(color: glassCardBorder(), width: 1.5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final o in _options)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(context, o.$1);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 15),
                            child: Row(
                              children: [
                                Icon(o.$3, size: 20, color: AppColors.accent),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(o.$2,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700)),
                                ),
                                if (_mode == o.$1)
                                  Icon(Icons.check_rounded,
                                      size: 20, color: AppColors.accent),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
/// 三级页：模板库排序（全宽卡片，与导出默认设置同宽）
class _TplSortPage extends StatefulWidget {
  const _TplSortPage();

  @override
  State<_TplSortPage> createState() => _TplSortPageState();
}

class _TplSortPageState extends State<_TplSortPage> {
  late List<String> _order = () {
    final cur = tplGroupOrder();
    return cur.isEmpty ? <String>[] : List<String>.from(cur);
  }();

  late Set<String> _hidden = gTplHidden.value.toSet();

  Future<void> _save() async {
    final s = await SettingsStore().load();
    await SettingsStore().save(
        s.copyWith(tplGroups: _order, tplHidden: _hidden.toList()));
    gTplGroups.value = _order;
    gTplHidden.value = _hidden.toList();
  }

  Future<void> _reset() async {
    setState(() {
      _order = <String>[];
      _hidden = <String>{};
    });
    // ⚠️ 不能 new 一个默认 AppSettings 覆盖：那把其它设置全清空了
    await _save();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return _SortScaffold(
      title: '模板库排序',
      hint: '拖动右侧 ≡ 调整分组顺序，点眼睛隐藏/显示',
      order: _order,
      hidden: _hidden,
      onReorder: (oldI, newI) {
        setState(() {
          if (newI > oldI) newI -= 1;
          final it = _order.removeAt(oldI);
          _order.insert(newI, it);
        });
        _save();
      },
      onToggle: (k) {
        setState(() {
          if (!_hidden.remove(k)) _hidden.add(k);
        });
        _save();
      },
      onReset: _reset,
    );
  }
}

/// 三级页：创作页排序（全宽卡片）
class _HomeSortPage extends StatefulWidget {
  const _HomeSortPage();

  @override
  State<_HomeSortPage> createState() => _HomeSortPageState();
}

class _HomeSortPageState extends State<_HomeSortPage> {
  late List<String> _order = () {
    final cur = gHomeOrder.value;
    return cur.isEmpty ? List<String>.from(kDefaultHomeOrder) : List<String>.from(cur);
  }();

  late Set<String> _hidden = gHomeHidden.value.toSet();

  Future<void> _save() async {
    final s = await SettingsStore().load();
    await SettingsStore().save(
        s.copyWith(homeOrder: _order, homeHidden: _hidden.toList()));
    gHomeOrder.value = _order;
    gHomeHidden.value = _hidden.toList();
  }

  Future<void> _reset() async {
    setState(() {
      _order = List<String>.from(kDefaultHomeOrder);
      _hidden = <String>{};
    });
    gHomeOrder.value = <String>[];
    gHomeHidden.value = <String>[];
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return _SortScaffold(
      title: '创作页排序',
      hint: '拖动右侧 ≡ 调整卡片顺序，点眼睛隐藏/显示',
      order: _order,
      hidden: _hidden,
      labelOf: (k) => kHomeCardNames[k] ?? k,
      onReorder: (oldI, newI) {
        setState(() {
          if (newI > oldI) newI -= 1;
          final it = _order.removeAt(oldI);
          _order.insert(newI, it);
        });
        _save();
      },
      onToggle: (k) {
        setState(() {
          if (!_hidden.remove(k)) _hidden.add(k);
        });
        _save();
      },
      onReset: _reset,
    );
  }
}

/// 排序页通用骨架（全宽卡片 + 拖动 + 眼睛 + 恢复默认）
class _SortScaffold extends StatelessWidget {
  final String title;
  final String hint;
  final List<String> order;
  final Set<String> hidden;
  final String Function(String)? labelOf;
  final void Function(int, int) onReorder;
  final void Function(String) onToggle;
  final VoidCallback onReset;

  const _SortScaffold({
    required this.title,
    required this.hint,
    required this.order,
    required this.hidden,
    required this.onReorder,
    required this.onToggle,
    required this.onReset,
    this.labelOf,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _SettingsHeader(title: title),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 4, 14, 30),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                  child: Text(hint,
                      style: TextStyle(
                          fontSize: 11.5, color: AppColors.textSub)),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: glassCardGradient(),
                    border: Border.all(color: glassCardBorder(), width: 1.5),
                  ),
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: order.length,
                    onReorder: onReorder,
                    proxyDecorator: (child, i, anim) => Material(
                      color: Colors.transparent,
                      child: child,
                    ),
                    itemBuilder: (ctx, i) {
                      final k = order[i];
                      final isHidden = hidden.contains(k);
                      final label = labelOf?.call(k) ?? k;
                      return Container(
                        key: ValueKey(k),
                        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFFF2F5FA)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(label,
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isHidden
                                          ? AppColors.textFaint
                                          : AppColors.text)),
                            ),
                            GestureDetector(
                              onTap: () => onToggle(k),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  isHidden
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 19,
                                  color: isHidden
                                      ? AppColors.textFaint
                                      : AppColors.textSub,
                                ),
                              ),
                            ),
                            ReorderableDragStartListener(
                              index: i,
                              child: Icon(Icons.drag_handle,
                                  size: 20, color: AppColors.textFaint),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: onReset,
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(24),
                      border:
                          Border.all(color: glassCardBorder(), width: 1.5),
                    ),
                    child: Text('恢复默认顺序',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accent)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
