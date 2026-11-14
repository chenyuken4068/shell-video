import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../services/motion_diag.dart';
import '../services/motion_probe.dart';
import '../widgets/app_glass.dart';
import '../widgets/glass_pill.dart';
import '../widgets/media_card.dart';

import '../theme/app_theme.dart';

import 'dart:io';



import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:video_player/video_player.dart';

import 'package:gal/gal.dart';

import 'package:ffmpeg_kit_flutter_video/ffmpeg_kit.dart';

import 'package:share_plus/share_plus.dart';



import '../services/export_store.dart';

import '../widgets/main_shell.dart' show gTab;



/// 图库页：已导出视频列表

class LibraryScreen extends StatefulWidget {

  const LibraryScreen({super.key});



  @override

  State<LibraryScreen> createState() => LibraryScreenState();

}



class LibraryScreenState extends State<LibraryScreen> {

  final _store = ExportStore();

  List<ExportItem> _items = [];

  bool _loading = true;

  // ── 批量选择 ──
  bool _selMode = false;
  final Set<String> _selected = {};



  @override

  void initState() {

    super.initState();

    refresh();

    // 合成导出后跳转图库 Tab 时自动刷新（IndexedStack 常驻不重建，需监听）

    gTab.addListener(_onTabChanged);

  }



  @override

  void dispose() {

    gTab.removeListener(_onTabChanged);

    super.dispose();

  }



  void _onTabChanged() {

    if (gTab.value == 1 && mounted) refresh();

  }



  /// 从导出目录/记录刷新（切到图库 Tab 时调用）

  Future<void> refresh() async {

    final list = await _store.load();

    if (!mounted) return;

    setState(() {

      _items = list;

      _loading = false;

    });

    // 首帧缺失时异步补抽（合成完成时已抽帧，这里兜底）

    for (final it in list) {

      _ensureThumb(it);

    }

  }



  /// 图库缩略图：视频首帧 jpg 缺失时用 FFmpeg 抽帧补上

  Future<void> _ensureThumb(ExportItem it) async {

    final thumb = it.path.replaceAll(RegExp(r'\.mp4$'), '.jpg');

    if (File(thumb).existsSync()) return;

    try {

      await FFmpegKit.execute(

        '-y -i "${it.path.replaceAll('"', '"')}" -vframes 1 -q:v 3 "${thumb.replaceAll('"', '"')}"',

      );

      if (mounted) setState(() {}); // 抽帧完成后刷新列表显示第一帧

    } catch (_) {}

  }



  /// 保存到相册：返回是否成功（提示由卡片自己显示）
  Future<bool> _save(ExportItem it) async {
    try {
      final ok = await Gal.requestAccess(toAlbum: false);
      if (!ok) return false;
      if (it.type == 'image') {
        await Gal.putImage(it.path);
      } else {
        await Gal.putVideo(it.path);
      }
      return true;
    } catch (_) {
      return false;
    }
  }



  void _openItem(ExportItem it) {

    // 图片创作产物：打开图片预览页；视频产物：打开播放器

    if (it.type == 'image') {

      Navigator.push(

        context,

        MaterialPageRoute(builder: (_) => ImageViewerScreen(path: it.path, name: it.name)),

      );

      return;

    }

    Navigator.push(

      context,

      MaterialPageRoute(builder: (_) => VideoPlayerScreen(path: it.path, name: it.name)),

    );

  }



  Future<void> _share(ExportItem it) async {

    try {

      await SharePlus.instance.share(ShareParams(files: [XFile(it.path)]));

    } catch (_) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text('文件不存在或无法分享: ${it.name}')),

      );

    }

  }



  Future<void> _remove(ExportItem it) async {

    final ok = await showDialog<bool>(

      context: context,

      builder: (context) => AlertDialog(

        title: Text('删除 "${it.name}"？'),

        content: const Text('将从本地存储中删除该文件。'),

        actions: [

          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),

          FilledButton(

            onPressed: () => Navigator.pop(context, true),

            style: FilledButton.styleFrom(backgroundColor: Colors.red),

            child: const Text('删除'),

          ),

        ],

      ),

    );

    if (ok != true) return;

    try {

      final f = File(it.path);

      if (await f.exists()) await f.delete();

    } catch (_) {}

    await _store.remove(it.id);

    refresh();

  }



  @override

  Widget build(BuildContext context) {

    return Stack(
      children: [

        // 视频列表（内容区 y=98）

        Positioned(

          top: 0,

          left: 14,

          right: 14,

          // 底部预留 0：卡片可一直滚到屏幕底，穿过悬浮底栏透出毛玻璃

          bottom: 0,

          child: _loading

              ? const Center(child: CircularProgressIndicator())

              : _items.isEmpty

                  ? _EmptyView(onRefresh: refresh)

                  : RefreshIndicator(

                      onRefresh: refresh,

                      child: GridView.builder(
                        padding: const EdgeInsets.only(top: 98, bottom: 120),
                        physics: const AlwaysScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 3 / 4,
                        ),
                        itemCount: _items.length,
                        itemBuilder: (context, i) {
                          final it = _items[i];
                          return MediaCard(
                            item: it,
                            selectMode: _selMode,
                            selected: _selected.contains(it.id),
                            onTap: () {
                              if (_selMode) {
                                _toggleSel(it);
                              } else {
                                _openItem(it);
                              }
                            },
                            onLongPress: () {
                              if (_selMode) {
                                _toggleSel(it);
                              } else {
                                _enterSel(it);
                              }
                            },
                            onSave: () => _save(it),
                          );
                        },
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
        // 批量模式：右上角「取消」
        if (_selMode)
          Positioned(
            top: 42,
            right: 20,
            child: GestureDetector(
              onTap: _exitSel,
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.fill,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text('取消',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSub)),
              ),
            ),
          ),
        Positioned(

          top: 40,

          left: 20,

          child: Text(

            _selMode ? '已选 ${_selected.length} 项' : '图库',

            style: TextStyle(

              fontSize: 26,

              fontWeight: FontWeight.w800,

              color: AppColors.text,

            ),

          ),

        ),

        if (_selMode) _batchBar(),
        ],

    );

  }


  // ───────── 批量选择 ─────────

  void _enterSel(ExportItem it) {
    HapticFeedback.selectionClick();
    setState(() {
      _selMode = true;
      _selected
        ..clear()
        ..add(it.id);
    });
  }

  void _exitSel() {
    setState(() {
      _selMode = false;
      _selected.clear();
    });
  }

  void _toggleSel(ExportItem it) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.remove(it.id)) _selected.add(it.id);
    });
  }

  void _toggleSelectAll() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.length == _items.length) {
        _selected.clear();
      } else {
        _selected.addAll(_items.map((e) => e.id));
      }
    });
  }

  List<ExportItem> get _selItems =>
      _items.where((e) => _selected.contains(e.id)).toList();

  Future<void> _batchSave() async {
    final list = _selItems;
    if (list.isEmpty) return;
    var ok = 0;
    for (final it in list) {
      if (await _save(it)) ok++;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已保存 $ok / ${list.length} 个到相册')),
    );
  }

  Future<void> _batchShare() async {
    final list = _selItems;
    if (list.isEmpty) return;
    try {
      await SharePlus.instance.share(
        ShareParams(files: list.map((e) => XFile(e.path)).toList()),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('分享失败：文件可能已被删除')),
      );
    }
  }

  Future<void> _batchDelete() async {
    final list = _selItems;
    if (list.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('删除 ${list.length} 个作品？'),
        content: const Text('将从本地存储中删除这些文件，无法恢复。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    for (final it in list) {
      try {
        final f = File(it.path);
        if (await f.exists()) await f.delete();
      } catch (_) {}
      await _store.remove(it.id);
    }
    if (!mounted) return;
    setState(() {
      _selMode = false;
      _selected.clear();
    });
    refresh();
  }

  /// 第 2 层悬浮底栏：全选 / 下载 / 分享 / 删除
  Widget _batchBar() {
    final all = _items.isNotEmpty && _selected.length == _items.length;
    return Positioned(
      left: 16,
      right: 16,
      // 主悬浮底栏：bottom 16 + 高度 64 = top 80 → 这里 90（留 10px 间距）
      bottom: 90 + MediaQuery.paddingOf(context).bottom,
      child: AppGlass(
        height: 58,
        radius: 29,
        child: Row(
          children: [
            _batchAction(
              all ? Icons.remove_done : Icons.done_all,
              all ? '全不选' : '全选',
              _toggleSelectAll,
            ),
            _batchDivider(),
            _batchAction(Icons.download_rounded, '下载', _batchSave),
            _batchDivider(),
            _batchAction(Icons.share_outlined, '分享', _batchShare),
            _batchDivider(),
            _batchAction(Icons.delete_outline, '删除', _batchDelete, danger: true),
          ],
        ),
      ),
    );
  }

  Widget _batchDivider() =>
      Container(width: 1, height: 26, color: const Color(0xFFF0F3F9));

  Widget _batchAction(IconData icon, String label, VoidCallback onTap,
      {bool danger = false}) {
    final c = danger ? const Color(0xFFE5484D) : const Color(0xFF5A6478);
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: c),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: c)),
          ],
        ),
      ),
    );
  }
}






class _EmptyView extends StatelessWidget {

  final VoidCallback onRefresh;



  const _EmptyView({required this.onRefresh});



  @override

  Widget build(BuildContext context) {

    return Center(

      child: Column(

        mainAxisSize: MainAxisSize.min,

        children: [

          Icon(Icons.video_library_outlined, size: 56, color: AppColors.textSub),

          const SizedBox(height: 12),

          Text(

            '还没有导出的视频',

            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSub),

          ),

          const SizedBox(height: 6),

          Text(

            '在创作页选择手机壳和视频，合成后会自动保存到本地',

            textAlign: TextAlign.center,

            style: TextStyle(fontSize: 12, color: AppColors.textSub),

          ),

          const SizedBox(height: 14),

          TextButton(onPressed: onRefresh, child: const Text('刷新')),

        ],

      ),

    );

  }

}





/// 视频播放页

/// 图片查看页：全屏预览带壳图片 + 分享

/// 图片预览：黑底 + 顶部玻璃（返回 / 文件名 / 更多→删除）+ 底部玻璃操作栏（保存 / 分享 / 删除）
class ImageViewerScreen extends StatefulWidget {
  final String path;
  final String name;

  const ImageViewerScreen({super.key, required this.path, required this.name});

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  final _transform = TransformationController();
  bool _showUI = true;
  bool _busy = false;
  bool _saved = false;

  // ── 实况照片（动态照片）播放 ──
  bool _isMotion = false;
  String? _motionMp4;
  VideoPlayerController? _vctrl;
  bool _motionPlaying = false;

  @override
  void dispose() {
    _vctrl?.dispose();
    _transform.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _probeMotion();
  }

  /// 探测是否是「实况照片」（JPEG 内嵌 MP4）→ 是则准备播放
  Future<void> _probeMotion() async {
    try {
      final tmp = await getTemporaryDirectory();
      final out = p.join(tmp.path,
          'motion_view_${DateTime.now().millisecondsSinceEpoch}.mp4');
      final n = await extractMotionVideo(widget.path, out);
      if (!mounted) return;
      if (n > 0) {
        setState(() {
          _isMotion = true;
          _motionMp4 = out;
        });
      }
    } catch (_) {/* 普通图片：忽略 */}
  }

  /// 播放 / 停止实况视频
  Future<void> _toggleMotion() async {
    if (_motionPlaying) {
      await _vctrl?.pause();
      if (mounted) setState(() => _motionPlaying = false);
      return;
    }
    try {
      var c = _vctrl;
      if (c == null || !c.value.isInitialized) {
        final mp4 = _motionMp4;
        if (mp4 == null) return;
        c = VideoPlayerController.file(File(mp4));
        await c.initialize();
        await c.setLooping(false);
        c.addListener(() {
          final v = c!.value;
          if (_motionPlaying && v.isInitialized && !v.isPlaying &&
              v.position >= v.duration - const Duration(milliseconds: 60)) {
            if (mounted) setState(() => _motionPlaying = false);
          }
        });
        _vctrl = c;
      }
      await c.seekTo(Duration.zero);
      await c.play();
      if (mounted) setState(() => _motionPlaying = true);
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    setState(() => _busy = true);
    var ok = false;
    try {
      final granted = await Gal.requestAccess(toAlbum: false);
      if (granted) {
        await Gal.putImage(widget.path);
        ok = true;
      }
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _saved = ok;
    });
    if (ok) HapticFeedback.lightImpact();
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => SaveToast(
        ok: ok,
        onDone: () {
          entry.remove();
        },
      ),
    );
    overlay.insert(entry);
    if (ok) {
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      if (mounted) setState(() => _saved = false);
    }
  }

  Future<void> _share() async {
    try {
      await SharePlus.instance.share(ShareParams(files: [XFile(widget.path)]));
    } catch (_) {}
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这张图片？'),
        content: const Text('将从本地存储中删除该文件。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Color(0xFFE5484D))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final f = File(widget.path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    if (mounted) Navigator.pop(context, true);
  }





  @override
  Widget build(BuildContext context) {
    final f = File(widget.path);
    final exists = f.existsSync();
    final mb = exists ? f.lengthSync() / (1024 * 1024) : 0.0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _topBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 媒体卡片（与全 App 一致的柔光玻璃卡）──
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: glassCardGradient(),
                      border: Border.all(color: glassCardBorder(), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .05),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // 固定预览区（contain 展示，不铺满全屏）
                        SizedBox(
                          height: 430,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: ColoredBox(
                              color: _motionPlaying
                                  ? Colors.black
                                  : const Color(0xFFEEF1F7),
                              child: exists
                                  ? (_motionPlaying &&
                                          _vctrl != null &&
                                          _vctrl!.value.isInitialized
                                      ? Center(
                                          child: AspectRatio(
                                            aspectRatio:
                                                _vctrl!.value.aspectRatio,
                                            child: VideoPlayer(_vctrl!),
                                          ),
                                        )
                                      : InteractiveViewer(
                                          transformationController: _transform,
                                          minScale: 1,
                                          maxScale: 4,
                                          child: Center(
                                            child: Image.file(f,
                                                fit: BoxFit.contain),
                                          ),
                                        ))
                                  : Center(
                                      child: Icon(Icons.broken_image_outlined,
                                          size: 42, color: AppColors.textFaint),
                                    ),
                            ),
                          ),
                        ),
                        // 实况：播放按钮（卡片内、媒体下方）
                        if (_isMotion && !_motionPlaying) ...[
                          const SizedBox(height: 12),
                          GestureDetector(
                            onTap: _toggleMotion,
                            child: Container(
                              height: 44,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 22),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.accent.withValues(alpha: .10),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                    color:
                                        AppColors.accent.withValues(alpha: .28),
                                    width: 1.5),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.play_arrow_rounded,
                                      size: 22, color: AppColors.accent),
                                  const SizedBox(width: 6),
                                  Text('播放实况',
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.accent)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  // ── 信息胶囊 ──
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ivChip(
                        icon: _isMotion
                            ? Icons.motion_photos_on_outlined
                            : Icons.image_outlined,
                        text: _isMotion ? '实况照片' : '图片',
                      ),
                      _ivChip(text: '${mb.toStringAsFixed(1)} MB'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // ── 底部操作栏 ──
          _ivActions(),
        ],
      ),
    );
  }

  Widget _topBar() {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.fill,
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.chevron_left, size: 22, color: AppColors.text),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showMore,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.fill,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.more_horiz,
                    size: 20, color: AppColors.textSub),
              ),
            ),
            const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }

  void _showMore() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 6),
            _sheetItem(Icons.science_outlined, '动图诊断（生成 txt 报告）', () {
              Navigator.pop(ctx);
              _diagMotion();
            }),
            _sheetItem(Icons.download_rounded, '保存到相册', () {
              Navigator.pop(ctx);
              _save();
            }),
            _sheetItem(Icons.share_outlined, '分享', () {
              Navigator.pop(ctx);
              _share();
            }),
            _sheetItem(Icons.delete_outline, '删除',
                () {
              Navigator.pop(ctx);
              _delete();
            }, danger: true),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _sheetItem(IconData icon, String label, VoidCallback onTap,
      {bool danger = false}) {
    final c = danger ? const Color(0xFFE5484D) : AppColors.text;
    return ListTile(
      leading: Icon(icon, color: danger ? c : AppColors.accent),
      title: Text(label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c)),
      onTap: onTap,
    );
  }

  /// 动图诊断：解析结构并生成 txt 报告
  Future<void> _diagMotion() async {
    try {
      final txt = await MotionDiag.run(
        widget.path,
        extra: '来源: 图库预览页手动诊断',
      );
      final dir = await getApplicationDocumentsDirectory();
      final name =
          '动图诊断_${DateTime.now().millisecondsSinceEpoch}.txt';
      final f = File('${dir.path}/$name');
      await f.writeAsString(txt, flush: true);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('动图诊断报告'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Text(txt,
                  style: const TextStyle(fontSize: 11.5, height: 1.35)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await SharePlus.instance
                      .share(ShareParams(files: [XFile(f.path)]));
                } catch (_) {}
              },
              child: const Text('分享 txt'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('诊断失败: $e')),
        );
      }
    }
  }

  Widget _ivChip({IconData? icon, required String text}) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: glassCardBorder(), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: AppColors.textSub),
            const SizedBox(width: 5),
          ],
          Text(text,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSub)),
        ],
      ),
    );
  }

  Widget _ivActions() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.card.withValues(alpha: .92),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: glassCardBorder(), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              _ivBtn(Icons.download_rounded, _saved ? '已保存' : '保存', _save,
                  color: _saved ? const Color(0xFF22A06B) : null),
              _ivDivider(),
              _ivBtn(Icons.share_outlined, '分享', _share),
              _ivDivider(),
              _ivBtn(Icons.delete_outline, '删除', _delete,
                  color: const Color(0xFFE5484D)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ivDivider() =>
      Container(width: 1, height: 26, color: AppColors.divider);

  Widget _ivBtn(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    final c = color ?? AppColors.textSub;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _busy ? null : onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: c),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: c)),
          ],
        ),
      ),
    );
  }
}


class VideoPlayerScreen extends StatefulWidget {
  final String path;
  final String name;

  const VideoPlayerScreen({super.key, required this.path, required this.name});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _ctrl;
  bool _init = false;
  String? _err;
  bool _showUI = true;
  bool _busy = false;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.file(File(widget.path));
    _ctrl.initialize().then((_) {
      if (!mounted) return;
      setState(() => _init = true);
      _ctrl.play();
    }).catchError((e) {
      if (!mounted) return;
      setState(() => _err = '$e');
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _save() async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    setState(() => _busy = true);
    var ok = false;
    try {
      final granted = await Gal.requestAccess(toAlbum: false);
      if (granted) {
        await Gal.putVideo(widget.path);
        ok = true;
      }
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _saved = ok;
    });
    if (ok) HapticFeedback.lightImpact();
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => SaveToast(
        ok: ok,
        onDone: () {
          entry.remove();
        },
      ),
    );
    overlay.insert(entry);
    if (ok) {
      await Future<void>.delayed(const Duration(milliseconds: 1300));
      if (mounted) setState(() => _saved = false);
    }
  }

  Future<void> _share() async {
    try {
      await SharePlus.instance.share(ShareParams(files: [XFile(widget.path)]));
    } catch (_) {}
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这个视频？'),
        content: const Text('将从本地存储中删除该文件。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Color(0xFFE5484D))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final f = File(widget.path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
    if (mounted) Navigator.pop(context, true);
  }

  Widget _glassBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: .42),
          border: Border.all(color: Colors.white.withValues(alpha: .18)),
        ),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap, {Color? color, bool active = false}) {
    final c = color ?? Colors.white.withValues(alpha: .82);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(active ? Icons.check_rounded : icon, size: 20, color: active ? const Color(0xFF3DD68C) : c),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c)),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final f = File(widget.path);
    final exists = f.existsSync();
    final mb = exists ? f.lengthSync() / (1024 * 1024) : 0.0;
    final dur = _ctrl.value.isInitialized ? _ctrl.value.duration : Duration.zero;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _vpTopBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── 视频卡片 ──
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: glassCardGradient(),
                      border: Border.all(color: glassCardBorder(), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .05),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      height: 430,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: ColoredBox(
                          color: const Color(0xFF0B0C0F),
                          child: _vpVideoArea(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // ── 进度条（可拖动）──
                  if (_init && _err == null)
                    ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: _ctrl,
                      builder: (_, v, __) => Column(
                        children: [
                          VideoProgressIndicator(
                            _ctrl,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: AppColors.accent,
                              bufferedColor: Color(0xFFD7E5FF),
                              backgroundColor: Color(0xFFE3E8F2),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_fmt(v.position),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSub)),
                              Text(_fmt(v.duration),
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSub)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  // ── 信息胶囊 ──
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _vpChip(icon: Icons.movie_outlined, text: '视频'),
                      _vpChip(text: _fmt(dur)),
                      _vpChip(text: '${mb.toStringAsFixed(1)} MB'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          _vpActions(),
        ],
      ),
    );
  }

  Widget _vpTopBar() {
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.fill,
                  shape: BoxShape.circle,
                ),
                child:
                    Icon(Icons.chevron_left, size: 22, color: AppColors.text),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _delete,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.fill,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.more_horiz,
                    size: 20, color: AppColors.textSub),
              ),
            ),
            const SizedBox(width: 14),
          ],
        ),
      ),
    );
  }

  Widget _vpVideoArea() {
    if (_err != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                color: Colors.white.withValues(alpha: .55), size: 40),
            const SizedBox(height: 10),
            Text('播放失败: $_err',
                style: TextStyle(
                    color: Colors.white.withValues(alpha: .65),
                    fontSize: 12)),
          ],
        ),
      );
    }
    if (!_init) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white70));
    }
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _ctrl,
      builder: (_, v, __) => GestureDetector(
        onTap: () => setState(() {
          v.isPlaying ? _ctrl.pause() : _ctrl.play();
        }),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: v.aspectRatio == 0 ? 9 / 16 : v.aspectRatio,
                child: VideoPlayer(_ctrl),
              ),
            ),
            // 暂停时显示播放圆钮
            if (!v.isPlaying)
              Container(
                width: 58,
                height: 58,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .38),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: .35)),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    size: 34, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }

  Widget _vpChip({IconData? icon, required String text}) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: glassCardBorder(), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: AppColors.textSub),
            const SizedBox(width: 5),
          ],
          Text(text,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSub)),
        ],
      ),
    );
  }

  Widget _vpActions() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.card.withValues(alpha: .92),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: glassCardBorder(), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .06),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              _vpBtn(Icons.download_rounded, _saved ? '已保存' : '保存', _save,
                  color: _saved ? const Color(0xFF22A06B) : null),
              _vpDivider(),
              _vpBtn(Icons.share_outlined, '分享', _share),
              _vpDivider(),
              _vpBtn(Icons.delete_outline, '删除', _delete,
                  color: const Color(0xFFE5484D)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _vpDivider() =>
      Container(width: 1, height: 26, color: AppColors.divider);

  Widget _vpBtn(IconData icon, String label, VoidCallback onTap,
      {Color? color}) {
    final c = color ?? AppColors.textSub;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: c),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w700, color: c)),
          ],
        ),
      ),
    );
  }
}
