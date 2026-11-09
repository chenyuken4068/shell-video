import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

import '../services/bg_library_store.dart';
import '../services/image_utils.dart';
import '../theme/app_theme.dart';

import 'compose_screen.dart';

/// 透明壳合成能力（mixin 形式挂在 `_ComposeScreenState` 上）
///
/// 迁移进度：
///   ① 背景状态（本文件已完成 ✓）
///   ② 背景方法（_setBgColor / _pickBgImage / _setBgFromLibrary）—— 下一步
///   ③ 背景面板 Widget（_bgPanel / _bgFuseRow / _presetColors）—— 再下一步
/// 未迁移完之前，`transparent_compose_screen.dart` 保留不动。
mixin TransparentPart on State<ComposeScreen> {
  // ── 背景：纯色 / 背景图 / 缩放偏移 / 图片原尺寸 ──
  Color bgColor = Colors.white;
  String? bgImagePath;

  /// 取色背景：把素材首帧当背景（略微放大 + 高斯模糊）
  bool bgFromContent = false;

  /// 取色背景用的素材路径（由合成台写入）
  String? bgContentPath;

  /// 背景高斯模糊开关与强度
  bool bgBlurOn = false;
  double bgBlurSigma = 18;
  int bgImageW = 0;
  int bgImageH = 0;

  /// 1.0 = 等比铺满画布(cover)，只允许放大
  double bgImageScale = 1.0;

  /// 相对画布像素偏移（保证覆盖画布，壳外永不露白）
  double bgImageDx = 0;
  double bgImageDy = 0;

  /// 当前是否有背景图
  bool get hasBgImage => bgImagePath != null;

  /// 清掉背景图，只留纯色
  void clearBgImage() {
    bgFromContent = false; // 清除背景 → 关闭取色
    setState(() {
      bgImagePath = null;
      bgImageScale = 1.0;
      bgImageDx = 0;
      bgImageDy = 0;
    });
  }

  // ───────── 背景操作 ─────────

  /// 设纯色背景（会清掉背景图）
  void setBgColor(Color c) {
    bgFromContent = false; // 选纯色 → 关闭取色
    setState(() {
      bgColor = c;
      bgImagePath = null;
    });
  }

  /// 选背景图（读取原尺寸，重置缩放/偏移）
  Future<void> pickBgImage() async {
    bgFromContent = false; // 选背景图 → 关闭取色
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null) return;
      final (w, h) = await imageSize(path);
      setState(() {
        bgImagePath = path;
        bgImageW = w;
        bgImageH = h;
        bgImageScale = 1.0;
        bgImageDx = 0;
        bgImageDy = 0;
      });
    } catch (e) {
      bgToast('读取背景图失败: $e');
    }
  }

  /// 从背景库圆卡直接设背景图
  Future<void> setBgFromLibrary(String path) async {
    bgFromContent = false; // 选背景库图 → 关闭取色
    try {
      final (w, h) = await imageSize(path);
      setState(() {
        bgImagePath = path;
        bgImageW = w;
        bgImageH = h;
        bgImageScale = 1.0;
        bgImageDx = 0;
        bgImageDy = 0;
      });
    } catch (e) {
      bgToast('读取背景图失败: $e');
    }
  }

  /// 打开调色盘
  void openBgColorPicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('选择背景颜色'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: bgColor,
            onColorChanged: (c) => bgColor = c,
            enableAlpha: false,
            labelTypes: const [ColorLabelType.hex],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          TextButton(
            onPressed: () {
              setBgColor(bgColor);
              Navigator.pop(ctx);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void bgToast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  // ───────── 背景色块面板（颜色区）─────────

  /// 预设背景色：白 / 黑 / 红 / 橙 / 黄 / 绿 / 青 / 紫
  static const List<Color> presetBgColors = [
    Color(0xFFFFFFFF),
    Color(0xFF000000),
    Color(0xFFFF3B30),
    Color(0xFFFF9500),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF5AC8FA),
    Color(0xFFAF52DE),
  ];

  Widget _swatch(Color c, {Widget? child}) {
    // 取色背景开启时，任何色块都不显示选中（互斥）
    final selected =
        !hasBgImage && !bgFromContent && bgColor.value == c.value;
    return GestureDetector(
      onTap: () => setBgColor(c),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: c,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.divider,
            width: selected ? 3 : 1,
          ),
        ),
        child: child,
      ),
    );
  }

  /// 背景颜色面板：透明钮 + 预设色块 + 调色盘按钮
  Widget buildBgColorPalette() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        // 🖌 取色背景（素材首帧当背景）
        _brushSwatch(),
        _swatch(
          Colors.transparent,
          child: Icon(Icons.block, size: 16, color: AppColors.textSub),
        ),
        for (final c in presetBgColors) _swatch(c),
        GestureDetector(
          onTap: openBgColorPicker,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hasBgImage ? Colors.white : bgColor,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.divider),
              gradient: !hasBgImage && !presetBgColors.any((c) => c.value == bgColor.value)
                  ? const SweepGradient(colors: [
                      Colors.red,
                      Colors.yellow,
                      Colors.green,
                      Colors.cyan,
                      Colors.blue,
                      Colors.purple,
                      Colors.red,
                    ])
                  : null,
            ),
            child: Icon(Icons.palette_outlined, size: 16, color: AppColors.textSub),
          ),
        ),
        // 导入的背景图接在调色盘后面继续排
        for (final path in bgLibrary) _libCircle(path),
      ],
    );
  }

  /// 🖌 取色背景按钮（图标画笔，选中蓝边）
  /// 🖌 取色背景圆卡（与背景色块同尺寸同风格；选中 = 浅蓝底 + 蓝边）
  Widget _brushSwatch() {
    final on = bgFromContent;
    return GestureDetector(
      onTap: toggleBgFromContent,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.accent.withValues(alpha: .12) : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: on ? AppColors.accent : AppColors.divider,
            width: on ? 2.5 : 1,
          ),
        ),
        child: Icon(Icons.brush,
            size: 16, color: on ? AppColors.accent : AppColors.textSub),
      ),
    );
  }

  /// 切换取色背景（与背景图互斥；需先选素材）
  void toggleBgFromContent() {
    if (!bgFromContent && (bgContentPath ?? '').isEmpty) {
      bgToast('请先选择图片或视频，再使用取色背景');
      return;
    }
    setState(() {
      bgFromContent = !bgFromContent;
      if (bgFromContent) {
        bgImagePath = null;
        // 取色背景默认带高斯模糊（略微放大 + 模糊）
        bgBlurOn = true;
      }
    });
  }

  /// 高斯模糊行（样式与「启用镜像复制背景」一致：卡片 + 右侧白钮开关）
  Widget buildBgBlurRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                child: Text('背景高斯模糊',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text)),
              ),
              Switch.adaptive(
                value: bgBlurOn,
                activeColor: Colors.white,
                activeTrackColor: AppColors.accent,
                onChanged: (v) => setState(() => bgBlurOn = v),
              ),
            ],
          ),
        ),
        // 开启后出现模糊度滑轨
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: bgBlurOn
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
                  child: Row(
                    children: [
                      Text('模糊度',
                          style: TextStyle(
                              fontSize: 11.5, color: AppColors.textSub)),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7),
                            overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 14),
                          ),
                          child: Slider(
                            value: bgBlurSigma.clamp(0, 100),
                            min: 0,
                            max: 100,
                            onChanged: (v) =>
                                setState(() => bgBlurSigma = v),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 30,
                        child: Text('${bgBlurSigma.round()}',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                                fontSize: 11.5, color: AppColors.textSub)),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _libCircle(String path) {
    final on = bgImagePath == path;
    return GestureDetector(
      onTap: () => setBgFromLibrary(path),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: on ? AppColors.accent : AppColors.divider,
            width: on ? 3 : 1,
          ),
          image: DecorationImage(
            image: FileImage(File(path)),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  // ───────── 背景图 + 背景库 ─────────

  /// 背景库（导入的背景图路径列表）
  List<String> bgLibrary = [];

  Future<void> loadBgLibrary() async {
    final list = await BgLibraryStore.load();
    if (!mounted) return;
    setState(() => bgLibrary = list);
  }

  /// 背景图选择行（文件名 + 选择/清除）
  Widget buildBgImageRow() {
    final has = hasBgImage;
    return GestureDetector(
      onTap: pickBgImage,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.wallpaper_outlined, size: 18, color: AppColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                has ? File(bgImagePath!).uri.pathSegments.last : '选择背景图片',
                maxLines: 1,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: has ? AppColors.text : AppColors.textSub,
                ),
              ),
            ),
            if (has)
              GestureDetector(
                onTap: clearBgImage,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Text('清除',
                      style: TextStyle(fontSize: 12, color: AppColors.accent)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 背景库圆卡（点击直接套用，选中带蓝边）
  Widget buildBgLibraryCircles() {
    if (bgLibrary.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final path in bgLibrary)
          GestureDetector(
            onTap: () => setBgFromLibrary(path),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: bgImagePath == path ? AppColors.accent : AppColors.divider,
                  width: bgImagePath == path ? 3 : 1,
                ),
                image: DecorationImage(
                  image: FileImage(File(path)),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
      ],
    );
  }


  /// 背景图大小 / 水平 / 垂直 调节（有背景图时才显示）
  Widget buildBgTransformRow() {
    if (!hasBgImage) return const SizedBox.shrink();
    Widget slider(String label, double value, double min, double max,
        ValueChanged<double> onChanged) {
      return Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(label,
                style: TextStyle(fontSize: 11, color: AppColors.textSub)),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
            ),
          ),
        ],
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.fromLTRB(10, 2, 10, 2),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          slider('大小', bgImageScale, 1.0, 3.0,
              (v) => setState(() => bgImageScale = v)),
          slider('水平', bgImageDx, -400, 400,
              (v) => setState(() => bgImageDx = v)),
          slider('垂直', bgImageDy, -400, 400,
              (v) => setState(() => bgImageDy = v)),
        ],
      ),
    );
  }
}
