import 'dart:ui' show ImageFilter;
import '../theme/app_theme.dart';

import 'dart:io';

import 'dart:typed_data';



import 'package:file_picker/file_picker.dart';

import 'package:flutter/material.dart';

import 'package:path/path.dart' as p;

import 'package:path_provider/path_provider.dart';

import 'package:share_plus/share_plus.dart';



import '../models/shell_template.dart';

import '../services/app_settings.dart';

import '../services/template_pack.dart';

import '../services/template_colors.dart';
import '../services/template_store.dart';

import '../widgets/main_shell.dart' show gTplGroups, gTplHidden;
import '../widgets/group_bar.dart';

import 'calibrate_screen.dart';

import 'compose_screen.dart';




/// 机型目录项

class _Model {

  final String brand; // 华为

  final String series; // Mate

  final String model; // Mate 90

  final String? templateId; // 已内置模板 id（如 builtin_xiaomi14）

  final bool isCommon; // 属于"常用"组

  /// 卡片标题：不填就用「品牌 机型」（比如一加 15 归在 OPPO 下，但名字只显示「一加 15」）

  final String? displayName;



  const _Model({

    required this.brand,

    required this.series,

    required this.model,

    this.templateId,

    this.isCommon = false,

    this.displayName,

  });



  String get fullName => displayName ?? '$brand $model';

}



const _kModels = <_Model>[

  // 常用

  _Model(brand: '小米', series: '数字系列', model: '14', templateId: 'builtin_xiaomi14', isCommon: true),

  _Model(brand: '华为', series: 'Mate 系列', model: 'Mate 60', isCommon: true),

  // 华为（含内置模板）

  _Model(brand: '华为', series: 'Pura 系列', model: 'Pura 90 Pro Max', displayName: '华为 Pura 90 Pro Max', templateId: 'builtin_huawei_pura90_promax'),

  _Model(brand: '华为', series: 'Mate 系列', model: 'Mate 90'),

  _Model(brand: '华为', series: 'Mate 系列', model: 'Mate 80'),

  _Model(brand: '华为', series: 'Mate 系列', model: 'Mate 70'),

  _Model(brand: '华为', series: 'Mate 系列', model: 'Mate 60'),

  // 小米（含内置模板）

  _Model(brand: '小米', series: '数字系列', model: '17 Ultra', displayName: '小米 17 Ultra', templateId: 'builtin_xiaomi_17_ultra'),

  _Model(brand: '小米', series: '数字系列', model: '17 Pro', templateId: 'builtin_xiaomi17pro'),

  _Model(brand: '小米', series: '数字系列', model: '15 Pro'),

  _Model(brand: '小米', series: '数字系列', model: '15'),

  _Model(brand: '小米', series: '数字系列', model: '14 Pro'),

  _Model(brand: '小米', series: '数字系列', model: '14', templateId: 'builtin_xiaomi14'),

  // OPPO（含新合入的内置模板：OPPO / 一加 / 真我 都归在 OPPO 品牌下）




  _Model(brand: 'OPPO', series: 'Find 系列', model: 'Find X10 Pro Max', displayName: 'OPPO Find X10 Pro Max', templateId: 'builtin_oppo_findx10promax_moonwhite'),
    _Model(brand: 'OPPO', series: 'Find 系列', model: 'Find X9S Pro', displayName: 'OPPO Find X9S Pro', templateId: 'builtin_oppo_findx9spro_freewhite'),
    _Model(brand: 'OPPO', series: 'Find 系列', model: 'Find X9 Ultra', displayName: 'OPPO Find X9 Ultra', templateId: 'builtin_oppo_findx9ultra_glacier'),
    _Model(brand: 'OPPO', series: 'Find 系列', model: 'Find X9 Pro', displayName: 'OPPO Find X9 Pro', templateId: 'builtin_oppo_findx9pro_frostwhite'),
    _Model(brand: 'OPPO', series: 'Find 系列', model: 'Find X9', displayName: 'OPPO Find X9', templateId: 'builtin_oppo_findx9_frostwhite'),
    _Model(brand: 'OPPO', series: 'Find 系列', model: 'Find X8s', displayName: 'OPPO Find X8s', templateId: 'builtin_oppo_findx8s_sakura'),
    _Model(brand: 'OPPO', series: 'Find 系列', model: 'Find X8 Ultra', displayName: 'OPPO Find X8 Ultra', templateId: 'builtin_oppo_findx8ultra_dawn'),
    _Model(brand: 'OPPO', series: 'Find 系列', model: 'Find X8', displayName: 'OPPO Find X8', templateId: 'builtin_oppo_findx8_white'),
    _Model(brand: 'OPPO', series: 'Find 系列', model: 'Find X7', displayName: 'OPPO Find X7', templateId: 'builtin_oppo_findx7_c7'),
    _Model(brand: 'OPPO', series: 'Find 系列', model: 'Find X6', displayName: 'OPPO Find X6', templateId: 'builtin_oppo_findx6_c6'),
    _Model(brand: 'OPPO', series: 'Find 系列', model: 'Find X5', displayName: 'OPPO Find X5', templateId: 'builtin_oppo_findx5_c5'),
    _Model(brand: 'OPPO', series: 'Find 系列', model: 'Find X3', displayName: 'OPPO Find X3', templateId: 'builtin_oppo_findx3_c4'),
    _Model(brand: 'OPPO', series: 'Find 系列', model: 'Find X2', displayName: 'OPPO Find X2', templateId: 'builtin_oppo_findx2_c3'),
    _Model(brand: 'OPPO', series: '一加', model: '一加 15', displayName: '一加 15', templateId: 'builtin_oneplus_15'),

  _Model(brand: 'OPPO', series: '真我', model: '真我 GT8 Pro', displayName: '真我 GT8 Pro', templateId: 'builtin_realme_gt8pro'),





  // vivo（含内置模板）








  // 三星（含内置模板）

  
    _Model(brand: 'vivo', series: 'X 系列', model: 'vivo X500', displayName: 'vivo X500', templateId: 'builtin_vivo_vivox500_v24'),
    _Model(brand: 'vivo', series: 'X 系列', model: 'vivo X300 Ultra', displayName: 'vivo X300 Ultra', templateId: 'builtin_vivo_vivox300ultra_v19'),
    _Model(brand: 'vivo', series: 'X 系列', model: 'vivo X300 Pro', displayName: 'vivo X300 Pro', templateId: 'builtin_vivo_vivox300pro_v15'),
    _Model(brand: 'vivo', series: 'X 系列', model: 'vivo X300', displayName: 'vivo X300', templateId: 'builtin_vivo_vivox300_v10'),
    _Model(brand: 'vivo', series: 'X 系列', model: 'vivo X200 Pro mini', displayName: 'vivo X200 Pro mini', templateId: 'builtin_vivo_vivox200promini_v6'),
    _Model(brand: 'vivo', series: 'X 系列', model: 'vivo X100', displayName: 'vivo X100', templateId: 'builtin_vivo_vivox100_v1'),
    _Model(brand: '三星', series: 'S 系列', model: 'S26 Ultra', displayName: '三星 Galaxy S26 Ultra', templateId: 'builtin_samsung_s26_ultra'),

  _Model(brand: '三星', series: 'S 系列', model: 'Galaxy S25 Ultra', displayName: '三星 Galaxy S25 Ultra', templateId: 'builtin_samsung_s25_ultra'),

  _Model(brand: '三星', series: 'S 系列', model: 'S25'),

  _Model(brand: '三星', series: 'S 系列', model: 'S24 Ultra'),

  _Model(brand: '三星', series: 'S 系列', model: 'S24'),

  // 荣耀（含内置模板）

  _Model(brand: '荣耀', series: '数字系列', model: '600', displayName: '荣耀 600', templateId: 'builtin_honor_600'),

  _Model(brand: '荣耀', series: 'Magic 系列', model: 'Magic7 Pro'),

  _Model(brand: '荣耀', series: 'Magic 系列', model: 'Magic7'),

  _Model(brand: '荣耀', series: 'Magic 系列', model: 'Magic6 Pro'),

  _Model(brand: '荣耀', series: 'Magic 系列', model: 'Magic6'),

];



/// 模板库二级页：品牌分类 + 机型列表

class TplLibraryScreen extends StatefulWidget {

  final String? initialBrand;

  /// true = 实况创作入口（模板选完进实况模式合成台）
  final bool liveMode;



  /// 可注入的数据源（测试用；为空时使用真实 TemplateStore）

  final TemplateStore? store;



  /// true = 选模板后进入图片创作台；false = 视频合成台

  final bool imageMode;



  /// true = 模板库管理模式（查看全部自制模板，可长按删除）

  final bool manageMode;



  const TplLibraryScreen({

    super.key,

    this.initialBrand,
    this.liveMode = false,

    this.store,

    this.imageMode = false,

    this.manageMode = false,

  });



  @override

  State<TplLibraryScreen> createState() => _TplLibraryScreenState();

}



class _TplLibraryScreenState extends State<TplLibraryScreen> {

  /// 默认分组顺序（可在「分组排序」里调整 / 隐藏）

  static const _defaultChips = [
    '自制',
    '小米',
    '常用',
    '华为',

    'OPPO',

    'vivo',

    '三星',

    '荣耀',];



  /// 当前显示顺序：用户顺序 → 过滤隐藏 → 漏掉的分组自动补到末尾

    /// 旧分组名 → 新分组名（自制抠图 / 自制透明 → 自制）
  static const _legacyGroups = {
    '自制抠图': '自制',
    '自制透明': '自制',
  };

  String _norm(String g) => _legacyGroups[g] ?? g;

List<String> get _chips {
    final order = gTplGroups.value.map(_norm).toList();
    final hidden = gTplHidden.value.map(_norm).toList();

    final out = <String>[];

    for (final c in order) {

      if (_defaultChips.contains(c) && !hidden.contains(c) && !out.contains(c)) {

        out.add(c);

      }

    }

    for (final c in _defaultChips) {

      if (!out.contains(c) && !hidden.contains(c)) out.add(c);

    }

    return out;

  }

  /// 分组显示名：自制抠图→抠图、自制透明→透明
  String _groupLabel(String g) {
    switch (g) {
      case '自制':
        return '自制';
      case '自制抠图':
        return '抠图';
      case '自制透明':
        return '透明';
      default:
        return g;
    }
  }



  late String _brand =
      widget.initialBrand ?? (_chips.isEmpty ? '自制抠图' : _chips.first);

  List<ShellTemplate> _templates = [];

  bool _loading = true;



  @override

  void initState() {

    super.initState();

    _load();

  }



  Future<void> _load() async {

    try {

      final store = widget.store ?? TemplateStore();

      final list = await store.load();

      if (!mounted) return;

      setState(() {

        _templates = list;

        _loading = false;

      });

    } catch (e) {

      debugPrint('模板库加载失败: $e');

      if (!mounted) return;

      setState(() => _loading = false);

    }

  }






  /// 全部内置分组（含被隐藏的），用于排序弹窗展示

  static const List<String> _allGroups = _defaultChips;



  /// 当前完整顺序（含隐藏项）：用户顺序 → 补上漏掉的分组

  static List<String> currentGroupOrder() {

    final out = <String>[];

    for (final c in gTplGroups.value) {

      if (_allGroups.contains(c) && !out.contains(c)) out.add(c);

    }

    for (final c in _allGroups) {

      if (!out.contains(c)) out.add(c);

    }

    return out;

  }



  /// 自制类分组（自制抠图 / 自制透明）

  bool get _isCustomTab =>
      _brand == '自制' || _brand == '自制抠图' || _brand == '自制透明';



  List get _shown {

    // 自制抠图 =「添加新壳」标定出的抠图模板；自制透明 =「添加新壳 · 透明」标定出的透明模板。

    // 内置模板不进自制分组（它们归各自品牌分组 / 常用），避免小米14 这种在自制里重复出现

    if (_brand == '自制') {
      // 自制分组 = 抠图模板 + 透明模板合并（卡片右上角标签区分）
      return _templates.where((t) => !t.builtIn).toList();
    }

    if (_brand == '自制抠图') {

      return _templates

          .where((t) => !t.isTransparent && !t.builtIn)

          .toList();

    }

    if (_brand == '自制透明') {

      return _templates

          .where((t) => t.isTransparent && !t.builtIn)

          .toList();

    }

    if (_brand == '常用') return _kModels.where((m) => m.isCommon).toList();

    // 品牌分类排除"常用"组专属条目，避免同一机型重复出现

    return _kModels.where((m) => m.brand == _brand && !m.isCommon).toList();

  }



  /// 合成台统一入口：**透明模板 → 透明合成台；普通（抠图）模板 → 普通合成台**。

  /// 所有打开模板的入口都必须走这里，避免某个分组里点进去跑错台子。

  void _pushCompose(ShellTemplate t) {

    Navigator.push(

      context,

      MaterialPageRoute(

        builder: (_) => t.isTransparent

            ? ComposeScreen(
                    template: t,
                    imageMode: widget.imageMode,
                    mode: widget.liveMode
                        ? ComposeMode.live
                        : widget.imageMode
                            ? ComposeMode.transparentImage
                            : ComposeMode.transparentVideo,
                  )

            : ComposeScreen(
              template: t,
              imageMode: widget.imageMode,
              mode: widget.liveMode
                  ? ComposeMode.live
                  : widget.imageMode
                      ? ComposeMode.image
                      : ComposeMode.video,
            ),

      ),

    );

  }



  void _openCustom(ShellTemplate t) {

    _pushCompose(t);

  }



  bool _isBuiltIn(_Model m) {

    if (m.templateId == null) return false;

    return _templates.any((t) => t.id == m.templateId);

  }



  ShellTemplate? _templateOf(_Model m) {

    if (m.templateId == null) return null;

    for (final t in _templates) {

      if (t.id == m.templateId) return t;

    }

    return null;

  }



  void _open(_Model m) {

    final t = _templateOf(m);

    if (t != null) {

      _pushCompose(t);

      return;

    }

    ScaffoldMessenger.of(context)

      ..hideCurrentSnackBar()

      ..showSnackBar(SnackBar(

        content: Text('「${m.fullName}」壳图未导入，请在创作页点击"添加新壳"导入'),

        duration: const Duration(seconds: 2),

      ));

  }



  /// 长按模板卡：可删除，也可切换「透明模板」标记（老模板归位用），两者共存

  Future<void> _showTemplateMenu(ShellTemplate t) async {

    final act = await showDialog<String>(

      context: context,

      builder: (ctx) => AlertDialog(

        title: Text(t.name),

        contentPadding: const EdgeInsets.only(top: 6),

        content: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            ListTile(

              leading: Icon(

                t.isTransparent

                    ? Icons.layers_outlined

                    : Icons.layers_clear_outlined,

                color: AppColors.accent,

              ),

              title: Text(t.isTransparent ? '取消透明标记' : '标记为透明模板'),

              subtitle: Text(

                t.isTransparent ? '移回「自制抠图」' : '移入「自制透明」，可用背景融合',

                style: const TextStyle(fontSize: 11.5),

              ),

              onTap: () => Navigator.pop(ctx, 'toggle'),

            ),

            ListTile(

              leading: const Icon(Icons.tune, color: AppColors.accent),

              title: const Text('重新标定'),

              subtitle: const Text(

                '改标定框或改名字（内置模板也可改）',

                style: TextStyle(fontSize: 11.5),

              ),

              onTap: () => Navigator.pop(ctx, 'recalib'),

            ),

            ListTile(

              leading: const Icon(Icons.ios_share, color: AppColors.accent),

              title: const Text('导出并分享'),

              subtitle: const Text(

                '生成 .zip 模板文件，发给别人导入',

                style: TextStyle(fontSize: 11.5),

              ),

              onTap: () => Navigator.pop(ctx, 'share'),

            ),

            ListTile(

              leading: const Icon(Icons.save_alt, color: AppColors.accent),

              title: const Text('保存模板到手机文件夹'),

              subtitle: const Text(

                '.zip 文件，自己留存或换个方式分享',

                style: TextStyle(fontSize: 11.5),

              ),

              onTap: () => Navigator.pop(ctx, 'savefile'),

            ),

            if (!t.builtIn)

              ListTile(

                leading: const Icon(Icons.delete_outline, color: Color(0xFFFF3B30)),

                title: const Text('删除模板', style: TextStyle(color: Color(0xFFFF3B30))),

                onTap: () => Navigator.pop(ctx, 'delete'),

              ),

          ],

        ),

        actions: [

          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),

        ],

      ),

    );

    if (!mounted || act == null) return;

    final store = widget.store ?? TemplateStore();

    if (act == 'toggle') {

      await store.updateParams(t.copyWith(isTransparent: !t.isTransparent));

      if (!mounted) return;

      _toast(t.isTransparent ? '已取消透明标记' : '已标记为透明模板');

      await _load();

    } else if (act == 'recalib') {

      // 用现有标定框打开标定页（编辑模式），保存后即可用新逻辑重新计算

      final saved = await Navigator.push<bool?>(

        context,

        MaterialPageRoute(

          builder: (_) => CalibrateScreen(

            imagePath: t.casePath,

            imageWidth: t.caseWidth,

            imageHeight: t.caseHeight,

            transparentMode: t.isTransparent,

            existing: t,

          ),

        ),

      );

      if (!mounted) return;

      if (saved == true) {

        _toast('已更新「${t.name}」的标定');

        await _load();

      }

    } else if (act == 'share') {

      await _shareTemplate(t);

    } else if (act == 'savefile') {

      await _saveTemplateToFile(t);

    } else if (act == 'delete') {

      await store.delete(t.id);

      if (!mounted) return;

      _toast('已删除「${t.name}」');

      await _load();

    }

  }



  // ───────────────── 模板导出 / 导入 ─────────────────



  String _safeFileName(String name) {

    var s = name.replaceAll(RegExp(r'[\\/:*?"<>|\s]+'), '_').trim();

    if (s.length > 30) s = s.substring(0, 30);

    return s.isEmpty ? 'template' : s;

  }



  /// 打包成 .shtpl（放缓存目录），失败返回 null

  Future<String?> _buildPack(ShellTemplate t) async {

    try {

      final tmp = await getTemporaryDirectory();

      final dir = Directory(p.join(tmp.path, 'tpl_share'));

      await dir.create(recursive: true);

      final out =

          p.join(dir.path, '带壳模板-${_safeFileName(t.name)}.${TemplatePack.ext}');

      await TemplatePack.write(t, out);

      return out;

    } catch (e) {

      if (mounted) _toast('导出模板失败: $e');

      return null;

    }

  }



  /// 导出并分享（系统分享面板：微信 / QQ / 文件…）

  Future<void> _shareTemplate(ShellTemplate t) async {

    final path = await _buildPack(t);

    if (path == null || !mounted) return;

    try {

      await SharePlus.instance.share(ShareParams(

        files: [XFile(path, mimeType: 'application/zip')],

        text: '带壳视频模板「${t.name}」',

      ));

    } catch (e) {

      if (mounted) _toast('分享失败: $e');

    }

  }



  /// 保存模板到手机文件夹（系统选择器，无需存储权限）

  Future<void> _saveTemplateToFile(ShellTemplate t) async {

    final path = await _buildPack(t);

    if (path == null || !mounted) return;

    try {

      final bytes = await File(path).readAsBytes();

      final saved = await FilePicker.platform.saveFile(

        dialogTitle: '保存模板到手机文件夹',

        fileName: '带壳模板-${_safeFileName(t.name)}.${TemplatePack.ext}',

        bytes: Uint8List.fromList(bytes),

      );

      if (!mounted) return;

      if (saved != null) _toast('已保存: ${p.basename(saved)}');

    } catch (e) {

      if (mounted) _toast('保存失败: $e');

    }

  }



  /// 导入模板：选文件 → 校验 → 预览确认 → 写库（按透明标记自动分组）

  Future<void> _importTemplate() async {

    try {

      final res = await FilePicker.platform.pickFiles(

        type: FileType.custom,

        allowedExtensions: [TemplatePack.ext, ...TemplatePack.legacyExts],

        allowMultiple: false,

      );

      final path = res?.files.single.path;

      if (path == null || !mounted) return;

      final tmp = await getTemporaryDirectory();

      final workDir = p.join(tmp.path, 'tpl_import');

      final data = await TemplatePack.parse(path, workDir: workDir);

      if (!mounted) return;



      final ok = await showDialog<bool>(

        context: context,

        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.card,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: glassCardBorder(), width: 1.5),
          ),

          title: const Text(
            '导入模板',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),

          content: SingleChildScrollView(

            child: Column(

              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Center(

                  child: ClipRRect(

                    borderRadius: BorderRadius.circular(12),

                    child: Image.file(

                      File(data.imagePath),

                      height: 160,

                      fit: BoxFit.contain,

                      errorBuilder: (_, _, _) => const SizedBox(

                        height: 80,

                        child: Center(child: Text('图片预览失败')),

                      ),

                    ),

                  ),

                ),

                const SizedBox(height: 12),

                Text('名字：${data.name}',

                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),

                const SizedBox(height: 4),

                Text('壳图：${data.sizeLabel}',

                    style: TextStyle(fontSize: 12, color: AppColors.textSub)),

                Text('屏幕框：${data.screenLabel}',

                    style: TextStyle(fontSize: 12, color: AppColors.textSub)),

                Text('类型：${data.isTransparent ? '透明模板（落到自制透明）' : '抠图模板（落到自制抠图）'}',

                    style: TextStyle(fontSize: 12, color: AppColors.textSub)),

              ],

            ),

          ),

          actions: [

            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),

            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('导入')),

          ],

        ),

      );

      if (ok != true || !mounted) return;



      final t = await TemplatePack.importInto(

        path,

        store: widget.store ?? TemplateStore(),

        workDir: workDir,

      );

      if (!mounted) return;

      _toast('已导入「${t.name}」');

      await _load();

    } on TemplatePackException catch (e) {

      if (mounted) _toast('导入失败：${e.message}');

    } catch (e) {

      if (mounted) _toast('导入失败：$e');

    }

  }



  void _toast(String msg) {

    ScaffoldMessenger.of(context)

      ..hideCurrentSnackBar()

      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));

  }



  @override

  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
      final headerH = safeTop + 64.0; // 顶栏(渐隐)总高 = 状态栏 + 64

    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBodyBehindAppBar: true,
      extendBody: true,
      // 顶栏：上实下虚（实色 → 模糊透明），标题行下移 40
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(headerH),
        child: Stack(
          children: [
            Positioned.fill(
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
          Positioned(
              left: 12,
              right: 14,
              top: safeTop + 8,
              height: 44,
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
                      child: Icon(Icons.chevron_left, size: 22, color: AppColors.text),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '模板库',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                  ),
                  const Spacer()
                ],
              ),
            ),
            ],
        
            
),
      ),
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
          Column(

          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [

            // 机型 / 模板列表

            Expanded(

              child: _loading

                  ? const Center(child: CircularProgressIndicator())

                  : _isCustomTab && _shown.isEmpty

                      ? _EmptyHint(
                              transparent: _brand == '自制透明',
                              merged: _brand == '自制',
                            )

                      : ListView.builder(

                      padding: EdgeInsets.fromLTRB(14, safeTop + 72, 14, 120),

                      itemCount: _shown.length,

                      itemBuilder: (context, i) {

                        if (_isCustomTab) {

                          final t = _shown[i] as ShellTemplate;

                          return Padding(

                            padding: const EdgeInsets.only(bottom: 10),

                            child: _CustomCard(

                              t: t,

                              onTap: () => _openCustom(t),

                              onLongPress: () => _showTemplateMenu(t),

                            ),

                          );

                        }

                        final m = _shown[i] as _Model;

                        final built = _isBuiltIn(m);

                        final t = _templateOf(m);

                        return Padding(

                          padding: const EdgeInsets.only(bottom: 10),

                          child: _ModelCard(

                            model: m,

                            builtIn: built,

                            thumbPath: t?.casePath,

                            onTap: () => _open(m),

                          ),

                        );

                      },

                    ),

            ),

          ],

        ), 
          Positioned(
            left: 20,
            right: 20,
            bottom: 16 + MediaQuery.paddingOf(context).bottom,
            child: GroupBar(
              groups: _chips,
              selected: _brand,
              labelOf: _groupLabel,
              onChanged: (g) => setState(() => _brand = g),
              onImport: _importTemplate,
            ),
          ),
          ]),

      ),

    );

  }

}



/// 自制分组为空时的引导（不提供导入入口，导入统一在「创作」页）

class _EmptyHint extends StatelessWidget {

  final bool transparent;
  final bool merged;



  const _EmptyHint({required this.transparent, this.merged = false});



  @override

  Widget build(BuildContext context) {

    return Center(

      child: Padding(

        padding: const EdgeInsets.fromLTRB(30, 0, 30, 60),

        child: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            Container(

              width: 56,

              height: 56,

              decoration: BoxDecoration(

                color: AppColors.accent.withValues(alpha: .08),

                shape: BoxShape.circle,

              ),

              child: Icon(

                transparent ? Icons.layers_clear_outlined : Icons.layers_outlined,

                size: 26,

                color: AppColors.accent,

              ),

            ),

            const SizedBox(height: 14),

            Text(

              merged
                  ? '还没有自制模板'
                  : transparent
                      ? '还没有透明模板'
                      : '还没有抠图模板',

              style: TextStyle(

                fontSize: 15,

                fontWeight: FontWeight.w800,

                color: AppColors.text,

              ),

            ),

            const SizedBox(height: 8),

            Text(

              transparent

                  ? '去「创作」页点「添加新壳 · 透明」\n导入透明 PNG 标定，自动识别、可融合背景'

                  : '去「创作」页点「添加新壳」\n导入带壳图并标定屏幕区域（纯色壁纸抠图最准）',

              textAlign: TextAlign.center,

              style: TextStyle(fontSize: 12, height: 1.55, color: AppColors.textSub),

            ),

          ],

        ),

      ),

    );

  }

}



/// 机型卡（116 高横条）

class _ModelCard extends StatelessWidget {

  final _Model model;

  final bool builtIn;

  final String? thumbPath;

  final VoidCallback onTap;



  const _ModelCard({

    required this.model,

    required this.builtIn,

    required this.thumbPath,

    required this.onTap,

  });



  @override

  Widget build(BuildContext context) {

    return GestureDetector(

      onTap: onTap,

      child: Container(

        height: 116,

        decoration: BoxDecoration(

          color: AppColors.card,

          borderRadius: BorderRadius.circular(16),

          boxShadow: [

            BoxShadow(

              color: Colors.black.withValues(alpha: .04),

              blurRadius: 10,

              offset: const Offset(0, 3),

            ),

          ],

        ),

        child: Row(

          children: [

            // 缩略图区

            SizedBox(

              width: 96,

              child: Padding(

                padding: const EdgeInsets.all(10),

                child: ClipRRect(

                  borderRadius: BorderRadius.circular(12),

                  child: _thumb(),

                ),

              ),

            ),

            // 名称

            Expanded(

              child: Column(

                mainAxisAlignment: MainAxisAlignment.center,

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Text(

                    model.fullName,

                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),

                  ),

                  const SizedBox(height: 5),

                  Text(

                    builtIn ? '已内置 · 可直接制作' : '待导入壳图',

                    style: TextStyle(

                      fontSize: 11.5,

                      fontWeight: FontWeight.w600,

                      color: builtIn ? AppColors.accent : AppColors.textSub,

                    ),

                  ),

                ],

              ),

            ),

            Padding(

              padding: EdgeInsets.only(right: 16),

              child: Icon(Icons.chevron_right, color: AppColors.textSub),

            ),

          ],

        ),

      ),

    );

  }



  Widget _thumb() {

    // ① 优先用「正反展示图」（assets 里的 _display.png）
    final disp = kTemplateDisplayFile[model.templateId];
    if (disp != null && disp.isNotEmpty) {
      final vs = kColorVariants[model.templateId];
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            disp,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => _placeholder(),
          ),
          // 颜色圆点（取色的实色）
          if (vs != null && vs.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 1,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final c in vs)
                    Container(
                      width: 9,
                      height: 9,
                      margin: const EdgeInsets.symmetric(horizontal: 1.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(c.color),
                        border: Border.all(color: Colors.white, width: 1),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withValues(alpha: .10),
                              blurRadius: 2),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      );
    }

    // ② 回退：正面壳图
    if (builtIn && thumbPath != null && File(thumbPath!).existsSync()) {

      return Image.file(

        File(thumbPath!),

        fit: BoxFit.contain,

        cacheWidth: 120,

        errorBuilder: (_, _, _) => _placeholder(),

      );

    }

    return _placeholder();

  }



  Widget _placeholder() {

    return Container(

      decoration: BoxDecoration(

        gradient: LinearGradient(

          begin: Alignment.topLeft,

          end: Alignment.bottomRight,

          colors: [

            AppColors.fill,

            AppColors.fill,

          ],

        ),

      ),

      child: Center(

        child: Icon(Icons.smartphone_outlined, size: 30, color: AppColors.textFaint),

      ),

    );

  }

}



/// 自制模板卡（导入标定保存的模板）

class _CustomCard extends StatelessWidget {

  final ShellTemplate t;

  final VoidCallback onTap;

  final VoidCallback onLongPress;



  const _CustomCard({required this.t, required this.onTap, required this.onLongPress});



  @override

  Widget build(BuildContext context) {

    final hasImg = t.casePath.isNotEmpty && File(t.casePath).existsSync();

    return Stack(
      children: [
        GestureDetector(

      onTap: onTap,

      onLongPress: onLongPress,

      child: Container(

        height: 116,

        decoration: BoxDecoration(

          color: AppColors.card,

          borderRadius: BorderRadius.circular(16),

          boxShadow: [

            BoxShadow(

              color: Colors.black.withValues(alpha: .04),

              blurRadius: 10,

              offset: const Offset(0, 3),

            ),

          ],

        ),

        child: Row(

          children: [

            SizedBox(

              width: 96,

              child: Padding(

                padding: const EdgeInsets.all(10),

                child: ClipRRect(

                  borderRadius: BorderRadius.circular(12),

                  child: hasImg

                      ? Image.file(

                          File(t.casePath),

                          fit: BoxFit.contain,

                          cacheWidth: 120,

                          errorBuilder: (_, _, _) => _ph(),

                        )

                      : _ph(),

                ),

              ),

            ),

            Expanded(

              child: Column(

                mainAxisAlignment: MainAxisAlignment.center,

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Text(

                    t.name,

                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),

                  ),

                  const SizedBox(height: 5),

                  Row(

                    children: [

                      Text(

                        '${t.screenW}x${t.screenH} · R${t.cornerR}',

                        style: const TextStyle(

                          fontSize: 11.5,

                          fontWeight: FontWeight.w600,

                          color: AppColors.accent,

                        ),

                      ),

                      if (t.isTransparent) ...[

                        const SizedBox(width: 6),

                        Container(

                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),

                          decoration: BoxDecoration(

                            color: const Color(0xFF34C759).withValues(alpha: .12),

                            borderRadius: BorderRadius.circular(5),

                          ),

                          child: const Text(

                            '全透明',

                            style: TextStyle(

                              fontSize: 9.5,

                              fontWeight: FontWeight.w700,

                              color: Color(0xFF248A3D),

                            ),

                          ),

                        ),

                      ],

                    ],

                  ),

                ],

              ),

            ),

            Padding(

              padding: EdgeInsets.only(right: 16),

              child: Icon(Icons.chevron_right, color: AppColors.textSub),

            ),

          ],

        ),

      ),

    ),

        // 自制分组标签：右上角白色磨砂胶囊（抠图=蓝点 / 透明=紫点）
        Positioned(
          right: 10,
          top: 8,
          child: Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .86),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(
                  color: Colors.white.withValues(alpha: .95), width: 1.2),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: .10),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.isTransparent
                        ? const Color(0xFF7A4BFF)
                        : AppColors.accent,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  t.isTransparent ? '透明' : '抠图',
                  style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5A6478)),
                ),
              ],
            ),
          ),
        ),
      ],
    );

  }



  Widget _ph() {

    return Container(

      decoration: BoxDecoration(

        gradient: LinearGradient(

          begin: Alignment.topLeft,

          end: Alignment.bottomRight,

          colors: [AppColors.fill, AppColors.fill],

        ),

      ),

      child: Center(

        child: Icon(Icons.smartphone_outlined, size: 30, color: AppColors.textFaint),

      ),

    );

  }

}





/// 分组排序弹窗：拖拽排序 + 逐项隐藏 + 恢复默认顺序

class GroupSortSheet extends StatefulWidget {

  final List<String> order;

  final List<String> hidden;



  const GroupSortSheet({required this.order, required this.hidden});



  @override

  State<GroupSortSheet> createState() => GroupSortSheetState();

}



class GroupSortSheetState extends State<GroupSortSheet> {

  late List<String> _order = List<String>.from(widget.order);

  late Set<String> _hidden = widget.hidden.toSet();



  @override

  Widget build(BuildContext context) {

    return Container(

      margin: EdgeInsets.zero,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(24)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF7F9FD)],
        ),
        border: Border(
          top: BorderSide(color: glassCardBorder(), width: 1.5),
        ),
      ),

      child: Column(

        mainAxisSize: MainAxisSize.min,

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          const Text('分组排序',

              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),

          const SizedBox(height: 4),

          Text('前三个在悬浮底栏展示',

              style: TextStyle(fontSize: 11.5, color: AppColors.textSub)),

          const SizedBox(height: 10),

          SizedBox(

            height: _order.length * 46.0,

            child: ReorderableListView.builder(

              buildDefaultDragHandles: false,

              itemCount: _order.length,

              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = _order.removeAt(oldIndex);
                  _order.insert(newIndex, item);
                });
                Navigator.pop(
                    context, (List<String>.from(_order), _hidden.toList()));
              },

              itemBuilder: (context, i) {

                final name = _order[i];

                final off = i >= 3; // 第 4 个起变淡（前三个上底栏）

                return SizedBox(

                  key: ValueKey(name),

                  height: 46,

                  child: Row(

                    children: [

                      ReorderableDragStartListener(

                        index: i,

                        child: Padding(

                          padding: EdgeInsets.only(right: 10),

                          child: Icon(Icons.drag_handle,

                              size: 20, color: AppColors.textSub),

                        ),

                      ),

                      Expanded(

                        child: Text(

                          name,

                          style: TextStyle(

                            fontSize: 14,

                            fontWeight: FontWeight.w600,

                            color: off

                                ? AppColors.textFaint

                                : AppColors.text,

                          ),

                        ),

                      ),

                    ],

                  ),

                );

              },

            ),

          ),

          const SizedBox(height: 8),

          Row(

            children: [

              TextButton.icon(

                onPressed: () {
                  setState(() {
                    _order = List<String>.from(_kDefaultGroupOrder);
                    _hidden = <String>{};
                  });
                  Navigator.pop(
                      context, (List<String>.from(_order), <String>[]));
                },

                icon: const Icon(Icons.restart_alt, size: 18),

                label: const Text('恢复默认顺序'),

              ),

            ],

          ),

        ],

      ),

    );

  }

}



/// 分组默认顺序（与模板库内置顺序一致）

const List<String> _kDefaultGroupOrder = [

  '自制抠图',

  '常用',

  '自制透明',

  '华为',

  '小米',

  'OPPO',

  'vivo',

  '三星',

  '荣耀',

];


/// 打开「模板库排序」浮层（模板库页右上角 ≡ 已移除，入口在「我的 → 模板库排序」）
Future<void> showGroupSortSheet(BuildContext context) async {
  final safeTop = MediaQuery.paddingOf(context).top;
  final result = await showDialog<(List<String>, List<String>)>(
    context: context,
    barrierColor: Colors.black26,
    builder: (_) => Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 96),
        child: GroupSortSheet(
          order: _TplLibraryScreenState.currentGroupOrder(),
          hidden: gTplHidden.value,
        ),
      ),
    ),
  );
  if (result == null) return;
  final (order, hidden) = result;
  final s = await SettingsStore().load();
  await SettingsStore().save(AppSettings(
    background: s.background,
    quality: s.quality,
    hardware: s.hardware,
    fps: s.fps,
    autoSaveBg: s.autoSaveBg,
    navGlass: s.navGlass,
    navGlassOpacity: s.navGlassOpacity,
    themeMode: s.themeMode,
    tplGroups: order,
    tplHidden: hidden,
  ));
  gTplGroups.value = List<String>.from(order);
  gTplHidden.value = List<String>.from(hidden);
}

/// 模板库分组的当前顺序（供「设置 → 模板库排序」页面使用）
List<String> tplGroupOrder() => _TplLibraryScreenState.currentGroupOrder();
