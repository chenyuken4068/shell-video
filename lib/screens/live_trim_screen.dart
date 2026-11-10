import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'package:path_provider/path_provider.dart';

import '../services/composer.dart';
import '../theme/app_theme.dart';

/// 裁切结果
class LiveTrimResult {
  final int startMs;
  final int endMs;
  final int coverMs;

  const LiveTrimResult({
    required this.startMs,
    required this.endMs,
    required this.coverMs,
  });

  double get startSec => startMs / 1000;
  double get endSec => endMs / 1000;
  double get coverSec => coverMs / 1000;
}

/// 实况创作 · 选帧与裁切（剪映式）
///
/// · 胶片条上【白色播放头】= 实时帧，拖动 → 预览跟着变
/// · 蓝色边框 + 左右手柄 = 裁切片段（拖手柄改起止，≤10 秒）
/// · 条【上方黄色小点】= 封面帧
/// · 条【下方「设为封面」】跟着播放头水平移动，点一下把当前帧设为封面
/// · 预览按视频真实比例显示，不留黑边
class LiveTrimScreen extends StatefulWidget {
  final String videoPath;

  const LiveTrimScreen({super.key, required this.videoPath});

  @override
  State<LiveTrimScreen> createState() => _LiveTrimScreenState();
}

class _LiveTrimScreenState extends State<LiveTrimScreen> {
  VideoPlayerController? _ctrl;
  bool _ready = false;
  String? _err;

  int _totalMs = 0;
  int _startMs = 0;
  int _endMs = 0;
  int _coverMs = 0;
  int _playMs = 0;

  bool _playing = false;
  static const int _maxLenMs = 10000;

  bool _draggingLeft = false;
  bool _draggingRight = false;

  double _stripWidth = 1;

  /// 胶片条缩略图（ffmpeg 抽帧）
  final List<String> _thumbs = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ctrl = VideoPlayerController.file(File(widget.videoPath));
      await ctrl.initialize();
      final total = ctrl.value.duration.inMilliseconds;
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      final end = total < _maxLenMs ? total : _maxLenMs;
      setState(() {
        _ctrl = ctrl;
        _totalMs = total;
        _startMs = 0;
        _endMs = end;
        _coverMs = 0;
        _playMs = 0;
        _ready = true;
      });
      ctrl.addListener(_onTick);
      await ctrl.seekTo(Duration.zero);
      _genThumbs();
    } catch (e) {
      if (!mounted) return;
      setState(() => _err = '视频加载失败: $e');
    }
  }

  /// 抽 10 帧做胶片条缩略图
  Future<void> _genThumbs() async {
    try {
      final tmp = await getTemporaryDirectory();
      final dir = Directory('${tmp.path}/live_thumb_${DateTime.now().millisecondsSinceEpoch}');
      await dir.create(recursive: true);
      final list = await Composer.extractThumbnails(
        videoPath: widget.videoPath,
        outDir: dir.path,
        count: 10,
        durationSec: _totalMs / 1000,
      );
      if (!mounted) return;
      setState(() {
        _thumbs
          ..clear()
          ..addAll(list);
      });
    } catch (_) {
      // 抽帧失败就保留条纹底图
    }
  }

  void _onTick() {
    if (!mounted) return;
    final ctrl = _ctrl;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    final pos = ctrl.value.position.inMilliseconds;
    if (pos < _startMs - 150 || pos > _endMs + 150) {
      ctrl.seekTo(Duration(milliseconds: _startMs));
      return;
    }
    if ((pos - _playMs).abs() > 70) {
      setState(() => _playMs = pos.clamp(0, _totalMs));
    }
  }

  @override
  void dispose() {
    _ctrl?.removeListener(_onTick);
    _ctrl?.dispose();
    super.dispose();
  }

  void _seek(int ms) {
    final v = ms.clamp(0, _totalMs);
    _ctrl?.seekTo(Duration(milliseconds: v));
    setState(() => _playMs = v);
  }

  void _togglePlay() {
    final ctrl = _ctrl;
    if (ctrl == null) return;
    if (_playing) {
      ctrl.pause();
      setState(() => _playing = false);
    } else {
      if (_playMs < _startMs || _playMs >= _endMs) _seek(_startMs);
      ctrl.play();
      setState(() => _playing = true);
    }
  }

  double _msToX(int ms) => _totalMs <= 0 ? 0 : ms / _totalMs * _stripWidth;

  int _xToMs(double x) {
    if (_stripWidth <= 0) return 0;
    return ((x / _stripWidth) * _totalMs).round().clamp(0, _totalMs);
  }

  void _onStripStart(Offset local) {
    _ctrl?.pause();
    _playing = false;
    final xl = _msToX(_startMs);
    final xr = _msToX(_endMs);
    if ((local.dx - xl).abs() < 26) {
      _draggingLeft = true;
      _draggingRight = false;
    } else if ((local.dx - xr).abs() < 26) {
      _draggingLeft = false;
      _draggingRight = true;
    } else {
      _draggingLeft = false;
      _draggingRight = false;
      _seek(_xToMs(local.dx));
    }
    setState(() {});
  }

  void _onStripUpdate(Offset local) {
    final ms = _xToMs(local.dx);
    setState(() {
      if (_draggingLeft) {
        var s = ms;
        if (s > _endMs - 500) s = _endMs - 500;
        if (s < 0) s = 0;
        _startMs = s;
        if (_coverMs < s) _coverMs = s;
        if (_playMs < s) _playMs = s;
        _ctrl?.seekTo(Duration(milliseconds: _startMs));
      } else if (_draggingRight) {
        var e = ms;
        if (e - _startMs > _maxLenMs) e = _startMs + _maxLenMs;
        if (e > _totalMs) e = _totalMs;
        if (e < _startMs + 500) e = _startMs + 500;
        _endMs = e;
        if (_coverMs > e) _coverMs = e;
        if (_playMs > e) _playMs = e;
        _ctrl?.seekTo(Duration(milliseconds: _endMs));
      } else {
        _playMs = ms;
        _ctrl?.seekTo(Duration(milliseconds: _playMs));
      }
    });
  }

  void _onStripEnd() {
    _draggingLeft = false;
    _draggingRight = false;
  }

  void _setCover() {
    final c = _playMs.clamp(_startMs, _endMs);
    setState(() => _coverMs = c);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('封面帧已设为 ${(c / 1000).toStringAsFixed(1)}s'),
        duration: const Duration(milliseconds: 1200),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      // 顶栏：玻璃返回钮 + 标题（与合成台 / 模板库一致）
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        leadingWidth: 52,
        titleSpacing: 0,
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
              child: Icon(Icons.chevron_left, size: 18, color: AppColors.text),
            ),
          ),
        ),
        title: const Text(
          '选帧与裁切',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
      ),
      body: _err != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(_err!, style: TextStyle(color: AppColors.textSub)),
              ),
            )
          : !_ready
              ? const Center(child: CircularProgressIndicator())
              : _buildBody(),
    );
  }

  Widget _buildBody() {
    final ctrl = _ctrl!;
    final ratio =
        ctrl.value.aspectRatio == 0 ? 9 / 16 : ctrl.value.aspectRatio;
    return Column(
      children: [
        // ── 预览（按视频比例，不留白）──
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: glassCardGradient(),
              border: Border.all(color: glassCardBorder(), width: 1.5),
            ),
            child: Center(
              child: AspectRatio(
                aspectRatio: ratio,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Colors.black),
                      FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: ctrl.value.size.width,
                          height: ctrl.value.size.height,
                          child: VideoPlayer(ctrl),
                        ),
                      ),
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .55),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            '${(_playMs / 1000).toStringAsFixed(1)}s'
                            ' / ${(_endMs / 1000).toStringAsFixed(1)}s',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      // ▶ 播放 / 暂停：预览当前裁剪片段（自动在 startMs~endMs 内循环）
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _togglePlay,
                        child: Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .55),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withValues(alpha: .35)),
                          ),
                          child: Icon(
                            _playing
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // ── 当前时间 / 片段范围 ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Text(
                '${(_playMs / 1000).toStringAsFixed(1)}s',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.accent,
                ),
              ),
              const Spacer(),
              Text(
                '片段 ${(_startMs / 1000).toStringAsFixed(1)}s'
                ' ~ ${(_endMs / 1000).toStringAsFixed(1)}s'
                '（${((_endMs - _startMs) / 1000).toStringAsFixed(1)}s）',
                style: TextStyle(fontSize: 11.5, color: AppColors.textSub),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // ── 胶片条（玻璃卡）──
        Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: glassCardGradient(),
            border: Border.all(color: glassCardBorder(), width: 1.5),
          ),
          child: LayoutBuilder(builder: (context, box) {
            _stripWidth = box.maxWidth;
            return Column(
              children: [
                // 黄色小点：封面帧（条上方）
                SizedBox(
                  height: 16,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left:
                            (_msToX(_coverMs) - 6).clamp(0.0, _stripWidth - 12),
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFC53D),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .25),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 胶片条本体
                GestureDetector(
                  onHorizontalDragStart: (d) => _onStripStart(d.localPosition),
                  onHorizontalDragUpdate: (d) =>
                      _onStripUpdate(d.localPosition),
                  onHorizontalDragEnd: (_) => _onStripEnd(),
                  onTapDown: (d) {
                    _onStripStart(d.localPosition);
                    _onStripEnd();
                  },
                  child: SizedBox(
                    height: 58,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 条纹底
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: _thumbs.isEmpty
                                ? CustomPaint(
                                    painter: _FilmStripPainter(),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Color(0xFF2E3A52),
                                            Color(0xFF36445F),
                                            Color(0xFF2A3449),
                                            Color(0xFF313D54),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                : Row(
                                    children: [
                                      for (final f in _thumbs)
                                        Expanded(
                                          child: Image.file(
                                            File(f),
                                            fit: BoxFit.cover,
                                            height: 58,
                                            gaplessPlayback: true,
                                          ),
                                        ),
                                    ],
                                  ),
                          ),
                        ),
                        // 左遮罩
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: _msToX(_startMs).clamp(0.0, _stripWidth),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0x9E0A0E18),
                              borderRadius: BorderRadius.horizontal(
                                  left: Radius.circular(10)),
                            ),
                          ),
                        ),
                        // 右遮罩
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          width:
                              (_stripWidth - _msToX(_endMs)).clamp(0.0, _stripWidth),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0x9E0A0E18),
                              borderRadius: BorderRadius.horizontal(
                                  right: Radius.circular(10)),
                            ),
                          ),
                        ),
                        // 选中框
                        Positioned(
                          left: _msToX(_startMs),
                          top: 0,
                          bottom: 0,
                          width: (_msToX(_endMs) - _msToX(_startMs))
                              .clamp(2.0, _stripWidth),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF4A90FF),
                                width: 2.5,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        // 左手柄
                        Positioned(
                          left: _msToX(_startMs).clamp(0.0, _stripWidth - 16),
                          top: 0,
                          bottom: 0,
                          child: _Handle(left: true),
                        ),
                        // 右手柄
                        Positioned(
                          left: (_msToX(_endMs) - 16)
                              .clamp(0.0, _stripWidth - 16),
                          top: 0,
                          bottom: 0,
                          child: _Handle(left: false),
                        ),
                        // 白色播放头
                        Positioned(
                          left: _msToX(_playMs).clamp(0.0, _stripWidth - 2),
                          top: -14,
                          bottom: 0,
                          child: IgnorePointer(
                            child: SizedBox(
                              width: 2,
                              child: Column(
                                children: [
                                  Transform.translate(
                                    offset: const Offset(-6, 0),
                                    child: Container(
                                      width: 14,
                                      height: 9,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(2)),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Container(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 标尺
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final s in [
                      0,
                      _totalMs ~/ 4,
                      _totalMs ~/ 2,
                      _totalMs * 3 ~/ 4,
                      _totalMs,
                    ])
                      Text(
                        '${(s / 1000).toStringAsFixed(0)}s',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textFaint),
                      ),
                  ],
                ),

                // 跟随播放头的「设为封面」
                SizedBox(
                  height: 40,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: (_msToX(_playMs) - 50)
                            .clamp(0.0, _stripWidth - 100),
                        top: 6,
                        child: GestureDetector(
                          onTap: _setCover,
                          child: Container(
                            height: 30,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF7E0),
                              borderRadius: BorderRadius.circular(15),
                              border:
                                  Border.all(color: const Color(0xFFFFE28A)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.adjust,
                                    size: 13, color: Color(0xFFB8860B)),
                                SizedBox(width: 4),
                                Text(
                                  '设为封面',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFB8860B),
                                  ),
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
            );
          }),
        ),

        // ── 下一步（悬浮玻璃底栏）──
        SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              gradient: glassCardGradient(),
              border: Border.all(color: glassCardBorder(), width: 1.5),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(
                    context,
                    LiveTrimResult(
                      startMs: _startMs,
                      endMs: _endMs,
                      coverMs: _coverMs.clamp(_startMs, _endMs),
                    ),
                  );
                },
                child: const Text(
                  '下一步',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 左右蓝色手柄（白色双竖线）
class _Handle extends StatelessWidget {
  final bool left;
  const _Handle({required this.left});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 16,
        decoration: BoxDecoration(
          color: const Color(0xFF4A90FF),
          borderRadius: BorderRadius.horizontal(
            left: Radius.circular(left ? 6 : 0),
            right: Radius.circular(left ? 0 : 6),
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 2,
                height: 7,
                color: Colors.white.withValues(alpha: .95),
              ),
              const SizedBox(height: 2),
              Container(
                width: 2,
                height: 7,
                color: Colors.white.withValues(alpha: .95),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 胶片条纹理：竖条纹模拟帧缩略图
class _FilmStripPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const step = 18.0;
    var x = 0.0;
    var i = 0;
    while (x < size.width) {
      final t = (i % 4) / 4;
      paint.color = Color.lerp(
        const Color(0xFF26303F),
        const Color(0xFF3A4A66),
        t,
      )!;
      canvas.drawRect(Rect.fromLTWH(x, 0, step - 3, size.height), paint);
      paint.color = const Color(0xFF1E2735);
      canvas.drawRect(Rect.fromLTWH(x + step - 3, 0, 3, size.height), paint);
      x += step;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
