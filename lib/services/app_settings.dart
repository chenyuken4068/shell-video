import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'composer.dart';

/// 默认导出设置（我的页可改，制作台读取为默认值）
class AppSettings {
  String background; // white / black
  Quality quality;
  bool hardware;
  int fps; // 导出帧率；0 = 原帧率（用视频探测值）
  bool autoSaveBg; // 自动留存模板背景（色值/背景图/缩放偏移）
  bool autoPickBg; // 自动取色：把素材首帧当背景（放大+模糊）
  bool bootAnim; // 开屏动画（启动时显示合成台原理图动画）
  String navGlass; // 底栏玻璃效果：matte = 柔光玻璃（默认）/ liquid = 液态玻璃
  double navGlassOpacity; // 液态玻璃通透度（越小越透），0.02 ~ 0.30
  String themeMode; // 背景模式：light = 白色（默认）/ dark = 黑色 / system = 跟随系统
  List<String> tplGroups; // 模板库分组顺序（空 = 用内置默认顺序）
  List<String> tplHidden; // 模板库被隐藏的分组

  /// 创作页卡片顺序（空 = 默认顺序）
  List<String> homeOrder;

  /// 创作页被隐藏的卡片
  List<String> homeHidden;

  AppSettings({
    this.background = 'white',
    this.quality = Quality.original,
    this.hardware = true,
    this.fps = 0,
    this.autoSaveBg = true,
    this.autoPickBg = true,
    this.bootAnim = true,
    this.navGlass = 'matte',
    this.navGlassOpacity = 0.02,
    this.themeMode = 'light',
    this.tplGroups = const [],
    this.tplHidden = const [],
    this.homeOrder = const [],
    this.homeHidden = const [],
  });

  String get bgLabel => background == 'white' ? '白底' : '黑底';
  String get qualityLabel => switch (quality) {
        Quality.original => '原画质',
        Quality.p1080 => '1080P',
        Quality.p720 => '720P',
      };
  String get hardwareLabel => hardware ? '硬件加速' : '软件编码';
  String get fpsLabel => fps <= 0 ? '原帧率' : '${fps}fps';
  String get autoSaveBgLabel => autoSaveBg ? '自动留存' : '不留存';
  String get autoPickBgLabel => autoPickBg ? '自动取色' : '关闭';
  String get navGlassLabel => navGlass == 'liquid' ? '液态玻璃' : '柔光玻璃';
  String get themeModeLabel => switch (themeMode) {
        'dark' => '黑色',
        'system' => '跟随系统',
        _ => '白色',
      };

  Map<String, dynamic> toJson() => {
        'background': background,
        'quality': quality.name,
        'hardware': hardware,
        'fps': fps,
        'autoSaveBg': autoSaveBg,
        'autoPickBg': autoPickBg,
        'bootAnim': bootAnim,
        'navGlass': navGlass,
        'navGlassOpacity': navGlassOpacity,
        'themeMode': themeMode,
        'tplGroups': tplGroups,
        'tplHidden': tplHidden,
    'homeOrder': homeOrder,
    'homeHidden': homeHidden,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        background: j['background'] as String? ?? 'white',
        quality: Quality.values.asNameMap()[j['quality']] ?? Quality.original,
        hardware: j['hardware'] as bool? ?? true,
        fps: (j['fps'] as num?)?.toInt() ?? 0,
        autoSaveBg: j['autoSaveBg'] as bool? ?? true,
        autoPickBg: j['autoPickBg'] as bool? ?? true,
        bootAnim: j['bootAnim'] as bool? ?? true,
        navGlass: j['navGlass'] as String? ?? 'matte',
        navGlassOpacity: (j['navGlassOpacity'] as num?)?.toDouble() ?? 0.02,
        themeMode: j['themeMode'] as String? ?? 'light',
        tplGroups:
            (j['tplGroups'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        tplHidden:
            (j['tplHidden'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    homeOrder:
        (j['homeOrder'] as List?)?.map((e) => e.toString()).toList() ?? const [],
    homeHidden:
        (j['homeHidden'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      );
}

class SettingsStore {
  Directory? _root;

  Future<File> _file() async {
    if (_root == null) {
      final docs = await getApplicationDocumentsDirectory();
      _root = Directory(p.join(docs.path, 'shell_video_app'));
      await _root!.create(recursive: true);
    }
    return File(p.join(_root!.path, 'settings.json'));
  }

  Future<AppSettings> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return AppSettings();
      final j = jsonDecode(await f.readAsString());
      if (j is Map<String, dynamic>) return AppSettings.fromJson(j);
    } catch (_) {}
    return AppSettings();
  }

  Future<void> save(AppSettings s) async {
    final f = await _file();
    await f.writeAsString(jsonEncode(s.toJson()));
  }
}

/// 自动取色开关（我的 → 通用设置）
final ValueNotifier<bool> gAutoPickBg = ValueNotifier<bool>(true);

/// 创作页卡片顺序（空 = 默认）
final ValueNotifier<List<String>> gHomeOrder = ValueNotifier<List<String>>([]);

/// 创作页被隐藏的卡片
final ValueNotifier<List<String>> gHomeHidden = ValueNotifier<List<String>>([]);

/// 创作页卡片的默认顺序（key 与 home_screen 一致）
const List<String> kDefaultHomeOrder = [
  'create',   // 开始创作
  'newShell', // 添加新壳
  'tplLib',   // 模板库
  'bgLib',    // 背景库
  'recent',   // 最近作品
];

/// 卡片显示名
const Map<String, String> kHomeCardNames = {
  'create': '开始创作',
  'newShell': '添加新壳',
  'tplLib': '模板库',
  'bgLib': '背景库',
  'recent': '最近作品',
};
