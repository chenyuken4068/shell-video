import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// 模板背景预设：按模板 id 记住背景（色值 + 背景图 + 缩放/偏移 + 图片原尺寸），
/// 退出合成台时留存、下次打开同一模板自动带出，省得重新选。
class BgPreset {
  int color; // 0xAARRGGBB
  String? imagePath;
  double scale;
  double dx;
  double dy;
  int w;
  int h;

  BgPreset({
    this.color = 0xFFFFFFFF,
    this.imagePath,
    this.scale = 1.0,
    this.dx = 0,
    this.dy = 0,
    this.w = 0,
    this.h = 0,
  });

  Map<String, dynamic> toJson() => {
        'color': color,
        'image': imagePath,
        'scale': scale,
        'dx': dx,
        'dy': dy,
        'w': w,
        'h': h,
      };

  factory BgPreset.fromJson(Map<String, dynamic> j) => BgPreset(
        color: (j['color'] as num?)?.toInt() ?? 0xFFFFFFFF,
        imagePath: j['image'] as String?,
        scale: (j['scale'] as num?)?.toDouble() ?? 1.0,
        dx: (j['dx'] as num?)?.toDouble() ?? 0,
        dy: (j['dy'] as num?)?.toDouble() ?? 0,
        w: (j['w'] as num?)?.toInt() ?? 0,
        h: (j['h'] as num?)?.toInt() ?? 0,
      );
}

class BgPresetStore {
  static Directory? _root;

  static Future<File> _file() async {
    if (_root == null) {
      final docs = await getApplicationDocumentsDirectory();
      _root = Directory(p.join(docs.path, 'shell_video_app'));
      await _root!.create(recursive: true);
    }
    return File(p.join(_root!.path, 'bg_presets.json'));
  }

  static Future<Map<String, dynamic>> _all() async {
    try {
      final f = await _file();
      if (!await f.exists()) return <String, dynamic>{};
      final j = jsonDecode(await f.readAsString());
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    return <String, dynamic>{};
  }

  static Future<BgPreset?> get(String templateId) async {
    final all = await _all();
    final v = all[templateId];
    if (v is Map<String, dynamic>) return BgPreset.fromJson(v);
    return null;
  }

  static Future<void> put(String templateId, BgPreset preset) async {
    if (templateId.isEmpty) return;
    try {
      final all = await _all();
      all[templateId] = preset.toJson();
      final f = await _file();
      await f.writeAsString(jsonEncode(all));
    } catch (_) {}
  }

  static Future<void> remove(String templateId) async {
    try {
      final all = await _all();
      if (all.remove(templateId) == null) return;
      final f = await _file();
      await f.writeAsString(jsonEncode(all));
    } catch (_) {}
  }
}
