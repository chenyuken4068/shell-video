import 'dart:ui' as ui;
import '../theme/app_theme.dart';

import 'live_trim_screen.dart';

import '../services/template_colors.dart';
import '../services/template_store.dart';
import 'compose_transparent_part.dart';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show compute;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:share_plus/share_plus.dart';

import '../models/shell_template.dart';
import '../services/app_settings.dart';
import '../services/composer.dart';

import '../services/app_log.dart';

import '../services/longshot_composer.dart';
import '../services/motion_photo_exporter.dart';

import '../services/motion_probe.dart';
import '../services/export_store.dart';
import '../services/video_info.dart';
import '../widgets/liquid_glass.dart';
import '../widgets/screen_hole_clipper.dart';
import 'library_screen.dart';

/// isolate 内旋转壳图（decode → 逆时针 90° → encode），返回空字节表示失败
Uint8List _rotateCasePng(Uint8List bytes) {
  try {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return Uint8List(0);
    final rot = img.copyRotate(decoded, angle: -90);
    return Uint8List.fromList(img.encodePng(rot));
  } catch (_) {
    return Uint8List(0);
  }
}

/// 合成台模式：所有合成能力集中在 ComposeScreen 一个页面，按需调用
enum ComposeMode {
  /// 视频创作（普通壳）
  video,
  /// 图片创作（普通壳）
  image,
  /// 实况创作（视频/动图 → 裁切 → 动态照片）
  live,
  /// 透明壳 · 视频
  transparentVideo,
  /// 透明壳 · 图片
  transparentImage,
}

/// 制作台：选视频 → 预览 → 导出带壳视频/截图
class ComposeScreen extends StatefulWidget {
  final ShellTemplate template;
  /// true = 图片创作（单帧图片合成，无截图按钮）；false = 视频合成台
  final bool imageMode;
  /// 合成模式（新增；imageMode 保留兼容）
  final ComposeMode mode;

  const ComposeScreen({
    super.key,
    required this.template,
    this.imageMode = false,
    this.mode = ComposeMode.video,
  });

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen>
    with SingleTickerProviderStateMixin, TransparentPart {
  /// 竖横切换：画布缩放与壳图旋转共用同一进度，严格同步
  static const _orientAnim = Duration(milliseconds: 380);
  static const _orientCurve = Curves.easeInOutCubic;

  String? _videoPath;
  String? _imagePath;
  VideoInfo? _info;
  /// 视频首帧缩略图：实时预览里贴到屏幕区域（图片模式直接用 _imagePath）
  String? _thumbPath;

  // 默认导出设置（来自我的页）
  Quality _quality = Quality.original;
  bool _hardware = true;
  int _fpsOverride = 0; // 0 = 原帧率（来自我的页设置）

  // 生成屏占比：标定框占成品画布比例（默认 0.9；调小四周加留白）
  double _ratio = 0.9;
  late double _ratioMax;
  // 画布宽高比（0 = 按屏占比自然比例=原尺寸）
  /// 画布比例：默认 9:16（进入即竖屏 9:16）
  double _canvasRatio = 9 / 16;
  /// 方向进度：0 = 竖屏，1 = 横屏（竖→横逆时针 90°，横→竖反向播放）
  late final AnimationController _orientCtrl;
  /// 画布比例切换动画：同一个画布尺寸连续插值（无淡入淡出）
  late final AnimationController _ratioCtrl;
  double _ratioFrom = 0;
  double _ratioTo = 0;

  bool _showGuide = true; // 坐标线

  // ── 长截图模式（仅图片创作）──
  bool _longMode = false;
  // 背景图是否镜像复制（上下翻转）铺满
  bool _bgMirror = true;

  // 设计壳位置偏移（画布像素，0=居中）
  double _shellDx = 0;
  double _shellDy = 0;
  bool _landscape = false; // 横屏合成模式
  late ShellTemplate _activeTemplate;
  ShellTemplate? _rotTemplate; // 旋转后的横屏壳图模板（缓存）
  Future<ShellTemplate>? _rotFuture; // 旋转任务（并发复用，避免重复旋转）
  bool _composing = false;
  double _progress = 0;
  String _progressText = '';
  bool _done = false;

  /// 实况裁切结果（live 模式）
  LiveTrimResult? _liveTrim;
  final List<String> _ffLog = []; // ffmpeg 日志缓存（失败时展示） // 合成完成态
  String? _donePath;

  @override
  void initState() {
    super.initState();
    _activeTemplate = widget.template;
    _initColors();
    _orientCtrl = AnimationController(
        vsync: this, duration: _orientAnim, value: 0)
      ..addStatusListener((_) {
        // 动画结束时重建一次：把“旋转中的壳图”换成已合成的预览图
        if (mounted) setState(() {});
      });
    // 画布比例动画（同一个画布尺寸连续插值）
    _ratioCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280), value: 1);
    // 滑块 = 设计壳缩放：25%~100%（默认 70%）；画布 = 壳框 ÷ 缩放 × 110%
    _ratioMax = 1.0;
    _ratio = 0.7;
    _loadDefaults();
    // 透明模式：预加载背景库（背景图圆卡数据源）
    if (widget.mode == ComposeMode.transparentVideo ||
        widget.mode == ComposeMode.transparentImage ||
        (widget.mode == ComposeMode.live && widget.template.isTransparent)) {
      loadBgLibrary();
    }
    // 自动取色（我的 → 通用设置）：默认用素材首帧当背景 + 模糊
    if (gAutoPickBg.value) {
      bgFromContent = true;
      bgBlurOn = true;
    }
    // 立即预生成横屏壳图（isolate 后台执行不卡 UI），就绪后刷新壳图显示
    _preRotate();
  }

  @override
  void dispose() {
    _orientCtrl.dispose();
    _ratioCtrl.dispose();
    super.dispose();
  }

  /// 预生成横屏旋转壳图并缓存：切换方向时零等待，避免卡顿
  Future<void> _preRotate() async {
    try {
      await _rotatedFor(true);
      if (mounted && _landscape) setState(() {});
    } catch (_) {
      _rotFuture = null; // 失败后允许重试
    }
  }

  /// 横屏壳图：竖版壳图逆时针旋转 90°，屏幕坐标同步变换（旋转在 isolate 执行，不卡 UI）
  Future<ShellTemplate> _rotatedFor(bool landscape) {
    if (!landscape) return Future.value(widget.template);
    final cached = _rotTemplate;
    if (cached != null) return Future.value(cached);
    return _rotFuture ??= _rotateCase(); // 并发调用复用同一任务
  }

  Future<ShellTemplate> _rotateCase() async {
    // 用【当前颜色】的竖版壳图旋转（否则切方向会把颜色覆盖回默认 ✗）
    final srcCase = _colorPaths[_colorSelId] ?? widget.template.casePath;
    final bytes = await File(srcCase).readAsBytes();
    final rotBytes = await compute(_rotateCasePng, bytes);
    if (rotBytes.isEmpty) return widget.template;
    final tmp = await getTemporaryDirectory();
    final rotPath = p.join(
        tmp.path,
        'rot_${widget.template.name}_${DateTime.now().millisecondsSinceEpoch}.png');
    await File(rotPath).writeAsBytes(rotBytes);
    final t = widget.template;
    // 逆时针90°：新宽=旧高，新高=旧宽；屏幕框同步旋转
    final rt = t.copyWith(
      casePath: rotPath,
      caseWidth: t.caseHeight,
      caseHeight: t.caseWidth,
      screenX: t.screenY,
      screenY: t.caseWidth - t.screenX - t.screenW,
      screenW: t.screenH,
      screenH: t.screenW,
    );
    _rotTemplate = rt;
    return rt;
  }

  Future<void> _switchOrient(bool land) async {
    if (_landscape == land) return;
    // 实时预览：切方向只要翻开关 + 起动画，画面立即跟着转（不用等合成）
    setState(() => _landscape = land);
    // 0 = 竖屏、1 = 横屏：竖→横逆时针 90°，横→竖顺时针 90°（同一进度反向播放）
    _orientCtrl.animateTo(land ? 1 : 0, duration: _orientAnim, curve: _orientCurve);
    try {
      final t = await _rotatedFor(land);
      if (!mounted || _landscape != land) return;
      setState(() => _activeTemplate = t);
    } catch (e) {
      _rotFuture = null; // 旋转失败：允许重试，并把动画/开关退回去
      _orientCtrl.animateTo(land ? 0 : 1, duration: _orientAnim, curve: _orientCurve);
      _toast('方向切换失败: $e');
      if (mounted) setState(() => _landscape = !land);
    }
  }

  Future<void> _loadDefaults() async {
    final s = await SettingsStore().load();
    if (!mounted) return;
    setState(() {
      _quality = s.quality;
      _hardware = s.hardware;
      _fpsOverride = s.fps;
    });
  }



  /// 保存到系统相册（按导出文件的实际类型选 putVideo / putImage）
  Future<void> _saveToAlbum() async {
    final out = _donePath;
    if (out == null) return;
    try {
      final ok = await Gal.requestAccess(toAlbum: false);
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('未获得相册访问权限，请在系统设置中允许访问照片和视频')));
        }
        return;
      }
      final lower = out.toLowerCase();
      final isVideoFile = lower.endsWith('.mp4') ||
          lower.endsWith('.mov') ||
          lower.endsWith('.m4v');
      if (isVideoFile) {
        await Gal.putVideo(out);
      } else {
        await Gal.putImage(out);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已保存到相册')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败: $e')));
      }
    }
  }

  /// 进「图库预览」：直接 push 刚导出这条的播放/查看页，
  /// 返回时回到合成台，设置与素材原样保留（不再 popUntil 把合成台销毁）
  void _openExportedPreview() {
    final out = _donePath;
    if (out == null) return;
    final lower = out.toLowerCase();
    final isVideoFile = lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isVideoFile
            ? VideoPlayerScreen(path: out, name: p.basename(out))
            : ImageViewerScreen(path: out, name: p.basename(out)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 取色背景用：把「当前素材首帧」（视频=抽帧结果）交给背景层
    bgContentPath = _contentPath;
    final t = widget.template;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 0,
        centerTitle: false,
        // 玻璃返回钮（同模板库）
        leadingWidth: 52,
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.fill,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.chevron_left,
                  size: 18, color: AppColors.text),
            ),
          ),
        ),
        // 玻璃顶栏：上实下虚（同模板库）
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
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
                  stops: const [0.0, 0.62, 0.88, 1.0],
                ),
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
        title: Text(
          widget.mode == ComposeMode.live
              ? '实况创作'
              : widget.imageMode
                  ? '图片创作'
                  : '视频创作',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ── 固定预览区（不随下方控件滚动）──
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween(begin: .94, end: 1.0).animate(anim),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey('pv_$_longMode'),
                    child: _longMode ? _buildLongPreview() : _buildPreviewCard(),
                  ),
                ),
              ),
              // ── 下方控件滚动区（方向栏跟随一起上滑）──
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 106),
                  children: [
                    // ── 模式切换：图片 / 长截图（仅图片创作）──
                    if (widget.imageMode) ...[
                      _buildModeSwitchCard(),
                      const SizedBox(height: 14),
                    ],
                    // ── 颜色切换（仅多配色模板）──
                    if (_colorVariants.length > 1) ...[
                      _buildColorCard(),
                      const SizedBox(height: 14),
                    ],
                    // ── 方向 + 画布比例（合并卡；长截图模式整卡隐藏，默认竖屏）──
                    ClipRect(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: _longMode
                            ? const SizedBox(width: double.infinity)
                            : Column(children: [
                                _buildOrientRatioCard(),
                                const SizedBox(height: 14),
                              ]),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildVideoCard(),
                  // ── 透明模式：背景面板（色块 / 背景图 / 背景库圆卡）──
                  // 所有创作模式（图片 / 视频 / 实况 / 长截图 / 透明）都用背景卡
                  if (_longMode ||
                      widget.mode == ComposeMode.video ||
                      widget.imageMode ||
                      widget.mode == ComposeMode.live ||
                      widget.mode == ComposeMode.transparentVideo ||
                      widget.mode == ComposeMode.transparentImage)
                    ClipRect(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                    const SizedBox(height: 14),
                    _sectionTitle('背景'),
                    const SizedBox(height: 8),
                    buildBgColorPalette(),
                    const SizedBox(height: 10),
                    buildBgImageRow(),
                    const SizedBox(height: 10),
                    buildBgBlurRow(),
                    // 长截图：背景镜像复制开关
                    if (_longMode) ...[
                      const SizedBox(height: 8),
                      Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.fillSoft,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('启用镜像复制背景',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.text)),
                            ),
                            Switch.adaptive(
                              value: _bgMirror,
                              activeColor: Colors.white,
                              activeTrackColor: AppColors.accent,
                              onChanged: (v) =>
                                  setState(() => _bgMirror = v),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // 有背景图时滑杆平滑展开
                    ClipRect(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: buildBgTransformRow(),
                      ),
                    ),
                  ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // ── 设计壳：缩放 + 水平/垂直位置（长截图模式收起）──
                    ClipRect(
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 280),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: _longMode
                            ? const SizedBox(width: double.infinity)
                            : Container(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: glassCardGradient(),
                        border: Border.all(
                            color: glassCardBorder(), width: 1.5),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('设计壳',
                              style: TextStyle(
                                  fontSize: 13.5, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 12),
                          _shellSlider(
                            label: '缩放',
                            value: (_ratio - 0.25) / (1.0 - 0.25),
                            text: '${(_ratio * 100).toStringAsFixed(0)}%',
                            onChanged: _composing
                                ? null
                                : (v) => setState(() {
                                      _ratio = 0.25 + v * 0.75;
                                      _shellDx = _shellDx.clamp(-_shellMaxDx, _shellMaxDx);
                                      _shellDy = _shellDy.clamp(-_shellMaxDy, _shellMaxDy);
                                    }),
                          ),
                          _shellSlider(
                            label: '水平位置',
                            value: (_shellDx + _shellMaxDx) /
                                (2 * math.max(_shellMaxDx, .001)),
                            text: '${(((_shellDx + _shellMaxDx) / (2 * math.max(_shellMaxDx, .001))) * 100).round()}%',
                            onChanged: _composing
                                ? null
                                : (v) => setState(() => _shellDx =
                                    (v * 2 - 1) * _shellMaxDx),
                          ),
                          _shellSlider(
                            label: '垂直位置',
                            value: (_shellDy + _shellMaxDy) /
                                (2 * math.max(_shellMaxDy, .001)),
                            text: '${(((_shellDy + _shellMaxDy) / (2 * math.max(_shellMaxDy, .001))) * 100).round()}%',
                            onChanged: _composing
                                ? null
                                : (v) => setState(() => _shellDy =
                                    (v * 2 - 1) * _shellMaxDy),
                          ),
                        ],
                      ),
                    ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // 底部操作栏（液态玻璃，上移 10：bottom 8 → 18）
          Positioned(
            left: 14,
            right: 14,
            bottom: 18,
            child: _buildActionBar(),
          ),
        ],
      ),
    );
  }

  // ---------- 预览 ----------
  /// 画布尺寸 + 壳在画布内位置（随方向、屏占比、画布比例变化；与合成一致）
  (int, int, int, int) _canvasFor(ShellTemplate t) {
    // 画布 = 壳框 ÷ 缩放 × 110%；壳框 = 屏幕框每边外扩「屏幕框宽 × 6%」
    final pad = (t.screenW * 0.06).round();
    final shellW = t.screenW + pad * 2;
    final shellH = t.screenH + pad * 2;
    var bw = shellW / _ratio * 1.1;
    var bh = shellH / _ratio * 1.1;
    // 画布比例在横屏必须取倒数：横屏模板 = 竖屏模板逆时针转 90°，
    // 竖屏选 9:16 → 横屏就是 16:9。否则横屏画布按竖屏比例算（宽高互换），
    // 壳在画布里只占很小一块 → 预览看着“横屏壳太小”
    final cr = _canvasRatio <= 0
        ? 0.0
        : (t.caseWidth > t.caseHeight ? 1 / _canvasRatio : _canvasRatio);
    if (cr > 0) {
      if (bw / bh > cr) {
        bh = bw / cr;
      } else {
        bw = bh * cr;
      }
    }
    var cw = bw.round();
    var ch = bh.round();
    if (cw.isOdd) cw += 1;
    if (ch.isOdd) ch += 1;
    // 壳在画布居中 → 反推壳图左上角位置
    final ccx = ((cw - shellW) / 2).round() - (t.screenX - pad);
    final ccy = ((ch - shellH) / 2).round() - (t.screenY - pad);
    return (cw, ch, ccx, ccy);
  }

  /// 内容素材的真实尺寸（用于判断横竖）
  Size? _contentSize;
  String? _contentSizePath;

  /// 探测内容素材尺寸（图片/视频首帧/动图首帧都适用）
  Future<void> _probeContentSize(String? path) async {
    if (path == null || path == _contentSizePath) return;
    _contentSizePath = path;
    try {
      final b = await File(path).readAsBytes();
      final codec = await ui.instantiateImageCodec(b);
      final f = await codec.getNextFrame();
      final sz = Size(f.image.width.toDouble(), f.image.height.toDouble());
      f.image.dispose();
      codec.dispose();
      if (mounted) setState(() => _contentSize = sz);
    } catch (_) {
      if (mounted) setState(() => _contentSize = null);
    }
  }

  /// 内容需要旋转的 90° 次数（结合画布方向）
  /// 横屏画布 + 竖屏素材 → 逆时针 90°（quarterTurns = 3）
  /// 竖屏画布 + 横屏素材 → 顺时针 90°（quarterTurns = 1）
  int get _contentTurns {
    final sz = _contentSize;
    if (sz == null || sz.width <= 0 || sz.height <= 0) return 0;
    final mediaPortrait = sz.height >= sz.width;
    final canvasPortrait = !_landscape;
    if (!canvasPortrait && mediaPortrait) return 3; // 逆时针 90°
    if (canvasPortrait && !mediaPortrait) return 1; // 顺时针 90°
    return 0;
  }

  /// 实时预览里要贴进屏幕区域的内容：图片模式用原图，视频模式用抽出来的首帧
  String? get _contentPath {
    final p = widget.imageMode ? _imagePath : _thumbPath;
    _probeContentSize(p);
    return p;
  }

  /// 预览卡：画布框（背景铺满）+ 壳/内容实时渲染，屏占比 / 画布比例 / 方向立即反映
  /// 切换画布比例：同一个画布连续插值（不淡入淡出、不换 widget）
  void _pickCanvasRatio(double v) {
    if ((_canvasRatio - v).abs() < 1e-6) return;
    _ratioFrom = _canvasRatio;
    _ratioTo = v;
    _ratioCtrl.forward(from: 0);
    setState(() => _canvasRatio = v);
  }
  /// 自定义画布比例（宽 : 高）
  Future<void> _pickCustomRatio() async {
    final wCtrl = TextEditingController(text: '9');
    final hCtrl = TextEditingController(text: '16');
    final r = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自定义比例'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: wCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '宽'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text(':', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            Expanded(
              child: TextField(
                controller: hCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '高'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              final w = double.tryParse(wCtrl.text.trim()) ?? 0;
              final h = double.tryParse(hCtrl.text.trim()) ?? 0;
              if (w <= 0 || h <= 0) return;
              Navigator.pop(ctx, w / h);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (r != null && mounted) _pickCanvasRatio(r);
  }


  /// 画布宽高比（可传入比例做动画插值，公式与 _canvasFor 一致）
  double _canvasAspect(ShellTemplate t, double crRaw) {
    final pad = (t.screenW * 0.06).round();
    final shellW = t.screenW + pad * 2;
    final shellH = t.screenH + pad * 2;
    var bw = shellW / _ratio * 1.1;
    var bh = shellH / _ratio * 1.1;
    final cr = crRaw <= 0 ? 0.0 : (t.caseWidth > t.caseHeight ? 1 / crRaw : crRaw);
    if (cr > 0) {
      if (bw / bh > cr) {
        bh = bw / cr;
      } else {
        bw = bh * cr;
      }
    }
    return bh / bw;
  }

  /// 预览卡：整个卡放进比例动画里重建 → 同一画布连续缩放
  Widget _buildPreviewCard() => AnimatedBuilder(
        animation: _ratioCtrl,
        builder: (context, _) => _buildPreviewCardBody(),
      );

  Widget _buildPreviewCardBody() {
    final w = MediaQuery.of(context).size.width;
    // ⚠️ 预览几何必须用【竖版未旋转】模板：
    //    _activeTemplate 在横屏时是「预旋转过的横版模板」（_rotateCase），
    //    预览外层还会用 Transform.rotate(angle) 再转一次 → 两次叠加 = 180° ✗
    final t0 = widget.template; // 竖屏模板（壳+内容坐标基准）
    final (cw0, ch0, _, _) = _canvasFor(t0);
    // 竖屏画布宽高比（横屏画布 = 竖屏画布转 90°，比例取倒数）
    // 画布比例动画：从 _ratioFrom 连续插值到 _ratioTo（同一个画布 ✓）
    final crNow = _ratioFrom +
        (_ratioTo - _ratioFrom) *
            Curves.easeOutCubic.transform(_ratioCtrl.value.clamp(0.0, 1.0));
    final r0 = _ratioCtrl.value >= 1.0 ? ch0 / cw0 : _canvasAspect(t0, crNow);
    final content = _contentPath;
    final hasContent =
        widget.imageMode ? _imagePath != null : _videoPath != null;

    return LayoutBuilder(
      builder: (context, cons) {
        // 目标场景判定：只有「横屏 + 画布比例 16:9」才做特殊处理，其它比例完全不动
        final is169 = (_landscape && (_canvasRatio - 16 / 9).abs() < 0.001);
        // 预览区可用高度：预览卡在 Column 里是非弹性子节点，LayoutBuilder 的 maxHeight
        // 是无界的 → 正常场景保持「不设上限」，卡片尺寸和以前完全一样（不受影响）。
        // 只有「横屏 + 画布横向」这一种情况（横屏选 16:9），卡片高度会被宽度
        // 算成整屏高，才用真实屏高兜底收一下。
        // 目标场景：**只有**「横屏 + 画布比例选 16:9」这一个组合（别的比例一律不动）
        final halfWideCanvas = is169;
        final mediaH = MediaQuery.sizeOf(context).height;
        final availH = (halfWideCanvas
                ? mediaH * 0.55
                : (cons.maxHeight.isFinite ? cons.maxHeight : double.infinity)) -
            8;
        // 只有「横屏 + 16:9」时，这块大画布会把预览撑满屏 → 预览整体按 3/4 显示
        //（画布和手机一起缩）；导出仍用完整画布，手机上小一点没关系，能看到整体效果即可
        final pvHalf = is169 ? 0.75 : 1.0;
        // 竖屏：9:16 等原比例，高度上限 56% 防超高
        final portH =
            math.min(math.min(236.0, (w - 28) * 0.62) * r0, availH * 0.56) *
                pvHalf;
        final portW = portH / r0;
        // 横屏：画布比例 = 竖屏比例交换（9:16 → 16:9），仅做尺寸缩放
        final landH = math.min((w - 28) / r0, availH * 0.56) * pvHalf;
        final landW = landH * r0;
        final s0 = portW / cw0; // 竖屏：画布 → 预览缩放
        final s1 = landW / ch0; // 横屏：画布转 90° 后的预览缩放

        return Center(
          child: AnimatedBuilder(
            animation: _orientCtrl,
            builder: (context, _) {
              final p = _orientCtrl.value;
              final boxW = portW + (landW - portW) * p;
              final boxH = portH + (landH - portH) * p;
              // 插值的是“缩放”而不是壳的宽高：壳图原始比例必须始终保持，
              // 分开插值宽度/高度会把壳在旋转中途拉扁
              final s = s0 + (s1 - s0) * p;
              // 目标尺寸（旋转前）
              final aw = t0.caseWidth * s;
              final ah = t0.caseHeight * s;
              // 1) 布局尺寸：先按能装进卡框的同比例尺寸摆好
              //    Stack 给非 Positioned 子组件的是松约束（max = 卡框），
              //    横屏卡框矮，竖版壳图（高>卡框高）会被夹矮 → 壳缩掉一半
              final rCase = t0.caseWidth / t0.caseHeight;
              final fitH = math.min(boxW / rCase, boxH);
              final fitW = fitH * rCase;
              final angle = -math.pi / 2 * p;
              final ca = math.cos(angle).abs();
              final sa = math.sin(angle).abs();
              // 2) 中间角度外接矩形可能溢出，收拢系数 ≤1（两端恒为 1，不跳变）
              final kFit = math.min(
                1.0,
                math.min(
                  boxW / (aw * ca + ah * sa),
                  boxH / (aw * sa + ah * ca),
                ),
              );
              // 3) 布局尺寸 → 目标尺寸（同比例放大）+ 收拢
              final k = (aw / fitW) * kFit;
              final sInner = fitW / t0.caseWidth; // 壳内坐标 → 布局尺寸
              // 内容层画在卡框坐标系里（不随外壳旋转 → 永远正立，和导出一致）：
              // 位置 = 屏幕洞中心被外壳转过 angle 之后的位置；
              // 外接框 = 旋转后洞的包围盒（两端恰好等于洞，中间角度略大以保证盖满）
              // 严格按标定值，不做任何内缩
              final holeW = t0.screenW * sInner;
              final holeH = t0.screenH * sInner;
              final ct = math.cos(angle);
              final st = math.sin(angle);
              final offX =
                  ((t0.screenX + t0.screenW / 2) - t0.caseWidth / 2) * sInner * k;
              final offY =
                  ((t0.screenY + t0.screenH / 2) - t0.caseHeight / 2) * sInner * k;
              final holeCx = boxW / 2 + offX * ct - offY * st;
              final holeCy = boxH / 2 + offX * st + offY * ct;
              final holeBw = (holeW * ct.abs() + holeH * st.abs()) * k;
              final holeBh = (holeW * st.abs() + holeH * ct.abs()) * k;

          // 同一个画布：尺寸随比例动画连续变化（已删除淡入淡出）
          return Container(
              width: boxW,
              height: boxH,
            decoration: BoxDecoration(
              gradient: glassCardGradient(),
        border: Border.all(color: glassCardBorder(), width: 1.5),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .05),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 背景（画布，纯色）
                Positioned.fill(child: _buildBg()),
                // 内容层：卡框坐标系里画、永不旋转 → 视频/图片始终正立（= 导出结果：
                // 壳转、内容不转，横屏时横视频按横屏比例裁切填满屏幕），
                // 再用 ScreenHoleClipper 裁成当前角度下的屏幕形状
                // 内容 + 壳：共用【同一个】位移，单坐标系保证永远贴合
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(_shellDx * s, _shellDy * s),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 内容层：不旋转（永远正立，和导出一致），裁成屏幕形状
                        if (content != null)
                          Positioned(
                            left: holeCx - holeBw / 2,
                            top: holeCy - holeBh / 2,
                            width: holeBw,
                            height: holeBh,
                            child: ClipPath(
                              clipper: ScreenHoleClipper(
                                width: holeW * k,
                                height: holeH * k,
                                angle: angle,
                                radius: t0.cornerR * sInner * k,
                  // 与导出 CornerMask 一致：圆弧圆心外扩 5px（按预览缩放）
                  outset: 5 * sInner * k,
                              ),
                              child: RotatedBox(
  quarterTurns: _contentTurns,
  child: Image.file(
                                File(content),
                                fit: BoxFit.cover,
                                cacheWidth: 480,
                                gaplessPlayback: true,
                                errorBuilder: (_, _, _) =>
                                    const SizedBox.shrink(),
                              ))  ,
                            ),
                          ),
                        // 外壳：随方向实时旋转（p=1 正好等于横屏旋转壳图）
                        Transform.rotate(
                          angle: angle,
                          child: Transform.scale(
                            scale: k,
                            child: SizedBox(
                              width: fitW,
                              height: fitH,
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: _buildCaseImage(
                    _colorPaths[_colorSelId] ?? widget.template.casePath),
                                  ),
                                  if (_showGuide)
                                    Positioned.fill(
                                        child: CustomPaint(
                                            painter: _GuidePainter(t: t0))),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // 未选素材：壳图下方提示
                if (!hasContent)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 12,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.card.withValues(alpha: .85),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.mode == ComposeMode.live
                              ? '选择视频 / 动图开始制作'
                              : widget.imageMode
                                  ? '选择图片开始制作'
                                  : '选择视频开始制作',
                          style: TextStyle(
                              fontSize: 10.5, color: AppColors.textSub),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
            },
          ),
        );
      },
    );
  }

  /// 壳图：始终传竖屏壳图，旋转由外层 Transform 负责
  Widget _buildCaseImage(String path) {
    final f = File(path);
    if (!f.existsSync()) return const SizedBox.shrink();
    return Image.file(
      f,
      // 必须 fill：壳图与孔位计算共用 fitW×fitH，contain 留边会让内容偏移
      fit: BoxFit.fill,
      cacheWidth: 480,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }

  // ---------- 方向切换（竖屏 / 横屏） ----------

  /// 方向与画布比例（合并卡）：左 30% 竖屏/横屏上下排，白线分隔，右 70% 比例 3x2

  /// 设计壳可移动半范围（四周留 8px 安全边）
  double get _shellMaxDx {
    final (cw0, _, _, _) = _canvasFor(widget.template);
    return math.max(0.0, (cw0 - cw0 * _ratio) / 2 - 8);
  }

  double get _shellMaxDy {
    final (_, ch0, _, _) = _canvasFor(widget.template);
    return math.max(0.0, (ch0 - ch0 * _ratio) / 2 - 8);
  }


  /// 设计壳里的一行滑杆（左标签 / 右百分比）
  Widget _shellSlider({
    required String label,
    required double value,
    required String text,
    required ValueChanged<double>? onChanged,
  }) {
    // 同一平面：标签 ─ 滑轨 ─ 百分比
    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: AppColors.textSub),
          ),
        ),
        Expanded(
          child: Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged),
        ),
        SizedBox(
          width: 44,
          child: Text(
            text,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.accent,
            ),
          ),
        ),
      ],
    );
  }



  // ── 长截图：预览缓存 ──
  Future<Uint8List>? _longFuture;
  String _longKey = '';

  /// 生成长截图（按内容/背景/镜像开关变化重新生成）
  Future<Uint8List> _longBytes() {
    final key = [
      _imagePath ?? '',
      bgImagePath ?? '',
      bgFromContent ? (bgContentPath ?? '') : '',
      _bgMirror.toString(),
      bgColor.toARGB32().toString(),
      // 模糊开关 / 强度必须参与缓存 key，否则滑杆调节后预览不刷新
      bgBlurOn.toString(),
      bgBlurSigma.toStringAsFixed(1),
    ].join('|');
    if (_longFuture == null || key != _longKey) {
      _longKey = key;
      _longFuture = LongshotComposer.compose(
        template: widget.template,
        contentPath: _imagePath!,
        bgImagePath: bgFromContent ? bgContentPath : bgImagePath,
        bgColor: bgColor.toARGB32(),
        bgMirror: _bgMirror,
        bgBlur: bgBlurOn,
        bgBlurSigma: bgBlurSigma,
        shellRatio: 0.8,
      );
    }
    return _longFuture!;
  }

  /// 长截图预览：整张画布（背景 + 壳 80% + 安全边），可上下滚动
  Widget _buildLongPreview() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
        height: 420,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: AppColors.fillSoft,
        ),
        clipBehavior: Clip.antiAlias,
        child: _imagePath == null
            ? Center(
                child: Text('选择一张长截图后显示画布预览',
                    style: TextStyle(fontSize: 12, color: AppColors.textSub)),
              )
            : FutureBuilder<Uint8List>(
                future: _longBytes(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: .94, end: 1),
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, child) =>
                        Transform.scale(scale: v, child: child),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: SingleChildScrollView(
                            // 按宽度铺满 = 整张画布（含左右/上下安全边）
                            child: Image.memory(snap.data!,
                                fit: BoxFit.fitWidth),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: .85),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Text('↕ 上下滑动看完整画布',
                                style: TextStyle(
                                    fontSize: 10, color: Color(0xFF7A8398))),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  /// 导出长截图（PNG）
  Future<void> _exportLong() async {
    if (_imagePath == null) return;
    setState(() {
      _composing = true;
      _progress = 0.1;
    });
    try {
      final bytes = await LongshotComposer.compose(
        template: widget.template,
        contentPath: _imagePath!,
        bgImagePath: bgFromContent ? bgContentPath : bgImagePath,
        bgColor: bgColor.toARGB32(),
        bgMirror: _bgMirror,
        bgBlur: bgBlurOn,
        bgBlurSigma: bgBlurSigma,
        shellRatio: 0.8,
      );
      final outDir = await getApplicationDocumentsDirectory();
      final dir = Directory(p.join(outDir.path, 'outputs'));
      if (!await dir.exists()) await dir.create(recursive: true);
      final name = 'long_${DateTime.now().millisecondsSinceEpoch}.png';
      final f = File(p.join(dir.path, name));
      await f.writeAsBytes(bytes, flush: true);
      await Gal.putImage(f.path, album: 'ShellVideo');
      if (!mounted) return;
      setState(() {
        _progress = 1;
        _composing = false;
        _done = true;
        _donePath = f.path;
      });
      AppLog.i('长截图导出: ${f.path} (${bytes.length} 字节)');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _composing = false;
        _progress = 0;
      });
      _toast('长截图导出失败: $e');
    }
  }


  // ── 多颜色切换 ──
  List<ColorVariant> _colorVariants = const [];
  String _colorSelId = '';
  Map<String, String> _colorPaths = {};

  void _initColors() {
    final vs = kColorVariants[widget.template.id];
    if (vs == null || vs.length < 2) return;
    _colorVariants = vs;
    _colorSelId = vs.first.templateId;
    _loadColorPaths();
  }

  Future<void> _loadColorPaths() async {
    try {
      final list = await TemplateStore().load();
      final m = <String, String>{};
      for (final v in _colorVariants) {
        for (final e in list) {
          if (e.id == v.templateId) m[v.templateId] = e.casePath;
        }
      }
      if (mounted) setState(() => _colorPaths = m);
    } catch (e) {
      AppLog.i('加载颜色壳图失败: $e');
    }
  }

  Future<void> _pickColor(ColorVariant v) async {
    if (v.templateId == _colorSelId) return;
    var path = _colorPaths[v.templateId];
    if (path == null) {
      await _loadColorPaths();
      path = _colorPaths[v.templateId];
    }
    if (path == null) {
      try {
        final list = await TemplateStore().load();
        for (final e in list) {
          if (e.id == v.templateId) path = e.casePath;
        }
      } catch (_) {}
    }
    AppLog.i('切色 ${v.name} tplId=${v.templateId} path=$path');
    if (path == null || !mounted) return;
    // ⚠️ 只换壳图，不动方向/旋转（横屏切色必须保持横屏）
    setState(() {
      _colorSelId = v.templateId;
      _activeTemplate = widget.template.withCasePath(path!);
    });
  }

  /// 颜色切换卡（≥2 色才显示）
  Widget _buildColorCard() {
    if (_colorVariants.length < 2) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: glassCardGradient(),
        border: Border.all(color: glassCardBorder(), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('颜色',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final v in _colorVariants)
                Expanded(
                  child: GestureDetector(
                    onTap: _composing ? null : () => _pickColor(v),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: v.templateId == _colorSelId
                                  ? AppColors.accent
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  _lighten(Color(v.color), .28),
                                  Color(v.color),
                                  _darken(Color(v.color), .18),
                                ],
                              ),
                              border: Border.all(
                                  color: Colors.white.withValues(alpha: .9),
                                  width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          v.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: v.templateId == _colorSelId
                                ? FontWeight.w800
                                : FontWeight.w700,
                            color: v.templateId == _colorSelId
                                ? AppColors.accent
                                : AppColors.textSub,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _lighten(Color c, double t) {
    int ch(double v) => (v * 255).round().clamp(0, 255);
    return Color.fromARGB(ch(c.a), ch(c.r + (1 - c.r) * t),
        ch(c.g + (1 - c.g) * t), ch(c.b + (1 - c.b) * t));
  }

  static Color _darken(Color c, double t) {
    int ch(double v) => (v * 255).round().clamp(0, 255);
    return Color.fromARGB(
        ch(c.a), ch(c.r * (1 - t)), ch(c.g * (1 - t)), ch(c.b * (1 - t)));
  }

  /// 模式切换卡：图片 / 长截图（仅图片创作显示）
  Widget _buildModeSwitchCard() {
    Widget seg(String label, bool on, VoidCallback onTap) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: on ? const Color(0xFFEAF2FF) : AppColors.fillSoft,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(
                color: on
                    ? AppColors.accent.withValues(alpha: .25)
                    : Colors.transparent,
                width: .5,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: on ? AppColors.accent : AppColors.textSub,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: glassCardGradient(),
        border: Border.all(color: glassCardBorder(), width: 1.5),
      ),
      child: Row(
        children: [
          seg('图片', !_longMode, () {
            if (_longMode) setState(() => _longMode = false);
          }),
          const SizedBox(width: 10),
          seg('长截图', _longMode, () {
            if (!_longMode) {
              setState(() {
                _longMode = true;
                _ratio = 0.8;
                _shellDx = 0;
                _shellDy = 0;
              });
              _switchOrient(false);
            }
          }),
        ],
      ),
    );
  }

  Widget _buildOrientRatioCard() {
    final portrait = !_landscape;
    // 顺序固定（不随方向变化）
    const labels = ['9:16', '3:4', '4:3', '1:1', '16:9', 'A4', 'A4横', '自定义'];
    const ratios = [
      9 / 16, 3 / 4, 4 / 3, 1 / 1,
      16 / 9, 1 / 1.414, 1.414 / 1, -1.0 /* 自定义 */
    ];

    Widget orientBtn(String label, IconData icon, bool on, VoidCallback tap) {
      return GestureDetector(
        onTap: _composing ? null : tap,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: on ? const Color(0xFFEAF2FF) : const Color(0xFFF2F4F8),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: on
                  ? AppColors.accent.withValues(alpha: .45)
                  : Colors.transparent,
              width: on ? 0.5 : 0,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 12,
                  color: on ? AppColors.accent : AppColors.textSub),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: on ? AppColors.accent : AppColors.textSub,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget ratioBtn(int i) {
      // 第 8 个 = 自定义比例
      if (ratios[i] < 0) {
        return GestureDetector(
          onTap: _composing ? null : _pickCustomRatio,
          child: Container(
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F8),
              borderRadius: BorderRadius.circular(19),
            ),
            child: Text(labels[i],
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSub)),
          ),
        );
      }
      final on = (_canvasRatio - ratios[i]).abs() < 0.02;
      return GestureDetector(
        onTap: _composing ? null : () => _pickCanvasRatio(ratios[i]),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? const Color(0xFFEAF2FF) : const Color(0xFFF2F4F8),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: on
                  ? AppColors.accent.withValues(alpha: .42)
                  : Colors.transparent,
              width: on ? 0.5 : 0,
            ),
          ),
          child: Text(
            labels[i],
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: on ? AppColors.accent : AppColors.textSub,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: glassCardGradient(),
        border: Border.all(color: glassCardBorder(), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '方向与画布比例',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左 30%：竖屏 / 横屏
              SizedBox(
                width: 90,
                child: Column(
                  children: [
                    orientBtn('竖屏', Icons.crop_portrait, portrait,
                        () => _switchOrient(false)),
                    const SizedBox(height: 8),
                    orientBtn('横屏', Icons.crop_landscape, !portrait,
                        () => _switchOrient(true)),
                  ],
                ),
              ),
              // 白分隔线
              Container(
                width: 1,
                height: 84,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: const Color(0xFFF0F3F9),
              ),
              // 右 70%：比例 3x2
              Expanded(
                child: Column(
                  children: [
                    Row(children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(child: ratioBtn(i)),
                      ],
                    ]),
                    const SizedBox(height: 8),
                    Row(children: [
                      for (var i = 3; i < 6; i++) ...[
                        if (i > 3) const SizedBox(width: 8),
                        Expanded(child: ratioBtn(i)),
                      ],
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageCard() {
    if (_imagePath == null) {
      return GestureDetector(
        onTap: _composing ? null : _pickImage,
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            gradient: glassCardGradient(),
        border: Border.all(color: glassCardBorder(), width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: .1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.image_outlined, size: 17, color: AppColors.accent),
              ),
              const SizedBox(width: 10),
              const Text(
                '选择本地图片',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.accent),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: glassCardGradient(),
        border: Border.all(color: glassCardBorder(), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.image_outlined, size: 20, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              p.basename(_imagePath!),
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton(
            onPressed: _composing ? null : _pickImage,
            child: const Text('更换', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ---------- 素材选择（视频 / 图片） ----------
  /// 重新裁切（实况模式）
  Future<void> _retrim() async {
    final path = _videoPath;
    if (path == null) return;
    final trim = await Navigator.push<LiveTrimResult>(
      context,
      MaterialPageRoute(builder: (_) => LiveTrimScreen(videoPath: path)),
    );
    if (trim != null && mounted) setState(() => _liveTrim = trim);
  }

  Widget _buildVideoCard() {
    if (widget.imageMode) return _buildImageCard();
    if (_videoPath == null) {
      return GestureDetector(
        onTap: _composing ? null : _pickVideo,
        child: Container(
          height: 62,
          decoration: BoxDecoration(
            gradient: glassCardGradient(),
        border: Border.all(color: glassCardBorder(), width: 1.5),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: .1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.video_library_outlined, size: 17, color: AppColors.accent),
              ),
              const SizedBox(width: 10),
              const Text(
                '选择本地视频',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.accent),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: glassCardGradient(),
        border: Border.all(color: glassCardBorder(), width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.movie_outlined, size: 20, color: AppColors.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.basename(_videoPath!),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_liveTrim != null) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.accent.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '实况 ${_liveTrim!.startSec.toStringAsFixed(1)}s ~ '
                          '${_liveTrim!.endSec.toStringAsFixed(1)}s · '
                          '封面 ${_liveTrim!.coverSec.toStringAsFixed(1)}s',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _composing ? null : _retrim,
                        child: const Text(
                          '重新裁切',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.accent,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_info != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _InfoTag(_info!.resolutionLabel),
                      const SizedBox(width: 6),
                      Text(
                        '${_info!.width}×${_info!.height} · ${_info!.durationLabel}',
                        style: TextStyle(fontSize: 10.5, color: AppColors.textSub),
                      ),
                      if (_info!.durationSeconds > 1800) ...[
                        const SizedBox(width: 6),
                        const Text(
                          '超30分钟',
                          style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: _composing ? null : _pickVideo,
            child: const Text('更换', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ---------- 底部操作栏 ----------
  Widget _buildActionBar() {
    // 操作栏：总高60、按钮显式高50、上下各5、左右各10（与外圈对齐）
    // 液态玻璃：比主底栏更实一点（要压住按钮、保证可读），原实现是
    // 「白色88%外壳 + 内部14圆角BackdropFilter」两层，这里合成一层
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        height: 64,
        child: LiquidGlass(
          borderRadius: 32,
          blur: 20,
          tint: const [Color(0xE8FFFFFF), Color(0xD9FFFFFF)],
          child: Padding(
            padding: const EdgeInsets.all(7),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _composing
                ? _buildProgressPill()
                : (_done ? _buildDoneBar() : _buildIdleBar()),
          ),
          ),
        ),
      ),
    );
  }


  // ── 底栏形态 ①：待导出 ──
  Widget _buildIdleBar() {
    return Row(
      key: const ValueKey('idle'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widget.imageMode
          ? [
              Expanded(
                child: _ActionBtn(
                  icon: Icons.image_outlined,
                  label: _longMode ? '导出带壳长图' : '导出带壳图片',
                  enabled: _imagePath != null,
                  onTap: _exportImage,
                  primary: true,
                ),
              ),
            ]
          : [
              Expanded(
                child: _ActionBtn(
                  icon: widget.mode == ComposeMode.live
                      ? Icons.motion_photos_on_outlined
                      : Icons.movie_outlined,
                  label: widget.mode == ComposeMode.live ? '导出动态照片' : '导出带壳视频',
                  enabled: _canExport,
                  onTap: _exportVideo,
                  primary: true,
                ),
              ),
            ],
    );
  }

  // ── 底栏形态 ②：充电式进度胶囊 ──
  Widget _buildProgressPill() {
    final v = _progress.clamp(0.0, 1.0);
    // 进度条动画：从当前显示位置平滑增长到目标值（不跳变）
    return TweenAnimationBuilder<double>(
      key: const ValueKey('progress'),
      tween: Tween<double>(begin: 0, end: v),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      builder: (context, av, _) => _progressBar(av),
    );
  }

  Widget _progressBar(double v) {
    final pct = (v * 100).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color(0xFFEAF3EA)),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: v,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF5BD97A), Color(0xFF34C759)],
                ),
              ),
            ),
          ),
          Center(
            child: Text(
              '$pct%',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1E7B38),
                letterSpacing: .5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 底栏形态 ③：完成（左导出 + 右三圆）──
  Widget _buildDoneBar() {
    // 图片创作（含长截图）导出图片，视频/实况导出视频 —— 不能一律显示「导出带壳视频」
    final isImg = widget.imageMode;
    return Row(
      key: const ValueKey('done'),
      children: [
        Expanded(
          child: _ActionBtn(
            icon: isImg
                ? Icons.image_outlined
                : (widget.mode == ComposeMode.live
                    ? Icons.motion_photos_on_outlined
                    : Icons.movie_outlined),
            label: isImg
                ? (_longMode ? '导出带壳长图' : '导出带壳图片')
                : (widget.mode == ComposeMode.live
                    ? '导出动态照片'
                    : '导出带壳视频'),
            enabled: true,
            onTap: isImg ? _exportImage : _exportVideo,
            primary: true,
          ),
        ),
        const SizedBox(width: 8),
        _CircleBtn(
          icon: Icons.download_outlined,
          label: '保存',
          onTap: () => _saveToAlbum(),
        ),
        const SizedBox(width: 8),
        _CircleBtn(
          icon: Icons.ios_share,
          label: '分享',
          onTap: () => _shareFile(_donePath!, '已生成'),
        ),
        const SizedBox(width: 8),
        _CircleBtn(
          icon: Icons.photo_library_outlined,
          label: '图库',
          active: true,
          onTap: _openExportedPreview,
        ),
      ],
    );
  }

  bool get _canExport => _videoPath != null && _info != null && !_composing;

  // ---------- 背景 / 屏占比 / 画布比例 ----------

  Widget _sectionTitle(String s) => Text(
        s,
        style: TextStyle(
            fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.text),
      );

  Widget _ratioChip(String label, double value) {
    final active = (_canvasRatio - value).abs() < 0.001;
    return GestureDetector(
      onTap: _composing ? null : () => _pickCanvasRatio(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.accent : AppColors.fill,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.textSub,
          ),
        ),
      ),
    );
  }

  /// 背景：始终用页面设置的纯色（白/黑）
  // 背景手势起始值
  double _bgStartScale = 1;

  /// 预览画布背景（沿用旧透明台逻辑）
  /// · 背景图按「卡框实际尺寸」算 cover，再留 1% 余量 → 永远不会露白
  /// · 偏移 _bgDx/_bgDy 是**画布坐标**（与导出共用），预览时乘布局缩放 s
  /// · 受覆盖约束夹边：图 ≥ 画布时不能拖出白边；图 < 画布时居中
  /// 背景层：纯色 / 背景图 / 取色背景（素材首帧，放大 1.06）+ 可选高斯模糊
  Widget _buildBg() {
    final fromContent = bgFromContent && (bgContentPath ?? '').isNotEmpty;
    final img = fromContent ? bgContentPath : bgImagePath;
    Widget inner;
    if (img == null) {
      inner = Container(color: bgColor);
    } else if (fromContent) {
      // 素材首帧当背景：略微放大铺满 + 可选模糊
      inner = ClipRect(
        child: Transform.scale(
          scale: 1.06,
          child: Image.file(
            File(img),
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
      );
    } else {
      inner = _buildBgImage(img);
    }
    if (!bgBlurOn || bgBlurSigma <= 0) return inner;
    // 模糊时整体放大 8%：模糊的半透明边缘移到画布外，避免白边/高光
    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(
          sigmaX: bgBlurSigma, sigmaY: bgBlurSigma),
      child: Transform.scale(scale: 1.08, child: inner),
    );
  }

  /// 背景图（可缩放 / 拖拽 / 镜像）
  Widget _buildBgImage(String img) {
    final (cw0, ch0, _, _) = _canvasFor(widget.template);
    return LayoutBuilder(builder: (context, c) {
      final cardW = math.max(c.maxWidth, 1.0);
      final cardH = math.max(c.maxHeight, 1.0);
      final s = cardW / cw0; // 画布 → 预览 缩放
      final iw = bgImageW > 0 ? bgImageW.toDouble() : cardW;
      final ih = bgImageH > 0 ? bgImageH.toDouble() : cardH;
      final cover = math.max(cardW / iw, cardH / ih) * 1.01;
      final f = cover * bgImageScale.clamp(0.5, 3.0);
      final fw = iw * f;
      final fh = ih * f;
      final ox = fw >= cardW
          ? (((cardW - fw) / 2) + bgImageDx * s).clamp(cardW - fw, 0.0)
          : (cardW - fw) / 2;
      final oy = fh >= cardH
          ? (((cardH - fh) / 2) + bgImageDy * s).clamp(cardH - fh, 0.0)
          : (cardH - fh) / 2;
      return GestureDetector(
        onScaleStart: (_) => _bgStartScale = bgImageScale,
        onScaleUpdate: (d) {
          setState(() {
            bgImageScale = (_bgStartScale * d.scale).clamp(1.0, 3.0);
            bgImageDx += d.focalPointDelta.dx / s;
            bgImageDy += d.focalPointDelta.dy / s;
          });
        },
        child: ClipRect(
          child: SizedBox(
            width: cardW,
            height: cardH,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(child: Container(color: bgColor)),
                Positioned(
                  left: ox,
                  top: oy,
                  width: fw,
                  height: fh,
                  child: Image.file(
                    File(img),
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }  BoxDecoration _cardDeco() => BoxDecoration(
        gradient: glassCardGradient(),
        border: Border.all(color: glassCardBorder(), width: 1.5),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

  // ---------- 动作 ----------

  Future<void> _pickVideo() async {
    if (widget.imageMode) return _pickImage();
    try {
      // 走系统相册（图片+视频+动图都在里面）；打不开时回退到「视频」类型
      var result = await FilePicker.platform.pickFiles(
        type: FileType.media,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.video,
          allowMultiple: false,
        );
      }
      if (result == null || result.files.isEmpty) return;
      final path0 = result.files.single.path;
      if (path0 == null) return;
      // 实况模式：动图先转 mp4，才能进裁切页
      var path = path0;
      if (widget.mode == ComposeMode.live) {
        // 选到的是「动态照片」（JPEG+MP4）→ 先把内嵌视频抽出来
        final extJpg = p.extension(path).toLowerCase();
        if (extJpg == '.jpg' || extJpg == '.jpeg') {
          final tmp = await getTemporaryDirectory();
          final mp4 = p.join(tmp.path,
              'live_in_${DateTime.now().millisecondsSinceEpoch}.mp4');
          final n = await extractMotionVideo(path, mp4);
          AppLog.i('动态照片抽视频: ${n > 0 ? '$n 字节 ✓' : '没有内嵌视频 ✗'}');
          if (n > 0) path = mp4;
        }
        final ext = p.extension(path).toLowerCase();
        if (ext == '.gif' || ext == '.webp') {
          final tmp = await getTemporaryDirectory();
          final mp4 = p.join(
              tmp.path, 'live_${DateTime.now().millisecondsSinceEpoch}.mp4');
          await Composer.gifToMp4(inputPath: path, outputPath: mp4);
          path = mp4;
        }
      }
      AppLog.i('_pickVideo mode=${widget.mode} imageMode=${widget.imageMode} path=$path');
      setState(() {
        _videoPath = path;
        _info = null;
        _thumbPath = null;
        _done = false;
        _donePath = null;
      });
      final info = await VideoInfoReader.probe(path);
      if (!mounted) return;
      setState(() => _info = info);
      _genThumb(path);
      // 实况模式：选完自动进裁切页
      if (widget.mode == ComposeMode.live) {
        final trim = await Navigator.push<LiveTrimResult>(
          context,
          MaterialPageRoute(builder: (_) => LiveTrimScreen(videoPath: path)),
        );
        AppLog.i('trim result=${trim == null ? 'null' : '${trim.startMs}-${trim.endMs} cover=${trim.coverMs}'}');
        if (trim != null && mounted) {
          setState(() => _liveTrim = trim);
        }
      }
    } catch (e) {
      _toast('读取视频失败: $e');
    }
  }

  /// 图片创作：选择本地图片
  Future<void> _pickImage() async {
    try {
      var result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.media,
          allowMultiple: false,
        );
      }
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;
      setState(() {
        _imagePath = path;
        _thumbPath = null;
        _done = false;
        _donePath = null;
      });
    } catch (e) {
      _toast('读取图片失败: $e');
    }
  }

  /// 抽视频首帧作为实时预览里贴进屏幕的内容
  /// （只抽一帧、不做整幅 ffmpeg 合成，所以拖动滑块能实时跟手）
  Future<void> _genThumb(String videoPath) async {
    try {
      final tmp = await getTemporaryDirectory();
      final thumb = p.join(
          tmp.path,
          'thumb_${widget.template.name}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await Composer.extractFrame(videoPath: videoPath, outputPath: thumb);
      if (!mounted) return;
      setState(() {
        if (File(thumb).existsSync()) _thumbPath = thumb;
      });
    } catch (_) {/* 抽帧失败不影响其它功能 */}
  }

  /// 图片创作：导出带壳图片并入库图库
  Future<void> _exportImage() async {
    // 长截图模式：走长截图合成
    if (_longMode) return _exportLong();
    // 透明模板：图片导出也走带背景的透明合成（否则背景不生效）
    if (widget.template.isTransparent) {
      return _exportTransparent();
    }
    setState(() {
      _composing = true;
      _progress = 0;
      _progressText = '';
      _done = false;
    });
    try {
      final store = ExportStore();
      final outDir = await store.outputsDir();
      final name =
          '${p.basenameWithoutExtension(_imagePath!)}_{${widget.template.name}}_${DateTime.now().millisecondsSinceEpoch}.png';
      final out = p.join(outDir.path, name);

      await Composer.composeImage(
        shellDx: _shellDx,
        contentQuarterTurns: _contentTurns,
        shellDy: _shellDy,
        template: _activeTemplate,
        imagePath: _imagePath!,
        outputPath: out,
        landscape: _landscape,
        bgImagePath: bgFromContent ? bgContentPath : bgImagePath,
        bgBlur: bgBlurOn,
        bgBlurSigma: bgBlurSigma,
        // 模糊时放大 8%：gblur 边缘半透明处落到画布外，避免白底透出形成高光
        bgScale: bgBlurOn && bgBlurSigma > 0
            ? math.max(bgImageScale, 1.08)
            : bgImageScale,
        bgDx: bgImageDx,
        bgDy: bgImageDy,
        ratio: _ratio,
        canvasRatio: _canvasRatio,
      );

      final now = DateTime.now();
      await store.add(ExportItem(
        id: '${now.millisecondsSinceEpoch}',
        name: name,
        path: out,
        resLabel: '原图',
        timeLabel: '${_dayLabel(now)} ${_hm(now)}',
        durLabel: '',
        type: 'image',
      ));

      if (!mounted) return;
      setState(() {
        _composing = false;
        _progress = 1;
        _progressText = '合成完成';
        _done = true;
        _donePath = out;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _composing = false;
        _progressText = '失败';
      });
      _toast('导出失败: $e');
      _showFailLog(e);
    }
  }


  /// 透明壳导出（视频 / 静态图）：走 Composer.composeTransparent
  Future<void> _exportTransparent() async {
    final isVideo = !widget.imageMode;
    final content = isVideo ? _videoPath : _imagePath;
    if (content == null && bgImagePath == null) {
      _toast(isVideo ? '请先选择视频或背景图' : '请先选择图片或背景图');
      return;
    }
    setState(() {
      _composing = true;
      _progress = 0;
      _progressText = '';
      _done = false;
      _ffLog.clear();
    });
    try {
      final store = ExportStore();
      final outDir = await store.outputsDir();
      final base = content != null ? p.basenameWithoutExtension(content) : '背景';
      final ext = isVideo ? 'mp4' : 'png';
      final name =
          '${base}_${widget.template.name}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final out = p.join(outDir.path, name);

      AppLog.i('导出 shellDx=${_shellDx.toStringAsFixed(1)} shellDy=${_shellDy.toStringAsFixed(1)} ratio=$_ratio template=${_activeTemplate.name}');
      await Composer.composeTransparent(
        shellDx: _shellDx,
        contentQuarterTurns: _contentTurns,
        shellDy: _shellDy,
        template: _activeTemplate,
        contentPath: content,
        outputPath: out,
        isVideo: isVideo,
        bgColor: bgColor.toARGB32(),
        bgImagePath: bgFromContent ? bgContentPath : bgImagePath,
        bgBlur: bgBlurOn,
        bgBlurSigma: bgBlurSigma,
        // 模糊时放大 8%：gblur 边缘半透明处落到画布外，避免白底透出形成高光
        bgScale: bgBlurOn && bgBlurSigma > 0
            ? math.max(bgImageScale, 1.08)
            : bgImageScale,
        bgDx: bgImageDx,
        bgDy: bgImageDy,
        ratio: _ratio,
        canvasRatio: _canvasRatio,
        quality: _quality,
        hardware: _hardware,
        fpsOverride: _fpsOverride,
        info: _info,
        onProgress: (pct, speed) {
          if (!mounted) return;
          setState(() {
            _progress = pct;
            _progressText = '${(pct * 100).toStringAsFixed(0)}%  $speed';
          });
        },
        onLog: (msg) {
          if (!mounted) return;
          setState(() {
            if (_ffLog.length > 80) _ffLog.removeAt(0);
            _ffLog.add(msg);
          });
        },
      );

      final now = DateTime.now();
      await store.add(ExportItem(
        id: '${now.millisecondsSinceEpoch}',
        name: name,
        path: out,
        resLabel: isVideo ? (_info?.resolutionLabel ?? '原图') : '原图',
        timeLabel: '${_dayLabel(now)} ${_hm(now)}',
        durLabel: isVideo ? (_info?.durationLabel ?? '') : '',
        type: isVideo ? 'video' : 'image',
      ));

      if (!mounted) return;
      setState(() {
        _composing = false;
        _progress = 1;
        _progressText = '合成完成';
        _done = true;
        _donePath = out;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _composing = false;
        _progressText = '失败';
      });
      _toast('导出失败: $e');
      _showFailLog(e);
    }
  }


  /// 实况导出：合成视频 → 抽封面帧 → 打包动态照片 → 存相册
  /// 打包期间保持 _composing=true，进度卡不消失（问题2）
  Future<void> _exportLive() async {
    if (_videoPath == null) {
      _toast('请先选择视频');
      return;
    }
    setState(() {
      _composing = true;
      _progress = 0;
      _progressText = '正在生成实况照片…';
      _done = false;
      _ffLog.clear();
    });
    try {
      final store = ExportStore();
      final outDir = await store.outputsDir();
      final base = p.basenameWithoutExtension(_videoPath!);
      final name =
          '${base}_${widget.template.name}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final out = p.join(outDir.path, name);
      AppLog.i('实况导出 shellDx=${_shellDx.toStringAsFixed(1)} '
          'shellDy=${_shellDy.toStringAsFixed(1)} ratio=$_ratio '
          'template=${_activeTemplate.name} transparent=${_activeTemplate.isTransparent}');

      if (_activeTemplate.isTransparent) {
        await Composer.composeTransparent(
          shellDx: _shellDx,
        contentQuarterTurns: _contentTurns,
          shellDy: _shellDy,
          template: _activeTemplate,
          contentPath: _videoPath,
          outputPath: out,
          isVideo: true,
          bgColor: bgColor.toARGB32(),
          bgImagePath: bgFromContent ? bgContentPath : bgImagePath,
        bgBlur: bgBlurOn,
        bgBlurSigma: bgBlurSigma,
          // 模糊时放大 8%：gblur 边缘半透明处落到画布外，避免白底透出形成高光
        bgScale: bgBlurOn && bgBlurSigma > 0
            ? math.max(bgImageScale, 1.08)
            : bgImageScale,
          bgDx: bgImageDx,
          bgDy: bgImageDy,
          ratio: _ratio,
          canvasRatio: _canvasRatio,
          quality: _quality,
          hardware: _hardware,
          fpsOverride: _fpsOverride,
          info: _info,
          onProgress: (pct, speed) {
            if (!mounted) return;
            setState(() {
              _progress = pct * .8;
              _progressText = '${(pct * 80).toStringAsFixed(0)}%  $speed';
            });
          },
          onLog: (msg) {
            if (!mounted) return;
            setState(() {
              if (_ffLog.length > 80) _ffLog.removeAt(0);
              _ffLog.add(msg);
            });
          },
        );
      } else {
        await Composer.composeVideo(
          shellDx: _shellDx,
        contentQuarterTurns: _contentTurns,
          shellDy: _shellDy,
          template: _activeTemplate,
          videoPath: _videoPath!,
          info: _info!,
          outputPath: out,
          hardware: _hardware,
          landscape: _landscape,
        bgImagePath: bgFromContent ? bgContentPath : bgImagePath,
        bgBlur: bgBlurOn,
        bgBlurSigma: bgBlurSigma,
        // 模糊时放大 8%：gblur 边缘半透明处落到画布外，避免白底透出形成高光
        bgScale: bgBlurOn && bgBlurSigma > 0
            ? math.max(bgImageScale, 1.08)
            : bgImageScale,
        bgDx: bgImageDx,
        bgDy: bgImageDy,
          quality: _quality,
          fpsOverride: _fpsOverride,
          ratio: _ratio,
          canvasRatio: _canvasRatio,
          onProgress: (pct, speed) {
            if (!mounted) return;
            setState(() {
              _progress = pct * .8;
              _progressText = '${(pct * 80).toStringAsFixed(0)}%  $speed';
            });
          },
          onLog: (msg) {
            if (!mounted) return;
            setState(() {
              if (_ffLog.length > 80) _ffLog.removeAt(0);
              _ffLog.add(msg);
            });
          },
        );
      }

      final dir = p.dirname(out);
      final stem = p.basenameWithoutExtension(out);
      // 抽封面帧
      if (!mounted) return;
      setState(() {
        _progress = .85;
        _progressText = '正在抽取封面帧…';
      });
      final cover = p.join(dir, '${stem}_cover.jpg');
      await Composer.extractFrame(videoPath: out, outputPath: cover);

      // 打包动态照片（OPPO 变体）
      if (!mounted) return;
      setState(() {
        _progress = .92;
        _progressText = '正在打包动态照片…';
      });
      final motion = await MotionPhotoExporter.build(
        videoPath: out,
        jpegPath: cover,
        outPath: p.join(dir, '${stem}_live.jpg'),
        coverMs: _liveTrim?.coverMs ?? 0,
      );

      if (!mounted) return;
      setState(() {
        _progress = .97;
        _progressText = '正在保存到相册…';
      });
      AppLog.i('motion built: $motion (coverMs=${_liveTrim?.coverMs})');
      await MotionPhotoExporter.saveToGallery(motion);
      AppLog.i('motion saved to gallery');

      // 记录到图库（指向动态照片）
      final now = DateTime.now();
      await store.add(ExportItem(
        id: '${now.millisecondsSinceEpoch}',
        name: p.basename(motion),
        path: motion,
        resLabel: _info!.resolutionLabel,
        timeLabel: '${_dayLabel(now)} ${_hm(now)}',
        durLabel: _info!.durationLabel,
        type: 'image',
      ));

      if (!mounted) return;
      setState(() {
        _composing = false;
        _progress = 1;
        _progressText = '实况照片已生成';
        _done = true;
        _donePath = motion;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _composing = false;
        _progressText = '失败';
      });
      _toast('实况导出失败: $e');
      _showFailLog(e);
    }
  }

  Future<void> _exportVideo() async {
    AppLog.i('exportVideo mode=${widget.mode}');
    if (widget.mode == ComposeMode.live) return _exportLive();
    if (widget.mode == ComposeMode.transparentVideo ||
        widget.mode == ComposeMode.transparentImage) {
      return _exportTransparent();
    }
    setState(() {
      _composing = true;
      _progress = 0;
      _progressText = '';
      _done = false;
      _ffLog.clear();
    });
    try {
      final store = ExportStore();
      final outDir = await store.outputsDir();
      final name =
          '${p.basenameWithoutExtension(_videoPath!)}_{${widget.template.name}}_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final out = p.join(outDir.path, name);

      AppLog.i('导出 shellDx=${_shellDx.toStringAsFixed(1)} shellDy=${_shellDy.toStringAsFixed(1)} ratio=$_ratio template=${_activeTemplate.name}');
      await Composer.composeVideo(
        shellDx: _shellDx,
        contentQuarterTurns: _contentTurns,
        shellDy: _shellDy,
        template: _activeTemplate,
        videoPath: _videoPath!,
        info: _info!,
        outputPath: out,
        hardware: _hardware,
        landscape: _landscape,
        bgImagePath: bgFromContent ? bgContentPath : bgImagePath,
        bgBlur: bgBlurOn,
        bgBlurSigma: bgBlurSigma,
        // 模糊时放大 8%：gblur 边缘半透明处落到画布外，避免白底透出形成高光
        bgScale: bgBlurOn && bgBlurSigma > 0
            ? math.max(bgImageScale, 1.08)
            : bgImageScale,
        bgDx: bgImageDx,
        bgDy: bgImageDy,
        quality: _quality,
        fpsOverride: _fpsOverride,
        ratio: _ratio,
        canvasRatio: _canvasRatio,
        onProgress: (pct, speed) {
          if (!mounted) return;
          setState(() {
            _progress = pct;
            _progressText = '${(pct * 100).toStringAsFixed(0)}%  $speed';
          });
        },
        onLog: (msg) {
          if (!mounted) return;
          setState(() {
            if (_ffLog.length > 80) _ffLog.removeAt(0);
            _ffLog.add(msg);
          });
        },
      );

      // 记录到图库
      final now = DateTime.now();
      await store.add(ExportItem(
        id: '${now.millisecondsSinceEpoch}',
        name: name,
        path: out,
        resLabel: _quality == Quality.original
            ? _info!.resolutionLabel
            : switch (_quality) {
                Quality.p1080 => '1080P',
                Quality.p720 => '720P',
                _ => _info!.resolutionLabel,
              },
        timeLabel: '${_dayLabel(now)} ${_hm(now)}',
        durLabel: _info!.durationLabel,
        type: 'video',
      ));

      if (!mounted) return;
      setState(() {
        _composing = false;
        _progress = 1;
        _progressText = '合成完成';
        _done = true;
        _donePath = out;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _composing = false;
        _progressText = '失败';
      });
      _toast('导出失败: $e');
      _showFailLog(e);
    }
  }

  Future<void> _shareFile(String path, String msg) async {
    try {
      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
    } catch (_) {
      _toast(msg);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 合成失败时展示 ffmpeg 日志：可长按选择，也可点「复制日志」一键复制
  void _showFailLog(Object e) {
    final full = '$e\n\n${_ffLog.reversed.join('\n')}';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('合成失败详情'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                '$e',
                style: const TextStyle(fontSize: 13, color: Color(0xFFFF3B30), fontWeight: FontWeight.w700),
              ),
              if (_ffLog.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  '日志（倒序，最新在最上面；长按可选中）',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSub),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  _ffLog.reversed.join('\n'),
                  style: TextStyle(fontSize: 10.5, height: 1.35, color: AppColors.textSub),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: full));
              if (ctx.mounted) {
                _toast('日志已复制，直接粘贴即可');
              }
            },
            child: const Text('复制日志'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  static String _dayLabel(DateTime t) {
    final now = DateTime.now();
    final d = DateTime(t.year, t.month, t.day);
    final n = DateTime(now.year, now.month, now.day);
    final diff = n.difference(d).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '昨天';
    return '${t.month}月${t.day}日';
  }

  static String _hm(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

// ---------- 小组件 ----------

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool enabled;
  final VoidCallback onTap;
  final bool primary;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? (primary ? Colors.white : AppColors.accent)
        : AppColors.textFaint;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: primary
              ? (enabled ? AppColors.accent : const Color(0xFFDDE2EA))
              : (enabled ? AppColors.accent.withValues(alpha: .12) : AppColors.fill),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  final String text;
  const _InfoTag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: AppColors.accent,
        ),
      ),
    );
  }
}

/// 百分比圆环
class _Ring extends StatelessWidget {
  final double progress; // 0..1
  final double size;
  final Color color;

  const _Ring({
    required this.progress,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _RingPainter(progress: progress.clamp(0, 1), color: color),
            ),
          ),
          Text(
            '${(progress.clamp(0, 1) * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: size * .17,
              fontWeight: FontWeight.w800,
              color: progress >= 1 ? const Color(0xFF34C759) : AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = AppColors.fill;
    canvas.drawCircle(center, radius, track);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2,
      3.14159 * 2 * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress;
}

/// 预览坐标线：只保留贯穿屏幕区域中心的十字线（无框、无坐标数字）
class _GuidePainter extends CustomPainter {
  final ShellTemplate t;

  _GuidePainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    // 壳图 → 预览等比
    final sx = t.screenX / t.caseWidth * size.width;
    final sy = t.screenY / t.caseHeight * size.height;
    final sw = t.screenW / t.caseWidth * size.width;
    final sh = t.screenH / t.caseHeight * size.height;
    final cx = sx + sw / 2;
    final cy = sy + sh / 2;

    // 十字线已删除
  }

  @override
  bool shouldRepaint(_GuidePainter old) => old.t != t;
}

/// 底栏右侧的圆形小按钮（等大正圆）
class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _CircleBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? AppColors.accent.withValues(alpha: .16)
              : AppColors.fillSoft,
          border: Border.all(
            color: active
                ? AppColors.accent.withValues(alpha: .42)
                : const Color(0xFFE4E9F4),
            width: active ? 0.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 15,
                color: active ? AppColors.accent : AppColors.textSub),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 8.5,
                height: 1,
                fontWeight: FontWeight.w800,
                color: active ? AppColors.accent : AppColors.textSub,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
