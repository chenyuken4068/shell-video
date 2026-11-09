import 'app_log.dart';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/shell_template.dart';

/// 模板库存储：JSON 索引 + 壳图文件
class TemplateStore {
  static const _indexName = 'templates.json';
  /// asset 路径 : 屏幕区域参数（旧表，仅当 index.json 读不到时兜底）
  static const Map<String, Map<String, int>> _builtInAssets = {
    'assets/templates/xiaomi14.png': {'x': 95, 'y': 157, 'w': 1198, 'h': 2669, 'r': 132},
    'assets/templates/xiaomi17pro.png': {'x': 37, 'y': 35, 'w': 1194, 'h': 2599, 'r': 95},
  };

  /// 内置模板清单：优先读 assets/templates/index.json，
  /// 这样"合入新内置模板"只要往 assets 里加图 + 改 json，不用改 Dart 代码
  static const String _builtInManifest = 'assets/templates/index.json';

  Future<List<Map<String, dynamic>>> _builtInSpecs() async {
    try {
      final raw = await rootBundle.loadString(_builtInManifest);
      final j = jsonDecode(raw);
      final list = j is Map<String, dynamic> ? j['templates'] : j;
      if (list is List) {
        final out = <Map<String, dynamic>>[];
        for (final e in list) {
          if (e is Map<String, dynamic> && e['file'] is String) {
            out.add(e);
          }
        }
        if (out.isNotEmpty) return out;
      }
    } catch (_) {}
    return _builtInAssets.entries
        .map((e) => <String, dynamic>{
              'id': p.basenameWithoutExtension(e.key),
              'name': p.basenameWithoutExtension(e.key),
              'file': p.basename(e.key),
              'x': e.value['x'],
              'y': e.value['y'],
              'w': e.value['w'],
              'h': e.value['h'],
              'r': e.value['r'],
              'transparent': false,
            })
        .toList();
  }

  Directory? _root;

  Future<Directory> _dir() async {
    if (_root != null) return _root!;
    final docs = await getApplicationDocumentsDirectory();
    _root = Directory(p.join(docs.path, 'shell_video_app', 'templates'));
    await _root!.create(recursive: true);
    return _root!;
  }

  /// 首启时把内置壳图解压到应用目录（ffmpeg 需要真实文件路径）
  Future<void> init() async {
    final root = await _dir();
    await _migrateCalibrationOnce(root);
    // 导入模板不做自动重标定：请在「标定」页点「识别」（用你原来的算法 ✓）
    final indexFile = File(p.join(root.path, _indexName));
    final List<Map<String, dynamic>> list = [];
    if (await indexFile.exists()) {
      final data = jsonDecode(await indexFile.readAsString());
      if (data is List) {
        for (final e in data) {
          if (e is Map<String, dynamic>) list.add(e);
        }
      }
    }
    var changed = false;

    for (final spec in await _builtInSpecs()) {
      final slug = (spec['id'] ?? spec['name'] ?? 'template').toString();
      final fileName = spec['file'].toString();
      final displayName = (spec['name'] ?? slug).toString();
      final id = 'builtin_$slug';
      // 已存在则跳过（不做任何自动校正）
      if (list.any((e) => e['id'] == id)) continue;


      final asset = 'assets/templates/$fileName';
      final casePath = p.join(root.path, slug, 'case.png');
      await Directory(p.dirname(casePath)).create(recursive: true);
      final data = await rootBundle.load(asset);
      await File(casePath).writeAsBytes(data.buffer.asUint8List());

      // 读取图片尺寸
      final dim = await _imageSize(casePath);
      list.add({
        'id': id,
        'name': displayName,
        'casePath': casePath,
        'caseWidth': dim.$1,
        'caseHeight': dim.$2,
        'screenX': spec['x'],
        'screenY': spec['y'],
        'screenW': spec['w'],
        'screenH': spec['h'],
        'cornerR': spec['r'],
        'builtIn': true,
        'isTransparent': spec['transparent'] == true,
      });
      changed = true;
    }

    if (changed) {
      await indexFile.writeAsString(jsonEncode(list));
    }
  }

  /// 一次性迁移（v2）：把内置模板的标定重写为 assets 的实测值。
  /// 只执行一次（用标记文件），之后不再改动任何标定。
  Future<void> _migrateCalibrationOnce(Directory root) async {
    final flag = File(p.join(root.path, '.calib_v5'));
    if (await flag.exists()) return;
    try {
      final indexFile = File(p.join(root.path, _indexName));
      if (await indexFile.exists()) {
        final raw = jsonDecode(await indexFile.readAsString());
        if (raw is List) {
          final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          final specs = await _builtInSpecs();
          final byId = {for (final s in specs) 'builtin_${s['id'] ?? s['name']}': s};
          var n = 0;
          for (final e in list) {
            final spec = byId[e['id']];
            if (spec == null) continue;                 // 用户导入的模板不动
            final changedCal = (e['screenX'] != spec['x']) ||
                (e['screenY'] != spec['y']) ||
                (e['screenW'] != spec['w']) ||
                (e['screenH'] != spec['h']) ||
                (e['cornerR'] != spec['r']);
            e['screenX'] = spec['x'];
            e['screenY'] = spec['y'];
            e['screenW'] = spec['w'];
            e['screenH'] = spec['h'];
            e['cornerR'] = spec['r'];
            if (changedCal) n++;
          }
          if (n > 0) {
            await indexFile.writeAsString(jsonEncode(list));
            AppLog.i('标定迁移 v5：已修正 $n 个内置模板');
          }
        }
      }
      await flag.writeAsString('5');
    } catch (e) {
      AppLog.i('标定迁移失败: $e');
    }
  }


  Future<List<ShellTemplate>> load() async {
    final root = await _dir();
    final indexFile = File(p.join(root.path, _indexName));
    if (!await indexFile.exists()) return [];
    final data = jsonDecode(await indexFile.readAsString());
    final list = <ShellTemplate>[];
    if (data is List) {
      for (final e in data) {
        if (e is Map<String, dynamic>) {
          final t = ShellTemplate.fromJson(e);
          if (await File(t.casePath).exists()) list.add(t);
        }
      }
    }
    return list;
  }

  /// 保存新模板：复制壳图 + 更新索引
  /// [isTransparent] true = 全透明模板（屏幕区域透明，无需抠图）
  Future<ShellTemplate> save({
    required String name,
    required String srcImage,
    required int caseWidth,
    required int caseHeight,
    required int screenX,
    required int screenY,
    required int screenW,
    required int screenH,
    required int cornerR,
    bool isTransparent = false,
  }) async {
    final root = await _dir();
    final list = await load();
    final newId = 'tpl_${DateTime.now().millisecondsSinceEpoch}';

    // 复制壳图到模板目录
    final tplDir = p.join(root.path, newId);
    await Directory(tplDir).create(recursive: true);
    final casePath = p.join(tplDir, 'case.png');
    await File(srcImage).copy(casePath);

    final t = ShellTemplate(
      id: newId,
      name: name,
      casePath: casePath,
      caseWidth: caseWidth,
      caseHeight: caseHeight,
      screenX: screenX,
      screenY: screenY,
      screenW: screenW,
      screenH: screenH,
      cornerR: cornerR,
      isTransparent: isTransparent,
    );

    list.add(t);
    await _writeIndex(list);
    return t;
  }

  /// 更新已有模板参数
  Future<ShellTemplate> updateParams(ShellTemplate t) async {
    final list = await load();
    list.removeWhere((e) => e.id == t.id);
    list.add(t);
    await _writeIndex(list);
    return t;
  }

  Future<void> delete(String id) async {
    final root = await _dir();
    final list = await load();
    list.removeWhere((e) => e.id == id);
    await _writeIndex(list);
    final dir = Directory(p.join(root.path, id));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<void> _writeIndex(List<ShellTemplate> list) async {
    final root = await _dir();
    final indexFile = File(p.join(root.path, _indexName));
    await indexFile.writeAsString(jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  Future<(int, int)> _imageSize(String path) async {
    final f = File(path);
    final bytes = await f.readAsBytes();
    // 简易 PNG 尺寸解析（IHDR）
    if (bytes.length > 24 && bytes[0] == 0x89 && bytes[1] == 0x50) {
      final w = (bytes[16] << 24) | (bytes[17] << 16) | (bytes[18] << 8) | bytes[19];
      final h = (bytes[20] << 24) | (bytes[21] << 16) | (bytes[22] << 8) | bytes[23];
      return (w, h);
    }
    // JPEG 回退：SOF 扫描
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
      var i = 2;
      while (i < bytes.length - 8) {
        if (bytes[i] != 0xFF) {
          i++;
          continue;
        }
        final marker = bytes[i + 1];
        if (marker >= 0xC0 && marker <= 0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC) {
          final h = (bytes[i + 5] << 8) | bytes[i + 6];
          final w = (bytes[i + 7] << 8) | bytes[i + 8];
          return (w, h);
        }
        final len = (bytes[i + 2] << 8) | bytes[i + 3];
        i += 2 + len;
      }
    }
    throw Exception('无法识别图片尺寸');
  }
}
