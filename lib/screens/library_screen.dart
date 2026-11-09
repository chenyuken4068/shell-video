import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../services/motion_probe.dart';
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
      bottom: 96,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .92),
          borderRadius: BorderRadius.circular(29),
          border: Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .16),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
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

  Widget _glassBtn({required IconData icon, required VoidCallback onTap, Color? color}) {
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
        child: Icon(icon, size: 20, color: color ?? Colors.white),
      ),
    );
  }

  Widget _action({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
    bool active = false,
  }) {
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
            Text(
              label,
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 26, color: Colors.white.withValues(alpha: .14));


  @override
  Widget build(BuildContext context) {
    final f = File(widget.path);
    return Scaffold(
      backgroundColor: const Color(0xFF0B0C0F),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _showUI = !_showUI),
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: 1,
                maxScale: 5,
                child: Center(
                  child: f.existsSync()
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            // 播放中显示视频，否则显示静态图
                            if (_motionPlaying &&
                                _vctrl != null &&
                                _vctrl!.value.isInitialized)
                              AspectRatio(
                                aspectRatio: _vctrl!.value.aspectRatio,
                                child: VideoPlayer(_vctrl!),
                              )
                            else
                              Image.file(f, fit: BoxFit.contain),
                            // 实况照片：中心播放按钮
                            if (_isMotion && !_motionPlaying)
                              GestureDetector(
                                onTap: _toggleMotion,
                                child: Container(
                                  width: 58,
                                  height: 58,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.black
                                        .withValues(alpha: .38),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: .35)),
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 34,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        )
                      : Icon(Icons.broken_image_outlined, size: 48, color: Colors.white.withValues(alpha: .4)),
                ),
              ),
            ),
          ),
          if (_showUI) ...[
            // 顶部：返回 / 文件名 / 更多（删除）
            Positioned(
              left: 16,
              right: 16,
              top: MediaQuery.paddingOf(context).top + 8,
              height: 44,
              child: Row(
                children: [
                  _glassBtn(icon: Icons.chevron_left, onTap: () => Navigator.pop(context)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _glassBtn(icon: Icons.more_horiz, onTap: _delete),
                ],
              ),
            ),
            // 底部操作栏
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 20,
              height: 64,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withValues(alpha: .18), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        _action(
                          icon: Icons.download_rounded,
                          label: _busy ? '保存中' : '保存',
                          active: _saved,
                          onTap: _save,
                        ),
                        _divider(),
                        _action(icon: Icons.ios_share, label: '分享', onTap: _share),
                        _divider(),
                        _action(
                          icon: Icons.delete_outline,
                          label: '删除',
                          color: const Color(0xFFFF7B72),
                          onTap: _delete,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
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

  Widget _divider() => Container(width: 1, height: 26, color: Colors.white.withValues(alpha: .14));

  @override
  Widget build(BuildContext context) {
    final padTop = MediaQuery.paddingOf(context).top;
    final padBottom = MediaQuery.paddingOf(context).bottom;

    Widget videoArea;
    if (_err != null) {
      videoArea = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: Colors.white.withValues(alpha: .5), size: 44),
          const SizedBox(height: 12),
          Text('播放失败: $_err',
              style: TextStyle(color: Colors.white.withValues(alpha: .6), fontSize: 13)),
        ],
      );
    } else if (!_init) {
      videoArea = const CircularProgressIndicator(color: Colors.white70);
    } else {
      videoArea = GestureDetector(
        onTap: () => setState(() {
          _ctrl.value.isPlaying ? _ctrl.pause() : _ctrl.play();
        }),
        child: AspectRatio(
          aspectRatio: _ctrl.value.aspectRatio,
          child: VideoPlayer(_ctrl),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0B0C0F),
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _showUI = !_showUI),
              child: Center(child: videoArea),
            ),
          ),
          if (_showUI) ...[
            // 顶部：返回 / 文件名 / 更多（删除）
            Positioned(
              left: 16,
              right: 16,
              top: padTop + 8,
              height: 44,
              child: Row(
                children: [
                  _glassBtn(Icons.chevron_left, () => Navigator.pop(context)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _glassBtn(Icons.more_horiz, _delete),
                ],
              ),
            ),
            // 中央播放/暂停
            if (_init)
              Center(
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: _ctrl,
                  builder: (_, v, _) => IgnorePointer(
                    child: AnimatedOpacity(
                      opacity: v.isPlaying ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: .46),
                          border: Border.all(color: Colors.white.withValues(alpha: .28), width: 1.5),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, size: 34, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            // 进度条 + 时间
            if (_init)
              Positioned(
                left: 20,
                right: 20,
                bottom: padBottom + 108,
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: _ctrl,
                  builder: (_, v, _) {
                    final total = v.duration.inMilliseconds.toDouble();
                    final pos = v.position.inMilliseconds.toDouble().clamp(0.0, total);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white.withValues(alpha: .22),
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: total <= 0 ? 0 : pos,
                            max: total <= 0 ? 1 : total,
                            onChanged: (x) => _ctrl.seekTo(Duration(milliseconds: x.round())),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_fmt(v.position),
                                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: .72))),
                            Text(_fmt(v.duration),
                                style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: .72))),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            // 底部玻璃操作栏
            Positioned(
              left: 16,
              right: 16,
              bottom: padBottom + 20,
              height: 64,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white.withValues(alpha: .18), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        _action(Icons.download_rounded, _busy ? '保存中' : '保存', _save, active: _saved),
                        _divider(),
                        _action(Icons.ios_share, '分享', _share),
                        _divider(),
                        _action(Icons.delete_outline, '删除', _delete, color: const Color(0xFFFF7B72)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
