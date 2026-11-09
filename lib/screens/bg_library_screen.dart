import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/bg_library_store.dart';
import '../theme/app_theme.dart';

/// 背景库：套模板库版式（渐变模糊顶栏 + 返回 + 标题）
/// · 无右上角 ≡、无底部悬浮分组栏
/// · 每行 2 个背景卡、最多 20 张、右下角唯一导入按钮
class BgLibraryScreen extends StatefulWidget {
  const BgLibraryScreen({super.key});

  @override
  State<BgLibraryScreen> createState() => _BgLibraryScreenState();
}

class _BgLibraryScreenState extends State<BgLibraryScreen> {
  List<String> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await BgLibraryStore.load();
    if (!mounted) return;
    setState(() {
      _items = list;
      _loading = false;
    });
  }

  Future<void> _import() async {
    if (_items.length >= BgLibraryStore.maxCount) {
      _toast('最多只能导入 ${BgLibraryStore.maxCount} 张背景');
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result == null || result.files.isEmpty) return;
      String? err;
      for (final f in result.files) {
        final path = f.path;
        if (path == null) continue;
        err = await BgLibraryStore.importFile(path);
        if (err != null) break;
      }
      if (!mounted) return;
      if (err != null) _toast(err);
      await _load();
    } catch (e) {
      _toast('导入失败: $e');
    }
  }

  Future<void> _delete(String path) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除这张背景？'),
        content: const Text('将从背景库中移除，合成台也不再显示。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok != true) return;
    await BgLibraryStore.remove(path);
    await _load();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    final headerH = safeTop + 64.0;

    return Scaffold(
      backgroundColor: AppColors.bg,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(headerH),
        child: Stack(
          children: [
            // 顶栏渐变模糊
            Positioned.fill(
              child: IgnorePointer(
                child: ClipRect(
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (rect) => const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black, Colors.black, Color(0x8C000000), Color(0x00000000)],
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
            // 返回 + 标题 + 计数
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
                      decoration: BoxDecoration(color: AppColors.fill, shape: BoxShape.circle),
                      child: Icon(Icons.chevron_left, size: 22, color: AppColors.text),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text('背景', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  Text(
                    '${_items.length} / ${BgLibraryStore.maxCount}',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textFaint),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _empty()
              : GridView.builder(
                  padding: EdgeInsets.fromLTRB(14, headerH + 8, 14, 120),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 11,
                    mainAxisSpacing: 11,
                    childAspectRatio: 4 / 3,
                  ),
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final path = _items[i];
                    return GestureDetector(
                      onLongPress: () => _delete(path),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(File(path), fit: BoxFit.cover, gaplessPlayback: true),
                            Positioned(
                              left: 7,
                              top: 7,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: .42),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${i + 1}',
                                  style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      // 唯一浮钮：右下角导入
      floatingActionButton: GestureDetector(
        onTap: _import,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: AppColors.isDark
                      ? [Colors.white.withValues(alpha: .16), Colors.white.withValues(alpha: .08)]
                      : [Colors.white.withValues(alpha: .92), Colors.white.withValues(alpha: .72)],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: AppColors.isDark ? .5 : .9), width: 1.5),
              ),
              child: Icon(Icons.add, size: 28, color: AppColors.isDark ? Colors.white : const Color(0xFF111214)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wallpaper_outlined, size: 44, color: AppColors.textFaint),
          const SizedBox(height: 12),
          Text(
            '还没有背景',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textSub),
          ),
          const SizedBox(height: 4),
          Text(
            '点右下角 ＋ 导入，最多 ${BgLibraryStore.maxCount} 张',
            style: TextStyle(fontSize: 12, color: AppColors.textFaint),
          ),
        ],
      ),
    );
  }
}
